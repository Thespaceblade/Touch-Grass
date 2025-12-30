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
    @Published var gameOverAlertAction: AlertAction? = nil
    @Published var selectedGameType: GameType = .manhunt // Track selected game type
    @Published var isBeginningGame: Bool = false // Prevent multiple simultaneous beginGame calls
    
    // Error alert action type
    enum AlertAction {
        case openSettings
        case openTeamManagement
        case openSessionSetup
        case dismiss
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var createSessionCancellable: AnyCancellable?
    
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
        // Initialize location service first if not already done
        let location = locationService
        let service = GameService(locationService: location)
        _gameService = service
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
    func ensureServicesInitialized() {
        // Access services to trigger lazy initialization if needed
        // The computed properties handle the initialization logic
        _ = locationService
        _ = gameService
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
        // Ensure services are initialized
        ensureServicesInitialized()
        
        // Use profile name if available, otherwise fall back to playerName
        let profileName = ProfileService.shared.displayName
        let nameToUse = profileName.isEmpty ? playerName : profileName
        
        let location = locationService
        let game = gameService
        
        // Cancel any pending createSession subscription
        createSessionCancellable?.cancel()
        
        // If we already have a coordinate, create session immediately
        if let coordinate = location.coordinate {
            game.createSession(hostName: nameToUse, hostLocation: coordinate, gameType: selectedGameType)
            return
        }
        
        // Otherwise, request permission (this will start location updates when granted)
        location.requestPermission()
        
        // Observe coordinate updates and create session when location becomes available
        // Use a separate cancellable so we can cancel it if createSession is called again
        createSessionCancellable = location.$coordinate
            .compactMap { $0 }
            .first() // Only take the first non-nil coordinate
            .sink { [weak self] coordinate in
                guard let self = self else { return }
                // Only create session if we don't already have one
                if game.session == nil {
                    let profileName = ProfileService.shared.displayName
                    let nameToUse = profileName.isEmpty ? self.playerName : profileName
                    game.createSession(hostName: nameToUse, hostLocation: coordinate, gameType: self.selectedGameType)
                }
            }
    }
    
    // Configure game settings (bubble) but keep in lobby
    func configureGame(bubbleStartRadius: Double, duration: Double? = nil, hunterCount: Int = 1, center: CLLocationCoordinate2D? = nil, scoreLimit: Int? = nil, teamABase: CLLocationCoordinate2D? = nil, teamBBase: CLLocationCoordinate2D? = nil) {
        // Ensure services are initialized
        ensureServicesInitialized()
        
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
            
            guard duration <= 3600 else {
                gameOverMessage = "Game duration is too long. Maximum is 3600 seconds (1 hour)."
                showGameOverAlert = true
                return
            }
        }
        
        // Validate hunter count
        // TEMPORARY: Allow 0 hunters for testing
        let maxPlayers = gameService.session?.players.count ?? 1
        guard hunterCount >= 0 else {
            gameOverMessage = "Hunter count must be at least 0 (testing mode)."
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
        
        // For CTF: No shrinking, no time limit. Use a very large duration and no shrink interval.
        // For other games: Progressive shrinking every 3 minutes, shrinks by 15% of remaining radius
        let shrinkInterval: Double = isCTF ? Double.infinity : 180 // 3 minutes for non-CTF, infinite for CTF
        let gameDuration: Double = duration ?? (isCTF ? Double.infinity : 1800) // Use provided duration or default (CTF = infinite)
        
        // Create bubble with placeholder startTime (will be set when game begins)
        let bubble = Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: bubbleStartRadius,
            startTime: Date(), // Placeholder - will be reset when game actually begins
            shrinkInterval: shrinkInterval,
            duration: gameDuration,
            shrinkHistory: []
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
        
        // Ensure services are initialized
        ensureServicesInitialized()
        
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
        
        // TEMPORARY: Allow 1 player for testing (normally requires 2)
        // Edge case: Must have at least 1 player to start (testing mode)
        guard session.players.count >= 1 else {
            isBeginningGame = false
            gameOverMessage = "Cannot begin game: Need at least 1 player to start. Currently \(session.players.count) player(s)."
            showGameOverAlert = true
            return
        }
        
        // TEMPORARY: Allow 0 hunters for testing (normally requires at least 1)
        // Edge case: Must have at least 0 hunters (testing mode - allows solo play)
        guard session.hunterCount >= 0 else {
            isBeginningGame = false
            gameOverMessage = "Cannot begin game: Invalid hunter count."
            showGameOverAlert = true
            return
        }
        
        // TEMPORARY: Skip hider validation for testing (normally requires at least 1)
        // Edge case: Must have at least 0 hiders (testing mode)
        let hiderCount = session.players.count - session.hunterCount
        guard hiderCount >= 0 else {
            isBeginningGame = false
            gameOverMessage = "Cannot begin game: Invalid player configuration. Currently \(hiderCount) hider(s)."
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
        // Ensure services are initialized
        ensureServicesInitialized()
        
        // Request location permission and start location updates if not already running
        let location = locationService
        if location.coordinate == nil {
            location.requestPermission()
        }
        
        guard let coordinate = location.coordinate else {
            gameOverMessage = "Cannot join game: Location not available. Please ensure GPS is enabled."
            showGameOverAlert = true
            return
        }
        
        // Validate join code format (6 digits)
        let cleanedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedCode.count == 6, cleanedCode.allSatisfy({ $0.isNumber }) else {
            gameOverMessage = "Invalid join code. Please enter a 6-digit code."
            showGameOverAlert = true
            return
        }
        
        Task {
            let (success, errorMessage) = await gameService.joinGame(
                joinCode: cleanedCode,
                playerName: playerName,
                playerLocation: coordinate,
                expectedGameType: selectedGameType
            )
            
            if !success {
                await MainActor.run {
                    gameOverMessage = errorMessage ?? "Could not join game. Make sure the join code is correct and the game hasn't started yet."
                    showGameOverAlert = true
                }
            }
        }
    }
}
