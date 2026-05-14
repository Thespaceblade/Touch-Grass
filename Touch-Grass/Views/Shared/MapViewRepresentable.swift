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

// MARK: - Zone System Overlay Metadata
// Metadata for new zone system overlays (safe area, boundary, next safe area preview)

enum ZoneOverlayType {
    case safeArea          // Current safe area (green/blue filled)
    case boundary          // Current boundary (yellow/orange edge)
    case nextSafeArea      // Next safe area preview (dashed outline, shown during warning)
}

struct ZoneOverlayMetadata {
    let type: ZoneOverlayType
    let isClosing: Bool    // Whether boundary is currently moving
}

// MARK: - Storm Overlay Metadata (Fortnite-style outside-zone UI)
//
// The "storm" treatment paints a translucent red MKPolygon outside the
// current playable circle (outer ring with a circular interior hole) and a
// dashed MKPolyline from the local player to the nearest point on that
// circle. Metadata is keyed on `ObjectIdentifier` to match the rest of the
// composition-based approach used in this file.

struct StormOutsideTintMetadata {
    let centerLat: Double
    let centerLon: Double
    let radiusMeters: Double
}

struct StormGuideLineMetadata {}

// Marks an MKPolyline as the CTF halfway line so the renderer / cleanup
// code can disambiguate it from the storm guide line and any future
// polylines we add.
struct HalfwayLineMetadata {}

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
    
    // Obfuscation: snapshot service + cadence
    let isPingActive: Bool // Visual emphasis pulse only — obfuscation is always on cross-team
    let bubbleEpoch: Int // Used in display-state hash so annotation+overlay refresh on epoch flip
    let zoneRadius: Double? // Live zone radius for bubble-ring sizing
    let obfuscationService: LocationObfuscationService? // Owner of opponent snapshots; nil → exact for everyone
    
    @Binding var mapType: MKMapType
    @Binding var showPlayerLabels: Bool
    
    // Add trigger bindings for map actions
    @Binding var zoomToBubbleTrigger: Bool
    @Binding var centerOnPlayerTrigger: Bool
    
    // New zone system
    let bubble: Bubble? // Optional bubble object for new zone system
    
    // Flip to true to restore the old auto-snap-to-zone camera behavior
    private static let autoSnapCameraToZone = false
    
    // Custom initializer to handle default bubble parameter
    init(
        userCoordinate: CLLocationCoordinate2D?,
        bubbleCenter: CLLocationCoordinate2D?,
        bubbleRadius: Double?,
        warningLevel: GameService.WarningLevel,
        players: [Player],
        currentPlayerId: String?,
        currentPlayerRole: PlayerRole?,
        gameType: GameType?,
        flags: [Flag],
        teamABase: CLLocationCoordinate2D?,
        teamBBase: CLLocationCoordinate2D?,
        teamASafeZone: GameSession.SafeZone?,
        teamBSafeZone: GameSession.SafeZone?,
        isPingActive: Bool,
        bubbleEpoch: Int = 0,
        zoneRadius: Double?,
        obfuscationService: LocationObfuscationService? = nil,
        mapType: Binding<MKMapType>,
        showPlayerLabels: Binding<Bool>,
        zoomToBubbleTrigger: Binding<Bool>,
        centerOnPlayerTrigger: Binding<Bool>,
        bubble: Bubble? = nil
    ) {
        self.userCoordinate = userCoordinate
        self.bubbleCenter = bubbleCenter
        self.bubbleRadius = bubbleRadius
        self.warningLevel = warningLevel
        self.players = players
        self.currentPlayerId = currentPlayerId
        self.currentPlayerRole = currentPlayerRole
        self.gameType = gameType
        self.flags = flags
        self.teamABase = teamABase
        self.teamBBase = teamBBase
        self.teamASafeZone = teamASafeZone
        self.teamBSafeZone = teamBSafeZone
        self.isPingActive = isPingActive
        self.bubbleEpoch = bubbleEpoch
        self.zoneRadius = zoneRadius
        self.obfuscationService = obfuscationService
        self._mapType = mapType
        self._showPlayerLabels = showPlayerLabels
        self._zoomToBubbleTrigger = zoomToBubbleTrigger
        self._centerOnPlayerTrigger = centerOnPlayerTrigger
        self.bubble = bubble
    }
    
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
        let coordinator = Coordinator(
            warningLevel: warningLevel,
            showPlayerLabels: showPlayerLabels,
            currentPlayerId: currentPlayerId
        )
        coordinator.bubble = bubble // Store bubble for new zone system
        return coordinator
    }
    
    func updateUIView(_ map: MKMapView, context: Context) {
        // Store reference to map view
        context.coordinator.mapView = map
        
        // Update coordinator
        context.coordinator.warningLevel = warningLevel
        context.coordinator.showPlayerLabels = showPlayerLabels
        context.coordinator.userCoordinate = userCoordinate
        context.coordinator.bubble = bubble // Update bubble for new zone system
        
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
        
        // Check if using new zone system
        if let bubble = bubble, bubble.usesNewZoneSystem {
            // NEW ZONE SYSTEM: Render safe area, boundary, and next safe area preview
            context.coordinator.updateZoneOverlays(map: map, bubble: bubble)
        } else if let center = bubbleCenter, let radius = bubbleRadius, radius > 0 {
            // LEGACY SYSTEM: Use existing bubble rendering
            // Only update bubble if center or radius changed significantly
            if context.coordinator.bubbleChanged(newCenter: center, newRadius: radius) {
                // Remove all zone system overlays (if any)
                let zoneOverlaysToRemove = map.overlays.filter { overlay in
                    if let circle = overlay as? MKCircle {
                        return context.coordinator.getZoneOverlayMetadata(for: circle) != nil
                    }
                    return false
                }
                map.removeOverlays(zoneOverlaysToRemove)
                for overlay in zoneOverlaysToRemove {
                    context.coordinator.removeZoneOverlayMetadata(for: overlay)
                }
                context.coordinator.clearZoneOverlayInstallationState()
                
                // Remove all circle overlays (legacy) - exclude obfuscation bubbles, safe zones, and zone overlays
                let circlesToRemove = map.overlays.filter { overlay in
                    if let circle = overlay as? MKCircle {
                        return context.coordinator.getObfuscationBubbleMetadata(for: circle) == nil &&
                               context.coordinator.getSafeZoneCircleMetadata(for: circle) == nil &&
                               context.coordinator.getZoneOverlayMetadata(for: circle) == nil
                    }
                    return false
                }
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
                
                if Self.autoSnapCameraToZone {
                    let currentRegion = map.region
                    let distance = CLLocation(latitude: center.latitude, longitude: center.longitude)
                        .distance(from: CLLocation(latitude: currentRegion.center.latitude, longitude: currentRegion.center.longitude))
                    
                    if distance > 50 || abs(radius - (context.coordinator.bubbleRadius ?? 0)) > 10 {
                        let region = MKCoordinateRegion(
                            center: center,
                            latitudinalMeters: max(radius * 3, 500),
                            longitudinalMeters: max(radius * 3, 500)
                        )
                        map.setRegion(region, animated: true)
                    }
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
        
        // Apply camera constraints so users can zoom in freely but zoom out is capped to the zone
        context.coordinator.updateCameraConstraints(for: bubble, on: map)
        
        // Fortnite-style storm presentation: red tint outside the safe
        // circle, dashed line from the local user to the nearest safe edge.
        // CTF already uses red/blue side tints and a halfway polyline; the
        // storm treatment would fight that UI, so we skip it there.
        if gameType != .captureTheFlag {
            let stormCenter: CLLocationCoordinate2D?
            let stormRadius: Double?
            if let bubble = bubble, bubble.usesNewZoneSystem {
                let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble)
                stormCenter = runtimeState.currentActiveZone.centerCoordinate
                stormRadius = runtimeState.currentActiveZone.radiusMeters
            } else if let bc = bubbleCenter, let br = bubbleRadius, br > 0 {
                stormCenter = bc
                stormRadius = br
            } else {
                stormCenter = nil
                stormRadius = nil
            }
            context.coordinator.updateStormOverlays(
                map: map,
                center: stormCenter,
                radiusMeters: stormRadius,
                userCoordinate: userCoordinate
            )
        } else {
            context.coordinator.removeStormOverlays(from: map)
        }
        
        // On first update where a bubble is available, zoom to it once then hand control to the user
        if !context.coordinator.hasSetInitialRegion,
           (bubble != nil || (bubbleCenter != nil && bubbleRadius != nil)) {
            context.coordinator.hasSetInitialRegion = true
            context.coordinator.zoomToBubble()
        }
        
        // Filter players for the map.
        // - CTF: only flag players (existing rule).
        // - Other game types: hide eliminated players entirely (v1 dead rule).
        //   Dead players stay in lists/spectator views but never get a map
        //   marker or bubble.
        let playersToShow: [Player]
        if gameType == .captureTheFlag {
            playersToShow = players.filter { $0.isFlag }
        } else {
            playersToShow = players.filter { $0.isAlive }
        }
        
        // Get current player's role for obfuscation.
        let viewerRole = currentPlayerRole ?? .hider
        let viewerId = currentPlayerId ?? ""
        
        // Update coordinator with ping state.
        context.coordinator.isPingActive = isPingActive
        context.coordinator.zoneRadius = zoneRadius
        
        // Defense-in-depth: the view layer is expected to drive
        // `refreshSnapshots` via `.onChange` / `.onAppear` so that opponent
        // snapshots exist before the first paint. If one slips through (e.g.
        // session attaches between view-level events and `updateUIView`),
        // populate any missing entries here so we don't draw nothing for an
        // entire epoch. We only refresh when at least one currently-obfuscated
        // opponent has no snapshot — cheap check, no per-frame churn.
        if let service = obfuscationService, !viewerId.isEmpty {
            let needsBackstopRefresh = playersToShow.contains { player in
                player.id != viewerId
                    && player.isAlive
                    && player.shouldShowObfuscatedLocation(viewerRole: viewerRole, viewerId: viewerId)
                    && service.opponentSnapshots[player.id] == nil
            }
            if needsBackstopRefresh {
                service.refreshSnapshots(
                    players: playersToShow,
                    viewerId: viewerId,
                    viewerRole: viewerRole,
                    gameType: gameType
                )
            }
        }
        
        // Display-state hash: anything that changes how players should be
        // drawn must invalidate. Includes:
        //   - bubbleEpoch (opponent snapshots refresh)
        //   - quantized zone radius (bubble ring size band)
        //   - viewer role + id
        //   - game type
        //   - id set + each player's (role, isAlive) — captured implicitly
        //     by hashing the playersToShow signature
        let displayStateSignature = Self.makeDisplayStateSignature(
            players: playersToShow,
            viewerId: viewerId,
            viewerRole: viewerRole,
            gameType: gameType,
            bubbleEpoch: bubbleEpoch,
            zoneRadius: zoneRadius,
            isPingActive: isPingActive
        )
        let displayStateChanged = context.coordinator.lastDisplayStateSignature != displayStateSignature
        
        // When the display state changes, drop existing obfuscation overlays
        // so the next pass can rebuild them with fresh coordinates / radii.
        if displayStateChanged {
            let existingBubbles = map.overlays.filter { overlay in
                if let circle = overlay as? MKCircle {
                    return context.coordinator.getObfuscationBubbleMetadata(for: circle) != nil
                }
                return false
            }
            for bubble in existingBubbles {
                context.coordinator.removeObfuscationBubbleMetadata(for: bubble)
            }
            map.removeOverlays(existingBubbles)
        }
        
        if displayStateChanged {
            // Players, epoch, zone band, or viewer changed — rebuild annotations.
            let existingAnnotations = map.annotations.filter { $0 is PlayerAnnotation }
            map.removeAnnotations(existingAnnotations)
            
            for player in playersToShow {
                // Validate player has valid ID and coordinates.
                guard !player.id.isEmpty,
                      player.latitude.isFinite && player.longitude.isFinite,
                      player.latitude >= -90 && player.latitude <= 90,
                      player.longitude >= -180 && player.longitude <= 180 else {
                    print("⚠️ Skipping invalid player: \(player.displayName) - ID: \(player.id.isEmpty ? "empty" : player.id), coords: (\(player.latitude), \(player.longitude))")
                    continue
                }
                
                // CTF: Flag players always show exact location (no obfuscation).
                let displayMode: PlayerMapDisplayMode
                let resolvedCoord: CLLocationCoordinate2D?
                
                if gameType == .captureTheFlag && player.isFlag {
                    displayMode = player.id == viewerId ? .selfExact : .teammateExact
                    resolvedCoord = player.coordinate
                } else if let service = obfuscationService {
                    displayMode = service.displayMode(for: player, viewerId: viewerId, viewerRole: viewerRole)
                    resolvedCoord = service.displayCoordinate(
                        for: player,
                        viewerId: viewerId,
                        viewerRole: viewerRole,
                        gameType: gameType,
                        zoneRadius: zoneRadius
                    )
                } else {
                    // No obfuscation service (e.g. spectator) — exact for everyone.
                    displayMode = player.id == viewerId ? .selfExact : .teammateExact
                    resolvedCoord = player.coordinate
                }
                
                // Opponent without a snapshot: skip rendering this frame. We
                // never fall back to the live opponent coordinate (privacy).
                guard let displayCoord = resolvedCoord else {
                    continue
                }
                
                // Validate display coordinate.
                guard displayCoord.latitude.isFinite && displayCoord.longitude.isFinite,
                      displayCoord.latitude >= -90 && displayCoord.latitude <= 90,
                      displayCoord.longitude >= -180 && displayCoord.longitude <= 180 else {
                    print("⚠️ Skipping player with invalid display coordinate: \(player.displayName)")
                    continue
                }
                
                let annotation = PlayerAnnotation(
                    player: player,
                    displayCoordinate: displayCoord,
                    displayMode: displayMode
                )
                map.addAnnotation(annotation)
                
                // Always draw an uncertainty bubble for opponentObfuscated.
                // The ring radius tracks the live `zoneRadius`; the fake
                // center is already snapshot-stable from `displayCoordinate`.
                if displayMode == .opponentObfuscated {
                    let radius = obfuscationService?.bubbleOverlayRadius(for: player, zoneRadius: zoneRadius)
                        ?? player.obfuscationBubbleRadius(zoneRadius: zoneRadius)
                    
                    guard radius.isFinite && radius > 0 && radius < 100000 else {
                        print("⚠️ Skipping obfuscation bubble for player \(player.id) - invalid radius: \(radius)")
                        continue
                    }
                    
                    let bubble = MKCircle(center: displayCoord, radius: radius)
                    let metadata = ObfuscationBubbleMetadata(
                        playerId: player.id,
                        pingStartTime: Date()
                    )
                    context.coordinator.setObfuscationBubbleMetadata(for: bubble, metadata: metadata)
                    map.addOverlay(bubble)
                }
            }
            
            context.coordinator.setLastRenderedPlayers(Set(playersToShow.map { $0.id }))
            context.coordinator.lastPingState = isPingActive
            context.coordinator.lastDisplayStateSignature = displayStateSignature
        } else {
            // Display state unchanged at the "structural" level — but exact
            // (selfExact / teammateExact) annotations may still need to track
            // live GPS movement. Opponent annotations stay frozen until the
            // next epoch (handled by displayStateChanged above).
            var needsUpdate = false
            
            for annotation in map.annotations.compactMap({ $0 as? PlayerAnnotation }) {
                guard annotation.displayMode != .opponentObfuscated,
                      let player = playersToShow.first(where: { $0.id == annotation.player.id }) else {
                    continue
                }
                
                guard !player.id.isEmpty,
                      player.latitude.isFinite && player.longitude.isFinite,
                      player.latitude >= -90 && player.latitude <= 90,
                      player.longitude >= -180 && player.longitude <= 180 else {
                    map.removeAnnotation(annotation)
                    continue
                }
                
                let newDisplayCoord = player.coordinate
                
                let distance = CLLocation(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude)
                    .distance(from: CLLocation(latitude: newDisplayCoord.latitude, longitude: newDisplayCoord.longitude))
                
                if distance > 15 {
                    needsUpdate = true
                    annotation.coordinate = newDisplayCoord
                    annotation.player = player
                }
            }
            
            if needsUpdate {
                let existingAnnotations = map.annotations.filter { $0 is PlayerAnnotation }
                let annotations = existingAnnotations.compactMap { $0 as? PlayerAnnotation }
                map.removeAnnotations(existingAnnotations)
                for annotation in annotations {
                    map.addAnnotation(annotation)
                }
            }
        }
        
        // Update flags and bases (CTF)
        updateFlagsAndBases(map: map, context: context)
    }
    
    // MARK: - Storm Geometry Helpers
    //
    // Pure functions used to build the Fortnite-style "storm" treatment.
    //
    // - `nearestPointOnBoundary`: closest coordinate on a circle to a point.
    //   Planar math is fine at typical playfield scales (a few km); we use
    //   the same 111_000 m-per-degree-of-latitude scale factor and
    //   longitude correction (`cos(latitude)`) the rest of the file uses.
    // - `stormHoleCoordinates`: ring of vertices around a circle, used as
    //   the MKPolygon interior so the outer red fill is cut away inside
    //   the safe zone.
    // - `stormOuterRingCoordinates`: a large rectangle around the zone
    //   center; this is the visible "world" the storm covers. It does not
    //   need to span the whole globe — just enough for typical zoom levels.
    
    static let stormOuterHalfSizeMeters: Double = 50_000 // 50 km — large enough at game zoom levels.
    static let stormHoleVertexCount: Int = 64
    
    static func nearestPointOnBoundary(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        from point: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        guard radiusMeters > 0 else { return center }
        
        let cosLat = cos(center.latitude * .pi / 180.0)
        let safeCosLat = abs(cosLat) < 1e-9 ? 1 : cosLat
        
        let dyMeters = (point.latitude - center.latitude) * 111_000.0
        let dxMeters = (point.longitude - center.longitude) * 111_000.0 * safeCosLat
        let distance = sqrt(dxMeters * dxMeters + dyMeters * dyMeters)
        
        // Player directly on center: pick north as an arbitrary radial.
        guard distance > 1e-6 else {
            return CLLocationCoordinate2D(
                latitude: center.latitude + radiusMeters / 111_000.0,
                longitude: center.longitude
            )
        }
        
        let scale = radiusMeters / distance
        let edgeDy = dyMeters * scale
        let edgeDx = dxMeters * scale
        
        return CLLocationCoordinate2D(
            latitude: center.latitude + edgeDy / 111_000.0,
            longitude: center.longitude + edgeDx / (111_000.0 * safeCosLat)
        )
    }
    
    static func stormHoleCoordinates(
        center: CLLocationCoordinate2D,
        radiusMeters: Double,
        vertexCount: Int = stormHoleVertexCount
    ) -> [CLLocationCoordinate2D] {
        guard radiusMeters > 0, vertexCount >= 3 else { return [] }
        let cosLat = cos(center.latitude * .pi / 180.0)
        let safeCosLat = abs(cosLat) < 1e-9 ? 1 : cosLat
        
        var coords: [CLLocationCoordinate2D] = []
        coords.reserveCapacity(vertexCount)
        for i in 0..<vertexCount {
            let theta = (Double(i) / Double(vertexCount)) * 2 * .pi
            let dyMeters = radiusMeters * cos(theta)
            let dxMeters = radiusMeters * sin(theta)
            coords.append(CLLocationCoordinate2D(
                latitude: center.latitude + dyMeters / 111_000.0,
                longitude: center.longitude + dxMeters / (111_000.0 * safeCosLat)
            ))
        }
        return coords
    }
    
    static func stormOuterRingCoordinates(
        around center: CLLocationCoordinate2D,
        halfSizeMeters: Double = stormOuterHalfSizeMeters
    ) -> [CLLocationCoordinate2D] {
        let cosLat = cos(center.latitude * .pi / 180.0)
        let safeCosLat = abs(cosLat) < 1e-9 ? 1 : cosLat
        let dLat = halfSizeMeters / 111_000.0
        let dLon = halfSizeMeters / (111_000.0 * safeCosLat)
        return [
            CLLocationCoordinate2D(latitude: center.latitude - dLat, longitude: center.longitude - dLon),
            CLLocationCoordinate2D(latitude: center.latitude - dLat, longitude: center.longitude + dLon),
            CLLocationCoordinate2D(latitude: center.latitude + dLat, longitude: center.longitude + dLon),
            CLLocationCoordinate2D(latitude: center.latitude + dLat, longitude: center.longitude - dLon)
        ]
    }
    
    /// Coarse hash of the new-zone overlay geometry. `updateUIView` can run
    /// every SwiftUI tick; rebuilding `MKCircle` zone overlays on every call
    /// (remove all → add) caused visible flicker during interpolated shrink.
    /// We only touch MapKit when this signature changes (~2 m radius bands,
    /// ~1 m center quantization).
    static func zoneOverlayVisualSignature(bubble: Bubble, runtimeState: RuntimeZoneState) -> Int {
        var h = Hasher()
        h.combine(bubble.startTime.timeIntervalSince1970)
        h.combine(bubble.centerLatitude)
        h.combine(bubble.centerLongitude)
        if let gen = bubble.zoneScheduleGeneratedAt {
            h.combine(gen.timeIntervalSince1970)
        }
        h.combine(runtimeState.phaseState.rawValue)
        let az = runtimeState.currentActiveZone
        h.combine(Int(az.centerLatitude * 100_000))
        h.combine(Int(az.centerLongitude * 100_000))
        h.combine(Int(az.radiusMeters / 2.0))
        if let pz = runtimeState.nextPreviewZone {
            h.combine(1)
            h.combine(Int(pz.centerLatitude * 100_000))
            h.combine(Int(pz.centerLongitude * 100_000))
            h.combine(Int(pz.radiusMeters / 2.0))
        } else {
            h.combine(0)
        }
        return h.finalize()
    }
    
    // MARK: - Display-State Signature
    //
    // Compact value summarizing everything that changes how players should be
    // drawn. Recomputed every `updateUIView`; rebuild happens only when this
    // value flips.
    private static func makeDisplayStateSignature(
        players: [Player],
        viewerId: String,
        viewerRole: PlayerRole,
        gameType: GameType?,
        bubbleEpoch: Int,
        zoneRadius: Double?,
        isPingActive: Bool
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(viewerId)
        hasher.combine(viewerRole)
        hasher.combine(gameType?.rawValue)
        hasher.combine(bubbleEpoch)
        // Quantize zone radius into 25 m bands so sub-band GPS noise doesn't
        // force a rebuild on every frame, but real shrink/expand does.
        if let zoneRadius {
            hasher.combine(Int(zoneRadius / 25.0))
        } else {
            hasher.combine(Int.min)
        }
        hasher.combine(isPingActive)
        for player in players {
            hasher.combine(player.id)
            hasher.combine(player.role)
            hasher.combine(player.isAlive)
            hasher.combine(player.isFlag)
        }
        return hasher.finalize()
    }
    
    private func updateFlagsAndBases(map: MKMapView, context: Context) {
        // Remove existing flag and base annotations
        let existingFlagAnnotations = map.annotations.filter { $0 is FlagAnnotation }
        let existingBaseAnnotations = map.annotations.filter { $0 is BaseAnnotation }
        map.removeAnnotations(existingFlagAnnotations + existingBaseAnnotations)
        
        // Remove existing CTF overlays (halfway line, side tints, safe zones).
        // We now identify the halfway line by its tagged metadata rather
        // than by `pointCount == 2`, so other two-point polylines (e.g. the
        // storm guide line) are left alone.
        let existingCTFOverlays = map.overlays.filter { overlay in
            if overlay is MKPolygon, context.coordinator.getCTFSideTintMetadata(for: overlay) != nil {
                return true
            }
            if overlay is MKCircle, context.coordinator.getSafeZoneCircleMetadata(for: overlay) != nil {
                return true
            }
            if overlay is MKPolyline, context.coordinator.getHalfwayLineMetadata(for: overlay) != nil {
                return true
            }
            return false
        }
        for overlay in existingCTFOverlays {
            context.coordinator.removeCTFSideTintMetadata(for: overlay)
            context.coordinator.removeSafeZoneCircleMetadata(for: overlay)
            context.coordinator.removeHalfwayLineMetadata(for: overlay)
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
            context.coordinator.setHalfwayLineMetadata(for: halfwayPolyline, metadata: HalfwayLineMetadata())
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
        var bubble: Bubble? // Store bubble for new zone system
        var userCoordinate: CLLocationCoordinate2D?
        var hasSetInitialRegion = false
        
        // Radar ping obfuscation state
        var isPingActive: Bool = false
        var zoneRadius: Double?
        var lastPingState: Bool = false
        var lastDisplayStateSignature: Int? // Bumps whenever display state changes (epoch, zone band, viewer, alive/role…)
        var gameStartTime: Date? // Track when game started to add delay before creating bubbles
        
        // Store obfuscation bubble metadata separately (composition instead of subclassing)
        // Maps MKCircle overlay to its metadata (playerId, pingStartTime)
        private var obfuscationBubbleMetadata: [ObjectIdentifier: ObfuscationBubbleMetadata] = [:]
        private var ctfSideTintMetadata: [ObjectIdentifier: CTFSideTintMetadata] = [:]
        private var safeZoneCircleMetadata: [ObjectIdentifier: SafeZoneCircleMetadata] = [:]
        private var zoneOverlayMetadata: [ObjectIdentifier: ZoneOverlayMetadata] = [:] // New zone system overlays
        private var stormOutsideTintMetadata: [ObjectIdentifier: StormOutsideTintMetadata] = [:]
        private var stormGuideLineMetadata: [ObjectIdentifier: StormGuideLineMetadata] = [:]
        private var halfwayLineMetadata: [ObjectIdentifier: HalfwayLineMetadata] = [:]
        
        // Cheap throttle so the storm polygon + guide polyline rebuild only
        // when something visually meaningful changes.
        var lastStormSignature: Int?
        
        /// Throttles new-zone `MKCircle` rebuilds (see `updateZoneOverlays`).
        private var lastZoneOverlayVisualSignature: Int?
        /// Circles we installed for the new zone system; used for add-then-remove
        /// updates so we never clear the map to zero zone rings for a frame.
        private var installedZoneCircleOverlays: [MKCircle] = []
        
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
        
        func getZoneOverlayMetadata(for overlay: MKOverlay) -> ZoneOverlayMetadata? {
            return zoneOverlayMetadata[ObjectIdentifier(overlay)]
        }
        
        func setZoneOverlayMetadata(for overlay: MKOverlay, metadata: ZoneOverlayMetadata) {
            zoneOverlayMetadata[ObjectIdentifier(overlay)] = metadata
        }
        
        func removeZoneOverlayMetadata(for overlay: MKOverlay) {
            zoneOverlayMetadata.removeValue(forKey: ObjectIdentifier(overlay))
        }
        
        /// Call when legacy mode or another path strips zone circles from the
        /// map so we do not hold dangling `MKCircle` references.
        func clearZoneOverlayInstallationState() {
            lastZoneOverlayVisualSignature = nil
            installedZoneCircleOverlays.removeAll()
        }
        
        func getStormOutsideTintMetadata(for overlay: MKOverlay) -> StormOutsideTintMetadata? {
            return stormOutsideTintMetadata[ObjectIdentifier(overlay)]
        }
        
        func setStormOutsideTintMetadata(for overlay: MKOverlay, metadata: StormOutsideTintMetadata) {
            stormOutsideTintMetadata[ObjectIdentifier(overlay)] = metadata
        }
        
        func removeStormOutsideTintMetadata(for overlay: MKOverlay) {
            stormOutsideTintMetadata.removeValue(forKey: ObjectIdentifier(overlay))
        }
        
        func getStormGuideLineMetadata(for overlay: MKOverlay) -> StormGuideLineMetadata? {
            return stormGuideLineMetadata[ObjectIdentifier(overlay)]
        }
        
        func setStormGuideLineMetadata(for overlay: MKOverlay, metadata: StormGuideLineMetadata) {
            stormGuideLineMetadata[ObjectIdentifier(overlay)] = metadata
        }
        
        func removeStormGuideLineMetadata(for overlay: MKOverlay) {
            stormGuideLineMetadata.removeValue(forKey: ObjectIdentifier(overlay))
        }
        
        func getHalfwayLineMetadata(for overlay: MKOverlay) -> HalfwayLineMetadata? {
            return halfwayLineMetadata[ObjectIdentifier(overlay)]
        }
        
        func setHalfwayLineMetadata(for overlay: MKOverlay, metadata: HalfwayLineMetadata) {
            halfwayLineMetadata[ObjectIdentifier(overlay)] = metadata
        }
        
        func removeHalfwayLineMetadata(for overlay: MKOverlay) {
            halfwayLineMetadata.removeValue(forKey: ObjectIdentifier(overlay))
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
        
        // MARK: - Camera Constraints
        
        func updateCameraConstraints(for bubble: Bubble?, on map: MKMapView) {
            let center: CLLocationCoordinate2D
            let radius: Double
            
            if let bubble = bubble, bubble.usesNewZoneSystem {
                let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble)
                center = runtimeState.currentActiveZone.centerCoordinate
                radius = runtimeState.currentActiveZone.radiusMeters
            } else if let bc = bubbleCenter, let br = bubbleRadius, br > 0 {
                center = bc
                radius = br
            } else {
                map.cameraZoomRange = nil
                map.cameraBoundary = nil
                return
            }
            
            let maxDistance = max(radius * 5, 1000)
            map.cameraZoomRange = MKMapView.CameraZoomRange(
                maxCenterCoordinateDistance: maxDistance
            )
            
            let boundaryRegion = MKCoordinateRegion(
                center: center,
                latitudinalMeters: radius * 4,
                longitudinalMeters: radius * 4
            )
            map.cameraBoundary = MKMapView.CameraBoundary(
                coordinateRegion: boundaryRegion
            )
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
        
        // MARK: - Zone System Overlay Updates
        
        func updateZoneOverlays(map: MKMapView, bubble: Bubble) {
            let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble)
            let activeZone = runtimeState.currentActiveZone
            let previewZone = runtimeState.nextPreviewZone
            
            map.userTrackingMode = .none
            
            // Always keep coordinator in sync for zoomToBubble / camera even
            // when we skip touching MapKit overlays this tick.
            updateBubble(center: activeZone.centerCoordinate, radius: activeZone.radiusMeters)
            
            let visualSig = MapViewRepresentable.zoneOverlayVisualSignature(
                bubble: bubble,
                runtimeState: runtimeState
            )
            if visualSig == lastZoneOverlayVisualSignature {
                if MapViewRepresentable.autoSnapCameraToZone {
                    let currentRegion = map.region
                    let distance = CLLocation(latitude: activeZone.centerLatitude, longitude: activeZone.centerLongitude)
                        .distance(from: CLLocation(latitude: currentRegion.center.latitude, longitude: currentRegion.center.longitude))
                    
                    if distance > 50 || abs(activeZone.radiusMeters - (bubbleRadius ?? 0)) > 10 {
                        let region = MKCoordinateRegion(
                            center: activeZone.centerCoordinate,
                            latitudinalMeters: max(activeZone.radiusMeters * 3, 500),
                            longitudinalMeters: max(activeZone.radiusMeters * 3, 500)
                        )
                        map.setRegion(region, animated: true)
                    }
                }
                return
            }
            lastZoneOverlayVisualSignature = visualSig
            
            var pending: [(circle: MKCircle, metadata: ZoneOverlayMetadata)] = []
            
            let boundaryCircle = MKCircle(center: activeZone.centerCoordinate, radius: activeZone.radiusMeters)
            pending.append((
                boundaryCircle,
                ZoneOverlayMetadata(type: .boundary, isClosing: runtimeState.phaseState == .closing)
            ))
            
            if runtimeState.phaseState == .closing, let previewZone {
                let safeAreaCircle = MKCircle(center: previewZone.centerCoordinate, radius: previewZone.radiusMeters)
                pending.append((
                    safeAreaCircle,
                    ZoneOverlayMetadata(type: .safeArea, isClosing: false)
                ))
            } else if runtimeState.phaseState == .rotation, let previewZone {
                let nextSafeAreaCircle = MKCircle(center: previewZone.centerCoordinate, radius: previewZone.radiusMeters)
                pending.append((
                    nextSafeAreaCircle,
                    ZoneOverlayMetadata(type: .nextSafeArea, isClosing: false)
                ))
            }
            
            // Add new overlays first so old zone rings never disappear for a
            // frame (was causing visible flicker during SwiftUI-driven updates).
            for item in pending {
                map.addOverlay(item.circle)
                setZoneOverlayMetadata(for: item.circle, metadata: item.metadata)
            }
            for old in installedZoneCircleOverlays {
                map.removeOverlay(old)
                removeZoneOverlayMetadata(for: old)
            }
            installedZoneCircleOverlays = pending.map(\.circle)
            
            if MapViewRepresentable.autoSnapCameraToZone {
                let currentRegion = map.region
                let distance = CLLocation(latitude: activeZone.centerLatitude, longitude: activeZone.centerLongitude)
                    .distance(from: CLLocation(latitude: currentRegion.center.latitude, longitude: currentRegion.center.longitude))
                
                if distance > 50 || abs(activeZone.radiusMeters - (bubbleRadius ?? 0)) > 10 {
                    let region = MKCoordinateRegion(
                        center: activeZone.centerCoordinate,
                        latitudinalMeters: max(activeZone.radiusMeters * 3, 500),
                        longitudinalMeters: max(activeZone.radiusMeters * 3, 500)
                    )
                    map.setRegion(region, animated: true)
                }
            }
        }
        
        // MARK: - Storm Overlay Updates
        //
        // Builds (or rebuilds) the two storm overlays:
        //   1. `MKPolygon` covering the visible world *outside* the safe
        //      circle, drawn as a translucent red fill. Inserted at index 0
        //      so it sits below the zone boundary/safe-area circles and the
        //      player annotations.
        //   2. `MKPolyline` (geodesic for crisp rendering at scale) from the
        //      local user's coordinate to the nearest point on the current
        //      safe circle, dashed. Added at `.aboveLabels` so it stays on
        //      top of everything.
        //
        // Throttled by a coarse signature of (center, radius, user coord,
        // hasGuide) so this only rebuilds when something actually changes.
        
        func updateStormOverlays(
            map: MKMapView,
            center: CLLocationCoordinate2D?,
            radiusMeters: Double?,
            userCoordinate: CLLocationCoordinate2D?
        ) {
            guard let center,
                  let radiusMeters,
                  radiusMeters.isFinite, radiusMeters > 0,
                  center.latitude.isFinite, center.longitude.isFinite,
                  center.latitude >= -90, center.latitude <= 90,
                  center.longitude >= -180, center.longitude <= 180 else {
                removeStormOverlays(from: map)
                lastStormSignature = nil
                return
            }
            
            // Only draw the guide line when we have a valid user coordinate.
            let validUser: CLLocationCoordinate2D? = {
                guard let u = userCoordinate,
                      u.latitude.isFinite, u.longitude.isFinite,
                      u.latitude >= -90, u.latitude <= 90,
                      u.longitude >= -180, u.longitude <= 180,
                      !(u.latitude == 0 && u.longitude == 0) else {
                    return nil
                }
                return u
            }()
            
            let signature = makeStormSignature(
                center: center,
                radiusMeters: radiusMeters,
                user: validUser
            )
            if signature == lastStormSignature { return }
            
            removeStormOverlays(from: map)
            
            // Outer "storm" polygon with the safe circle cut out as an
            // interior hole. `interiorPolygons` makes MapKit clip the fill.
            let outerPoints = MapViewRepresentable.stormOuterRingCoordinates(around: center)
            let holeCoords = MapViewRepresentable.stormHoleCoordinates(
                center: center,
                radiusMeters: radiusMeters
            )
            
            if !outerPoints.isEmpty && holeCoords.count >= 3 {
                let holePolygon = MKPolygon(coordinates: holeCoords, count: holeCoords.count)
                let stormPolygon = MKPolygon(
                    coordinates: outerPoints,
                    count: outerPoints.count,
                    interiorPolygons: [holePolygon]
                )
                setStormOutsideTintMetadata(
                    for: stormPolygon,
                    metadata: StormOutsideTintMetadata(
                        centerLat: center.latitude,
                        centerLon: center.longitude,
                        radiusMeters: radiusMeters
                    )
                )
                // Index 0 = drawn first = visually at the bottom.
                map.insertOverlay(stormPolygon, at: 0, level: .aboveRoads)
            }
            
            // Dashed guide line from the user to the nearest point on the
            // safe circle. Skipped silently when we don't have a usable
            // user fix yet.
            if let user = validUser {
                let edge = MapViewRepresentable.nearestPointOnBoundary(
                    center: center,
                    radiusMeters: radiusMeters,
                    from: user
                )
                let coords = [user, edge]
                let guidePolyline = MKGeodesicPolyline(coordinates: coords, count: coords.count)
                setStormGuideLineMetadata(for: guidePolyline, metadata: StormGuideLineMetadata())
                map.addOverlay(guidePolyline, level: .aboveLabels)
            }
            
            lastStormSignature = signature
        }
        
        func removeStormOverlays(from map: MKMapView) {
            let toRemove = map.overlays.filter { overlay in
                if overlay is MKPolygon, getStormOutsideTintMetadata(for: overlay) != nil {
                    return true
                }
                if overlay is MKPolyline, getStormGuideLineMetadata(for: overlay) != nil {
                    return true
                }
                return false
            }
            for overlay in toRemove {
                removeStormOutsideTintMetadata(for: overlay)
                removeStormGuideLineMetadata(for: overlay)
            }
            map.removeOverlays(toRemove)
        }
        
        // Quantizes inputs so micro GPS jitter / sub-meter zone math don't
        // force a rebuild every frame; real movement crosses the bands.
        private func makeStormSignature(
            center: CLLocationCoordinate2D,
            radiusMeters: Double,
            user: CLLocationCoordinate2D?
        ) -> Int {
            var hasher = Hasher()
            hasher.combine(Int(center.latitude * 100_000))   // ~1.1 m
            hasher.combine(Int(center.longitude * 100_000))
            hasher.combine(Int(radiusMeters / 2.0))           // 2 m bands
            if let user {
                hasher.combine(Int(user.latitude * 100_000))
                hasher.combine(Int(user.longitude * 100_000))
            } else {
                hasher.combine(Int.min)
            }
            return hasher.finalize()
        }
        
        // MARK: - Overlay Rendering
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            // Handle new zone system overlays (check if this circle has zone overlay metadata)
            if let circle = overlay as? MKCircle,
               let zoneMetadata = getZoneOverlayMetadata(for: circle) {
                let renderer = MKCircleRenderer(circle: circle)
                
                switch zoneMetadata.type {
                case .safeArea:
                    // Safe Area: Green/blue filled circle (target during closing phase)
                    // Solid stroke (no dashes) - this is the target the boundary is moving toward
                    renderer.fillColor = UIColor.systemGreen.withAlphaComponent(0.15)
                    renderer.strokeColor = UIColor.systemGreen
                    renderer.lineWidth = 3.0
                    // No dash pattern - solid line for target zone
                    
                case .boundary:
                    // Boundary: Yellow/orange edge (current playable area)
                    // Always solid stroke - this is the current zone
                    if zoneMetadata.isClosing {
                        // Closing: Orange/red with thicker stroke (boundary is moving)
                        renderer.fillColor = UIColor.systemOrange.withAlphaComponent(0.1)
                        renderer.strokeColor = UIColor.systemOrange
                        renderer.lineWidth = 5.0 // Thicker when moving
                        // No dash pattern - solid line for boundary
                    } else {
                        // Static: Yellow edge (normal boundary)
                        renderer.fillColor = UIColor.systemYellow.withAlphaComponent(0.05)
                        renderer.strokeColor = UIColor.systemYellow
                        renderer.lineWidth = 4.0
                        // No dash pattern - solid line for boundary
                    }
                    
                case .nextSafeArea:
                    // Next Safe Area Preview: Dashed outline (shown during warning phase)
                    // This is the preview of where the zone will move to
                    renderer.fillColor = UIColor.clear // No fill - just outline
                    renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.7)
                    renderer.lineWidth = 2.5
                    renderer.lineDashPattern = [10, 5] // Dashed outline for preview
                }
                
                return renderer
            }
            
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
            // Handle obfuscation bubbles - check if this circle has obfuscation metadata.
            //
            // Obfuscation is now always-on across the cross-team boundary, so
            // these bubbles don't pulse-fade like the old radar ping. We just
            // draw a steady translucent disc with a dashed outline. The ring
            // radius is set by the controller and may follow the live zone.
            if let circle = overlay as? MKCircle,
               let metadata = getObfuscationBubbleMetadata(for: circle) {
                guard circle.coordinate.latitude.isFinite && circle.coordinate.longitude.isFinite,
                      circle.coordinate.latitude >= -90 && circle.coordinate.latitude <= 90,
                      circle.coordinate.longitude >= -180 && circle.coordinate.longitude <= 180,
                      circle.radius.isFinite && circle.radius > 0 && circle.radius < 100000,
                      !metadata.playerId.isEmpty else {
                    print("⚠️ Invalid obfuscation bubble properties in renderer, using default renderer")
                    return MKOverlayRenderer(overlay: overlay)
                }
                
                let renderer = MKCircleRenderer(circle: circle)
                
                // Tint by the *target's* role so the player can see what kind
                // of signal they're looking at without seeing identity.
                let role = mapView.annotations.compactMap { $0 as? PlayerAnnotation }
                    .first(where: { $0.player.id == metadata.playerId })?.player.role
                
                let bubbleColor: UIColor = {
                    switch role {
                    case .hunter: return UIColor.systemRed
                    case .hider:  return UIColor.systemBlue
                    case .zombie: return UIColor.systemGreen
                    case .human:  return UIColor.systemBlue
                    case .teamA:  return UIColor.systemBlue
                    case .teamB:  return UIColor.systemRed
                    case .none:   return UIColor.systemGray
                    }
                }()
                
                renderer.fillColor = bubbleColor.withAlphaComponent(0.18)
                renderer.strokeColor = bubbleColor.withAlphaComponent(0.65)
                renderer.lineWidth = 3.0
                renderer.lineDashPattern = [8, 4]
                
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
            
            // Storm outside-zone tint (Fortnite-style red fill, polygon
            // with a circular interior hole around the safe zone).
            if let polygon = overlay as? MKPolygon,
               getStormOutsideTintMetadata(for: polygon) != nil {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.systemRed.withAlphaComponent(0.32)
                renderer.strokeColor = UIColor.systemRed.withAlphaComponent(0.55)
                renderer.lineWidth = 1.0
                return renderer
            }
            
            // Storm guide line (dashed, you -> nearest safe edge).
            if let polyline = overlay as? MKPolyline,
               getStormGuideLineMetadata(for: polyline) != nil {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.white.withAlphaComponent(0.95)
                renderer.lineWidth = 3.5
                renderer.lineDashPattern = [8, 6]
                renderer.lineCap = .round
                return renderer
            }
            
            // CTF halfway line — now keyed on metadata so we don't claim
            // every 2-point polyline (the storm guide is also 2 points).
            if let polyline = overlay as? MKPolyline,
               getHalfwayLineMetadata(for: polyline) != nil {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.white
                renderer.lineWidth = 4.0
                renderer.lineDashPattern = [10, 5]
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
            let displayMode = (view.annotation as? PlayerAnnotation)?.displayMode ?? .teammateExact
            let isCurrentPlayer = displayMode == .selfExact
            let isObfuscated = displayMode == .opponentObfuscated
            
            // Size: self gets the largest, opponents get a slightly smaller
            // signal marker, teammates use the default.
            let size: CGFloat
            switch displayMode {
            case .selfExact: size = 42
            case .teammateExact: size = 32
            case .opponentObfuscated: size = 28
            }
            view.frame = CGRect(x: 0, y: 0, width: size, height: size)
            
            // Opponent (obfuscated): never show a real avatar. Force the
            // hollow / radar-style "signal" marker so it's visually distinct
            // from exact teammate pins.
            if isObfuscated {
                let containerView = UIView(frame: view.bounds)
                containerView.backgroundColor = .clear
                configureOpponentSignalAnnotation(containerView: containerView, player: player, size: size)
                view.addSubview(containerView)
                return
            }
            
            // Self / teammate: load profile picture if available, otherwise
            // fall back to the default icon.
            let containerView = UIView(frame: view.bounds)
            containerView.backgroundColor = .clear
            
            if let profilePictureBase64 = player.profilePictureBase64 {
                loadProfilePicture(for: view, base64String: profilePictureBase64, player: player, size: size, isCurrentPlayer: isCurrentPlayer, isObfuscated: false)
                return
            }
            
            configureDefaultAnnotation(containerView: containerView, player: player, size: size, isCurrentPlayer: isCurrentPlayer, isObfuscated: false)
            view.addSubview(containerView)
        }
        
        /// Distinct "opposing-team signal" treatment.
        ///
        /// - hollow, dashed ring (no fill)
        /// - small pulsing radar dot at the fake center
        /// - role tint (hunter / hider / zombie / human / team color)
        /// - never shows the player's name (annotation `title` already
        ///   substitutes `"Hunter signal"` / etc.)
        private func configureOpponentSignalAnnotation(containerView: UIView, player: Player, size: CGFloat) {
            let tint = roleColor(for: player.role)
            
            // Hollow dashed ring.
            let ring = CAShapeLayer()
            ring.strokeColor = tint.withAlphaComponent(0.85).cgColor
            ring.fillColor = UIColor.clear.cgColor
            ring.lineWidth = 2
            ring.lineDashPattern = [5, 4]
            ring.path = UIBezierPath(
                arcCenter: CGPoint(x: size / 2, y: size / 2),
                radius: size / 2 - 1,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            ).cgPath
            containerView.layer.addSublayer(ring)
            
            // Small filled radar dot at center.
            let dotSize: CGFloat = size * 0.32
            let dot = UIView(frame: CGRect(
                x: (size - dotSize) / 2,
                y: (size - dotSize) / 2,
                width: dotSize,
                height: dotSize
            ))
            dot.backgroundColor = tint.withAlphaComponent(0.75)
            dot.layer.cornerRadius = dotSize / 2
            dot.layer.borderWidth = 1
            dot.layer.borderColor = UIColor.white.withAlphaComponent(0.65).cgColor
            containerView.addSubview(dot)
            
            // Subtle pulse on the dot so it reads as a live signal.
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 0.85
            pulse.toValue = 1.15
            pulse.duration = 1.4
            pulse.repeatCount = .infinity
            pulse.autoreverses = true
            dot.layer.add(pulse, forKey: "signalPulse")
            
            // Soft outer halo so the marker reads on busy basemaps without
            // implying a precise location.
            let halo = UIView(frame: CGRect(
                x: -6, y: -6,
                width: size + 12, height: size + 12
            ))
            halo.backgroundColor = .clear
            halo.layer.cornerRadius = (size + 12) / 2
            halo.layer.borderWidth = 1
            halo.layer.borderColor = tint.withAlphaComponent(0.25).cgColor
            containerView.insertSubview(halo, at: 0)
            
            containerView.alpha = 0.9
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
            
            // Strongest treatment for the local player: thick white outline
            // outside the role-color border so "you" reads at a glance.
            if isCurrentPlayer {
                let whiteOutline = UIView(frame: CGRect(
                    x: -3, y: -3,
                    width: size + 6, height: size + 6
                ))
                whiteOutline.backgroundColor = .clear
                whiteOutline.layer.cornerRadius = (size + 6) / 2
                whiteOutline.layer.borderWidth = 3
                whiteOutline.layer.borderColor = UIColor.white.cgColor
                whiteOutline.layer.shadowColor = UIColor.black.cgColor
                whiteOutline.layer.shadowOpacity = 0.25
                whiteOutline.layer.shadowRadius = 2
                whiteOutline.layer.shadowOffset = .zero
                containerView.addSubview(whiteOutline)
            }
            
            // Outer circle (role color border)
            let outerCircle = UIView(frame: containerView.bounds)
            outerCircle.backgroundColor = .clear
            outerCircle.layer.cornerRadius = size / 2
            outerCircle.layer.borderWidth = isCurrentPlayer ? 4 : 3
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
            // Strongest treatment for the local player: thick white halo so
            // "you" reads at a glance even before the role-color border draws.
            if isCurrentPlayer {
                let whiteOutline = UIView(frame: CGRect(
                    x: -3, y: -3,
                    width: size + 6, height: size + 6
                ))
                whiteOutline.backgroundColor = .clear
                whiteOutline.layer.cornerRadius = (size + 6) / 2
                whiteOutline.layer.borderWidth = 3
                whiteOutline.layer.borderColor = UIColor.white.cgColor
                whiteOutline.layer.shadowColor = UIColor.black.cgColor
                whiteOutline.layer.shadowOpacity = 0.25
                whiteOutline.layer.shadowRadius = 2
                whiteOutline.layer.shadowOffset = .zero
                containerView.addSubview(whiteOutline)
            }
            
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

