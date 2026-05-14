//
//  LocationObfuscationService.swift
//  Touch-Grass
//
//  Owns viewer-specific obfuscation state for the map: a snapshot store keyed
//  by `targetPlayerId`, an epoch counter that advances on a timer, and the
//  pure display helpers callers should use. `Player` stays Codable transport;
//  this service does not mutate or cache state on Player.
//

import Foundation
import CoreLocation
import Combine

/// Per-target snapshot used to render an opponent on the map.
///
/// `coordinate` is the *true* coordinate captured at snapshot time. We jitter
/// from this value (not from the live coordinate) so the fake pin stays
/// stationary within an epoch even when the opponent is moving.
///
/// `radius` is the obfuscation radius captured at snapshot time. The visible
/// bubble overlay may track the *live* zone radius, but the jitter math uses
/// this snapshot radius so the fake pin doesn't drift as the zone shrinks
/// within an epoch.
struct ObfuscatedLocationSnapshot: Equatable {
    let coordinate: CLLocationCoordinate2D
    let radius: Double
    let epoch: Int

    static func == (lhs: ObfuscatedLocationSnapshot, rhs: ObfuscatedLocationSnapshot) -> Bool {
        return lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.radius == rhs.radius
            && lhs.epoch == rhs.epoch
    }
}

@MainActor
final class LocationObfuscationService: ObservableObject {
    // MARK: - Epoch

    /// How often opponent snapshots refresh. Doubles as the "fake pin moves"
    /// cadence. 60s is the previous radar-ping interval; keep it for parity.
    static let epochInterval: TimeInterval = 60.0

    /// Short, optional visual pulse window kept around for animations that
    /// still want to flash on epoch transitions. Obfuscation itself does NOT
    /// depend on this — cross-team is always obfuscated.
    static let pingDuration: TimeInterval = 10.0

    @Published private(set) var bubbleEpoch: Int = 0
    @Published var isPingActive: Bool = false
    @Published var pingStartTime: Date?
    @Published private(set) var opponentSnapshots: [String: ObfuscatedLocationSnapshot] = [:]

    private var epochTimer: Timer?
    private var pingEndTimer: Timer?

    // MARK: - Lifecycle

    init() {
        startEpochCycle()
    }

