import Foundation
import CoreLocation

// MARK: - Zone System Types

enum PhaseType: String, Codable, Equatable {
    case passive      // Initial phase - no movement
    case warning      // Showing next safe area, not closing yet
    case closing      // Boundary moving toward safe area
    case continuous   // Late game - continuous movement
    case finalClosure // Final phase - no safe area, just shrinking
}

struct ZonePhase: Codable, Equatable {
    var phaseNumber: Int
    var startTime: Date
    var duration: TimeInterval
    var safeAreaCenterLatitude: Double
    var safeAreaCenterLongitude: Double
    var safeAreaRadius: Double
    var boundaryStartCenterLatitude: Double
    var boundaryStartCenterLongitude: Double
    var boundaryStartRadius: Double
    var boundaryEndCenterLatitude: Double
    var boundaryEndCenterLongitude: Double
    var boundaryEndRadius: Double
    var closingSpeed: Double // m/s
    var warningDuration: TimeInterval
    var phaseType: PhaseType
    
    var safeAreaCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: safeAreaCenterLatitude, longitude: safeAreaCenterLongitude)
    }
    
    var boundaryStartCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: boundaryStartCenterLatitude, longitude: boundaryStartCenterLongitude)
    }
    
    var boundaryEndCenter: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: boundaryEndCenterLatitude, longitude: boundaryEndCenterLongitude)
    }
    
    init(
        phaseNumber: Int,
        startTime: Date,
        duration: TimeInterval,
        safeAreaCenter: CLLocationCoordinate2D,
        safeAreaRadius: Double,
        boundaryStartCenter: CLLocationCoordinate2D,
        boundaryStartRadius: Double,
        boundaryEndCenter: CLLocationCoordinate2D,
        boundaryEndRadius: Double,
        closingSpeed: Double,
        warningDuration: TimeInterval,
        phaseType: PhaseType
    ) {
        self.phaseNumber = phaseNumber
        self.startTime = startTime
        self.duration = duration
        self.safeAreaCenterLatitude = safeAreaCenter.latitude
        self.safeAreaCenterLongitude = safeAreaCenter.longitude
        self.safeAreaRadius = safeAreaRadius
        self.boundaryStartCenterLatitude = boundaryStartCenter.latitude
        self.boundaryStartCenterLongitude = boundaryStartCenter.longitude
        self.boundaryStartRadius = boundaryStartRadius
        self.boundaryEndCenterLatitude = boundaryEndCenter.latitude
        self.boundaryEndCenterLongitude = boundaryEndCenter.longitude
        self.boundaryEndRadius = boundaryEndRadius
        self.closingSpeed = closingSpeed
        self.warningDuration = warningDuration
        self.phaseType = phaseType
    }
}

struct ZoneCircle: Equatable {
    var centerLatitude: Double
    var centerLongitude: Double
    var radiusMeters: Double
    
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    init(center: CLLocationCoordinate2D, radiusMeters: Double) {
        self.centerLatitude = center.latitude
        self.centerLongitude = center.longitude
        self.radiusMeters = radiusMeters
    }
}

enum ZoneShrinkBehavior: String, Codable, Equatable {
    case contained
    case moving
}

struct ZoneScheduleEntry: Codable, Identifiable, Equatable {
    var id: String
    var phaseIndex: Int
    var areaPercent: Double
    var centerLatitude: Double
    var centerLongitude: Double
    var radiusMeters: Double
    var pullAngle: Double?
    var pullStrength: Double?
    var revealOffset: TimeInterval
    var closingStartOffset: TimeInterval
    var closingEndOffset: TimeInterval
    var revealTime: Date
    var closingStartTime: Date
    var closingEndTime: Date
    var shrinkBehavior: ZoneShrinkBehavior
    
    enum CodingKeys: String, CodingKey {
        case id, phaseIndex, areaPercent, centerLatitude, centerLongitude, radiusMeters
        case pullAngle, pullStrength
        case revealOffset, closingStartOffset, closingEndOffset
        case revealTime, closingStartTime, closingEndTime
        case shrinkBehavior
    }
    
