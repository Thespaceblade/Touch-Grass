//
//  GameEndOutcomeDisplay.swift
//  Touch-Grass
//
//  Centralized copy for game-end screens. Encodes "[Side] Wins!" headlines,
//  CTF tied-score draws, Manhunt/Zombie timer expiry as survivor wins, and
//  neutral "No result" copy when the winner can't be determined.
//

import Foundation

struct GameEndOutcomeDisplay: Equatable, Sendable {
    /// Small-caps label above the headline. "WINNER" / "DRAW" / "RESULT".
    let eyebrow: String
    /// Big headline. e.g. "Hiders Win!", "Draw!", "No result".
    let title: String
    /// One-line subtitle under the headline.
    let subtitle: String
    /// CTF tied-score time expiry.
    let isDraw: Bool
    /// Draw or no-result: views should use neutral (non team-colored) styling.
    let isNeutral: Bool

    static func display(
        gameType: GameType,
        winner: GameStats.GameWinner?,
        session: GameSession,
        gameStats: GameStats
    ) -> GameEndOutcomeDisplay {
        guard let winner else {
            return .noResult
        }

        switch gameType {
        case .manhunt:
            switch winner {
            case .hunters:
                return .init(
                    eyebrow: "WINNER",
                    title: "Hunters Win!",
                    subtitle: "All hiders were caught!",
                    isDraw: false,
                    isNeutral: false
                )
            case .hiders:
                return .init(
                    eyebrow: "WINNER",
                    title: "Hiders Win!",
                    subtitle: "Some hiders survived!",
                    isDraw: false,
                    isNeutral: false
                )
            case .timeUp:
                // Clock-stop in tag modes = survivors win.
                return .init(
                    eyebrow: "WINNER",
                    title: "Hiders Win!",
                    subtitle: "Time ran out.",
                    isDraw: false,
                    isNeutral: false
                )
            case .teamA, .teamB:
                return .noResult
            }

        case .zombieTag:
            switch winner {
            case .hunters:
                return .init(
                    eyebrow: "WINNER",
                    title: "Zombies Win!",
                    subtitle: "All humans were infected!",
                    isDraw: false,
                    isNeutral: false
                )
            case .hiders:
                return .init(
                    eyebrow: "WINNER",
                    title: "Humans Win!",
                    subtitle: "Some humans survived!",
                    isDraw: false,
                    isNeutral: false
                )
            case .timeUp:
                return .init(
                    eyebrow: "WINNER",
                    title: "Humans Win!",
                    subtitle: "Time ran out.",
                    isDraw: false,
                    isNeutral: false
                )
            case .teamA, .teamB:
                return .noResult
            }

        case .captureTheFlag:
            switch winner {
            case .teamA:
                return .init(
                    eyebrow: "WINNER",
                    title: "Team A Wins!",
                    subtitle: ctfScoreSubtitle(session: session),
                    isDraw: false,
                    isNeutral: false
                )
            case .teamB:
                return .init(
                    eyebrow: "WINNER",
                    title: "Team B Wins!",
                    subtitle: ctfScoreSubtitle(session: session),
                    isDraw: false,
                    isNeutral: false
                )
            case .timeUp:
                // CTF only sets timeUp when scores are tied at expiry.
                if session.teamAScore == session.teamBScore {
                    return .init(
                        eyebrow: "DRAW",
                        title: "Draw!",
                        subtitle: "Same score when time ran out.",
                        isDraw: true,
                        isNeutral: true
                    )
                }
                return .init(
                    eyebrow: "RESULT",
                    title: "Time's Up!",
                    subtitle: ctfScoreSubtitle(session: session),
                    isDraw: false,
                    isNeutral: true
                )
            case .hunters, .hiders:
                return .noResult
            }
        }
    }

    private static func ctfScoreSubtitle(session: GameSession) -> String {
        "Final score \(session.teamAScore)–\(session.teamBScore)."
    }

    private static let noResult = GameEndOutcomeDisplay(
        eyebrow: "RESULT",
        title: "No result",
        subtitle: "Winner couldn't be determined.",
        isDraw: false,
        isNeutral: true
    )
}
