//
//  ZoneService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/31/25.
//

import Foundation
import CoreLocation

@MainActor
final class ZoneService {
    private static func print(_ message: String) {
        if message.hasPrefix("❌") {
            Swift.print(message)
        } else {
            DebugLogger.log(message)
        }
    }
    
    static let minimumShrinkingStartRadius: Double = 100.0
    static let minimumPlayableRadius: Double = 25.0
    static let finalHoldRadius: Double = minimumPlayableRadius
    static let enforcementToleranceMeters: Double = 10.0

    // MARK: - Moving Zone Tuning
    /// Minimum radius (meters) at which moving-zone behavior can begin.
    static let movingZoneMinThreshold: Double = 100.0
    /// Fraction of the starting radius at which moving-zone behavior begins.
    /// Effective threshold = max(movingZoneMinThreshold, startRadius * movingZoneRadiusFraction).
    static let movingZoneRadiusFraction: Double = 0.20
    /// Per-phase shrink factor once moving-zone behavior is active.
    /// Pressure should come from movement, not aggressive radius collapse.
    static let movingZoneShrinkFactor: Double = 0.90
    /// Offset range (as a multiple of previous radius) used to position the
    /// next moving zone. Produces partial overlap with the previous zone.
    static let movingZoneOffsetRange: ClosedRange<Double> = 0.55...0.85
    /// Slack (meters) when checking that a moving zone still fits in the
    /// original host-created boundary.
    static let movingZoneHostBoundaryToleranceMeters: Double = 0.5

    /// Returns the radius at which contained shrink behavior gives way to
    /// moving-zone behavior for a schedule with the given starting radius.
    static func movingZoneThreshold(startRadius: Double) -> Double {
        max(movingZoneMinThreshold, startRadius * movingZoneRadiusFraction)
    }
    
    enum ZoneCurveKind: String {
        case blitz
        case standard
        case extended
        case marathon
    }
    
    // MARK: - Precomputed Zone Schedule
    
    static func preparePrecomputedZoneSchedule(
        bubble: inout Bubble,
        gameType: GameType,
        generatedAt: Date = Date(),
        randomDouble: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) {
        bubble.usesNewZoneSystem = gameType != .captureTheFlag
        bubble.boundaryCenterLatitude = bubble.centerLatitude
        bubble.boundaryCenterLongitude = bubble.centerLongitude
        bubble.boundaryRadius = bubble.startRadius
        bubble.safeAreaCenter = nil
        bubble.safeAreaRadius = nil
        bubble.nextSafeAreaCenter = nil
        bubble.nextSafeAreaRadius = nil
        bubble.warningStartTime = nil
        bubble.closingStartTime = nil
        bubble.closingDuration = nil
        bubble.isClosing = false
        bubble.isContinuousMode = false
        bubble.closingSpeed = 0
        
        guard gameType != .captureTheFlag else {
            bubble.zoneSchedule = []
            bubble.zoneScheduleGeneratedAt = nil
            bubble.zoneScheduleEnabled = false
            return
        }
        
        guard bubble.enableShrinking else {
            bubble.zoneSchedule = []
            bubble.zoneScheduleGeneratedAt = nil
            bubble.zoneScheduleEnabled = false
            return
        }
        
        guard bubble.startRadius >= minimumShrinkingStartRadius else {
            bubble.zoneSchedule = []
            bubble.zoneScheduleGeneratedAt = nil
            bubble.zoneScheduleEnabled = false
            print("ℹ️ Zone schedule disabled: start radius below \(Int(minimumShrinkingStartRadius))m")
            return
        }
        
        let schedule = generateZoneSchedule(
            startCenter: bubble.boundaryCenter,
            startRadius: bubble.startRadius,
            duration: bubble.duration,
            timingAnchor: bubble.startTime,
            randomDouble: randomDouble
        )
        
        guard !schedule.isEmpty,
              isValidZoneSchedule(schedule, startCenter: bubble.boundaryCenter, startRadius: bubble.startRadius) else {
            bubble.zoneSchedule = []
            bubble.zoneScheduleGeneratedAt = nil
            bubble.zoneScheduleEnabled = false
            print("❌ Zone schedule generation failed; fixed full-zone fallback remains active")
            return
        }
        
        bubble.zoneSchedule = schedule
        bubble.zoneScheduleGeneratedAt = generatedAt
        bubble.zoneScheduleEnabled = true
        
        let runtimeState = deriveRuntimeZoneState(for: bubble, now: bubble.startTime)
        applyRuntimeState(runtimeState, to: &bubble)
    }
    
