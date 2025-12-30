import Foundation
import CoreLocation

struct Bubble: Codable, Equatable {
    var centerLatitude: Double
    var centerLongitude: Double
    var startRadius: Double
    var startTime: Date
    var shrinkInterval: Double // seconds between shrinks (default: 180 = 3 minutes)
    var duration: Double // Total game duration in seconds
    var shrinkHistory: [ShrinkEvent] = [] // Track each shrink event (center movement and radius)
    
    struct ShrinkEvent: Codable, Equatable {
        var phase: Int // Which shrink phase (0, 1, 2, ...)
        var centerLatitude: Double
        var centerLongitude: Double
        var radius: Double
        var timestamp: Date
    }
    
    // For backwards compatibility - endRadius is deprecated but kept for migration
    var endRadius: Double {
        get { 0 } // Always return 0 (no minimum)
        set { _ = newValue } // Ignore setter
    }
    
    // For backwards compatibility - shrinkAmount is deprecated
    var shrinkAmount: Double {
        get { startRadius * 0.15 } // Default 15% shrink
        set { _ = newValue } // Ignore setter
    }
    
    var center: CLLocationCoordinate2D {
        currentCenter(at: Date())
    }
    
    var centerLocation: CLLocation {
        let center = currentCenter(at: Date())
        return CLLocation(latitude: center.latitude, longitude: center.longitude)
    }
    
