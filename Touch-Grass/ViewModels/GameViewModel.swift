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
    @Published var showGameOverAlert = false
    @Published var gameOverMessage = ""
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
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func createSession() {
        guard locationService.isReadyForGameplay else {
            requestRequiredPreGamePermissions()
            gameOverMessage = "Finish the two-step location setup before creating a game."
            showGameOverAlert = true
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
                self.gameOverMessage = "Cannot create game: Sign-in failed. Please check your connection and try again."
                self.showGameOverAlert = true
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
                        gameOverMessage = "Location is allowed, but GPS has not found you yet. Move somewhere with a clearer signal and try again."
                        showGameOverAlert = true
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
            gameOverMessage = "Cannot configure game: Location not available. Please ensure GPS is enabled."
            showGameOverAlert = true
            return
        }
        
        // Validate coordinate
        guard center.latitude.isFinite && center.longitude.isFinite,
              center.latitude >= -90 && center.latitude <= 90,
              center.longitude >= -180 && center.longitude <= 180 else {
            gameOverMessage = "Invalid location coordinates. Please try again."
            showGameOverAlert = true
            return
        }
        
        // Validate bubble parameters
        guard bubbleStartRadius > 0 && bubbleStartRadius.isFinite else {
            gameOverMessage = "Invalid bubble settings: Start radius must be greater than 0."
            showGameOverAlert = true
            return
        }
        
        guard bubbleStartRadius <= 10000 else {
            gameOverMessage = "Bubble radius is too large. Maximum is 10,000 meters."
            showGameOverAlert = true
            return
        }
        
        // Validate duration only if provided (CTF doesn't use duration)
        if let duration = duration {
            guard duration > 0 && duration.isFinite else {
                gameOverMessage = "Invalid game duration: Duration must be greater than 0 seconds."
                showGameOverAlert = true
                return
            }
            
            guard duration <= 7200 else {
                gameOverMessage = "Game duration is too long. Maximum is 7200 seconds (2 hours)."
                showGameOverAlert = true
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
            gameOverMessage = "Hunter count must be at least \(minHunterCount)."
            showGameOverAlert = true
            return
        }
        
        guard hunterCount <= maxPlayers else {
            gameOverMessage = "Hunter count must be less than or equal to the number of players (\(maxPlayers))."
            showGameOverAlert = true
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
            gameOverMessage = "Cannot begin game: No session exists."
            showGameOverAlert = true
            return
        }
        
        guard session.bubble != nil else {
            isBeginningGame = false
            gameOverMessage = "Cannot begin game: Game settings not configured. Please configure the bubble first."
            showGameOverAlert = true
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
            gameOverMessage = "Cannot begin game: Need at least \(vmMinPlayers) player(s) to start. Currently \(session.players.count)."
            showGameOverAlert = true
            return
        }
        
        guard session.hunterCount >= vmMinHunters else {
            isBeginningGame = false
            gameOverMessage = "Cannot begin game: Need at least \(vmMinHunters) hunter(s)."
            showGameOverAlert = true
            return
        }
        
        let hiderCount = session.players.count - session.hunterCount
        guard hiderCount >= vmMinHiders else {
            isBeginningGame = false
            gameOverMessage = "Cannot begin game: Need at least \(vmMinHiders) hider(s). Currently \(hiderCount)."
            showGameOverAlert = true
            return
        }
        
        // Check if current player is the host
        guard let currentPlayer = gameService.currentPlayer,
              currentPlayer.id == session.hostId else {
            isBeginningGame = false
            gameOverMessage = "Only the host can begin the game."
            showGameOverAlert = true
            return
        }
        
        // GameService.beginGame will reset the bubble start time
        print("🎮 GameViewModel.beginGame called")
        print("   Session exists: \(gameService.session != nil)")
        print("   Bubble exists: \(gameService.session?.bubble != nil)")
        print("   Current player is host: \(gameService.currentPlayer?.id == session.hostId)")
        print("   Current gameState: \(gameService.gameState)")
        
        gameService.beginGame()
        
        // Check for errors from GameService
        if let error = gameService.beginGameError {
            isBeginningGame = false
            gameOverMessage = error
            showGameOverAlert = true
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
                    gameOverMessage = error
                    showGameOverAlert = true
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
        guard let game = _gameService, let session = game.session else { return }
        
        let now = Date()
        let elapsed = session.bubble.map { now.timeIntervalSince($0.startTime) } ?? 0
        
        // Determine game over reason
        if let bubble = session.bubble, abs(elapsed) >= bubble.duration {
            gameOverMessage = "⏰ Time's up! Game over."
        } else {
            let hiders = session.players.filter { $0.role == .hider }
            let aliveHiders = hiders.filter { $0.isAlive }
            
            if hiders.count > 0 && aliveHiders.isEmpty {
                // Hunter wins
                if let currentPlayer = game.currentPlayer, currentPlayer.role == .hunter {
                    gameOverMessage = "🎯 Victory! All hiders caught!"
                } else {
                    gameOverMessage = "Game over! All hiders were caught."
                }
            } else {
                // All eliminated or other condition
                let alivePlayers = session.players.filter { $0.isAlive }
                if alivePlayers.isEmpty {
                    gameOverMessage = "Game over! All players eliminated."
                } else if let currentPlayer = game.currentPlayer, !currentPlayer.isAlive {
                    gameOverMessage = "You were eliminated! Game over."
                } else {
                    gameOverMessage = "Game over!"
                }
            }
        }
        
        showGameOverAlert = true
        game.endGame()
    }
    
    // MARK: - Join Game
    
    func joinGame(joinCode: String) {
        // Ensure services are initialized (sync version for immediate use)
        ensureServicesInitializedSync()

        guard locationService.isReadyForGameplay else {
            requestRequiredPreGamePermissions()
            gameOverMessage = "Finish the two-step location setup before joining a game."
            showGameOverAlert = true
            return
        }
        requestBluetoothPermissionIfNeeded()
        
        // Validate join code format (6 digits)
        let cleanedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedCode.count == 6, cleanedCode.allSatisfy({ $0.isNumber }) else {
            gameOverMessage = "Invalid join code. Please enter a 6-digit code."
            showGameOverAlert = true
            return
        }

        // Set loading state
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
                        self.gameOverMessage = "Cannot join game: Sign-in failed. Please check your connection and try again."
                        self.showGameOverAlert = true
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
                        self.gameOverMessage = errorMessage ?? "Could not join game. Make sure the join code is correct and the game hasn't started yet."
                        self.showGameOverAlert = true
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
                gameOverMessage = "Location is allowed, but GPS has not found you yet. Move somewhere with a clearer signal and try again."
                showGameOverAlert = true
            }
        }
    }
}
