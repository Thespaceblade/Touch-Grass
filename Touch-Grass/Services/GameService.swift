//
//  GameService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import CoreLocation
import Combine
import UserNotifications

@MainActor
final class GameService: ObservableObject {
    // Maximum number of players per session (for testing with friends)
    static let maxPlayersPerSession: Int = 12

    /// True when the local guest device created the lobby. Two devices on
    /// the same Apple ID share a Firebase auth uid; only the device that
    /// originally created the session is the local host.
    func isCurrentPlayerSessionHost() -> Bool {
        guard let session, let currentPlayer else { return false }
        return session.isDeviceHost(currentPlayer)
    }
    
    @Published var session: GameSession?
    @Published var currentPlayer: Player?
    @Published var isOutOfBounds: Bool = false
    /// When a Manhunt hider first leaves the zone, grace starts; UI shows countdown until elimination.
    @Published private(set) var outOfBoundsGraceStartedAt: Date?
    static let outOfBoundsGraceDuration: TimeInterval = 12
    var outOfBoundsGraceRemaining: TimeInterval? {
        guard let started = outOfBoundsGraceStartedAt else { return nil }
        let remaining = Self.outOfBoundsGraceDuration - Date().timeIntervalSince(started)
        return remaining > 0 ? remaining : nil
    }
    @Published var distanceToEdge: Double?
    @Published var warningLevel: WarningLevel = .none
    @Published var caughtPlayers: [String] = [] // IDs of caught players
    @Published var lastEliminationMessage: String? // For UI feedback
    @Published var lastCatchMessage: String? // For UI feedback
    /// Short-lived message shown to the user when a tag request is silently
    /// rejected (out of range, wrong role, missing data, etc.). UI code can
    /// surface this as a toast or banner. Auto-clears 4s after assignment.
    @Published var tagRequestRejectedMessage: String?
    private var tagRequestRejectedClearTask: Task<Void, Never>?
    /// Hunter-facing toast when a hider rejects a BLE tag request.
    @Published var tagDeniedByTargetMessage: String?
    private var tagDeniedByTargetClearTask: Task<Void, Never>?
    let announcementManager = GameAnnouncementManager()
    @Published var shouldEndGame: Bool = false // Game over condition
    /// Non-host devices set this when their local `checkGameOver` decides
    /// the game is over but the authoritative `.ended` transition has not
    /// yet arrived from Firestore. The host owns the terminal write; this
    /// flag lets non-host UI show a "waiting for host" hint without
    /// locally diverging from the server session state.
    @Published var awaitingServerGameEnd: Bool = false
    @Published var winningTeam: Flag.Team? = nil // CTF: Which team won (if game ended)
    
    // Explicit game state tracking for reliable SwiftUI observation
    @Published var gameState: GameState = .lobby
    
    private var updateTimer: Timer?
    private let locationService: LocationService
    private var notificationService: NotificationService {
        NotificationService.shared
    }
    // Firestore is only needed once a real session/network operation begins.
    // Keeping it lazy avoids test/startup crashes in pure init smoke tests.
    private var _firestoreService: FirestoreService?
    private var firestoreService: FirestoreService {
        if let service = _firestoreService {
            return service
        }
        let service = FirestoreService()
        _firestoreService = service
        return service
    }
    private var _bluetoothTagService: BluetoothTagService?
    private var bluetoothTagService: BluetoothTagService {
        if let service = _bluetoothTagService {
            return service
        }
        let service = BluetoothTagService()
        service.onTagRequest = { [weak self] fromPlayerId, fromPlayerName in
            Task { @MainActor in
                self?.handleTagRequest(fromPlayerId: fromPlayerId, fromPlayerName: fromPlayerName)
            }
        }
        service.onTagConfirmed = { [weak self] playerId in
            Task { @MainActor in
                self?.handleTagConfirmed(playerId: playerId)
            }
        }
        service.onTagRejected = { [weak self] rejectorId in
            Task { @MainActor in
                self?.handleTagRejected(byPlayerId: rejectorId)
            }
        }
        _bluetoothTagService = service
        return service
    }
    
    // Location update throttling
    private var lastFirestoreUpdate: Date?
    private let firestoreUpdateInterval: TimeInterval = 5.0 // Update Firestore every 5 seconds max (optimized from 3s for battery)
    private var pendingLocationUpdate: CLLocationCoordinate2D?
    private var lastUpdateCoordinate: CLLocationCoordinate2D?
    private let minUpdateDistance: Double = 5.0 // Only update if moved 5+ meters (battery optimization)
    private let bleConfirmedTagGpsGraceDistance: Double = 40.0
    private var remoteReadySessionId: String?

    /// Active-game heartbeat timer. Bumps the local player's `lastUpdated`
    /// in Firestore on a fixed interval so a stationary hider (or any
    /// player whose coordinates haven't changed enough to trigger a
    /// location sync) doesn't look offline to the rest of the lobby.
    private var presenceHeartbeatTimer: Timer?
    private let presenceHeartbeatInterval: TimeInterval = 15.0
    
    private func print(_ message: String) {
        if message.hasPrefix("❌") {
            Swift.print(message)
        } else {
            DebugLogger.log(message)
        }
    }
    
