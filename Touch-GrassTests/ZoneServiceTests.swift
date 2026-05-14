//
//  ZoneServiceTests.swift
//  Touch-GrassTests
//

import XCTest
import CoreLocation
@testable import Touch_Grass

#if DEBUG
@MainActor
final class ZoneServiceTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000)
    private let center = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
    
    func testStandardScheduleUsesV1TimingAndAreaCurve() {
        let schedule = ZoneService.generateZoneSchedule(
            startCenter: center,
            startRadius: 500,
            duration: 1_800,
            timingAnchor: start,
            randomDouble: { range in range.lowerBound }
        )
        
        XCTAssertEqual(schedule.count, 9)
        XCTAssertEqual(schedule[0].areaPercent, 0.85, accuracy: 0.0001)
        XCTAssertEqual(schedule[0].revealOffset, 216, accuracy: 0.1)
        
        let transitionDuration = (1_800.0 - 216.0) / 9.0
        XCTAssertEqual(schedule[0].closingStartOffset - schedule[0].revealOffset, transitionDuration * 0.65, accuracy: 0.1)
        XCTAssertEqual(schedule[0].closingEndOffset - schedule[0].closingStartOffset, transitionDuration * 0.35, accuracy: 0.1)
        XCTAssertEqual(schedule[0].radiusMeters, 500 * sqrt(0.85), accuracy: 0.1)
    }
    
    func testSmallStartRadiusDisablesSchedule() {
        var bubble = Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: 80,
            startTime: start,
            shrinkInterval: 180,
            duration: 1_800
        )
        
        ZoneService.preparePrecomputedZoneSchedule(
            bubble: &bubble,
            gameType: .manhunt,
            generatedAt: start,
            randomDouble: { range in range.lowerBound }
        )
        
        XCTAssertTrue(bubble.usesNewZoneSystem)
        XCTAssertFalse(bubble.zoneScheduleEnabled)
        XCTAssertTrue(bubble.zoneSchedule.isEmpty)
        
        let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: start.addingTimeInterval(600))
        XCTAssertEqual(runtimeState.currentActiveZone.radiusMeters, 80, accuracy: 0.1)
        XCTAssertFalse(runtimeState.scheduleIsEnabled)
    }
    
    func testGeneratedScheduleIsContainedAndClampsFinalRadius() {
        let schedule = ZoneService.generateZoneSchedule(
            startCenter: center,
            startRadius: 500,
            duration: 900,
            timingAnchor: start,
            randomDouble: { range in range.upperBound }
        )
        
        XCTAssertFalse(schedule.isEmpty)
        XCTAssertTrue(ZoneService.isValidZoneSchedule(schedule, startCenter: center, startRadius: 500))
        XCTAssertTrue(schedule.allSatisfy { $0.radiusMeters >= ZoneService.minimumPlayableRadius })
        XCTAssertEqual(schedule.last!.radiusMeters, ZoneService.minimumPlayableRadius, accuracy: 0.1)
    }
    
    func testRuntimeStateOpeningRotationClosingAndComplete() {
        var bubble = Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: 500,
            startTime: start,
            shrinkInterval: 180,
            duration: 1_800
        )
        ZoneService.preparePrecomputedZoneSchedule(
            bubble: &bubble,
            gameType: .manhunt,
            generatedAt: start,
            randomDouble: { range in range.lowerBound }
        )
        
        guard let first = bubble.zoneSchedule.first else {
            XCTFail("Schedule should be generated")
            return
        }
        
        let opening = ZoneService.deriveRuntimeZoneState(for: bubble, now: first.revealTime.addingTimeInterval(-1))
        XCTAssertEqual(opening.phaseState, .openingGrace)
        XCTAssertNil(opening.nextPreviewZone)
        XCTAssertEqual(opening.currentActiveZone.radiusMeters, 500, accuracy: 0.1)
        
        let rotation = ZoneService.deriveRuntimeZoneState(for: bubble, now: first.revealTime.addingTimeInterval(1))
        XCTAssertEqual(rotation.phaseState, .rotation)
        XCTAssertNotNil(rotation.nextPreviewZone)
        XCTAssertEqual(rotation.currentActiveZone.radiusMeters, 500, accuracy: 0.1)
        
        let closingMidpoint = Date(
            timeInterval: first.closingEndTime.timeIntervalSince(first.closingStartTime) / 2,
            since: first.closingStartTime
        )
        let closing = ZoneService.deriveRuntimeZoneState(for: bubble, now: closingMidpoint)
        XCTAssertEqual(closing.phaseState, .closing)
        XCTAssertEqual(closing.currentActiveZone.radiusMeters, (500 + first.radiusMeters) / 2, accuracy: 0.1)
        
        let complete = ZoneService.deriveRuntimeZoneState(for: bubble, now: bubble.zoneSchedule.last!.closingEndTime.addingTimeInterval(1))
        XCTAssertEqual(complete.phaseState, .complete)
        XCTAssertEqual(complete.currentActiveZone.radiusMeters, bubble.zoneSchedule.last!.radiusMeters, accuracy: 0.1)
    }
    
    func testInvalidEnabledScheduleFallsBackToFullZone() {
        var bubble = Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: 500,
            startTime: start,
            shrinkInterval: 180,
            duration: 1_800
        )
        bubble.usesNewZoneSystem = true
        bubble.zoneScheduleEnabled = true
        bubble.zoneSchedule = []
        
        let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: start.addingTimeInterval(600))
        XCTAssertFalse(runtimeState.scheduleIsValid)
        XCTAssertEqual(runtimeState.currentActiveZone.radiusMeters, 500, accuracy: 0.1)
        XCTAssertNil(runtimeState.nextPreviewZone)
    }
    
    func testFairnessRerollsRepeatedHardPullAngle() {
        var angles: [Double] = [0, 0, 0, 0, 10, 20, 120, 180, 210, 240]
        let schedule = ZoneService.generateZoneSchedule(
            startCenter: center,
            startRadius: 500,
            duration: 1_800,
            timingAnchor: start,
            randomDouble: { range in
                if range.upperBound <= 1.0 {
                    return range.upperBound
                }
                return angles.isEmpty ? 300 : angles.removeFirst()
            }
        )
        
        XCTAssertGreaterThanOrEqual(schedule[4].pullStrength ?? 0, 0.55)
        XCTAssertGreaterThanOrEqual(schedule[5].pullStrength ?? 0, 0.55)
        XCTAssertEqual(schedule[5].pullAngle ?? -1, 120, accuracy: 0.001)
    }
    
    func testLargeRadiusTransitionCountHonorsMinimumRotationDuration() {
        let schedule = ZoneService.generateZoneSchedule(
            startCenter: center,
            startRadius: 1_000,
            duration: 900,
            timingAnchor: start,
            randomDouble: { range in range.lowerBound }
        )
        
        XCTAssertEqual(schedule.count, 5)
        for entry in schedule {
            XCTAssertGreaterThanOrEqual(entry.closingStartOffset - entry.revealOffset, 90)
        }
    }

    // MARK: - Late-Game Moving Zones

    func testMovingZoneThresholdMatchesFormula() {
        XCTAssertEqual(ZoneService.movingZoneThreshold(startRadius: 100), 100, accuracy: 0.001)
        XCTAssertEqual(ZoneService.movingZoneThreshold(startRadius: 300), 100, accuracy: 0.001)
        XCTAssertEqual(ZoneService.movingZoneThreshold(startRadius: 1_000), 200, accuracy: 0.001)
        XCTAssertEqual(ZoneService.movingZoneThreshold(startRadius: 2_500), 500, accuracy: 0.001)
    }

    func testLateGameSchedulesEnterMovingMode() {
        let startRadius: Double = 300
        let schedule = ZoneService.generateZoneSchedule(
            startCenter: center,
            startRadius: startRadius,
            duration: 1_800,
            timingAnchor: start,
            randomDouble: { range in range.lowerBound }
        )

        XCTAssertFalse(schedule.isEmpty)
        XCTAssertTrue(ZoneService.isValidZoneSchedule(schedule, startCenter: center, startRadius: startRadius))

        let containedCount = schedule.filter { $0.shrinkBehavior == .contained }.count
        let movingCount = schedule.filter { $0.shrinkBehavior == .moving }.count
        XCTAssertGreaterThan(containedCount, 0, "Early phases should be contained")
        XCTAssertGreaterThan(movingCount, 0, "Late phases should switch to moving")

        // Once a phase becomes moving, all subsequent phases should also be
        // moving — the active radius decreases monotonically, so the threshold
        // can only be crossed in one direction.
        var sawMoving = false
        for entry in schedule {
            if entry.shrinkBehavior == .moving {
                sawMoving = true
            } else {
                XCTAssertFalse(sawMoving, "Contained phase appeared after a moving phase")
            }
        }
    }

    func testMovingZoneUsesGentleShrinkAndStaysInsideHost() {
        let startRadius: Double = 300
        let schedule = ZoneService.generateZoneSchedule(
            startCenter: center,
            startRadius: startRadius,
            duration: 1_800,
            timingAnchor: start,
            randomDouble: { range in range.lowerBound }
        )

        let startLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)

        var previousRadius = startRadius
        var previousCenter = center

        for entry in schedule {
            defer {
                previousRadius = entry.radiusMeters
                previousCenter = entry.centerCoordinate
            }

            guard entry.shrinkBehavior == .moving else { continue }

            let expectedRadius = max(
                ZoneService.finalHoldRadius,
                previousRadius * ZoneService.movingZoneShrinkFactor
            )
            XCTAssertEqual(entry.radiusMeters, expectedRadius, accuracy: 0.1)

            let entryLocation = CLLocation(
                latitude: entry.centerLatitude,
                longitude: entry.centerLongitude
            )
            let distanceFromStart = entryLocation.distance(from: startLocation)
            XCTAssertLessThanOrEqual(
                distanceFromStart + entry.radiusMeters,
                startRadius + ZoneService.movingZoneHostBoundaryToleranceMeters + 1.0,
                "Moving zone must fit inside host-created boundary"
            )

            let previousLocation = CLLocation(
                latitude: previousCenter.latitude,
                longitude: previousCenter.longitude
            )
            let centerDistance = entryLocation.distance(from: previousLocation)
            XCTAssertLessThan(
                centerDistance,
                previousRadius + entry.radiusMeters,
                "Moving zone must overlap the previous zone"
            )
        }
    }

    func testMovingZoneCanBreakContainedRule() {
        let startRadius: Double = 300
        let schedule = ZoneService.generateZoneSchedule(
            startCenter: center,
            startRadius: startRadius,
            duration: 1_800,
            timingAnchor: start,
            randomDouble: { range in range.lowerBound }
        )

        var previousRadius = startRadius
        var previousCenter = center
        var sawBrokenContainment = false

        for entry in schedule {
            let entryLocation = CLLocation(
                latitude: entry.centerLatitude,
                longitude: entry.centerLongitude
            )
            let previousLocation = CLLocation(
                latitude: previousCenter.latitude,
                longitude: previousCenter.longitude
            )
            let centerDistance = entryLocation.distance(from: previousLocation)
            let containedLimit = max(0, previousRadius - entry.radiusMeters)

            if entry.shrinkBehavior == .moving, centerDistance > containedLimit + 1.0 {
                sawBrokenContainment = true
            }

            previousRadius = entry.radiusMeters
            previousCenter = entry.centerCoordinate
        }

        XCTAssertTrue(
            sawBrokenContainment,
            "At least one moving zone should sit partially outside the previous safe area"
        )
    }

    func testValidatorAcceptsValidMovingSchedule() {
        // 50m north of the host center, inside a 100m host radius.
        let movingCenter = CLLocationCoordinate2D(
            latitude: center.latitude + (50.0 / 111_111.0),
            longitude: center.longitude
        )
        let entry = ZoneScheduleEntry(
            phaseIndex: 1,
            areaPercent: 0.16,
            center: movingCenter,
            radiusMeters: 40,
            pullAngle: 0,
            pullStrength: 0.7,
            revealOffset: 60,
            closingStartOffset: 90,
            closingEndOffset: 120,
            timingAnchor: start,
            shrinkBehavior: .moving
        )

        XCTAssertTrue(
            ZoneService.isValidZoneSchedule([entry], startCenter: center, startRadius: 100)
        )
    }

    func testValidatorRejectsMovingZoneOutsideHost() {
        // 80m north of host center, radius 40m → 80 + 40 = 120m > 100m host.
        let outsideCenter = CLLocationCoordinate2D(
            latitude: center.latitude + (80.0 / 111_111.0),
            longitude: center.longitude
        )
        let entry = ZoneScheduleEntry(
            phaseIndex: 1,
            areaPercent: 0.16,
            center: outsideCenter,
            radiusMeters: 40,
            pullAngle: 0,
            pullStrength: 0.7,
            revealOffset: 60,
            closingStartOffset: 90,
            closingEndOffset: 120,
            timingAnchor: start,
            shrinkBehavior: .moving
        )

        XCTAssertFalse(
            ZoneService.isValidZoneSchedule([entry], startCenter: center, startRadius: 100)
        )
    }

    func testValidatorRejectsDisjointMovingZone() {
        // Contained phase 1 sits 20m north of the host center with radius 30m.
        let center1 = CLLocationCoordinate2D(
            latitude: center.latitude + (20.0 / 111_111.0),
            longitude: center.longitude
        )
        let entry1 = ZoneScheduleEntry(
            phaseIndex: 1,
            areaPercent: 0.4,
            center: center1,
            radiusMeters: 30,
            pullAngle: 0,
            pullStrength: 0.3,
            revealOffset: 60,
            closingStartOffset: 90,
            closingEndOffset: 120,
            timingAnchor: start,
            shrinkBehavior: .contained
        )

        // Phase 2 sits 60m south of the host center → 80m from phase 1 center.
        // That exceeds R1 + R2 = 55m so the circles are disjoint, but the zone
        // still fits inside the 100m host boundary so the failure must come
        // from the moving-mode overlap check rather than host containment.
        let center2 = CLLocationCoordinate2D(
            latitude: center.latitude - (60.0 / 111_111.0),
            longitude: center.longitude
        )
        let entry2 = ZoneScheduleEntry(
            phaseIndex: 2,
            areaPercent: 0.16,
            center: center2,
            radiusMeters: 25,
            pullAngle: 180,
            pullStrength: 0.7,
            revealOffset: 130,
            closingStartOffset: 160,
            closingEndOffset: 200,
            timingAnchor: start,
            shrinkBehavior: .moving
        )

        XCTAssertFalse(
            ZoneService.isValidZoneSchedule([entry1, entry2], startCenter: center, startRadius: 100)
        )
    }
}
#endif
