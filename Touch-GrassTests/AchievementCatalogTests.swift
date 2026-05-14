//
//  AchievementCatalogTests.swift
//  Touch-GrassTests
//

import XCTest
@testable import Touch_Grass

final class AchievementCatalogTests: XCTestCase {

    func testNewlyUnlockedDetectsFreshIds() {
        let before = ProfileAchievementStats(
            totalGamesPlayed: 0,
            totalWins: 0,
            totalPlaytimeSeconds: 0,
            gamesManhunt: 0,
            gamesZombieTag: 0,
            gamesCTF: 0,
            winsManhunt: 0,
            winsZombieTag: 0,
            winsCTF: 0,
            totalPredatorTags: 0,
            timesFirstTagged: 0,
            zombieHordeWins: 0,
            humanSurvivalWins: 0
        )
        var after = before
        after.totalGamesPlayed = 1
        after.totalWins = 1

        let fresh = AchievementCatalog.newlyUnlocked(before: before, after: after)
        XCTAssertTrue(fresh.contains(.firstSteps))
        XCTAssertTrue(fresh.contains(.firstWin))
    }

    func testNewlyUnlockedEmptyWhenNoChange() {
        let stats = ProfileAchievementStats(
            totalGamesPlayed: 5,
            totalWins: 2,
            totalPlaytimeSeconds: 100,
            gamesManhunt: 2,
            gamesZombieTag: 1,
            gamesCTF: 1,
            winsManhunt: 1,
            winsZombieTag: 0,
            winsCTF: 0,
            totalPredatorTags: 3,
            timesFirstTagged: 0,
            zombieHordeWins: 0,
            humanSurvivalWins: 0
        )
        let fresh = AchievementCatalog.newlyUnlocked(before: stats, after: stats)
        XCTAssertTrue(fresh.isEmpty)
    }

    func testTripleThreatUnlocksWhenAllModesPlayed() {
        let before = ProfileAchievementStats(
            totalGamesPlayed: 3,
            totalWins: 0,
            totalPlaytimeSeconds: 0,
            gamesManhunt: 1,
            gamesZombieTag: 1,
            gamesCTF: 0,
            winsManhunt: 0,
            winsZombieTag: 0,
            winsCTF: 0,
            totalPredatorTags: 0,
            timesFirstTagged: 0,
            zombieHordeWins: 0,
            humanSurvivalWins: 0
        )
        var after = before
        after.gamesCTF = 1
        after.totalGamesPlayed = 4

        let fresh = AchievementCatalog.newlyUnlocked(before: before, after: after)
        XCTAssertTrue(fresh.contains(.tripleThreat))
    }
}
