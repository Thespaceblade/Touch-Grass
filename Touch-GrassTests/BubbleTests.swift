//
//  BubbleTests.swift
//  Touch-GrassTests
//
//  Debug-only unit tests for Bubble calculations
//

import XCTest
import CoreLocation
@testable import Touch_Grass

#if DEBUG
final class BubbleTests: XCTestCase {
    
    // MARK: - Bubble Creation Tests
    
    func testBubbleCreation() {
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        XCTAssertEqual(bubble.centerLatitude, 37.7749, accuracy: 0.0001)
        XCTAssertEqual(bubble.centerLongitude, -122.4194, accuracy: 0.0001)
        XCTAssertEqual(bubble.startRadius, 500.0, accuracy: 0.1)
        XCTAssertEqual(bubble.shrinkInterval, 180.0, accuracy: 0.1)
        XCTAssertEqual(bubble.duration, 1800.0, accuracy: 0.1)
    }
    
    // MARK: - Current Radius Tests
    
    func testCurrentRadiusAtStart() {
        let startTime = Date()
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: startTime,
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        let currentRadius = bubble.currentRadius(at: startTime)
        XCTAssertEqual(currentRadius, 500.0, accuracy: 0.1, "Radius should be start radius at start time")
    }
    
    func testCurrentRadiusAfterShrink() {
        let startTime = Date()
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: startTime,
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        // After one shrink interval (180 seconds)
        let afterShrink = startTime.addingTimeInterval(180.0)
        let currentRadius = bubble.currentRadius(at: afterShrink)
        
        // Should have shrunk by 15% (default shrink amount)
        let expectedRadius = 500.0 * 0.85
        XCTAssertEqual(currentRadius, expectedRadius, accuracy: 1.0, "Radius should shrink after interval")
    }
    
    // MARK: - Distance to Edge Tests
    
    func testDistanceToEdgeInsideBubble() {
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        // Point inside bubble (100m from center)
        let pointInside = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4194)
        let distance = bubble.distanceToEdge(from: pointInside)
        
        // Should be negative (inside) or positive distance to edge
        // Distance from center is ~111m, so distance to edge should be ~389m (500 - 111)
        XCTAssertLessThan(abs(distance), 500.0, "Distance should be less than radius")
    }
    
    func testDistanceToEdgeOutsideBubble() {
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        // Point far outside bubble (1000m from center)
        let pointOutside = CLLocationCoordinate2D(latitude: 37.7840, longitude: -122.4194)
        let distance = bubble.distanceToEdge(from: pointOutside)
        
        // Should be positive (outside)
        XCTAssertGreaterThan(distance, 0, "Distance should be positive when outside")
    }
    
    func testDistanceToEdgeAtCenter() {
        let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let bubble = Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        let distance = bubble.distanceToEdge(from: center)
        
        // At center, distance to edge should equal radius
        XCTAssertEqual(abs(distance), 500.0, accuracy: 1.0, "Distance at center should equal radius")
    }
    
    // MARK: - Shrink History Tests
    
    func testShrinkHistoryTracking() {
        let startTime = Date()
        var bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: startTime,
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        // Simulate a shrink event
        let shrinkEvent = Bubble.ShrinkEvent(
            phase: 1,
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            radius: 425.0,
            timestamp: startTime.addingTimeInterval(180.0)
        )
        
        bubble.shrinkHistory.append(shrinkEvent)
        
        XCTAssertEqual(bubble.shrinkHistory.count, 1, "Should have one shrink event")
        XCTAssertEqual(bubble.shrinkHistory.first?.phase, 1, "Shrink phase should be 1")
        if let radius = bubble.shrinkHistory.first?.radius {
            XCTAssertEqual(radius, 425.0, accuracy: 0.1, "Shrink radius should be correct")
        } else {
            XCTFail("Shrink event should have a radius")
        }
    }
    
    // MARK: - Edge Cases
    
    func testZeroRadiusBubble() {
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 0.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        let currentRadius = bubble.currentRadius(at: Date())
        XCTAssertEqual(currentRadius, 0.0, accuracy: 0.1, "Zero radius bubble should stay zero")
    }
    
    func testVeryLargeRadiusBubble() {
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 10000.0, // 10km
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        let currentRadius = bubble.currentRadius(at: Date())
        XCTAssertEqual(currentRadius, 10000.0, accuracy: 1.0, "Large radius should be preserved")
    }
    
    func testInfiniteDurationBubble() {
        let bubble = Bubble(
            centerLatitude: 37.7749,
            centerLongitude: -122.4194,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: .infinity,
            duration: .infinity
        )
        
        // Bubble with infinite duration should not shrink
        let futureTime = Date().addingTimeInterval(3600.0) // 1 hour later
        let currentRadius = bubble.currentRadius(at: futureTime)
        XCTAssertEqual(currentRadius, 500.0, accuracy: 0.1, "Infinite duration bubble should not shrink")
    }
}
#endif

