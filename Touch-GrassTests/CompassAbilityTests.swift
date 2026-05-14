//
//  CompassAbilityTests.swift
//  Touch-GrassTests
//
//  Pure unit tests for `CompassAbilityConfig` math. These guard the
//  contract that `GameService` (eligibility) and the SwiftUI control
//  (charging ring) both depend on, if either gets out of sync, the
//  cooldown ring would lie about when the ability is actually fireable.
//

import XCTest
@testable import Touch_Grass

#if DEBUG
final class CompassAbilityTests: XCTestCase {

    // MARK: - cooldownDuration

    func testCooldownStartsAtCooldownStartForElapsedZero() {
        let total: TimeInterval = 1800
        let value = CompassAbilityConfig.cooldownDuration(elapsed: 0, totalDuration: total)
        XCTAssertEqual(value, CompassAbilityConfig.cooldownStart, accuracy: 0.001)
    }

    func testCooldownClampsAtCooldownEndPastTaperPoint() {
        let total: TimeInterval = 1800
        let pastTaper = total * (CompassAbilityConfig.cooldownTaperPoint + 0.1)
        let value = CompassAbilityConfig.cooldownDuration(elapsed: pastTaper, totalDuration: total)
        XCTAssertEqual(value, CompassAbilityConfig.cooldownEnd, accuracy: 0.001)
    }

    func testCooldownInterpolatesLinearlyAtTaperMidpoint() {
        let total: TimeInterval = 1800
        let mid = total * (CompassAbilityConfig.cooldownTaperPoint / 2.0)
        let value = CompassAbilityConfig.cooldownDuration(elapsed: mid, totalDuration: total)
        let expected = (CompassAbilityConfig.cooldownStart + CompassAbilityConfig.cooldownEnd) / 2.0
        XCTAssertEqual(value, expected, accuracy: 0.001)
    }

    func testCooldownFallsBackForNonFiniteDuration() {
        let value = CompassAbilityConfig.cooldownDuration(
            elapsed: 60,
            totalDuration: .infinity
        )
        XCTAssertEqual(value, CompassAbilityConfig.fixedCooldownFallback, accuracy: 0.001)
    }

    func testCooldownFallsBackForZeroDuration() {
        let value = CompassAbilityConfig.cooldownDuration(elapsed: 30, totalDuration: 0)
        XCTAssertEqual(value, CompassAbilityConfig.fixedCooldownFallback, accuracy: 0.001)
    }

    // MARK: - firstUseDelay

    func testFirstUseDelayAtLeastBase() {
        let value = CompassAbilityConfig.firstUseDelay(elapsed: 0, totalDuration: 120)
        XCTAssertGreaterThanOrEqual(value, CompassAbilityConfig.baseFirstUseDelay)
    }

    func testFirstUseDelayCappedAtMax() {
        let value = CompassAbilityConfig.firstUseDelay(elapsed: 0, totalDuration: 10_000)
        XCTAssertLessThanOrEqual(value, CompassAbilityConfig.maxFirstUseDelay)
    }

    func testFirstUseDelayFallsBackForNonFiniteDuration() {
        let value = CompassAbilityConfig.firstUseDelay(elapsed: 0, totalDuration: .infinity)
        XCTAssertEqual(value, CompassAbilityConfig.baseFirstUseDelay, accuracy: 0.001)
    }

    // MARK: - Compass model identity

    func testCompassPulseEquatable() {
        let a = CompassPulse(
            eventId: "a",
            usedByPlayerId: "p1",
            targetPlayerId: "p2",
            distanceMeters: 12.3,
            usedAt: Date(timeIntervalSince1970: 1)
        )
        let b = CompassPulse(
            eventId: "a",
            usedByPlayerId: "p1",
            targetPlayerId: "p2",
            distanceMeters: 12.3,
            usedAt: Date(timeIntervalSince1970: 1)
        )
        let c = CompassPulse(
            eventId: "c",
            usedByPlayerId: "p1",
            targetPlayerId: "p2",
            distanceMeters: 12.3,
            usedAt: Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - screenRelativeBearing

    func testScreenRelativeBearingNilHeadingReturnsGeographic() {
        let g = 42.0
        XCTAssertEqual(
            CompassAbilityConfig.screenRelativeBearing(geographicBearingDegrees: g, headingDegreesFromNorth: nil),
            g,
            accuracy: 0.0001
        )
    }

    func testScreenRelativeBearingFacingNorthLeavesBearingUnchanged() {
        XCTAssertEqual(
            CompassAbilityConfig.screenRelativeBearing(geographicBearingDegrees: 90, headingDegreesFromNorth: 0),
            90,
            accuracy: 0.0001
        )
    }

    func testScreenRelativeBearingFacingEastShiftsWest() {
        // Top of phone = east (90°). Target at north (0°) appears toward left (-90° screen) = 270° CW from up.
        XCTAssertEqual(
            CompassAbilityConfig.screenRelativeBearing(geographicBearingDegrees: 0, headingDegreesFromNorth: 90),
            270,
            accuracy: 0.0001
        )
    }
}
#endif