    // Prevent listener from overwriting our local updates
    private var isUpdatingSession: Bool = false
    private var isStartingGameFromServerSnapshot: Bool = false
    private var isBeginGameRefreshInFlight: Bool = false
    private var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
        NSClassFromString("XCTestCase") != nil ||
        NSClassFromString("XCTest.XCTestCase") != nil
    }
    
    // Game statistics
    @Published var gameStats: GameStats?
    
    // Distance indicators
    @Published var nearestHunterDistance: Double?
    @Published var nearestHiderDistance: Double?
    @Published var nearestHunterDirection: Double? // Bearing in degrees (0-360)
    @Published var nearestHiderDirection: Double? // Bearing in degrees (0-360)
    @Published var nearestHunterId: String? // ID of nearest hunter
    @Published var nearestHiderId: String? // ID of nearest hider

    // MARK: - Predator compass pulse ability (Manhunt hunters / ZT zombies)

    /// True while a compass pulse transaction is in flight. The
    /// `PredatorPulseControl` uses this to keep the spin animation alive
    /// until the commit result lands, then drives the locked needle from
    /// `compassPulseLastResult`.
    @Published var compassPulseInFlight: Bool = false

    /// Outcome of the most recent compass pulse fired from THIS device.
    /// Drives the predator's local result UI. Listener-side announcements
    /// for other clients flow through `announcementManager` instead.
    @Published var compassPulseLastResult: CompassPulseResult?

    /// Dedupe key for HUD announcements. Both the optimistic merge after a
    /// local commit AND the Firestore listener will eventually deliver the
    /// same `eventId`; we want side effects (pills, haptics) to fire at
    /// most once per pulse, regardless of which path arrived first.
    private var lastProcessedCompassEventId: String?

    /// Auto-clear task for `compassPulseLastResult`. Result UI lingers for
    /// ~4s after a successful pulse, then fades back to the ready state.
    private var compassPulseResultClearTask: Task<Void, Never>?

    /// Result the predator's UI binds to after `requestCompassPulse` resolves.
    enum CompassPulseResult: Equatable {
        case success(CompassPulseCommit)
        case noTargets
        case failed
    }
    
    // Proximity warnings (for hiders when hunters are nearby)
    @Published var proximityWarningLevel: ProximityWarningLevel = .none
    @Published var proximityWarningDistance: Double?
    
    enum ProximityWarningLevel {
        case none
        case safe      // > 50m
        case caution   // 20-50m
        case warning   // 10-20m
        case danger    // < 10m
    }
    
    // Visual feedback triggers
    @Published var shouldFlashScreen: Bool = false
    @Published var shouldPulseBubble: Bool = false
    @Published var catchAnimationTrigger: Bool = false
    @Published var eliminationAnimationTrigger: Bool = false
    
    // Network and connection status
    @Published var networkError: String?
    @Published var isConnected: Bool = true
    
        // CTF: Flag phone disconnect tracking
        @Published var flagPhoneDisconnected: [Flag.Team: Bool] = [:] // Track which flag phones are disconnected
        
        // CTF: Flag motion tracking for alerts
        private var flagMotionState: [String: Bool] = [:] // Track flag player ID -> isMoving state
        private var flagLastLocation: [String: CLLocation] = [:] // Track flag player ID -> last known location
        private var lastFlagMotionAlert: [String: Date] = [:] // Track last motion alert time to prevent spam
    
    // BLE tagging
    @Published var canTagPlayerId: String? // Player ID that can be tagged via BLE
    @Published var pendingTagRequest: BluetoothTagService.TagRequest? // Incoming tag request
    
    enum WarningLevel {
        case none
        case safe
        case warning
        case danger
    }
    
    init(locationService: LocationService) {
        self.locationService = locationService
    }

    // MARK: - Post-game profile / achievements

    /// Records local profile stats for the finished game and announces newly unlocked achievements in the map hub.
    /// Staggers one `announcementManager` post per unlock (0.35s apart) so pills stay readable.
    func applyPostGameProfileOutcome(
        session: GameSession,
        gameStats: GameStats,
        currentPlayer: Player?,
        emitToasts: Bool = true
    ) {
        /// Unique per finished match: `gameNumber` only advances on "Play Again", not on "Back to lobby",
        /// so we include the match's start time (stable for that game, distinct across replays in one session).
        let dedupeKey = "\(session.id):\(session.gameNumber):\(gameStats.gameStartTime.timeIntervalSinceReferenceDate)"
        let ids = ProfileService.shared.recordLocalGameOutcome(
            dedupeKey: dedupeKey,
            gameType: session.gameType,
            gameStats: gameStats,
            currentPlayer: currentPlayer,
            duration: gameStats.totalGameDuration(),
            wonOverride: nil
        )
        guard emitToasts, !ids.isEmpty else { return }
        for (index, id) in ids.enumerated() {
            let delay = 0.35 * Double(index)
            let message = AchievementCatalog.toastMessage(for: id)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                self.announcementManager.post(message, type: .achievementUnlocked)
            }
        }
    }
    
    // Expose BLE service for UI
    var bleService: BluetoothTagService {
        bluetoothTagService
    }
    
    func requestBluetoothPermissionIfNeeded() {
        bluetoothTagService.requestPermission()
    }
    
    // Expose Firestore service for UI (needed for flag placement)
    var firestore: FirestoreService {
        firestoreService
    }
    
    // MARK: - Session Commit Pipeline
    //
    // Every lobby mutation (role flip, team change, flag toggle, bubble
    // configure, etc.) goes through `commitLobbySession` so we never push
    // a stale local roster back to Firestore. Without this, the host's
    // local `session.players` (often 1) would overwrite a server roster
    // that already contains the joiner, deleting them - this is the
    // "flip wipe" bug.
    //
    // Active-game callers that need the same protection (notifications,
    // scoreboard updates, etc.) can opt in by passing
    // `requireState: nil`. The roster merge is identical to lobby; only
    // the precondition relaxes.

    enum LobbyCommitError: Error {
        case noSession
        case notHost
        case wrongState
        case serverSessionMissing
    }

    /// Read the latest session from Firestore, let the caller mutate it,
    /// merge the resulting roster against the server snapshot so no
    /// player is ever dropped, then write the merged session back.
    ///
    /// `mutation` is called on a `var` copy of the **server** session.
    /// Callers should change roles/bubble/etc. on the players or fields
    /// of that copy; they should not rebuild `players` from local state.
    ///
    /// On success, `self.session` and `self.currentPlayer` are updated
    /// from the committed result so the UI reflects the same source of
    /// truth Firestore now has.
    @discardableResult
    func commitLobbySession(
        requireHost: Bool = true,
        requireState: GameState? = .lobby,
        _ mutation: (inout GameSession) -> Void
    ) async throws -> GameSession {
        guard let localSession = session else {
            throw LobbyCommitError.noSession
        }
        if requireHost, !isCurrentPlayerSessionHost() {
            throw LobbyCommitError.notHost
        }

        let serverSession: GameSession
        do {
            guard let fetched = try await firestoreService.fetchSession(sessionId: localSession.id) else {
                throw LobbyCommitError.serverSessionMissing
            }
            serverSession = fetched
        } catch let error as LobbyCommitError {
            throw error
        } catch {
            // Network/decode error: bubble up so callers can surface it.
            throw error
        }

        if let requiredState = requireState, serverSession.gameState != requiredState {
            throw LobbyCommitError.wrongState
        }

        var working = serverSession
        let serverPlayers = serverSession.players
        mutation(&working)
        working.players = LobbyRosterMerge.merge(server: serverPlayers, mutated: working.players)

        try await firestoreService.updateSession(working)

        self.session = working
        self.gameState = working.gameState
        if let localId = currentPlayer?.id,
           let refreshed = working.players.first(where: { $0.id == localId }) {
            self.currentPlayer = refreshed
        }

        return working
    }

    /// Fire-and-forget wrapper for call sites that cannot easily become
    /// async (SwiftUI button actions, etc.). Errors are routed to
    /// `networkError` so the lobby UI can surface them.
    ///
    /// When `optimisticLocalUpdate` is true (the default), the mutation
    /// is also applied to the in-memory `self.session` immediately so
    /// the UI reflects the change without waiting for the Firestore
    /// round-trip. The authoritative commit (read-merge-write) still
    /// runs in the background and reconciles via the listener.
    func commitLobbySessionInBackground(
        requireHost: Bool = true,
        requireState: GameState? = .lobby,
        optimisticLocalUpdate: Bool = true,
        onSuccess: (() -> Void)? = nil,
        _ mutation: @escaping (inout GameSession) -> Void
    ) {
        if optimisticLocalUpdate, var local = self.session {
            mutation(&local)
            self.session = local
            self.gameState = local.gameState
            if let localId = self.currentPlayer?.id,
               let refreshed = local.players.first(where: { $0.id == localId }) {
                self.currentPlayer = refreshed
            }
        }

        if isRunningUnitTests {
            onSuccess?()
            return
        }

        Task { @MainActor in
            do {
                _ = try await commitLobbySession(
                    requireHost: requireHost,
                    requireState: requireState,
                    mutation
                )
                onSuccess?()
            } catch LobbyCommitError.notHost {
                print("❌ Lobby commit blocked: not host")
            } catch LobbyCommitError.wrongState {
                print("❌ Lobby commit blocked: game state no longer eligible")
            } catch LobbyCommitError.noSession {
                print("❌ Lobby commit blocked: no local session")
            } catch LobbyCommitError.serverSessionMissing {
                print("❌ Lobby commit blocked: server session missing")
                networkError = "Lobby is no longer available."
            } catch {
                print("❌ Lobby commit failed: \(error.localizedDescription)")
                networkError = "Couldn't sync change. Check your connection."
            }
        }
    }

    // MARK: - Session Management
    
    func createSession(hostName: String, hostLocation: CLLocationCoordinate2D, gameType: GameType = .manhunt, playerId: String? = nil) {
        guard AppReleaseConfiguration.isGameModeAvailable(gameType) else {
            print("❌ Cannot create session: \(gameType.rawValue) is not available in this release")
            networkError = AppReleaseConfiguration.unavailableGameModeMessage
            return
        }

        // Validate host location
        guard isValidCoordinate(hostLocation) else {
            print("❌ Cannot create session: invalid host location")
            return
        }
        
        // Validate host name (sanitize)
        let sanitizedName = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedName.isEmpty || !ProfileService.shared.displayName.isEmpty else {
            print("❌ Cannot create session: host name is empty")
            return
        }
        
        // Get profile picture from ProfileService
        let profileService = ProfileService.shared
        
        // Determine initial role based on game type
        let initialRole: PlayerRole
        if gameType == .zombieTag {
            initialRole = .human // Start as human in zombie tag
        } else if gameType == .captureTheFlag {
            initialRole = .teamA // Start as Team A for CTF (will be balanced when game starts)
        } else {
            initialRole = .hider // Default to hider for manhunt
        }
        
        let authUid = playerId ?? AuthService.shared.currentUserIdForLocalOperation()
        let guestDeviceId = AuthService.shared.guestDeviceId
        let host = Player(
            id: guestDeviceId,
            displayName: sanitizedName.isEmpty ? profileService.displayName : sanitizedName,
            latitude: hostLocation.latitude,
            longitude: hostLocation.longitude,
            role: initialRole,
            isAlive: true,
            profilePictureBase64: profileService.getProfilePictureBase64(),
            authUserId: authUid,
            deviceInstallationId: guestDeviceId
        )
        
        let newSession = GameSession(
            hostId: authUid,
            hostPlayerId: guestDeviceId,
            hostAuthUid: authUid,
            gameState: .lobby,
            gameType: gameType,
            players: [host],
            hunterCount: 1, // Default to 1 hunter (or 1 zombie for zombie tag)
            flags: [],
            teamAScore: 0,
            teamBScore: 0,
            teamABase: nil,
            teamBBase: nil,
            scoreLimit: 0 // Not used - CTF win condition is both flags in same safe zone
        )
        
        session = newSession
        gameState = .lobby  // Update explicit state
        currentPlayer = host
        saveResumeSnapshot(for: newSession, localPlayerId: host.id, force: true)

        print("✅ Session created: \(newSession.id)")
        print("✅ Join code: \(newSession.joinCode)")
        print("✅ Game state set to: \(gameState)")

        if isRunningUnitTests {
            isConnected = true
            networkError = nil
            remoteReadySessionId = newSession.id
            return
        }
        
        // Save to Firestore before attaching the listener. Listening to a
        // not-yet-created document can be denied by security rules, and a
        // permission-denied listener will not recover when the write lands.
        Task {
            do {
                try await firestoreService.createSession(newSession)
                guard self.session?.id == newSession.id else { return }
                isConnected = true
                networkError = nil
                startSessionListener(newSession.id)
            } catch {
                print("❌ Error creating session in Firestore: \(error)")
                if self.session?.id == newSession.id {
                    GuestSessionStore.shared.clear(reason: "create-session-failed")
                    resetLocalGameState()
                }
                networkError = "Failed to create session. Check internet connection."
                isConnected = false
            }
        }
    }
    
    // Validate bubble parameters
    private func validateBubble(_ bubble: Bubble) -> Bool {
        guard bubble.startRadius > 0 && bubble.startRadius.isFinite else {
            return false
        }
        guard bubble.startRadius <= 10000 else { // Max 10km radius
            return false
        }
        guard isValidCoordinate(CLLocationCoordinate2D(latitude: bubble.centerLatitude, longitude: bubble.centerLongitude)) else {
            return false
        }
        // Duration can be infinite (no time limit) for any game type
        // For CTF: both duration and shrinkInterval are infinite (no shrinking, no time limit)
        // For other games with infinite duration: shrinkInterval is still finite (zones still shrink)
        if bubble.duration.isInfinite {
            // Infinite duration means no time limit - zones can still shrink
            // Only CTF requires shrinkInterval to also be infinite (no shrinking)
            // For Manhunt/ZombieTag with infinite duration, shrinkInterval should be finite
            if bubble.shrinkInterval.isInfinite {
                // This is valid for CTF (no time limit, no shrinking)
            } else {
                // This is valid for Manhunt/ZombieTag (no time limit, but zones shrink)
                guard bubble.shrinkInterval > 0 && bubble.shrinkInterval.isFinite else {
                    return false
                }
            }
        } else {
            // Finite duration validation
            guard bubble.duration > 0 && bubble.duration.isFinite else {
                return false
            }
            guard bubble.duration <= 7200 else { // Max 2 hours
                return false
            }
            guard bubble.shrinkInterval > 0 && bubble.shrinkInterval.isFinite else {
                return false
            }
        }
        return true
    }
    
    // Configure game settings (bubble) but keep in lobby state
    func configureGame(bubble: Bubble, hunterCount: Int? = nil, scoreLimit: Int? = nil, teamABase: CLLocationCoordinate2D? = nil, teamBBase: CLLocationCoordinate2D? = nil) {
        guard let session = session else { return }
        guard session.gameState == .lobby else {
            print("❌ Cannot configure game: game is no longer in the lobby")
            return
        }
        guard isCurrentPlayerSessionHost() else {
            print("❌ Only host can configure game settings")
            return
        }

        // Note: scoreLimit parameter is ignored - CTF win condition is both flags in same safe zone

        guard validateBubble(bubble) else {
            print("❌ Bubble validation failed:")
            print("   - Duration: \(bubble.duration) (isInfinite: \(bubble.duration.isInfinite))")
            print("   - ShrinkInterval: \(bubble.shrinkInterval) (isInfinite: \(bubble.shrinkInterval.isInfinite))")
            print("   - StartRadius: \(bubble.startRadius)")
            print("   - Center: (\(bubble.centerLatitude), \(bubble.centerLongitude))")
            return
        }
        print("✅ Bubble validation passed")

        // We validate hunterCount against the server roster inside the
        // commit closure (the authoritative `players.count`), but check
        // it against the local copy here to short-circuit obviously
        // invalid input before a Firestore round-trip.
        if let hunterCount = hunterCount {
            #if DEBUG
            guard hunterCount >= 0 else { return }
            #else
            guard hunterCount >= 1 else { return }
            #endif
            guard hunterCount <= session.players.count else {
                print("❌ Invalid hunter count: \(hunterCount) (must be <= \(session.players.count) players)")
                return
            }
        }

        print("⚙️ GameService.configureGame called")
        print("   Current state: \(session.gameState)")
        print("   Game type: \(session.gameType.rawValue)")

        commitLobbySessionInBackground { session in
            if session.gameType == .captureTheFlag {
                if let teamABase = teamABase, let teamBBase = teamBBase {
                    session.teamABase = teamABase
                    session.teamBBase = teamBBase
                    Swift.print("   Team bases set: A at \(teamABase.latitude), \(teamABase.longitude), B at \(teamBBase.latitude), \(teamBBase.longitude)")
                } else {
                    let center = bubble.currentCenter()
                    let radius = bubble.currentRadius()
                    let baseOffset: Double = radius * 0.4
                    let teamABaseCoord = CLLocationCoordinate2D(
                        latitude: center.latitude + baseOffset / 111000.0,
                        longitude: center.longitude
                    )
                    let teamBBaseCoord = CLLocationCoordinate2D(
                        latitude: center.latitude - baseOffset / 111000.0,
                        longitude: center.longitude
                    )
                    session.teamABase = teamABaseCoord
                    session.teamBBase = teamBBaseCoord
                    Swift.print("   Team bases auto-positioned: A at \(teamABaseCoord.latitude), \(teamABaseCoord.longitude), B at \(teamBBaseCoord.latitude), \(teamBBaseCoord.longitude)")
                }
            }

            session.bubble = bubble
            if let hunterCount = hunterCount, hunterCount <= session.players.count {
                session.hunterCount = hunterCount
                Swift.print("   Hunter count updated to: \(hunterCount)")
            }

            Swift.print("✅ Bubble configured: \(bubble.centerLatitude), \(bubble.centerLongitude)")
            Swift.print("✅ Bubble radius: \(bubble.currentRadius(at: Date()))m")
            Swift.print("✅ Bubble set on session: \(session.bubble != nil ? "YES" : "NO")")
            Swift.print("✅ Game remains in lobby state")
        }
    }
    
    // Actually begin the game (transition from lobby to active)
    // Published error message for UI
    @Published var beginGameError: String?
    @Published var beginGameErrorAction: BeginGameErrorAction? = nil
    
    // Error action type for begin game errors
    enum BeginGameErrorAction {
        case openSettings
        case openTeamManagement
        case openSessionSetup
        case dismiss
    }
    
    func beginGame() {
        // Clear any previous error
        beginGameError = nil
        beginGameErrorAction = nil
        
        print("🎮 GameService.beginGame() called")
        
        guard var session = session else {
            let error = "Cannot begin game: No session exists. Please create a session first."
            print("❌ \(error)")
            beginGameError = error
            beginGameErrorAction = .openSessionSetup
            // Ensure game state stays in lobby
            if gameState != .lobby {
                gameState = .lobby
            }
            return
        }
        
        print("   📊 Session info:")
        print("      - Game type: \(session.gameType.rawValue)")
        print("      - Players: \(session.players.count)")
        print("      - Hunter count: \(session.hunterCount)")
        print("      - Bubble configured: \(session.bubble != nil)")

        guard isCurrentPlayerSessionHost() else {
            let error = "Only the host can begin the game."
            print("❌ \(error)")
            beginGameError = error
            beginGameErrorAction = .dismiss
            if gameState != .lobby {
                gameState = .lobby
            }
            return
        }

        guard session.gameState == .lobby else {
            let error = "Cannot begin game: this session is already \(session.gameState.rawValue)."
            print("❌ \(error)")
            beginGameError = error
            beginGameErrorAction = .dismiss
            return
        }

        let shouldRefreshBeforeBegin = !isRunningUnitTests

        if shouldRefreshBeforeBegin && isBeginGameRefreshInFlight {
            print("⏳ Begin game already refreshing latest lobby snapshot")
            return
        }

        if shouldRefreshBeforeBegin && !isStartingGameFromServerSnapshot {
            isBeginGameRefreshInFlight = true
            Task { @MainActor in
                defer { self.isBeginGameRefreshInFlight = false }
                do {
                    guard let serverSession = try await firestoreService.fetchSession(sessionId: session.id) else {
                        beginGameError = "Cannot begin game: this lobby no longer exists."
                        beginGameErrorAction = .dismiss
                        return
                    }
                    self.session = serverSession
                    self.gameState = serverSession.gameState
                    if let localPlayerId = currentPlayer?.id,
                       let refreshed = serverSession.players.first(where: { $0.id == localPlayerId }) {
                        currentPlayer = refreshed
                    }
                    self.isStartingGameFromServerSnapshot = true
                    beginGame()
                    self.isStartingGameFromServerSnapshot = false
                } catch {
                    self.isStartingGameFromServerSnapshot = false
                    print("❌ Error refreshing lobby before begin game: \(error.localizedDescription)")
                    beginGameError = "Couldn't refresh the lobby. Check your connection and try again."
                    beginGameErrorAction = .dismiss
                    networkError = "Couldn't refresh the lobby. Check your connection and try again."
                    isConnected = false
                }
            }
            return
        }
        
        // CTF-specific validation
        if session.gameType == .captureTheFlag {
            // CTF requires at least 2 players
            guard session.players.count >= 2 else {
                let error = "Capture The Flag requires at least 2 players. Currently \(session.players.count) player(s)."
                print("❌ \(error)")
                beginGameError = error
                beginGameErrorAction = .openSessionSetup
                if gameState != .lobby {
                    gameState = .lobby
                }
                return
            }
            
            // Check that both teams have players
            let teamACount = session.players.filter { $0.team == .teamA }.count
            let teamBCount = session.players.filter { $0.team == .teamB }.count
            
            guard teamACount > 0 && teamBCount > 0 else {
                let error = "Both teams need at least 1 player. Team A: \(teamACount), Team B: \(teamBCount)."
                print("❌ \(error)")
                beginGameError = error
                beginGameErrorAction = .openTeamManagement
                if gameState != .lobby {
                    gameState = .lobby
                }
                return
            }
            
            // Check that team bases are set
            guard session.teamABase != nil && session.teamBBase != nil else {
                let error = "Team bases must be configured. Please set Team A and Team B base locations in settings."
                print("❌ \(error)")
                beginGameError = error
                beginGameErrorAction = .openSettings
                if gameState != .lobby {
                    gameState = .lobby
                }
                return
            }
            
            // Check flag players if any are designated
            let teamAFlag = session.players.first { $0.team == .teamA && $0.isFlag }
            let teamBFlag = session.players.first { $0.team == .teamB && $0.isFlag }
            
            // If one team has a flag player, both must have one
            if (teamAFlag != nil && teamBFlag == nil) || (teamAFlag == nil && teamBFlag != nil) {
                let error = "Both teams must have a flag player designated, or neither team. Please designate flag players in Team Management."
                print("❌ \(error)")
                beginGameError = error
                beginGameErrorAction = .openTeamManagement
                if gameState != .lobby {
                    gameState = .lobby
                }
                return
            }
        } else {
            #if DEBUG
            let minPlayers = 1
            #else
            let minPlayers = session.gameType.minimumPlayers
            #endif
            guard session.players.count >= minPlayers else {
                let error = "Cannot begin game: Need at least \(minPlayers) player(s) to start. Currently \(session.players.count) player(s)."
                print("❌ \(error)")
                beginGameError = error
                beginGameErrorAction = .openSessionSetup
                if gameState != .lobby {
                    gameState = .lobby
                }
                return
            }
        }
        
        #if DEBUG
        let minHunters = 0
        #else
        let minHunters = 1
        #endif
        print("   🔍 Validation: hunterCount = \(session.hunterCount)")
        guard session.hunterCount >= minHunters else {
            let error = "Cannot begin game: Need at least \(minHunters) hunter(s). Currently \(session.hunterCount)."
            print("❌ \(error)")
            beginGameError = error
            if gameState != .lobby {
                gameState = .lobby
            }
            return
        }
        print("   ✅ Hunter count validation passed: \(session.hunterCount)")
        
        if session.gameType != .captureTheFlag {
            let hiderCount = session.players.count - session.hunterCount
            print("   🔍 Validation: \(session.players.count) players - \(session.hunterCount) hunters = \(hiderCount) hiders")
            #if DEBUG
            let minHiders = 0
            #else
            let minHiders = 1
            #endif
            guard hiderCount >= minHiders else {
                let error = "Cannot begin game: Need at least \(minHiders) hider(s). Currently \(hiderCount)."
                print("❌ \(error)")
                beginGameError = error
                if gameState != .lobby {
                    gameState = .lobby
                }
                return
            }
            print("   ✅ Hider count validation passed: \(hiderCount) hiders")
        }
        
        // CTF doesn't strictly require bubble (uses bases), but create one if missing
        if session.gameType == .captureTheFlag && session.bubble == nil {
            // Create a default bubble centered on first player for zone boundaries
            if let firstPlayer = session.players.first {
                let defaultBubble = Bubble(
                    centerLatitude: firstPlayer.latitude,
                    centerLongitude: firstPlayer.longitude,
                    startRadius: 500, // 500m default
                    startTime: Date(),
                    shrinkInterval: 300, // 5 minutes
                    duration: 1800, // 30 minutes
                    shrinkHistory: []
                )
                session.bubble = defaultBubble
                print("🚩 Created default bubble for CTF")
            }
        }
        
        guard var bubble = session.bubble else {
            let error = "Cannot begin game: Game settings (bubble) not configured. Please configure the game settings first by tapping the settings button."
            print("❌ \(error)")
            beginGameError = error
            beginGameErrorAction = .openSettings
            // Ensure game state stays in lobby
            if gameState != .lobby {
                gameState = .lobby
            }
            return
        }
        
        // Manhunt / Zombie Tag: the lobby UI shows a countdown after `gameState` becomes `.active`,
        // but `startUpdateTimer()` already runs `checkGameOver()`. `configureGame` uses a real
        // `Date()` for `bubble.startTime`, so "elapsed" would include lobby + countdown and can
        // exceed `duration` before `startGameTimer()` commits the real match start — instant false "time's up".
        if session.gameType == .manhunt || session.gameType == .zombieTag {
            bubble.startTime = Date.distantFuture
        }
        
        print("🎮 GameService.beginGame called")
        print("   Current state: \(session.gameState)")
        print("   Game type: \(session.gameType.rawValue)")
        print("   Game number: \(session.gameNumber)")
        print("   Hunter count: \(session.hunterCount)")
        print("   Total players: \(session.players.count)")

        let preBeginSession = self.session
        
        // Assign roles based on game type
        if session.gameType == .zombieTag {
            // Zombie Tag: Assign one random zombie, rest are humans
            assignZombieTagRoles(session: &session)
        } else if session.gameType == .captureTheFlag {
            // CTF: Assign teams and initialize flags
            assignCTFTeams(session: &session)
            initializeCTFFlags(session: &session)
        } else {
            // Manhunt: Assign hunters based on game number
        if session.gameNumber == 1 {
            // First game: Randomly assign hunters
            assignRandomHunters(session: &session, count: session.hunterCount)
        } else {
            // Subsequent games: First tagged player becomes hunter
            assignHuntersFromFirstTagged(session: &session, count: session.hunterCount)
            }
        }
        
        // `bubble.startTime` is `Date.distantFuture` for Manhunt/Zombie until the host's
        // countdown finishes and `startGameTimer()` commits the real match start.
        session.bubble = bubble
        
        session.endReason = nil

        // CTF: Set game state to flag placement if flags need to be placed
        if session.gameType == .captureTheFlag {
            // Reset safe zones for new game
            session.teamASafeZone = nil
            session.teamBSafeZone = nil
            
            // Check if both flag players exist
            let teamAFlag = session.players.first { $0.team == .teamA && $0.isFlag }
            let teamBFlag = session.players.first { $0.team == .teamB && $0.isFlag }
            
            if teamAFlag != nil && teamBFlag != nil {
                // Reset flag placement status
                session.teamAFlagPlaced = false
                session.teamBFlagPlaced = false
                session.gameState = .flagPlacement
            } else {
                // No flag players - go straight to active
        session.gameState = .active
            }
        } else {
            session.gameState = .active
        }
        
        // Reset game state
        shouldEndGame = false
        awaitingServerGameEnd = false
        winningTeam = nil
        lastEliminationMessage = nil
        lastCatchMessage = nil
        caughtPlayers = []
        flagPhoneDisconnected = [:] // Reset flag phone disconnect status
        nearestHunterDistance = nil
        nearestHiderDistance = nil
        nearestHunterDirection = nil
        nearestHiderDirection = nil
        nearestHunterId = nil
        nearestHiderId = nil
        canTagPlayerId = nil
        pendingTagRequest = nil
        
        // Initialize game stats
        gameStats = GameStats(gameStartTime: Date())
        
        if session.gameType == .captureTheFlag {
            Task {
                _ = await notificationService.requestPermission()
            }
        }
        
        // Start BLE tagging service (only for Manhunt and ZombieTag, not CTF)
        // CTF doesn't use BLE tagging since only flags are tracked on the map
        if session.gameType != .captureTheFlag,
           let playerId = currentPlayer?.id, let playerName = currentPlayer?.displayName {
            bluetoothTagService.start(playerId: playerId, playerName: playerName)
        }
        
        // Update both session and explicit gameState
        // Set flag to prevent listener from overwriting
        isUpdatingSession = true
        
        // Update state synchronously first to ensure UI reacts immediately
        self.session = session
        self.gameState = session.gameState  // Use session's gameState (may be .flagPlacement for CTF)
        
        // Update current player if their role changed
        if let playerId = currentPlayer?.id,
           let updatedPlayer = session.players.first(where: { $0.id == playerId }) {
            currentPlayer = updatedPlayer
        }
        
        // For CTF without flag players (goes straight to active), start the timer now
        if session.gameType == .captureTheFlag && session.gameState == .active {
            // Check if bubble.startTime hasn't been set yet (it will be nil/old)
            if var updatedBubble = session.bubble {
                updatedBubble.startTime = Date()
                session.bubble = updatedBubble
                self.session = session
                print("⏱️ CTF game timer started (no flag placement, bubble.startTime set to: \(updatedBubble.startTime))")
            }
        }
        
        print("✅ Game state changed to: \(self.gameState)")
        print("✅ Session gameState: \(session.gameState)")
        if let bubble = session.bubble {
            print("✅ Bubble start time: \(bubble.startTime)")
        }
        print("✅ Hunters assigned: \(session.players.filter { $0.role == .hunter }.map { $0.displayName })")
        
        // Force UI update on main thread immediately
        Task { @MainActor in
            print("✅ Task: Verifying state is \(self.gameState)")
            print("✅ Task: Session state is \(self.session?.gameState.rawValue ?? "nil")")
        }
        
        if isRunningUnitTests {
            isUpdatingSession = false
            startUpdateTimer()
            return
        }

        // Sync to Firestore (async, but state is already updated above)
        Task {
            do {
                try await firestoreService.updateSession(session)
                // Clear flag after Firestore update completes
                await MainActor.run {
                    self.isUpdatingSession = false
                    print("✅ Firestore update complete, listener re-enabled")
                }
            } catch {
                print("❌ Error updating session in Firestore: \(error)")
                let refreshedSession = try? await firestoreService.fetchSession(sessionId: session.id)
                // Clear flag even on error, but keep the state change
                await MainActor.run {
                    self.isUpdatingSession = false
                    if let refreshedSession {
                        self.session = refreshedSession
                        self.gameState = refreshedSession.gameState
                        if let playerId = self.currentPlayer?.id,
                           let refreshedPlayer = refreshedSession.players.first(where: { $0.id == playerId }) {
                            self.currentPlayer = refreshedPlayer
                        }
                    } else if self.session?.id == session.id, let preBeginSession {
                        self.session = preBeginSession
                        self.gameState = preBeginSession.gameState
                        if let playerId = self.currentPlayer?.id,
                           let previousPlayer = preBeginSession.players.first(where: { $0.id == playerId }) {
                            self.currentPlayer = previousPlayer
                        }
                    }
                    self.networkError = "Couldn't start the game. Check your connection and try again."
                    self.isConnected = false
                }
            }
        }
        
        startUpdateTimer()
    }
    
    // MARK: - Role Assignment
    
    // Assign roles for Zombie Tag (one zombie, rest humans)
    private func assignZombieTagRoles(session: inout GameSession) {
        guard session.players.count > 0 else { return }
        
        // Reset all players to humans and alive
        for i in 0..<session.players.count {
            session.players[i].role = .human
            session.players[i].isAlive = true
        }
        
        // Randomly select one zombie
        let shuffled = session.players.shuffled()
        guard let firstPlayer = shuffled.first else { return } // Safety check (should never happen due to guard above)
        if let zombieIndex = session.players.firstIndex(where: { $0.id == firstPlayer.id }) {
            session.players[zombieIndex].role = .zombie
            print("🧟 Assigned zombie: \(session.players[zombieIndex].displayName)")
        }
    }
    
    // Assign teams for Capture The Flag (balanced teams)
    private func assignCTFTeams(session: inout GameSession) {
        guard session.players.count >= 2 else {
            print("⚠️ CTF requires at least 2 players")
            return
        }
        
        // Reset all players to alive
        for i in 0..<session.players.count {
            session.players[i].isAlive = true
        }
        
        // Shuffle players and split into two teams
        let shuffled = session.players.shuffled()
        let midpoint = shuffled.count / 2
        
        // Assign Team A (first half)
        for i in 0..<midpoint {
            if let index = session.players.firstIndex(where: { $0.id == shuffled[i].id }) {
                session.players[index].role = .teamA
                print("🔵 Assigned Team A: \(session.players[index].displayName)")
            }
        }
        
        // Assign Team B (second half)
        for i in midpoint..<shuffled.count {
            if let index = session.players.firstIndex(where: { $0.id == shuffled[i].id }) {
                session.players[index].role = .teamB
                print("🔴 Assigned Team B: \(session.players[index].displayName)")
            }
        }
    }
    
    // Initialize flags for CTF
    private func initializeCTFFlags(session: inout GameSession) {
        guard let bubble = session.bubble else {
            print("⚠️ Cannot initialize CTF flags: no bubble configured")
            return
        }
        
        // Calculate base positions (opposite sides of bubble)
        let center = bubble.currentCenter()
        let radius = bubble.currentRadius(at: Date())
        
        // Team A base (north of center)
        let teamABase = CLLocationCoordinate2D(
            latitude: center.latitude + (radius * 0.3 / 111000.0), // ~30% of radius north
            longitude: center.longitude
        )
        
        // Team B base (south of center)
        let teamBBase = CLLocationCoordinate2D(
            latitude: center.latitude - (radius * 0.3 / 111000.0), // ~30% of radius south
            longitude: center.longitude
        )
        
        session.teamABase = teamABase
        session.teamBBase = teamBBase
        
        // Create flags at their bases
        let flagA = Flag(
            team: .teamA,
            latitude: teamABase.latitude,
            longitude: teamABase.longitude,
            isAtBase: true
        )
        
        let flagB = Flag(
            team: .teamB,
            latitude: teamBBase.latitude,
            longitude: teamBBase.longitude,
            isAtBase: true
        )
        
        session.flags = [flagA, flagB]
        session.teamAScore = 0
        session.teamBScore = 0
        
        print("🚩 CTF flags initialized")
        print("   Team A base: \(teamABase.latitude), \(teamABase.longitude)")
        print("   Team B base: \(teamBBase.latitude), \(teamBBase.longitude)")
    }
    
    private func assignRandomHunters(session: inout GameSession, count: Int) {
        print("🎯 assignRandomHunters called with count: \(count), total players: \(session.players.count)")
        
        #if DEBUG
        let minCount = 0
        #else
        let minCount = 1
        #endif
        guard count >= minCount && count <= session.players.count else {
            print("⚠️ Invalid hunter count: \(count), defaulting to \(minCount)")
            for i in 0..<session.players.count {
                session.players[i].role = .hider
            }
            return
        }
        
        // If count is 0, make everyone a hider
        if count == 0 {
            print("🎯 Setting all \(session.players.count) players to hiders (testing mode)")
            for i in 0..<session.players.count {
                session.players[i].role = .hider
            }
            return
        }
        
        // Check if hunters are already manually assigned correctly
        let currentHunters = session.players.filter { $0.role == .hunter }
        let currentHunterCount = currentHunters.count
        print("🎯 Current hunters in session: \(currentHunters.map { $0.displayName }.joined(separator: ", ")) (count: \(currentHunterCount), requested: \(count))")
        
        // If the current hunter count matches the requested count, preserve manual assignments
        if currentHunterCount == count {
            print("🎯 Preserving existing \(count) manually assigned hunter(s): \(currentHunters.map { $0.displayName }.joined(separator: ", "))")
            // Just ensure all players are alive
            for i in 0..<session.players.count {
                session.players[i].isAlive = true
            }
            return
        }

        if currentHunterCount > 0 {
            let hunterIdsToKeep = Set(currentHunters.prefix(count).map(\.id))
            print("🎯 Preserving \(hunterIdsToKeep.count) manually assigned hunter(s), then filling to requested count")

            for i in 0..<session.players.count {
                session.players[i].isAlive = true
                session.players[i].role = hunterIdsToKeep.contains(session.players[i].id) ? .hunter : .hider
            }

            let additionalHuntersNeeded = max(0, count - hunterIdsToKeep.count)
            if additionalHuntersNeeded > 0 {
                let candidates = session.players.filter { $0.role == .hider }.shuffled()
                let huntersToAssign = min(additionalHuntersNeeded, candidates.count)
                print("   🎯 Assigning \(huntersToAssign) additional hunter(s) from \(candidates.count) candidates")
                for i in 0..<huntersToAssign {
                    if let index = session.players.firstIndex(where: { $0.id == candidates[i].id }) {
                        session.players[index].role = .hunter
                        print("   ✅ Assigned additional hunter \(i + 1)/\(huntersToAssign): \(session.players[index].displayName)")
                    }
                }
            }

            let actualHunterCount = session.players.filter { $0.role == .hunter }.count
            print("   ✅ Total hunters assigned: \(actualHunterCount) (requested: \(count))")
            return
        }

        // Otherwise, reset all players to hiders and randomly assign
        print("🎯 No manually assigned hunters found, assigning randomly")

        // Reset all players to hiders first
        for i in 0..<session.players.count {
            session.players[i].role = .hider
            session.players[i].isAlive = true
        }
        
        // Randomly select hunters
        let shuffled = session.players.shuffled()
        let huntersToAssign = min(count, shuffled.count)
        print("   🎯 Assigning \(huntersToAssign) hunter(s) from \(shuffled.count) players")
        for i in 0..<huntersToAssign {
            if let index = session.players.firstIndex(where: { $0.id == shuffled[i].id }) {
                session.players[index].role = .hunter
                print("   ✅ Assigned hunter \(i + 1)/\(huntersToAssign): \(session.players[index].displayName)")
            }
        }
        
        // Verify assignment
        let actualHunterCount = session.players.filter { $0.role == .hunter }.count
        print("   ✅ Total hunters assigned: \(actualHunterCount) (requested: \(count))")
    }
    
    private func assignHuntersFromFirstTagged(session: inout GameSession, count: Int) {
        // Reset all players to hiders first
        for i in 0..<session.players.count {
            session.players[i].role = .hider
            session.players[i].isAlive = true
        }
        
        // First tagged player becomes hunter
        if let firstTaggedId = session.firstTaggedPlayerId,
           let firstTaggedIndex = session.players.firstIndex(where: { $0.id == firstTaggedId }) {
            session.players[firstTaggedIndex].role = .hunter
            print("🎯 First tagged player is hunter: \(session.players[firstTaggedIndex].displayName)")
            
            // If we need more hunters, randomly assign from remaining players
            if count > 1 {
                let remainingPlayers = session.players.filter { $0.role == .hider }
                let shuffled = remainingPlayers.shuffled()
                let additionalHunters = min(count - 1, shuffled.count)
                
                for i in 0..<additionalHunters {
                    if let index = session.players.firstIndex(where: { $0.id == shuffled[i].id }) {
                        session.players[index].role = .hunter
                        print("🎯 Additional hunter assigned: \(session.players[index].displayName)")
                    }
                }
            }
        } else {
            // No first tagged player (shouldn't happen, but fallback to random)
            print("⚠️ No first tagged player found, using random assignment")
            assignRandomHunters(session: &session, count: count)
        }
    }
    
    // Host override: Manually set a player as hunter
    func setTeam(playerId: String, team: Flag.Team) {
        guard isCurrentPlayerSessionHost() else {
            print("❌ Only host can change teams")
            return
        }
        guard session?.gameState == .lobby else {
            print("❌ Cannot change teams: game has already started")
            return
        }

        commitLobbySessionInBackground { session in
            guard let index = session.players.firstIndex(where: { $0.id == playerId }) else {
                Swift.print("❌ Cannot set team: player not found in server roster")
                return
            }
            let newRole: PlayerRole = team == .teamA ? .teamA : .teamB
            session.players[index].role = newRole
            Swift.print("✅ Player \(session.players[index].displayName) moved to \(team.rawValue)")
        }
    }
    
    // Set team leader status for a player (CTF)
    func setTeamLeader(playerId: String, isTeamLeader: Bool) {
        guard isCurrentPlayerSessionHost() else {
            print("❌ Only host can set team leader")
            return
        }
        guard session?.gameType == .captureTheFlag else {
            print("❌ Cannot set team leader: not a CTF game")
            return
        }
        guard session?.gameState == .lobby else {
            print("❌ Cannot change team leader: game has already started")
            return
        }

        commitLobbySessionInBackground { session in
            guard let playerIndex = session.players.firstIndex(where: { $0.id == playerId }),
                  let playerTeam = session.players[playerIndex].team else {
                Swift.print("❌ Cannot set team leader: player not found or no team in server roster")
                return
            }

            if isTeamLeader {
                for i in 0..<session.players.count {
                    if session.players[i].team == playerTeam && session.players[i].isTeamLeader {
                        session.players[i].isTeamLeader = false
                    }
                }
            }
            session.players[playerIndex].isTeamLeader = isTeamLeader
            Swift.print("✅ Player \(session.players[playerIndex].displayName) team leader status set to: \(isTeamLeader)")
        }
    }
    
    func placeSafeZone(team: Flag.Team, center: CLLocationCoordinate2D, radius: Double) {
        guard let currentPlayer = currentPlayer,
              currentPlayer.isTeamLeader,
              currentPlayer.team == team else {
            print("❌ Only team leader can place safe zone")
            return
        }
        guard session?.gameState == .flagPlacement else {
            print("❌ Cannot place safe zone: Game has already started")
            return
        }
        guard isValidCoordinate(center) else {
            print("❌ Invalid safe zone center coordinate")
            return
        }
        guard radius >= 5.0 && radius <= 50.0 else {
            print("❌ Safe zone radius must be between 5 and 50 meters")
            return
        }

        let safeZone = GameSession.SafeZone(center: center, radius: radius, confirmedAt: Date())

        commitLobbySessionInBackground(
            requireHost: false,
            requireState: .flagPlacement
        ) { session in
            if team == .teamA {
                session.teamASafeZone = safeZone
                Swift.print("✅ Team A safe zone confirmed (IMMUTABLE) at \(center.latitude), \(center.longitude) with radius \(radius)m")
            } else {
                session.teamBSafeZone = safeZone
                Swift.print("✅ Team B safe zone confirmed (IMMUTABLE) at \(center.latitude), \(center.longitude) with radius \(radius)m")
            }
        }
    }
    
    func setFlag(playerId: String, isFlag: Bool) {
        guard session?.gameType == .captureTheFlag else {
            print("❌ Cannot set flag: not a CTF game")
            return
        }
        guard session?.gameState == .lobby else {
            print("❌ Cannot change flag status: game has already started")
            return
        }
        guard let currentPlayer = currentPlayer,
              (currentPlayer.id == playerId || isCurrentPlayerSessionHost()) else {
            print("❌ Only the player themselves or host can set flag status")
            return
        }

        commitLobbySessionInBackground(requireHost: false) { session in
            guard let index = session.players.firstIndex(where: { $0.id == playerId }) else {
                Swift.print("❌ Cannot set flag: player not found in server roster")
                return
            }
            let player = session.players[index]
            guard let playerTeam = player.team else {
                Swift.print("❌ Player must be on a team to be a flag")
                return
            }

            // If removing flag status and in placement phase, reset placement.
            // The outer guard restricts this to `.lobby`, but the check is
            // preserved verbatim to avoid changing CTF lobby semantics.
            if !isFlag && player.isFlag && session.gameState == .flagPlacement {
                if playerTeam == .teamA {
                    session.teamAFlagPlaced = false
                    Swift.print("🚩 Team A flag placement reset (flag removed)")
                } else if playerTeam == .teamB {
                    session.teamBFlagPlaced = false
                    Swift.print("🚩 Team B flag placement reset (flag removed)")
                }
            }

            if isFlag {
                for i in 0..<session.players.count {
                    if session.players[i].team == playerTeam && session.players[i].isFlag && session.players[i].id != playerId {
                        session.players[i].isFlag = false
                        Swift.print("✅ Removed flag status from \(session.players[i].displayName)")
                    }
                }
            }

            session.players[index].isFlag = isFlag
            Swift.print("✅ Player \(player.displayName) flag status set to \(isFlag)")
        }
    }
    
    func setHunter(playerId: String) {
        guard isCurrentPlayerSessionHost() else {
            print("❌ Only host can set hunters")
            return
        }
        guard session?.gameState == .lobby else {
            print("❌ Cannot change hunters: game has already started")
            return
        }

        commitLobbySessionInBackground { session in
            guard let playerIndex = session.players.firstIndex(where: { $0.id == playerId }) else {
                Swift.print("❌ Player not found in server roster: \(playerId)")
                return
            }

            // If we're setting a hider as hunter, we need to demote a hunter
            if session.players[playerIndex].role == .hider {
                if let hunterToDemote = session.players.first(where: { $0.role == .hunter && $0.id != playerId }),
                   let hunterIndex = session.players.firstIndex(where: { $0.id == hunterToDemote.id }) {
                    session.players[hunterIndex].role = .hider
                }
                session.players[playerIndex].role = .hunter
            } else {
                // Demote this player; promote any other hider if available.
                session.players[playerIndex].role = .hider
                if let hiderToPromote = session.players.first(where: { $0.role == .hider && $0.id != playerId }),
                   let hiderIndex = session.players.firstIndex(where: { $0.id == hiderToPromote.id }) {
                    session.players[hiderIndex].role = .hunter
                }
            }
            Swift.print("✅ Hunter role updated for: \(session.players[playerIndex].displayName)")
        }
    }
    
    /// Called when the pre-game countdown completes to start the game timer
    /// This ensures the bubble.startTime is set when the game actually begins, not during the countdown
    func startGameTimer() {
        guard var session = session, var bubble = session.bubble else {
            print("⚠️ Cannot start game timer: session or bubble is nil")
            return
        }

        guard isCurrentPlayerSessionHost() else {
            // The host owns the authoritative timer/zone write. Other players still
            // start their local rule timer and receive the synced bubble via listener.
            startUpdateTimer()
            print("⏱️ Non-host countdown complete; waiting for host timer sync")
            return
        }
        
        // Set bubble start time to now when countdown completes
        bubble.startTime = Date()
        
        if session.gameType != .captureTheFlag {
            ZoneService.preparePrecomputedZoneSchedule(
                bubble: &bubble,
                gameType: session.gameType,
                generatedAt: Date()
            )
            if bubble.zoneScheduleEnabled {
                print("✅ Zone schedule generated for \(session.gameType.rawValue): \(bubble.zoneSchedule.count) phases")
            } else if bubble.enableShrinking {
                print("ℹ️ Zone schedule disabled or unavailable; full zone remains active")
            }
        } else if !bubble.enableShrinking {
            print("ℹ️ Zone shrinking disabled - zone will remain fixed at \(bubble.startRadius)m")
            // Initialize boundary to match start radius and center (fixed zone)
            bubble.boundaryRadius = bubble.startRadius
            bubble.boundaryCenterLatitude = bubble.centerLatitude
            bubble.boundaryCenterLongitude = bubble.centerLongitude
            bubble.zoneSchedule = []
            bubble.zoneScheduleGeneratedAt = nil
            bubble.zoneScheduleEnabled = false
        }
        
        session.bubble = bubble
        self.session = session
        
        print("⏱️ Game timer started (bubble.startTime set to: \(bubble.startTime))")
        
        // Start local derivation ticks for runtime zone state. These ticks do not
        // persist interpolated zone positions back to Firestore.
        if session.gameType != .captureTheFlag && bubble.usesNewZoneSystem {
            startUpdateTimer()
            print("🔵 Zone: Update timer started in startGameTimer()")
        }
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error updating bubble start time in Firestore: \(error)")
            }
        }
    }
    
    func endGame() {
        guard let currentSession = session else {
            print("❌ Cannot end game: no session")
            return
        }

        // Host-only authoritative end. Non-hosts can no longer flip the
        // local session to `.ended` ahead of Firestore, because the
        // matching Firestore write is rejected by rules and was the
        // source of split-state bugs where some devices finished the
        // game while others kept playing.
        guard isCurrentPlayerSessionHost() else {
            print("🏁 Non-host endGame: deferring to host write (will finalize on listener)")
            awaitingServerGameEnd = true
            return
        }

        print("🏁 Ending game - current gameState: \(gameState) (host write)")

        var session = finalizeLocalGameEnd(session: currentSession)
        session.endReason = .completed

        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error updating session in Firestore: \(error)")
            }
        }

        // Schedule session cleanup after 5 minutes (allows "Play Again" functionality)
        // This prevents Firestore storage bloat from old sessions
        let sessionId = session.id
        Task {
            try? await Task.sleep(nanoseconds: 5 * 60 * 1_000_000_000)

            if self.session?.id == sessionId,
               self.session?.gameState == .ended {
                do {
                    try await firestoreService.deleteSession(sessionId)
                    print("🗑️ Session cleaned up from Firestore: \(sessionId)")
                } catch {
                    print("❌ Error deleting session: \(error)")
                }
            } else {
                print("⚠️ Session \(sessionId) was reused (Play Again), skipping cleanup")
            }
        }
    }

    /// Local-only end-game finalization: stats, local `.ended` transition,
    /// timers, and location cleanup. Returns the session with `gameState`
    /// already set to `.ended` so the host caller can pass it straight to
    /// Firestore. Non-host devices invoke this from the session listener
    /// once the host's authoritative `.ended` write lands, so every
    /// player's local UI lands on the same end state from the same
    /// computation.
    @discardableResult
    private func finalizeLocalGameEnd(session existingSession: GameSession) -> GameSession {
        var session = existingSession

        syncPendingLocationUpdate()
        bluetoothTagService.stop()

        let gameStartTime: Date
        if let bubble = session.bubble {
            gameStartTime = bubble.startTime
        } else {
            gameStartTime = Date()
            print("⚠️ Warning: No bubble found when ending game, using current time as start time")
        }

        var stats = gameStats ?? GameStats(gameStartTime: gameStartTime)
        stats.gameEndTime = Date()

        if session.gameType == .captureTheFlag {
            if let team = winningTeam {
                stats.winner = team == .teamA ? .teamA : .teamB
            } else if let bubble = session.bubble {
                if bubble.duration.isFinite {
                    let elapsed = Date().timeIntervalSince(bubble.startTime)
                    if elapsed >= bubble.duration {
                        if session.teamAScore > session.teamBScore {
                            stats.winner = .teamA
                        } else if session.teamBScore > session.teamAScore {
                            stats.winner = .teamB
                        } else {
                            stats.winner = .timeUp
                        }
                    }
                }
            }
        } else {
            let hiders = session.players.filter { $0.role == .hider }
            let aliveHiders = hiders.filter { $0.isAlive }

            if let bubble = session.bubble {
                let elapsed = elapsedSinceMatchStart(for: bubble)
                if bubble.duration.isFinite,
                   let elapsed,
                   elapsed >= bubble.duration {
                    stats.winner = .timeUp
                } else if hiders.count > 0 && aliveHiders.isEmpty {
                    stats.winner = .hunters
                } else if aliveHiders.count > 0 {
                    stats.winner = .hiders
                }
            } else {
                if hiders.count > 0 && aliveHiders.isEmpty {
                    stats.winner = .hunters
                } else if aliveHiders.count > 0 {
                    stats.winner = .hiders
                }
            }
        }

        gameStats = stats
        print("✅ Game stats finalized - Winner: \(stats.winner?.rawValue ?? "none"), Catches: \(stats.catches.count)")

        session.gameState = .ended
        self.session = session
        self.gameState = .ended
        shouldEndGame = false
        awaitingServerGameEnd = false
        stopUpdateTimer()
        locationService.stop()

        return session
    }
    
    // MARK: - Session teardown
    //
    // Three teardown shapes, deliberately distinct:
    //
    // - `detachFromSession()` — tab change / back-to-menu / app background.
    //   Drops local listeners and timers but keeps the Firestore doc AND
    //   the local snapshot so resume can re-pick the same lobby on the
    //   next launch.
    //
    // - `leaveSession()` — explicit "Leave game" / lobby exit. Host
    //   leave marks the session ended for everyone; non-host leave
    //   removes just this device's player. Always clears the local snapshot.
    //
    // - `clearSession()` — mode switch / debug. Deletes the Firestore doc
    //   and clears the snapshot. Use this when the user actively wants
    //   the current session gone.

    /// Drop local state for the current session WITHOUT touching
    /// Firestore or the resume snapshot. Used when navigating away from
    /// the game tab without explicitly leaving the lobby.
    func detachFromSession() {
        print("🧷 Detaching from session (keeping Firestore + snapshot)")
        stopUpdateTimer()
        stopSessionListener()
        bluetoothTagService.stop()
        locationService.stop()
        resetLocalGameState()
    }

    /// Explicit Leave from the lobby/active game. Host leave ends the
    /// session for everyone; non-host leave removes only this device's
    /// player from the roster. The Firestore write is transactional so
    /// other screens receive one authoritative listener update.
    @discardableResult
    func leaveSession() async -> Bool {
        print("🚪 Leaving session")
        let currentSession = session
        let leavingPlayerId = currentPlayer?.id

        if let currentSession, let leavingPlayerId {
            let sessionId = currentSession.id
            let isHostDevice = currentSession.isDeviceHost(playerId: leavingPlayerId)

            do {
                let updatedSession = try await firestoreService.leaveSession(
                    sessionId: sessionId,
                    playerId: leavingPlayerId
                )
                if isHostDevice || updatedSession.endReason == .hostLeft {
                    print("🏁 Host left; session ended for everyone: \(sessionId)")
                } else {
                    print("👋 Removed local player from session: \(sessionId)")
                }
            } catch {
                print("❌ Error updating session on leave: \(error)")
                networkError = "Couldn't leave the session. Check your connection and try again."
                isConnected = false
                return false
            }
        }

        stopUpdateTimer()
        stopSessionListener()
        bluetoothTagService.stop()
        locationService.stop()
        GuestSessionStore.shared.clear(reason: "leaveSession")
        resetLocalGameState()
        return true
    }

    /// Hard reset used when switching game modes or in debug. Deletes
    /// the Firestore doc and clears the snapshot.
    func clearSession() {
        print("🧹 Clearing game session completely")
        
        stopUpdateTimer()
        stopSessionListener()
        bluetoothTagService.stop()
        locationService.stop()
        
        if let sessionId = session?.id {
            Task {
                do {
                    try await firestoreService.deleteSession(sessionId)
                    print("🗑️ Session deleted from Firestore: \(sessionId)")
                } catch {
                    print("❌ Error deleting session from Firestore: \(error)")
                }
            }
        }

        GuestSessionStore.shared.clear(reason: "clearSession")
        resetLocalGameState()
        print("✅ Game service cleared")
    }

    /// Reset all `@Published` state without touching Firestore or the
    /// local snapshot. Shared between detach / leave / clear.
    private func resetLocalGameState() {
        session = nil
        currentPlayer = nil
        gameState = .lobby
        gameStats = nil
        isOutOfBounds = false
        clearOutOfBoundsGrace()
        distanceToEdge = nil
        warningLevel = .none
        caughtPlayers = []
        lastEliminationMessage = nil
        lastCatchMessage = nil
        tagRequestRejectedMessage = nil
        tagRequestRejectedClearTask?.cancel()
        tagDeniedByTargetMessage = nil
        tagDeniedByTargetClearTask?.cancel()
        shouldEndGame = false
        awaitingServerGameEnd = false
        winningTeam = nil
        nearestHunterDistance = nil
        nearestHiderDistance = nil
        nearestHunterDirection = nil
        nearestHiderDirection = nil
        nearestHunterId = nil
        nearestHiderId = nil
        proximityWarningLevel = .none
        proximityWarningDistance = nil
        shouldFlashScreen = false
        shouldPulseBubble = false
        catchAnimationTrigger = false
        eliminationAnimationTrigger = false
        networkError = nil
        isConnected = true
        flagPhoneDisconnected = [:]
        canTagPlayerId = nil
        pendingTagRequest = nil
        lastFirestoreUpdate = nil
        pendingLocationUpdate = nil
        lastUpdateCoordinate = nil
        isUpdatingSession = false
        remoteReadySessionId = nil
    }

    /// Clear local state after a remote terminal event without modifying
    /// Firestore. Used when another device receives `ended(hostLeft)`.
    func discardEndedSessionLocally(reason: String) {
        print("🧹 Discarding ended session locally: \(reason)")
        stopUpdateTimer()
        stopSessionListener()
        bluetoothTagService.stop()
        locationService.stop()
        GuestSessionStore.shared.clear(reason: reason)
        resetLocalGameState()
    }
    
    // Play Again - reset game state but keep session
    func playAgain() {
        guard var session = session else {
            print("❌ Cannot play again: no session")
            return
        }

        guard isCurrentPlayerSessionHost() else {
            print("🔄 Non-host playAgain ignored; waiting for host to start next round")
            return
        }
        
        print("🔄 Play Again called - current gameState: \(gameState)")
        
        // Increment game number
        session.gameNumber += 1
        
        // Reset game state to lobby
        session.gameState = .lobby
        session.endReason = nil
        session.bubble = nil // Clear bubble - needs to be reconfigured
        
        // Reset all players to alive and lobby roles (hunters reassigned on next beginGame)
        for i in 0..<session.players.count {
            session.players[i].role = .hider
            session.players[i].isAlive = true
        }
        
        // Reset game state
        shouldEndGame = false
        winningTeam = nil
        lastEliminationMessage = nil
        lastCatchMessage = nil
        caughtPlayers = []
        isOutOfBounds = false
        clearOutOfBoundsGrace()
        distanceToEdge = nil
        warningLevel = .none
        nearestHunterDistance = nil
        nearestHiderDistance = nil
        nearestHunterDirection = nil
        nearestHiderDirection = nil
        nearestHunterId = nil
        nearestHiderId = nil
        canTagPlayerId = nil
        pendingTagRequest = nil
        tagRequestRejectedMessage = nil
        tagRequestRejectedClearTask?.cancel()
        tagDeniedByTargetMessage = nil
        tagDeniedByTargetClearTask?.cancel()
        gameStats = nil
        
        // Reset CTF-specific state
        if session.gameType == .captureTheFlag {
            session.flagCarriers = [:]
            session.teamAFlagPlaced = false
            session.teamBFlagPlaced = false
            session.teamASafeZone = nil
            session.teamBSafeZone = nil
            session.teamAScore = 0
            session.teamBScore = 0
            flagPhoneDisconnected = [:]
            flagMotionState = [:]
            flagLastLocation = [:]
            lastFlagMotionAlert = [:]
        }
        
        // Stop BLE service
        bluetoothTagService.stop()
        
        // IMPORTANT: Update session and gameState together to trigger SwiftUI updates
        self.session = session
        self.gameState = .lobby  // This must be set AFTER session to ensure consistency
        
        print("✅ Play Again - Game number: \(session.gameNumber)")
        print("✅ Game state set to: \(gameState)")
        print("   First tagged from last game: \(session.firstTaggedPlayerId ?? "none")")
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
                print("✅ Play Again session synced to Firestore")
            } catch {
                print("❌ Error syncing play again to Firestore: \(error)")
            }
        }
    }
    
    // Reset to lobby - used when navigating back from game end screen
    func resetToLobby() {
        guard var session = session else {
            print("❌ Cannot reset to lobby: no session")
            return
        }

        guard isCurrentPlayerSessionHost() else {
            print("🔄 Non-host resetToLobby ignored; waiting for host")
            return
        }
        
        print("🔄 Reset to Lobby called - current gameState: \(gameState)")
        
        // Reset game state to lobby (but keep session and players)
        session.gameState = .lobby
        session.endReason = nil
        
        // Clear game-specific state but keep session data
        shouldEndGame = false
        winningTeam = nil
        lastEliminationMessage = nil
        lastCatchMessage = nil
        caughtPlayers = []
        isOutOfBounds = false
        clearOutOfBoundsGrace()
        distanceToEdge = nil
        warningLevel = .none
        nearestHunterDistance = nil
        nearestHiderDistance = nil
        nearestHunterDirection = nil
        nearestHiderDirection = nil
        nearestHunterId = nil
        nearestHiderId = nil
        canTagPlayerId = nil
        pendingTagRequest = nil
        tagRequestRejectedMessage = nil
        tagRequestRejectedClearTask?.cancel()
        tagDeniedByTargetMessage = nil
        tagDeniedByTargetClearTask?.cancel()
        // Keep gameStats for reference, but can be cleared if needed
        // gameStats = nil
        
        // Stop BLE service
        bluetoothTagService.stop()
        
        // Stop location updates
        locationService.stop()
        
        // Stop update timer
        stopUpdateTimer()
        
        // IMPORTANT: Update session and gameState together to trigger SwiftUI updates
        self.session = session
        self.gameState = .lobby  // This must be set AFTER session to ensure consistency
        
        print("✅ Reset to Lobby - Game state set to: \(gameState)")
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
                print("✅ Reset to lobby session synced to Firestore")
            } catch {
                print("❌ Error syncing reset to lobby to Firestore: \(error)")
            }
        }
    }
    
    // MARK: - Reconnection
    
    // Attempt to reconnect to an existing session
    // This is called when a player's session becomes nil or they lose connection
    func attemptReconnection(joinCode: String, playerLocation: CLLocationCoordinate2D) async -> (Bool, String?) {
        // Try to find session by join code (even if game has started)
        do {
            guard let session = try await firestoreService.findSessionByCodeAnyState(joinCode) else {
                return (false, "Session not found. The game may have ended.")
            }
            
            // Check if current player exists in this session
            guard let currentPlayerId = currentPlayer?.id,
                  session.players.contains(where: { $0.id == currentPlayerId }) else {
                return (false, "You are not part of this session. Please join with the join code.")
            }
            
            // Update player location in session
            var updatedSession = session
            if let playerIndex = updatedSession.players.firstIndex(where: { $0.id == currentPlayerId }) {
                updatedSession.players[playerIndex].latitude = playerLocation.latitude
                updatedSession.players[playerIndex].longitude = playerLocation.longitude
                updatedSession.players[playerIndex].lastUpdated = Date()
                
                // TEAM SWITCHING FIX: Preserve team assignment on reconnect
                // If player was on a team before disconnect, restore it
                if let previousPlayer = currentPlayer,
                   let previousTeam = previousPlayer.team {
                    // Restore team assignment to prevent defaulting to "all visible"
                    updatedSession.players[playerIndex].role = previousPlayer.role
                    print("✅ Restored team assignment for reconnected player: \(previousTeam.rawValue)")
                }
            }
            
            // Restore session
            self.session = updatedSession
            self.gameState = updatedSession.gameState
            self.remoteReadySessionId = updatedSession.id
            
            // Update current player (with preserved team assignment)
            if let player = updatedSession.players.first(where: { $0.id == currentPlayerId }) {
                self.currentPlayer = player
            }
            
            // Start listening
            startSessionListener(updatedSession.id)
            
            // If game is active, restart services
            if updatedSession.gameState == .active {
                locationService.start()
                if let playerId = currentPlayer?.id, let playerName = currentPlayer?.displayName {
                    bluetoothTagService.start(playerId: playerId, playerName: playerName)
                }
                startUpdateTimer()
            }
            
            print("✅ Successfully reconnected to session: \(updatedSession.id)")
            return (true, nil)
            
        } catch {
            print("❌ Reconnection error: \(error)")
            return (false, "Failed to reconnect. Please try joining again.")
        }
    }
    
    // MARK: - Join Game
    
    // Join an existing game by join code
    // Returns: (success: Bool, errorMessage: String?)
    func joinGame(joinCode: String, playerName: String, playerLocation: CLLocationCoordinate2D, expectedGameType: GameType? = nil, playerId: String? = nil) async -> (Bool, String?) {
        // Validate join code format
        let cleanedCode = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanedCode.count == 6, cleanedCode.allSatisfy({ $0.isNumber }) else {
            print("❌ Invalid join code format: \(cleanedCode)")
            return (false, "Invalid join code format. Please enter a 6-digit code.")
        }
        
        // Validate player location
        guard isValidCoordinate(playerLocation) else {
            print("❌ Cannot join game: invalid player location")
            return (false, "Invalid location. Please ensure GPS is enabled.")
        }
        
        // Validate player name
        let sanitizedName = playerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedName.isEmpty || !ProfileService.shared.displayName.isEmpty else {
            print("❌ Cannot join game: player name is empty")
            return (false, "Please enter a player name.")
        }
        
        do {
            // Find session by join code
            guard let session = try await firestoreService.findSessionByCode(cleanedCode) else {
                print("❌ No session found with join code: \(cleanedCode)")
                return (false, "No session found with that join code.")
            }

            guard AppReleaseConfiguration.isGameModeAvailable(session.gameType) else {
                print("❌ Join blocked: \(session.gameType.rawValue) is not available in this release")
                return (false, AppReleaseConfiguration.unavailableGameModeMessage)
            }
            
            // Validate game type matches expected game type (if provided)
            if let expectedType = expectedGameType {
                guard session.gameType == expectedType else {
                    let gameTypeName = session.gameType.rawValue
                    let expectedName = expectedType.rawValue
                    print("❌ Game type mismatch: session is \(gameTypeName), expected \(expectedName)")
                    return (false, "This join code is for \(gameTypeName), but you're trying to join from \(expectedName). Please select the correct game type.")
                }
            }
            
            // New joins are limited to lobbies. Reconnection to an active game uses
            // findSessionByCodeAnyState and the existing authenticated player id.
            if session.gameState != .lobby {
                print("❌ Cannot join game that has already started (state: \(session.gameState.rawValue))")
                return (false, "This game has already started. Ask the host for a new lobby.")
            }
            
            // Get profile picture from ProfileService
            let profileService = ProfileService.shared
            
            let authUid = playerId ?? currentPlayer?.authUserId ?? AuthService.shared.currentUserIdForLocalOperation()
            let joiningPlayerId = AuthService.shared.guestDeviceId
            
            let wasAlreadyInRoster = session.players.contains { $0.id == joiningPlayerId }
            if wasAlreadyInRoster {
                print("🔄 Reconnecting lobby player with device id: \(joiningPlayerId)")
            }

            let joiningPlayer = Player(
                id: joiningPlayerId,
                displayName: sanitizedName.isEmpty ? profileService.displayName : sanitizedName,
                latitude: playerLocation.latitude,
                longitude: playerLocation.longitude,
                role: .hider, // Joiners are hiders
                isAlive: true,
                profilePictureBase64: profileService.getProfilePictureBase64(),
                authUserId: authUid,
                deviceInstallationId: joiningPlayerId
            )

            let updatedSession = try await firestoreService.joinSession(
                sessionId: session.id,
                player: joiningPlayer,
                maxPlayers: Self.maxPlayersPerSession
            )

            guard let committedPlayer = updatedSession.players.first(where: { $0.id == joiningPlayerId }) else {
                print("❌ Join transaction succeeded but local player is missing from committed roster")
                return (false, "Failed to join game. Please try again.")
            }
            
            // Set local session and player
            self.session = updatedSession
            self.currentPlayer = committedPlayer
            self.gameState = updatedSession.gameState
            self.remoteReadySessionId = updatedSession.id
            self.saveResumeSnapshot(for: updatedSession, localPlayerId: committedPlayer.id, force: true)
            
            // Start listening to session changes
            startSessionListener(updatedSession.id)
            
            // If game is already active, start BLE immediately
            if updatedSession.gameState == .active {
                print("🎮 Joined active game - starting BLE immediately")
                bluetoothTagService.start(playerId: committedPlayer.id, playerName: committedPlayer.displayName)
                startUpdateTimer()
            }
            
            print("✅ Successfully \(wasAlreadyInRoster ? "reconnected to" : "joined") session: \(updatedSession.id) with \(updatedSession.players.count) players")
            return (true, nil)
            
        } catch {
            print("❌ Error joining game: \(error)")
            let nsError = error as NSError
            if let kind = nsError.userInfo["joinSessionErrorKind"] as? String {
                switch kind {
                case "notLobby":
                    return (false, "This game has already started. Ask the host for a new lobby.")
                case "full":
                    return (false, "Session is full! Maximum \(Self.maxPlayersPerSession) players allowed.")
                case "sessionMissing":
                    return (false, "No session found with that join code.")
                default:
                    break
                }
            }
            return (false, "Failed to join game. Please try again.")
        }
    }
    
    // MARK: - Location Updates
    
    // Validate coordinate is valid (not NaN, infinity, or out of bounds)
    private func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        guard coordinate.latitude.isFinite && coordinate.longitude.isFinite else {
            print("❌ Invalid coordinate: NaN or infinity")
            return false
        }
        guard coordinate.latitude >= -90 && coordinate.latitude <= 90 else {
            print("❌ Invalid latitude: \(coordinate.latitude) (must be -90 to 90)")
            return false
        }
        guard coordinate.longitude >= -180 && coordinate.longitude <= 180 else {
            print("❌ Invalid longitude: \(coordinate.longitude) (must be -180 to 180)")
            return false
        }
        return true
    }

    private func isValidTagAttempt(tagger: Player, target: Player, session: GameSession) -> Bool {
        guard isValidCoordinate(tagger.coordinate),
              isValidCoordinate(target.coordinate) else {
            return false
        }

        let distance = tagger.location.distance(from: target.location)
        guard distance.isFinite && distance >= 0 else {
            print("⚠️ Invalid tag distance calculation")
            return false
        }

        // BLE confirms physical proximity, but GPS can lag badly under trees,
        // buildings, or lock-screen handoffs. Keep enough GPS grace for real
        // close-range BLE tags while still rejecting obvious remote completions.
        let allowedDistance = max(session.catchDistance * 1.5, bleConfirmedTagGpsGraceDistance)
        guard distance <= allowedDistance else {
            print("⚠️ Rejected tag attempt: \(Int(distance))m away, allowed \(Int(allowedDistance))m")
            return false
        }

        return true
    }
    
    func updatePlayerLocation(_ coordinate: CLLocationCoordinate2D) {
        // Validate coordinate first
        guard isValidCoordinate(coordinate) else {
            print("⚠️ Skipping location update: invalid coordinate")
            return
        }
        
        guard var player = currentPlayer,
              var session = session,
              player.isAlive else { return }
        
        // CTF: Only flag players should track location
        if session.gameType == .captureTheFlag {
            guard player.isFlag else {
                // Non-flag players don't track location in CTF
                print("📍 CTF: Skipping location update for non-flag player \(player.displayName)")
                return
            }
        }
        
        // Always update local player location immediately
        player.latitude = coordinate.latitude
        player.longitude = coordinate.longitude
        player.lastUpdated = Date()
        
        // Update in session
        if let index = session.players.firstIndex(where: { $0.id == player.id }) {
            session.players[index] = player
        }
        
        // Update flag location if player is carrying a flag (CTF)
        if session.gameType == .captureTheFlag {
            for flagIndex in 0..<session.flags.count {
                if session.flags[flagIndex].carrierId == player.id {
                    session.flags[flagIndex].latitude = player.latitude
                    session.flags[flagIndex].longitude = player.longitude
                }
            }
        }
        
        currentPlayer = player
        self.session = session
        
        // Store pending update
        pendingLocationUpdate = coordinate

        guard remoteReadySessionId == session.id else {
            return
        }
        
        // Check if player has moved significantly (distance-based throttling for battery)
        var shouldUpdate = true
        if let lastCoord = lastUpdateCoordinate {
            let lastLocation = CLLocation(latitude: lastCoord.latitude, longitude: lastCoord.longitude)
            let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = lastLocation.distance(from: currentLocation)
            shouldUpdate = distance >= minUpdateDistance
        }
        
        // Throttle Firestore updates (only sync every 5 seconds AND if moved 5+ meters)
        let now = Date()
        if let lastUpdate = lastFirestoreUpdate {
            let timeSinceLastUpdate = now.timeIntervalSince(lastUpdate)
            if timeSinceLastUpdate >= firestoreUpdateInterval && shouldUpdate {
                syncLocationToFirestore(session)
                lastFirestoreUpdate = now
                lastUpdateCoordinate = coordinate
                pendingLocationUpdate = nil
            }
        } else {
            // First update - sync immediately
            syncLocationToFirestore(session)
            lastFirestoreUpdate = now
            lastUpdateCoordinate = coordinate
            pendingLocationUpdate = nil
        }
        
        // Always check game rules immediately (local checks)
        checkOutOfBounds()
        checkProximityCatches()
    }
    
    private func syncLocationToFirestore(_ session: GameSession) {
        guard let playerId = currentPlayer?.id,
              let player = session.players.first(where: { $0.id == playerId }) else {
            return
        }
        
        Task {
            do {
                if session.gameType == .manhunt || session.gameType == .zombieTag {
                    try await firestoreService.commitPlayerPresence(
                        sessionId: session.id,
                        player: player,
                        includeCoordinates: true
                    )
                } else {
                    try await firestoreService.updatePlayerLocation(
                        sessionId: session.id,
                        player: player,
                        flags: session.gameType == .captureTheFlag ? session.flags : nil
                    )
                }
                // Clear network error on successful sync
                if networkError != nil {
                    networkError = nil
                    isConnected = true
                }
            } catch {
                print("❌ Error syncing player location: \(error)")
                // Set network error but don't mark as disconnected (might be temporary)
                networkError = "Connection issue: \(error.localizedDescription)"
                // Only mark as disconnected if it's a persistent network error
                if let nsError = error as NSError?,
                   nsError.domain == NSURLErrorDomain,
                   (nsError.code == NSURLErrorNotConnectedToInternet || nsError.code == NSURLErrorTimedOut) {
                    isConnected = false
                }
            }
        }
    }
    
    // Force sync pending location update (called when game ends or on demand)
    func syncPendingLocationUpdate() {
        guard let session = session,
              let pending = pendingLocationUpdate else { return }
        
        // Update with pending location
        var updatedSession = session
        if let playerIndex = updatedSession.players.firstIndex(where: { $0.id == currentPlayer?.id }) {
            updatedSession.players[playerIndex].latitude = pending.latitude
            updatedSession.players[playerIndex].longitude = pending.longitude
            updatedSession.players[playerIndex].lastUpdated = Date()
        }
        
        syncLocationToFirestore(updatedSession)
        pendingLocationUpdate = nil
    }
    
    // Handle flag player leaving (CTF-specific cleanup)
    private func handleFlagPlayerLeaving(leavingPlayerId: String, session: inout GameSession) {
        guard let leavingPlayer = session.players.first(where: { $0.id == leavingPlayerId }),
              leavingPlayer.isFlag else {
            return // Not a flag player, no special handling needed
        }
        
        print("🚩 Flag player \(leavingPlayer.displayName) is leaving - cleaning up flag state")
        
        // If flag is captured, drop it at flag player's last known location
        if session.flagCarriers[leavingPlayerId] != nil {
            print("🚩 Dropping captured flag at flag player's last location")
            session.flagCarriers.removeValue(forKey: leavingPlayerId)
        }
        
        // If in flag placement phase, reset placement status
        if session.gameState == .flagPlacement {
            if leavingPlayer.team == .teamA {
                session.teamAFlagPlaced = false
                print("🚩 Team A flag placement reset")
            } else if leavingPlayer.team == .teamB {
                session.teamBFlagPlaced = false
                print("🚩 Team B flag placement reset")
            }
        }
    }
    
    // Handle team leader disconnection during safe zone placement
    private func handleTeamLeaderDisconnection(disconnectedPlayerId: String, session: inout GameSession) {
        guard let disconnectedPlayer = session.players.first(where: { $0.id == disconnectedPlayerId }),
              disconnectedPlayer.isTeamLeader,
              session.gameState == .flagPlacement else {
            return // Not a team leader or not in flag placement phase
        }
        
        let team = disconnectedPlayer.team
        let teamName = team == .teamA ? "Team A" : "Team B"
        print("⚠️ \(teamName) leader \(disconnectedPlayer.displayName) disconnected during safe zone placement")
        
        // Check if safe zone was already placed
        let safeZonePlaced = (team == .teamA && session.teamASafeZone != nil) ||
                            (team == .teamB && session.teamBSafeZone != nil)
        
        if safeZonePlaced {
            print("✅ \(teamName) safe zone already placed - no action needed")
            return
        }
        
        // FALLBACK: Auto-assign new team leader if possible
        // Find another player on the same team who can become leader
        let teamPlayers = session.players.filter { $0.team == team && $0.id != disconnectedPlayerId && $0.isAlive }
        
        if let newLeader = teamPlayers.first {
            // Auto-assign new leader
            if let index = session.players.firstIndex(where: { $0.id == newLeader.id }) {
                session.players[index].isTeamLeader = true
                print("✅ Auto-assigned \(newLeader.displayName) as new \(teamName) leader")
            }
        } else {
            // No other players on team - safe zone placement will be blocked until leader reconnects
            print("⚠️ No other players on \(teamName) - safe zone placement blocked until leader reconnects")
        }
        
        // If flag player is also the leader and flag is placed, use flag location as fallback
        if disconnectedPlayer.isFlag {
            let flagPlaced = (team == .teamA && session.teamAFlagPlaced) ||
                            (team == .teamB && session.teamBFlagPlaced)
            
            if flagPlaced, let _ = disconnectedPlayer.coordinate as CLLocationCoordinate2D? {
                // Auto-place safe zone at flag location with default radius after 30 second timeout
                print("⏳ Will auto-place \(teamName) safe zone at flag location if leader doesn't return in 30s")
                // This will be handled by a timer in the UI
            }
        }
    }
    
    // Check for players who lost location (disconnected for > 30 seconds)
    // Also handles reconnection and host migration
    private func checkForDisconnectedPlayers(session: GameSession) {
        var session = session
        let now = Date()
        
        // TEST MODE: Skip disconnect checking if fake players are present
        // Fake players don't update their location, so they'll always appear disconnected
        let hasFakePlayers = session.players.contains { $0.displayName.contains("Fake Player") }
        if hasFakePlayers {
            // In test mode, skip disconnect checking to avoid spam
            return
        }
        
        // CONNECTIVITY GRACE PERIOD:
        // - disconnectTimeout (30s): Player marked as disconnected, but still visible
        // - reconnectionWindow (120s): Player can reconnect without being eliminated
        // - After reconnectionWindow: Player is eliminated (if hider/human)
        let disconnectTimeout: TimeInterval = 30.0 // 30 seconds - mark as disconnected
        let reconnectionWindow: TimeInterval = 120.0 // 2 minutes to reconnect - grace period
        var sessionNeedsUpdate = false
        
        // CTF: Track flag phone disconnect status
        if session.gameType == .captureTheFlag {
            var updatedDisconnectStatus: [Flag.Team: Bool] = [:]
            
            // Check Team A flag phone
            if let teamAFlag = session.players.first(where: { $0.isFlag && $0.team == .teamA }) {
                let timeSinceUpdate = now.timeIntervalSince(teamAFlag.lastUpdated)
                let isDisconnected = timeSinceUpdate > disconnectTimeout
                updatedDisconnectStatus[.teamA] = isDisconnected
                
                if isDisconnected && flagPhoneDisconnected[.teamA] != true {
                    print("⚠️ Team A flag phone disconnected (no update for \(Int(timeSinceUpdate))s)")
                    notificationService.notifyFlagDisconnected(team: .teamA)
                } else if !isDisconnected && flagPhoneDisconnected[.teamA] == true {
                    print("✅ Team A flag phone reconnected")
                    notificationService.notifyFlagReconnected(team: .teamA)
                }
            }
            
            // Check Team B flag phone
            if let teamBFlag = session.players.first(where: { $0.isFlag && $0.team == .teamB }) {
                let timeSinceUpdate = now.timeIntervalSince(teamBFlag.lastUpdated)
                let isDisconnected = timeSinceUpdate > disconnectTimeout
                updatedDisconnectStatus[.teamB] = isDisconnected
                
                if isDisconnected && flagPhoneDisconnected[.teamB] != true {
                    print("⚠️ Team B flag phone disconnected (no update for \(Int(timeSinceUpdate))s)")
                    notificationService.notifyFlagDisconnected(team: .teamB)
                } else if !isDisconnected && flagPhoneDisconnected[.teamB] == true {
                    print("✅ Team B flag phone reconnected")
                    notificationService.notifyFlagReconnected(team: .teamB)
                }
            }
            
            // Update disconnect status
            flagPhoneDisconnected = updatedDisconnectStatus
        }
        
        for player in session.players where player.isAlive {
            let timeSinceUpdate = now.timeIntervalSince(player.lastUpdated)

            // Check if player is disconnected
            if timeSinceUpdate > disconnectTimeout {
                print("⚠️ Player \(player.displayName) disconnected (no location update for \(Int(timeSinceUpdate))s)")

                // Handle flag player leaving (CTF-specific)
                if session.gameType == .captureTheFlag {
                    handleFlagPlayerLeaving(leavingPlayerId: player.id, session: &session)

                    // Also check if this is a team leader
                    if player.isTeamLeader {
                        handleTeamLeaderDisconnection(disconnectedPlayerId: player.id, session: &session)
                    }

                    sessionNeedsUpdate = true
                }

                // Manhunt/Zombie Tag: never auto-eliminate hiders or humans
                // based on stale `lastUpdated`. Hiding still is normal play,
                // and the new active-game heartbeat handles real presence.
                // Disconnect remains a UI signal only.
                if session.gameType == .manhunt || session.gameType == .zombieTag {
                    continue
                }

                // If disconnected for too long (beyond reconnection window), eliminate.
                // CTF-only at this point: hider/human roles do not exist in CTF, so
                // this branch is effectively dormant. Kept as defense-in-depth in case
                // additional game types are added later.
                if timeSinceUpdate > reconnectionWindow {
                    if player.role == .hider || player.role == .human {
                        eliminatePlayer(player.id)
                    }
                } else {
                    // Still within reconnection window - mark as disconnected but don't eliminate yet
                    print("⏳ Player \(player.displayName) still in reconnection window (\(Int(reconnectionWindow - timeSinceUpdate))s remaining)")
                }
            }
        }
        
        // Check for host migration (if host disconnected beyond reconnection window)
        if let hostIndex = session.players.firstIndex(where: { $0.id == session.hostPlayerId }) {
            let host = session.players[hostIndex]
            let timeSinceHostUpdate = now.timeIntervalSince(host.lastUpdated)
            
            // If host disconnected for too long, migrate to another player
            if timeSinceHostUpdate > reconnectionWindow {
                // Find a new host (prefer alive players, then any player)
                if let newHost = session.players.first(where: { $0.id != session.hostPlayerId && $0.isAlive }) {
                    print("👑 Host migration: \(host.displayName) disconnected, migrating to \(newHost.displayName)")
                    session.hostPlayerId = newHost.id
                    session.hostAuthUid = newHost.authUserId
                    session.hostId = newHost.authUserId
                    sessionNeedsUpdate = true
                    
                    // Notify all players (via network error message that will be displayed)
                    if currentPlayer?.id == newHost.id {
                        networkError = "You are now the host (previous host disconnected)"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
                            self?.networkError = nil
                        }
                    }
                } else if let anyPlayer = session.players.first(where: { $0.id != session.hostPlayerId }) {
                    // Fallback: assign to any player if no alive players available
                    print("👑 Host migration: No alive players, assigning to \(anyPlayer.displayName)")
                    session.hostPlayerId = anyPlayer.id
                    session.hostAuthUid = anyPlayer.authUserId
                    session.hostId = anyPlayer.authUserId
                    sessionNeedsUpdate = true
                } else {
                    // No other players - end the game
                    print("⚠️ Host disconnected and no other players - ending game")
                    signalGameOverDetected()
                    return
                }
            }
        }
        
        // Update session if host migrated or flag player left
        if sessionNeedsUpdate {
            self.session = session
            Task {
                do {
                    try await firestoreService.updateSession(session)
                    print("✅ Session updated after host migration/flag player cleanup")
                } catch {
                    print("❌ Error updating session after host migration/flag player cleanup: \(error)")
                }
            }
        }
    }
    
    // MARK: - Game Rules

    private func activeZoneMetrics(
        for coordinate: CLLocationCoordinate2D,
        bubble: Bubble,
        now: Date = Date(),
        logFailures: Bool = true
    ) -> (distanceToEdge: Double, radius: Double)? {
        let distance: Double
        let radius: Double

        if bubble.usesNewZoneSystem {
            let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: now)
            radius = runtimeState.currentActiveZone.radiusMeters
            guard radius.isFinite && radius > 0 else {
                if logFailures {
                    print("⚠️ Invalid boundary radius: \(radius) - skipping zone check")
                }
                return nil
            }
            distance = runtimeState.distanceToEdge(from: coordinate)
        } else {
            radius = bubble.currentRadius(at: now)
            guard radius.isFinite && radius > 0 else {
                if logFailures {
                    print("⚠️ Invalid bubble radius: \(radius) - skipping zone check")
                }
                return nil
            }
            distance = bubble.distanceToEdge(from: coordinate, at: now)
        }

        guard distance.isFinite else {
            if logFailures {
                print("⚠️ Invalid distance calculation - skipping zone check")
            }
            return nil
        }

        return (distance, radius)
    }

    private func isCoordinateOutsideActiveZone(
        _ coordinate: CLLocationCoordinate2D,
        bubble: Bubble,
        now: Date = Date(),
        logFailures: Bool = true
    ) -> Bool {
        guard let metrics = activeZoneMetrics(
            for: coordinate,
            bubble: bubble,
            now: now,
            logFailures: logFailures
        ) else {
            return false
        }

        let outOfBoundsDistance = bubble.usesNewZoneSystem
            ? metrics.distanceToEdge - ZoneService.enforcementToleranceMeters
            : metrics.distanceToEdge
        return outOfBoundsDistance > 0
    }
    
    private func checkOutOfBounds() {
        guard let session = session,
              let bubble = session.bubble,
              let player = currentPlayer,
              player.isAlive else {
            isOutOfBounds = false
            clearOutOfBoundsGrace()
            distanceToEdge = nil
            return
        }
        
        // Validate player coordinate
        guard isValidCoordinate(player.coordinate) else {
            print("⚠️ Invalid player coordinate in checkOutOfBounds - skipping")
            return
        }

        guard let metrics = activeZoneMetrics(for: player.coordinate, bubble: bubble) else {
            return
        }

        distanceToEdge = metrics.distanceToEdge

        let outOfBoundsDistance = bubble.usesNewZoneSystem
            ? metrics.distanceToEdge - ZoneService.enforcementToleranceMeters
            : metrics.distanceToEdge

        if outOfBoundsDistance > 0 {
            let firstOOBTransition = !isOutOfBounds
            isOutOfBounds = true
            warningLevel = .danger

            if player.role == .hunter || player.role == .zombie {
                clearOutOfBoundsGrace()
            } else if session.gameType == .manhunt, player.role == .hider {
                if outOfBoundsGraceStartedAt == nil {
                    outOfBoundsGraceStartedAt = Date()
                    HapticFeedbackManager.shared.warning()
                }
                if let started = outOfBoundsGraceStartedAt,
                   Date().timeIntervalSince(started) >= Self.outOfBoundsGraceDuration,
                   player.isAlive {
                    clearOutOfBoundsGrace()
                    eliminatePlayer(player.id)
                }
            } else if firstOOBTransition {
                clearOutOfBoundsGrace()
                eliminatePlayer(player.id)
            }
        } else {
            clearOutOfBoundsGrace()
            isOutOfBounds = false
            updateWarningLevel(distance: abs(metrics.distanceToEdge), radius: metrics.radius)
        }
    }

    private func clearOutOfBoundsGrace() {
        outOfBoundsGraceStartedAt = nil
    }
    
    private func updateWarningLevel(distance: Double, radius: Double? = nil) {
        let effectiveRadius: Double
        if let radius = radius {
            effectiveRadius = radius
        } else if let bubble = session?.bubble {
            // Fallback to legacy system
            effectiveRadius = bubble.currentRadius(at: Date())
        } else {
            return
        }
        let warningZone = effectiveRadius * 0.2 // 20% of radius
        
        // Haptic feedback for proximity warnings
        if distance < 20 {
            HapticFeedbackManager.shared.proximityWarning(distance: distance)
        }
        
        if distance < warningZone {
            warningLevel = .danger
        } else if distance < warningZone * 2 {
            warningLevel = .warning
        } else if distance < warningZone * 3 {
            warningLevel = .safe
        } else {
            warningLevel = .none
        }
    }
    
    private func checkProximityCatches() {
        // BLE-based tagging - no auto-catch
        // Tagging is now manual via BLE connection
        // This method is kept for GPS-based proximity checking (for UI indicators)
        
        guard let session = session,
              let bubble = session.bubble,
              let player = currentPlayer,
              player.isAlive else { return }
        
        // Validate current player location
        guard isValidCoordinate(player.coordinate) else {
            print("⚠️ Invalid current player location in checkProximityCatches - skipping")
            return
        }
        
        let currentLocation = player.location
        
        // Calculate distances for UI indicators
        calculateDistances(currentLocation: currentLocation, session: session)
        
        // Update proximity warnings for hiders
        updateProximityWarnings(currentLocation: currentLocation, session: session)
        
        // Update BLE canTagPlayer based on GPS proximity (as backup indicator)
        // Actual tagging requires BLE connection
        let canTag: Bool
        if session.gameType == .zombieTag {
            // Zombie Tag: Zombies can tag humans
            canTag = (player.role == .zombie)
        } else {
            // Manhunt: Hunters can tag hiders
            canTag = (player.role == .hunter)
        }

        if canTag,
           isCoordinateOutsideActiveZone(player.coordinate, bubble: bubble, logFailures: false) {
            canTagPlayerId = nil
            return
        }
        
        if canTag {
        for otherPlayer in session.players where otherPlayer.id != player.id {
            let isValidTarget: Bool
            if session.gameType == .zombieTag {
                // Zombie Tag: Target must be human
                isValidTarget = (otherPlayer.role == .human)
            } else {
                // Manhunt: Target must be hider
                isValidTarget = (otherPlayer.role == .hider)
            }
            
            guard isValidTarget,
                  otherPlayer.isAlive,
                  !caughtPlayers.contains(otherPlayer.id) else { continue }
            
            // Validate player location
            guard isValidCoordinate(otherPlayer.coordinate) else {
                print("⚠️ Invalid location for player \(otherPlayer.displayName) - skipping")
                continue
            }
            
            let distance = currentLocation.distance(from: otherPlayer.location)
            
            // Validate distance
            guard distance.isFinite && distance >= 0 else {
                print("⚠️ Invalid distance to player \(otherPlayer.displayName) - skipping")
                continue
            }
                
                // If close enough AND BLE connection exists, allow tagging
                // Only allow if current player is hunter/zombie and nearby player is hider/human
                if distance <= session.catchDistance {
                    // Check if BLE connection exists for this player
                    if bluetoothTagService.canTagPlayer == otherPlayer.id {
                        // Check roles: hunter can tag hider, zombie can tag human
                        let canTag = (player.role == .hunter && otherPlayer.role == .hider) ||
                                    (player.role == .zombie && otherPlayer.role == .human)
                        
                        if canTag && otherPlayer.isAlive {
                            canTagPlayerId = otherPlayer.id
                        }
                    }
                }
            }
        }
        
        // CTF doesn't use BLE tagging - only flags are tracked
        if session.gameType == .captureTheFlag {
            // Check for CTF flag interactions (no BLE needed)
            checkCTFFlagInteractions(session: session)
            canTagPlayerId = nil // No tagging in CTF
            return
        }
        
        // Update canTagPlayerId from BLE service (only for Manhunt and ZombieTag)
        // Only set if current player is hunter/zombie and nearby player is hider/human
        guard let currentPlayer = currentPlayer,
              player.isAlive,
              (player.role == .hunter || player.role == .zombie) else {
            canTagPlayerId = nil
            return
        }
        
        // Try direct match first
        if let blePlayerId = bluetoothTagService.canTagPlayer {
            // Check if this player ID exists in the session
            if let sessionPlayer = session.players.first(where: { $0.id == blePlayerId }) {
                // Verify role: hunter can tag hider, zombie can tag human
                let canTag = (player.role == .hunter && sessionPlayer.role == .hider) ||
                            (player.role == .zombie && sessionPlayer.role == .human)
                
                if canTag && sessionPlayer.isAlive {
                    canTagPlayerId = blePlayerId
                } else {
                    canTagPlayerId = nil
                }
            } else {
                // Fallback: Try to match by name (in case BLE is using peripheral UUID)
                // Find player in session with matching name from BLE nearby players
                if let nearbyPlayer = bluetoothTagService.nearbyPlayers.first(where: { $0.id == blePlayerId }),
                   let sessionPlayer = session.players.first(where: { $0.displayName == nearbyPlayer.name && $0.isAlive }) {
                    // Verify role: hunter can tag hider, zombie can tag human
                    let canTag = (currentPlayer.role == .hunter && sessionPlayer.role == .hider) ||
                                (currentPlayer.role == .zombie && sessionPlayer.role == .human)
                    
                    if canTag {
                        canTagPlayerId = sessionPlayer.id
                        print("🔗 Matched BLE player by name: \(nearbyPlayer.name) -> \(sessionPlayer.id)")
                    } else {
                        canTagPlayerId = nil
                    }
                } else {
                    canTagPlayerId = nil
                }
            }
        } else {
            canTagPlayerId = nil
        }
    }
    
    // MARK: - Capture The Flag Functions
    
    // Get flag player for a team
    private func getFlagPlayer(for team: Flag.Team, in session: GameSession) -> Player? {
        return session.players.first { $0.team == team && $0.isFlag }
    }
    
    // Check if flag player can be captured
    private func canCaptureFlagPlayer(_ flagPlayer: Player, by player: Player, in session: GameSession) -> Bool {
        // Flag player must be at base (not captured)
        guard session.flagCarriers[flagPlayer.id] == nil else { return false }
        // Player must be on opposite team
        guard player.team != flagPlayer.team else { return false }
        // Player must be alive
        guard player.isAlive else { return false }
        // Flag player must be alive
        guard flagPlayer.isAlive else { return false }
        
        // Check if flag is within its team's safe zone (cannot be captured in safe zone)
        let flagLocation = flagPlayer.location
        let flagTeamSafeZone = flagPlayer.team == .teamA ? session.teamASafeZone : session.teamBSafeZone
        
        if let safeZone = flagTeamSafeZone {
            let safeZoneLocation = CLLocation(latitude: safeZone.center.latitude, longitude: safeZone.center.longitude)
            let distance = flagLocation.distance(from: safeZoneLocation)
            
            // If flag is within its team's safe zone, it cannot be captured
            if distance.isFinite && distance >= 0 && distance <= safeZone.radius {
                return false
            }
        }
        
        return true
    }
    
    // Check if flag player can be returned
    private func canReturnFlagPlayer(_ flagPlayer: Player, by player: Player, in session: GameSession) -> Bool {
        // Flag player must be captured
        guard session.flagCarriers[flagPlayer.id] != nil else { return false }
        // Player must be on the flag's team
        guard player.team == flagPlayer.team else { return false }
        // Player must be alive
        guard player.isAlive else { return false }
        
        // Check if player is within their team's safe zone
        let playerLocation = player.location
        let teamSafeZone = player.team == .teamA ? session.teamASafeZone : session.teamBSafeZone
        
        if let safeZone = teamSafeZone {
            let safeZoneLocation = CLLocation(latitude: safeZone.center.latitude, longitude: safeZone.center.longitude)
            let distance = playerLocation.distance(from: safeZoneLocation)
            
            // Player must be within safe zone radius to return flag
            guard distance.isFinite && distance >= 0 && distance <= safeZone.radius else {
                return false
            }
        } else {
            // No safe zone set - flag returns are not allowed
            return false
        }
        
        return true
    }
    
    // Check if flag player can be scored (at enemy base)
    private func canScoreFlagPlayer(_ flagPlayer: Player, by player: Player, enemyBase: CLLocationCoordinate2D, captureDistance: Double, in session: GameSession) -> Bool {
        // Validate base coordinates
        guard isValidCoordinate(enemyBase) else {
            print("⚠️ Cannot score: Invalid base coordinates")
            return false
        }
        
        // Flag player must be captured by this player
        guard session.flagCarriers[flagPlayer.id] == player.id else { return false }
        
        // Flag carrier cannot score while in a safe zone - must leave safe zone to score
        if isPlayerInSafeZone(player, in: session) {
            print("🛡️ Cannot score: Flag carrier is in a safe zone - must leave to score!")
            return false
        }
        
        // Flag player must be at enemy base
        let flagLocation = flagPlayer.location
        let baseLocation = CLLocation(latitude: enemyBase.latitude, longitude: enemyBase.longitude)
        let distance = flagLocation.distance(from: baseLocation)
        
        // Validate distance is finite and within range
        guard distance.isFinite && distance >= 0 && distance <= captureDistance else {
            return false
        }
        
        return true
    }
    
    // Check for flag capture, return, and score interactions
    private func checkCTFFlagInteractions(session: GameSession) {
        guard let currentPlayer = currentPlayer,
              currentPlayer.isAlive,
              let playerTeam = currentPlayer.team else { return }
        
        // Check flag motion for alerts (CTF only)
        checkFlagMotionAlerts(session: session)
        
        let playerLocation = currentPlayer.location
        
        // Check player flags (new system)
        if let teamAFlag = getFlagPlayer(for: .teamA, in: session) {
            let distance = playerLocation.distance(from: teamAFlag.location)
            
            if distance.isFinite && distance >= 0 && distance <= session.catchDistance {
                // Check if player can capture flag
                if canCaptureFlagPlayer(teamAFlag, by: currentPlayer, in: session) {
                    print("🚩 Player \(currentPlayer.displayName) can capture Team A flag")
                }
                
                // Check if player can return their team's flag
                if canReturnFlagPlayer(teamAFlag, by: currentPlayer, in: session) {
                    print("🚩 Player \(currentPlayer.displayName) can return Team A flag")
                }
                
                // Check if player can score (return enemy flag to base)
                if let enemyBase = (playerTeam == .teamA ? session.teamBBase : session.teamABase) {
                    if canScoreFlagPlayer(teamAFlag, by: currentPlayer, enemyBase: enemyBase, captureDistance: session.catchDistance, in: session) {
                        // Score automatically when close enough
                        scorePlayerFlag(flagPlayerId: teamAFlag.id)
                    }
                }
            }
        }
        
        if let teamBFlag = getFlagPlayer(for: .teamB, in: session) {
            let distance = playerLocation.distance(from: teamBFlag.location)
            
            if distance.isFinite && distance >= 0 && distance <= session.catchDistance {
                // Check if player can capture flag
                if canCaptureFlagPlayer(teamBFlag, by: currentPlayer, in: session) {
                    print("🚩 Player \(currentPlayer.displayName) can capture Team B flag")
                }
                
                // Check if player can return their team's flag
                if canReturnFlagPlayer(teamBFlag, by: currentPlayer, in: session) {
                    print("🚩 Player \(currentPlayer.displayName) can return Team B flag")
                }
                
                // Check if player can score (return enemy flag to base)
                if let enemyBase = (playerTeam == .teamA ? session.teamBBase : session.teamABase) {
                    if canScoreFlagPlayer(teamBFlag, by: currentPlayer, enemyBase: enemyBase, captureDistance: session.catchDistance, in: session) {
                        // Score automatically when close enough
                        scorePlayerFlag(flagPlayerId: teamBFlag.id)
                    }
                }
            }
        }
        
        // Legacy: Check virtual flags (for backward compatibility)
        for flag in session.flags {
            let flagLocation = flag.location
            let distance = playerLocation.distance(from: flagLocation)
            
            guard distance.isFinite && distance >= 0,
                  distance <= session.catchDistance else { continue }
            
            // Check if player can capture flag
            if flag.canBeCaptured(by: currentPlayer) {
                // Show UI indicator that flag can be captured
                // Actual capture requires button press (will be handled in UI)
                print("🚩 Player \(currentPlayer.displayName) can capture \(flag.team.rawValue) flag")
            }
            
            // Check if player can return their team's flag
            if flag.canBeReturned(by: currentPlayer) {
                // Show UI indicator that flag can be returned
                print("🚩 Player \(currentPlayer.displayName) can return \(flag.team.rawValue) flag")
            }
            
            // Check if player can score (return enemy flag to base)
            if let enemyBase = (playerTeam == .teamA ? session.teamBBase : session.teamABase) {
                if flag.canBeScored(by: currentPlayer, enemyBase: enemyBase, captureDistance: session.catchDistance) {
                    // Score the flag!
                    scoreFlag(flagId: flag.id)
                }
            }
        }
    }
    
    // MARK: - CTF Motion Detection Alerts
    
    private func checkFlagMotionAlerts(session: GameSession) {
        guard session.gameType == .captureTheFlag else { return }
        
        let now = Date()
        let motionAlertCooldown: TimeInterval = 5.0 // Prevent spam - only alert every 5 seconds
        let motionThreshold: Double = 5.0 // meters - flag must move this much to be considered "moving"
        
        // Check both flag players
        for flagPlayer in session.players where flagPlayer.isFlag {
            let flagPlayerId = flagPlayer.id
            let isCaptured = session.flagCarriers[flagPlayerId] != nil
            let wasMoving = flagMotionState[flagPlayerId] ?? false
            let currentLocation = flagPlayer.location
            
            // Get last known location
            let lastLocation = flagLastLocation[flagPlayerId]
            
            var isMoving = false
            if let lastLoc = lastLocation {
                let distance = currentLocation.distance(from: lastLoc)
                // If flag moved more than threshold, consider it moving
                isMoving = distance > motionThreshold
            }
            
            // Update motion state and location
            flagMotionState[flagPlayerId] = isMoving
            flagLastLocation[flagPlayerId] = currentLocation
            
            // Only alert if flag is captured
            guard isCaptured else {
                // Reset motion state when flag is not captured
                if wasMoving {
                    flagMotionState[flagPlayerId] = false
                }
                continue
            }
            
            // Check if motion state changed
            if isMoving != wasMoving {
                let lastAlertTime = lastFlagMotionAlert[flagPlayerId] ?? Date.distantPast
                let timeSinceLastAlert = now.timeIntervalSince(lastAlertTime)
                
                if timeSinceLastAlert >= motionAlertCooldown {
                    lastFlagMotionAlert[flagPlayerId] = now
                    
                    if isMoving {
                        // Flag started moving - alert team members
                        alertFlagMovement(flagPlayer: flagPlayer, isMoving: true, session: session)
                    } else {
                        // Flag stopped moving - alert team members
                        alertFlagMovement(flagPlayer: flagPlayer, isMoving: false, session: session)
                    }
                }
            }
        }
    }
    
    private func alertFlagMovement(flagPlayer: Player, isMoving: Bool, session: GameSession) {
        guard let flagTeam = flagPlayer.team else { return }
        
        let teamName = flagTeam == .teamA ? "Team A" : "Team B"
        let message = isMoving ? 
            "🚩 \(teamName) flag is being carried!" : 
            "🚩 \(teamName) flag has stopped moving!"
        
        notificationService.sendNotification(
            identifier: "flag_motion_\(flagPlayer.id)_\(Date().timeIntervalSince1970)",
            title: isMoving ? "Flag Moving!" : "Flag Stopped",
            body: message,
            categoryIdentifier: "FLAG_CAPTURE",
            sound: nil
        )
        
        print("📱 \(message)")
    }
    
    // Capture a player flag (new system)
    // FLAG STATE PRIORITY: Manual input (this function) > BLE > Motion (prompt only)
    func capturePlayerFlag(flagPlayerId: String) {
        guard var session = session,
              let currentPlayer = currentPlayer,
              let _ = currentPlayer.team,
              let flagPlayer = session.players.first(where: { $0.id == flagPlayerId && $0.isFlag }),
              canCaptureFlagPlayer(flagPlayer, by: currentPlayer, in: session) else {
            print("❌ Cannot capture player flag")
            return
        }
        
        // STATE AUTHORITY: Manual input always wins - override any conflicting states
        // Check if flag is already captured (could be from BLE or motion detection)
        if let existingCarrierId = session.flagCarriers[flagPlayerId],
           existingCarrierId != currentPlayer.id {
            print("⚠️ Flag already captured by \(existingCarrierId) - manual override to \(currentPlayer.id)")
            // Manual input takes priority - override existing state
        }
        
        // Set carrier (manual input has highest authority)
        session.flagCarriers[flagPlayerId] = currentPlayer.id
        
        // Haptic feedback
        HapticFeedbackManager.shared.playerCaught()
        
        // Visual feedback
        catchAnimationTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.catchAnimationTrigger = false
        }
        
        let isYourFlag = flagPlayer.team == currentPlayer.team
        notificationService.notifyFlagCaptured(
            team: flagPlayer.team ?? .teamA,
            capturedBy: currentPlayer.displayName,
            isYourFlag: isYourFlag
        )
        
        lastCatchMessage = "🚩 Captured \(flagPlayer.team?.rawValue ?? "enemy") flag!"
        announcementManager.post("Captured \(flagPlayer.team?.rawValue ?? "enemy") flag!", type: .flagEvent)
        
        self.session = session
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing player flag capture: \(error)")
            }
        }
    }
    
    // Return a player flag to base (new system)
    // Take possession of a flag after tagging the carrier
    // FLAG HANDOFF: Handles physical flag phone being passed between players
    // BLE will re-pair automatically, but we need to update the carrier in our state
    func takePossessionOfFlag(flagPlayerId: String) {
        guard var session = session,
              let currentPlayer = currentPlayer,
              let flagPlayer = session.players.first(where: { $0.id == flagPlayerId && $0.isFlag }),
              let flagTeam = flagPlayer.team,
              let playerTeam = currentPlayer.team else {
            print("❌ Cannot take possession of flag")
            return
        }
        
        // Defender must be on the flag's team (defending their own flag)
        guard playerTeam == flagTeam else {
            print("❌ Only defenders (flag's team) can take possession")
            return
        }
        
        // Flag must be captured by enemy team
        guard let enemyCarrierId = session.flagCarriers[flagPlayerId],
              let enemyCarrier = session.players.first(where: { $0.id == enemyCarrierId }),
              enemyCarrier.team != flagTeam else {
            print("❌ Flag is not captured by enemy team")
            return
        }
        
        // FLAG HANDOFF: Transfer flag possession to defender
        // When a flag phone is physically passed between players:
        // - BLE will automatically re-pair with the new carrier's phone
        // - This function updates our state to reflect the new carrier
        // - The flag is now "held by team" (defending team) rather than "held by player"
        session.flagCarriers[flagPlayerId] = currentPlayer.id
        
        // Haptic feedback
        HapticFeedbackManager.shared.playerCaught()
        
        lastCatchMessage = "🚩 Took possession of \(flagTeam.rawValue) flag! Return it to base."
        announcementManager.post("Took possession of \(flagTeam.rawValue) flag! Return to base.", type: .flagEvent)
        
        self.session = session
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing flag possession: \(error)")
            }
        }
    }
    
    func returnPlayerFlag(flagPlayerId: String) {
        guard var session = session,
              let currentPlayer = currentPlayer,
              let flagPlayer = session.players.first(where: { $0.id == flagPlayerId && $0.isFlag }),
              let flagTeam = flagPlayer.team,
              canReturnFlagPlayer(flagPlayer, by: currentPlayer, in: session) else {
            print("❌ Cannot return player flag")
            return
        }
        
        // Remove carrier (flag returns to base)
        session.flagCarriers[flagPlayerId] = nil
        
        // Reset flag player location to their base
        let baseLocation = flagTeam == .teamA ? session.teamABase : session.teamBBase
        if let base = baseLocation,
           let flagPlayerIndex = session.players.firstIndex(where: { $0.id == flagPlayerId }) {
            session.players[flagPlayerIndex].latitude = base.latitude
            session.players[flagPlayerIndex].longitude = base.longitude
            session.players[flagPlayerIndex].lastUpdated = Date()
            print("🚩 Flag player \(flagPlayer.displayName) returned to base at \(base.latitude), \(base.longitude)")
        }
        
        // Haptic feedback
        HapticFeedbackManager.shared.tagConfirmed()
        
        lastCatchMessage = "🚩 Returned \(flagTeam.rawValue) flag to base!"
        announcementManager.post("Returned \(flagTeam.rawValue) flag to base!", type: .flagEvent)
        
        self.session = session
        
        let isYourFlag = flagTeam == currentPlayer.team
        notificationService.notifyFlagReturned(
            team: flagTeam,
            returnedBy: currentPlayer.displayName,
            isYourFlag: isYourFlag
        )
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing player flag return: \(error)")
            }
        }
    }
    
    // Bring enemy flag to base (new system)
    // Note: Base = Team's half of the circle, Safe Zone = Circle at back of that half
    // This doesn't score points - it just brings the flag to base (team's half)
    // Win condition is checked separately: enemy flag at base AND own flag in safe zone
    func scorePlayerFlag(flagPlayerId: String) {
        guard var session = session,
              let currentPlayer = currentPlayer,
              let playerTeam = currentPlayer.team,
              let flagPlayer = session.players.first(where: { $0.id == flagPlayerId && $0.isFlag }),
              let flagTeam = flagPlayer.team else {
            return
        }
        
        // Verify this is an enemy flag
        guard flagTeam != playerTeam else { return }
        
        // Verify flag is captured by this player
        guard session.flagCarriers[flagPlayerId] == currentPlayer.id else { return }
        
        // Remove carrier - flag is now at base (not captured)
        // Flag doesn't reset - it stays at base location
        session.flagCarriers[flagPlayerId] = nil
        
        // Haptic feedback
        HapticFeedbackManager.shared.playerCaught()
        
        // Visual feedback
        catchAnimationTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.catchAnimationTrigger = false
        }
        
        lastCatchMessage = "🚩 \(playerTeam.rawValue) brought \(flagTeam.rawValue) flag to base!"
        announcementManager.post("\(playerTeam.rawValue) brought \(flagTeam.rawValue) flag to base!", type: .flagEvent)
        
        self.session = session
        
        // Immediately check win condition after scoring
        checkGameOver()
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing player flag score: \(error)")
            }
        }
    }
    
    // Capture a flag (legacy virtual flag system)
    func captureFlag(flagId: String) {
        guard var session = session,
              let currentPlayer = currentPlayer,
              let _ = currentPlayer.team,
              let flagIndex = session.flags.firstIndex(where: { $0.id == flagId }),
              session.flags[flagIndex].canBeCaptured(by: currentPlayer) else {
            print("❌ Cannot capture flag")
            return
        }
        
        var flag = session.flags[flagIndex]
        flag.isAtBase = false
        flag.carrierId = currentPlayer.id
        flag.captureTime = Date()
        // Update flag location to player location
        flag.latitude = currentPlayer.latitude
        flag.longitude = currentPlayer.longitude
        
        session.flags[flagIndex] = flag
        
        // Haptic feedback
        HapticFeedbackManager.shared.playerCaught()
        
        // Visual feedback
        catchAnimationTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.catchAnimationTrigger = false
        }
        
        lastCatchMessage = "🚩 Captured \(flag.team.rawValue) flag!"
        announcementManager.post("Captured \(flag.team.rawValue) flag!", type: .flagEvent)
        
        self.session = session
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing flag capture: \(error)")
            }
        }
    }
    
    // Return a flag to base
    func returnFlag(flagId: String) {
        guard var session = session,
              let currentPlayer = currentPlayer,
              let flagIndex = session.flags.firstIndex(where: { $0.id == flagId }),
              session.flags[flagIndex].canBeReturned(by: currentPlayer) else {
            print("❌ Cannot return flag")
            return
        }
        
        var flag = session.flags[flagIndex]
        flag.isAtBase = true
        flag.carrierId = nil
        flag.captureTime = nil
        // Reset flag to base location
        if flag.team == .teamA, let base = session.teamABase {
            flag.latitude = base.latitude
            flag.longitude = base.longitude
        } else if flag.team == .teamB, let base = session.teamBBase {
            flag.latitude = base.latitude
            flag.longitude = base.longitude
        }
        
        session.flags[flagIndex] = flag
        
        // Haptic feedback
        HapticFeedbackManager.shared.tagConfirmed()
        
        lastCatchMessage = "🚩 Returned \(flag.team.rawValue) flag!"
        announcementManager.post("Returned \(flag.team.rawValue) flag!", type: .flagEvent)
        
        self.session = session
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing flag return: \(error)")
            }
        }
    }
    
    // Score a flag (return enemy flag to your base)
    private func scoreFlag(flagId: String) {
        guard var session = session,
              let currentPlayer = currentPlayer,
              let playerTeam = currentPlayer.team,
              let flagIndex = session.flags.firstIndex(where: { $0.id == flagId }) else {
            return
        }
        
        let flag = session.flags[flagIndex]
        
        // Verify this is an enemy flag
        guard flag.team != playerTeam else { return }
        
        // Update score
        if playerTeam == .teamA {
            session.teamAScore += 1
        } else {
            session.teamBScore += 1
        }
        
        // Reset flag to its base
        var resetFlag = flag
        resetFlag.isAtBase = true
        resetFlag.carrierId = nil
        resetFlag.captureTime = nil
        if resetFlag.team == .teamA, let base = session.teamABase {
            resetFlag.latitude = base.latitude
            resetFlag.longitude = base.longitude
        } else if resetFlag.team == .teamB, let base = session.teamBBase {
            resetFlag.latitude = base.latitude
            resetFlag.longitude = base.longitude
        }
        
        session.flags[flagIndex] = resetFlag
        
        // Haptic feedback
        HapticFeedbackManager.shared.playerCaught()
        
        // Visual feedback
        catchAnimationTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.catchAnimationTrigger = false
        }
        
        lastCatchMessage = "🚩 \(playerTeam.rawValue) scored! (\(session.teamAScore)-\(session.teamBScore))"
        announcementManager.post("\(playerTeam.rawValue) scored! (\(session.teamAScore)-\(session.teamBScore))", type: .flagEvent)
        
        self.session = session
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing flag score: \(error)")
            }
        }
    }
    
    // Calculate distance and direction to nearest hunter/hider or zombie/human
    private func calculateDistances(currentLocation: CLLocation, session: GameSession) {
        guard let currentPlayer = currentPlayer else { return }
        
        // Validate current location
        guard isValidCoordinate(currentLocation.coordinate) else {
            print("⚠️ Invalid current location in calculateDistances - skipping")
            return
        }
        
        let isZombieTag = session.gameType == .zombieTag
        
        var minHunterDistance: Double?
        var minHiderDistance: Double?
        var minZombieDistance: Double?
        var minHumanDistance: Double?
        var nearestHunter: Player?
        var nearestHider: Player?
        var nearestZombie: Player?
        var nearestHuman: Player?
        
        for player in session.players where player.id != currentPlayer.id && player.isAlive {
            // Validate player location
            guard isValidCoordinate(player.coordinate) else {
                print("⚠️ Invalid location for player \(player.displayName) - skipping")
                continue
            }
            
            let distance = currentLocation.distance(from: player.location)
            
            // Validate distance is finite
            guard distance.isFinite && distance >= 0 else {
                print("⚠️ Invalid distance calculation for player \(player.displayName) - skipping")
                continue
            }
            
            if isZombieTag {
                // Zombie Tag: Track zombies and humans
                if player.role == .zombie {
                    if let currentMin = minZombieDistance {
                        if distance < currentMin {
                            minZombieDistance = distance
                            nearestZombie = player
                        }
                    } else {
                        minZombieDistance = distance
                        nearestZombie = player
                    }
                } else if player.role == .human {
                    if let currentMin = minHumanDistance {
                        if distance < currentMin {
                            minHumanDistance = distance
                            nearestHuman = player
                        }
                    } else {
                        minHumanDistance = distance
                        nearestHuman = player
                    }
                }
            } else {
                // Manhunt: Track hunters and hiders
            if player.role == .hunter {
                if let currentMin = minHunterDistance {
                    if distance < currentMin {
                        minHunterDistance = distance
                        nearestHunter = player
                    }
                } else {
                    minHunterDistance = distance
                    nearestHunter = player
                }
            } else if player.role == .hider {
                if let currentMin = minHiderDistance {
                    if distance < currentMin {
                        minHiderDistance = distance
                        nearestHider = player
                    }
                } else {
                    minHiderDistance = distance
                    nearestHider = player
                    }
                }
            }
        }
        
        if isZombieTag {
            // For zombie tag, use zombie/human distances
            nearestHunterDistance = minZombieDistance
            nearestHiderDistance = minHumanDistance
            nearestHunterId = nearestZombie?.id
            nearestHiderId = nearestHuman?.id
            
            // Calculate bearing to nearest zombie/human
            if let zombie = nearestZombie, let distance = minZombieDistance, distance > 0 {
                let bearing = currentLocation.bearing(to: zombie.location)
                nearestHunterDirection = bearing
            } else {
                nearestHunterDirection = nil
            }
            
            if let human = nearestHuman, let distance = minHumanDistance, distance > 0 {
                let bearing = currentLocation.bearing(to: human.location)
                nearestHiderDirection = bearing
            } else {
                nearestHiderDirection = nil
            }
        } else {
            // For manhunt, use hunter/hider distances
        nearestHunterDistance = minHunterDistance
        nearestHiderDistance = minHiderDistance
        nearestHunterId = nearestHunter?.id
        nearestHiderId = nearestHider?.id
        
        // Calculate bearing (direction) to nearest threats
        if let hunter = nearestHunter, let distance = minHunterDistance, distance > 0 {
            let bearing = currentLocation.bearing(to: hunter.location)
            nearestHunterDirection = bearing
        } else {
            nearestHunterDirection = nil
        }
        
        if let hider = nearestHider, let distance = minHiderDistance, distance > 0 {
            let bearing = currentLocation.bearing(to: hider.location)
            nearestHiderDirection = bearing
        } else {
            nearestHiderDirection = nil
            }
        }
    }
    
    // Update proximity warnings for hiders/humans when hunters/zombies are nearby
    private func updateProximityWarnings(currentLocation: CLLocation, session: GameSession) {
        guard let currentPlayer = currentPlayer,
              currentPlayer.isAlive else {
            proximityWarningLevel = .none
            proximityWarningDistance = nil
            return
        }
        
        // Check if current player should receive warnings
        let shouldWarn: Bool
        if session.gameType == .zombieTag {
            // Zombie Tag: Humans get warnings about zombies
            shouldWarn = (currentPlayer.role == .human)
        } else {
            // Manhunt: Hiders get warnings about hunters
            shouldWarn = (currentPlayer.role == .hider)
        }
        
        guard shouldWarn else {
            proximityWarningLevel = .none
            proximityWarningDistance = nil
            return
        }
        
        // Validate current location
        guard isValidCoordinate(currentLocation.coordinate) else {
            print("⚠️ Invalid current location in updateProximityWarnings - skipping")
            proximityWarningLevel = .none
            proximityWarningDistance = nil
            return
        }
        
        // Find nearest threat (hunter or zombie)
        var minDistance: Double?
        let threatRole: PlayerRole = session.gameType == .zombieTag ? .zombie : .hunter
        for player in session.players where player.role == threatRole && player.isAlive {
            // Validate player location
            guard isValidCoordinate(player.coordinate) else {
                print("⚠️ Invalid location for hunter \(player.displayName) - skipping")
                continue
            }
            
            let distance = currentLocation.distance(from: player.location)
            
            // Validate distance
            guard distance.isFinite && distance >= 0 else {
                print("⚠️ Invalid distance to hunter \(player.displayName) - skipping")
                continue
            }
            
            if minDistance == nil || distance < minDistance! {
                minDistance = distance
            }
        }
        
        proximityWarningDistance = minDistance
        
        // Set warning level based on distance
        if let distance = minDistance {
            if distance < 10 {
                proximityWarningLevel = .danger
                // Flash screen when very close
                shouldFlashScreen = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.shouldFlashScreen = false
                }
                // Strong haptic feedback
                HapticFeedbackManager.shared.dangerProximity()
            } else if distance < 20 {
                proximityWarningLevel = .warning
                // Medium haptic feedback
                HapticFeedbackManager.shared.proximityWarning(distance: distance)
            } else if distance < 50 {
                proximityWarningLevel = .caution
                // Light haptic feedback
                HapticFeedbackManager.shared.proximityWarning(distance: distance)
            } else {
                proximityWarningLevel = .safe
            }
        } else {
            proximityWarningLevel = .none
        }
    }
    
    // MARK: - BLE Tagging
    
    func requestTag(playerId: String) {
        guard let session = session,
              let currentPlayer = currentPlayer,
              let target = session.players.first(where: { $0.id == playerId }),
              currentPlayer.isAlive,
              target.isAlive else {
            print("❌ Cannot request tag: missing or inactive player")
            return
        }

        let validRoles = (session.gameType == .manhunt && currentPlayer.role == .hunter && target.role == .hider) ||
                         (session.gameType == .zombieTag && currentPlayer.role == .zombie && target.role == .human)
        guard validRoles else {
            print("❌ Cannot request tag: invalid roles")
            return
        }

        guard canTagPlayerId == playerId,
              isValidTagAttempt(tagger: currentPlayer, target: target, session: session) else {
            print("❌ Cannot request tag: target is not in confirmed range")
            return
        }

        bluetoothTagService.requestTag(playerId: playerId)
    }
    
    func confirmTag(playerId: String) {
        bluetoothTagService.confirmTag(playerId: playerId)
    }
    
    func rejectTag() {
        let taggerId = pendingTagRequest?.fromPlayerId
        bluetoothTagService.rejectTag(toTaggerPlayerId: taggerId)
        pendingTagRequest = nil
    }

    private func handleTagRejected(byPlayerId rejectorId: String) {
        guard let session = session,
              let currentPlayer = currentPlayer,
              currentPlayer.role == .hunter,
              currentPlayer.isAlive else { return }
        guard session.players.contains(where: { $0.id == rejectorId && $0.role == .hider }) else { return }
        surfaceTagDeniedByTarget("Target denied the tag.")
    }

    /// Publish a short-lived message for hunters when a hider rejects their tag.
    private func surfaceTagDeniedByTarget(_ message: String) {
        tagDeniedByTargetMessage = message
        tagDeniedByTargetClearTask?.cancel()
        tagDeniedByTargetClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run { [weak self] in
                self?.tagDeniedByTargetMessage = nil
            }
        }
    }

    /// Host removes an alive Manhunt player (disconnect ghost/manual moderator action).
    /// Hiders still use the zone catch transaction so member-level catch rules remain narrow;
    /// hunters require a host-only full session update because the normal elimination path
    /// intentionally protects hunters from automatic zone/tag elimination.
    func hostEliminatePlayer(playerId: String) {
        guard isCurrentPlayerSessionHost(),
              let session = session,
              session.gameState == .active,
              session.gameType == .manhunt,
              let target = session.players.first(where: { $0.id == playerId }),
              (target.role == .hider || target.role == .hunter),
              target.isAlive else {
            print("⚠️ hostEliminatePlayer ignored: invalid host, session, or target")
            return
        }

        let displayName = target.displayName
        if target.role == .hunter {
            hostRemoveManhuntHunter(playerId)
        } else {
            eliminatePlayer(playerId)
        }
        announcementManager.post("Host removed \(displayName) from the game.", type: .playerEliminated)
        checkGameOver()
    }

    private func hostRemoveManhuntHunter(_ playerId: String) {
        guard var session = session,
              session.gameType == .manhunt,
              var player = session.players.first(where: { $0.id == playerId && $0.role == .hunter && $0.isAlive }) else { return }

        player.isAlive = false
        guard let index = session.players.firstIndex(where: { $0.id == playerId }) else { return }
        session.players[index] = player

        if playerId == currentPlayer?.id {
            HapticFeedbackManager.shared.playerEliminated()
            eliminationAnimationTrigger = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.eliminationAnimationTrigger = false
            }
            lastEliminationMessage = "You were removed from the game by the host."
            currentPlayer = player
            locationService.stop()
        } else {
            lastEliminationMessage = "\(player.displayName) was removed from the game by the host."
        }

        self.session = session

        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing host hunter removal to Firestore: \(error)")
            }
        }
    }
    
    private func handleTagRequest(fromPlayerId: String, fromPlayerName: String) {
        guard let session = session,
              let currentPlayer = currentPlayer else {
            print("❌ Invalid tag request: missing session/player data")
            surfaceTagRequestRejection("Tag request ignored: not in an active game.")
            return
        }
        guard currentPlayer.isAlive else {
            print("❌ Invalid tag request: you are already eliminated")
            surfaceTagRequestRejection("Tag request ignored: you're already out.")
            return
        }
        guard let fromPlayer = session.players.first(where: { $0.id == fromPlayerId }) else {
            print("❌ Invalid tag request: unknown sender")
            surfaceTagRequestRejection("Tag request ignored: unknown sender.")
            return
        }
        
        let isValidManhunt = fromPlayer.role == .hunter && currentPlayer.role == .hider
        let isValidZombie = fromPlayer.role == .zombie && currentPlayer.role == .human
        
        guard isValidManhunt || isValidZombie else {
            print("❌ Invalid tag request: incompatible roles (\(fromPlayer.role) -> \(currentPlayer.role))")
            surfaceTagRequestRejection("Tag from \(fromPlayerName) ignored: wrong role.")
            return
        }

        guard isValidTagAttempt(tagger: fromPlayer, target: currentPlayer, session: session) else {
            print("❌ Invalid tag request: players are not close enough")
            surfaceTagRequestRejection("Tag from \(fromPlayerName) ignored: not close enough.")
            return
        }
        
        let request = BluetoothTagService.TagRequest(
            id: UUID().uuidString,
            fromPlayerId: fromPlayerId,
            fromPlayerName: fromPlayerName,
            timestamp: Date()
        )
        
        pendingTagRequest = request
        
        // Haptic feedback for tag request
        HapticFeedbackManager.shared.tagRequest()
        
        print("📥 Tag request received from \(fromPlayerName)")
    }
    
    /// Publish a short-lived rejection message so the UI can show a toast.
    /// The message clears automatically after 4 seconds.
    private func surfaceTagRequestRejection(_ message: String) {
        tagRequestRejectedMessage = message
        tagRequestRejectedClearTask?.cancel()
        tagRequestRejectedClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run { [weak self] in
                self?.tagRequestRejectedMessage = nil
            }
        }
    }
    
    private func handleTagConfirmed(playerId: String) {
        // Idempotency: a confirmed tag may arrive twice, once from our own
        // local `confirmTag` callback (confirmer side) and once from the
        // remote write/notify on the tagger's side. Skip if we've already
        // recorded this player as caught, or they're no longer alive.
        if caughtPlayers.contains(playerId) {
            pendingTagRequest = nil
            canTagPlayerId = nil
            return
        }
        if let target = session?.players.first(where: { $0.id == playerId }),
           !target.isAlive {
            pendingTagRequest = nil
            canTagPlayerId = nil
            return
        }
        
        // Haptic feedback for tag confirmation
        HapticFeedbackManager.shared.tagConfirmed()
        
        // Tag was confirmed - catch the player
        catchPlayer(playerId)
        pendingTagRequest = nil
        canTagPlayerId = nil
    }
    
    private func eliminatePlayer(_ playerId: String) {
        guard var session = session,
              var player = session.players.first(where: { $0.id == playerId }) else { return }

        // CTF: Players cannot be eliminated
        if session.gameType == .captureTheFlag {
            // Handle flag player leaving
            handleFlagPlayerLeaving(leavingPlayerId: playerId, session: &session)
            self.session = session
            print("⚠️ CTF: Players cannot be eliminated - only handling flag state")
            return
        }

        // Edge case: Hunters and zombies cannot be eliminated (they can only be caught/tagged)
        guard player.role != .hunter && player.role != .zombie else {
            print("⚠️ Attempted to eliminate \(player.role == .hunter ? "hunter" : "zombie") \(player.displayName) - cannot be eliminated")
            return
        }

        let isManhuntHider = session.gameType == .manhunt && player.role == .hider

        if isManhuntHider, session.firstTaggedPlayerId == nil {
            session.firstTaggedPlayerId = playerId
            print("🏷️ First tagged player (zone elimination): \(player.displayName) (will be hunter next game)")
        }

        player.isAlive = false

        if let index = session.players.firstIndex(where: { $0.id == playerId }) {
            session.players[index] = player
        }

        // Haptic feedback for elimination
        if playerId == currentPlayer?.id {
            HapticFeedbackManager.shared.playerEliminated()
            // Visual feedback: trigger elimination animation
            eliminationAnimationTrigger = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.eliminationAnimationTrigger = false
            }
        }

        // Set elimination message for UI feedback
        if playerId == currentPlayer?.id {
            lastEliminationMessage = "You were eliminated! You left the bubble."
            announcementManager.post("You were eliminated! You left the bubble.", type: .playerEliminated)
            currentPlayer = player
            locationService.stop()
        } else {
            lastEliminationMessage = "\(player.displayName) was eliminated!"
            announcementManager.post("\(player.displayName) was eliminated!", type: .playerEliminated)
        }

        self.session = session

        // Manhunt OOB / zone elimination of a hider goes through the
        // same narrow catch transaction as a BLE/honor tag so non-hosts
        // (the common case once the host is a hider) don't have their
        // write rejected by Firestore rules.
        if isManhuntHider,
           !isRunningUnitTests,
           let callerId = currentPlayer?.id {
            let sessionId = session.id
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    _ = try await self.firestoreService.commitManhuntCatch(
                        sessionId: sessionId,
                        callerPlayerId: callerId,
                        targetPlayerId: playerId,
                        kind: .zone
                    )
                } catch {
                    self.print("❌ Error syncing elimination to Firestore: \(error.localizedDescription)")
                }
            }
            return
        }

        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing elimination to Firestore: \(error)")
            }
        }
    }
    
    // Check if a player is within any safe zone
    private func isPlayerInSafeZone(_ player: Player, in session: GameSession) -> Bool {
        let playerLocation = player.location
        
        // Check Team A safe zone
        if let safeZone = session.teamASafeZone {
            let safeZoneLocation = CLLocation(latitude: safeZone.center.latitude, longitude: safeZone.center.longitude)
            let distance = playerLocation.distance(from: safeZoneLocation)
            if distance.isFinite && distance >= 0 && distance <= safeZone.radius {
                return true
            }
        }
        
        // Check Team B safe zone
        if let safeZone = session.teamBSafeZone {
            let safeZoneLocation = CLLocation(latitude: safeZone.center.latitude, longitude: safeZone.center.longitude)
            let distance = playerLocation.distance(from: safeZoneLocation)
            if distance.isFinite && distance >= 0 && distance <= safeZone.radius {
                return true
            }
        }
        
        return false
    }
    
    /// How a Manhunt catch was initiated. The post-catch shared mutation
    /// branches on this for stats and announcement copy:
    /// - `.bluetooth` writes a normal `GameStats.CatchRecord` for the hunter.
    /// - `.honor` is the hider confirming a tag Bluetooth missed; survival time
    ///   only, no fake hunter row in stats.
    enum CatchSource {
        case bluetooth(tagger: Player)
        case honor
    }

    private func catchPlayer(_ playerId: String) {
        guard var session = session,
              var player = session.players.first(where: { $0.id == playerId }) else { return }
        
        // CTF: Check if player is in a safe zone - cannot be tagged in safe zones
        if session.gameType == .captureTheFlag {
            if isPlayerInSafeZone(player, in: session) {
                print("🛡️ Player \(player.displayName) is in a safe zone - cannot be tagged!")
                return
            }
        }
        
        // Check if this is zombie tag or manhunt
        let isZombieTag = session.gameType == .zombieTag
        let tagger = currentPlayer

        if session.gameType != .captureTheFlag,
           let tagger = tagger,
           !isValidTagAttempt(tagger: tagger, target: player, session: session) {
            print("⚠️ Tag confirmation rejected: target is no longer in range")
            return
        }
        
        // Manhunt: route through the shared `applyManhuntHiderCaught` helper
        // so manual tag confirms and BLE-confirmed tags converge on a single
        // mutation path.
        if session.gameType == .manhunt {
            guard let hunter = tagger, hunter.role == .hunter else {
                print("⚠️ Only hunters can tag in manhunt")
                return
            }
            guard playerId != hunter.id else {
                print("⚠️ Attempted to catch self - ignoring")
                return
            }
            guard player.role == .hider else {
                print("⚠️ Attempted to catch hunter \(player.displayName) - only hiders can be caught")
                return
            }
            guard player.isAlive else {
                print("⚠️ Attempted to catch already eliminated player \(player.displayName)")
                return
            }
            applyManhuntHiderCaught(playerId, source: .bluetooth(tagger: hunter))
            return
        }
        
        if isZombieTag {
            // Zombie Tag: Zombie tags human, human becomes zombie
            guard let zombie = tagger,
                  zombie.role == .zombie else {
                print("⚠️ Only zombies can tag in zombie tag")
                return
            }
            
            // Edge case: Cannot tag yourself
            guard playerId != zombie.id else {
                print("⚠️ Attempted to tag self - ignoring")
                return
            }
            
            // Edge case: Cannot tag other zombies (only humans can be tagged)
            guard player.role == .human else {
                print("⚠️ Attempted to tag zombie \(player.displayName) - only humans can be tagged")
                return
            }
            
            // Edge case: Cannot tag already eliminated players
            guard player.isAlive else {
                print("⚠️ Attempted to tag already eliminated player \(player.displayName)")
                return
            }
            
            // Convert human to zombie (don't eliminate, just change role)
            player.role = .zombie
            print("🧟 \(player.displayName) has been infected and is now a zombie!")
        } else if session.gameType == .captureTheFlag {
            // CTF: Players cannot be eliminated
            // When a flag carrier is tagged, the flag does NOT automatically drop.
            // The flag stealer must physically give the phone back to the team,
            // and the team manually returns the flag in the app (calls returnPlayerFlag).
            // If flag player is tagged, drop the flag (flag player can be tagged)
            if player.isFlag {
                session.flagCarriers[playerId] = nil
                print("🚩 Flag player \(player.displayName) was tagged - flag dropped!")
            } else {
                // Flag carrier was tagged - flag remains captured until defender takes possession
                if let (_, _) = session.flagCarriers.first(where: { $0.value == playerId }) {
                    print("🚩 Flag carrier \(player.displayName) was tagged - defender must take possession!")
                    // Flag stays captured - defender needs to take possession via button
                    // Don't change flagCarriers here - defender will call takePossessionOfFlag()
                }
            }
            // Don't eliminate player in CTF
            if let index = session.players.firstIndex(where: { $0.id == playerId }) {
                session.players[index] = player
            }
            self.session = session
            return // Exit early - no elimination in CTF
        } else {
            // Manhunt was handled above by `applyManhuntHiderCaught`; any
            // other game types fall through to the shared post-catch logic
            // below without elimination.
            return
        }
        
        if let index = session.players.firstIndex(where: { $0.id == playerId }) {
            session.players[index] = player
        }
        
        caughtPlayers.append(playerId)
        
        // Track first tagged player (for next game's hunter assignment)
        if session.firstTaggedPlayerId == nil {
            session.firstTaggedPlayerId = playerId
            print("🏷️ First tagged player: \(player.displayName) (will be hunter next game)")
        }
        
        // Haptic feedback for catch
        HapticFeedbackManager.shared.playerCaught()
        
        // Visual feedback: trigger catch animation
        catchAnimationTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.catchAnimationTrigger = false
        }
        
        // Update game stats, Zombie Tag uses the standard CatchRecord shape
        // (the "hunter" is the zombie that converted the human).
        if var stats = gameStats, let tagger = tagger {
            let catchRecord = GameStats.CatchRecord(
                id: UUID().uuidString,
                hunterId: tagger.id,
                hunterName: tagger.displayName,
                hiderId: player.id,
                hiderName: player.displayName,
                timestamp: Date()
            )
            stats.catches.append(catchRecord)
            let survivalTime = Date().timeIntervalSince(stats.gameStartTime)
            stats.survivalTimes[playerId] = survivalTime
            gameStats = stats
        }
        
        // Zombie Tag message + announcement.
        if let currentPlayer = currentPlayer, currentPlayer.role == .zombie {
            lastCatchMessage = "🧟 Infected \(player.displayName)!"
            announcementManager.post("Infected \(player.displayName)!", type: .playerTagged)
        } else if playerId == currentPlayer?.id {
            lastCatchMessage = "You were infected by a zombie!"
            announcementManager.post("You were infected by a zombie!", type: .playerTagged)
        } else {
            lastCatchMessage = "🧟 \(player.displayName) has been infected!"
            announcementManager.post("\(player.displayName) has been infected!", type: .playerTagged)
        }
        
        self.session = session
        
        // Sync to Firestore
        Task {
            do {
                try await firestoreService.updateSession(session)
            } catch {
                print("❌ Error syncing catch to Firestore: \(error)")
            }
        }
    }
    
    // MARK: - Shared Manhunt catch mutation
    //
    // Single mutation path used by both BLE-confirmed tags and manual
    // hider confirms when BLE missed the tag. Callers must do their own gating
    // (hunter+proximity for BLE, alive-hider-self for manual) before invoking this.
    private func applyManhuntHiderCaught(_ playerId: String, source: CatchSource) {
        guard var session = session,
              var player = session.players.first(where: { $0.id == playerId }) else { return }
        guard session.gameType == .manhunt else { return }
        guard player.role == .hider else { return }
        guard player.isAlive else { return }

        // Local optimistic update so the tagger's own UI updates without
        // waiting for the round-trip. The authoritative Firestore write
        // happens through `commitManhuntCatch`, which Firestore rules let
        // non-hosts perform (unlike a broad `updateSession`).
        player.isAlive = false
        if let index = session.players.firstIndex(where: { $0.id == playerId }) {
            session.players[index] = player
        }

        caughtPlayers.append(playerId)

        if session.firstTaggedPlayerId == nil {
            session.firstTaggedPlayerId = playerId
            print("🏷️ First tagged player: \(player.displayName) (will be hunter next game)")
        }

        HapticFeedbackManager.shared.playerCaught()

        catchAnimationTrigger = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.catchAnimationTrigger = false
        }

        // Stats. BLE writes a normal CatchRecord with hunter attribution.
        // Manual confirm (honor) records survival time only, no fake hunter row.
        if var stats = gameStats {
            switch source {
            case .bluetooth(let tagger):
                let catchRecord = GameStats.CatchRecord(
                    id: UUID().uuidString,
                    hunterId: tagger.id,
                    hunterName: tagger.displayName,
                    hiderId: player.id,
                    hiderName: player.displayName,
                    timestamp: Date()
                )
                stats.catches.append(catchRecord)
            case .honor:
                break
            }
            let survivalTime = Date().timeIntervalSince(stats.gameStartTime)
            stats.survivalTimes[playerId] = survivalTime
            gameStats = stats
        }

        // Message + announcement, branched by source so the feed reads
        // naturally for both flows.
        switch source {
        case .bluetooth:
            if let currentPlayer = currentPlayer, currentPlayer.role == .hunter {
                lastCatchMessage = "🎯 Caught \(player.displayName)!"
                announcementManager.post("Caught \(player.displayName)!", type: .playerTagged)
            } else if playerId == currentPlayer?.id {
                lastCatchMessage = "You were caught by a hunter!"
                announcementManager.post("You were caught by a hunter!", type: .playerTagged)
            } else {
                lastCatchMessage = "\(player.displayName) was caught!"
                announcementManager.post("\(player.displayName) was caught!", type: .playerTagged)
            }
        case .honor:
            if playerId == currentPlayer?.id {
                lastCatchMessage = "You were tagged."
                announcementManager.post("You were tagged.", type: .playerTagged)
            } else {
                lastCatchMessage = "\(player.displayName) was tagged."
                announcementManager.post("\(player.displayName) was tagged.", type: .playerTagged)
            }
        }

        self.session = session

        guard !isRunningUnitTests,
              let callerId = currentPlayer?.id else {
            return
        }

        let kind: FirestoreService.ManhuntCatchKind = {
            switch source {
            case .bluetooth: return .bluetooth
            case .honor: return .honor
            }
        }()

        Task { [weak self] in
            guard let self = self else { return }
            do {
                _ = try await self.firestoreService.commitManhuntCatch(
                    sessionId: session.id,
                    callerPlayerId: callerId,
                    targetPlayerId: playerId,
                    kind: kind
                )
            } catch {
                self.print("❌ Error syncing catch to Firestore: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Manual tag confirm (Bluetooth backup)
    
    /// Hider confirms they were tagged when BLE didn’t register it. Bypasses
    /// hunter / proximity validation but reuses the shared catch mutation so
    /// caught state, announcements, and Firestore sync stay consistent.
    ///
    /// Manhunt only in v1. Returns silently for unsupported configurations so
    /// callers can wire it up speculatively from the UI.
    func honorReportTagged() {
        guard let session = session,
              session.gameType == .manhunt,
              let me = currentPlayer,
              me.role == .hider,
              me.isAlive
        else {
            print("⚠️ honorReportTagged ignored: not an alive Manhunt hider")
            return
        }
        applyManhuntHiderCaught(me.id, source: .honor)
    }
    
    #if DEBUG
    /// Detach Firestore listener so unit tests are not overwritten by async snapshots.
    func testing_stopSessionListener() {
        stopSessionListener()
    }

    /// Unit-test hook for the active-game presence heartbeat.
    func testing_sendPresenceHeartbeat() {
        sendPresenceHeartbeat()
    }

    /// Unit-test hook for disconnect / presence policy.
    func testing_checkForDisconnectedPlayers() {
        guard let session = session else { return }
        checkForDisconnectedPlayers(session: session)
    }

    /// Unit-test hook for local zone status.
    func testing_checkOutOfBounds() {
        checkOutOfBounds()
    }

    func testing_advanceOutOfBoundsGrace(by seconds: TimeInterval) {
        guard let started = outOfBoundsGraceStartedAt else { return }
        outOfBoundsGraceStartedAt = started.addingTimeInterval(-seconds)
    }

    /// Unit-test hook for BLE tag GPS sanity validation.
    func testing_isValidTagAttempt(taggerId: String, targetId: String) -> Bool {
        guard let session = session,
              let tagger = session.players.first(where: { $0.id == taggerId }),
              let target = session.players.first(where: { $0.id == targetId }) else {
            return false
        }
        return isValidTagAttempt(tagger: tagger, target: target, session: session)
    }

    /// Unit-test hook for host-only game-over signaling.
    func testing_signalGameOverDetected() {
        signalGameOverDetected()
    }

    /// Runs the same hunter assignment branch as `beginGame()` without starting the match.
    func testing_assignManhuntHunters() {
        guard var session = session, session.gameType == .manhunt else { return }
        if session.gameNumber == 1 {
            assignRandomHunters(session: &session, count: session.hunterCount)
        } else {
            assignHuntersFromFirstTagged(session: &session, count: session.hunterCount)
        }
        self.session = session
    }

    /// Hunter-side BLE catch path for unit tests (`applyManhuntHiderCaught` + `CatchRecord`).
    func testing_simulateManhuntBleCatch(hiderId: String) {
        guard let session = session,
              session.gameType == .manhunt,
              let hunter = currentPlayer,
              hunter.role == .hunter,
              session.players.contains(where: { $0.id == hiderId && $0.role == .hider && $0.isAlive })
        else {
            print("⚠️ testing_simulateManhuntBleCatch ignored: invalid session, hunter, or hider")
            return
        }
        applyManhuntHiderCaught(hiderId, source: .bluetooth(tagger: hunter))
    }
    #endif
    
    // MARK: - Timer
    
    private func startUpdateTimer() {
        stopUpdateTimer()
        // New zone system: Use faster local ticks while closing for smooth rendering.
        // Legacy system uses 2.0s updates
        let interval: TimeInterval = {
            if let bubble = session?.bubble, bubble.usesNewZoneSystem {
                let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble)
                return runtimeState.phaseState == .closing ? 0.1 : 0.5
            } else {
                return 2.0 // Legacy system
            }
        }()
        updateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                // Batch updates to reduce UI churn
                if let session = self.session {
                    self.checkForDisconnectedPlayers(session: session)
                }
                // Use new zone system if enabled, otherwise use legacy
                if self.session?.bubble?.usesNewZoneSystem ?? false {
                    self.updateZoneSystem()
                } else {
                    self.checkAndApplyShrinks()
                }
                self.checkOutOfBounds()
                self.checkProximityCatches()
                self.checkGameOver()
            }
        }
        // Add timer to main run loop
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }

        // Manhunt / Zombie Tag: keep GPS alive even when the player is
        // standing still, and start the presence heartbeat so stationary
        // hiders stay visibly connected to other clients.
        if let session = session,
           session.gameState == .active,
           session.gameType == .manhunt || session.gameType == .zombieTag {
            locationService.setGameplayKeepAlive(true)
            startPresenceHeartbeat()
            ScreenWakeLock.setEnabled(true)
        }
    }
    
    // MARK: - Zone System (New)
    
    /// Updates the derived runtime zone cache without mutating the authoritative schedule.
    private func updateZoneSystem() {
        guard var session = session,
              var bubble = session.bubble,
              session.gameState == .active else { return }
        
        let previousPhaseState: RuntimeZonePhaseState = {
            if bubble.isClosing {
                return .closing
            } else if bubble.warningStartTime != nil {
                return .rotation
            } else {
                return .openingGrace
            }
        }()
        let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: Date())
        ZoneService.applyRuntimeState(runtimeState, to: &bubble)
        session.bubble = bubble
        self.session = session
        
        if previousPhaseState != runtimeState.phaseState {
            shouldPulseBubble = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.shouldPulseBubble = false
            }
            HapticFeedbackManager.shared.zoneShrink()
            startUpdateTimer()
        }
    }
    
    // MARK: - Legacy Zone System
    
    // Check if a shrink event should occur and apply it (LEGACY SYSTEM)
    private func checkAndApplyShrinks() {
        guard var session = session,
              var bubble = session.bubble,
              session.gameState == .active else { return }
        
        guard bubble.enableShrinking,
              !bubble.usesNewZoneSystem,
              session.gameType == .captureTheFlag else {
            return
        }
        
        // Validate bubble parameters before processing
        guard bubble.startRadius.isFinite && bubble.startRadius > 0,
              bubble.shrinkInterval.isFinite && bubble.shrinkInterval > 0,
              bubble.duration.isFinite && bubble.duration > 0 else {
            print("⚠️ Invalid bubble parameters in checkAndApplyShrinks - skipping")
            return
        }
        
        let currentPhase = bubble.currentPhase()
        let lastShrinkPhase = bubble.shrinkHistory.last?.phase ?? -1
        
        // If we've entered a new phase, calculate and apply the shrink
        if currentPhase > lastShrinkPhase {
            bubble.calculateNextShrink()
            
            // Validate new bubble state
            let newRadius = bubble.currentRadius(at: Date())
            guard newRadius.isFinite && newRadius > 0 else {
                print("⚠️ Invalid bubble radius after shrink - reverting")
                return
            }
            
            guard isValidCoordinate(bubble.currentCenter(at: Date())) else {
                print("⚠️ Invalid bubble center after shrink - reverting")
                return
            }
            
            // Visual feedback: pulse bubble on shrink
            shouldPulseBubble = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.shouldPulseBubble = false
            }
            
            // Haptic feedback for zone shrink
            HapticFeedbackManager.shared.zoneShrink()
            session.bubble = bubble
            self.session = session
            
            // Haptic feedback for zone shrink
            HapticFeedbackManager.shared.zoneShrink()
            
            // Sync to Firestore so all players see the new zone
            Task {
                do {
                    try await firestoreService.updateSession(session)
                    print("✅ Zone shrunk to phase \(currentPhase), new center: \(bubble.currentCenter().latitude), \(bubble.currentCenter().longitude)")
                } catch {
                    print("❌ Error syncing shrink to Firestore: \(error)")
                }
            }
        }
    }
    
    /// Elapsed match time for Manhunt/Zombie Tag. Nil during pre-game countdown while
    /// `bubble.startTime` is still in the future (including `Date.distantFuture`).
    private func elapsedSinceMatchStart(for bubble: Bubble, now: Date = Date()) -> TimeInterval? {
        guard bubble.startTime <= now else { return nil }
        let elapsed = now.timeIntervalSince(bubble.startTime)
        guard elapsed.isFinite, elapsed >= 0 else { return nil }
        return elapsed
    }
    
    // MARK: - Game Over Detection

    /// Host sets `shouldEndGame` so `handleGameOver` → `endGame()` writes
    /// Firestore. Non-hosts only set `awaitingServerGameEnd` and wait for
    /// the listener — avoids local `.ended` ahead of the authoritative write.
    private func signalGameOverDetected() {
        if isCurrentPlayerSessionHost() {
            shouldEndGame = true
        } else {
            awaitingServerGameEnd = true
            print("🏁 Game over detected locally; waiting for host to end session")
        }
    }
    
    func checkGameOver() {
        guard let session = session,
              session.gameState == .active,
              let bubble = session.bubble else { return }
        
        #if DEBUG
        if session.players.count <= 1 {
            print("🧪 Testing mode: Skipping game over checks (solo player)")
            return
        }
        #endif
        
        // Check win conditions based on game type
        if session.gameType == .captureTheFlag {
            // CTF: Skip time validation - no time limit, no shrinking
        } else {
            // Only validate duration if it's finite (infinite duration means no time limit)
            if bubble.duration.isFinite {
                guard bubble.duration > 0 else {
                    print("⚠️ Invalid bubble duration - skipping time check")
                    return
                }
            }
        }
        
        // For Manhunt/Zombie, time-limit checks must use elapsed only after the host has committed
        // `bubble.startTime` in `startGameTimer()` (or joined clients received it). Before that,
        // `beginGame` uses `Date.distantFuture` so pre-countdown is not counted as match time.
        let elapsedSinceMatchStart: TimeInterval? = session.gameType == .captureTheFlag
            ? nil
            : self.elapsedSinceMatchStart(for: bubble)
        
        // Check win conditions based on game type
        if session.gameType == .zombieTag {
            // Zombie Tag win conditions
            let humans = session.players.filter { $0.role == .human && $0.isAlive }
            
            // Zombies win if all humans are infected
            if humans.isEmpty {
                print("🧟 All humans infected - zombies win!")
                signalGameOverDetected()
                return
            }
            
            // Check if time is up (only if duration is finite - humans win if time runs out)
            if bubble.duration.isFinite,
               let elapsed = elapsedSinceMatchStart,
               elapsed >= bubble.duration {
                print("⏰ Time's up - humans win!")
                signalGameOverDetected()
                return
            }
        } else if session.gameType == .captureTheFlag {
            // CTF win conditions: A team wins when BOTH flags are together in that team's safe zone
            // There are only 2 flags - not a points-based system. Flags don't reset.
            // Game ends when both flags are in a single safe zone on either team.
            // CTF has no time limit and no shrinking zone.
            
            // Get both flag players
            let teamAFlag = session.players.first { $0.team == .teamA && $0.isFlag }
            let teamBFlag = session.players.first { $0.team == .teamB && $0.isFlag }
            
            guard let flagA = teamAFlag, let flagB = teamBFlag else { return }
            
            let flagALocation = flagA.location
            let flagBLocation = flagB.location
            
            // Check if Team A wins: Both flags are in Team A safe zone
            var teamAWins = false
            var teamAWinsTimestamp: Date? = nil
            if let teamASafeZone = session.teamASafeZone {
                let safeZoneLocation = CLLocation(latitude: teamASafeZone.center.latitude, longitude: teamASafeZone.center.longitude)
                
                let distanceFlagAToSafeZone = flagALocation.distance(from: safeZoneLocation)
                let distanceFlagBToSafeZone = flagBLocation.distance(from: safeZoneLocation)
                
                if distanceFlagAToSafeZone.isFinite && distanceFlagBToSafeZone.isFinite &&
                   distanceFlagAToSafeZone <= teamASafeZone.radius &&
                   distanceFlagBToSafeZone <= teamASafeZone.radius {
                    teamAWins = true
                    teamAWinsTimestamp = Date() // Record when win condition was met
                    print("🚩 Team A win condition met! Both flags are in Team A safe zone")
                }
            }
            
            // Check if Team B wins: Both flags are in Team B safe zone
            var teamBWins = false
            var teamBWinsTimestamp: Date? = nil
            if let teamBSafeZone = session.teamBSafeZone {
                let safeZoneLocation = CLLocation(latitude: teamBSafeZone.center.latitude, longitude: teamBSafeZone.center.longitude)
                
                let distanceFlagAToSafeZone = flagALocation.distance(from: safeZoneLocation)
                let distanceFlagBToSafeZone = flagBLocation.distance(from: safeZoneLocation)
                
                if distanceFlagAToSafeZone.isFinite && distanceFlagBToSafeZone.isFinite &&
                   distanceFlagAToSafeZone <= teamBSafeZone.radius &&
                   distanceFlagBToSafeZone <= teamBSafeZone.radius {
                    teamBWins = true
                    teamBWinsTimestamp = Date() // Record when win condition was met
                    print("🚩 Team B win condition met! Both flags are in Team B safe zone")
                }
            }
            
            // DETERMINISTIC TIEBREAKER: If both teams win simultaneously, first entry wins
            // Use server timestamp (Firestore update time) or safe zone confirmation time as tiebreaker
            if teamAWins && teamBWins {
                // Compare safe zone confirmation times (earlier = more established = wins)
                let teamASafeZoneTime = session.teamASafeZone?.confirmedAt ?? Date.distantPast
                let teamBSafeZoneTime = session.teamBSafeZone?.confirmedAt ?? Date.distantPast
                
                if teamASafeZoneTime < teamBSafeZoneTime {
                    // Team A safe zone was confirmed first - Team A wins
                    print("🚩 TIEBREAKER: Team A wins (safe zone confirmed first)")
                    winningTeam = .teamA
                    signalGameOverDetected()
                    return
                } else if teamBSafeZoneTime < teamASafeZoneTime {
                    // Team B safe zone was confirmed first - Team B wins
                    print("🚩 TIEBREAKER: Team B wins (safe zone confirmed first)")
                    winningTeam = .teamB
                    signalGameOverDetected()
                    return
                } else {
                    // Same confirmation time - use current timestamp (first to check wins)
                    if let teamATime = teamAWinsTimestamp, let teamBTime = teamBWinsTimestamp {
                        if teamATime <= teamBTime {
                            print("🚩 TIEBREAKER: Team A wins (first to check win condition)")
                            winningTeam = .teamA
                        } else {
                            print("🚩 TIEBREAKER: Team B wins (first to check win condition)")
                            winningTeam = .teamB
                        }
                        signalGameOverDetected()
                        return
                    }
                }
            } else if teamAWins {
                print("🚩 Team A wins! Both flags are in Team A safe zone")
                winningTeam = .teamA
                signalGameOverDetected()
                return
            } else if teamBWins {
                print("🚩 Team B wins! Both flags are in Team B safe zone")
                winningTeam = .teamB
                signalGameOverDetected()
                return
            }
            
            // CTF has no time limit - game continues until win condition is met
            return
        } else {
            // Manhunt win conditions
            // Check if time is up (only if duration is finite)
            if bubble.duration.isFinite,
               let elapsed = elapsedSinceMatchStart,
               elapsed >= bubble.duration {
                signalGameOverDetected()
                return
            }
        
        // Check if all hiders are caught (hunter wins)
        let hiders = session.players.filter { $0.role == .hider }
        let aliveHiders = hiders.filter { $0.isAlive }
        if hiders.count > 0 && aliveHiders.isEmpty {
            signalGameOverDetected()
            return
        }
        
        // Edge case: Check if all hunters are eliminated (shouldn't happen, but handle it)
        let hunters = session.players.filter { $0.role == .hunter }
        let aliveHunters = hunters.filter { $0.isAlive }
        if hunters.count > 0 && aliveHunters.isEmpty {
            print("⚠️ All hunters eliminated - ending game (hiders win)")
            signalGameOverDetected()
            return
            }
        }
        
        // Edge case: Check if all players are eliminated
        let alivePlayers = session.players.filter { $0.isAlive }
        if alivePlayers.isEmpty {
            print("⚠️ All players eliminated - ending game")
            signalGameOverDetected()
            return
        }
        
        // Edge case: Check if only hunters remain (hunters win)
        let remainingHiders = session.players.filter { $0.role == .hider && $0.isAlive }
        let aliveHunters = session.players.filter { $0.role == .hunter && $0.isAlive }
        if remainingHiders.isEmpty && aliveHunters.count > 0 {
            signalGameOverDetected()
            return
        }
        
        // Edge case: Check if current player is eliminated and no other players
        if let currentPlayer = currentPlayer,
           !currentPlayer.isAlive,
           session.players.count == 1 {
            signalGameOverDetected()
            return
        }
    }
    
    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
        stopPresenceHeartbeat()
        locationService.setGameplayKeepAlive(false)
        ScreenWakeLock.setEnabled(false)
    }

    // MARK: - Presence Heartbeat (Manhunt/Zombie)

    /// Starts the active-game heartbeat. Each tick writes the local
    /// player's `lastUpdated` to Firestore even when their coordinates
    /// haven't changed, so other clients can distinguish a hider standing
    /// still from a player who has actually disconnected.
    ///
    /// Safe to call multiple times; restarts the timer if already running.
    /// No-op for CTF (CTF presence is tracked via flag-phone updates).
    private func startPresenceHeartbeat() {
        stopPresenceHeartbeat()

        guard let session = session,
              session.gameType == .manhunt || session.gameType == .zombieTag else {
            return
        }

        // Skip in unit tests; timers there add noise and the heartbeat
        // requires Firestore which the unit test rig does not provide.
        guard !isRunningUnitTests else { return }

        let timer = Timer.scheduledTimer(withTimeInterval: presenceHeartbeatInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                self.sendPresenceHeartbeat()
            }
        }
        presenceHeartbeatTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopPresenceHeartbeat() {
        presenceHeartbeatTimer?.invalidate()
        presenceHeartbeatTimer = nil
    }

    /// Push a heartbeat write for the local player. Only writes when the
    /// player is alive, the match is active, and remote sync is ready.
    /// Uses the dedicated `commitPlayerPresence` path so security rules
    /// can permit it as a self-only `lastUpdated` bump even after the
    /// member presence rule is tightened.
    private func sendPresenceHeartbeat() {
        guard let session = session,
              session.gameState == .active,
              session.gameType == .manhunt || session.gameType == .zombieTag,
              let player = currentPlayer,
              player.isAlive,
              remoteReadySessionId == session.id else {
            return
        }

        var heartbeatPlayer = player
        heartbeatPlayer.lastUpdated = Date()

        // Reflect the bump locally so disconnect checks on this device
        // also see fresh presence without waiting for the round trip.
        if let index = self.session?.players.firstIndex(where: { $0.id == player.id }) {
            self.session?.players[index].lastUpdated = heartbeatPlayer.lastUpdated
        }
        self.currentPlayer = heartbeatPlayer

        Task {
            do {
                try await firestoreService.commitPlayerPresence(
                    sessionId: session.id,
                    player: heartbeatPlayer
                )
            } catch {
                print("⚠️ Presence heartbeat failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Predator Compass Pulse Ability

    /// True iff the local player is currently a predator of a supported
    /// game type, alive, and the game is active. Drives the UI gate that
    /// shows / hides the `PredatorPulseControl`.
    var canShowCompassAbility: Bool {
        guard let session = session,
              session.gameState == .active,
              session.supportsCompassAbility,
              let predatorRole = session.compassPredatorRole,
              let player = currentPlayer,
              player.role == predatorRole,
              player.isAlive else {
            return false
        }
        return true
    }

    /// Time remaining (seconds) until the local predator can fire their
    /// next pulse, computed against the local session snapshot. The
    /// transaction also revalidates with a fresh snapshot, but the UI
    /// uses this for the charging ring + first-use delay animation.
    func compassCooldownRemaining(now: Date = Date()) -> TimeInterval {
        guard let session = session,
              let bubble = session.bubble,
              let player = currentPlayer else {
            return CompassAbilityConfig.fixedCooldownFallback
        }
        let elapsed = now.timeIntervalSince(bubble.startTime)
        let firstUse = CompassAbilityConfig.firstUseDelay(
            elapsed: elapsed,
            totalDuration: bubble.duration
        )
        if elapsed < firstUse {
            return max(0, firstUse - elapsed)
        }

        guard let lastUsed = session.compassLastUsedAtByPlayerId[player.id] else {
            return 0
        }
        let cooldown = CompassAbilityConfig.cooldownDuration(
            elapsed: elapsed,
            totalDuration: bubble.duration
        )
        let sinceLast = now.timeIntervalSince(lastUsed)
        return max(0, cooldown - sinceLast)
    }

    /// Total cooldown duration the ring should track from. UI uses this
    /// as the denominator when drawing the cooldown ring's progress.
    func compassCooldownTotal(now: Date = Date()) -> TimeInterval {
        guard let session = session, let bubble = session.bubble else {
            return CompassAbilityConfig.fixedCooldownFallback
        }
        let elapsed = now.timeIntervalSince(bubble.startTime)
        let firstUse = CompassAbilityConfig.firstUseDelay(
            elapsed: elapsed,
            totalDuration: bubble.duration
        )
        if elapsed < firstUse {
            return firstUse
        }
        return CompassAbilityConfig.cooldownDuration(
            elapsed: elapsed,
            totalDuration: bubble.duration
        )
    }

    /// `true` if the local predator can fire a pulse right now per the
    /// local snapshot. UI gate; the transaction does the authoritative
    /// check.
    var canUseCompassPulse: Bool {
        guard canShowCompassAbility else { return false }
        guard !compassPulseInFlight else { return false }
        guard let session = session,
              let bubble = session.bubble,
              let player = currentPlayer,
              !isCoordinateOutsideActiveZone(player.coordinate, bubble: bubble, logFailures: false) else {
            return false
        }
        return compassCooldownRemaining() <= 0.0001
    }

    /// True if there is currently no eligible prey from the local
    /// snapshot. Lets the UI render a disabled "No targets" pose without
    /// firing a transaction.
    var compassHasEligiblePrey: Bool {
        guard let session = session, let player = currentPlayer else { return false }
        return !session.eligibleCompassPrey(firedBy: player.id).isEmpty
    }

    /// Fire a compass pulse. Validates GPS freshness locally, then defers
    /// to a Firestore transaction for atomic prey selection + cooldown
    /// enforcement against the latest snapshot. The result drives
    /// `compassPulseLastResult` for the predator's local UI; listener
    /// side effects (prey/other-predator pills) fan out from the session
    /// snapshot in `startSessionListener`.
    func requestCompassPulse() async {
        guard canShowCompassAbility,
              let session = session,
              let player = currentPlayer else {
            return
        }

        guard compassHasEligiblePrey else {
            compassPulseLastResult = .noTargets
            announcementManager.post("No targets.", type: .general)
            HapticFeedbackManager.shared.warning()
            scheduleCompassResultClear()
            return
        }

        guard let location = locationService.getCurrentLocation() else {
            print("⚠️ Compass pulse aborted, no local GPS fix")
            compassPulseLastResult = .failed
            announcementManager.post("Pulse failed.", type: .warning)
            scheduleCompassResultClear()
            return
        }
        let now = Date()
        let locationAge = now.timeIntervalSince(location.timestamp)
        if locationAge.isFinite, locationAge > CompassAbilityConfig.maxActorLocationAge {
            print("⚠️ Compass pulse aborted, GPS stale (\(Int(locationAge))s)")
            compassPulseLastResult = .failed
            announcementManager.post("Pulse failed.", type: .warning)
            scheduleCompassResultClear()
            return
        }
        if let bubble = session.bubble,
           isCoordinateOutsideActiveZone(location.coordinate, bubble: bubble, now: now, logFailures: false) {
            print("⚠️ Compass pulse aborted, predator is outside the active zone")
            compassPulseLastResult = .failed
            announcementManager.post("Return to the zone.", type: .warning)
            HapticFeedbackManager.shared.warning()
            scheduleCompassResultClear()
            return
        }

        compassPulseInFlight = true
        defer { compassPulseInFlight = false }

        do {
            let commit = try await firestoreService.commitCompassPulse(
                sessionId: session.id,
                actorId: player.id,
                actorLocation: location,
                now: now
            )
            let pulse = commit.pulse

            // Optimistic local merge so the predator's UI doesn't wait on
            // the listener echo. We do NOT set `isUpdatingSession` here -
            // compass writes must allow the listener to flow through for
            // other devices, and dedupe relies on `lastProcessedCompassEventId`
            // rather than blocking listener processing.
            if var updatedSession = self.session {
                updatedSession.compassPulse = pulse
                updatedSession.compassLastUsedAtByPlayerId[player.id] = pulse.usedAt
                self.session = updatedSession
            }
            lastProcessedCompassEventId = pulse.eventId
            compassPulseLastResult = .success(commit)
            HapticFeedbackManager.shared.selection()
            scheduleCompassResultClear()
        } catch let error as NSError {
            let kind = error.userInfo["compassPulseErrorKind"] as? String
            switch kind {
            case "noEligiblePrey":
                compassPulseLastResult = .noTargets
                announcementManager.post("No targets.", type: .general)
                HapticFeedbackManager.shared.warning()
            case "cooldownActive":
                // Silent, local UI should already reflect cooldown; this
                // is a tie-breaker against fast double-tap or stale local
                // cooldown.
                compassPulseLastResult = nil
            case "outsideZone":
                compassPulseLastResult = .failed
                announcementManager.post("Return to the zone.", type: .warning)
                HapticFeedbackManager.shared.warning()
            case "notEligible":
                compassPulseLastResult = nil
            default:
                compassPulseLastResult = .failed
                announcementManager.post("Pulse failed.", type: .warning)
            }
            scheduleCompassResultClear()
            print("⚠️ Compass pulse failed: \(error.localizedDescription)")
        }
    }

    /// Bearing (degrees, 0=N) from the actor GPS position at commit time to
    /// the target coordinates used for that same commit (same geometry as
    /// `pulse.distanceMeters`).
    func compassBearing(for commit: CompassPulseCommit) -> Double? {
        let actor = CLLocation(latitude: commit.actorLatitude, longitude: commit.actorLongitude)
        let target = CLLocation(latitude: commit.targetLatitude, longitude: commit.targetLongitude)
        return actor.bearing(to: target)
    }

    private func scheduleCompassResultClear() {
        compassPulseResultClearTask?.cancel()
        compassPulseResultClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
            if Task.isCancelled { return }
            await MainActor.run { [weak self] in
                self?.compassPulseLastResult = nil
            }
        }
    }

    /// Inspect a new session snapshot for an unseen compass pulse and
    /// post the appropriate skinned announcement pill. Called from the
    /// session listener after `self.session` has been replaced.
    private func handleCompassPulseAnnouncement(in session: GameSession) {
        guard let pulse = session.compassPulse else { return }
        guard pulse.eventId != lastProcessedCompassEventId else { return }

        let age = Date().timeIntervalSince(pulse.usedAt)
        // Skip stale events (reconnect / late join) and any negative-age
        // clock drift; we don't want a pill storm on cold start.
        guard age.isFinite, age >= -1.0, age <= CompassAbilityConfig.pulseAnnouncementMaxAge else {
            lastProcessedCompassEventId = pulse.eventId
            return
        }

        lastProcessedCompassEventId = pulse.eventId

        guard let viewer = currentPlayer else { return }

        // Acting predator already saw their own result UI locally; suppress
        // the listener echo so we don't double-announce.
        if pulse.usedByPlayerId == viewer.id {
            return
        }

        let actorName = session.players.first(where: { $0.id == pulse.usedByPlayerId })?.displayName
            ?? "Someone"

        switch session.gameType {
        case .manhunt:
            if viewer.role == .hider {
                announcementManager.post("The hunters picked up your trail.", type: .compassPulse)
                HapticFeedbackManager.shared.warning()
            } else if viewer.role == .hunter {
                announcementManager.post("\(actorName) used a compass pulse.", type: .compassPulse)
            }
        case .zombieTag:
            if viewer.role == .human {
                announcementManager.post("Something sensed the living.", type: .compassPulse)
                HapticFeedbackManager.shared.warning()
            } else if viewer.role == .zombie {
                announcementManager.post("\(actorName) locked onto a signal.", type: .compassPulse)
            }
        default:
            break
        }
    }

    // MARK: - Session Listener
    
    private func startSessionListener(_ sessionId: String) {
        stopSessionListener()

        firestoreService.listenToSession(
            sessionId,
            completion: { [weak self] updatedSession in
                Task { @MainActor in
                    guard let self = self else { return }

                    // Handle session deletion or not found
                    guard var session = updatedSession else {
                        self.print("⚠️ Session not found in Firestore - may have been deleted")
                        // Check if we have a current session that was deleted
                        if self.session != nil {
                            self.networkError = "Session was deleted. The game may have ended."
                            self.isConnected = false
                            // Don't clear session immediately - allow reconnection attempt
                        }
                        // The resume snapshot is only useful if the Firestore
                        // doc still exists; drop it so the next launch lands
                        // on the home screen instead of hanging on a missing
                        // session.
                        GuestSessionStore.shared.clear(reason: "session-missing")
                        return
                    }

                    // Roster growth always wins: if the incoming snapshot
                    // has more players than we currently know about, apply
                    // it unconditionally. The previous `isUpdatingSession`
                    // gate could drop a joiner's update on the host while
                    // the host was mid-write, which made the host stay
                    // stuck at 1 player.
                    let localPlayerCount = self.session?.players.count ?? 0
                    let rosterGrew = session.players.count > localPlayerCount

                    if self.isUpdatingSession && !rosterGrew {
                        self.print("⏸️ Ignoring Firestore update - local update in progress (roster did not grow)")
                        return
                    }

                    // Update local session with Firestore data
                    self.print("📡 Session updated from Firestore - \(session.players.count) players (rosterGrew=\(rosterGrew))")
                    self.remoteReadySessionId = session.id
                    #if DEBUG
                    for player in session.players {
                        self.print("   - \(player.displayName) [\(player.id)] (\(player.role.rawValue))")
                    }
                    #endif
                
                // Clear network error if we successfully received update
                if self.networkError != nil {
                    self.networkError = nil
                    self.isConnected = true
                }
                
                let previousGameState = self.gameState
                
                if let previousSession = self.session {
                    if previousSession.gameNumber > session.gameNumber {
                        self.print("⏭️ Ignoring stale Firestore update for older game number \(session.gameNumber)")
                        return
                    }
                    
                    if previousSession.gameNumber == session.gameNumber,
                       let previousBubble = previousSession.bubble,
                       session.bubble == nil {
                        self.print("🔒 Preserving local bubble in session listener (Firestore update doesn't have it yet)")
                        session.bubble = previousBubble
                    }
                }
                
                // Check for flag players who left (CTF-specific)
                if session.gameType == .captureTheFlag,
                   let previousSession = self.session {
                    let previousPlayerIds = Set(previousSession.players.map { $0.id })
                    let currentPlayerIds = Set(session.players.map { $0.id })
                    let leftPlayerIds = previousPlayerIds.subtracting(currentPlayerIds)
                    
                    for leftPlayerId in leftPlayerIds {
                        if let leftPlayer = previousSession.players.first(where: { $0.id == leftPlayerId }),
                           leftPlayer.isFlag {
                            self.handleFlagPlayerLeaving(leavingPlayerId: leftPlayerId, session: &session)
                        }
                    }
                }
                
                // AGGRESSIVE RESYNC: For CTF, always trust Firestore flag state (server truth)
                // This prevents ghost flags and duplicate captures
                if session.gameType == .captureTheFlag,
                   let previousSession = self.session {
                    // Reconcile flag carrier state - Firestore always wins
                    let firestoreFlagCarriers = session.flagCarriers
                    let localFlagCarriers = previousSession.flagCarriers
                    
                    // If Firestore has different flag carriers, resync immediately
                    if firestoreFlagCarriers != localFlagCarriers {
                        self.print("🔄 FLAG STATE RESYNC: Firestore flag carriers differ from local")
                        self.print("   Firestore: \(firestoreFlagCarriers)")
                        self.print("   Local: \(localFlagCarriers)")
                        self.print("   → Using Firestore state (server truth)")
                        // Firestore state is already in session.flagCarriers, so we use it
                    }
                }
                
                self.session = session
                self.gameState = session.gameState

                // Refresh the local resume snapshot from the latest
                // listener payload. Throttled inside the store so this
                // is safe to call on every tick.
                if let localId = self.currentPlayer?.id {
                    self.saveResumeSnapshot(for: session, localPlayerId: localId)
                }
                if session.gameState == .ended {
                    GuestSessionStore.shared.clear(reason: "game-ended")
                }

                // Update current player if they exist in session
                if let playerId = self.currentPlayer?.id,
                   let player = session.players.first(where: { $0.id == playerId }) {
                    let wasAlive = self.currentPlayer?.isAlive ?? false
                    self.currentPlayer = player
                    
                    // If player was eliminated but is now alive (reconnection), restart location updates
                    if !wasAlive && player.isAlive {
                        self.print("🔄 Player reconnected and is alive - restarting location updates")
                        self.locationService.start()
                    }
                } else if let playerId = self.currentPlayer?.id {
                    // Player not found in session - they may have been removed
                    // Check if we can reconnect
                    self.print("⚠️ Current player \(playerId) not found in session - may need to rejoin")
                }

                // Post a skinned announcement pill (prey / other-predator)
                // when a fresh compass pulse has landed on the document.
                // The actor's own pulse is short-circuited inside the
                // helper by `eventId` dedupe.
                self.handleCompassPulseAnnouncement(in: session)

                // Start BLE if game just became active (for players who joined or host)
                if previousGameState != .active && session.gameState == .active {
                    self.print("🎮 Game became active - starting BLE for current player")
                    if let playerId = self.currentPlayer?.id, let playerName = self.currentPlayer?.displayName {
                        self.bluetoothTagService.start(playerId: playerId, playerName: playerName)
                        self.print("✅ BLE started for \(playerName)")
                    }
                }

                // Stop BLE if game ended
                if previousGameState == .active && session.gameState != .active {
                    self.print("🛑 Game ended - stopping BLE")
                    self.bluetoothTagService.stop()
                }

                // Non-host finalization: when the host's authoritative
                // `.ended` write lands, every other device runs the same
                // local finalize path (stats, BLE/location cleanup, end
                // UI) so all players see the end screen with consistent
                // stats. The host already ran `finalizeLocalGameEnd`
                // inside `endGame()`, so this is a no-op there.
                if previousGameState == .active,
                   session.gameState == .ended,
                   !self.isCurrentPlayerSessionHost() {
                    self.finalizeLocalGameEnd(session: session)
                }
            }
        },
            onDecodeError: { [weak self] error in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.print("❌ Session listener decode failed: \(error.localizedDescription)")
                    // Surface to UI so a schema mismatch doesn't manifest
                    // as a silent "host won't update" symptom. We do
                    // *not* clear the resume snapshot here - the doc
                    // still exists, just couldn't be decoded.
                    self.networkError = "Couldn't read latest lobby data. Try again in a moment."
                    self.isConnected = false
                }
            },
            onListenError: { [weak self] error in
                Task { @MainActor in
                    guard let self = self else { return }
                    self.print("❌ Session listener failed: \(error.localizedDescription)")
                    self.print("🔐 Listener auth debug: authServiceUid=\(AuthService.shared.userId ?? "nil"), localPlayerId=\(self.currentPlayer?.id ?? "nil"), localPlayerAuth=\(self.currentPlayer?.authUserId ?? "nil"), sessionHostAuth=\(self.session?.hostAuthUid ?? "nil"), memberAuthUids=\(self.session?.memberAuthUserIds.joined(separator: ",") ?? "nil")")
                    self.networkError = "Couldn't sync the latest lobby data. Check your connection and try again."
                    self.isConnected = false
                    self.remoteReadySessionId = nil
                }
            }
        )
    }
    
    private func stopSessionListener() {
        _firestoreService?.stopListening()
    }

    // MARK: - Resume

    /// Persist a compact snapshot of the active lobby so the next app
    /// launch can rehydrate it. Called from create/join and from the
    /// session listener (throttled inside `GuestSessionStore`).
    private func saveResumeSnapshot(for session: GameSession, localPlayerId: String, force: Bool = false) {
        guard session.gameState != .ended else { return }
        let snapshot = GuestSessionSnapshot(
            sessionId: session.id,
            joinCode: session.joinCode,
            gameType: session.gameType,
            localPlayerId: localPlayerId,
            hostPlayerId: session.hostPlayerId,
            savedAt: Date()
        )
        GuestSessionStore.shared.save(snapshot, force: force)
    }

    /// Attempt to rehydrate an active session from a stored snapshot.
    /// Returns the `GameType` to restore in the UI on success, or `nil`
    /// when no usable snapshot exists. The snapshot is cleared on every
    /// non-success path so launches never get stuck on a stale lobby.
    func resumeIfPossible() async -> GameType? {
        guard let snapshot = GuestSessionStore.shared.currentSnapshot() else {
            return nil
        }

        do {
            _ = try await AuthService.shared.ensureSignedIn()
        } catch {
            print("⚠️ Resume aborted: sign-in failed (\(error.localizedDescription))")
            return nil
        }

        let recovered: GameSession?
        do {
            recovered = try await firestoreService.findSessionByCodeAnyState(snapshot.joinCode)
        } catch {
            print("⚠️ Resume aborted: Firestore lookup failed (\(error.localizedDescription))")
            return nil
        }

        guard let recoveredSession = recovered, recoveredSession.id == snapshot.sessionId else {
            print("⚠️ Resume snapshot stale (session \(snapshot.sessionId) not found) - clearing")
            GuestSessionStore.shared.clear(reason: "resume-not-found")
            return nil
        }

        guard recoveredSession.gameState != .ended else {
            print("⚠️ Resume snapshot points to ended game - clearing")
            GuestSessionStore.shared.clear(reason: "resume-ended")
            return nil
        }

        guard let localPlayer = recoveredSession.players.first(where: { $0.id == snapshot.localPlayerId }) else {
            print("⚠️ Resume snapshot local player \(snapshot.localPlayerId) no longer in roster - clearing")
            GuestSessionStore.shared.clear(reason: "resume-player-missing")
            return nil
        }

        self.session = recoveredSession
        self.currentPlayer = localPlayer
        self.gameState = recoveredSession.gameState
        self.remoteReadySessionId = recoveredSession.id
        startSessionListener(recoveredSession.id)

        if recoveredSession.gameState == .active {
            bluetoothTagService.start(playerId: localPlayer.id, playerName: localPlayer.displayName)
            startUpdateTimer()
        }

        saveResumeSnapshot(for: recoveredSession, localPlayerId: localPlayer.id, force: true)
        print("✅ Resumed session \(recoveredSession.id) on this device")
        return recoveredSession.gameType
    }
    
    @MainActor
    deinit {
        stopUpdateTimer()
        stopSessionListener()
        _bluetoothTagService?.stop()
    }
}
