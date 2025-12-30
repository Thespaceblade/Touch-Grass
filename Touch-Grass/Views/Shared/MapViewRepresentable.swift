import SwiftUI
import MapKit

// MARK: - Obfuscation Bubble Overlay
// Use composition instead of subclassing to avoid MapKit serialization issues
// Store metadata separately and use regular MKCircle instances

struct ObfuscationBubbleMetadata {
    let playerId: String
    var pingStartTime: Date
}

// MARK: - CTF Halfway Line Overlay
// Note: We use MKPolyline directly for the halfway line instead of a custom class
// This avoids serialization issues with MapKit

// MARK: - CTF Side Tint Overlay
// Use composition instead of subclassing to avoid MapKit serialization issues
// Store metadata separately and use regular MKPolygon instances

struct CTFSideTintMetadata {
    let isRedSide: Bool
}

// MARK: - Safe Zone Circle Overlay
// Use composition instead of subclassing to avoid MapKit serialization issues
// Store metadata separately and use regular MKCircle instances

struct SafeZoneCircleMetadata {
    let team: Flag.Team
}

struct MapViewRepresentable: UIViewRepresentable {
    let userCoordinate: CLLocationCoordinate2D?
    let bubbleCenter: CLLocationCoordinate2D?
    let bubbleRadius: Double?
    let warningLevel: GameService.WarningLevel
    let players: [Player]
    let currentPlayerId: String?
    let currentPlayerRole: PlayerRole? // Add current player's role for obfuscation
    let gameType: GameType? // Game type to determine display rules
    
    // CTF-specific
    let flags: [Flag] // Flags for Capture The Flag
    let teamABase: CLLocationCoordinate2D? // Team A base location
    let teamBBase: CLLocationCoordinate2D? // Team B base location
    let teamASafeZone: GameSession.SafeZone? // Team A safe zone
    let teamBSafeZone: GameSession.SafeZone? // Team B safe zone
    
    // Radar ping obfuscation
    let isPingActive: Bool // Whether radar ping is currently active
    let zoneRadius: Double? // Zone radius for calculating bubble size
    
    @Binding var mapType: MKMapType
    @Binding var showPlayerLabels: Bool
    
