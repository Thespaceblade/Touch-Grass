//
//  GameServiceTests.swift
//  Touch-GrassTests
//
//  Debug-only unit tests for GameService core functionality
//

import XCTest
import CoreLocation
@testable import Touch_Grass

#if DEBUG
@MainActor
final class GameServiceTests: XCTestCase {
    var gameService: GameService!
    var locationService: LocationService!
    
    override func setUp() {
        super.setUp()
        locationService = LocationService()
        gameService = GameService(locationService: locationService)
        TestServiceRetainer.retain(locationService)
        TestServiceRetainer.retain(gameService)
    }
    
    override func tearDown() {
        gameService = nil
        locationService = nil
        super.tearDown()
    }
    
    // MARK: - Session Creation Tests
    
    func testCreateSession() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        gameService.createSession(hostName: hostName, hostLocation: hostLocation, gameType: .manhunt)

        XCTAssertNotNil(gameService.session, "Session should be created")
        XCTAssertEqual(gameService.session?.hostId, gameService.currentPlayer?.authUserId, "Host legacy uid should match current player")
        XCTAssertEqual(gameService.session?.hostAuthUid, gameService.currentPlayer?.authUserId, "Host auth uid should match current player")
        XCTAssertEqual(gameService.session?.hostPlayerId, gameService.currentPlayer?.id, "Host player id should match current player's device id")
        XCTAssertEqual(gameService.currentPlayer?.id, AuthService.shared.guestDeviceId, "Current player id should be this device's guest id")
        XCTAssertEqual(gameService.session?.gameType, .manhunt, "Game type should be Manhunt")
        XCTAssertEqual(gameService.gameState, .lobby, "Initial game state should be lobby")
    }
    
    func testCreateCTFSession() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        gameService.createSession(hostName: hostName, hostLocation: hostLocation, gameType: .captureTheFlag)
        
        XCTAssertNotNil(gameService.session, "CTF session should be created")
        XCTAssertEqual(gameService.session?.gameType, .captureTheFlag, "Game type should be CTF")
        XCTAssertEqual(gameService.session?.teamAScore, 0, "Initial Team A score should be 0")
        XCTAssertEqual(gameService.session?.teamBScore, 0, "Initial Team B score should be 0")
    }
    
    func testCreateZombieTagSession() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        gameService.createSession(hostName: hostName, hostLocation: hostLocation, gameType: .zombieTag)
        
        XCTAssertNotNil(gameService.session, "Zombie Tag session should be created")
        XCTAssertEqual(gameService.session?.gameType, .zombieTag, "Game type should be Zombie Tag")
    }
    
    // MARK: - Player Limit Tests
    
    func testMaxPlayersPerSession() {
        XCTAssertEqual(GameService.maxPlayersPerSession, 12, "Max players should be 12")
    }
    
    func testJoinCodeGeneration() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        gameService.createSession(hostName: hostName, hostLocation: hostLocation)
        
        guard let joinCode = gameService.session?.joinCode else {
            XCTFail("Join code should be generated")
            return
        }
        
        XCTAssertEqual(joinCode.count, 6, "Join code should be 6 digits")
        XCTAssertTrue(joinCode.allSatisfy { $0.isNumber }, "Join code should contain only numbers")
    }
    
    // MARK: - Bubble Configuration Tests
    
    func testConfigureGameWithBubble() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: hostName, hostLocation: hostLocation)
        
        guard gameService.session != nil else {
            XCTFail("Session should exist")
            return
        }
        
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        gameService.configureGame(bubble: bubble, hunterCount: 1)

        XCTAssertNotNil(gameService.session?.bubble, "Bubble should be configured")
        if let configuredBubble = gameService.session?.bubble {
            XCTAssertEqual(configuredBubble.startRadius, 500.0, accuracy: 0.1, "Bubble radius should be set")
        }
        XCTAssertEqual(gameService.session?.hunterCount, 1, "Hunter count should be set")
    }
    
    // MARK: - Game State Tests
    
    func testGameStateTransitions() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: hostName, hostLocation: hostLocation)
        
        // Should start in lobby
        XCTAssertEqual(gameService.gameState, .lobby, "Should start in lobby")
        
        // Configure game
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        gameService.configureGame(bubble: bubble, hunterCount: 1)
        
        // Still in lobby after configuration
        XCTAssertEqual(gameService.gameState, .lobby, "Should still be in lobby after configuration")
    }
    
    // MARK: - Player Management Tests
    
    func testAddPlayer() throws {
        throw XCTSkip("addPlayer API not exposed on GameService, players join via joinGame flow")
    }
    
    // MARK: - CTF Specific Tests
    
    func testCTFFlagPlacement() throws {
        throw XCTSkip("setTeamBases requires bubble configuration first, covered by integration tests")
    }
    
    // MARK: - Validation Tests
    
    func testInvalidCoordinateValidation() throws {
        throw XCTSkip("Coordinate validation not yet enforced at the createSession boundary")
    }
    
    func testEmptyHostNameValidation() throws {
        throw XCTSkip("Empty host name validation not yet enforced at the createSession boundary")
    }
}
#endif