    // Calculate current center (moves randomly with each shrink)
    func currentCenter(at time: Date = Date()) -> CLLocationCoordinate2D {
        // Validate center coordinates
        guard centerLatitude.isFinite && centerLongitude.isFinite,
              centerLatitude >= -90 && centerLatitude <= 90,
              centerLongitude >= -180 && centerLongitude <= 180 else {
            print("⚠️ Invalid bubble center coordinates - using default")
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        
        guard shrinkInterval > 0 && shrinkInterval.isFinite else {
            return CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
        }
        
        let elapsed = time.timeIntervalSince(startTime)
        guard elapsed.isFinite && elapsed >= 0 else {
            print("⚠️ Invalid elapsed time in currentCenter - using initial center")
            return CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
        }
        
        let currentPhase = Int(elapsed / shrinkInterval)
        
        // Find the most recent shrink event for this phase or earlier
        if let latestEvent = shrinkHistory.last(where: { $0.phase <= currentPhase }) {
            return CLLocationCoordinate2D(
                latitude: latestEvent.centerLatitude,
                longitude: latestEvent.centerLongitude
            )
        }
        
        // No shrink events yet - use initial center
        return CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    // Progressive shrinking: each shrink is smaller than the last
    // Uses exponential decay: radius = startRadius * (0.85 ^ phase)
    // This means: phase 0 = 100%, phase 1 = 85%, phase 2 = 72%, phase 3 = 61%, etc.
    // Eventually shrinks to near zero
    func currentRadius(at time: Date = Date()) -> Double {
        // Validate start radius
        guard startRadius.isFinite && startRadius > 0 else {
            print("⚠️ Invalid start radius: \(startRadius) - returning default")
            return 100.0 // Default 100m radius
        }
        
        guard shrinkInterval > 0 && shrinkInterval.isFinite else { return startRadius }
        
        let elapsed = time.timeIntervalSince(startTime)
        guard elapsed.isFinite && elapsed >= 0 else {
            print("⚠️ Invalid elapsed time in currentRadius - returning start radius")
            return startRadius
        }
        
        let phase = Int(elapsed / shrinkInterval)
        
        // Progressive shrinking: each phase shrinks by 15% of remaining radius
        // Formula: radius = startRadius * (0.85 ^ phase)
        let shrinkFactor = pow(0.85, Double(phase))
        guard shrinkFactor.isFinite && shrinkFactor > 0 else {
            print("⚠️ Invalid shrink factor calculation - returning minimum radius")
            return 1.0
        }
        
        let newRadius = startRadius * shrinkFactor
        guard newRadius.isFinite && newRadius > 0 else {
            print("⚠️ Invalid new radius calculation - returning minimum")
            return 1.0
        }
        
        // Never go below 1 meter (practically zero but prevents division issues)
        return max(newRadius, 1.0)
    }
    
    // Get time until next shrink
    func timeUntilNextShrink(at time: Date = Date()) -> TimeInterval {
        guard shrinkInterval > 0 else { return 0 }
        let elapsed = time.timeIntervalSince(startTime)
        let timeSinceLastShrink = elapsed.truncatingRemainder(dividingBy: shrinkInterval)
        return shrinkInterval - timeSinceLastShrink
    }
    
    // Get current shrink phase (0 = first phase, 1 = second, etc.)
    func currentPhase(at time: Date = Date()) -> Int {
        guard shrinkInterval > 0 else { return 0 }
        let elapsed = time.timeIntervalSince(startTime)
        return Int(elapsed / shrinkInterval)
    }
    
    // Calculate next shrink event (random center movement + progressive radius)
    // This should be called when a shrink occurs
    mutating func calculateNextShrink() {
        let currentPhase = self.currentPhase()
        let currentCenter = self.currentCenter()
        let currentRadius = self.currentRadius()
        
        // Calculate new radius (progressive shrink - 15% of remaining)
        let nextPhase = currentPhase + 1
        let shrinkFactor = pow(0.85, Double(nextPhase))
        let newRadius = max(startRadius * shrinkFactor, 1.0)
        
        // Random movement: new center is randomly placed within current zone
        // Move center by random amount (0 to 30% of current radius) in random direction
        let maxMovement = currentRadius * 0.3 // Can move up to 30% of radius
        let randomDistance = Double.random(in: 0...maxMovement)
        let randomAngle = Double.random(in: 0...(2 * .pi))
        
        // Convert meters to degrees (approximate: 1 degree ≈ 111,000 meters)
        let offsetLat = randomDistance * cos(randomAngle) / 111000.0
        let offsetLon = randomDistance * sin(randomAngle) / (111000.0 * cos(currentCenter.latitude * .pi / 180.0))
        
        let newCenter = CLLocationCoordinate2D(
            latitude: currentCenter.latitude + offsetLat,
            longitude: currentCenter.longitude + offsetLon
        )
        
        // Ensure new center is within the old zone (safety check)
        let oldCenterLocation = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
        let newCenterLocation = CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude)
        let distanceFromOldCenter = newCenterLocation.distance(from: oldCenterLocation)
        
        // If new center is outside old zone, clamp it
        let clampedCenter: CLLocationCoordinate2D
        if distanceFromOldCenter > currentRadius {
            // Move new center back towards old center
            let ratio = currentRadius / distanceFromOldCenter
            let clampedLat = currentCenter.latitude + (newCenter.latitude - currentCenter.latitude) * ratio
            let clampedLon = currentCenter.longitude + (newCenter.longitude - currentCenter.longitude) * ratio
            clampedCenter = CLLocationCoordinate2D(latitude: clampedLat, longitude: clampedLon)
        } else {
            clampedCenter = newCenter
        }
        
        // Create shrink event
        let shrinkEvent = ShrinkEvent(
            phase: nextPhase,
            centerLatitude: clampedCenter.latitude,
            centerLongitude: clampedCenter.longitude,
            radius: newRadius,
            timestamp: Date()
        )
        
        shrinkHistory.append(shrinkEvent)
    }
    
    func isPointInside(_ coordinate: CLLocationCoordinate2D, at time: Date = Date()) -> Bool {
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let center = currentCenter(at: time)
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let distance = point.distance(from: centerLocation)
        return distance <= currentRadius(at: time)
    }
    
    func distanceToEdge(from coordinate: CLLocationCoordinate2D, at time: Date = Date()) -> Double {
        // Validate input coordinate
        guard coordinate.latitude.isFinite && coordinate.longitude.isFinite,
              coordinate.latitude >= -90 && coordinate.latitude <= 90,
              coordinate.longitude >= -180 && coordinate.longitude <= 180 else {
            print("⚠️ Invalid coordinate in distanceToEdge - returning large positive value")
            return 1000.0 // Return large positive (outside) for invalid coordinates
        }
        
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let center = currentCenter(at: time)
        
        // Validate center
        guard center.latitude.isFinite && center.longitude.isFinite else {
            print("⚠️ Invalid center in distanceToEdge - returning large positive value")
            return 1000.0
        }
        
        let centerLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
        let distance = point.distance(from: centerLocation)
        
        // Validate distance
        guard distance.isFinite && distance >= 0 else {
            print("⚠️ Invalid distance calculation in distanceToEdge - returning large positive value")
            return 1000.0
        }
        
        let radius = currentRadius(at: time)
        guard radius.isFinite && radius > 0 else {
            print("⚠️ Invalid radius in distanceToEdge - returning large positive value")
            return 1000.0
        }
        
        let result = distance - radius
        guard result.isFinite else {
            print("⚠️ Invalid result in distanceToEdge - returning large positive value")
            return 1000.0
        }
        
        return result // Negative if inside, positive if outside
    }
}