    var centerCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLatitude, longitude: centerLongitude)
    }
    
    var zoneCircle: ZoneCircle {
        ZoneCircle(center: centerCoordinate, radiusMeters: radiusMeters)
    }
    
    init(
        id: String = UUID().uuidString,
        phaseIndex: Int,
        areaPercent: Double,
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        pullAngle: Double?,
        pullStrength: Double?,
        revealOffset: TimeInterval,
        closingStartOffset: TimeInterval,
        closingEndOffset: TimeInterval,
        timingAnchor: Date,
        shrinkBehavior: ZoneShrinkBehavior = .contained
    ) {
        self.id = id
        self.phaseIndex = phaseIndex
        self.areaPercent = areaPercent
        self.centerLatitude = center.latitude
        self.centerLongitude = center.longitude
        self.radiusMeters = radiusMeters
        self.pullAngle = pullAngle
        self.pullStrength = pullStrength
        self.revealOffset = revealOffset
        self.closingStartOffset = closingStartOffset
        self.closingEndOffset = closingEndOffset
        self.revealTime = timingAnchor.addingTimeInterval(revealOffset)
        self.closingStartTime = timingAnchor.addingTimeInterval(closingStartOffset)
        self.closingEndTime = timingAnchor.addingTimeInterval(closingEndOffset)
        self.shrinkBehavior = shrinkBehavior
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        phaseIndex = try container.decode(Int.self, forKey: .phaseIndex)
        areaPercent = try container.decode(Double.self, forKey: .areaPercent)
        centerLatitude = try container.decode(Double.self, forKey: .centerLatitude)
        centerLongitude = try container.decode(Double.self, forKey: .centerLongitude)
        radiusMeters = try container.decode(Double.self, forKey: .radiusMeters)
        pullAngle = try container.decodeIfPresent(Double.self, forKey: .pullAngle)
        pullStrength = try container.decodeIfPresent(Double.self, forKey: .pullStrength)
        revealOffset = try container.decode(TimeInterval.self, forKey: .revealOffset)
        closingStartOffset = try container.decode(TimeInterval.self, forKey: .closingStartOffset)
        closingEndOffset = try container.decode(TimeInterval.self, forKey: .closingEndOffset)
        revealTime = try container.decode(Date.self, forKey: .revealTime)
        closingStartTime = try container.decode(Date.self, forKey: .closingStartTime)
        closingEndTime = try container.decode(Date.self, forKey: .closingEndTime)
        shrinkBehavior = try container.decodeIfPresent(ZoneShrinkBehavior.self, forKey: .shrinkBehavior) ?? .contained
    }
}

enum RuntimeZonePhaseState: String, Equatable {
    case openingGrace
    case rotation
    case closing
    case complete
}

struct RuntimeZoneState: Equatable {
    var currentActiveZone: ZoneCircle
    var nextPreviewZone: ZoneCircle?
    var phaseState: RuntimeZonePhaseState
    var timeRemainingInPhase: TimeInterval?
    var scheduleIsValid: Bool
    var scheduleIsEnabled: Bool
    var enforcementToleranceMeters: Double
    
    func distanceToEdge(from coordinate: CLLocationCoordinate2D) -> Double {
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let center = CLLocation(
            latitude: currentActiveZone.centerLatitude,
            longitude: currentActiveZone.centerLongitude
        )
        return point.distance(from: center) - currentActiveZone.radiusMeters
    }
}

// MARK: - Bubble

struct Bubble: Codable, Equatable {
    var centerLatitude: Double
    var centerLongitude: Double
    var startRadius: Double
    var startTime: Date
    var shrinkInterval: Double // seconds between shrinks (default: 180 = 3 minutes)
    var duration: Double // Total game duration in seconds
    var shrinkHistory: [ShrinkEvent] = [] // Track each shrink event (center movement and radius) - LEGACY
    var showTimer: Bool = true // Whether to show the game timer in the UI
    var enableShrinking: Bool = true // Whether the zone should shrink over time (if false, zone stays fixed)
    
