//
//  ScreenshotSeedFactory.swift
//  Touch-Grass
//
//  DEBUG-only helper that builds deterministic `GameViewModel`, `GameSession`,
//  `Player`, `Bubble`, and `GameStats` values used to render real SwiftUI
//  screens for marketing screenshots. Bypasses Firebase, GPS, and Bluetooth.
//

#if DEBUG
import Foundation
import CoreLocation
import SwiftUI

@MainActor
enum ScreenshotSeedFactory {

    // MARK: - Fixed reference values

    /// A pleasant park-style coordinate (Prospect Park, Brooklyn) used as the
    /// stable anchor for every seeded scenario. Choosing a fixed real-world
    /// location makes MapKit show recognizable parkland tiles when online.
    static let anchor = CLLocationCoordinate2D(latitude: 40.6602, longitude: -73.9690)

    /// Fixed start time so that the bubble timer renders deterministic values.
    /// We anchor to a date roughly 4 minutes ago so the in-game HUD shows a
    /// healthy mid-game time remaining instead of "0:00".
    static let bubbleStartTime: Date = Date(timeIntervalSinceNow: -240)

    /// Six-digit join code used in the lobby screenshot.
    static let joinCode = "428931"

    // MARK: - View model entry point

    /// Builds a fully seeded `GameViewModel` for the given scenario.
    ///
    /// The view model has its `locationService` pre-authorised and seeded
    /// with `anchor`, plus a `gameService` populated with the right session,
    /// players, bubble, and (where relevant) game stats.
    static func makeViewModel(for scenario: ScreenshotScenario) -> GameViewModel {
        let viewModel = GameViewModel()

        // Stable display name for the local player so the lobby is not gated
        // on the "Please add your name" alert.
        ProfileService.shared.saveProfile(name: "You")

        // Touch the published properties to trigger lazy creation of the
        // underlying services, then seed them directly.
        let location = viewModel.locationService
        location.authorization = .authorizedAlways
        location.coordinate = anchor
        location.accuracy = 5
        let horizontalAccuracy = location.accuracy ?? 5
        location.lastKnownLocation = CLLocation(
            coordinate: anchor,
            altitude: 0,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: Date()
        )

        switch scenario {
        case .gameSelection:
            viewModel.selectedGame = nil
            viewModel.selectedGameType = .manhunt

        case .ctfLobby:
            viewModel.selectedGame = .captureTheFlag
            viewModel.selectedGameType = .captureTheFlag
            seedCTFLobby(viewModel: viewModel)

        case .ctfActive:
            viewModel.selectedGame = .captureTheFlag
            viewModel.selectedGameType = .captureTheFlag
            seedCTFActive(viewModel: viewModel)

        case .zombieActive:
            viewModel.selectedGame = .zombieTag
            viewModel.selectedGameType = .zombieTag
            seedZombieActive(viewModel: viewModel)

        case .manhuntActive:
            viewModel.selectedGame = .manhunt
            viewModel.selectedGameType = .manhunt
            seedManhuntActive(viewModel: viewModel)

        case .resultsShare:
            viewModel.selectedGame = .captureTheFlag
            viewModel.selectedGameType = .captureTheFlag
            seedResultsShare(viewModel: viewModel)
        }

        return viewModel
    }

    // MARK: - CTF Lobby

    private static func seedCTFLobby(viewModel: GameViewModel) {
        let hostId = "screenshot-host"
        let players = ctfLobbyPlayers(hostId: hostId)

        let bubble = makeBubble(at: anchor, radius: 220, shrinks: false)

        var session = GameSession(
            hostId: hostId,
            gameState: .lobby,
            gameType: .captureTheFlag,
            bubble: bubble,
            players: players,
            joinCode: joinCode,
            hunterCount: 0,
            teamABase: offset(anchor, latMeters: -90, lonMeters: -110),
            teamBBase: offset(anchor, latMeters: 100, lonMeters: 120),
            scoreLimit: 0
        )
        session.teamAScore = 0
        session.teamBScore = 0

        viewModel.gameService.session = session
        viewModel.gameService.currentPlayer = players.first(where: { $0.id == hostId })
        viewModel.gameService.gameState = .lobby
    }

