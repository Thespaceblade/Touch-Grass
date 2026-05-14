//
//  CompassAbility.swift
//  Touch-Grass
//
//  Predator compass pulse model + shared configuration.
//
//  The pulse is a Firestore-backed ability available to the hunting role
//  (Manhunt: `.hunter`, Zombie Tag: `.zombie`). When invoked, the actor's
//  app picks a random eligible prey from the latest session snapshot,
//  computes great-circle distance from its live GPS to the prey's
//  snapshot coordinates, and commits the pulse atomically. All clients
//  render `distanceMeters` from the committed pulse for a shared outcome.
//

import Foundation

// MARK: - CompassPulse

/// A single committed compass pulse on a session document. The presence of
/// a `CompassPulse` with a previously unseen `eventId` is what drives
/// listener-side HUD announcements and predator result UI.
struct CompassPulse: Codable, Equatable {
    /// Unique id for this pulse event. Used to dedupe HUD side effects
    /// across the listener echo and the optimistic local merge on the
    /// acting device.
    let eventId: String

    /// `Player.id` of the predator who fired the pulse. Must equal
    /// `request.auth.uid` in Firestore rules.
    let usedByPlayerId: String

    /// `Player.id` of the prey selected at commit time.
    let targetPlayerId: String

    /// Great-circle distance in meters from the actor's local GPS at
    /// commit time to the prey's snapshot coordinates. This is the
    /// authoritative display value for every client.
    let distanceMeters: Double

    /// Client-generated timestamp at commit time. Rules tie this to
    /// `compassLastUsedAtByPlayerId[usedByPlayerId]`. Not authoritative
    /// — server time would require a Cloud Function.
    let usedAt: Date
}

// MARK: - CompassPulseCommit

/// Swift-only snapshot of a successful compass pulse transaction: the written
/// `CompassPulse` plus the exact actor and target coordinates used to compute
/// `distanceMeters` so UI bearing cannot drift from the session `players` array.
struct CompassPulseCommit: Equatable {
    let pulse: CompassPulse
    let actorLatitude: Double
    let actorLongitude: Double
    let targetLatitude: Double
    let targetLongitude: Double
}

// MARK: - CompassAbilityConfig

/// Pure static configuration for the predator compass pulse ability. All
/// timings shared between `GameService` (eligibility / commit gating) and
/// SwiftUI (charging ring + ready state) come from here so the cooldown
/// ring and the eligibility check can never disagree.
enum CompassAbilityConfig {
    /// Cooldown at the very start of a match, in seconds. Pulses early on
    /// should feel rare; the curve relaxes toward `cooldownEnd` as the
    /// match progresses so it stays useful in the final third.
    static let cooldownStart: TimeInterval = 120.0

    /// Cooldown after `cooldownTaperPoint * duration` has elapsed. The
    /// curve clamps at this value for the rest of the match.
    static let cooldownEnd: TimeInterval = 45.0

    /// Fraction of `bubble.duration` after which `cooldownDuration` has
    /// fully relaxed from `cooldownStart` toward `cooldownEnd`. Linear
    /// interpolation between 0 and this point.
    static let cooldownTaperPoint: Double = 0.8

    /// Fallback cooldown if `bubble.duration` is missing or non-finite.
    static let fixedCooldownFallback: TimeInterval = 90.0

    /// Delay from match start before the first pulse can fire. Gives the
    /// HUD a beat to settle and prevents an "instant pulse" feel.
    static let baseFirstUseDelay: TimeInterval = 60.0

    /// Cap on `firstUseDelay`. Even on very long matches, the predator
    /// doesn't wait forever for the first charge.
    static let maxFirstUseDelay: TimeInterval = 90.0

    /// Window during which a fresh `CompassPulse` event will trigger HUD
    /// announcement pills on listener clients. Older events (e.g. seen
    /// after a reconnect / late join) are skipped silently.
    static let pulseAnnouncementMaxAge: TimeInterval = 10.0

    /// Maximum acceptable age (seconds) of the actor's local GPS fix at
    /// commit time. Stale GPS aborts the pulse with a failure pill and
    /// does NOT advance cooldown.
    static let maxActorLocationAge: TimeInterval = 15.0

    /// Cooldown duration as a function of how far the match has progressed.
    /// Linearly interpolates from `cooldownStart` down to `cooldownEnd`
    /// over the first `cooldownTaperPoint` fraction of `totalDuration`,
    /// then clamps. Falls back to `fixedCooldownFallback` if inputs are
    /// non-finite or non-positive.
    static func cooldownDuration(elapsed: TimeInterval, totalDuration: TimeInterval) -> TimeInterval {
        guard totalDuration.isFinite, totalDuration > 0,
              elapsed.isFinite, elapsed >= 0 else {
            return fixedCooldownFallback
        }
        let taperEnd = totalDuration * cooldownTaperPoint
        guard taperEnd > 0 else { return cooldownEnd }
        let progress = min(1.0, max(0.0, elapsed / taperEnd))
        return cooldownStart + (cooldownEnd - cooldownStart) * progress
    }

    /// Delay between match start and the first allowed pulse. Tuned to be
    /// short enough on quick matches and capped on long ones.
    static func firstUseDelay(elapsed _: TimeInterval, totalDuration: TimeInterval) -> TimeInterval {
        guard totalDuration.isFinite, totalDuration > 0 else { return baseFirstUseDelay }
        let proportional = min(maxFirstUseDelay, max(0, totalDuration * 0.15))
        return max(baseFirstUseDelay, proportional)
    }
}

// MARK: - Eligibility helpers

extension GameSession {
    /// Game types that support the predator compass pulse ability.
    /// CTF intentionally excluded — flags already give location signal.
    static let compassAbilitySupportedGameTypes: Set<GameType> = [.manhunt, .zombieTag]

    /// True if the gameType supports the predator compass pulse.
    var supportsCompassAbility: Bool {
        Self.compassAbilitySupportedGameTypes.contains(gameType)
    }

    /// The prey-side role for the current `gameType`. Used to filter the
    /// random target pool and to skin prey-side announcement copy.
    /// Returns `nil` for unsupported game types.
    var compassPreyRole: PlayerRole? {
        switch gameType {
        case .manhunt: return .hider
        case .zombieTag: return .human
        default: return nil
        }
    }

    /// The predator-side role for the current `gameType`. Returns `nil`
    /// for unsupported game types.
    var compassPredatorRole: PlayerRole? {
        switch gameType {
        case .manhunt: return .hunter
        case .zombieTag: return .zombie
        default: return nil
        }
    }

    /// Alive prey eligible to be picked by a pulse fired by `predatorId`.
    /// Excludes the predator themselves, dead players, and (in Manhunt)
    /// flag-carrier specifics that aren't relevant here.
    func eligibleCompassPrey(firedBy predatorId: String) -> [Player] {
        guard let preyRole = compassPreyRole else { return [] }
        return players.filter { player in
            player.id != predatorId &&
            player.isAlive &&
            player.role == preyRole
        }
    }
}
