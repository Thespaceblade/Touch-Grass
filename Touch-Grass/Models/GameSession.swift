//
//  GameSession.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import Foundation
import CoreLocation

struct GameSession: Identifiable {
    let id: String
    var hostId: String
    var gameState: GameState
    var gameType: GameType // Type of game being played
    var bubble: Bubble?
    var players: [Player]
    var catchDistance: Double // meters for proximity catch
    var joinCode: String // 6-digit join code for players to join
    var hunterCount: Int // Number of hunters in the game
    var firstTaggedPlayerId: String? // ID of first player tagged (becomes hunter next game)
    var gameNumber: Int // Track which game in the session (1, 2, 3, etc.)
    
    // Capture The Flag specific
    var flags: [Flag] = [] // Flags for CTF (legacy - kept for compatibility)
    var flagCarriers: [String: String] = [:] // Map of flag player ID -> carrier player ID (nil if at base)
    var teamAScore: Int = 0 // Team A score
    var teamBScore: Int = 0 // Team B score
    var teamABase: CLLocationCoordinate2D? // Team A base location
    var teamBBase: CLLocationCoordinate2D? // Team B base location
    var scoreLimit: Int = 3 // Legacy field - not used in CTF win condition (kept for backwards compatibility)
    var teamAFlagPlaced: Bool = false // Team A flag has been placed
    var teamBFlagPlaced: Bool = false // Team B flag has been placed
    var teamASafeZone: SafeZone? = nil // Team A safe zone (center + radius)
    var teamBSafeZone: SafeZone? = nil // Team B safe zone (center + radius)

    // Predator compass pulse ability (Manhunt hunters / Zombie Tag zombies).
    // The latest committed pulse on this session, every client renders the
    // SAME `distanceMeters` from this value, so the actor's bearing/distance
    // are authoritative for display once written. `usedAt` is a client-
    // generated timestamp; rules tie it to the cooldown map entry below.
    var compassPulse: CompassPulse? = nil
    // Per-predator cooldown anchor: last `usedAt` keyed by `usedByPlayerId`.
    // Lives next to `compassPulse` so a transaction can read both atomically
    // and Firestore rules can compare timestamps without touching `players`.
    var compassLastUsedAtByPlayerId: [String: Date] = [:]
    
    struct SafeZone: Codable, Equatable {
        // IMMUTABLE: Once confirmed, these values never change (prevents GPS drift)
        let center: CLLocationCoordinate2D
        let radius: Double // meters
        let confirmedAt: Date // Timestamp when safe zone was confirmed (for tiebreaking)
        
        var centerLatitude: Double { center.latitude }
        var centerLongitude: Double { center.longitude }
        
        init(center: CLLocationCoordinate2D, radius: Double, confirmedAt: Date = Date()) {
            self.center = center
            self.radius = radius
            self.confirmedAt = confirmedAt
        }
        
        enum CodingKeys: String, CodingKey {
            case centerLatitude, centerLongitude, radius, confirmedAt
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let lat = try container.decode(Double.self, forKey: .centerLatitude)
            let lon = try container.decode(Double.self, forKey: .centerLongitude)
            self.center = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            self.radius = try container.decode(Double.self, forKey: .radius)
            // confirmedAt is optional for backward compatibility
            self.confirmedAt = (try? container.decode(Date.self, forKey: .confirmedAt)) ?? Date()
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(center.latitude, forKey: .centerLatitude)
            try container.encode(center.longitude, forKey: .centerLongitude)
            try container.encode(radius, forKey: .radius)
            try container.encode(confirmedAt, forKey: .confirmedAt)
        }
        
        static func == (lhs: SafeZone, rhs: SafeZone) -> Bool {
            return lhs.center.latitude == rhs.center.latitude &&
                   lhs.center.longitude == rhs.center.longitude &&
                   lhs.radius == rhs.radius &&
                   lhs.confirmedAt == rhs.confirmedAt
        }
    }
    
    // Codable keys for custom encoding/decoding
    enum CodingKeys: String, CodingKey {
        case id, hostId, gameState, gameType, bubble, players, catchDistance, joinCode
        case hunterCount, firstTaggedPlayerId, gameNumber, flags
        case teamAScore, teamBScore, scoreLimit
        case teamABaseLat, teamABaseLon, teamBBaseLat, teamBBaseLon
        case teamAFlagPlaced, teamBFlagPlaced
        case teamASafeZone, teamBSafeZone
        case flagCarriers
        case compassPulse, compassLastUsedAtByPlayerId
    }
    
