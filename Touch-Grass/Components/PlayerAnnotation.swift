//
//  PlayerAnnotation.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import MapKit
import CoreLocation

class PlayerAnnotation: NSObject, MKAnnotation {
    var player: Player  // Changed from 'let' to 'var'
    var coordinate: CLLocationCoordinate2D  // Display coordinate (may be obfuscated)
    var title: String? {
        player.displayName
    }
    var subtitle: String? {
        player.isAlive ? player.role.rawValue.capitalized : "Eliminated"
    }
    
    init(player: Player, displayCoordinate: CLLocationCoordinate2D? = nil) {
        self.player = player
        // Use provided display coordinate (obfuscated) or actual coordinate
        self.coordinate = displayCoordinate ?? player.coordinate
        super.init()
    }
    
    // Update coordinate smoothly
    func updateCoordinate(_ newCoordinate: CLLocationCoordinate2D, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseOut], animations: {
                self.coordinate = newCoordinate
            })
        } else {
            self.coordinate = newCoordinate
        }
    }
}
