//
//  ManhuntGameFlowTests.swift
//  Touch-GrassTests
//
//  Created to test Manhunt game flow logic
//

import XCTest
@testable import Touch_Grass
import CoreLocation

@MainActor
final class ManhuntGameFlowTests: XCTestCase {
    var locationService: LocationService!
    var gameService: GameService!
    
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
    
    // MARK: - Game End Screen Display Tests
    
    func testGameEndScreenDisplay() {
        // Given: A game session exists and game ends
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: "Test Host", hostLocation: hostLocation, gameType: .manhunt)
        
        // Wait for session to be created
        let sessionExpectation = XCTestExpectation(description: "Session created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            sessionExpectation.fulfill()
        }
        wait(for: [sessionExpectation], timeout: 1.0)
        
        guard let session = gameService.session else {
            XCTFail("Session should exist")
            return
        }
        
        // Configure game
        let bubble = Bubble(
            centerLatitude: hostLocation.latitude,
            centerLongitude: hostLocation.longitude,
            startRadius: 300,
            startTime: Date(),
            shrinkInterval: 180,
            duration: 900,
            shrinkHistory: []
        )
        gameService.configureGame(bubble: bubble, hunterCount: 1)
        
        // Start game
        gameService.beginGame()
        
        // Wait for game to start
        let startExpectation = XCTestExpectation(description: "Game started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)
        
        XCTAssertEqual(gameService.gameState, .active, "Game should be active")
        
        // End game
        gameService.endGame()
        
        // Wait for game to end
        let endExpectation = XCTestExpectation(description: "Game ended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            endExpectation.fulfill()
        }
        wait(for: [endExpectation], timeout: 1.0)
        
        // Then: Game state should be .ended
        XCTAssertEqual(gameService.gameState, .ended, "Game state should be .ended")
        
        // And: GameStats should be populated
        XCTAssertNotNil(gameService.gameStats, "GameStats should be populated when game ends")
        
        // And: Session should still exist
        XCTAssertNotNil(gameService.session, "Session should still exist after game ends")
        
        // And: GameStats should have gameEndTime set
        if let stats = gameService.gameStats {
            XCTAssertNotNil(stats.gameEndTime, "GameStats should have gameEndTime set")
            XCTAssertNotNil(stats.gameStartTime, "GameStats should have gameStartTime set")
        }
    }
    
    // MARK: - Game Stats Generation Tests
    
    func testGameStatsAlwaysPopulated() {
        // Given: A game session exists
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: "Test Host", hostLocation: hostLocation, gameType: .manhunt)
        
        let expectation = XCTestExpectation(description: "Session created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        guard let session = gameService.session else {
            XCTFail("Session should exist")
            return
        }
        
        // Configure and start game
        let bubble = Bubble(
            centerLatitude: hostLocation.latitude,
            centerLongitude: hostLocation.longitude,
            startRadius: 300,
            startTime: Date(),
            shrinkInterval: 180,
            duration: 900,
            shrinkHistory: []
        )
        gameService.configureGame(bubble: bubble, hunterCount: 1)
        gameService.beginGame()
        
        let startExpectation = XCTestExpectation(description: "Game started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)
        
        // When: Game ends
        gameService.endGame()
        
        let endExpectation = XCTestExpectation(description: "Game ended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            endExpectation.fulfill()
        }
        wait(for: [endExpectation], timeout: 1.0)
        
        // Then: GameStats should always be populated
        XCTAssertNotNil(gameService.gameStats, "GameStats should always be populated when game ends")
        
        if let stats = gameService.gameStats {
            XCTAssertNotNil(stats.gameStartTime, "GameStats should have gameStartTime")
            XCTAssertNotNil(stats.gameEndTime, "GameStats should have gameEndTime")
            // Winner may be nil in some edge cases, but stats should still exist
        }
    }
    
    // MARK: - Reset To Lobby Tests
    
    func testResetToLobby() {
        // Given: A game has ended
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: "Test Host", hostLocation: hostLocation, gameType: .manhunt)
        
        let expectation = XCTestExpectation(description: "Session created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        guard let session = gameService.session else {
            XCTFail("Session should exist")
            return
        }
        
        // Configure, start, and end game
        let bubble = Bubble(
            centerLatitude: hostLocation.latitude,
            centerLongitude: hostLocation.longitude,
            startRadius: 300,
            startTime: Date(),
            shrinkInterval: 180,
            duration: 900,
            shrinkHistory: []
        )
        gameService.configureGame(bubble: bubble, hunterCount: 1)
        gameService.beginGame()
        
