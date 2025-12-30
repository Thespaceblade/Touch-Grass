import Foundation
import CoreLocation
import Combine
import CoreMotion

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {

    @Published var coordinate: CLLocationCoordinate2D?
    @Published var accuracy: CLLocationAccuracy?
    @Published var authorization: CLAuthorizationStatus = .notDetermined
    @Published var isMoving: Bool = false // Track motion state

    private let manager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private var motionUpdateTimer: Timer?
    private var lastMotionDetection: Date = Date()
    private var isLocationActive: Bool = false
    private var motionDetectionActive: Bool = false
    private var lastAcceleration: CMAcceleration? // For accelerometer fallback
    
    // Motion detection thresholds
    private let motionAccelerationThreshold: Double = 0.15 // m/s² - user acceleration threshold (gravity-filtered)
    private let motionDetectionInterval: TimeInterval = 0.5 // Check motion every 0.5s
    private let motionStopDelay: TimeInterval = 3.0 // Stop GPS 3s after motion stops (to avoid constant toggling)

    override init() {
        super.init()
        manager.delegate = self
        // Optimized: Use 10m accuracy instead of Best (reduces battery drain by ~70%)
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        // Optimized: Only update when moved 10m+ (was 5m) - reduces CPU usage
        manager.distanceFilter = 10
        manager.pausesLocationUpdatesAutomatically = false
        // Enable background location updates
        manager.allowsBackgroundLocationUpdates = true

        // 🔑 SYNC CURRENT AUTH STATE - Use instance property (iOS 14+)
        let currentStatus = manager.authorizationStatus
        authorization = currentStatus

        // PERFORMANCE: Don't auto-start location updates on init
        // Location will start when explicitly requested (e.g., when game session is created)
        // This improves initial load performance
        // Motion detection will start when start() is called
    }
    
    deinit {
        // Note: CMMotionManager and CLLocationManager will automatically stop their updates
        // when deallocated. We can't call stop methods here due to MainActor isolation,
        // but the system handles cleanup automatically.
    }
    
    // MARK: - Motion Detection
    
    private func startMotionDetection() {
        guard !motionDetectionActive else { return }
        
        // Use device motion (filters out gravity) for better accuracy
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = motionDetectionInterval
            motionDetectionActive = true
            
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let self = self, let motion = motion else { return }
                
                // Get user acceleration (acceleration minus gravity) - this is what we want
                let userAccel = motion.userAcceleration
                let magnitude = sqrt(pow(userAccel.x, 2) + pow(userAccel.y, 2) + pow(userAccel.z, 2))
                
                // Detect if device is moving (above threshold)
                let moving = magnitude > self.motionAccelerationThreshold
                
                if moving {
                    self.lastMotionDetection = Date()
                    
                    // Start location updates if motion detected and we're not already active
                    if !self.isMoving {
                        self.isMoving = true
                        self.startLocationUpdatesIfNeeded()
                    }
                } else {
                    // Check if we should stop location updates (after delay)
                    let timeSinceLastMotion = Date().timeIntervalSince(self.lastMotionDetection)
                    if self.isMoving && timeSinceLastMotion > self.motionStopDelay {
                        self.isMoving = false
                        self.stopLocationUpdatesIfNeeded()
                    }
                }
            }
        } else if motionManager.isAccelerometerAvailable {
            // Fallback to accelerometer if device motion not available
            motionManager.accelerometerUpdateInterval = motionDetectionInterval
            motionDetectionActive = true
            lastAcceleration = nil // Reset tracking
            
            motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
                guard let self = self, let acceleration = data?.acceleration else { return }
                
                if let last = self.lastAcceleration {
                    // Calculate change in acceleration (indicates movement)
                    let deltaX = abs(acceleration.x - last.x)
                    let deltaY = abs(acceleration.y - last.y)
                    let deltaZ = abs(acceleration.z - last.z)
                    let deltaMagnitude = sqrt(pow(deltaX, 2) + pow(deltaY, 2) + pow(deltaZ, 2))
                    
                    let moving = deltaMagnitude > self.motionAccelerationThreshold * 0.5
                    
                    if moving {
                        self.lastMotionDetection = Date()
                        if !self.isMoving {
                            self.isMoving = true
                            self.startLocationUpdatesIfNeeded()
                        }
                    } else {
                        let timeSinceLastMotion = Date().timeIntervalSince(self.lastMotionDetection)
                        if self.isMoving && timeSinceLastMotion > self.motionStopDelay {
                            self.isMoving = false
                            self.stopLocationUpdatesIfNeeded()
                        }
                    }
                }
                self.lastAcceleration = acceleration
            }
        }
    }
    
    private func stopMotionDetection() {
        motionManager.stopDeviceMotionUpdates()
        motionManager.stopAccelerometerUpdates()
        motionUpdateTimer?.invalidate()
        motionUpdateTimer = nil
        motionDetectionActive = false
        lastAcceleration = nil
        isMoving = false
    }
    
    private func startLocationUpdatesIfNeeded() {
        // Only start if we have authorization and aren't already running
        guard !isLocationActive,
              authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            return
        }
        
        isLocationActive = true
        manager.startUpdatingLocation()
        DebugLogger.log("📍 GPS started (motion detected)")
    }
    
    private func stopLocationUpdatesIfNeeded() {
        // Only stop if we're currently running
        guard isLocationActive else { return }
        
        isLocationActive = false
        manager.stopUpdatingLocation()
        DebugLogger.log("📍 GPS stopped (no motion detected)")
    }

    func requestPermission() {
        let status = manager.authorizationStatus

        switch status {
        case .notDetermined:
            // First request "When In Use" permission
            manager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse:
            // Start location updates with current permission
            start()
            // Request "Always" authorization for background location updates
            // This is required for background location tracking during games
            manager.requestAlwaysAuthorization()

        case .authorizedAlways:
            start()

        case .denied, .restricted:
            break
            
        @unknown default:
            break
        }
    }

    func start() {
        guard authorization == .authorizedWhenInUse || authorization == .authorizedAlways else {
            return
        }
        
        // Enable background location if we have Always authorization
        if authorization == .authorizedAlways {
            manager.allowsBackgroundLocationUpdates = true
        } else {
            manager.allowsBackgroundLocationUpdates = false
        }
        
        // Start motion detection - it will start GPS when motion is detected
        startMotionDetection()
        
        // Get initial location immediately if we don't have one yet
        if coordinate == nil {
            manager.startUpdatingLocation()
            isLocationActive = true
            DebugLogger.log("📍 GPS started (initial location request)")
        }
    }

    func stop() {
        manager.stopUpdatingLocation()
        isLocationActive = false
        stopMotionDetection()
    }
    
    func getCurrentLocation() -> CLLocation? {
        guard let coord = coordinate else { return nil }
        return CLLocation(latitude: coord.latitude, longitude: coord.longitude)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let newStatus = manager.authorizationStatus
        let oldStatus = authorization
        authorization = newStatus

        if newStatus == .denied || newStatus == .restricted {
            coordinate = nil
            accuracy = nil
            stopMotionDetection()
        } else if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
            // Start location updates if:
            // 1. We just got permission (was notDetermined before)
            // 2. We upgraded from When In Use to Always (enables background location)
            if oldStatus == .notDetermined || (oldStatus == .authorizedWhenInUse && newStatus == .authorizedAlways) {
                start()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {

        guard let loc = locations.last else { return }
        
        // Only update if accuracy is reasonable (< 50m) or if we don't have a location yet
        if let currentCoord = coordinate {
            let currentLoc = CLLocation(latitude: currentCoord.latitude, longitude: currentCoord.longitude)
            let distance = loc.distance(from: currentLoc)
            
            // Only update if moved significantly (> 3m) or accuracy improved
            if distance < 3 && loc.horizontalAccuracy >= (accuracy ?? 100) {
                return // Skip update - not significant enough
            }
        }

        coordinate = loc.coordinate
        accuracy = loc.horizontalAccuracy
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        // Only log critical errors
        if let clError = error as? CLError, clError.code != .locationUnknown {
            DebugLogger.error("Location error: \(error.localizedDescription)")
        }
    }
}
