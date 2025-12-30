import Foundation
import CoreLocation

struct Player: Identifiable, Codable, Equatable {
    let id: String
    var displayName: String
    var latitude: Double
    var longitude: Double
    var role: PlayerRole
    var isAlive: Bool
    var lastUpdated: Date
    var profilePictureBase64: String? // Profile picture as base64 string (for Firestore)
    var isFlag: Bool = false // CTF: True if this player is designated as their team's flag
    var isTeamLeader: Bool = false // CTF: True if this player is designated as their team's leader
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    // Get obfuscated coordinate based on viewer and target roles
    // Rules:
    // - Hunters see exact locations of other hunters, but obfuscated locations of hiders (radar ping)
    // - Hiders see exact locations of other hiders, but obfuscated locations of hunters (radar ping)
    // - Zombies see exact locations of other zombies, but obfuscated locations of humans (radar ping)
    // - Humans see exact locations of other humans, but obfuscated locations of zombies (radar ping)
    // - Everyone always sees their own exact location
    // - Obfuscated locations are shown in bubbles that appear every 1 minute for 10 seconds
    func obfuscatedCoordinate(for viewerRole: PlayerRole, viewerId: String, isPingActive: Bool = false, zoneRadius: Double? = nil) -> CLLocationCoordinate2D {
        // Always see your own exact location
        if viewerId == id {
            return coordinate
        }
        
        // Determine if we should obfuscate based on roles
        let shouldObfuscate: Bool
        
        if viewerRole == .hunter {
            // Hunter sees:
            // - Exact locations of other hunters
            // - Obfuscated locations of hiders (only during ping)
            shouldObfuscate = (self.role == .hider) && isPingActive
        } else if viewerRole == .hider {
            // Hider sees:
            // - Exact locations of other hiders
            // - Obfuscated locations of hunters (only during ping)
            shouldObfuscate = (self.role == .hunter) && isPingActive
        } else if viewerRole == .zombie {
            // Zombie sees:
            // - Exact locations of other zombies
            // - Obfuscated locations of humans (only during ping)
            shouldObfuscate = (self.role == .human) && isPingActive
        } else if viewerRole == .human {
            // Human sees:
            // - Exact locations of other humans
            // - Obfuscated locations of zombies (only during ping)
            shouldObfuscate = (self.role == .zombie) && isPingActive
        } else if viewerRole == .teamA || viewerRole == .teamB {
            // CTF: Players see exact locations of teammates, obfuscated locations of enemies (only during ping)
            let viewerTeam: Flag.Team? = viewerRole == .teamA ? .teamA : .teamB
            let targetTeam = self.team
            shouldObfuscate = (targetTeam != nil && targetTeam != viewerTeam) && isPingActive
        } else {
            // Default: don't obfuscate
            shouldObfuscate = false
        }
        
        // If no obfuscation needed, return exact coordinate
        if !shouldObfuscate {
            return coordinate
        }
        
        // Calculate bubble radius based on zone size
        // Use 5-10% of zone radius, with min 50m and max 200m
        let baseRadius = zoneRadius ?? 500.0
        let bubbleRadius = max(50.0, min(200.0, baseRadius * 0.075)) // 7.5% of zone, clamped
        
        // Generate consistent "random" offset from player ID
        // This ensures the same player always appears in roughly the same offset position
        var hasher = Hasher()
        hasher.combine(id)
        hasher.combine(viewerId) // Different offset for different viewers
        let hash = abs(hasher.finalize())
        
        // Offset range: 30% to 80% of bubble radius (ensures location is within bubble but not centered)
        let offsetRange = bubbleRadius * 0.3...bubbleRadius * 0.8
        
        // Use hash to generate consistent offset
        let offset = offsetRange.lowerBound + (Double(hash % 1000) / 1000.0) * (offsetRange.upperBound - offsetRange.lowerBound)
        
        // Use hash to generate consistent angle (0-2π)
        let angle = (Double(hash % 628) / 100.0) // 628 ≈ 2π * 100
        
        // Convert meters to degrees (approximate: 1 degree ≈ 111,000 meters)
        let offsetLat = offset * cos(angle) / 111000.0
        let offsetLon = offset * sin(angle) / (111000.0 * cos(latitude * .pi / 180.0))
        
        return CLLocationCoordinate2D(
            latitude: latitude + offsetLat,
            longitude: longitude + offsetLon
        )
    }
    
    // Get bubble radius for obfuscated player (for radar ping visualization)
    func obfuscationBubbleRadius(zoneRadius: Double? = nil) -> Double {
        let baseRadius = zoneRadius ?? 500.0
        // Use 5-10% of zone radius, with min 50m and max 200m
        return max(50.0, min(200.0, baseRadius * 0.075))
    }
    
    init(id: String = UUID().uuidString,
         displayName: String,
         latitude: Double = 0,
         longitude: Double = 0,
         role: PlayerRole = .hider,
         isAlive: Bool = true,
         lastUpdated: Date = Date(),
         profilePictureBase64: String? = nil,
         isFlag: Bool = false,
         isTeamLeader: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.latitude = latitude
        self.longitude = longitude
        self.role = role
        self.isAlive = isAlive
        self.lastUpdated = lastUpdated
        self.profilePictureBase64 = profilePictureBase64
        self.isFlag = isFlag
    }
}

enum PlayerRole: String, Codable {
    case hunter
    case hider
    case zombie
    case human
    case teamA
    case teamB
}

extension Player {
    var team: Flag.Team? {
        switch role {
        case .teamA: return .teamA
        case .teamB: return .teamB
        default: return nil
        }
    }
    
    // CTF: Get the flag player for a team
    static func flagPlayer(for team: Flag.Team, in players: [Player]) -> Player? {
        return players.first { $0.team == team && $0.isFlag }
    }
}

// MARK: - CLLocation Extension for Bearing

extension CLLocation {
    /// Calculate bearing (direction) from this location to another location
    /// Returns: Bearing in degrees (0-360, where 0 = North, 90 = East, 180 = South, 270 = West)
    func bearing(to destination: CLLocation) -> Double {
        let lat1 = self.coordinate.latitude * .pi / 180.0
        let lat2 = destination.coordinate.latitude * .pi / 180.0
        let lon1 = self.coordinate.longitude * .pi / 180.0
        let lon2 = destination.coordinate.longitude * .pi / 180.0
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var bearing = atan2(y, x) * 180.0 / .pi
        bearing = (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)
        
        return bearing
    }
}