    private static func ctfLobbyPlayers(hostId: String) -> [Player] {
        [
            Player(
                id: hostId,
                displayName: "You",
                latitude: anchor.latitude,
                longitude: anchor.longitude,
                role: .teamA,
                isAlive: true,
                isFlag: false,
                isTeamLeader: true
            ),
            Player(
                id: "screenshot-jordan",
                displayName: "Jordan",
                latitude: anchor.latitude + 0.0004,
                longitude: anchor.longitude - 0.0006,
                role: .teamA,
                isAlive: true,
                isFlag: true,
                isTeamLeader: false
            ),
            Player(
                id: "screenshot-mateo",
                displayName: "Mateo",
                latitude: anchor.latitude + 0.0001,
                longitude: anchor.longitude + 0.0008,
                role: .teamB,
                isAlive: true,
                isFlag: false,
                isTeamLeader: true
            ),
            Player(
                id: "screenshot-priya",
                displayName: "Priya",
                latitude: anchor.latitude - 0.0005,
                longitude: anchor.longitude + 0.0003,
                role: .teamB,
                isAlive: true,
                isFlag: true,
                isTeamLeader: false
            ),
            Player(
                id: "screenshot-alex",
                displayName: "Alex",
                latitude: anchor.latitude - 0.0002,
                longitude: anchor.longitude - 0.0004,
                role: .teamA,
                isAlive: true,
                isFlag: false,
                isTeamLeader: false
            ),
            Player(
                id: "screenshot-sky",
                displayName: "Sky",
                latitude: anchor.latitude + 0.0006,
                longitude: anchor.longitude + 0.0002,
                role: .teamB,
                isAlive: true,
                isFlag: false,
                isTeamLeader: false
            )
        ]
    }

    // MARK: - CTF Active

    private static func seedCTFActive(viewModel: GameViewModel) {
        let hostId = "screenshot-host"
        let players = ctfLobbyPlayers(hostId: hostId)

        let bubble = makeBubble(at: anchor, radius: 320, shrinks: false)

        var session = GameSession(
            hostId: hostId,
            gameState: .active,
            gameType: .captureTheFlag,
            bubble: bubble,
            players: players,
            joinCode: joinCode,
            hunterCount: 0,
            teamABase: offset(anchor, latMeters: -90, lonMeters: -110),
            teamBBase: offset(anchor, latMeters: 100, lonMeters: 120),
            scoreLimit: 0
        )
        session.teamAScore = 1
        session.teamBScore = 0
        session.teamAFlagPlaced = true
        session.teamBFlagPlaced = true
        session.teamASafeZone = GameSession.SafeZone(
            center: offset(anchor, latMeters: -90, lonMeters: -110),
            radius: 32
        )
        session.teamBSafeZone = GameSession.SafeZone(
            center: offset(anchor, latMeters: 100, lonMeters: 120),
            radius: 32
        )

        viewModel.gameService.session = session
        viewModel.gameService.currentPlayer = players.first(where: { $0.id == hostId })
        viewModel.gameService.gameState = .active
        viewModel.gameService.warningLevel = .safe
        viewModel.gameService.distanceToEdge = 84
    }

    // MARK: - Zombie Active

    private static func seedZombieActive(viewModel: GameViewModel) {
        let hostId = "screenshot-host"
        let players: [Player] = [
            Player(id: hostId, displayName: "You",
                   latitude: anchor.latitude, longitude: anchor.longitude,
                   role: .human),
            Player(id: "screenshot-z1", displayName: "Maya",
                   latitude: anchor.latitude + 0.0004, longitude: anchor.longitude - 0.0002,
                   role: .zombie),
            Player(id: "screenshot-z2", displayName: "Devon",
                   latitude: anchor.latitude - 0.0005, longitude: anchor.longitude + 0.0006,
                   role: .zombie),
            Player(id: "screenshot-h1", displayName: "Riley",
                   latitude: anchor.latitude + 0.0002, longitude: anchor.longitude + 0.0007,
                   role: .human),
            Player(id: "screenshot-h2", displayName: "Sam",
                   latitude: anchor.latitude - 0.0003, longitude: anchor.longitude - 0.0008,
                   role: .human),
            Player(id: "screenshot-h3", displayName: "Iris",
                   latitude: anchor.latitude + 0.0006, longitude: anchor.longitude + 0.0001,
                   role: .human)
        ]

        let bubble = makeBubble(at: anchor, radius: 280, shrinks: true)

        let session = GameSession(
            hostId: hostId,
            gameState: .active,
            gameType: .zombieTag,
            bubble: bubble,
            players: players,
            joinCode: joinCode,
            hunterCount: 2
        )

        viewModel.gameService.session = session
        viewModel.gameService.currentPlayer = players.first(where: { $0.id == hostId })
        viewModel.gameService.gameState = .active
        viewModel.gameService.warningLevel = .warning
        viewModel.gameService.distanceToEdge = 36
        viewModel.gameService.proximityWarningLevel = .warning
        viewModel.gameService.proximityWarningDistance = 18
        viewModel.gameService.nearestHunterDistance = 18
        viewModel.gameService.nearestHunterDirection = 42
    }