    // Add trigger bindings for map actions
    @Binding var zoomToBubbleTrigger: Bool
    @Binding var centerOnPlayerTrigger: Bool
    
    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.showsUserLocation = true
        map.delegate = context.coordinator
        map.mapType = mapType
        map.showsCompass = true
        map.showsScale = true
        context.coordinator.mapView = map
        return map
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            warningLevel: warningLevel,
            showPlayerLabels: showPlayerLabels,
            currentPlayerId: currentPlayerId
        )
    }
    
    func updateUIView(_ map: MKMapView, context: Context) {
        // Store reference to map view
        context.coordinator.mapView = map
        
        // Update coordinator
        context.coordinator.warningLevel = warningLevel
        context.coordinator.showPlayerLabels = showPlayerLabels
        context.coordinator.userCoordinate = userCoordinate
        
        // Handle zoom triggers
        if zoomToBubbleTrigger {
            context.coordinator.zoomToBubble()
            Task { @MainActor in
                zoomToBubbleTrigger = false
            }
        }
        
        if centerOnPlayerTrigger {
            context.coordinator.centerOnPlayer()
            Task { @MainActor in
                centerOnPlayerTrigger = false
            }
        }
        
        // Update map type only if changed
        if map.mapType != mapType {
            map.mapType = mapType
        }
        
        // Optimized bubble update - only update if changed
        if let center = bubbleCenter, let radius = bubbleRadius, radius > 0 {
            // Only update bubble if center or radius changed significantly
            if context.coordinator.bubbleChanged(newCenter: center, newRadius: radius) {
                // Remove all circle overlays
                let circlesToRemove = map.overlays.filter { $0 is MKCircle }
                map.removeOverlays(circlesToRemove)
                
                // Disable user tracking
                map.userTrackingMode = .none
                
                // Add main bubble circle
                let circle = MKCircle(center: center, radius: radius)
                map.addOverlay(circle)
                
                // Add warning zone if needed
                if warningLevel != .none {
                    let warningRadius = radius * 0.2
                    let warningCircle = MKCircle(center: center, radius: warningRadius)
                    map.addOverlay(warningCircle)
                }
                
                // Only update region if bubble moved significantly (not on every update)
                let currentRegion = map.region
                let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    .distance(from: CLLocation(latitude: currentRegion.center.latitude, longitude: currentRegion.center.longitude))
                
                // Only update region if bubble center moved > 50m or radius changed significantly
                if distance > 50 || abs(radius - (context.coordinator.bubbleRadius ?? 0)) > 10 {
                    let region = MKCoordinateRegion(
                        center: center,
                        latitudinalMeters: max(radius * 3, 500),
                        longitudinalMeters: max(radius * 3, 500)
                    )
                    map.setRegion(region, animated: true)
                }
                
                // Update coordinator tracking
                context.coordinator.updateBubble(center: center, radius: radius)
            }
        } else {
            // No bubble - follow user location
            if userCoordinate != nil, map.userTrackingMode != .follow {
                map.userTrackingMode = .follow
            }
        }
        
        // CTF: Only show flag players on the map
        let playersToShow: [Player]
        if gameType == .captureTheFlag {
            playersToShow = players.filter { $0.isFlag }
        } else {
            playersToShow = players
        }
        
        // Optimized annotation update - only update if players changed or positions changed significantly
        let currentPlayerIds = Set(playersToShow.map { $0.id })
        let lastRenderedIds = context.coordinator.getLastRenderedPlayers()
        
        // Get current player's role for obfuscation
        let viewerRole = currentPlayerRole ?? .hider
        let viewerId = currentPlayerId ?? ""
        
        // Update coordinator with ping state
        context.coordinator.isPingActive = isPingActive
        context.coordinator.zoneRadius = zoneRadius
        
        // Check if ping state changed - need to update obfuscated players
        let pingStateChanged = context.coordinator.lastPingState != isPingActive
        
        // Always remove obfuscation bubbles when ping state changes
        if pingStateChanged {
            // Remove all circles that have obfuscation metadata (they're obfuscation bubbles)
            let existingBubbles = map.overlays.filter { overlay in
                if let circle = overlay as? MKCircle {
                    return context.coordinator.getObfuscationBubbleMetadata(for: circle) != nil
                }
                return false
            }
            // Clear metadata for removed bubbles
            for bubble in existingBubbles {
                context.coordinator.removeObfuscationBubbleMetadata(for: bubble)
            }
            map.removeOverlays(existingBubbles)
        }
        
        if currentPlayerIds != lastRenderedIds || pingStateChanged {
            // Players changed or ping state changed - update all annotations
            let existingAnnotations = map.annotations.filter { $0 is PlayerAnnotation }
            map.removeAnnotations(existingAnnotations)
            
            for player in playersToShow {
                // Validate player has valid ID and coordinates
                guard !player.id.isEmpty,
                      player.latitude.isFinite && player.longitude.isFinite,
                      player.latitude >= -90 && player.latitude <= 90,
                      player.longitude >= -180 && player.longitude <= 180 else {
                    // Skip invalid players (e.g., fake players with invalid data)
                    print("⚠️ Skipping invalid player: \(player.displayName) - ID: \(player.id.isEmpty ? "empty" : player.id), coords: (\(player.latitude), \(player.longitude))")
                    continue
                }
                
                // CTF: Flag players always show exact location (no obfuscation)
                let displayCoord: CLLocationCoordinate2D
                if gameType == .captureTheFlag && player.isFlag {
                    // Flag players always show exact location to everyone
                    displayCoord = player.coordinate
                } else {
                    displayCoord = player.obfuscatedCoordinate(for: viewerRole, viewerId: viewerId, isPingActive: isPingActive, zoneRadius: zoneRadius)
                }
                
                // Validate display coordinate before creating annotation
                guard displayCoord.latitude.isFinite && displayCoord.longitude.isFinite,
                      displayCoord.latitude >= -90 && displayCoord.latitude <= 90,
                      displayCoord.longitude >= -180 && displayCoord.longitude <= 180 else {
                    print("⚠️ Skipping player with invalid display coordinate: \(player.displayName)")
                    continue
                }
                
                let annotation = PlayerAnnotation(
                    player: player,
                    displayCoordinate: displayCoord
                )
                map.addAnnotation(annotation)
                
                // CTF: Flag players never get obfuscation bubbles - they're always visible
                // Add obfuscation bubble if ping is active and player should be obfuscated
                if gameType != .captureTheFlag || !player.isFlag {
                    let shouldObfuscate = (viewerRole == .hunter && player.role == .hider) ||
                                         (viewerRole == .hider && player.role == .hunter) ||
                                         (viewerRole == .zombie && player.role == .human) ||
                                         (viewerRole == .human && player.role == .zombie)
                    
                    if isPingActive && shouldObfuscate && viewerId != player.id {
                        // Validate coordinates before creating bubble
                        guard displayCoord.latitude.isFinite && displayCoord.longitude.isFinite,
                              displayCoord.latitude >= -90 && displayCoord.latitude <= 90,
                              displayCoord.longitude >= -180 && displayCoord.longitude <= 180 else {
                            // Skip invalid coordinates (e.g., from fake players without proper location)
                            print("⚠️ Skipping obfuscation bubble for player \(player.id) - invalid display coordinates")
                            continue
                        }
                        let bubbleRadius = player.obfuscationBubbleRadius(zoneRadius: zoneRadius)
                        guard bubbleRadius.isFinite && bubbleRadius > 0 && bubbleRadius < 100000 else {
                            print("⚠️ Skipping obfuscation bubble for player \(player.id) - invalid radius: \(bubbleRadius)")
                            continue
                        }
                        
                        // Create regular MKCircle (not subclass) to avoid MapKit serialization issues
                        let bubble = MKCircle(center: displayCoord, radius: bubbleRadius)
                        
                        // Store metadata separately
                        let metadata = ObfuscationBubbleMetadata(
                            playerId: player.id,
                            pingStartTime: Date()
                        )
                        context.coordinator.setObfuscationBubbleMetadata(for: bubble, metadata: metadata)
                        
                        // Add overlay
                        map.addOverlay(bubble)
                    }
                }
            }
            
            context.coordinator.setLastRenderedPlayers(currentPlayerIds)
            context.coordinator.lastPingState = isPingActive
        } else {
            // Players haven't changed - check if positions need updating
            // Optimized: Only update if coordinate changed significantly (> 15m) to reduce churn
            var needsUpdate = false
            
            for annotation in map.annotations.compactMap({ $0 as? PlayerAnnotation }) {
                if let player = playersToShow.first(where: { $0.id == annotation.player.id }) {
                    // Validate player data
                    guard !player.id.isEmpty,
                          player.latitude.isFinite && player.longitude.isFinite,
                          player.latitude >= -90 && player.latitude <= 90,
                          player.longitude >= -180 && player.longitude <= 180 else {
                        // Remove invalid player annotation
                        map.removeAnnotation(annotation)
                        continue
                    }
                    
                    // CTF: Flag players always show exact location (no obfuscation)
                    let newDisplayCoord: CLLocationCoordinate2D
                    if gameType == .captureTheFlag && player.isFlag {
                        // Flag players always show exact location to everyone
                        newDisplayCoord = player.coordinate
                    } else {
                        newDisplayCoord = player.obfuscatedCoordinate(for: viewerRole, viewerId: viewerId, isPingActive: isPingActive, zoneRadius: zoneRadius)
                    }
                    
                    // Validate display coordinate
                    guard newDisplayCoord.latitude.isFinite && newDisplayCoord.longitude.isFinite,
                          newDisplayCoord.latitude >= -90 && newDisplayCoord.latitude <= 90,
                          newDisplayCoord.longitude >= -180 && newDisplayCoord.longitude <= 180 else {
                        continue
                    }
                    
                    let distance = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
                        .distance(from: CLLocation(latitude: newDisplayCoord.latitude, longitude: newDisplayCoord.longitude))
                    
                    if distance > 15 {
                        needsUpdate = true
                        annotation.coordinate = newDisplayCoord
                        annotation.player = player
                    }
                }
            }
            
            // If significant changes, trigger map update
            if needsUpdate {
                // Force map to refresh annotations by removing and re-adding
                // But only do this if changes are significant to avoid constant updates
                let existingAnnotations = map.annotations.filter { $0 is PlayerAnnotation }
                let annotations = existingAnnotations.compactMap { $0 as? PlayerAnnotation }
                map.removeAnnotations(existingAnnotations)
                
                // Re-add with updated coordinates
                for annotation in annotations {
                    map.addAnnotation(annotation)
                }
            }
        }
        
        // Update flags and bases (CTF)
        updateFlagsAndBases(map: map, context: context)
    }
    
    private func updateFlagsAndBases(map: MKMapView, context: Context) {
        // Remove existing flag and base annotations
        let existingFlagAnnotations = map.annotations.filter { $0 is FlagAnnotation }
        let existingBaseAnnotations = map.annotations.filter { $0 is BaseAnnotation }
        map.removeAnnotations(existingFlagAnnotations + existingBaseAnnotations)
        
        // Remove existing CTF overlays (halfway line, side tints, and safe zones)
        // Note: Halfway line is now a regular MKPolyline, so we identify it by checking if it's a 2-point polyline
        // Remove CTF overlays (side tints, safe zones, halfway line)
        let existingCTFOverlays = map.overlays.filter { overlay in
            // Check if it's a CTF side tint (polygon with metadata)
            if overlay is MKPolygon, context.coordinator.getCTFSideTintMetadata(for: overlay) != nil {
                return true
            }
            // Check if it's a safe zone circle (circle with metadata)
            if overlay is MKCircle, context.coordinator.getSafeZoneCircleMetadata(for: overlay) != nil {
                return true
            }
            // Check if it's the halfway line (2-point polyline)
            if let polyline = overlay as? MKPolyline, polyline.pointCount == 2 {
                return true
            }
            return false
        }
        // Clear metadata for removed overlays
        for overlay in existingCTFOverlays {
            context.coordinator.removeCTFSideTintMetadata(for: overlay)
            context.coordinator.removeSafeZoneCircleMetadata(for: overlay)
        }
        map.removeOverlays(existingCTFOverlays)
        
        // Add flag annotations
        for flag in flags {
            let annotation = FlagAnnotation(flag: flag)
            map.addAnnotation(annotation)
        }
        
        // Add base annotations
        if let teamABase = teamABase, let teamBBase = teamBBase, let bubbleCenter = bubbleCenter, let bubbleRadius = bubbleRadius {
            let annotationA = BaseAnnotation(team: .teamA, coordinate: teamABase)
            map.addAnnotation(annotationA)
            
            let annotationB = BaseAnnotation(team: .teamB, coordinate: teamBBase)
            map.addAnnotation(annotationB)
            
            // Add CTF halfway line (from Team A base to Team B base)
            let coordinates = [teamABase, teamBBase]
            let halfwayPolyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            map.addOverlay(halfwayPolyline)
            
            // Calculate perpendicular line for side tints
            // Get bearing from Team A to Team B
            let teamALoc = CLLocation(latitude: teamABase.latitude, longitude: teamABase.longitude)
            let teamBLoc = CLLocation(latitude: teamBBase.latitude, longitude: teamBBase.longitude)
            let bearing = teamALoc.bearing(to: teamBLoc)
            let perpendicularBearing = (bearing + 90).truncatingRemainder(dividingBy: 360)
            
            // Calculate midpoint
            let midLat = (teamABase.latitude + teamBBase.latitude) / 2
            let midLon = (teamABase.longitude + teamBBase.longitude) / 2
            let midpoint = CLLocationCoordinate2D(latitude: midLat, longitude: midLon)
            
            // Create polygon points for each side
            // Calculate points at bubble edge along perpendicular line
            let _ = bubbleRadius * 1.5 // Extend beyond bubble (for future use)
            let _ = perpendicularBearing * .pi / 180.0 // Radians (for future use)
            
            // Red side (Team B side) - points
            let redSidePoints = createSidePolygon(
                center: bubbleCenter,
                radius: bubbleRadius,
                midpoint: midpoint,
                perpendicularBearing: perpendicularBearing,
                isRedSide: true
            )
            if redSidePoints.count >= 3 {
                // Create regular MKPolygon (not subclass) to avoid MapKit serialization issues
                let redTint = MKPolygon(coordinates: redSidePoints, count: redSidePoints.count)
                // Store metadata separately
                let metadata = CTFSideTintMetadata(isRedSide: true)
                context.coordinator.setCTFSideTintMetadata(for: redTint, metadata: metadata)
                map.addOverlay(redTint)
            }
            
            // Blue side (Team A side) - points
            let blueSidePoints = createSidePolygon(
                center: bubbleCenter,
                radius: bubbleRadius,
                midpoint: midpoint,
                perpendicularBearing: perpendicularBearing,
                isRedSide: false
            )
            if blueSidePoints.count >= 3 {
                // Create regular MKPolygon (not subclass) to avoid MapKit serialization issues
                let blueTint = MKPolygon(coordinates: blueSidePoints, count: blueSidePoints.count)
                // Store metadata separately
                let metadata = CTFSideTintMetadata(isRedSide: false)
                context.coordinator.setCTFSideTintMetadata(for: blueTint, metadata: metadata)
                map.addOverlay(blueTint)
            }
        } else {
            // Fallback: add base annotations even if we can't create overlays
            if let teamABase = teamABase {
                let annotation = BaseAnnotation(team: .teamA, coordinate: teamABase)
                map.addAnnotation(annotation)
            }
            
            if let teamBBase = teamBBase {
                let annotation = BaseAnnotation(team: .teamB, coordinate: teamBBase)
                map.addAnnotation(annotation)
            }
        }
        
        // Add safe zone overlays
        if let teamASafeZone = teamASafeZone {
            // Create regular MKCircle (not subclass) to avoid MapKit serialization issues
            let safeZoneCircle = MKCircle(center: teamASafeZone.center, radius: teamASafeZone.radius)
            // Store metadata separately
            let metadata = SafeZoneCircleMetadata(team: .teamA)
            context.coordinator.setSafeZoneCircleMetadata(for: safeZoneCircle, metadata: metadata)
            map.addOverlay(safeZoneCircle)
        }
        
        if let teamBSafeZone = teamBSafeZone {
            // Create regular MKCircle (not subclass) to avoid MapKit serialization issues
            let safeZoneCircle = MKCircle(center: teamBSafeZone.center, radius: teamBSafeZone.radius)
            // Store metadata separately
            let metadata = SafeZoneCircleMetadata(team: .teamB)
            context.coordinator.setSafeZoneCircleMetadata(for: safeZoneCircle, metadata: metadata)
            map.addOverlay(safeZoneCircle)
        }
    }
    
    // Helper function to create polygon points for side tint
    private func createSidePolygon(center: CLLocationCoordinate2D, radius: Double, midpoint: CLLocationCoordinate2D, perpendicularBearing: Double, isRedSide: Bool) -> [CLLocationCoordinate2D] {
        // Create a polygon that covers half the bubble
        // Calculate perpendicular direction (line from Team A to Team B)
        let lineBearing = perpendicularBearing * .pi / 180.0
        let direction: Double = isRedSide ? 1.0 : -1.0
        
        var points: [CLLocationCoordinate2D] = []
        
        // Calculate the perpendicular angle (90 degrees from line)
        let perpAngle = lineBearing + (.pi / 2) * direction
        
        // Create points along the bubble edge on one side
        // Start from -90 degrees to +90 degrees relative to perpendicular
        let numPoints = 16 // More points for smoother curve
        let piOverNumPoints = Double.pi / Double(numPoints)
        let halfPi = Double.pi / 2.0
        let radiusOverMeters = radius / 111000.0
        let centerLatRadians = center.latitude * Double.pi / 180.0
        let radiusOverMetersLon = radius / (111000.0 * cos(centerLatRadians))
        
        for i in 0...numPoints {
            let iDouble = Double(i)
            let angleOffset = (piOverNumPoints * iDouble) - halfPi // -90 to +90 degrees
            let angle = perpAngle + angleOffset
            
            let lat = center.latitude + radiusOverMeters * cos(angle)
            let lon = center.longitude + radiusOverMetersLon * sin(angle)
            points.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        // Add center point to close the polygon
        points.append(center)
        
        return points
    }
    
    final class Coordinator: NSObject, MKMapViewDelegate {
        var warningLevel: GameService.WarningLevel
        var showPlayerLabels: Bool
        let currentPlayerId: String?
        weak var mapView: MKMapView?
        
        var bubbleCenter: CLLocationCoordinate2D?
        var bubbleRadius: Double?
        var userCoordinate: CLLocationCoordinate2D?
        
        // Radar ping obfuscation state
        var isPingActive: Bool = false
        var zoneRadius: Double?
        var lastPingState: Bool = false
        var gameStartTime: Date? // Track when game started to add delay before creating bubbles
        
        // Store obfuscation bubble metadata separately (composition instead of subclassing)
        // Maps MKCircle overlay to its metadata (playerId, pingStartTime)
        private var obfuscationBubbleMetadata: [ObjectIdentifier: ObfuscationBubbleMetadata] = [:]
        private var ctfSideTintMetadata: [ObjectIdentifier: CTFSideTintMetadata] = [:]
        private var safeZoneCircleMetadata: [ObjectIdentifier: SafeZoneCircleMetadata] = [:]
        
        // Add tracking for what was last rendered
        private var lastRenderedPlayers: Set<String> = []
        private var lastBubbleCenter: CLLocationCoordinate2D?
        private var lastBubbleRadius: Double?
        
        func getObfuscationBubbleMetadata(for overlay: MKOverlay) -> ObfuscationBubbleMetadata? {
            return obfuscationBubbleMetadata[ObjectIdentifier(overlay)]
        }
        
        func setObfuscationBubbleMetadata(for overlay: MKOverlay, metadata: ObfuscationBubbleMetadata) {
            obfuscationBubbleMetadata[ObjectIdentifier(overlay)] = metadata
        }
        
        func removeObfuscationBubbleMetadata(for overlay: MKOverlay) {
            obfuscationBubbleMetadata.removeValue(forKey: ObjectIdentifier(overlay))
        }
        
        func clearAllObfuscationBubbleMetadata() {
            obfuscationBubbleMetadata.removeAll()
        }
        
        func getCTFSideTintMetadata(for overlay: MKOverlay) -> CTFSideTintMetadata? {
            return ctfSideTintMetadata[ObjectIdentifier(overlay)]
        }
        
        func setCTFSideTintMetadata(for overlay: MKOverlay, metadata: CTFSideTintMetadata) {
            ctfSideTintMetadata[ObjectIdentifier(overlay)] = metadata
        }
        
        func removeCTFSideTintMetadata(for overlay: MKOverlay) {
            ctfSideTintMetadata.removeValue(forKey: ObjectIdentifier(overlay))
        }
        
        func getSafeZoneCircleMetadata(for overlay: MKOverlay) -> SafeZoneCircleMetadata? {
            return safeZoneCircleMetadata[ObjectIdentifier(overlay)]
        }
        
        func setSafeZoneCircleMetadata(for overlay: MKOverlay, metadata: SafeZoneCircleMetadata) {
            safeZoneCircleMetadata[ObjectIdentifier(overlay)] = metadata
        }
        
        func removeSafeZoneCircleMetadata(for overlay: MKOverlay) {
            safeZoneCircleMetadata.removeValue(forKey: ObjectIdentifier(overlay))
        }
        
        // Cache for decoded profile pictures to avoid re-decoding base64
        private var imageCache: [String: UIImage] = [:]
        
        // Radar ping animation timer
        private var pingAnimationTimer: Timer?
        
        init(warningLevel: GameService.WarningLevel, showPlayerLabels: Bool, currentPlayerId: String?) {
            self.warningLevel = warningLevel
            self.showPlayerLabels = showPlayerLabels
            self.currentPlayerId = currentPlayerId
        }
        
        // MARK: - Map Control Functions
        
        func zoomToBubble() {
            guard let mapView = mapView,
                  let center = bubbleCenter,
                  let radius = bubbleRadius else { return }
            let region = MKCoordinateRegion(
                center: center,
                latitudinalMeters: max(radius * 3, 500),
                longitudinalMeters: max(radius * 3, 500)
            )
            mapView.setRegion(region, animated: true)
        }
        
        func centerOnPlayer() {
            guard let mapView = mapView,
                  let coordinate = userCoordinate else { return }
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 500,
                longitudinalMeters: 500
            )
            mapView.setRegion(region, animated: true)
        }
        
        // MARK: - Bubble Tracking Helpers
        
        func bubbleChanged(newCenter: CLLocationCoordinate2D?, newRadius: Double?) -> Bool {
            // Compare coordinates using distance
            if let oldCenter = lastBubbleCenter, let newCenter = newCenter {
                let distance = CLLocation(latitude: oldCenter.latitude, longitude: oldCenter.longitude)
                    .distance(from: CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude))
                // INCREASE threshold to reduce updates (1.0 → 5.0 meters)
                if distance > 5.0 {
                    return true
                }
            } else if lastBubbleCenter != nil || newCenter != nil {
                return true
            }
            
            // Compare radius - INCREASE threshold (1.0 → 2.0 meters)
            let radiusChanged = abs((lastBubbleRadius ?? 0) - (newRadius ?? 0)) > 2.0
            return radiusChanged
        }
        
        func updateBubble(center: CLLocationCoordinate2D?, radius: Double?) {
            lastBubbleCenter = center
            lastBubbleRadius = radius
            bubbleCenter = center
            bubbleRadius = radius
        }
        
        func getLastRenderedPlayers() -> Set<String> {
            return lastRenderedPlayers
        }
        
        func setLastRenderedPlayers(_ players: Set<String>) {
            lastRenderedPlayers = players
        }
        
        // MARK: - Overlay Rendering
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Handle safe zone circles (check if this circle has safe zone metadata)
            if let circle = overlay as? MKCircle,
               let metadata = getSafeZoneCircleMetadata(for: circle) {
                let renderer = MKCircleRenderer(circle: circle)
                let teamColor = metadata.team == .teamA ? UIColor.blue : UIColor.red
                renderer.fillColor = teamColor.withAlphaComponent(0.2)
                renderer.strokeColor = teamColor
                renderer.lineWidth = 3.0
                renderer.lineDashPattern = [5, 5] // Dashed border
                return renderer
            }
            // Handle obfuscation bubbles (radar ping) - check if this circle has obfuscation metadata
            if let circle = overlay as? MKCircle,
               let metadata = getObfuscationBubbleMetadata(for: circle) {
                // Comprehensive safety check: ensure the circle has valid properties
                guard circle.coordinate.latitude.isFinite && circle.coordinate.longitude.isFinite,
                      circle.coordinate.latitude >= -90 && circle.coordinate.latitude <= 90,
                      circle.coordinate.longitude >= -180 && circle.coordinate.longitude <= 180,
                      circle.radius.isFinite && circle.radius > 0 && circle.radius < 100000,
                      !metadata.playerId.isEmpty else {
                    // Return a default renderer for invalid bubbles to prevent crash
                    print("⚠️ Invalid obfuscation bubble properties in renderer, using default renderer")
                    return MKOverlayRenderer(overlay: overlay)
                }
                
                let renderer = MKCircleRenderer(circle: circle)
                
                // Calculate ping animation progress (0.0 to 1.0 over 10 seconds)
                let elapsed = Date().timeIntervalSince(metadata.pingStartTime)
                let pingDuration: TimeInterval = 10.0
                let progress = min(1.0, elapsed / pingDuration)
                
                // Radar ping effect: pulsing opacity and expanding ring
                // Outer ring expands from center, fading out
                let pulseOpacity = 1.0 - progress // Fade out over 10 seconds
                let _ = 1.0 + (progress * 0.3) // Expand slightly (for future use)
                
                // Color: orange/red for hunters, blue for hiders
                let isHunter = currentPlayerId != nil && 
                              (mapView.annotations.compactMap { $0 as? PlayerAnnotation }
                               .first(where: { $0.player.id == metadata.playerId })?.player.role == .hunter)
                
                let bubbleColor = isHunter ? UIColor.systemOrange : UIColor.systemBlue
                
                // Main bubble fill (semi-transparent)
                renderer.fillColor = bubbleColor.withAlphaComponent(0.15 * pulseOpacity)
                
                // Outer ring (expanding pulse effect)
                renderer.strokeColor = bubbleColor.withAlphaComponent(0.6 * pulseOpacity)
                renderer.lineWidth = 3.0
                renderer.lineDashPattern = [8, 4] // Dashed for radar effect
                
                // Animate the ping effect
                if progress < 1.0 {
                    // Schedule refresh for animation
                    // Note: circle is already MKCircle from the outer if-let binding
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak mapView, weak self] in
                        guard let mapView = mapView, let self = self,
                              self.getObfuscationBubbleMetadata(for: circle) != nil else {
                            return
                        }
                        // Force redraw
                        mapView.removeOverlay(circle)
                        mapView.addOverlay(circle)
                    }
                }
                
                return renderer
            }
            
            // Handle regular circles (game bubble, warning zones)
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                
                // Determine if this is warning zone or main bubble
                // Skip if this circle has obfuscation metadata (it's an obfuscation bubble, handled above)
                if getObfuscationBubbleMetadata(for: circle) != nil {
                    // This is an obfuscation bubble, should have been handled above
                    // Return a default renderer as fallback
                    return MKOverlayRenderer(overlay: overlay)
                }
                
                let circles = mapView.overlays.compactMap { $0 as? MKCircle }
                let allCircles = circles.filter { getObfuscationBubbleMetadata(for: $0) == nil } // Exclude obfuscation bubbles
                let mainCircle = allCircles.max(by: { $0.radius < $1.radius })
                let isWarningZone = circle.radius < (mainCircle?.radius ?? 0)
                
                if isWarningZone {
                    // Warning zone
                    renderer.strokeColor = warningColor
                    renderer.fillColor = warningColor.withAlphaComponent(0.1)
                    renderer.lineWidth = 2
                    renderer.lineDashPattern = [5, 5]
                } else {
                    // Main bubble - MAKE IT VERY VISIBLE
                    let color = bubbleColor
                    renderer.strokeColor = color
                    renderer.fillColor = color.withAlphaComponent(0.25) // Visible fill
                    renderer.lineWidth = 6 // Thicker line for visibility
                }
                
                return renderer
            }
            
            // Handle CTF halfway line (2-point polyline between team bases)
            if let polyline = overlay as? MKPolyline, polyline.pointCount == 2 {
                // Check if this is the halfway line by verifying it's between team bases
                // For now, render all 2-point polylines as halfway lines
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.white
                renderer.lineWidth = 4.0
                renderer.lineDashPattern = [10, 5] // Dashed line
                return renderer
            }
            
            // Handle CTF side tints (check if this polygon has side tint metadata)
            if let polygon = overlay as? MKPolygon,
               let metadata = getCTFSideTintMetadata(for: polygon) {
                let renderer = MKPolygonRenderer(polygon: polygon)
                if metadata.isRedSide {
                    renderer.fillColor = UIColor.red.withAlphaComponent(0.15) // Red tint
                    renderer.strokeColor = UIColor.red.withAlphaComponent(0.3)
                } else {
                    renderer.fillColor = UIColor.blue.withAlphaComponent(0.15) // Blue tint
                    renderer.strokeColor = UIColor.blue.withAlphaComponent(0.3)
                }
                renderer.lineWidth = 1.0
                return renderer
            }
            
            return MKOverlayRenderer()
        }
        // MARK: - Annotation Rendering
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // Skip user location annotation
            if annotation is MKUserLocation {
                return nil
            }
            
            // Handle flag annotations
            if let flagAnnotation = annotation as? FlagAnnotation {
                return configureFlagAnnotation(mapView: mapView, annotation: flagAnnotation)
            }
            
            // Handle base annotations
            if let baseAnnotation = annotation as? BaseAnnotation {
                return configureBaseAnnotation(mapView: mapView, annotation: baseAnnotation)
            }
            
            guard let playerAnnotation = annotation as? PlayerAnnotation else {
                return nil
            }
            
            let player = playerAnnotation.player
            let identifier = "PlayerAnnotation_\(player.id)"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            // Clear existing subviews FIRST to prevent accumulation
            annotationView?.subviews.forEach { $0.removeFromSuperview() }
            
            // Configure annotation view (safely unwrap)
            guard let safeAnnotationView = annotationView else {
                return annotationView
            }
            configurePlayerAnnotation(safeAnnotationView, for: player)
            
            return annotationView
        }
        
        private func configureFlagAnnotation(mapView: MKMapView, annotation: FlagAnnotation) -> MKAnnotationView {
            let identifier = "FlagAnnotation_\(annotation.flag.id)"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            let flag = annotation.flag
            let isCarried = flag.carrierId != nil
            // Team A = Blue, Team B = Red
            let teamColor = flag.team == .teamA ? UIColor.blue : UIColor.red
            
            // Create flag icon
            let flagSize: CGFloat = isCarried ? 30 : 40
            let flagView = UIView(frame: CGRect(x: 0, y: 0, width: flagSize, height: flagSize))
            flagView.backgroundColor = .clear
            
            // Flag icon using SF Symbol
            let flagImage = UIImage(systemName: "flag.fill")?
                .withTintColor(teamColor, renderingMode: .alwaysOriginal)
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: flagSize * 0.8, weight: .bold))
            
            let imageView = UIImageView(image: flagImage)
            imageView.frame = flagView.bounds
            imageView.contentMode = .scaleAspectFit
            flagView.addSubview(imageView)
            
            // Add pulsing effect if at base
            if !isCarried && flag.isAtBase {
                let pulseLayer = CALayer()
                pulseLayer.frame = flagView.bounds.insetBy(dx: -10, dy: -10)
                pulseLayer.cornerRadius = pulseLayer.frame.width / 2
                pulseLayer.backgroundColor = teamColor.withAlphaComponent(0.3).cgColor
                flagView.layer.insertSublayer(pulseLayer, at: 0)
                
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.3
                pulseAnimation.duration = 1.5
                pulseAnimation.repeatCount = .greatestFiniteMagnitude
                pulseAnimation.autoreverses = true
                pulseLayer.add(pulseAnimation, forKey: "pulse")
            }
            
            annotationView?.frame = flagView.bounds
            annotationView?.addSubview(flagView)
            annotationView?.centerOffset = CGPoint(x: 0, y: -flagSize / 2)
            
            return annotationView ?? MKAnnotationView()
        }
        
        private func configureBaseAnnotation(mapView: MKMapView, annotation: BaseAnnotation) -> MKAnnotationView {
            let identifier = "BaseAnnotation_\(annotation.team.rawValue)"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            let teamColor = annotation.team == .teamA ? UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0) : UIColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1.0)
            
            // Create base circle
            let baseSize: CGFloat = 50
            let baseView = UIView(frame: CGRect(x: 0, y: 0, width: baseSize, height: baseSize))
            baseView.backgroundColor = teamColor.withAlphaComponent(0.2)
            baseView.layer.cornerRadius = baseSize / 2
            baseView.layer.borderWidth = 3
            baseView.layer.borderColor = teamColor.cgColor
            
            // Add team letter
            let label = UILabel(frame: baseView.bounds)
            label.text = annotation.team == .teamA ? "A" : "B"
            label.textColor = teamColor
            label.font = .systemFont(ofSize: 24, weight: .bold)
            label.textAlignment = .center
            baseView.addSubview(label)
            
            annotationView?.frame = baseView.bounds
            annotationView?.addSubview(baseView)
            annotationView?.centerOffset = CGPoint(x: 0, y: -baseSize / 2)
            
            return annotationView ?? MKAnnotationView()
        }
        
        private func configurePlayerAnnotation(_ view: MKAnnotationView, for player: Player) {
            // Determine if this is current player
            let isCurrentPlayer = player.id == currentPlayerId
            
            // Determine if this location is obfuscated
            // Check if the displayed coordinate differs significantly from actual coordinate
            let actualCoord = player.coordinate
            let displayedCoord = (view.annotation as? PlayerAnnotation)?.coordinate ?? actualCoord
            let distance = CLLocation(latitude: actualCoord.latitude, longitude: actualCoord.longitude)
                .distance(from: CLLocation(latitude: displayedCoord.latitude, longitude: displayedCoord.longitude))
            let isObfuscated = distance > 10.0 // If more than 10m difference, it's obfuscated
            
            // Size based on role and status
            let size: CGFloat = isCurrentPlayer ? 40 : 32
            view.frame = CGRect(x: 0, y: 0, width: size, height: size)
            
            // Create custom view
            let containerView = UIView(frame: view.bounds)
            containerView.backgroundColor = .clear
            
            // Load profile picture if available (from base64)
            if let profilePictureBase64 = player.profilePictureBase64 {
                loadProfilePicture(for: view, base64String: profilePictureBase64, player: player, size: size, isCurrentPlayer: isCurrentPlayer, isObfuscated: isObfuscated)
                return
            }
            
            // Fallback to default icon view
            configureDefaultAnnotation(containerView: containerView, player: player, size: size, isCurrentPlayer: isCurrentPlayer, isObfuscated: isObfuscated)
            view.addSubview(containerView)
        }
        
        private func loadProfilePicture(for view: MKAnnotationView, base64String: String, player: Player, size: CGFloat, isCurrentPlayer: Bool, isObfuscated: Bool) {
            // Check cache first to avoid re-decoding
            let cacheKey = "\(player.id)_\(base64String.prefix(20))" // Use player ID + first 20 chars of base64 as key
            
            if let cachedImage = imageCache[cacheKey] {
                configureProfilePictureAnnotation(view: view, image: cachedImage, player: player, size: size, isCurrentPlayer: isCurrentPlayer, isObfuscated: isObfuscated)
                return
            }
            
            // Decode base64 image
            guard let imageData = Data(base64Encoded: base64String),
                  let image = UIImage(data: imageData) else {
                // Fallback to default if image fails to decode
                let containerView = UIView(frame: view.bounds)
                configureDefaultAnnotation(containerView: containerView, player: player, size: size, isCurrentPlayer: isCurrentPlayer, isObfuscated: isObfuscated)
                view.addSubview(containerView)
                return
            }
            
            // Cache the decoded image (limit cache size to prevent memory issues)
            if imageCache.count >= 12 { // Max 12 cached images (one per player)
                // Remove oldest entry (simple FIFO - remove first)
                if let firstKey = imageCache.keys.first {
                    imageCache.removeValue(forKey: firstKey)
                }
            }
            imageCache[cacheKey] = image
            
            configureProfilePictureAnnotation(view: view, image: image, player: player, size: size, isCurrentPlayer: isCurrentPlayer, isObfuscated: isObfuscated)
        }
        
        private func configureProfilePictureAnnotation(view: MKAnnotationView, image: UIImage?, player: Player, size: CGFloat, isCurrentPlayer: Bool, isObfuscated: Bool) {
            // Clear existing subviews
            view.subviews.forEach { $0.removeFromSuperview() }
            
            let containerView = UIView(frame: view.bounds)
            containerView.backgroundColor = .clear
            
            // Outer circle (role color border)
            let outerCircle = UIView(frame: containerView.bounds)
            outerCircle.backgroundColor = .clear
            outerCircle.layer.cornerRadius = size / 2
            outerCircle.layer.borderWidth = 3
            outerCircle.layer.borderColor = roleColor(for: player.role).cgColor
            
            // Add dashed border for obfuscated locations
            if isObfuscated {
                let dashedBorder = CAShapeLayer()
                dashedBorder.strokeColor = roleColor(for: player.role).cgColor
                dashedBorder.fillColor = UIColor.clear.cgColor
                dashedBorder.lineWidth = 3
                dashedBorder.lineDashPattern = [5, 5]
                dashedBorder.path = UIBezierPath(arcCenter: CGPoint(x: size/2, y: size/2),
                                                 radius: size/2 - 1.5,
                                                 startAngle: 0,
                                                 endAngle: .pi * 2,
                                                 clockwise: true).cgPath
                outerCircle.layer.addSublayer(dashedBorder)
                // Make the solid border more transparent
                outerCircle.layer.borderColor = roleColor(for: player.role).withAlphaComponent(0.5).cgColor
            }
            
            // Add pulsing animation for current player - remove old animation first
            outerCircle.layer.removeAnimation(forKey: "pulse")
            if isCurrentPlayer {
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.2
                pulseAnimation.duration = 1.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                outerCircle.layer.add(pulseAnimation, forKey: "pulse")
            }
            
            containerView.addSubview(outerCircle)
            
            // Profile picture or default icon
            let imageSize = size - 8
            let imageView = UIImageView(frame: CGRect(
                x: 4,
                y: 4,
                width: imageSize,
                height: imageSize
            ))
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = imageSize / 2
            
            if let image = image {
                imageView.image = image
            } else {
                // Fallback to default icon
                imageView.backgroundColor = player.isAlive ? roleColor(for: player.role) : UIColor.gray
                let iconLabel = UILabel(frame: imageView.bounds)
                iconLabel.textAlignment = .center
                iconLabel.textColor = .white
                iconLabel.font = .systemFont(ofSize: imageSize * 0.4, weight: .bold)
                iconLabel.text = !player.isAlive ? "✕" : (player.role == .hunter ? "🔍" : "👤")
                imageView.addSubview(iconLabel)
            }
            
            // Add gray overlay if eliminated
            if !player.isAlive {
                let overlay = UIView(frame: imageView.bounds)
                overlay.backgroundColor = UIColor.black.withAlphaComponent(0.5)
                overlay.layer.cornerRadius = imageSize / 2
                imageView.addSubview(overlay)
            }
            
            containerView.addSubview(imageView)
            
            // Add "bubble" indicator for obfuscated locations
            if isObfuscated && player.isAlive {
                let bubbleCircle = UIView(frame: CGRect(x: -10, y: -10, width: size + 20, height: size + 20))
                bubbleCircle.backgroundColor = .clear
                bubbleCircle.layer.cornerRadius = (size + 20) / 2
                bubbleCircle.layer.borderWidth = 2
                bubbleCircle.layer.borderColor = roleColor(for: player.role).withAlphaComponent(0.4).cgColor
                
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.3
                pulseAnimation.duration = 2.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                bubbleCircle.layer.add(pulseAnimation, forKey: "bubblePulse")
                
                let fadeAnimation = CABasicAnimation(keyPath: "opacity")
                fadeAnimation.fromValue = 0.6
                fadeAnimation.toValue = 0.2
                fadeAnimation.duration = 2.0
                fadeAnimation.repeatCount = .infinity
                fadeAnimation.autoreverses = true
                bubbleCircle.layer.add(fadeAnimation, forKey: "bubbleFade")
                
                containerView.addSubview(bubbleCircle)
            }
            
            // Add flag icon for flag players (CTF)
            if player.isFlag && player.isAlive {
                let flagSize: CGFloat = size * 0.4
                let flagView = UIImageView(frame: CGRect(
                    x: size - flagSize - 2,
                    y: -2,
                    width: flagSize,
                    height: flagSize
                ))
                flagView.contentMode = .scaleAspectFit
                // Team A = Blue, Team B = Red
                let flagColor = player.role == .teamA ? UIColor.blue : UIColor.red
                flagView.image = UIImage(systemName: "flag.fill")?.withTintColor(flagColor, renderingMode: .alwaysOriginal)
                flagView.backgroundColor = UIColor.white
                flagView.layer.cornerRadius = flagSize / 2
                flagView.layer.borderWidth = 1.5
                flagView.layer.borderColor = flagColor.cgColor
                
                // Add pulsing animation for flag
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.2
                pulseAnimation.duration = 1.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                flagView.layer.add(pulseAnimation, forKey: "flagPulse")
                
                containerView.addSubview(flagView)
            }
            
            view.addSubview(containerView)
        }
        
        private func configureDefaultAnnotation(containerView: UIView, player: Player, size: CGFloat, isCurrentPlayer: Bool, isObfuscated: Bool) {
            // Role-specific shape: Diamond for hunters, Circle for hiders
            let isHunter = player.role == .hunter
            let shapeView = UIView(frame: containerView.bounds)
            
            if isHunter {
                // Diamond shape for hunters
                let diamondPath = UIBezierPath()
                let center = CGPoint(x: size / 2, y: size / 2)
                let radius = size / 2 - 1.5
                diamondPath.move(to: CGPoint(x: center.x, y: center.y - radius))
                diamondPath.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                diamondPath.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                diamondPath.addLine(to: CGPoint(x: center.x - radius, y: center.y))
                diamondPath.close()
                
                let shapeLayer = CAShapeLayer()
                shapeLayer.path = diamondPath.cgPath
                shapeLayer.fillColor = roleColor(for: player.role).withAlphaComponent(0.3).cgColor
                shapeLayer.strokeColor = roleColor(for: player.role).cgColor
                shapeLayer.lineWidth = 3
                shapeView.layer.addSublayer(shapeLayer)
            } else {
                // Circle shape for hiders
                shapeView.backgroundColor = roleColor(for: player.role).withAlphaComponent(0.3)
                shapeView.layer.cornerRadius = size / 2
                shapeView.layer.borderWidth = 3
                shapeView.layer.borderColor = roleColor(for: player.role).cgColor
            }
            
            let outerCircle = shapeView
            
            // Add dashed border for obfuscated locations
            if isObfuscated {
                let dashedBorder = CAShapeLayer()
                dashedBorder.strokeColor = roleColor(for: player.role).cgColor
                dashedBorder.fillColor = UIColor.clear.cgColor
                dashedBorder.lineWidth = 3
                dashedBorder.lineDashPattern = [5, 5]
                dashedBorder.path = UIBezierPath(arcCenter: CGPoint(x: size/2, y: size/2),
                                                 radius: size/2 - 1.5,
                                                 startAngle: 0,
                                                 endAngle: .pi * 2,
                                                 clockwise: true).cgPath
                outerCircle.layer.addSublayer(dashedBorder)
                outerCircle.layer.borderColor = roleColor(for: player.role).withAlphaComponent(0.5).cgColor
            }
            
            containerView.addSubview(outerCircle)
            
            // Add flag icon for flag players (CTF) - before inner shape so it appears on top
            if player.isFlag && player.isAlive {
                let flagSize: CGFloat = size * 0.4
                let flagView = UIImageView(frame: CGRect(
                    x: size - flagSize - 2,
                    y: -2,
                    width: flagSize,
                    height: flagSize
                ))
                flagView.contentMode = .scaleAspectFit
                // Team A = Blue, Team B = Red
                let flagColor = player.role == .teamA ? UIColor.blue : UIColor.red
                flagView.image = UIImage(systemName: "flag.fill")?.withTintColor(flagColor, renderingMode: .alwaysOriginal)
                flagView.backgroundColor = UIColor.white
                flagView.layer.cornerRadius = flagSize / 2
                flagView.layer.borderWidth = 1.5
                flagView.layer.borderColor = flagColor.cgColor
                
                // Add pulsing animation for flag
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.2
                pulseAnimation.duration = 1.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                flagView.layer.add(pulseAnimation, forKey: "flagPulse")
                
                containerView.addSubview(flagView)
            }
            
            // Inner shape (status) - match outer shape
            let innerSize = size - 8
            let innerShape = UIView(frame: CGRect(
                x: 4,
                y: 4,
                width: innerSize,
                height: innerSize
            ))
            
            if isHunter {
                // Diamond shape for hunters
                let diamondPath = UIBezierPath()
                let center = CGPoint(x: innerSize / 2, y: innerSize / 2)
                let radius = innerSize / 2 - 1
                diamondPath.move(to: CGPoint(x: center.x, y: center.y - radius))
                diamondPath.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                diamondPath.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                diamondPath.addLine(to: CGPoint(x: center.x - radius, y: center.y))
                diamondPath.close()
                
                let shapeLayer = CAShapeLayer()
                shapeLayer.path = diamondPath.cgPath
                shapeLayer.fillColor = (player.isAlive ? roleColor(for: player.role) : UIColor.gray).cgColor
                innerShape.layer.addSublayer(shapeLayer)
            } else {
                // Circle shape for hiders
                innerShape.backgroundColor = player.isAlive
                    ? roleColor(for: player.role)
                    : UIColor.gray
                innerShape.layer.cornerRadius = innerSize / 2
            }
            
            let innerCircle = innerShape
            
            // Add icon
            let iconLabel = UILabel(frame: innerCircle.bounds)
            iconLabel.textAlignment = .center
            iconLabel.textColor = .white
            iconLabel.font = .systemFont(ofSize: innerSize * 0.4, weight: .bold)
            
            if !player.isAlive {
                iconLabel.text = "✕"
            } else {
                iconLabel.text = player.role == .hunter ? "🔍" : "👤"
            }
            
            innerCircle.addSubview(iconLabel)
            containerView.addSubview(innerCircle)
            
            // Add flag icon for flag players (CTF)
            if player.isFlag && player.isAlive {
                let flagSize: CGFloat = size * 0.4
                let flagView = UIImageView(frame: CGRect(
                    x: size - flagSize - 2,
                    y: -2,
                    width: flagSize,
                    height: flagSize
                ))
                flagView.contentMode = .scaleAspectFit
                // Team A = Blue, Team B = Red
                let flagColor = player.role == .teamA ? UIColor.blue : UIColor.red
                flagView.image = UIImage(systemName: "flag.fill")?.withTintColor(flagColor, renderingMode: .alwaysOriginal)
                flagView.backgroundColor = UIColor.white
                flagView.layer.cornerRadius = flagSize / 2
                flagView.layer.borderWidth = 1.5
                flagView.layer.borderColor = flagColor.cgColor
                
                // Add pulsing animation for flag
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.2
                pulseAnimation.duration = 1.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                flagView.layer.add(pulseAnimation, forKey: "flagPulse")
                
                containerView.addSubview(flagView)
            }
            
            // Add "bubble" indicator for obfuscated locations
            if isObfuscated && player.isAlive {
                // Add a pulsing circle around the annotation to indicate approximate location
                let bubbleCircle = UIView(frame: CGRect(x: -10, y: -10, width: size + 20, height: size + 20))
                bubbleCircle.backgroundColor = .clear
                bubbleCircle.layer.cornerRadius = (size + 20) / 2
                bubbleCircle.layer.borderWidth = 2
                bubbleCircle.layer.borderColor = roleColor(for: player.role).withAlphaComponent(0.4).cgColor
                
                // Pulsing animation for bubble
                let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                pulseAnimation.fromValue = 1.0
                pulseAnimation.toValue = 1.3
                pulseAnimation.duration = 2.0
                pulseAnimation.repeatCount = .infinity
                pulseAnimation.autoreverses = true
                bubbleCircle.layer.add(pulseAnimation, forKey: "bubblePulse")
                
                // Fade animation
                let fadeAnimation = CABasicAnimation(keyPath: "opacity")
                fadeAnimation.fromValue = 0.6
                fadeAnimation.toValue = 0.2
                fadeAnimation.duration = 2.0
                fadeAnimation.repeatCount = .infinity
                fadeAnimation.autoreverses = true
                bubbleCircle.layer.add(fadeAnimation, forKey: "bubbleFade")
                
                containerView.insertSubview(bubbleCircle, at: 0)
            }
            
            // Player name label (if enabled)
            if showPlayerLabels && player.isAlive {
                let maxWidth: CGFloat = 120 // Maximum width for name label
                let nameLabel = UILabel(frame: CGRect(x: 0, y: size + 4, width: maxWidth, height: 16))
                // Add "~" prefix for obfuscated locations
                let displayName = isObfuscated ? "~\(player.displayName)" : player.displayName
                nameLabel.text = displayName
                nameLabel.font = .systemFont(ofSize: 10, weight: .medium)
                nameLabel.textColor = roleColor(for: player.role)
                nameLabel.textAlignment = .center
                nameLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
                nameLabel.layer.cornerRadius = 4
                nameLabel.clipsToBounds = true
                nameLabel.adjustsFontSizeToFitWidth = true
                nameLabel.minimumScaleFactor = 0.7
                nameLabel.numberOfLines = 1
                nameLabel.sizeToFit()
                let labelWidth = min(nameLabel.frame.width + 8, maxWidth)
                nameLabel.frame.size.width = labelWidth
                nameLabel.frame.origin.x = (size - labelWidth) / 2
                containerView.addSubview(nameLabel)
                containerView.frame.size.height = size + 20
            }
            
        }
        
        // MARK: - Helper Methods
        
        private var bubbleColor: UIColor {
            switch warningLevel {
            case .danger: return UIColor(AppColors.bubbleCritical)
            case .warning: return UIColor(AppColors.bubbleDanger)
            case .safe: return UIColor(AppColors.bubbleWarning)
            case .none: return UIColor(AppColors.bubbleSafe)
            }
        }
        
        private var warningColor: UIColor {
            switch warningLevel {
            case .danger: return UIColor(AppColors.bubbleCritical)
            case .warning: return UIColor(AppColors.bubbleDanger)
            case .safe: return UIColor(AppColors.bubbleWarning)
            case .none: return .clear
            }
        }
        
        private func roleColor(for role: PlayerRole) -> UIColor {
            switch role {
            case .hunter:
                return UIColor(AppColors.hunterPrimary)
            case .hider:
                return UIColor(AppColors.hiderPrimary)
            case .zombie:
                return UIColor(AppColors.zombiePrimary)
            case .human:
                return UIColor(AppColors.zombieLight)
            case .teamA:
                return UIColor(AppColors.ctfTeamA)
            case .teamB:
                return UIColor(AppColors.ctfTeamB)
            }
        }
    }
}