    // NEW: Zone System Fields
    var currentPhaseNumber: Int = 0
    var phaseHistory: [ZonePhase] = []
    var safeAreaCenterLatitude: Double? // Current target safe area
    var safeAreaCenterLongitude: Double?
    var safeAreaRadius: Double? // Current target safe area radius
    var boundaryCenterLatitude: Double // Current playable boundary center (defaults to centerLatitude)
    var boundaryCenterLongitude: Double // Current playable boundary center (defaults to centerLongitude)
    var boundaryRadius: Double // Current playable boundary radius (defaults to startRadius)
    var isClosing: Bool = false // Is boundary currently moving?
    var closingStartTime: Date? // When current closing started
    var closingDuration: TimeInterval? // How long current closing takes
    var nextSafeAreaCenterLatitude: Double? // Preview of next safe area
    var nextSafeAreaCenterLongitude: Double?
    var nextSafeAreaRadius: Double? // Preview of next safe area radius
    var warningStartTime: Date? // When warning phase started
    var warningDuration: TimeInterval = 30.0 // Default 30s warning
    var closingSpeed: Double = 0.0 // Meters per second boundary moves
    var isContinuousMode: Bool = false // Late game continuous movement
    var usesNewZoneSystem: Bool = false // Flag to indicate new vs legacy system
    var zoneSchedule: [ZoneScheduleEntry] = []
    var zoneScheduleGeneratedAt: Date?
    var zoneScheduleEnabled: Bool = false
    
    // Sentinel value for "infinite" (no shrinking, no time limit)
    // JSON/Firestore cannot encode Double.infinity, so we use a very large number
    static let infiniteSentinel: Double = 1e10 // 10 billion seconds (~317 years)
    
    enum CodingKeys: String, CodingKey {
        case centerLatitude, centerLongitude, startRadius, startTime, shrinkInterval, duration, shrinkHistory, showTimer, enableShrinking
        // New zone system keys
        case currentPhaseNumber, phaseHistory
        case safeAreaCenterLatitude, safeAreaCenterLongitude, safeAreaRadius
        case boundaryCenterLatitude, boundaryCenterLongitude, boundaryRadius
        case isClosing, closingStartTime, closingDuration
        case nextSafeAreaCenterLatitude, nextSafeAreaCenterLongitude, nextSafeAreaRadius
        case warningStartTime, warningDuration, closingSpeed, isContinuousMode
        case usesNewZoneSystem
        case zoneSchedule, zoneScheduleGeneratedAt, zoneScheduleEnabled
    }
    
    // Computed properties for convenience
    var safeAreaCenter: CLLocationCoordinate2D? {
        get {
            guard let lat = safeAreaCenterLatitude, let lon = safeAreaCenterLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            safeAreaCenterLatitude = newValue?.latitude
            safeAreaCenterLongitude = newValue?.longitude
        }
    }
    
    var nextSafeAreaCenter: CLLocationCoordinate2D? {
        get {
            guard let lat = nextSafeAreaCenterLatitude, let lon = nextSafeAreaCenterLongitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            nextSafeAreaCenterLatitude = newValue?.latitude
            nextSafeAreaCenterLongitude = newValue?.longitude
        }
    }
    
    var boundaryCenter: CLLocationCoordinate2D {
        get {
            CLLocationCoordinate2D(latitude: boundaryCenterLatitude, longitude: boundaryCenterLongitude)
        }
        set {
            boundaryCenterLatitude = newValue.latitude
            boundaryCenterLongitude = newValue.longitude
        }
    }
    
    // Explicit memberwise initializer
    init(
        centerLatitude: Double,
        centerLongitude: Double,
        startRadius: Double,
        startTime: Date,
        shrinkInterval: Double,
        duration: Double,
        shrinkHistory: [ShrinkEvent] = [],
        showTimer: Bool = true,
        enableShrinking: Bool = true,
        usesNewZoneSystem: Bool = false,
        zoneSchedule: [ZoneScheduleEntry] = [],
        zoneScheduleGeneratedAt: Date? = nil,
        zoneScheduleEnabled: Bool = false
    ) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.startRadius = startRadius
        self.startTime = startTime
        self.shrinkInterval = shrinkInterval
        self.duration = duration
        self.shrinkHistory = shrinkHistory
        self.showTimer = showTimer
        self.enableShrinking = enableShrinking
        self.usesNewZoneSystem = usesNewZoneSystem
        self.zoneSchedule = zoneSchedule
        self.zoneScheduleGeneratedAt = zoneScheduleGeneratedAt
        self.zoneScheduleEnabled = zoneScheduleEnabled
        
