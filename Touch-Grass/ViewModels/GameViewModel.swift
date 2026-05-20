//
//  GameViewModel.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class GameViewModel: ObservableObject {
    // PERFORMANCE: Lazy initialization - services are only created when needed
    // This dramatically improves initial load time since services won't be initialized
    // until a game is actually selected or session is created
    private var _locationService: LocationService?
    private var _gameService: GameService?
    
    @Published var playerName: String = "Player"
    /// Drives the in-app "Game Over" alert in ContentView. Set this only for
    /// genuine end-of-session messaging (elimination, etc.) — inline and
    /// toast feedback now own everything else.
    @Published var showGameOverAlert = false
    @Published var gameOverMessage = ""
    /// Lightweight toast surfaced by `ContentView`. Set with `presentToast(...)`
    /// for transient feedback that doesn't belong inline (sign-in, GPS
    /// timeouts, generic blocking conditions).
    @Published var activeToast: AppToastMessage?
    /// Inline error for the join-code input. The active lobby reads this to
    /// render the shake / red border / X icon. Cleared by the input on edit.
    @Published var joinCodeError: JoinCodeError?
    /// Blocking, themed notice surfaced by the active lobby (or any view that
    /// opts in). Used in place of native `.alert(...)` for begin-game
    /// validation, configuration errors, and other lobby-scoped messages.
    @Published var lobbyNotice: LobbyNotice?
    /// Blocking top-level notice for terminal session events that should
    /// return every client to the game picker, such as the host leaving.
    @Published var sessionEndedNotice: SessionEndedNotice?
    @Published var selectedGameType: GameType = .manhunt // Track selected game type
    @Published var isBeginningGame: Bool = false // Prevent multiple simultaneous beginGame calls
    
    // CRITICAL: Use @Published for selectedGame to ensure reliable updates in release builds
    // @State can be optimized away in release, but @Published is always tracked
    @Published var selectedGame: GameType? = nil
    
    // Loading state for smooth transitions
    @Published var isServicesInitializing: Bool = false
    @Published var isCreatingSession: Bool = false
    @Published var isJoiningGame: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private var createSessionCancellable: AnyCancellable?
    private var joinGameCancellable: AnyCancellable?
    private var handledHostLeftSessionIds = Set<String>()

    struct SessionEndedNotice: Identifiable, Equatable {
        let id = UUID()
        let gameType: GameType
        let title: String
        let message: String
    }
    
    // Public accessors that ensure services are initialized when accessed
    var locationService: LocationService {
        if let service = _locationService {
            return service
        }
        let service = LocationService()
        _locationService = service
        return service
    }
    
    var gameService: GameService {
        if let service = _gameService {
            return service
        }
        // CRITICAL: Initialize location service first if not already done
        // This must happen synchronously to avoid race conditions
        let location = locationService
        
        // Create GameService - this is lightweight and non-blocking
        // GameService.init only sets up callbacks, doesn't do heavy work
        let service = GameService(locationService: location)
        _gameService = service
        
        // Setup subscriptions - Combine subscriptions are non-blocking
        // This is safe to do synchronously as it just sets up publishers
        setupSubscriptions(location: location, game: service)
        
        return service
    }
    
    init() {
        // PERFORMANCE: Don't create services in init
        // Services will be lazily initialized when first accessed
    }

    // MARK: - Feedback helpers

    /// Show a transient toast at the top of the app. Use for situational
    /// failures that aren't tied to a specific control (sign-in, GPS).
    func presentToast(_ message: String, type: ToastType = .error) {
        activeToast = AppToastMessage(message: message, type: type)
    }

    /// Mark a join-code attempt as failed. If the message maps to a known
    /// inline category the lobby renders it on the field; otherwise it
    /// surfaces as a toast so the user still gets feedback.
    func reportJoinFailure(_ message: String) {
        if let inline = JoinCodeError.from(gameServiceMessage: message) {
            joinCodeError = inline
        } else {
            presentToast(message, type: .error)
        }
    }

    func clearJoinCodeError() {
        if joinCodeError != nil { joinCodeError = nil }
    }

    /// Surface a blocking lobby notice (themed). Active lobbies observe
    /// `$lobbyNotice` and render a `ThemedNoticeOverlay`.
    func presentLobbyNotice(_ notice: LobbyNotice) {
        lobbyNotice = notice
    }

    func dismissSessionEndedNotice() {
        sessionEndedNotice = nil
    }

    @discardableResult
    func leaveCurrentSessionFromUserAction() async -> Bool {
        let currentSession = gameService.session
        let currentPlayer = gameService.currentPlayer
        let wasHost = currentSession?.isDeviceHost(currentPlayer) ?? false
        let gameType = currentSession?.gameType ?? selectedGameType
        let sessionId = currentSession?.id

        if wasHost, let sessionId {
            // Mark this session as already handled so the host's own
            // Firestore `hostLeft` echo doesn't trigger the remote
            // "Host Left" notice that's meant for non-hosts.
            handledHostLeftSessionIds.insert(sessionId)
        }

        let didLeave = await gameService.leaveSession()
        guard didLeave else {
            if wasHost, let sessionId {
                handledHostLeftSessionIds.remove(sessionId)
            }
            presentToast("Couldn't leave the lobby. Check your connection and try again.", type: .error)
            return false
        }

        if wasHost {
            selectedGameType = gameType
        }
        return true
    }

    /// Convenience for the common "Can't do that yet" lobby validation.
    private func presentLobbyMessage(_ message: String, title: String = "Heads up") {
        presentLobbyNotice(LobbyNotice(title: title, message: message))
    }

    /// Map the legacy `GameService.BeginGameErrorAction` to the new
    /// `LobbyNotice.Action` so the themed notice can offer the right
    /// follow-up button (e.g. "Manage Teams", "Configure Game").
    private func lobbyAction(from action: GameService.BeginGameErrorAction?) -> LobbyNotice.Action {
        switch action {
        case .openSettings:
            return .openBubbleSettings
        case .openTeamManagement:
            return .openTeamManagement
        case .openSessionSetup:
            return .openSessionSetup
        case .dismiss, .none:
            return .dismiss
        }
    }

    /// Attempt to rehydrate a previously-active lobby on app launch.
    /// Safe to call multiple times — `GuestSessionStore` only returns a
    /// fresh snapshot once and clears it on misses.
    func resumeActiveSessionIfNeeded() async {
        guard selectedGame == nil, gameService.session == nil else { return }
        if let restoredType = await gameService.resumeIfPossible() {
            selectedGameType = restoredType
            selectedGame = restoredType
        }
    }
    
    // MARK: - Service Initialization
    
    /// Ensures services are initialized (called when game is selected)
    /// This is safe to call multiple times - it only initializes once
    /// Sets isServicesInitializing flag to allow smooth loading UI
    func ensureServicesInitialized() async {
        #if DEBUG
        print("🔍 DEBUG: ensureServicesInitialized() called")
        print("🔍 DEBUG: _locationService exists: \(_locationService != nil)")
        print("🔍 DEBUG: _gameService exists: \(_gameService != nil)")
        #endif
        
        // If services already exist, no initialization needed
        if _locationService != nil && _gameService != nil {
            return
        }
        
        // Set loading flag
        isServicesInitializing = true
        
        // Initialize services asynchronously to avoid blocking UI
        // Note: Service initialization is still synchronous, but we wrap it in Task
        // to allow the loading UI to appear first
        await Task { @MainActor in
            // Access services to trigger lazy initialization
            // The computed properties handle the initialization logic
            _ = locationService
            _ = gameService
            
            // Clear loading flag immediately after initialization (no artificial delay)
            isServicesInitializing = false
        }.value
    }
    
    /// Synchronous version for internal use (when services must be ready immediately)
    /// Only use this when you know services are already initialized
    private func ensureServicesInitializedSync() {
        _ = locationService
        _ = gameService
    }
    
    func requestBluetoothPermissionIfNeeded() {
        ensureServicesInitializedSync()
        guard selectedGameType != .captureTheFlag else { return }
        gameService.requestBluetoothPermissionIfNeeded()
    }
    
    func requestRequiredPreGamePermissions() {
        ensureServicesInitializedSync()
        locationService.requestPermission()
        requestBluetoothPermissionIfNeeded()
    }
    
    private func setupSubscriptions(location: LocationService, game: GameService) {
        // Subscribe to location updates
        // CTF: Only update location if player is a flag player
        location.$coordinate
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                guard let self = self else { return }
                // CTF: Only track location for flag players
                if let session = self._gameService?.session,
                   session.gameType == .captureTheFlag,
                   let currentPlayer = self._gameService?.currentPlayer,
                   !currentPlayer.isFlag {
                    // Non-flag player in CTF - don't update location
                    return
                }
                self._gameService?.updatePlayerLocation(coordinate)
            }
            .store(in: &cancellables)
        
        // Subscribe to game state changes
        game.$isOutOfBounds
            .sink { [weak self] isOut in
                if isOut {
                    self?.handlePlayerEliminated()
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to game over condition
        game.$shouldEndGame
            .sink { [weak self] shouldEnd in
                if shouldEnd {
                    self?.handleGameOver()
                }
            }
            .store(in: &cancellables)
        
        // Forward only critical gameService changes (not all changes)
        // Only forward gameState changes to reduce unnecessary view updates
        game.$gameState
            .dropFirst() // Skip initial value
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        // Also forward session changes (which affect UI routing)
        game.$session
            .dropFirst()
            .sink { [weak self] session in
                self?.objectWillChange.send()
                self?.handleHostLeftSessionIfNeeded(session, game: game)
            }
            .store(in: &cancellables)
    }

    private func handleHostLeftSessionIfNeeded(_ session: GameSession?, game: GameService) {
        guard let session,
              session.gameState == .ended,
              session.endReason == .hostLeft,
              selectedGame != nil,
              !handledHostLeftSessionIds.contains(session.id) else {
            return
        }

        handledHostLeftSessionIds.insert(session.id)
        selectedGameType = session.gameType
        sessionEndedNotice = SessionEndedNotice(
            gameType: session.gameType,
            title: "Host Left",
            message: "The host left the game, so the session ended."
        )
        selectedGame = nil
        game.discardEndedSessionLocally(reason: "host-left-remote")
    }
    
    func createSession() {
        guard locationService.isReadyForGameplay else {
            requestRequiredPreGamePermissions()
            presentToast("Finish the two-step location setup before creating a game.", type: .warning)
            return
        }
        requestBluetoothPermissionIfNeeded()

        // Set loading state
        isCreatingSession = true
        
        // Ensure services are initialized (sync version for immediate use)
        ensureServicesInitializedSync()
        
        let location = locationService
        let game = gameService

        Task { @MainActor in
            let playerId: String
            do {
                playerId = try await AuthService.shared.ensureSignedIn()
            } catch {
                self.isCreatingSession = false
                self.presentToast("Sign-in failed. Check your connection and try again.", type: .error)
                return
            }

            // CRITICAL: Always clear any existing session first to ensure fresh lobby
            // This guarantees a new join code and clean state every time
            game.clearSession()

            // Use profile name if available, otherwise fall back to playerName
            let profileName = ProfileService.shared.displayName
            let nameToUse = profileName.isEmpty ? playerName : profileName

            // Cancel any pending createSession subscription
            createSessionCancellable?.cancel()

            // Helper to create session and handle completion
            let createSessionAction: (CLLocationCoordinate2D) -> Void = { [weak self] coordinate in
                guard let self = self else { return }
                game.createSession(hostName: nameToUse, hostLocation: coordinate, gameType: self.selectedGameType, playerId: playerId)

                // Clear loading state after a brief delay to allow session to be set
                // Session is set synchronously, so we just need to allow UI to update
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000) // 0.3s delay
                    self.isCreatingSession = false
                }
            }

            // If we already have a coordinate, create session immediately
            if let coordinate = location.coordinate {
                createSessionAction(coordinate)
                return
            }

            // Otherwise, request permission (this will start location updates when granted)
            location.requestPermission()
            requestBluetoothPermissionIfNeeded()

            // Observe coordinate updates and create session when location becomes available
            // Use a separate cancellable so we can cancel it if createSession is called again
            createSessionCancellable = location.$coordinate
                .compactMap { $0 }
                .first() // Only take the first non-nil coordinate
                .sink { coordinate in
                    createSessionAction(coordinate)
                }

            // Safety: Set a timeout to clear loading state if location never arrives
            // This handles cases where permission is denied or location service fails
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 second timeout
                // If still loading after timeout, clear it (createSessionAction will have set it to false if successful)
                if isCreatingSession {
                    isCreatingSession = false
                    if location.hasRequiredGamePermission && location.coordinate == nil {
                        presentToast("GPS has not found you yet. Move somewhere with a clearer signal and try again.", type: .warning)
                    }
                }
            }
        }
    }
    
    // Configure game settings (bubble) but keep in lobby
    func configureGame(bubbleStartRadius: Double, duration: Double? = nil, hunterCount: Int = 1, center: CLLocationCoordinate2D? = nil, scoreLimit: Int? = nil, teamABase: CLLocationCoordinate2D? = nil, teamBBase: CLLocationCoordinate2D? = nil, showTimer: Bool = true, enableShrinking: Bool = true) {
        // Ensure services are initialized (sync version for immediate use)
        ensureServicesInitializedSync()
        
        // Use provided center or fall back to user location
        let location = locationService
        let bubbleCenter = center ?? location.coordinate
        
        guard let center = bubbleCenter else {
            presentLobbyMessage("Location not available. Make sure GPS is enabled and try again.", title: "Can't configure game")
            return
        }
        
        // Validate coordinate
        guard center.latitude.isFinite && center.longitude.isFinite,
              center.latitude >= -90 && center.latitude <= 90,
              center.longitude >= -180 && center.longitude <= 180 else {
            presentLobbyMessage("Invalid location coordinates. Please try again.", title: "Can't configure game")
            return
        }
        
        // Validate bubble parameters
        guard bubbleStartRadius > 0 && bubbleStartRadius.isFinite else {
            presentLobbyMessage("Start radius must be greater than 0.", title: "Invalid bubble settings")
            return
        }
        
        guard bubbleStartRadius <= 10000 else {
            presentLobbyMessage("Bubble radius is too large. Maximum is 10,000 meters.", title: "Invalid bubble settings")
            return
        }
        
        // Validate duration only if provided (CTF doesn't use duration)
        if let duration = duration {
            guard duration > 0 && duration.isFinite else {
                presentLobbyMessage("Duration must be greater than 0 seconds.", title: "Invalid game duration")
                return
            }
            
            guard duration <= 7200 else {
                presentLobbyMessage("Maximum is 7200 seconds (2 hours).", title: "Game duration too long")
                return
            }
        }
        
        let maxPlayers = gameService.session?.players.count ?? 1
        #if DEBUG
        let minHunterCount = 0
        #else
        let minHunterCount = 1
        #endif
        guard hunterCount >= minHunterCount else {
            presentLobbyMessage("Hunter count must be at least \(minHunterCount).")
            return
        }
        
        guard hunterCount <= maxPlayers else {
            presentLobbyMessage("Hunter count must be less than or equal to the number of players (\(maxPlayers)).")
            return
        }
        
        // Check if this is CTF (no shrinking, no time limit)
        let isCTF = gameService.session?.gameType == .captureTheFlag
        
        // Determine shrink interval based on enableShrinking setting
        // For CTF: No shrinking, no time limit. Use a very large duration and no shrink interval.
        // For other games: 
        //   - If enableShrinking is true: Progressive shrinking every 3 minutes
        //   - If enableShrinking is false: No shrinking (use sentinel value)
        // Use sentinel value instead of infinity for no shrinking (JSON/Firestore cannot encode infinity)
        let shrinkInterval: Double
        if isCTF {
            shrinkInterval = Bubble.infiniteSentinel // CTF never shrinks
        } else if enableShrinking {
            shrinkInterval = 180 // 3 minutes for shrinking zones
        } else {
            shrinkInterval = Bubble.infiniteSentinel // No shrinking if disabled
        }
        
        let gameDuration: Double = duration ?? (isCTF ? Bubble.infiniteSentinel : 1800) // Use provided duration or default (CTF = sentinel)
        
        // Create bubble with placeholder startTime (will be set when game begins)
        let bubble = Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: bubbleStartRadius,
            startTime: Date(), // Placeholder - will be reset when game actually begins
            shrinkInterval: shrinkInterval,
            duration: gameDuration,
            shrinkHistory: [],
            showTimer: showTimer,
            enableShrinking: enableShrinking
        )
        
        // Configure game with bubble and hunter count together
        // This ensures atomic update and avoids race conditions
        // For CTF, pass team bases (scoreLimit is ignored - win condition is both flags in same safe zone)
        let teamABaseParam = teamABase
        let teamBBaseParam = teamBBase
        gameService.configureGame(bubble: bubble, hunterCount: hunterCount, scoreLimit: nil, teamABase: teamABaseParam, teamBBase: teamBBaseParam)
    }
    
    // Actually begin the game (transition from lobby to active)
    func beginGame() {
        // Prevent multiple simultaneous calls
        guard !isBeginningGame else {
            print("⚠️ beginGame already in progress, ignoring duplicate call")
            return
        }
        
        isBeginningGame = true
        
        // Ensure services are initialized (sync version for immediate use)
        ensureServicesInitializedSync()
        
        guard let session = gameService.session else {
            isBeginningGame = false
            presentLobbyMessage("No session exists.", title: "Can't begin game")
            return
        }
        
        guard session.bubble != nil else {
            isBeginningGame = false
            presentLobbyNotice(LobbyNotice(
                title: "Configure the play zone first",
                message: "Tap Configure Game to set the bubble before starting.",
                primaryAction: .openBubbleSettings
            ))
            return
        }
        
        #if DEBUG
        let vmMinPlayers = 1
        let vmMinHunters = 0
        let vmMinHiders = 0
        #else
        let vmMinPlayers = session.gameType.minimumPlayers
        let vmMinHunters = 1
        let vmMinHiders = 1
        #endif
        guard session.players.count >= vmMinPlayers else {
            isBeginningGame = false
            presentLobbyMessage("Need at least \(vmMinPlayers) player(s) to start. Currently \(session.players.count).", title: "Not enough players")
            return
        }
        
        guard session.hunterCount >= vmMinHunters else {
            isBeginningGame = false
            presentLobbyMessage("Need at least \(vmMinHunters) hunter(s).", title: "Not enough hunters")
            return
        }
        
        let hiderCount = session.players.count - session.hunterCount
        guard hiderCount >= vmMinHiders else {
            isBeginningGame = false
            presentLobbyMessage("Need at least \(vmMinHiders) hider(s). Currently \(hiderCount).", title: "Not enough hiders")
            return
        }
        
        // Check if current player is the host
        guard let currentPlayer = gameService.currentPlayer,
              session.isDeviceHost(currentPlayer) else {
            isBeginningGame = false
            presentLobbyMessage("Only the host can begin the game.")
            return
        }
        
        // GameService.beginGame will reset the bubble start time
        print("🎮 GameViewModel.beginGame called")
        print("   Session exists: \(gameService.session != nil)")
        print("   Bubble exists: \(gameService.session?.bubble != nil)")
        print("   Current player is host: \(session.isDeviceHost(gameService.currentPlayer))")
        print("   Current gameState: \(gameService.gameState)")
        
        gameService.beginGame()
        
        // Check for errors from GameService
        if let error = gameService.beginGameError {
            isBeginningGame = false
            presentLobbyNotice(LobbyNotice(
                title: "Can't begin game",
                message: error,
                primaryAction: lobbyAction(from: gameService.beginGameErrorAction)
            ))
            print("❌ Begin game error: \(error)")
        } else {
            // Give a small delay for state to update (Firestore operations are async)
            Task { @MainActor in
                // Wait a brief moment for state to propagate
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                print("   After beginGame, gameState: \(gameService.gameState)")
                // Verify game actually started
                // Note: CTF can go to .flagPlacement instead of .active
                let expectedStates: [GameState] = [.active, .flagPlacement]
                if !expectedStates.contains(gameService.gameState) {
                    isBeginningGame = false
                    let error = "Game failed to start. Current state: \(gameService.gameState). Please try again."
                    presentLobbyMessage(error, title: "Can't begin game")
                    print("❌ \(error)")
                } else {
                    print("✅ Game started successfully - state: \(gameService.gameState)")
                    // Reset flag after successful start (with additional delay to prevent rapid re-clicks)
                    try? await Task.sleep(nanoseconds: 400_000_000) // 0.4 more seconds
                    isBeginningGame = false
                }
            }
        }
    }
    
    private func handlePlayerEliminated() {
        // Message is set by GameService, just show the alert
        guard let game = _gameService, let message = game.lastEliminationMessage else { return }
        gameOverMessage = message
        showGameOverAlert = true
    }
    
    func playAgain() {
        _gameService?.playAgain()
    }
    
    private func handleGameOver() {
        guard let game = _gameService, game.session != nil else { return }
        // Full game-end UI (Manhunt / Zombie / CTF) already covers outcomes including time's up.
        // Do not show the generic ContentView `.alert` on top of that.
        game.endGame()
    }
    
    // MARK: - Join Game
    
    func joinGame(joinCode: String) {
        // Ensure services are initialized (sync version for immediate use)
        ensureServicesInitializedSync()

        guard locationService.isReadyForGameplay else {
            requestRequiredPreGamePermissions()
            presentToast("Finish the two-step location setup before joining a game.", type: .warning)
            return
        }
        requestBluetoothPermissionIfNeeded()
        
        // Validate join code format (6 digits)
        let cleanedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedCode.count == 6, cleanedCode.allSatisfy({ $0.isNumber }) else {
            joinCodeError = .invalidFormat
            return
        }

        // Clear any previous inline error and set loading state
        joinCodeError = nil
        isJoiningGame = true

        // Request location and wait briefly if permission is already granted but GPS is still warming up.
        let location = locationService
        let startJoin: (CLLocationCoordinate2D) -> Void = { [weak self] coordinate in
            guard let self else { return }
            self.joinGameCancellable?.cancel()
            self.joinGameCancellable = nil

            Task {
                let playerId: String
                do {
                    playerId = try await AuthService.shared.ensureSignedIn()
                } catch {
                    await MainActor.run {
                        self.isJoiningGame = false
                        self.presentToast("Sign-in failed. Check your connection and try again.", type: .error)
                    }
                    return
                }

                let profileName = ProfileService.shared.displayName
                let nameToUse = profileName.isEmpty ? self.playerName : profileName

                let (success, errorMessage) = await self.gameService.joinGame(
                    joinCode: cleanedCode,
                    playerName: nameToUse,
                    playerLocation: coordinate,
                    expectedGameType: self.selectedGameType,
                    playerId: playerId
                )

                await MainActor.run {
                    self.isJoiningGame = false

                    if !success {
                        let raw = errorMessage ?? "Could not join game. Make sure the join code is correct and the game hasn't started yet."
                        self.reportJoinFailure(raw)
                    }
                }
            }
        }

        if let coordinate = location.coordinate {
            startJoin(coordinate)
            return
        }

        location.requestPermission()
        requestBluetoothPermissionIfNeeded()
        joinGameCancellable?.cancel()
        joinGameCancellable = location.$coordinate
            .compactMap { $0 }
            .first()
            .sink { coordinate in
                startJoin(coordinate)
            }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if isJoiningGame && location.coordinate == nil {
                joinGameCancellable?.cancel()
                joinGameCancellable = nil
                isJoiningGame = false
                presentToast("GPS has not found you yet. Move somewhere with a clearer signal and try again.", type: .warning)
            }
        }
    }
}