    init(id: String = UUID().uuidString,
         hostId: String,
         gameState: GameState = .lobby,
         gameType: GameType = .manhunt,
         bubble: Bubble? = nil,
         players: [Player] = [],
         catchDistance: Double = 10.0,
         joinCode: String = GameSession.generateJoinCode(),
         hunterCount: Int = 1,
         firstTaggedPlayerId: String? = nil,
         gameNumber: Int = 1,
         flags: [Flag] = [],
         teamAScore: Int = 0,
         teamBScore: Int = 0,
         teamABase: CLLocationCoordinate2D? = nil,
         teamBBase: CLLocationCoordinate2D? = nil,
         scoreLimit: Int = 3) {
        self.id = id
        self.hostId = hostId
        self.gameState = gameState
        self.gameType = gameType
        self.bubble = bubble
        self.players = players
        self.catchDistance = catchDistance
        self.joinCode = joinCode
        self.hunterCount = hunterCount
        self.firstTaggedPlayerId = firstTaggedPlayerId
        self.gameNumber = gameNumber
        self.flags = flags
        self.teamAScore = teamAScore
        self.teamBScore = teamBScore
        self.teamABase = teamABase
        self.teamBBase = teamBBase
        self.scoreLimit = scoreLimit
    }
    
    // Generate a 6-digit join code
    static func generateJoinCode() -> String {
        let code = Int.random(in: 100000...999999)
        return String(code)
    }
}

// MARK: - Codable Conformance
extension GameSession: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        hostId = try container.decode(String.self, forKey: .hostId)
        gameState = try container.decode(GameState.self, forKey: .gameState)
        gameType = try container.decode(GameType.self, forKey: .gameType)
        bubble = try container.decodeIfPresent(Bubble.self, forKey: .bubble)
        players = try container.decode([Player].self, forKey: .players)
        catchDistance = try container.decode(Double.self, forKey: .catchDistance)
        joinCode = try container.decode(String.self, forKey: .joinCode)
        hunterCount = try container.decode(Int.self, forKey: .hunterCount)
        firstTaggedPlayerId = try container.decodeIfPresent(String.self, forKey: .firstTaggedPlayerId)
        gameNumber = try container.decode(Int.self, forKey: .gameNumber)
        flags = try container.decodeIfPresent([Flag].self, forKey: .flags) ?? []
        teamAScore = try container.decodeIfPresent(Int.self, forKey: .teamAScore) ?? 0
        teamBScore = try container.decodeIfPresent(Int.self, forKey: .teamBScore) ?? 0
        scoreLimit = try container.decodeIfPresent(Int.self, forKey: .scoreLimit) ?? 3
        teamAFlagPlaced = try container.decodeIfPresent(Bool.self, forKey: .teamAFlagPlaced) ?? false
        teamBFlagPlaced = try container.decodeIfPresent(Bool.self, forKey: .teamBFlagPlaced) ?? false
        
        // Decode optional coordinates
        if let lat = try container.decodeIfPresent(Double.self, forKey: .teamABaseLat),
           let lon = try container.decodeIfPresent(Double.self, forKey: .teamABaseLon) {
            teamABase = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            teamABase = nil
        }
        
        if let lat = try container.decodeIfPresent(Double.self, forKey: .teamBBaseLat),
           let lon = try container.decodeIfPresent(Double.self, forKey: .teamBBaseLon) {
            teamBBase = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            teamBBase = nil
        }
        
        teamASafeZone = try container.decodeIfPresent(SafeZone.self, forKey: .teamASafeZone)
        teamBSafeZone = try container.decodeIfPresent(SafeZone.self, forKey: .teamBSafeZone)
        flagCarriers = try container.decodeIfPresent([String: String].self, forKey: .flagCarriers) ?? [:]

        compassPulse = try container.decodeIfPresent(CompassPulse.self, forKey: .compassPulse)
        compassLastUsedAtByPlayerId = try container.decodeIfPresent([String: Date].self, forKey: .compassLastUsedAtByPlayerId) ?? [:]
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(hostId, forKey: .hostId)
        try container.encode(gameState, forKey: .gameState)
        try container.encode(gameType, forKey: .gameType)
        try container.encodeIfPresent(bubble, forKey: .bubble)
        try container.encode(players, forKey: .players)
        try container.encode(catchDistance, forKey: .catchDistance)
        try container.encode(joinCode, forKey: .joinCode)
        try container.encode(hunterCount, forKey: .hunterCount)
        try container.encodeIfPresent(firstTaggedPlayerId, forKey: .firstTaggedPlayerId)
        try container.encode(gameNumber, forKey: .gameNumber)
        try container.encode(flags, forKey: .flags)
        try container.encode(teamAScore, forKey: .teamAScore)
        try container.encode(teamBScore, forKey: .teamBScore)
        try container.encode(scoreLimit, forKey: .scoreLimit)
        try container.encode(teamAFlagPlaced, forKey: .teamAFlagPlaced)
        try container.encode(teamBFlagPlaced, forKey: .teamBFlagPlaced)
        try container.encodeIfPresent(teamASafeZone, forKey: .teamASafeZone)
        try container.encodeIfPresent(teamBSafeZone, forKey: .teamBSafeZone)
        try container.encode(flagCarriers, forKey: .flagCarriers)
        
        // Encode optional coordinates
        if let base = teamABase {
            try container.encode(base.latitude, forKey: .teamABaseLat)
            try container.encode(base.longitude, forKey: .teamABaseLon)
        }
        
        if let base = teamBBase {
            try container.encode(base.latitude, forKey: .teamBBaseLat)
            try container.encode(base.longitude, forKey: .teamBBaseLon)
        }

        try container.encodeIfPresent(compassPulse, forKey: .compassPulse)
        if !compassLastUsedAtByPlayerId.isEmpty {
            try container.encode(compassLastUsedAtByPlayerId, forKey: .compassLastUsedAtByPlayerId)
        }
    }
}

