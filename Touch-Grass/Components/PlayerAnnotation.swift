//
//  PlayerAnnotation.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import MapKit
import CoreLocation

/// How a `PlayerAnnotation` should be rendered.
///
/// Picked once at annotation-creation time by the map controller using
/// `LocationObfuscationService.displayMode(...)` so the annotation view never
/// re-derives styling from scattered role checks.
enum PlayerMapDisplayMode {
    /// Local player. Strongest visual treatment, exact live GPS.
    case selfExact
    /// Same-team player. Exact live GPS, normal team-colored marker.
    case teammateExact
    /// Opposing-team player. Coordinate is a jittered snapshot inside the
    /// uncertainty bubble, render with a distinct "signal" treatment so it's
    /// obvious this is *not* a precise location.
    case opponentObfuscated
}

class PlayerAnnotation: NSObject, MKAnnotation {
    var player: Player
    var coordinate: CLLocationCoordinate2D  // Display coordinate (may be obfuscated)
    var displayMode: PlayerMapDisplayMode

    var title: String? {
        switch displayMode {
        case .selfExact, .teammateExact:
            return player.displayName
        case .opponentObfuscated:
            // Strip identity for opposing-team signals.
            return signalLabel(for: player.role)
        }
    }

    var subtitle: String? {
        switch displayMode {
        case .selfExact, .teammateExact:
            return player.isAlive ? player.role.rawValue.capitalized : "Eliminated"
        case .opponentObfuscated:
            return "Approximate location"
        }
    }

    init(
        player: Player,
        displayCoordinate: CLLocationCoordinate2D? = nil,
        displayMode: PlayerMapDisplayMode = .teammateExact
    ) {
        self.player = player
        self.coordinate = displayCoordinate ?? player.coordinate
        self.displayMode = displayMode
        super.init()
    }

    /// Update coordinate smoothly.
    func updateCoordinate(_ newCoordinate: CLLocationCoordinate2D, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
                self.coordinate = newCoordinate
            })
        } else {
            self.coordinate = newCoordinate
        }
    }

    private func signalLabel(for role: PlayerRole) -> String {
        switch role {
        case .hunter: return "Hunter signal"
        case .hider:  return "Hider signal"
        case .zombie: return "Zombie signal"
        case .human:  return "Human signal"
        case .teamA:  return "Team A signal"
        case .teamB:  return "Team B signal"
        }
    }
}