    func startEpochCycle() {
        // Fire the first ping immediately so any visual emphasis is in sync
        // with the snapshot the view layer is about to take on first load.
        triggerPing()

        epochTimer = Timer.scheduledTimer(withTimeInterval: Self.epochInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.advanceEpoch()
            }
        }
    }

    private func advanceEpoch() {
        bubbleEpoch &+= 1
        // Snapshots are refreshed by the view layer on epoch change via
        // `refreshSnapshots(...)`. Bumping the value here triggers the
        // SwiftUI publish; the view's `onChange(bubbleEpoch)` does the work.
        triggerPing()
    }

    private func triggerPing() {
        isPingActive = true
        pingStartTime = Date()

        pingEndTimer?.invalidate()
        pingEndTimer = Timer.scheduledTimer(withTimeInterval: Self.pingDuration, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.isPingActive = false
                self.pingStartTime = nil
            }
        }
    }

    func stop() {
        epochTimer?.invalidate()
        epochTimer = nil
        pingEndTimer?.invalidate()
        pingEndTimer = nil
        isPingActive = false
        pingStartTime = nil
        opponentSnapshots.removeAll()
    }

    deinit {
        // Timers reference `self` weakly; nothing else to clean up that we
        // can do from `deinit` (MainActor-isolated methods are unavailable).
    }

    // MARK: - Snapshot Maintenance
    //
    // Rules (see plan):
    // 1. Initial load: when viewer + players first become available, snapshot
    //    every cross-role alive opponent immediately so the map never shows
    //    "missing snapshot → live fallback".
    // 2. Ongoing: only refresh existing entries when `bubbleEpoch` advances.
    // 3. Mid-epoch joiners: if a new opponent appears with no entry, snapshot
    //    them once on first sight (playability).
    //
    // Stale entries (for players who have left or died or switched roles to
    // same-team) are pruned to keep the store from growing forever.

    /// Should be called when:
    /// - viewer + session first become available
    /// - `bubbleEpoch` changes
    /// - the players list changes (to handle joiners / leavers / role flips)
    func refreshSnapshots(
        players: [Player],
        viewerId: String,
        viewerRole: PlayerRole,
        gameType: GameType?
    ) {
        guard !viewerId.isEmpty else { return }

        // CTF flag players are always shown exactly — do not snapshot them.
        // Other CTF interactions still go through the cross-team rule below.
        let zoneRadius = lastZoneRadius

        var nextSnapshots: [String: ObfuscatedLocationSnapshot] = [:]
        let currentEpoch = bubbleEpoch

        for player in players {
            // Skip self and any player that shouldn't be obfuscated.
            guard player.id != viewerId,
                  isValidCoordinate(player.coordinate),
                  player.shouldShowObfuscatedLocation(viewerRole: viewerRole, viewerId: viewerId)
            else { continue }

            // Skip CTF flag players — they're always exact.
            if gameType == .captureTheFlag && player.isFlag { continue }

            let bubbleRadius = player.obfuscationBubbleRadius(zoneRadius: zoneRadius)

            if let existing = opponentSnapshots[player.id], existing.epoch == currentEpoch {
                // Already snapshotted this epoch (e.g. joiner from a previous
                // refresh, or initial load) — keep the existing snapshot so
                // the fake pin stays stable across re-renders within an epoch.
                nextSnapshots[player.id] = existing
            } else {
                nextSnapshots[player.id] = ObfuscatedLocationSnapshot(
                    coordinate: player.coordinate,
                    radius: bubbleRadius,
                    epoch: currentEpoch
                )
            }
        }

        opponentSnapshots = nextSnapshots
    }

    /// Last `zoneRadius` passed into `displayCoordinate(...)` — used as a
    /// default when refreshing snapshots so the bubble radius scales to the
    /// current zone size. Stored privately; not published.
    private var lastZoneRadius: Double?

    private func isValidCoordinate(_ coord: CLLocationCoordinate2D) -> Bool {
        return coord.latitude.isFinite
            && coord.longitude.isFinite
            && coord.latitude >= -90 && coord.latitude <= 90
            && coord.longitude >= -180 && coord.longitude <= 180
    }

    // MARK: - Public Display API
    //
    // Single entry point the map uses to decide:
    //   • what coordinate to draw
    //   • how to draw it (PlayerMapDisplayMode)
    //   • what the uncertainty radius should be
    //
    // The map MUST NOT call `player.coordinate` directly for non-self/non-CTF
    // rendering — go through `displayCoordinate(...)` / `displayMode(...)`.

    /// What style this target should be rendered with from the viewer's
    /// perspective.
    func displayMode(
        for target: Player,
        viewerId: String,
        viewerRole: PlayerRole
    ) -> PlayerMapDisplayMode {
        if target.id == viewerId { return .selfExact }
        if target.shouldShowObfuscatedLocation(viewerRole: viewerRole, viewerId: viewerId) {
            return .opponentObfuscated
        }
        return .teammateExact
    }

    /// Coordinate to display for the target.
    ///
    /// - Self and same-team / CTF-flag players always return their exact
    ///   live coordinate.
    /// - Opponents return a jittered coordinate derived from
    ///   `opponentSnapshots[target.id]`.
    /// - **If an opponent has no snapshot yet, this returns `nil`** —
    ///   callers must skip drawing that pin / bubble until a snapshot is
    ///   populated by `refreshSnapshots(...)`. The previous live-coordinate
    ///   fallback was a privacy leak (one exact frame on first paint), so
    ///   we never read `target.coordinate` for obfuscated targets here.
    func displayCoordinate(
        for target: Player,
        viewerId: String,
        viewerRole: PlayerRole,
        gameType: GameType?,
        zoneRadius: Double?
    ) -> CLLocationCoordinate2D? {
        lastZoneRadius = zoneRadius

        if target.id == viewerId { return target.coordinate }
        if gameType == .captureTheFlag && target.isFlag { return target.coordinate }

        if target.shouldShowObfuscatedLocation(viewerRole: viewerRole, viewerId: viewerId) {
            guard let snapshot = opponentSnapshots[target.id] else {
                // Defense-in-depth: do not leak live opponent GPS even for a
                // single frame. The caller will skip rendering until the
                // next `refreshSnapshots(...)` populates this entry.
                return nil
            }

            return Self.jitteredCoordinate(
                from: snapshot.coordinate,
                targetId: target.id,
                viewerId: viewerId,
                epoch: snapshot.epoch,
                radius: snapshot.radius
            )
        }

        return target.coordinate
    }

    /// Radius (meters) of the uncertainty bubble that surrounds an opponent's
    /// fake pin. Driven by live `zoneRadius` so the *ring* shrinks with the
    /// zone, while the *fake center* uses the snapshot radius captured at
    /// snapshot time.
    func bubbleOverlayRadius(for target: Player, zoneRadius: Double?) -> Double {
        return target.obfuscationBubbleRadius(zoneRadius: zoneRadius)
    }

    // MARK: - Pure Jitter

    /// Deterministic jitter from a basis coordinate. Same `(targetId, viewerId,
    /// epoch)` always returns the same offset — so within an epoch the fake
    /// pin is stable, and different viewers see different offsets so the
    /// uncertainty actually feels uncertain.
    static func jitteredCoordinate(
        from basis: CLLocationCoordinate2D,
        targetId: String,
        viewerId: String,
        epoch: Int,
        radius: Double
    ) -> CLLocationCoordinate2D {
        var hasher = Hasher()
        hasher.combine(targetId)
        hasher.combine(viewerId)
        hasher.combine(epoch)
        let hash = abs(hasher.finalize())

        // Offset 30%–80% of radius so the fake center is always somewhere
        // inside the bubble but never sitting on the basis coordinate.
        let lowerBound = radius * 0.3
        let upperBound = radius * 0.8
        let offset = lowerBound + (Double(hash % 1000) / 1000.0) * (upperBound - lowerBound)
        let angle = Double(hash % 628) / 100.0 // ≈ 0…2π

        let offsetLat = offset * cos(angle) / 111_000.0
        let cosLat = cos(basis.latitude * .pi / 180.0)
        let offsetLon = offset * sin(angle) / (111_000.0 * (cosLat == 0 ? 1 : cosLat))

        return CLLocationCoordinate2D(
            latitude: basis.latitude + offsetLat,
            longitude: basis.longitude + offsetLon
        )
    }
}
