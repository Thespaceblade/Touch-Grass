//
//  LocationServiceTests.swift
//  Touch-GrassTests
//

import XCTest
import CoreLocation
@testable import Touch_Grass

#if DEBUG
@MainActor
final class LocationServiceTests: XCTestCase {

    func testGetCurrentLocationPreservesStaleTimestampFromDidUpdateLocations() {
        let service = LocationService()
        TestServiceRetainer.retain(service)

        let past = Date(timeIntervalSinceNow: -600)
        let loc = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.334, longitude: -122.009),
            altitude: 0,
            horizontalAccuracy: 12,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: past
        )

        service.locationManager(CLLocationManager(), didUpdateLocations: [loc])

        XCTAssertEqual(service.getCurrentLocation()?.timestamp, past)
        let age = Date().timeIntervalSince(service.getCurrentLocation()!.timestamp)
        XCTAssertGreaterThan(age, CompassAbilityConfig.maxActorLocationAge)
    }

    func testSkippedDidUpdateDoesNotRefreshLastKnownLocation() {
        let service = LocationService()
        TestServiceRetainer.retain(service)

        let firstTime = Date(timeIntervalSinceNow: -300)
        let first = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.0, longitude: -74.0),
            altitude: 0,
            horizontalAccuracy: 20,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: firstTime
        )
        service.locationManager(CLLocationManager(), didUpdateLocations: [first])
        XCTAssertEqual(service.getCurrentLocation()?.timestamp, firstTime)

        // Same spot, worse accuracy, <3m movement → rejected by filter
        let secondTime = Date()
        let second = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.0 + 1e-7, longitude: -74.0),
            altitude: 0,
            horizontalAccuracy: 80,
            verticalAccuracy: -1,
            course: -1,
            speed: -1,
            timestamp: secondTime
        )
        service.locationManager(CLLocationManager(), didUpdateLocations: [second])

        XCTAssertEqual(service.getCurrentLocation()?.timestamp, firstTime)
    }
}
#endif
