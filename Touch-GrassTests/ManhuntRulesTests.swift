//
//  ManhuntRulesTests.swift
//  Touch-GrassTests
//
//  Unit tests for GameService Manhunt rules (catch, honor, zone, timer, hunters).
//

import XCTest
import CoreLocation
@testable import Touch_Grass

@MainActor
final class ManhuntRulesTests: XCTestCase {
    var locationService: LocationService!
    var gameService: GameService!

    private let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

    override func setUp() {
        super.setUp()
        locationService = LocationService()
        gameService = GameService(locationService: locationService)
        TestServiceRetainer.retain(locationService)
        TestServiceRetainer.retain(gameService)
    }

    override func tearDown() {
        gameService.clearSession()
        gameService = nil
        locationService = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func defaultBubble(
        duration: TimeInterval = 900,
        startTime: Date = Date(),
        startRadius: Double = 300,
        enableShrinking: Bool = false
    ) -> Bubble {
        Bubble(
            centerLatitude: hostLocation.latitude,
            centerLongitude: hostLocation.longitude,
            startRadius: startRadius,
            startTime: startTime,
            shrinkInterval: 180,
            duration: duration,
            shrinkHistory: [],
            enableShrinking: enableShrinking,
            usesNewZoneSystem: false
        )
    }

    @discardableResult
    private func makeLobby(
        extraPlayerNames: [String] = ["Hider One", "Hider Two"],
        hunterCount: Int = 1,
        bubble: Bubble? = nil
    ) -> (hostId: String, hiderIds: [String]) {
        gameService.createSession(hostName: "Host", hostLocation: hostLocation, gameType: .manhunt)
        gameService.testing_stopSessionListener()
        guard var session = gameService.session, let hostId = gameService.currentPlayer?.id else {
            XCTFail("Session not created")
            return ("", [])
        }

        var hiderIds: [String] = []
        for name in extraPlayerNames {
            let id = UUID().uuidString
            hiderIds.append(id)
            session.players.append(
                Player(
                    id: id,
                    displayName: name,
                    latitude: hostLocation.latitude,
                    longitude: hostLocation.longitude,
                    role: .hider
                )
            )
        }
        gameService.session = session
        gameService.configureGame(bubble: bubble ?? defaultBubble(), hunterCount: hunterCount)
        return (hostId, hiderIds)
    }

    private func beginActiveMatch(startTimer: Bool = true) {
        gameService.beginGame()
        XCTAssertEqual(gameService.gameState, .active)
        if startTimer {
            gameService.startGameTimer()
        }
    }

    private func player(withId id: String) -> Player? {
        gameService.session?.players.first { $0.id == id }
    }

    private func setCurrentPlayer(id: String) {
        guard let player = player(withId: id) else {
            XCTFail("Player \(id) not in session")
            return
        }
        gameService.currentPlayer = player
    }

    private func commitMatchStart(secondsAgo: TimeInterval = 0) {
        guard var session = gameService.session, var bubble = session.bubble else {
            XCTFail("No bubble")
            return
        }
        bubble.startTime = Date().addingTimeInterval(-secondsAgo)
        session.bubble = bubble
        gameService.session = session
    }

    // MARK: - Catch / honor

    func testApplyManhuntHiderCaught_ble() {
        _ = makeLobby(extraPlayerNames: ["Hider A", "Hider B"])
        beginActiveMatch()
        commitMatchStart()

        guard let session = gameService.session,
              let hunter = session.players.first(where: { $0.role == .hunter }),
              let target = session.players.first(where: { $0.role == .hider })
        else {
            XCTFail("Expected hunter and hider after beginGame")
            return
        }

        let targetId = target.id
        setCurrentPlayer(id: hunter.id)
        gameService.testing_simulateManhuntBleCatch(hiderId: targetId)

        XCTAssertFalse(player(withId: targetId)?.isAlive ?? true)
        XCTAssertTrue(gameService.caughtPlayers.contains(targetId))
        XCTAssertEqual(gameService.session?.firstTaggedPlayerId, targetId)

        let catchRecords = gameService.gameStats?.catches ?? []
        XCTAssertEqual(catchRecords.count, 1)
        XCTAssertEqual(catchRecords.first?.hiderId, targetId)
        XCTAssertEqual(catchRecords.first?.hunterId, hunter.id)
        XCTAssertNotNil(gameService.gameStats?.survivalTimes[targetId])
    }

    func testHonorReportTagged() {
        let (_, hiderIds) = makeLobby(extraPlayerNames: ["Hider A"])
        beginActiveMatch()
        commitMatchStart()

        let hiderId = hiderIds[0]
        guard var session = gameService.session,
              let idx = session.players.firstIndex(where: { $0.id == hiderId }) else {
            XCTFail("Hider missing")
            return
        }
        session.players[idx].role = .hider
        gameService.session = session
        setCurrentPlayer(id: hiderId)

        gameService.honorReportTagged()

        XCTAssertFalse(player(withId: hiderId)?.isAlive ?? true)
        XCTAssertTrue(gameService.caughtPlayers.contains(hiderId))
        XCTAssertEqual(gameService.session?.firstTaggedPlayerId, hiderId)
        XCTAssertTrue(gameService.gameStats?.catches.isEmpty ?? false, "Honor must not create CatchRecord")
        XCTAssertNotNil(gameService.gameStats?.survivalTimes[hiderId])
    }

    // MARK: - Zone elimination

    func testZoneEliminationEndsGameForHunters() {
        let bubble = defaultBubble(startRadius: 80, enableShrinking: false)
        _ = makeLobby(extraPlayerNames: ["Solo Hider"], bubble: bubble)
        beginActiveMatch()
        commitMatchStart()

        guard let hiderId = gameService.session?.players.first(where: { $0.role == .hider })?.id else {
            XCTFail("Expected at least one hider")
            return
        }
        setCurrentPlayer(id: hiderId)

        let outside = CLLocationCoordinate2D(
            latitude: hostLocation.latitude + 0.01,
            longitude: hostLocation.longitude
        )
        gameService.updatePlayerLocation(outside)

        XCTAssertFalse(player(withId: hiderId)?.isAlive ?? true)
        XCTAssertEqual(gameService.session?.firstTaggedPlayerId, hiderId)

        gameService.checkGameOver()
        XCTAssertTrue(gameService.shouldEndGame)

        gameService.endGame()
        XCTAssertEqual(gameService.gameStats?.winner, .hunters)
    }

    // MARK: - Timer

    func testTimerExpiryHidersWin() {
        let bubble = defaultBubble(duration: 10)
        makeLobby(extraPlayerNames: ["Hider A"], bubble: bubble)
        beginActiveMatch()
        commitMatchStart(secondsAgo: 11)

        gameService.shouldEndGame = false
        gameService.checkGameOver()
        XCTAssertTrue(gameService.shouldEndGame)

        gameService.endGame()
        XCTAssertEqual(gameService.gameStats?.winner, .timeUp)
    }

    func testBeginGameDoesNotExpireDuringCountdown() {
        let bubble = defaultBubble(duration: 1)
        makeLobby(extraPlayerNames: ["Hider A"], bubble: bubble)
        gameService.beginGame()

        guard let bubbleAfterBegin = gameService.session?.bubble else {
            XCTFail("No bubble")
            return
        }
        XCTAssertGreaterThan(bubbleAfterBegin.startTime, Date())

        gameService.shouldEndGame = false
        gameService.checkGameOver()
        XCTAssertFalse(gameService.shouldEndGame)

        gameService.endGame()
        XCTAssertNotEqual(gameService.gameStats?.winner, .timeUp)
    }

    // MARK: - Hunter rotation

    func testAssignHuntersFromFirstTagged() {
        _ = makeLobby(extraPlayerNames: ["Tagged Hider", "Other Hider"])
        beginActiveMatch()
        commitMatchStart()

        guard let session = gameService.session,
              let hunter = session.players.first(where: { $0.role == .hunter }),
              let hiderToTag = session.players.first(where: { $0.role == .hider && $0.id != hunter.id })
        else {
            XCTFail("Expected one hunter and at least one hider after beginGame")
            return
        }

        let taggedId = hiderToTag.id
        setCurrentPlayer(id: hunter.id)
        gameService.testing_simulateManhuntBleCatch(hiderId: taggedId)
        XCTAssertEqual(gameService.session?.firstTaggedPlayerId, taggedId)
        gameService.endGame()

        gameService.playAgain()
        XCTAssertEqual(gameService.session?.gameNumber, 2)
        XCTAssertEqual(gameService.session?.firstTaggedPlayerId, taggedId)

        gameService.testing_stopSessionListener()
        gameService.configureGame(bubble: defaultBubble(), hunterCount: 1)
        XCTAssertEqual(gameService.session?.gameNumber, 2)
        XCTAssertEqual(gameService.session?.firstTaggedPlayerId, taggedId)

        gameService.beginGame()
        XCTAssertEqual(player(withId: taggedId)?.role, .hunter, "First tagged player should be hunter in game 2")
    }

    func testHostOnlyStartGameTimer() {
        let (hostId, hiderIds) = makeLobby(extraPlayerNames: ["Guest"])
        let guestId = hiderIds[0]
        beginActiveMatch(startTimer: false)

        guard var distant = gameService.session?.bubble?.startTime else {
            XCTFail("No bubble")
            return
        }
        XCTAssertGreaterThan(distant, Date())

        setCurrentPlayer(id: guestId)
        gameService.startGameTimer()

        XCTAssertGreaterThan(gameService.session?.bubble?.startTime ?? Date.distantPast, Date())

        setCurrentPlayer(id: hostId)
        gameService.startGameTimer()

        let started = gameService.session?.bubble?.startTime ?? Date.distantFuture
        XCTAssertLessThanOrEqual(started, Date())
    }

    func testManualHunterAssignment() {
        let (hostId, hiderIds) = makeLobby(extraPlayerNames: ["Pick Me", "Other"])
        let manualHunterId = hiderIds[0]

        gameService.setHunter(playerId: manualHunterId)
        XCTAssertEqual(player(withId: manualHunterId)?.role, .hunter)

        gameService.beginGame()

        XCTAssertEqual(player(withId: manualHunterId)?.role, .hunter)
        XCTAssertEqual(
            gameService.session?.players.filter { $0.role == .hunter }.count,
            1
        )
        XCTAssertEqual(player(withId: hostId)?.role, .hider)
    }
}
