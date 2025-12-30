//
//  Flag.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import CoreLocation

struct Flag: Codable, Equatable, Identifiable {
    let id: String
    var team: Team
    var latitude: Double
    var longitude: Double
    var isAtBase: Bool // True if flag is at its home base
    var carrierId: String? // ID of player carrying the flag (nil if at base)
    var captureTime: Date? // When flag was captured (nil if at base)
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    init(id: String = UUID().uuidString,
         team: Team,
         latitude: Double,
         longitude: Double,
         isAtBase: Bool = true,
         carrierId: String? = nil,
         captureTime: Date? = nil) {
        self.id = id
        self.team = team
        self.latitude = latitude
        self.longitude = longitude
        self.isAtBase = isAtBase
        self.carrierId = carrierId
        self.captureTime = captureTime
    }
    
    // Check if flag can be captured by a player
    func canBeCaptured(by player: Player) -> Bool {
        // Flag must be at base
        guard isAtBase else { return false }
        // Player must be on opposite team
        guard player.team != team else { return false }
        // Player must be alive
        guard player.isAlive else { return false }
        return true
    }
    
    // Check if flag can be returned by a player
    func canBeReturned(by player: Player) -> Bool {
        // Flag must be captured (not at base)
        guard !isAtBase else { return false }
        // Player must be on the flag's team
        guard player.team == team else { return false }
        // Player must be alive
        guard player.isAlive else { return false }
        return true
    }
    
    // Check if flag can be scored (returned to enemy base)
    func canBeScored(by player: Player, enemyBase: CLLocationCoordinate2D, captureDistance: Double) -> Bool {
        // Flag must be captured
        guard !isAtBase else { return false }
        // Player must be carrying the flag
        guard carrierId == player.id else { return false }
        // Player must be at enemy base
        let playerLocation = CLLocation(latitude: player.latitude, longitude: player.longitude)
        let baseLocation = CLLocation(latitude: enemyBase.latitude, longitude: enemyBase.longitude)
        let distance = playerLocation.distance(from: baseLocation)
        return distance <= captureDistance
    }
    
    enum Team: String, Codable {
        case teamA = "Team A"
        case teamB = "Team B"
        
        var opposite: Team {
            switch self {
            case .teamA: return .teamB
            case .teamB: return .teamA
            }
        }
    }
}

