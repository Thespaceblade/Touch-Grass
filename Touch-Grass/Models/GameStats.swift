//
//  GameStats.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation

struct GameStats: Codable {
    var catches: [CatchRecord] = []
    var survivalTimes: [String: TimeInterval] = [:] // playerId: survival time in seconds
    var firstTaggedPlayerId: String?
    var gameStartTime: Date
    var gameEndTime: Date?
    var winner: GameWinner?
    
    struct CatchRecord: Codable, Identifiable {
        let id: String
        let hunterId: String
        let hunterName: String
        let hiderId: String
        let hiderName: String
        let timestamp: Date
    }
    
    enum GameWinner: String, Codable {
        case hunters
        case hiders
        case timeUp
        case teamA // CTF
        case teamB // CTF
    }
    
    init(gameStartTime: Date) {
        self.gameStartTime = gameStartTime
    }
    
    // Calculate statistics
    func catchesByHunter() -> [String: Int] {
        var counts: [String: Int] = [:]
        for catchRecord in catches {
            counts[catchRecord.hunterId, default: 0] += 1
        }
        return counts
    }
    
    func longestSurvival() -> (playerId: String, time: TimeInterval)? {
        guard let max = survivalTimes.max(by: { $0.value < $1.value }) else { return nil }
        return (max.key, max.value)
    }
    
    func totalGameDuration() -> TimeInterval {
        guard let endTime = gameEndTime else {
            return Date().timeIntervalSince(gameStartTime)
        }
        return endTime.timeIntervalSince(gameStartTime)
    }
}