    static func generateZoneSchedule(
        startCenter: CLLocationCoordinate2D,
        startRadius: Double,
        duration: TimeInterval,
        timingAnchor: Date,
        randomDouble: (ClosedRange<Double>) -> Double = { Double.random(in: $0) }
    ) -> [ZoneScheduleEntry] {
        guard startRadius.isFinite,
              startRadius >= minimumShrinkingStartRadius,
              duration.isFinite,
              duration > 0 else {
            return []
        }
        
        let curveKind = zoneCurveKind(for: duration)
        var areaCurve = areaCurve(for: curveKind)
        var activeTransitions = activeTransitionCount(
            duration: duration,
            startRadius: startRadius,
            curveTransitionCount: areaCurve.count - 1
        )
        
        if startRadius < 250 {
            activeTransitions = min(activeTransitions, 4)
        }
        
        guard activeTransitions > 0 else { return [] }
        areaCurve = Array(areaCurve.prefix(activeTransitions + 1))
        
        let openingGrace = openingGraceDuration(for: duration)
        let remainingDuration = duration - openingGrace
        guard remainingDuration > 0 else { return [] }
        
        let transitionDuration = remainingDuration / Double(activeTransitions)
        let rotationDuration = transitionDuration * 0.65
        
        var entries: [ZoneScheduleEntry] = []
        var previousZone = ZoneCircle(center: startCenter, radiusMeters: startRadius)
        var previousPullAngle: Double?
        var previousPullStrength: Double?
        let movingZoneThreshold = movingZoneThreshold(startRadius: startRadius)
        
        for transitionIndex in 1...activeTransitions {
            let isMovingZone = previousZone.radiusMeters <= movingZoneThreshold
            let radius: Double
            let areaPercent: Double
            let pullRange: ClosedRange<Double>
            let shrinkBehavior: ZoneShrinkBehavior
            
            if isMovingZone {
                radius = max(finalHoldRadius, previousZone.radiusMeters * 0.90)
                areaPercent = min(max(pow(radius / startRadius, 2), 0), 1)
                pullRange = 0.55...0.85
                shrinkBehavior = .moving
            } else {
                areaPercent = areaCurve[transitionIndex]
                radius = radiusMeters(
                    forAreaPercent: areaPercent,
                    startRadius: startRadius
                )
                pullRange = pullStrengthRange(
                    forPhaseIndex: transitionIndex,
                    curveKind: curveKind,
                    totalTransitions: activeTransitions
                )
                shrinkBehavior = .contained
            }
            
            let pullStrength = randomDouble(pullRange)
            var pullAngle = normalizedDegrees(randomDouble(0.0...360.0))
            
            if let previousPullAngle,
               let previousPullStrength,
               previousPullStrength >= 0.55,
               pullStrength >= 0.55 {
                var attempts = 0
                while angularDistanceDegrees(pullAngle, previousPullAngle) <= 45.0 && attempts < 5 {
                    pullAngle = normalizedDegrees(randomDouble(0.0...360.0))
                    attempts += 1
                }
            }
            
            let offsetDistance: Double
            let center: CLLocationCoordinate2D
            if isMovingZone {
                let desiredOffset = previousZone.radiusMeters * pullStrength
                offsetDistance = hostBoundedOffsetDistance(
                    from: previousZone.centerCoordinate,
                    desiredOffset: desiredOffset,
                    bearingDegrees: pullAngle,
                    nextRadius: radius,
                    startCenter: startCenter,
                    startRadius: startRadius
                )
                center = coordinate(
                    from: previousZone.centerCoordinate,
                    distanceMeters: offsetDistance,
                    bearingDegrees: pullAngle
                )
            } else {
                let maxOffset = max(0, previousZone.radiusMeters - radius)
                offsetDistance = maxOffset * pullStrength
                center = coordinate(
                    from: previousZone.centerCoordinate,
                    distanceMeters: offsetDistance,
                    bearingDegrees: pullAngle
                )
            }
            
            let revealOffset = openingGrace + (Double(transitionIndex - 1) * transitionDuration)
            let closingStartOffset = revealOffset + rotationDuration
            let closingEndOffset = revealOffset + transitionDuration
            
            let entry = ZoneScheduleEntry(
                phaseIndex: transitionIndex,
                areaPercent: areaPercent,
                center: center,
                radiusMeters: radius,
                pullAngle: pullAngle,
                pullStrength: pullStrength,
                revealOffset: revealOffset,
                closingStartOffset: closingStartOffset,
                closingEndOffset: closingEndOffset,
                timingAnchor: timingAnchor,
                shrinkBehavior: shrinkBehavior
            )
            
            entries.append(entry)
            previousZone = entry.zoneCircle
            previousPullAngle = pullAngle
            previousPullStrength = pullStrength
        }
        
        return entries
    }
    
    static func deriveRuntimeZoneState(
        for bubble: Bubble,
        now: Date = Date()
    ) -> RuntimeZoneState {
        let hostCenter = CLLocationCoordinate2D(
            latitude: bubble.centerLatitude,
            longitude: bubble.centerLongitude
        )
        let hostZone = ZoneCircle(center: hostCenter, radiusMeters: bubble.startRadius)
        
        guard bubble.enableShrinking,
              bubble.zoneScheduleEnabled else {
            return RuntimeZoneState(
                currentActiveZone: hostZone,
                nextPreviewZone: nil,
                phaseState: .complete,
                timeRemainingInPhase: nil,
                scheduleIsValid: true,
                scheduleIsEnabled: false,
                enforcementToleranceMeters: enforcementToleranceMeters
            )
        }
        
        let schedule = bubble.zoneSchedule
        guard isValidZoneSchedule(
            schedule,
            startCenter: hostCenter,
            startRadius: bubble.startRadius
        ) else {
            print("❌ Invalid zone schedule detected; full-zone fallback is active")
            return RuntimeZoneState(
                currentActiveZone: hostZone,
                nextPreviewZone: nil,
                phaseState: .complete,
                timeRemainingInPhase: nil,
                scheduleIsValid: false,
                scheduleIsEnabled: true,
                enforcementToleranceMeters: enforcementToleranceMeters
            )
        }
        
        if let firstEntry = schedule.first, now < firstEntry.revealTime {
            return RuntimeZoneState(
                currentActiveZone: hostZone,
                nextPreviewZone: nil,
                phaseState: .openingGrace,
                timeRemainingInPhase: firstEntry.revealTime.timeIntervalSince(now),
                scheduleIsValid: true,
                scheduleIsEnabled: true,
                enforcementToleranceMeters: enforcementToleranceMeters
            )
        }
        
        for index in schedule.indices {
            let entry = schedule[index]
            let previousZone = index == schedule.startIndex ? hostZone : schedule[schedule.index(before: index)].zoneCircle
            
            if now < entry.revealTime {
                return RuntimeZoneState(
                    currentActiveZone: previousZone,
                    nextPreviewZone: nil,
                    phaseState: .complete,
                    timeRemainingInPhase: entry.revealTime.timeIntervalSince(now),
                    scheduleIsValid: true,
                    scheduleIsEnabled: true,
                    enforcementToleranceMeters: enforcementToleranceMeters
                )
            }
            
            if now < entry.closingStartTime {
                return RuntimeZoneState(
                    currentActiveZone: previousZone,
                    nextPreviewZone: entry.zoneCircle,
                    phaseState: .rotation,
                    timeRemainingInPhase: entry.closingStartTime.timeIntervalSince(now),
                    scheduleIsValid: true,
                    scheduleIsEnabled: true,
                    enforcementToleranceMeters: enforcementToleranceMeters
                )
            }
            
            if now < entry.closingEndTime {
                let activeZone = interpolateZone(
                    from: previousZone,
                    to: entry.zoneCircle,
                    startTime: entry.closingStartTime,
                    endTime: entry.closingEndTime,
                    now: now
                )
                return RuntimeZoneState(
                    currentActiveZone: activeZone,
                    nextPreviewZone: entry.zoneCircle,
                    phaseState: .closing,
                    timeRemainingInPhase: entry.closingEndTime.timeIntervalSince(now),
                    scheduleIsValid: true,
                    scheduleIsEnabled: true,
                    enforcementToleranceMeters: enforcementToleranceMeters
                )
            }
        }
        
        let finalZone = schedule.last?.zoneCircle ?? hostZone
        return RuntimeZoneState(
            currentActiveZone: finalZone,
            nextPreviewZone: nil,
            phaseState: .complete,
            timeRemainingInPhase: nil,
            scheduleIsValid: true,
            scheduleIsEnabled: true,
            enforcementToleranceMeters: enforcementToleranceMeters
        )
    }
    