        // Initialize new zone system fields with defaults
        self.currentPhaseNumber = 0
        self.phaseHistory = []
        self.safeAreaCenterLatitude = nil
        self.safeAreaCenterLongitude = nil
        self.safeAreaRadius = nil
        self.boundaryCenterLatitude = centerLatitude
        self.boundaryCenterLongitude = centerLongitude
        self.boundaryRadius = startRadius
        self.isClosing = false
        self.closingStartTime = nil
        self.closingDuration = nil
        self.nextSafeAreaCenterLatitude = nil
        self.nextSafeAreaCenterLongitude = nil
        self.nextSafeAreaRadius = nil
        self.warningStartTime = nil
        self.warningDuration = 30.0
        self.closingSpeed = 0.0
        self.isContinuousMode = false
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        centerLatitude = try container.decode(Double.self, forKey: .centerLatitude)
        centerLongitude = try container.decode(Double.self, forKey: .centerLongitude)
        startRadius = try container.decode(Double.self, forKey: .startRadius)
        startTime = try container.decode(Date.self, forKey: .startTime)
        
        // Decode shrinkInterval - convert sentinel back to infinity
        let shrinkIntervalValue = try container.decode(Double.self, forKey: .shrinkInterval)
        shrinkInterval = shrinkIntervalValue >= Self.infiniteSentinel ? Double.infinity : shrinkIntervalValue
        
        // Decode duration - convert sentinel back to infinity
        let durationValue = try container.decode(Double.self, forKey: .duration)
        duration = durationValue >= Self.infiniteSentinel ? Double.infinity : durationValue
        
        shrinkHistory = try container.decodeIfPresent([ShrinkEvent].self, forKey: .shrinkHistory) ?? []
        
        // Decode showTimer - default to true for backwards compatibility
        showTimer = try container.decodeIfPresent(Bool.self, forKey: .showTimer) ?? true
        
        // Decode enableShrinking - default to true for backwards compatibility
        enableShrinking = try container.decodeIfPresent(Bool.self, forKey: .enableShrinking) ?? true
        
