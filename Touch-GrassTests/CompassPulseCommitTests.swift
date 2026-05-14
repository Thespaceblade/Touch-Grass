//
//  CompassPulseCommitTests.swift
//  Touch-GrassTests
//

import XCTest
import CoreLocation
@testable import Touch_Grass

#if DEBUG
@MainActor
final class CompassPulseCommitTests: XCTestCase {

    func testCompassPulseCommitEquatable() {
        let pulse = CompassPulse(
            eventId: "e1",
            usedByPlayerId: "a",
            targetPlayerId: "t",
            distanceMeters: 100,
            usedAt: Date(timeIntervalSince1970: 10)
        )
        let c1 = CompassPulseCommit(
            pulse: pulse,
            actorLatitude: 40.0,
            actorLongitude: -74.0,
            targetLatitude: 40.01,
            targetLongitude: -74.0
        )
        let c2 = CompassPulseCommit(
            pulse: pulse,
            actorLatitude: 40.0,
            actorLongitude: -74.0,
            targetLatitude: 40.01,
            targetLongitude: -74.0
        )
        XCTAssertEqual(c1, c2)
    }

    func testCompassBearingMatchesGreatCircleFromCommitCoordinatesOnly() {
        let locationService = LocationService()
        let gameService = GameService(locationService: locationService)
        TestServiceRetainer.retain(locationService)
        TestServiceRetainer.retain(gameService)

        let pulse = CompassPulse(
            eventId: "e1",
            usedByPlayerId: "pred",
            targetPlayerId: "prey",
            distanceMeters: 0,
            usedAt: Date()
        )
        let commit = CompassPulseCommit(
            pulse: pulse,
            actorLatitude: 40.6602,
            actorLongitude: -73.9690,
            targetLatitude: 40.6702,
            targetLongitude: -73.9690
        )

        let actor = CLLocation(latitude: commit.actorLatitude, longitude: commit.actorLongitude)
        let target = CLLocation(latitude: commit.targetLatitude, longitude: commit.targetLongitude)
        let expected = actor.bearing(to: target)

        let bearing = gameService.compassBearing(for: commit)
        XCTAssertNotNil(bearing)
        XCTAssertEqual(bearing!, expected, accuracy: 0.05)
    }

    func testCompassBearingIgnoresSessionPlayerCoordinates() {
        let locationService = LocationService()
        let gameService = GameService(locationService: locationService)
        TestServiceRetainer.retain(locationService)
        TestServiceRetainer.retain(gameService)

        let pulse = CompassPulse(
            eventId: "e1",
            usedByPlayerId: "pred",
            targetPlayerId: "prey",
            distanceMeters: 0,
            usedAt: Date()
        )
        let commit = CompassPulseCommit(
            pulse: pulse,
            actorLatitude: 40.0,
            actorLongitude: -74.0,
            targetLatitude: 40.002,
            targetLongitude: -74.0
        )

        let bearingBefore = gameService.compassBearing(for: commit)

        var session = GameSession(
            hostId: "h",
            gameState: .active,
            gameType: .manhunt,
            bubble: nil,
            players: [
                Player(
                    id: "prey",
                    displayName: "Prey",
                    latitude: 1.0,
                    longitude: 1.0,
                    role: .hider,
                    isAlive: true,
                    isFlag: false,
                    isTeamLeader: false
                )
            ],
            catchDistance: 10,
            joinCode: "000000",
            hunterCount: 1
        )
        gameService.session = session

        XCTAssertEqual(gameService.compassBearing(for: commit), bearingBefore)
    }
}
#endif