    static func applyRuntimeState(_ state: RuntimeZoneState, to bubble: inout Bubble) {
        bubble.boundaryCenter = state.currentActiveZone.centerCoordinate
        bubble.boundaryRadius = state.currentActiveZone.radiusMeters
        bubble.isClosing = state.phaseState == .closing
        bubble.isContinuousMode = false
        
        switch state.phaseState {
        case .openingGrace, .complete:
            bubble.nextSafeAreaCenter = nil
            bubble.nextSafeAreaRadius = nil
            bubble.safeAreaCenter = state.currentActiveZone.centerCoordinate
            bubble.safeAreaRadius = state.currentActiveZone.radiusMeters
            bubble.warningStartTime = nil
            bubble.closingStartTime = nil
            bubble.closingDuration = nil
        case .rotation:
            bubble.safeAreaCenter = state.currentActiveZone.centerCoordinate
            bubble.safeAreaRadius = state.currentActiveZone.radiusMeters
            bubble.nextSafeAreaCenter = state.nextPreviewZone?.centerCoordinate
            bubble.nextSafeAreaRadius = state.nextPreviewZone?.radiusMeters
            if bubble.warningStartTime == nil {
                bubble.warningStartTime = Date()
            }
            bubble.closingStartTime = nil
            bubble.closingDuration = nil
        case .closing:
            bubble.safeAreaCenter = state.nextPreviewZone?.centerCoordinate
            bubble.safeAreaRadius = state.nextPreviewZone?.radiusMeters
            bubble.nextSafeAreaCenter = state.nextPreviewZone?.centerCoordinate
            bubble.nextSafeAreaRadius = state.nextPreviewZone?.radiusMeters
            bubble.warningStartTime = nil
            if bubble.closingStartTime == nil {
                bubble.closingStartTime = Date()
            }
            bubble.closingDuration = state.timeRemainingInPhase
        }
    }
    
    static func isValidZoneSchedule(
        _ schedule: [ZoneScheduleEntry],
        startCenter: CLLocationCoordinate2D,
        startRadius: Double
    ) -> Bool {
        guard !schedule.isEmpty,
              startRadius.isFinite,
              startRadius > 0 else {
            return false
        }
        
        var previousZone = ZoneCircle(center: startCenter, radiusMeters: startRadius)
        var previousClosingEndOffset: TimeInterval?
        
        for (index, entry) in schedule.enumerated() {
            guard entry.phaseIndex == index + 1,
                  entry.areaPercent >= 0,
                  entry.areaPercent <= 1,
                  entry.radiusMeters.isFinite,
                  entry.radiusMeters >= minimumPlayableRadius,
                  entry.revealOffset.isFinite,
                  entry.closingStartOffset.isFinite,
                  entry.closingEndOffset.isFinite,
                  entry.revealOffset <= entry.closingStartOffset,
                  entry.closingStartOffset < entry.closingEndOffset,
                  entry.revealTime <= entry.closingStartTime,
                  entry.closingStartTime < entry.closingEndTime else {
                return false
            }
            
            if let previousClosingEndOffset,
               entry.revealOffset < previousClosingEndOffset - 0.001 {
                return false
            }
            
            let entryCenter = CLLocation(latitude: entry.centerLatitude, longitude: entry.centerLongitude)
            let previousCenter = CLLocation(
                latitude: previousZone.centerLatitude,
                longitude: previousZone.centerLongitude
            )
            let centerDistance = entryCenter.distance(from: previousCenter)

            switch entry.shrinkBehavior {
            case .contained:
                let maxAllowedOffset = max(0, previousZone.radiusMeters - entry.radiusMeters)
                guard centerDistance <= maxAllowedOffset + 1.0 else {
                    return false
                }
            case .moving:
                // Moving zones must still overlap the previous zone (not disjoint)
                // and the entire next circle must fit inside the original host
                // boundary so play never leaves the host-created area.
                guard centerDistance < previousZone.radiusMeters + entry.radiusMeters - 1.0 else {
                    return false
                }
                let startCenterLoc = CLLocation(
                    latitude: startCenter.latitude,
                    longitude: startCenter.longitude
                )
                let distanceFromStart = entryCenter.distance(from: startCenterLoc)
                guard distanceFromStart + entry.radiusMeters
                        <= startRadius + movingZoneHostBoundaryToleranceMeters + 1.0 else {
                    return false
                }
            }
            
            previousZone = entry.zoneCircle
            previousClosingEndOffset = entry.closingEndOffset
        }
        
        return true
    }
    
    static func zoneCurveKind(for duration: TimeInterval) -> ZoneCurveKind {
        let minutes = duration / 60.0
        if minutes <= 20 {
            return .blitz
        } else if minutes <= 45 {
            return .standard
        } else if minutes <= 90 {
            return .extended
        } else {
            return .marathon
        }
    }
    
    static func areaCurve(for kind: ZoneCurveKind) -> [Double] {
        switch kind {
        case .blitz:
            return [1.00, 0.80, 0.55, 0.32, 0.15, 0.05, 0.00]
        case .standard:
            return [1.00, 0.85, 0.70, 0.52, 0.36, 0.22, 0.12, 0.06, 0.02, 0.00]
        case .extended:
            return [1.00, 0.88, 0.72, 0.54, 0.38, 0.24, 0.14, 0.07, 0.03, 0.00]
        case .marathon:
            return [1.00, 0.90, 0.78, 0.62, 0.44, 0.28, 0.16, 0.08, 0.03, 0.00]
        }
    }
    
    static func openingGraceDuration(for duration: TimeInterval) -> TimeInterval {
        min(max(duration * 0.12, 90.0), 600.0)
    }
    
    static func radiusMeters(forAreaPercent areaPercent: Double, startRadius: Double) -> Double {
        guard areaPercent > 0 else {
            return minimumPlayableRadius
        }
        return max(startRadius * sqrt(areaPercent), minimumPlayableRadius)
    }
    
    static func activeTransitionCount(
        duration: TimeInterval,
        startRadius: Double,
        curveTransitionCount: Int
    ) -> Int {
        let openingGrace = openingGraceDuration(for: duration)
        let remainingDuration = duration - openingGrace
        guard remainingDuration >= 62 else { return 0 }
        
        var activeTransitions = min(curveTransitionCount, Int(floor(remainingDuration / 62.0)))
        if startRadius >= 750 {
            while activeTransitions > 0 {
                let transitionDuration = remainingDuration / Double(activeTransitions)
                if transitionDuration * 0.65 >= 90.0 {
                    break
                }
                activeTransitions -= 1
            }
        }
        
        return activeTransitions
    }
    
