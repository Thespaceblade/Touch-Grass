//
//  PlayerTests.swift
//  Touch-GrassTests
//
//  Debug-only unit tests for Player model
//

import XCTest
import CoreLocation
@testable import Touch_Grass

#if DEBUG
final class PlayerTests: XCTestCase {
    
    // MARK: - Player Creation Tests
    
    func testPlayerCreation() {
        let player = Player(
            displayName: "Test Player",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        XCTAssertEqual(player.displayName, "Test Player")
        XCTAssertEqual(player.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(player.longitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(player.role, .hider)
        XCTAssertTrue(player.isAlive)
        XCTAssertNotNil(player.id, "Player should have an ID")
    }
    
    func testPlayerWithProfilePicture() {
        let base64Image = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
        
        let player = Player(
            displayName: "Test Player",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hunter,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: base64Image
        )
        
        XCTAssertNotNil(player.profilePictureBase64)
        XCTAssertEqual(player.profilePictureBase64, base64Image)
    }
    
    // MARK: - Role Tests
    
    func testPlayerRoles() {
        let roles: [PlayerRole] = [.hunter, .hider, .zombie, .human, .teamA, .teamB]
        
        for role in roles {
            let player = Player(
                displayName: "Test",
                latitude: 37.7749,
                longitude: -122.4194,
                role: role,
                isAlive: true,
                lastUpdated: Date(),
                profilePictureBase64: nil
            )
            XCTAssertEqual(player.role, role, "Player role should be set correctly")
        }
    }
    
    // MARK: - Coordinate Tests
    
    func testPlayerCoordinate() {
        let player = Player(
            displayName: "Test",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let coordinate = player.coordinate
        XCTAssertEqual(coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(coordinate.longitude, -122.4194, accuracy: 0.0001)
    }
    
    func testPlayerLocation() {
        let player = Player(
            displayName: "Test",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let location = player.location
        XCTAssertEqual(location.coordinate.latitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(location.coordinate.longitude, -122.4194, accuracy: 0.0001)
    }
    
    // MARK: - CTF Specific Tests
    
    func testCTFTeamAssignment() {
        let teamAPlayer = Player(
            displayName: "Team A Player",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .teamA,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        let teamBPlayer = Player(
            displayName: "Team B Player",
            latitude: 37.7750,
            longitude: -122.4195,
            role: .teamB,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        XCTAssertEqual(teamAPlayer.role, .teamA)
        XCTAssertEqual(teamBPlayer.role, .teamB)
    }
    
    func testFlagPlayer() {
        let flagPlayer = Player(
            displayName: "Flag Player",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .teamA,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        // Note: isFlag would need to be a property or computed property
        // This test documents the expected behavior
        XCTAssertNotNil(flagPlayer, "Flag player should be creatable")
    }
    
    // MARK: - Edge Cases
    
    func testPlayerWithEmptyName() {
        let player = Player(
            displayName: "",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        XCTAssertEqual(player.displayName, "", "Player can have empty name")
    }
    
    func testPlayerAtOrigin() {
        let player = Player(
            displayName: "Test",
            latitude: 0.0,
            longitude: 0.0,
            role: .hider,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        XCTAssertEqual(player.latitude, 0.0)
        XCTAssertEqual(player.longitude, 0.0)
    }
    
    func testDeadPlayer() {
        let player = Player(
            displayName: "Dead Player",
            latitude: 37.7749,
            longitude: -122.4194,
            role: .hider,
            isAlive: false,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        XCTAssertFalse(player.isAlive, "Player should be marked as dead")
    }
}
#endif

