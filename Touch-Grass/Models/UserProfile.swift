//
//  UserProfile.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation

struct UserProfile: Identifiable, Codable, Equatable {
    let id: String // Apple User ID
    var displayName: String
    var email: String?
    var profilePictureURL: String?
    var createdAt: Date
    var lastUpdated: Date
    
    // Game statistics
    var gamesPlayed: Int
    var gamesWon: Int
    var totalCatches: Int
    var totalSurvivalTime: TimeInterval // Total seconds survived across all games
    
    // Computed properties
    var averageSurvivalTime: TimeInterval {
        guard gamesPlayed > 0 else { return 0 }
        return totalSurvivalTime / Double(gamesPlayed)
    }
    
    var winRate: Double {
        guard gamesPlayed > 0 else { return 0 }
        return Double(gamesWon) / Double(gamesPlayed)
    }
    
    init(id: String,
         displayName: String,
         email: String? = nil,
         profilePictureURL: String? = nil,
         createdAt: Date = Date(),
         lastUpdated: Date = Date(),
         gamesPlayed: Int = 0,
         gamesWon: Int = 0,
         totalCatches: Int = 0,
         totalSurvivalTime: TimeInterval = 0) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.profilePictureURL = profilePictureURL
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.gamesPlayed = gamesPlayed
        self.gamesWon = gamesWon
        self.totalCatches = totalCatches
        self.totalSurvivalTime = totalSurvivalTime
    }
}