    // MARK: - Manhunt Active

    private static func seedManhuntActive(viewModel: GameViewModel) {
        let hostId = "screenshot-host"
        let players: [Player] = [
            Player(id: hostId, displayName: "You",
                   latitude: anchor.latitude, longitude: anchor.longitude,
                   role: .hider),
            Player(id: "screenshot-hunter", displayName: "Casey",
                   latitude: anchor.latitude + 0.0005, longitude: anchor.longitude + 0.0004,
                   role: .hunter),
            Player(id: "screenshot-hider1", displayName: "Nia",
                   latitude: anchor.latitude - 0.0006, longitude: anchor.longitude - 0.0001,
                   role: .hider),
            Player(id: "screenshot-hider2", displayName: "Theo",
                   latitude: anchor.latitude + 0.0003, longitude: anchor.longitude - 0.0007,
                   role: .hider),
            Player(id: "screenshot-hider3", displayName: "Quinn",
                   latitude: anchor.latitude - 0.0004, longitude: anchor.longitude + 0.0005,
                   role: .hider)
        ]

        let bubble = makeBubble(at: anchor, radius: 260, shrinks: true)

        let session = GameSession(
            hostId: hostId,
            gameState: .active,
            gameType: .manhunt,
            bubble: bubble,
            players: players,
            joinCode: joinCode,
            hunterCount: 1
        )

        viewModel.gameService.session = session
        viewModel.gameService.currentPlayer = players.first(where: { $0.id == hostId })
        viewModel.gameService.gameState = .active
        viewModel.gameService.warningLevel = .warning
        viewModel.gameService.distanceToEdge = 42
        viewModel.gameService.proximityWarningLevel = .safe
        viewModel.gameService.proximityWarningDistance = 72
        viewModel.gameService.nearestHunterDistance = 72
        viewModel.gameService.nearestHunterDirection = 28
    }

    // MARK: - Results / Share

    private static func seedResultsShare(viewModel: GameViewModel) {
        let hostId = "screenshot-host"
        let players = ctfLobbyPlayers(hostId: hostId)

        let bubble = makeBubble(at: anchor, radius: 320, shrinks: false)

        var session = GameSession(
            hostId: hostId,
            gameState: .ended,
            gameType: .captureTheFlag,
            bubble: bubble,
            players: players,
            joinCode: joinCode,
            hunterCount: 0,
            teamABase: offset(anchor, latMeters: -90, lonMeters: -110),
            teamBBase: offset(anchor, latMeters: 100, lonMeters: 120),
            scoreLimit: 0
        )
        session.teamAScore = 2
        session.teamBScore = 1

        let startTime = Date(timeIntervalSinceNow: -540)
        let endTime = Date(timeIntervalSinceNow: -10)

        var stats = GameStats(gameStartTime: startTime)
        stats.gameEndTime = endTime
        stats.winner = .teamA
        for player in players {
            stats.survivalTimes[player.id] = endTime.timeIntervalSince(startTime)
        }

        viewModel.gameService.session = session
        viewModel.gameService.currentPlayer = players.first(where: { $0.id == hostId })
        viewModel.gameService.gameState = .ended
        viewModel.gameService.gameStats = stats
        viewModel.gameService.winningTeam = .teamA
    }

    // MARK: - Helpers

    private static func makeBubble(at center: CLLocationCoordinate2D,
                                   radius: Double,
                                   shrinks: Bool) -> Bubble {
        let shrinkInterval = shrinks ? 180.0 : Bubble.infiniteSentinel
        let duration = shrinks ? 1800.0 : Bubble.infiniteSentinel
        return Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: radius,
            startTime: bubbleStartTime,
            shrinkInterval: shrinkInterval,
            duration: duration,
            shrinkHistory: [],
            showTimer: true,
            enableShrinking: shrinks
        )
    }

    /// Offsets a coordinate by approximate meters in latitude / longitude.
    /// Good enough for placing bases a short distance from the anchor.
    private static func offset(_ coord: CLLocationCoordinate2D,
                               latMeters: Double,
                               lonMeters: Double) -> CLLocationCoordinate2D {
        let dLat = latMeters / 111_000.0
        let dLon = lonMeters / (111_000.0 * cos(coord.latitude * .pi / 180.0))
        return CLLocationCoordinate2D(latitude: coord.latitude + dLat,
                                       longitude: coord.longitude + dLon)
    }
}
#endif
