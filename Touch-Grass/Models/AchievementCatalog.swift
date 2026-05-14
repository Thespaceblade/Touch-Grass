//
//  AchievementCatalog.swift
//  Touch-Grass
//
//  Local achievement definitions and pure evaluation from profile counters.
//

import Foundation

// MARK: - Stats snapshot (UserDefaults-backed; testable without ProfileService)

struct ProfileAchievementStats: Equatable, Sendable {
    var totalGamesPlayed: Int
    var totalWins: Int
    var totalPlaytimeSeconds: Int
    var gamesManhunt: Int
    var gamesZombieTag: Int
    var gamesCTF: Int
    var winsManhunt: Int
    var winsZombieTag: Int
    var winsCTF: Int
    var totalPredatorTags: Int
    var timesFirstTagged: Int
    var zombieHordeWins: Int
    var humanSurvivalWins: Int
}

// MARK: - Achievement identity

enum AchievementID: String, CaseIterable, Identifiable, Sendable {
    case firstSteps
    case firstWin
    case veteran
    case champion
    case marathonRunner
    case tripleThreat

    case manhuntRegular
    case predator5
    case predator25

    case patientZero3
    case outbreak
    case lastHumanStanding

    case ctfRookie
    case ctfChampion

    var id: String { rawValue }
}

enum AchievementSection: String, CaseIterable, Sendable {
    case general = "General"
    case manhunt = "Manhunt"
    case zombieTag = "Zombie Tag"
    case captureTheFlag = "Capture The Flag"
}

struct AchievementDefinition: Sendable {
    let id: AchievementID
    let title: String
    let description: String
    let iconSystemName: String
    let section: AchievementSection

    func isUnlocked(_ stats: ProfileAchievementStats) -> Bool {
        switch id {
        case .firstSteps:
            return stats.totalGamesPlayed >= 1
        case .firstWin:
            return stats.totalWins >= 1
        case .veteran:
            return stats.totalGamesPlayed >= 10
        case .champion:
            return stats.totalWins >= 5
        case .marathonRunner:
            return stats.totalPlaytimeSeconds >= 7200 // 2 hours
        case .tripleThreat:
            return stats.gamesManhunt >= 1 && stats.gamesZombieTag >= 1 && stats.gamesCTF >= 1

        case .manhuntRegular:
            return stats.gamesManhunt >= 1
        case .predator5:
            return stats.totalPredatorTags >= 5
        case .predator25:
            return stats.totalPredatorTags >= 25

        case .patientZero3:
            return stats.timesFirstTagged >= 3
        case .outbreak:
            return stats.zombieHordeWins >= 1
        case .lastHumanStanding:
            return stats.humanSurvivalWins >= 1

        case .ctfRookie:
            return stats.gamesCTF >= 1
        case .ctfChampion:
            return stats.winsCTF >= 3
        }
    }

    /// Progress for achievements that support a numeric target (nil = binary only).
    func progress(_ stats: ProfileAchievementStats) -> (current: Int, target: Int)? {
        switch id {
        case .veteran:
            return (min(stats.totalGamesPlayed, 10), 10)
        case .champion:
            return (min(stats.totalWins, 5), 5)
        case .marathonRunner:
            let target = 7200
            return (min(stats.totalPlaytimeSeconds, target), target)
        case .predator5:
            return (min(stats.totalPredatorTags, 5), 5)
        case .predator25:
            return (min(stats.totalPredatorTags, 25), 25)
        case .patientZero3:
            return (min(stats.timesFirstTagged, 3), 3)
        case .ctfChampion:
            return (min(stats.winsCTF, 3), 3)
        default:
            return nil
        }
    }
}

// MARK: - Catalog

enum AchievementCatalog {
    static let definitions: [AchievementDefinition] = [
        AchievementDefinition(id: .firstSteps, title: "First Steps", description: "Play your first game", iconSystemName: "star.fill", section: .general),
        AchievementDefinition(id: .firstWin, title: "Winner", description: "Win your first game", iconSystemName: "trophy.fill", section: .general),
        AchievementDefinition(id: .veteran, title: "Veteran", description: "Play 10 games", iconSystemName: "medal.fill", section: .general),
        AchievementDefinition(id: .champion, title: "Champion", description: "Win 5 games", iconSystemName: "crown.fill", section: .general),
        AchievementDefinition(id: .marathonRunner, title: "Marathon", description: "Play 2 hours total", iconSystemName: "figure.run", section: .general),
        AchievementDefinition(id: .tripleThreat, title: "Triple Threat", description: "Play Manhunt, Zombie Tag, and CTF at least once each", iconSystemName: "square.grid.3x3.fill", section: .general),

        AchievementDefinition(id: .manhuntRegular, title: "Hide & Seek", description: "Finish a Manhunt game", iconSystemName: "figure.run", section: .manhunt),
        AchievementDefinition(id: .predator5, title: "Predator", description: "Land 5 tags as hunter or zombie", iconSystemName: "hand.raised.fill", section: .manhunt),
        AchievementDefinition(id: .predator25, title: "Apex Predator", description: "Land 25 tags as hunter or zombie", iconSystemName: "flame.fill", section: .manhunt),

        AchievementDefinition(id: .patientZero3, title: "Patient Zero", description: "Be the first tagged 3 times", iconSystemName: "cross.case.fill", section: .zombieTag),
        AchievementDefinition(id: .outbreak, title: "Outbreak", description: "Win as a zombie when the horde takes the match", iconSystemName: "figure.walk.arrival", section: .zombieTag),
        AchievementDefinition(id: .lastHumanStanding, title: "Last Stand", description: "Win as a human", iconSystemName: "shield.checkered", section: .zombieTag),

        AchievementDefinition(id: .ctfRookie, title: "Flag Bearer", description: "Finish a Capture the Flag game", iconSystemName: "flag.fill", section: .captureTheFlag),
        AchievementDefinition(id: .ctfChampion, title: "Safe Zone Legend", description: "Win 3 CTF matches", iconSystemName: "flag.checkered", section: .captureTheFlag),
    ]

    private static let definitionById: [AchievementID: AchievementDefinition] = {
        var map: [AchievementID: AchievementDefinition] = [:]
        for def in definitions {
            map[def.id] = def
        }
        return map
    }()

    static func definition(for id: AchievementID) -> AchievementDefinition? {
        definitionById[id]
    }

    static func unlockedIds(for stats: ProfileAchievementStats) -> Set<AchievementID> {
        var set = Set<AchievementID>()
        for def in definitions where def.isUnlocked(stats) {
            set.insert(def.id)
        }
        return set
    }

    /// Ids that became unlocked when moving from `before` stats to `after` stats.
    static func newlyUnlocked(before beforeStats: ProfileAchievementStats, after afterStats: ProfileAchievementStats) -> [AchievementID] {
        let beforeSet = unlockedIds(for: beforeStats)
        let afterSet = unlockedIds(for: afterStats)
        let fresh = afterSet.subtracting(beforeSet)
        return definitions.map(\.id).filter { fresh.contains($0) }
    }

    static var totalCount: Int { definitions.count }

    static func unlockedCount(for stats: ProfileAchievementStats) -> Int {
        unlockedIds(for: stats).count
    }

    static func toastMessage(for id: AchievementID) -> String {
        guard let def = definition(for: id) else { return "Achievement unlocked" }
        return "Unlocked: \(def.title)"
    }
}
