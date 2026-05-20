//
//  GuestSessionStore.swift
//  Touch-Grass
//
//  Persists a small snapshot of the active lobby so that force-quitting
//  the app or restarting the device can resume the same session on this
//  device. Only the IDs needed to re-fetch from Firestore are saved
//  locally; the canonical session lives in Firestore.
//

import Foundation

/// Compact, Codable snapshot of an active session as seen by this
/// device. The full session is rehydrated from Firestore by
/// `GameService.resume(snapshot:)` on launch.
struct GuestSessionSnapshot: Codable, Equatable {
    let sessionId: String
    let joinCode: String
    let gameType: GameType
    /// `players[i].id` for the local player (i.e. this device's guest id).
    let localPlayerId: String
    /// Host's device-scoped player id at snapshot time. Used for quick
    /// "is the host this device?" decisions before the listener fires.
    let hostPlayerId: String
    let savedAt: Date
}

@MainActor
final class GuestSessionStore {
    static let shared = GuestSessionStore()

    private let userDefaultsKey = "guestSessionSnapshot.v1"
    private let maxSnapshotAge: TimeInterval = 24 * 60 * 60 // 24 hours

    /// Minimum interval between disk writes when the listener fires
    /// repeatedly. Avoids hammering UserDefaults on busy lobbies.
    private let saveThrottle: TimeInterval = 5

    private var lastSaveAt: Date?
    private var lastSavedSessionId: String?

    private init() {}

    // MARK: - Read

    /// Return the saved snapshot if it exists and is younger than
    /// `maxSnapshotAge`. Stale snapshots are removed on read so callers
    /// never have to think about expiry.
    func currentSnapshot() -> GuestSessionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return nil
        }
        do {
            let snapshot = try JSONDecoder().decode(GuestSessionSnapshot.self, from: data)
            if Date().timeIntervalSince(snapshot.savedAt) > maxSnapshotAge {
                clear(reason: "expired")
                return nil
            }
            return snapshot
        } catch {
            // Malformed snapshot, drop it.
            clear(reason: "decode-failed")
            return nil
        }
    }

    // MARK: - Write

    /// Save (or refresh) the snapshot for the current lobby. Throttled
    /// so listener-driven updates don't write more than once per
    /// `saveThrottle` seconds for the same session.
    func save(_ snapshot: GuestSessionSnapshot, force: Bool = false) {
        if !force,
           let lastSaveAt,
           snapshot.sessionId == lastSavedSessionId,
           Date().timeIntervalSince(lastSaveAt) < saveThrottle {
            return
        }

        do {
            let data = try JSONEncoder().encode(snapshot)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            lastSaveAt = Date()
            lastSavedSessionId = snapshot.sessionId
        } catch {
            DebugLogger.log("⚠️ GuestSessionStore failed to encode snapshot: \(error.localizedDescription)")
        }
    }

    /// Clear the stored snapshot. Called on explicit Leave / confirmed
    /// session-missing / game ended-and-exited / decode failures.
    func clear(reason: String = "manual") {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        lastSaveAt = nil
        lastSavedSessionId = nil
        DebugLogger.log("🧹 GuestSessionStore cleared (\(reason))")
    }
}