    static func interpolateZone(
        from startZone: ZoneCircle,
        to endZone: ZoneCircle,
        startTime: Date,
        endTime: Date,
        now: Date
    ) -> ZoneCircle {
        let duration = endTime.timeIntervalSince(startTime)
        guard duration > 0 else { return endZone }
        
        let progress = min(max(now.timeIntervalSince(startTime) / duration, 0), 1)
        let latitude = startZone.centerLatitude + (endZone.centerLatitude - startZone.centerLatitude) * progress
        let longitude = startZone.centerLongitude + (endZone.centerLongitude - startZone.centerLongitude) * progress
        let radius = startZone.radiusMeters + (endZone.radiusMeters - startZone.radiusMeters) * progress
        return ZoneCircle(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            radiusMeters: max(radius, minimumPlayableRadius)
        )
    }
    
    private static func pullStrengthRange(
        forPhaseIndex phaseIndex: Int,
        curveKind: ZoneCurveKind,
        totalTransitions: Int
    ) -> ClosedRange<Double> {
        if curveKind == .blitz {
            switch phaseIndex {
            case 1: return 0.05...0.15
            case 2: return 0.20...0.35
            case 3: return 0.35...0.55
            case 4: return 0.50...0.70
            default: return 0.60...0.80
            }
        }
        
        switch phaseIndex {
        case 1: return 0.05...0.15
        case 2: return 0.10...0.25
        case 3: return 0.20...0.35
        case 4: return 0.30...0.50
        case 5: return 0.45...0.65
        case 6: return 0.55...0.75
        case 7: return 0.65...0.85
        default:
            return totalTransitions <= 6 ? 0.45...0.70 : 0.45...0.70
        }
    }
    
    private static func coordinate(
        from coordinate: CLLocationCoordinate2D,
        distanceMeters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        guard distanceMeters > 0 else { return coordinate }
        
        let earthRadius = 6_371_000.0
        let bearing = bearingDegrees * .pi / 180.0
        let lat1 = coordinate.latitude * .pi / 180.0
        let lon1 = coordinate.longitude * .pi / 180.0
        let angularDistance = distanceMeters / earthRadius
        
        let lat2 = asin(
            sin(lat1) * cos(angularDistance) +
            cos(lat1) * sin(angularDistance) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180.0 / .pi,
            longitude: lon2 * 180.0 / .pi
        )
    }
    
    private static func angularDistanceDegrees(_ lhs: Double, _ rhs: Double) -> Double {
        let difference = abs(normalizedDegrees(lhs) - normalizedDegrees(rhs))
        return min(difference, 360.0 - difference)
    }
    
    private static func normalizedDegrees(_ value: Double) -> Double {
        let normalized = value.truncatingRemainder(dividingBy: 360.0)
        return normalized >= 0 ? normalized : normalized + 360.0
    }

    /// Distance in meters between two geographic coordinates.
    private static func metersBetween(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D
    ) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Returns an offset distance (meters) along `bearingDegrees` from
    /// `previousCenter` such that the resulting circle of radius `nextRadius`
    /// still fits inside the host-created boundary `(startCenter, startRadius)`.
    ///
    /// The desired offset is tried first, then shrunk geometrically until the
    /// candidate satisfies host containment. As a worst case the offset
    /// collapses to zero, which places the next zone on top of the previous
    /// center (the previous center is guaranteed to be inside the host
    /// boundary by induction over the schedule).
    private static func hostBoundedOffsetDistance(
        from previousCenter: CLLocationCoordinate2D,
        desiredOffset: Double,
        bearingDegrees: Double,
        nextRadius: Double,
        startCenter: CLLocationCoordinate2D,
        startRadius: Double
    ) -> Double {
        let tolerance = movingZoneHostBoundaryToleranceMeters
        var offset = max(0, desiredOffset)

        for _ in 0..<8 {
            let candidate = coordinate(
                from: previousCenter,
                distanceMeters: offset,
                bearingDegrees: bearingDegrees
            )
            let distanceFromStart = metersBetween(startCenter, candidate)
            if distanceFromStart + nextRadius <= startRadius + tolerance {
                return offset
            }
            if offset <= 1.0 {
                break
            }
            offset *= 0.6
        }

        return 0
    }
    
    // MARK: - Safe Area Calculation
    