// MARK: - Equatable Conformance
extension GameSession: Equatable {
    static func == (lhs: GameSession, rhs: GameSession) -> Bool {
        guard lhs.id == rhs.id,
              lhs.hostId == rhs.hostId,
              lhs.gameState == rhs.gameState,
              lhs.gameType == rhs.gameType,
              lhs.bubble == rhs.bubble,
              lhs.players == rhs.players,
              lhs.catchDistance == rhs.catchDistance,
              lhs.joinCode == rhs.joinCode,
              lhs.hunterCount == rhs.hunterCount,
              lhs.firstTaggedPlayerId == rhs.firstTaggedPlayerId,
              lhs.gameNumber == rhs.gameNumber,
              lhs.flags == rhs.flags,
              lhs.teamAScore == rhs.teamAScore,
              lhs.teamBScore == rhs.teamBScore,
              lhs.scoreLimit == rhs.scoreLimit,
              lhs.teamAFlagPlaced == rhs.teamAFlagPlaced,
              lhs.teamBFlagPlaced == rhs.teamBFlagPlaced,
              lhs.teamASafeZone == rhs.teamASafeZone,
              lhs.teamBSafeZone == rhs.teamBSafeZone,
              lhs.flagCarriers == rhs.flagCarriers,
              lhs.compassPulse == rhs.compassPulse,
              lhs.compassLastUsedAtByPlayerId == rhs.compassLastUsedAtByPlayerId else {
            return false
        }
        
        // Compare optional CLLocationCoordinate2D
        func coordinatesEqual(_ lhs: CLLocationCoordinate2D?, _ rhs: CLLocationCoordinate2D?) -> Bool {
            switch (lhs, rhs) {
            case (nil, nil): return true
            case (let l?, let r?): return l.latitude == r.latitude && l.longitude == r.longitude
            default: return false
            }
        }
        
        return coordinatesEqual(lhs.teamABase, rhs.teamABase) &&
               coordinatesEqual(lhs.teamBBase, rhs.teamBBase)
    }
}

// MARK: - GameType Codable
extension GameType: Codable {}

enum GameState: String, Codable {
    case lobby
    case flagPlacement // CTF: Waiting for flags to be placed
    case active
    case ended
}
