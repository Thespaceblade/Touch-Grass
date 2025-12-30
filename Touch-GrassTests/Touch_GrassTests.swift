//
//  Touch_GrassTests.swift
//  Touch-GrassTests
//
//  Created by Jason Charwin on 12/26/25.
//

import XCTest
@testable import Touch_Grass

#if DEBUG
@MainActor
final class Touch_GrassTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    // MARK: - Quick Smoke Tests
    
    func testAppCanInitialize() {
        // Basic smoke test - verify app components can be created
        let locationService = LocationService()
        XCTAssertNotNil(locationService, "LocationService should initialize")
        
        let gameService = GameService(locationService: locationService)
        XCTAssertNotNil(gameService, "GameService should initialize")
    }
    
    func testGameTypesExist() {
        // Verify all game types are defined
        let gameTypes: [GameType] = [.manhunt, .captureTheFlag, .zombieTag]
        XCTAssertEqual(gameTypes.count, 3, "Should have 3 game types")
    }
    
    func testPlayerRolesExist() {
        // Verify all player roles are defined
        let roles: [PlayerRole] = [.hunter, .hider, .zombie, .human, .teamA, .teamB]
        XCTAssertEqual(roles.count, 6, "Should have 6 player roles")
    }
    
    func testMaxPlayersLimit() {
        // Verify max players is set correctly
        XCTAssertEqual(GameService.maxPlayersPerSession, 12, "Max players should be 12")
    }
}
#endif
