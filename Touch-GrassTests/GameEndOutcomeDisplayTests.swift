//
//  GameEndOutcomeDisplayTests.swift
//  Touch-GrassTests
//

import XCTest
@testable import Touch_Grass

final class GameEndOutcomeDisplayTests: XCTestCase {

    private func makeSession(gameType: GameType, teamAScore: Int = 0, teamBScore: Int = 0) -> GameSession {
        GameSession(
            hostId: "host",
            gameType: gameType,
            teamAScore: teamAScore,
            teamBScore: teamBScore
        )
    }

    private func makeStats(_ winner: GameStats.GameWinner?) -> GameStats {
        var stats = GameStats(gameStartTime: Date())
        stats.winner = winner
        stats.gameEndTime = Date()
        return stats
    }

    func testCTFTimeUpWithEqualScoresIsDraw() {
        let session = makeSession(gameType: .captureTheFlag, teamAScore: 2, teamBScore: 2)
        let stats = makeStats(.timeUp)

        let outcome = GameEndOutcomeDisplay.display(
            gameType: .captureTheFlag,
            winner: stats.winner,
            session: session,
            gameStats: stats
        )

        XCTAssertTrue(outcome.isDraw)
        XCTAssertTrue(outcome.isNeutral)
        XCTAssertEqual(outcome.eyebrow, "DRAW")
        XCTAssertEqual(outcome.title, "Draw!")
    }

    func testManhuntTimeUpReadsAsHidersWin() {
        let session = makeSession(gameType: .manhunt)
        let stats = makeStats(.timeUp)

        let outcome = GameEndOutcomeDisplay.display(
            gameType: .manhunt,
            winner: stats.winner,
            session: session,
            gameStats: stats
        )

        XCTAssertFalse(outcome.isDraw)
        XCTAssertFalse(outcome.isNeutral)
        XCTAssertEqual(outcome.eyebrow, "WINNER")
        XCTAssertEqual(outcome.title, "Hiders Win!")
    }

    func testZombieTimeUpReadsAsHumansWin() {
        let session = makeSession(gameType: .zombieTag)
        let stats = makeStats(.timeUp)

        let outcome = GameEndOutcomeDisplay.display(
            gameType: .zombieTag,
            winner: stats.winner,
            session: session,
            gameStats: stats
        )

        XCTAssertEqual(outcome.title, "Humans Win!")
        XCTAssertEqual(outcome.eyebrow, "WINNER")
    }

    func testNilWinnerIsNoResult() {
        let session = makeSession(gameType: .manhunt)
        let stats = makeStats(nil)

        let outcome = GameEndOutcomeDisplay.display(
            gameType: .manhunt,
            winner: stats.winner,
            session: session,
            gameStats: stats
        )

        XCTAssertTrue(outcome.isNeutral)
        XCTAssertFalse(outcome.isDraw)
        XCTAssertEqual(outcome.eyebrow, "RESULT")
        XCTAssertEqual(outcome.title, "No result")
    }

    func testCTFTeamAWinsTitle() {
        let session = makeSession(gameType: .captureTheFlag, teamAScore: 3, teamBScore: 1)
        let stats = makeStats(.teamA)

        let outcome = GameEndOutcomeDisplay.display(
            gameType: .captureTheFlag,
            winner: stats.winner,
            session: session,
            gameStats: stats
        )

        XCTAssertEqual(outcome.title, "Team A Wins!")
        XCTAssertEqual(outcome.eyebrow, "WINNER")
        XCTAssertFalse(outcome.isNeutral)
    }
}