    /// Selects the initial safe area for the first phase
    /// - Parameters:
    ///   - mapCenter: The center of the initial playable area
    ///   - mapRadius: The radius of the initial playable area
    ///   - playerLocations: Current player locations (optional, for intelligent placement)
    /// - Returns: The center and radius of the initial safe area
    static func selectInitialSafeArea(
        mapCenter: CLLocationCoordinate2D,
        mapRadius: Double,
        playerLocations: [CLLocationCoordinate2D] = []
    ) -> (center: CLLocationCoordinate2D, radius: Double) {
        // Validate input parameters
        guard mapRadius > 0 && mapRadius.isFinite else {
            print("⚠️ Invalid mapRadius (\(mapRadius)) in selectInitialSafeArea - using default")
            return (center: mapCenter, radius: 100.0) // Default fallback
        }
        
        // Initial safe area covers 85% of the map
        let safeAreaRadius = mapRadius * 0.85
        
        // Calculate offset direction (prefer area with fewer players, but add some randomness)
        let offsetDirection: Double
        let offsetDistance: Double
        
        if !playerLocations.isEmpty {
            // Calculate center of player mass
            let avgLat = playerLocations.map { $0.latitude }.reduce(0, +) / Double(playerLocations.count)
            let avgLon = playerLocations.map { $0.longitude }.reduce(0, +) / Double(playerLocations.count)
            let playerCenter = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            
            // Offset away from player center by 20-30% of radius
            let bearing = bearingBetween(mapCenter, and: playerCenter)
            
            // Offset in opposite direction from player center
            offsetDirection = (bearing + 180.0).truncatingRemainder(dividingBy: 360.0)
            offsetDistance = mapRadius * Double.random(in: 0.20...0.30)
        } else {
            // No players yet, use random direction
            offsetDirection = Double.random(in: 0...360)
            offsetDistance = mapRadius * Double.random(in: 0.20...0.30)
        }
        
        // Convert offset to lat/lon (approximate: 1 degree ≈ 111,000 meters)
        let offsetMeters = offsetDistance
        let offsetLat = offsetMeters * cos(offsetDirection * .pi / 180.0) / 111000.0
        let offsetLon = offsetMeters * sin(offsetDirection * .pi / 180.0) / (111000.0 * cos(mapCenter.latitude * .pi / 180.0))
        
        let safeAreaCenter = CLLocationCoordinate2D(
            latitude: mapCenter.latitude + offsetLat,
            longitude: mapCenter.longitude + offsetLon
        )
        
        // Validate: Ensure safe area is contained within map
        let safeAreaLoc = CLLocation(latitude: safeAreaCenter.latitude, longitude: safeAreaCenter.longitude)
        let mapCenterLoc = CLLocation(latitude: mapCenter.latitude, longitude: mapCenter.longitude)
        let distanceFromMapCenter = safeAreaLoc.distance(from: mapCenterLoc)
        
        let maxAllowedDistance = mapRadius - safeAreaRadius
        if distanceFromMapCenter > maxAllowedDistance {
            // Clamp safe area center to stay within map
            // Guard against division by zero
            guard distanceFromMapCenter > 0 else {
                // If distance is zero, return map center
                return (center: mapCenter, radius: safeAreaRadius)
            }
            let ratio = maxAllowedDistance / distanceFromMapCenter
            let clampedLat = mapCenter.latitude + (safeAreaCenter.latitude - mapCenter.latitude) * ratio
            let clampedLon = mapCenter.longitude + (safeAreaCenter.longitude - mapCenter.longitude) * ratio
            let clampedCenter = CLLocationCoordinate2D(latitude: clampedLat, longitude: clampedLon)
            
            // Validate clamped coordinates
            guard clampedCenter.latitude.isFinite && clampedCenter.longitude.isFinite else {
                print("⚠️ Invalid clamped coordinates in selectInitialSafeArea - using map center")
                return (center: mapCenter, radius: safeAreaRadius)
            }
            
            return (
                center: clampedCenter,
                radius: safeAreaRadius
            )
        }
        
        // Validate safe area center coordinates
        guard safeAreaCenter.latitude.isFinite && safeAreaCenter.longitude.isFinite else {
            print("⚠️ Invalid safeAreaCenter coordinates in selectInitialSafeArea - using map center")
            return (center: mapCenter, radius: safeAreaRadius)
        }
        
        return (center: safeAreaCenter, radius: safeAreaRadius)
    }
    
    /// Calculates the next safe area based on the previous one
    /// - Parameters:
    ///   - previousSafeArea: The previous safe area center and radius
    ///   - phaseNumber: Current phase number (for escalation)
    ///   - totalPhases: Estimated total phases (for scaling)
    ///   - playerLocations: Current player locations (optional, for intelligent placement)
    /// - Returns: The center and radius of the next safe area
    static func calculateNextSafeArea(
        previousSafeArea: (center: CLLocationCoordinate2D, radius: Double),
        phaseNumber: Int,
        totalPhases: Int = 10,
        playerLocations: [CLLocationCoordinate2D] = []
    ) -> (center: CLLocationCoordinate2D, radius: Double) {
        // Calculate shrink factor (escalates over phases)
        let shrinkFactor: Double
        if phaseNumber <= 1 {
            shrinkFactor = 0.75 // 75% of previous
        } else if phaseNumber <= 3 {
            shrinkFactor = 0.70 // 70% of previous
        } else if phaseNumber <= 5 {
            shrinkFactor = 0.60 // 60% of previous
        } else if phaseNumber <= 7 {
            shrinkFactor = 0.50 // 50% of previous
        } else {
            shrinkFactor = 0.40 // 40% of previous (late game)
        }
        
        // Validate input radius
        guard previousSafeArea.radius > 0 && previousSafeArea.radius.isFinite else {
            print("⚠️ Invalid previousSafeArea.radius (\(previousSafeArea.radius)) in calculateNextSafeArea - using minimum radius")
            return (center: previousSafeArea.center, radius: 1.0) // Minimum radius
        }
        
        let newRadius = previousSafeArea.radius * shrinkFactor
        guard newRadius > 0 else {
            return (center: previousSafeArea.center, radius: 1.0) // Minimum radius
        }
        
        // Calculate offset (decreases over time for late game)
        let offsetPercentage: Double
        if phaseNumber <= 2 {
            offsetPercentage = Double.random(in: 0.30...0.40) // 30-40% of previous radius
        } else if phaseNumber <= 5 {
            offsetPercentage = Double.random(in: 0.20...0.30) // 20-30% of previous radius
        } else {
            offsetPercentage = Double.random(in: 0.10...0.20) // 10-20% of previous radius (late game)
        }
        
        let maxOffsetDistance = previousSafeArea.radius * offsetPercentage
        
        // Determine offset direction
        let offsetDirection: Double
        if !playerLocations.isEmpty && phaseNumber > 2 {
            // In later phases, try to create movement incentives
            // Weight toward areas with fewer players, but not perfectly
            let previousCenterLoc = CLLocation(latitude: previousSafeArea.center.latitude, longitude: previousSafeArea.center.longitude)
            
            // Find direction with fewer players
            var directionWeights: [Double: Int] = [:]
            for direction in stride(from: 0, to: 360, by: 45) {
                let playersInDirection = playerLocations.filter { loc in
                    let playerLoc = CLLocation(latitude: loc.latitude, longitude: loc.longitude)
                    let bearing = bearingBetween(previousSafeArea.center, and: loc)
                    let bearingDiff = abs(bearing - Double(direction))
                    let minBearingDiff = min(bearingDiff, 360 - bearingDiff)
                    return minBearingDiff < 45 && playerLoc.distance(from: previousCenterLoc) < previousSafeArea.radius
                }.count
                directionWeights[Double(direction)] = playersInDirection
            }
            
            // Select direction with fewer players, with some randomness
            let sortedDirections = directionWeights.sorted { $0.value < $1.value }
            let candidateDirections = Array(sortedDirections.prefix(3)) // Top 3 directions with fewest players
            if !candidateDirections.isEmpty {
                offsetDirection = candidateDirections.randomElement()!.key + Double.random(in: -20...20)
            } else {
                offsetDirection = Double.random(in: 0...360)
            }
        } else {
            // Early phases: more random
            offsetDirection = Double.random(in: 0...360)
        }
        
        // Convert offset to lat/lon
        let offsetLat = maxOffsetDistance * cos(offsetDirection * .pi / 180.0) / 111000.0
        let offsetLon = maxOffsetDistance * sin(offsetDirection * .pi / 180.0) / (111000.0 * cos(previousSafeArea.center.latitude * .pi / 180.0))
        
        var newCenter = CLLocationCoordinate2D(
            latitude: previousSafeArea.center.latitude + offsetLat,
            longitude: previousSafeArea.center.longitude + offsetLon
        )
        
        // CRITICAL: Ensure new safe area is contained within previous safe area
        let previousCenterLoc = CLLocation(latitude: previousSafeArea.center.latitude, longitude: previousSafeArea.center.longitude)
        let newCenterLoc = CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude)
        let distanceFromPrevious = newCenterLoc.distance(from: previousCenterLoc)
        let maxAllowedDistance = previousSafeArea.radius - newRadius
        