        // Decode new zone system fields - all optional for backwards compatibility
        usesNewZoneSystem = try container.decodeIfPresent(Bool.self, forKey: .usesNewZoneSystem) ?? false
        currentPhaseNumber = try container.decodeIfPresent(Int.self, forKey: .currentPhaseNumber) ?? 0
        phaseHistory = try container.decodeIfPresent([ZonePhase].self, forKey: .phaseHistory) ?? []
        safeAreaCenterLatitude = try container.decodeIfPresent(Double.self, forKey: .safeAreaCenterLatitude)
        safeAreaCenterLongitude = try container.decodeIfPresent(Double.self, forKey: .safeAreaCenterLongitude)
        safeAreaRadius = try container.decodeIfPresent(Double.self, forKey: .safeAreaRadius)
        boundaryCenterLatitude = try container.decodeIfPresent(Double.self, forKey: .boundaryCenterLatitude) ?? centerLatitude
        boundaryCenterLongitude = try container.decodeIfPresent(Double.self, forKey: .boundaryCenterLongitude) ?? centerLongitude
        boundaryRadius = try container.decodeIfPresent(Double.self, forKey: .boundaryRadius) ?? startRadius
        isClosing = try container.decodeIfPresent(Bool.self, forKey: .isClosing) ?? false
        closingStartTime = try container.decodeIfPresent(Date.self, forKey: .closingStartTime)
        closingDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .closingDuration)
        nextSafeAreaCenterLatitude = try container.decodeIfPresent(Double.self, forKey: .nextSafeAreaCenterLatitude)
        nextSafeAreaCenterLongitude = try container.decodeIfPresent(Double.self, forKey: .nextSafeAreaCenterLongitude)
        nextSafeAreaRadius = try container.decodeIfPresent(Double.self, forKey: .nextSafeAreaRadius)
        warningStartTime = try container.decodeIfPresent(Date.self, forKey: .warningStartTime)
        warningDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .warningDuration) ?? 30.0
        closingSpeed = try container.decodeIfPresent(Double.self, forKey: .closingSpeed) ?? 0.0
        isContinuousMode = try container.decodeIfPresent(Bool.self, forKey: .isContinuousMode) ?? false
        zoneSchedule = try container.decodeIfPresent([ZoneScheduleEntry].self, forKey: .zoneSchedule) ?? []
        zoneScheduleGeneratedAt = try container.decodeIfPresent(Date.self, forKey: .zoneScheduleGeneratedAt)
        zoneScheduleEnabled = try container.decodeIfPresent(Bool.self, forKey: .zoneScheduleEnabled) ?? false
        
        // Migration: If old system bubble, ensure boundary fields are initialized
        if !usesNewZoneSystem {
            boundaryCenterLatitude = centerLatitude
            boundaryCenterLongitude = centerLongitude
            boundaryRadius = startRadius
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(centerLatitude, forKey: .centerLatitude)
        try container.encode(centerLongitude, forKey: .centerLongitude)
        try container.encode(startRadius, forKey: .startRadius)
        try container.encode(startTime, forKey: .startTime)
        
        // Encode infinity as sentinel value (JSON/Firestore cannot encode Double.infinity)
        let shrinkIntervalValue = shrinkInterval.isInfinite ? Self.infiniteSentinel : shrinkInterval
        try container.encode(shrinkIntervalValue, forKey: .shrinkInterval)
        
        let durationValue = duration.isInfinite ? Self.infiniteSentinel : duration
        try container.encode(durationValue, forKey: .duration)
        
        try container.encode(shrinkHistory, forKey: .shrinkHistory)
        try container.encode(showTimer, forKey: .showTimer)
        try container.encode(enableShrinking, forKey: .enableShrinking)
        
        // Encode new zone system fields
        try container.encode(usesNewZoneSystem, forKey: .usesNewZoneSystem)
        try container.encode(currentPhaseNumber, forKey: .currentPhaseNumber)
        try container.encode(phaseHistory, forKey: .phaseHistory)
        if let lat = safeAreaCenterLatitude {
            try container.encode(lat, forKey: .safeAreaCenterLatitude)
        }
        if let lon = safeAreaCenterLongitude {
            try container.encode(lon, forKey: .safeAreaCenterLongitude)
        }
        if let radius = safeAreaRadius {
            try container.encode(radius, forKey: .safeAreaRadius)
        }
        try container.encode(boundaryCenterLatitude, forKey: .boundaryCenterLatitude)
        try container.encode(boundaryCenterLongitude, forKey: .boundaryCenterLongitude)
        try container.encode(boundaryRadius, forKey: .boundaryRadius)
        try container.encode(isClosing, forKey: .isClosing)
        if let startTime = closingStartTime {
            try container.encode(startTime, forKey: .closingStartTime)
        }
        if let duration = closingDuration {
            try container.encode(duration, forKey: .closingDuration)
        }
        if let lat = nextSafeAreaCenterLatitude {
            try container.encode(lat, forKey: .nextSafeAreaCenterLatitude)
        }
        if let lon = nextSafeAreaCenterLongitude {
            try container.encode(lon, forKey: .nextSafeAreaCenterLongitude)
        }
        if let radius = nextSafeAreaRadius {
            try container.encode(radius, forKey: .nextSafeAreaRadius)
        }
        if let startTime = warningStartTime {
            try container.encode(startTime, forKey: .warningStartTime)
        }
        try container.encode(warningDuration, forKey: .warningDuration)
        try container.encode(closingSpeed, forKey: .closingSpeed)
        try container.encode(isContinuousMode, forKey: .isContinuousMode)
        try container.encode(zoneSchedule, forKey: .zoneSchedule)
        if let generatedAt = zoneScheduleGeneratedAt {
            try container.encode(generatedAt, forKey: .zoneScheduleGeneratedAt)
        }
        try container.encode(zoneScheduleEnabled, forKey: .zoneScheduleEnabled)
    }
    
    // MARK: - Migration Helpers
    
    /// Migrates an old bubble to the new zone system
    /// This creates initial phase data from the old shrinkHistory
    mutating func migrateToNewZoneSystem() {
        guard !usesNewZoneSystem else { return } // Already migrated
        
        usesNewZoneSystem = true
        boundaryCenterLatitude = centerLatitude
        boundaryCenterLongitude = centerLongitude
        boundaryRadius = startRadius
        
        // If we have shrink history, we can reconstruct some phase data
        // Otherwise, bubble will start fresh with new system
        if !shrinkHistory.isEmpty {
            // Create initial phase from first shrink event
            if let firstShrink = shrinkHistory.first {
                let safeArea = CLLocationCoordinate2D(
                    latitude: firstShrink.centerLatitude,
                    longitude: firstShrink.centerLongitude
                )
                safeAreaCenterLatitude = safeArea.latitude
                safeAreaCenterLongitude = safeArea.longitude
                safeAreaRadius = firstShrink.radius
            }
        }
        
        // Note: Old shrinkHistory is kept for reference but won't be used by new system
    }
    
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
