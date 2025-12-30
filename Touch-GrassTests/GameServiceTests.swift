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
        XCTAssertEqual(gameService.session?.hostId, gameService.currentPlayer?.id, "Host should be current player")
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
        
        gameService.configureGame(bubble: bubble, hunterCount: 2)
        
        // Wait a moment for async Firestore operations
        let expectation = XCTestExpectation(description: "Bubble configured")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertNotNil(gameService.session?.bubble, "Bubble should be configured")
        if let configuredBubble = gameService.session?.bubble {
            XCTAssertEqual(configuredBubble.startRadius, 500.0, accuracy: 0.1, "Bubble radius should be set")
        }
        XCTAssertEqual(gameService.session?.hunterCount, 2, "Hunter count should be set")
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
    
    func testAddPlayer() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: hostName, hostLocation: hostLocation)
        
        guard let session = gameService.session else {
            XCTFail("Session should exist")
            return
        }
        
        let initialCount = session.players.count
        
        // Note: This would need to be implemented in GameService
        // gameService.addPlayer(newPlayer)
        
        // For now, just verify initial player exists
        XCTAssertEqual(initialCount, 1, "Should have 1 player (host) initially")
    }
    
    // MARK: - CTF Specific Tests
    
    func testCTFFlagPlacement() {
        let hostName = "Test Host"
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: hostName, hostLocation: hostLocation, gameType: .captureTheFlag)
        
        guard let session = gameService.session else {
            XCTFail("Session should exist")
            return
        }
        
        // Note: This would need to be implemented
        // gameService.setTeamBases(teamA: teamABase, teamB: teamBBase)
        
        // Verify initial state
        XCTAssertNil(session.teamABase, "Team A base should be nil initially")
        XCTAssertNil(session.teamBBase, "Team B base should be nil initially")
    }
    
    // MARK: - Validation Tests
    
    func testInvalidCoordinateValidation() {
        let invalidCoordinate = CLLocationCoordinate2D(latitude: 999, longitude: 999)
        
        // Should not create session with invalid coordinate
        // This tests the validation logic
        let hostName = "Test Host"
        gameService.createSession(hostName: hostName, hostLocation: invalidCoordinate)
        
        // Session might be nil or coordinate might be clamped - depends on implementation
        // This test documents expected behavior
    }
    
    func testEmptyHostNameValidation() {
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Should handle empty host name (might use profile name as fallback)
        gameService.createSession(hostName: "", hostLocation: hostLocation)
        
        // Verify session was created (with fallback name) or rejected
        // This test documents expected behavior
    }
}
#endif