        if distanceFromPrevious > maxAllowedDistance {
            // Clamp new center to stay within previous safe area
            // Guard against division by zero (distanceFromPrevious should be > 0 if we're in this branch)
            guard distanceFromPrevious > 0 else {
                // If distance is zero or negative, return previous center
                return (center: previousSafeArea.center, radius: newRadius)
            }
            let ratio = maxAllowedDistance / distanceFromPrevious
            let clampedLat = previousSafeArea.center.latitude + (newCenter.latitude - previousSafeArea.center.latitude) * ratio
            let clampedLon = previousSafeArea.center.longitude + (newCenter.longitude - previousSafeArea.center.longitude) * ratio
            let clampedCenter = CLLocationCoordinate2D(latitude: clampedLat, longitude: clampedLon)
            
            // Validate clamped coordinates
            guard clampedCenter.latitude.isFinite && clampedCenter.longitude.isFinite else {
                print("⚠️ Invalid clamped coordinates in calculateNextSafeArea - using previous center")
                return (center: previousSafeArea.center, radius: newRadius)
            }
            
            newCenter = clampedCenter
        }
        
        // Validate final coordinates
        guard newCenter.latitude.isFinite && newCenter.longitude.isFinite else {
            print("⚠️ Invalid newCenter coordinates in calculateNextSafeArea - using previous center")
            return (center: previousSafeArea.center, radius: newRadius)
        }
        