        let startExpectation = XCTestExpectation(description: "Game started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)
        
        gameService.endGame()
        
        let endExpectation = XCTestExpectation(description: "Game ended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            endExpectation.fulfill()
        }
        wait(for: [endExpectation], timeout: 1.0)
        
        XCTAssertEqual(gameService.gameState, .ended, "Game should be ended")
        
        // When: Reset to lobby is called
        gameService.resetToLobby()
        
        let resetExpectation = XCTestExpectation(description: "Reset to lobby")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            resetExpectation.fulfill()
        }
        wait(for: [resetExpectation], timeout: 1.0)
        
        // Then: Game state should be .lobby
        XCTAssertEqual(gameService.gameState, .lobby, "Game state should be .lobby after reset")
        
        // And: Session should still exist
        XCTAssertNotNil(gameService.session, "Session should still exist after reset to lobby")
        
        // And: Session gameState should be .lobby
        if let session = gameService.session {
            XCTAssertEqual(session.gameState, .lobby, "Session gameState should be .lobby")
        }
    }
    
    // MARK: - Play Again Tests
    
    func testPlayAgain() {
        // Given: A game has ended
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: "Test Host", hostLocation: hostLocation, gameType: .manhunt)
        
        let expectation = XCTestExpectation(description: "Session created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        guard let session = gameService.session else {
            XCTFail("Session should exist")
            return
        }
        
        let initialGameNumber = session.gameNumber
        
        // Configure, start, and end game
        let bubble = Bubble(
            centerLatitude: hostLocation.latitude,
            centerLongitude: hostLocation.longitude,
            startRadius: 300,
            startTime: Date(),
            shrinkInterval: 180,
            duration: 900,
            shrinkHistory: []
        )
        gameService.configureGame(bubble: bubble, hunterCount: 1)
        gameService.beginGame()
        
        let startExpectation = XCTestExpectation(description: "Game started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)
        
        gameService.endGame()
        
        let endExpectation = XCTestExpectation(description: "Game ended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            endExpectation.fulfill()
        }
        wait(for: [endExpectation], timeout: 1.0)
        
        XCTAssertEqual(gameService.gameState, .ended, "Game should be ended")
        
        // When: Play again is called
        gameService.playAgain()

        // Then: Game state should be .lobby
        XCTAssertEqual(gameService.gameState, .lobby, "Game state should be .lobby after play again")
        
        // And: Game number should be incremented
        if let session = gameService.session {
            XCTAssertEqual(session.gameNumber, initialGameNumber + 1, "Game number should be incremented")
            XCTAssertEqual(session.gameState, .lobby, "Session gameState should be .lobby")
            XCTAssertNil(session.bubble, "Bubble should be cleared for play again")
        }
        
        // And: GameStats should be cleared
        XCTAssertNil(gameService.gameStats, "GameStats should be cleared after play again")
    }
    
    // MARK: - Game End Transition Tests
    
    func testGameEndTransition() {
        // Given: A game is active
        let hostLocation = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        gameService.createSession(hostName: "Test Host", hostLocation: hostLocation, gameType: .manhunt)
        
        let expectation = XCTestExpectation(description: "Session created")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Configure and start game
        let bubble = Bubble(
            centerLatitude: hostLocation.latitude,
            centerLongitude: hostLocation.longitude,
            startRadius: 300,
            startTime: Date(),
            shrinkInterval: 180,
            duration: 900,
            shrinkHistory: []
        )
        gameService.configureGame(bubble: bubble, hunterCount: 1)
        gameService.beginGame()
        
        let startExpectation = XCTestExpectation(description: "Game started")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            startExpectation.fulfill()
        }
        wait(for: [startExpectation], timeout: 1.0)
        
        XCTAssertEqual(gameService.gameState, .active, "Game should be active")
        
        // When: Game ends
        gameService.endGame()
        
        let endExpectation = XCTestExpectation(description: "Game ended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            endExpectation.fulfill()
        }
        wait(for: [endExpectation], timeout: 1.0)
        
        // Then: Game state should transition from .active to .ended
        XCTAssertEqual(gameService.gameState, .ended, "Game state should be .ended")
        
        // And: Session gameState should also be .ended
        if let session = gameService.session {
            XCTAssertEqual(session.gameState, .ended, "Session gameState should be .ended")
        }
        
        // And: GameStats should be available
        XCTAssertNotNil(gameService.gameStats, "GameStats should be available after game ends")
    }
}
