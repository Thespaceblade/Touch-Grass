//
//  GameSessionTests.swift
//  Touch-GrassTests
//
//  Debug-only unit tests for GameSession model
//

import XCTest
import CoreLocation
@testable import Touch_Grass

#if DEBUG
final class GameSessionTests: XCTestCase {
    
    // MARK: - Session Creation Tests
    
    func testSessionCreation() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .manhunt,
            players: [host],
            hunterCount: 1
        )
        
        XCTAssertEqual(session.hostId, host.id)
        XCTAssertEqual(session.gameState, .lobby)
        XCTAssertEqual(session.gameType, .manhunt)
        XCTAssertEqual(session.players.count, 1)
        XCTAssertEqual(session.hunterCount, 1)
        XCTAssertNotNil(session.id, "Session should have an ID")
        XCTAssertEqual(session.joinCode.count, 6, "Join code should be 6 digits")
    }
    
    // MARK: - Game Type Tests
    
    func testManhuntSession() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .manhunt,
            players: [host],
            hunterCount: 1
        )
        
        XCTAssertEqual(session.gameType, .manhunt)
    }
    
    func testCTFSession() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .teamA,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .captureTheFlag,
            players: [host],
            hunterCount: 0
        )
        
        XCTAssertEqual(session.gameType, .captureTheFlag)
        XCTAssertEqual(session.teamAScore, 0)
        XCTAssertEqual(session.teamBScore, 0)
    }
    
    func testZombieTagSession() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .human,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .zombieTag,
            players: [host],
            hunterCount: 1 // 1 zombie
        )
        
        XCTAssertEqual(session.gameType, .zombieTag)
    }
    
    // MARK: - Bubble Tests
    
    func testSessionWithBubble() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        var session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .manhunt,
            players: [host],
            hunterCount: 1
        )
        
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        session.bubble = bubble
        
        XCTAssertNotNil(session.bubble)
        if let bubble = session.bubble {
            XCTAssertEqual(bubble.startRadius, 500.0, accuracy: 0.1)
        } else {
            XCTFail("Bubble should not be nil")
        }
    }
    
    // MARK: - CTF Specific Tests
    
    func testCTFTeamBases() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .teamA,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        var session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .captureTheFlag,
            players: [host],
            hunterCount: 0
        )
        
        let teamABase = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let teamBBase = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195)
        
        session.teamABase = teamABase
        session.teamBBase = teamBBase
        
        XCTAssertNotNil(session.teamABase)
        XCTAssertNotNil(session.teamBBase)
        if let sessionTeamABase = session.teamABase, let sessionTeamBBase = session.teamBBase {
            XCTAssertEqual(sessionTeamABase.latitude, teamABase.latitude, accuracy: 0.0001)
            XCTAssertEqual(sessionTeamBBase.latitude, teamBBase.latitude, accuracy: 0.0001)
        } else {
            XCTFail("Team bases should not be nil")
        }
    }
    
    func testCTFSafeZones() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .teamA,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        var session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .captureTheFlag,
            players: [host],
            hunterCount: 0
        )
        
        let teamASafeZone = GameSession.SafeZone(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 50.0
        )
        
        let teamBSafeZone = GameSession.SafeZone(
            center: CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195),
            radius: 50.0
        )
        
        session.teamASafeZone = teamASafeZone
        session.teamBSafeZone = teamBSafeZone
        
        XCTAssertNotNil(session.teamASafeZone)
        XCTAssertNotNil(session.teamBSafeZone)
        if let teamASafeZone = session.teamASafeZone, let teamBSafeZone = session.teamBSafeZone {
            XCTAssertEqual(teamASafeZone.radius, 50.0, accuracy: 0.1)
            XCTAssertEqual(teamBSafeZone.radius, 50.0, accuracy: 0.1)
        } else {
            XCTFail("Safe zones should not be nil")
        }
    }
    
    func testCTFFlagCarriers() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .teamA,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        var session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .captureTheFlag,
            players: [host],
            hunterCount: 0
        )
        
        let flagPlayerId = "flag-player-1"
        let carrierPlayerId = "carrier-1"
        
        session.flagCarriers[flagPlayerId] = carrierPlayerId
        
        XCTAssertEqual(session.flagCarriers[flagPlayerId], carrierPlayerId)
        XCTAssertEqual(session.flagCarriers.count, 1)
    }
    
    // MARK: - Player Management Tests
    
    func testSessionWithMultiplePlayers() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let player2 = Player(
            displayName: "Player 2",
            latitude: 37.7750,
            longitude: -122.4195,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let player3 = Player(
            displayName: "Player 3",
            latitude: 37.7751,
            longitude: -122.4196,
            role: .hunter,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .manhunt,
            players: [host, player2, player3],
            hunterCount: 1
        )
        
        XCTAssertEqual(session.players.count, 3)
        XCTAssertEqual(session.hunterCount, 1)
    }
    
    // MARK: - Game State Tests
    
    func testGameStateTransitions() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        var session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .manhunt,
            players: [host],
            hunterCount: 1
        )
        
        XCTAssertEqual(session.gameState, .lobby)
        
        session.gameState = .active
        XCTAssertEqual(session.gameState, .active)
        
        session.gameState = .ended
        XCTAssertEqual(session.gameState, .ended)
    }
    
    // MARK: - Edge Cases
    
    func testSessionWithMaxPlayers() {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        var players = [host]
        let maxPlayers = 12 // Use constant instead of accessing @MainActor property
        for i in 2...maxPlayers {
            let player = Player(
                displayName: "Player \(i)",
                latitude: 37.7749 + Double(i) * 0.0001,
                longitude: -122.4194 + Double(i) * 0.0001,
                role: .hider,
                isAlive: true,
                lastUpdated: Date(),
                profilePictureBase64: nil
            )
            players.append(player)
        }
        
        let session = GameSession(
            hostId: host.id,
            gameState: .lobby,
            gameType: .manhunt,
            players: players,
            hunterCount: 1
        )
        
        XCTAssertEqual(session.players.count, 12) // Use constant instead of accessing @MainActor property
    }

    // MARK: - Codable Round-Trip (regression: dictionaryToSession truncation)

    /// Regression test for the `dictionaryToSession` truncation bug that
    /// silently dropped CTF fields and would have dropped compass fields.
    /// All optional / collection-typed fields must survive a full encode
    /// → decode round-trip with their values intact.
    func testGameSessionCodableRoundTripPreservesAllFields() throws {
        let host = Player(
            displayName: "Host",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hunter,
            isAlive: true
        )
        let hider = Player(
            displayName: "Hider",
            latitude: 37.7750,
            longitude: -122.4195,
            role: .hider,
            isAlive: true
        )

        var session = GameSession(
            hostId: host.id,
            gameState: .active,
            gameType: .captureTheFlag,
            players: [host, hider],
            hunterCount: 0
        )

        session.teamAFlagPlaced = true
        session.teamBFlagPlaced = false
        session.teamABase = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        session.teamBBase = CLLocationCoordinate2D(latitude: 37.7752, longitude: -122.4198)
        session.teamASafeZone = GameSession.SafeZone(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            radius: 42.0
        )
        session.flagCarriers = ["flagA": hider.id]

        let usedAt = Date(timeIntervalSince1970: 1_700_000_000)
        session.compassPulse = CompassPulse(
            eventId: "evt-1",
            usedByPlayerId: host.id,
            targetPlayerId: hider.id,
            distanceMeters: 123.5,
            usedAt: usedAt
        )
        session.compassLastUsedAtByPlayerId = [host.id: usedAt]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(session)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(GameSession.self, from: data)

        XCTAssertEqual(decoded.id, session.id)
        XCTAssertEqual(decoded.gameType, .captureTheFlag)
        XCTAssertEqual(decoded.teamAFlagPlaced, true)
        XCTAssertEqual(decoded.teamBFlagPlaced, false)
        XCTAssertNotNil(decoded.teamABase)
        XCTAssertNotNil(decoded.teamBBase)
        guard let decodedSafeZone = decoded.teamASafeZone else {
            XCTFail("teamASafeZone should round-trip")
            return
        }
        XCTAssertEqual(decodedSafeZone.radius, 42.0, accuracy: 0.001)
        XCTAssertEqual(decoded.flagCarriers["flagA"], hider.id)

        guard let decodedPulse = decoded.compassPulse else {
            XCTFail("compassPulse should round-trip")
            return
        }
        XCTAssertEqual(decodedPulse.eventId, "evt-1")
        XCTAssertEqual(decodedPulse.usedByPlayerId, host.id)
        XCTAssertEqual(decodedPulse.targetPlayerId, hider.id)
        XCTAssertEqual(decodedPulse.distanceMeters, 123.5, accuracy: 0.001)
        XCTAssertEqual(
            decodedPulse.usedAt.timeIntervalSince1970,
            usedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
        XCTAssertEqual(decoded.compassLastUsedAtByPlayerId.count, 1)
        guard let mappedUsedAt = decoded.compassLastUsedAtByPlayerId[host.id] else {
            XCTFail("compassLastUsedAtByPlayerId should round-trip")
            return
        }
        XCTAssertEqual(
            mappedUsedAt.timeIntervalSince1970,
            usedAt.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    // MARK: - Compass eligibility

    func testEligibleCompassPreyExcludesPredatorAndDeadAndWrongRole() {
        let hunter = Player(
            displayName: "Hunter",
            latitude: 0, longitude: 0,
            role: .hunter, isAlive: true
        )
        let hiderAlive = Player(
            displayName: "HiderAlive",
            latitude: 0, longitude: 0,
            role: .hider, isAlive: true
        )
        let hiderDead = Player(
            displayName: "HiderDead",
            latitude: 0, longitude: 0,
            role: .hider, isAlive: false
        )
        let otherHunter = Player(
            displayName: "OtherHunter",
            latitude: 0, longitude: 0,
            role: .hunter, isAlive: true
        )

        let session = GameSession(
            hostId: hunter.id,
            gameState: .active,
            gameType: .manhunt,
            players: [hunter, hiderAlive, hiderDead, otherHunter],
            hunterCount: 2
        )

        let eligible = session.eligibleCompassPrey(firedBy: hunter.id)
        XCTAssertEqual(eligible.map(\.id), [hiderAlive.id])
    }

    func testEligibleCompassPreyForZombieTag() {
        let zombie = Player(
            displayName: "Zombie",
            latitude: 0, longitude: 0,
            role: .zombie, isAlive: true
        )
        let humanAlive = Player(
            displayName: "Human",
            latitude: 0, longitude: 0,
            role: .human, isAlive: true
        )

        let session = GameSession(
            hostId: zombie.id,
            gameState: .active,
            gameType: .zombieTag,
            players: [zombie, humanAlive],
            hunterCount: 1
        )

        let eligible = session.eligibleCompassPrey(firedBy: zombie.id)
        XCTAssertEqual(eligible.map(\.id), [humanAlive.id])
    }

    func testEligibleCompassPreyEmptyForCTF() {
        let teamA = Player(
            displayName: "TeamA",
            latitude: 0, longitude: 0,
            role: .teamA, isAlive: true
        )
        let teamB = Player(
            displayName: "TeamB",
            latitude: 0, longitude: 0,
            role: .teamB, isAlive: true
        )

        let session = GameSession(
            hostId: teamA.id,
            gameState: .active,
            gameType: .captureTheFlag,
            players: [teamA, teamB],
            hunterCount: 0
        )

        XCTAssertTrue(session.eligibleCompassPrey(firedBy: teamA.id).isEmpty)
        XCTAssertFalse(session.supportsCompassAbility)
    }
}
#endif