        return (center: newCenter, radius: newRadius)
    }
    
    // MARK: - Closing Speed Calculation
    
    /// Calculates the closing speed for a phase
    /// - Parameters:
    ///   - phaseNumber: Current phase number
    ///   - distanceToClose: Distance boundary needs to travel to reach safe area
    ///   - phaseDuration: Total duration of the closing phase
    /// - Returns: Closing speed in meters per second
    static func calculateClosingSpeed(
        phaseNumber: Int,
        distanceToClose: Double,
        phaseDuration: TimeInterval
    ) -> Double {
        // Base speed increases with phase
        let baseSpeed: Double
        if phaseNumber <= 1 {
            baseSpeed = 0.5 // Walking pace
        } else if phaseNumber <= 3 {
            baseSpeed = 1.2 // Fast walk
        } else if phaseNumber <= 5 {
            baseSpeed = 2.5 // Running pace
        } else if phaseNumber <= 7 {
            baseSpeed = 4.5 // Sprint
        } else {
            baseSpeed = 6.0 // Very fast (difficult to outrun)
        }
        
        // Validate phaseDuration to prevent division by zero
        guard phaseDuration > 0 else {
            print("⚠️ Invalid phaseDuration (\(phaseDuration)) in calculateClosingSpeed - using base speed")
            return baseSpeed
        }
        
        // Calculate minimum speed needed to close in time
        let minRequiredSpeed = distanceToClose / phaseDuration
        
        // Use the maximum of base speed and minimum required speed
        // This ensures boundary always reaches safe area in time
        return max(baseSpeed, minRequiredSpeed)
    }
    
    // MARK: - Boundary Movement
    
    /// Updates the boundary position based on current closing state
    /// - Parameters:
    ///   - currentTime: Current time
    ///   - closingStartTime: When the closing started
    ///   - closingDuration: How long the closing should take
    ///   - startCenter: Starting boundary center
    ///   - startRadius: Starting boundary radius
    ///   - targetCenter: Target boundary center (safe area)
    ///   - targetRadius: Target boundary radius (safe area radius)
    /// - Returns: Current boundary center and radius
    static func updateBoundaryPosition(
        currentTime: Date,
        closingStartTime: Date,
        closingDuration: TimeInterval,
        startCenter: CLLocationCoordinate2D,
        startRadius: Double,
        targetCenter: CLLocationCoordinate2D,
        targetRadius: Double
    ) -> (center: CLLocationCoordinate2D, radius: Double) {
        // Validate closingDuration to prevent division by zero
        guard closingDuration > 0 else {
            print("⚠️ Invalid closingDuration (\(closingDuration)) in updateBoundaryPosition - returning target position")
            return (center: targetCenter, radius: targetRadius)
        }
        
        let elapsed = currentTime.timeIntervalSince(closingStartTime)
        let progress = min(max(elapsed / closingDuration, 0.0), 1.0) // Clamp to [0, 1]
        
        // Linear interpolation of center and radius
        let currentCenterLat = startCenter.latitude + (targetCenter.latitude - startCenter.latitude) * progress
        let currentCenterLon = startCenter.longitude + (targetCenter.longitude - startCenter.longitude) * progress
        let currentCenter = CLLocationCoordinate2D(latitude: currentCenterLat, longitude: currentCenterLon)
        
        // Validate coordinates are finite
        guard currentCenter.latitude.isFinite && currentCenter.longitude.isFinite else {
            print("⚠️ Invalid coordinates in updateBoundaryPosition - using target position")
            return (center: targetCenter, radius: targetRadius)
        }
        
        let currentRadius = startRadius + (targetRadius - startRadius) * progress
        
        // Validate radius is positive and finite
        guard currentRadius > 0 && currentRadius.isFinite else {
            print("⚠️ Invalid radius (\(currentRadius)) in updateBoundaryPosition - using target radius")
            return (center: targetCenter, radius: targetRadius)
        }
        
        return (center: currentCenter, radius: currentRadius)
    }
    
    // MARK: - Phase Duration Calculation
    
    /// Calculates the duration for a phase based on phase number and game duration
    /// - Parameters:
    ///   - phaseNumber: The phase number (0 = initial passive phase)
    ///   - gameDuration: Total game duration in seconds
    /// - Returns: Duration in seconds for warning + closing combined
    static func phaseDuration(for phaseNumber: Int, gameDuration: TimeInterval) -> TimeInterval {
        if phaseNumber == 0 {
            // Phase 0 (initial passive): Use a fixed 2 minutes
            return 120.0
        }
        
        // Calculate how many events can fit in the remaining game time
        // Events should occur every 2-5 minutes (120-300 seconds)
        // We want to fit events evenly throughout the game
        
        let remainingTime = gameDuration - 120.0 // Subtract Phase 0 duration
        guard remainingTime > 0 else {
            return 120.0 // Fallback if game is too short
        }
        
        // Calculate number of events (target: 2-5 minute intervals)
        // Aim for 3-3.5 minute average intervals
        let targetInterval: TimeInterval = 210.0 // 3.5 minutes average
        let numEvents = max(1, Int(remainingTime / targetInterval))
        
        // Calculate actual interval between events
        let eventInterval = remainingTime / Double(numEvents)
        
        // Clamp interval to 2-5 minute range
        let clampedInterval = min(max(eventInterval, 120.0), 300.0)
        
        return clampedInterval
    }
    
    /// Calculates the warning duration for a phase
    /// - Parameters:
    ///   - phaseNumber: The phase number
    ///   - gameDuration: Total game duration in seconds
    /// - Returns: Warning duration in seconds
    static func warningDuration(for phaseNumber: Int, gameDuration: TimeInterval) -> TimeInterval {
        if phaseNumber == 0 {
            return 0.0 // No warning in initial passive phase
        }
        
        // Calculate closing duration (1-3 minutes, progressive)
        let closingDur = closingDuration(for: phaseNumber, gameDuration: gameDuration)
        
        // Calculate total phase duration
        let totalPhaseDuration = phaseDuration(for: phaseNumber, gameDuration: gameDuration)
        
        // Warning duration is the remaining time (but at least 30 seconds)
        let warningDur = max(30.0, totalPhaseDuration - closingDur)
        
        return warningDur
    }
    
    /// Calculates the closing duration for a phase (1-3 minutes, progressive)
    /// - Parameters:
    ///   - phaseNumber: The phase number
    ///   - gameDuration: Total game duration in seconds
    /// - Returns: Closing duration in seconds (60-180 seconds)
    static func closingDuration(for phaseNumber: Int, gameDuration: TimeInterval) -> TimeInterval {
        guard phaseNumber > 0 else { return 0.0 } // Phase 0 has no closing
        
        // Calculate how many events total
        let remainingTime = gameDuration - 120.0 // Subtract Phase 0
        guard remainingTime > 0 else { return 60.0 }
        
        let targetInterval: TimeInterval = 210.0
        let numEvents = max(1, Int(remainingTime / targetInterval))
        
        // Progressive closing duration: start at 180s (3 min), decrease to 60s (1 min)
        // Early phases: longer closing (3 minutes)
        // Late phases: shorter closing (1 minute)
        let progress = Double(phaseNumber - 1) / Double(max(1, numEvents - 1))
        let closingDur = 180.0 - (progress * 120.0) // 180s -> 60s
        
        // Clamp to 1-3 minute range (60-180 seconds)
        return min(max(closingDur, 60.0), 180.0)
    }
    
    // MARK: - Zone System Initialization
    
    /// Initializes the new zone system for a bubble
    /// This should be called when the game starts (not in lobby)
    /// - Parameters:
    ///   - bubble: Bubble to initialize (mutated)
    ///   - playerLocations: Current player locations (for intelligent initial safe area placement)
    static func initializeZoneSystem(
        bubble: inout Bubble,
        playerLocations: [CLLocationCoordinate2D] = []
    ) {
        guard !bubble.usesNewZoneSystem else { return } // Already initialized
        
        // Enable new zone system
        bubble.usesNewZoneSystem = true
        
        // Initialize boundary to match initial center and radius
        bubble.boundaryCenterLatitude = bubble.centerLatitude
        bubble.boundaryCenterLongitude = bubble.centerLongitude
        bubble.boundaryRadius = bubble.startRadius
        
        // Set up initial passive phase (Phase 0)
        bubble.currentPhaseNumber = 0
        bubble.isClosing = false
        bubble.isContinuousMode = false
        bubble.warningStartTime = nil
        bubble.closingStartTime = nil
        bubble.closingSpeed = 0.0
        
        // Select initial safe area (passive phase - players can see it, but boundary doesn't move yet)
        let initialSafeArea = selectInitialSafeArea(
            mapCenter: bubble.boundaryCenter,
            mapRadius: bubble.boundaryRadius,
            playerLocations: playerLocations
        )
        bubble.safeAreaCenter = initialSafeArea.center
        bubble.safeAreaRadius = initialSafeArea.radius
        
        // Create Phase 0 record
        let phase0 = ZonePhase(
            phaseNumber: 0,
            startTime: bubble.startTime,
            duration: Self.phaseDuration(for: 0, gameDuration: bubble.duration),
            safeAreaCenter: initialSafeArea.center,
            safeAreaRadius: initialSafeArea.radius,
            boundaryStartCenter: bubble.boundaryCenter,
            boundaryStartRadius: bubble.boundaryRadius,
            boundaryEndCenter: bubble.boundaryCenter, // No movement in passive phase
            boundaryEndRadius: bubble.boundaryRadius,
            closingSpeed: 0.0,
            warningDuration: 0.0,
            phaseType: .passive
        )
        bubble.phaseHistory.append(phase0)
        
        let phase0Dur = Self.phaseDuration(for: 0, gameDuration: bubble.duration)
        print("🎮 Zone: Initialized new zone system. Phase 0 (passive) started.")
        print("   Start time: \(bubble.startTime)")
        print("   Game duration: \(bubble.duration)s")
        print("   Phase 0 duration: \(phase0Dur)s")
        print("   Safe area: (\(initialSafeArea.center.latitude), \(initialSafeArea.center.longitude)), radius: \(initialSafeArea.radius)m")
        print("   Boundary: (\(bubble.boundaryCenter.latitude), \(bubble.boundaryCenter.longitude)), radius: \(bubble.boundaryRadius)m")
    }
    
    // MARK: - Phase Transition Management
    
    /// Determines if the zone should transition to the next phase
    /// - Parameters:
    ///   - bubble: The current bubble state
    ///   - currentTime: Current time
    /// - Returns: True if phase should transition
    static func shouldTransitionToNextPhase(
        bubble: Bubble,
        currentTime: Date
    ) -> Bool {
        guard bubble.usesNewZoneSystem else { return false } // Legacy system doesn't use phase transitions
        
        let elapsed = currentTime.timeIntervalSince(bubble.startTime)
        
        // Check if we're in a phase that should transition
        if bubble.isClosing {
            // Check if closing has completed
            if let closingStart = bubble.closingStartTime,
               let duration = bubble.closingDuration {
                let closingElapsed = currentTime.timeIntervalSince(closingStart)
                return closingElapsed >= duration
            }
            return false
        } else if bubble.warningStartTime != nil {
            // Check if warning phase should end and start closing
            let warningElapsed = currentTime.timeIntervalSince(bubble.warningStartTime!)
            return warningElapsed >= bubble.warningDuration
        } else {
            // In passive phase - check if it's time to start warning
            let phaseDuration = Self.phaseDuration(for: bubble.currentPhaseNumber, gameDuration: bubble.duration)
            let shouldTransition = elapsed >= phaseDuration
            if shouldTransition {
                print("🔵 Zone: Should transition from Phase \(bubble.currentPhaseNumber) - Elapsed: \(Int(elapsed))s, Phase duration: \(Int(phaseDuration))s")
            }
            return shouldTransition
        }
    }
    
    /// Enters the warning phase (shows next safe area preview)
    /// - Parameters:
    ///   - bubble: Current bubble state (mutated)
    ///   - currentTime: Current time
    ///   - playerLocations: Current player locations (for safe area calculation)
    static func enterWarningPhase(
        bubble: inout Bubble,
        currentTime: Date,
        playerLocations: [CLLocationCoordinate2D] = []
    ) {
        let nextPhaseNumber = bubble.currentPhaseNumber + 1
        
        // Calculate next safe area
        let currentSafeArea: (center: CLLocationCoordinate2D, radius: Double)
        if let safeCenter = bubble.safeAreaCenter, let safeRadius = bubble.safeAreaRadius {
            currentSafeArea = (center: safeCenter, radius: safeRadius)
        } else {
            // First phase - use initial safe area
            let initialSafeArea = selectInitialSafeArea(
                mapCenter: bubble.boundaryCenter,
                mapRadius: bubble.boundaryRadius,
                playerLocations: playerLocations
            )
            bubble.safeAreaCenter = initialSafeArea.center
            bubble.safeAreaRadius = initialSafeArea.radius
            currentSafeArea = initialSafeArea
        }
        
        let nextSafeArea = calculateNextSafeArea(
            previousSafeArea: currentSafeArea,
            phaseNumber: nextPhaseNumber,
            playerLocations: playerLocations
        )
        
        // Set preview of next safe area
        bubble.nextSafeAreaCenter = nextSafeArea.center
        bubble.nextSafeAreaRadius = nextSafeArea.radius
        bubble.warningStartTime = currentTime
        bubble.warningDuration = Self.warningDuration(for: nextPhaseNumber, gameDuration: bubble.duration)
        bubble.isClosing = false
        
        print("⚠️ Zone: Entered warning phase \(nextPhaseNumber). Next safe area at (\(nextSafeArea.center.latitude), \(nextSafeArea.center.longitude)), radius: \(nextSafeArea.radius)m")
    }
    
    /// Enters the closing phase (boundary moves toward safe area)
    /// - Parameters:
    ///   - bubble: Current bubble state (mutated)
    ///   - currentTime: Current time
    static func enterClosingPhase(
        bubble: inout Bubble,
        currentTime: Date
    ) {
        guard let nextSafeCenter = bubble.nextSafeAreaCenter,
              let nextSafeRadius = bubble.nextSafeAreaRadius else {
            print("❌ Cannot enter closing phase: next safe area not set")
            return
        }
        
        // Move current safe area to next safe area
        bubble.safeAreaCenter = nextSafeCenter
        bubble.safeAreaRadius = nextSafeRadius
        bubble.nextSafeAreaCenter = nil
        bubble.nextSafeAreaRadius = nil
        
        // Calculate distance to close
        let currentBoundaryCenter = bubble.boundaryCenter
        let currentBoundaryRadius = bubble.boundaryRadius
        let boundaryCenterLoc = CLLocation(latitude: currentBoundaryCenter.latitude, longitude: currentBoundaryCenter.longitude)
        let safeAreaLoc = CLLocation(latitude: nextSafeCenter.latitude, longitude: nextSafeCenter.longitude)
        let distanceToClose = boundaryCenterLoc.distance(from: safeAreaLoc)
        
        // Calculate closing duration and speed
        let nextPhaseNumber = bubble.currentPhaseNumber + 1
        let closingDuration = Self.closingDuration(for: nextPhaseNumber, gameDuration: bubble.duration)
        let totalPhaseDuration = Self.phaseDuration(for: nextPhaseNumber, gameDuration: bubble.duration)
        let warningDuration = Self.warningDuration(for: nextPhaseNumber, gameDuration: bubble.duration)
        
        let closingSpeed = calculateClosingSpeed(
            phaseNumber: nextPhaseNumber,
            distanceToClose: distanceToClose,
            phaseDuration: closingDuration
        )
        
        // Start closing
        bubble.isClosing = true
        bubble.closingStartTime = currentTime
        bubble.closingDuration = closingDuration
        bubble.closingSpeed = closingSpeed
        bubble.warningStartTime = nil
        
        // Update phase number
        bubble.currentPhaseNumber = nextPhaseNumber
        
        // Create phase record
        let phase = ZonePhase(
            phaseNumber: nextPhaseNumber,
            startTime: currentTime,
            duration: totalPhaseDuration,
            safeAreaCenter: nextSafeCenter,
            safeAreaRadius: nextSafeRadius,
            boundaryStartCenter: currentBoundaryCenter,
            boundaryStartRadius: currentBoundaryRadius,
            boundaryEndCenter: nextSafeCenter,
            boundaryEndRadius: nextSafeRadius,
            closingSpeed: closingSpeed,
            warningDuration: warningDuration,
            phaseType: nextPhaseNumber >= 7 ? .continuous : .closing
        )
        bubble.phaseHistory.append(phase)
        
        print("🏃 Zone: Entered closing phase \(nextPhaseNumber). Closing at \(closingSpeed) m/s over \(closingDuration)s")
    }
    
    // MARK: - Helper Functions
    
    private static func bearingBetween(_ from: CLLocationCoordinate2D, and to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let dLon = (to.longitude - from.longitude) * .pi / 180.0
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180.0 / .pi
        
        return (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}
