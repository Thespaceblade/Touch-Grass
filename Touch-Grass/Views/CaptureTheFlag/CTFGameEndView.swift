//
//  CTFGameEndView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct CTFGameEndView: View {
    let session: GameSession
    let gameStats: GameStats
    let currentPlayer: Player?
    let gameService: GameService
    let canManageNextRound: Bool
    let onPlayAgain: () -> Void
    let onBackToLobby: () -> Void
    
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            // Team-colored gradient background
            LinearGradient(
                colors: [winnerPrimaryColor, winnerDarkColor],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Cartoon confetti overlay
            confettiOverlay

            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    Spacer().frame(height: AppSpacing.lg)
                    winnerSection
                    statsSection
                    rankingsSection
                    actionButtons
                    Spacer().frame(height: AppSpacing.lg)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.md)
            }
            .safeAreaPadding(.bottom, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            gameService.applyPostGameProfileOutcome(
                session: session,
                gameStats: gameStats,
                currentPlayer: currentPlayer
            )
        }
    }

    // MARK: - Confetti

    private var confettiOverlay: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let colors: [Color] = [AppColors.cartoonSun, .white, AppColors.ctfLight, AppColors.ctfTeamB.opacity(0.8)]
                for i in 0..<34 {
                    let x = CGFloat((i * 37) % Int(size.width))
                    let y = CGFloat((i * 53) % Int(size.height))
                    let w = CGFloat(5 + i % 6)
                    let h = CGFloat(9 + i % 4)
                    let color = colors[i % colors.count]
                    let rect = CGRect(x: x, y: y, width: w, height: h)
                    context.fill(Path(rect), with: .color(color.opacity(0.55)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Winner Section

    private var winnerSection: some View {
        VStack(spacing: 12) {
            Text(outcome.eyebrow)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .tracking(2.2)

            Text(outcome.title)
                .font(.system(size: 56, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.45)
                .lineLimit(2)
                .shadow(color: AppColors.cartoonInk.opacity(0.4), radius: 0, x: 3, y: 3)

            Text(outcome.subtitle)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)

            HStack(spacing: 6) {
                Image(systemName: badgeIcon)
                    .font(.system(size: 14, weight: .bold))
                Text("\(badgeLeading) · \(timeString(from: gameStats.totalGameDuration()))")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .multilineTextAlignment(.center)
            }
            .foregroundColor(AppColors.cartoonInkOnSunFill)
            .padding(.vertical, 5)
            .padding(.horizontal, 14)
            .background(AppColors.cartoonSun2)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.cartoonInkOnSunFill, lineWidth: 2))
            .background(Capsule().fill(Color(white: 0.18)).offset(x: 2, y: 2))
        }
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        CartoonCard(padding: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Game Statistics")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(winnerPrimaryColor.opacity(0.9))
                    .padding(.bottom, 10)

                statsRow(label: "Game Duration", value: timeString(from: gameStats.totalGameDuration()), isLast: false)
                statsRow(label: "Final Score",
                         value: "\(session.teamAScore) – \(session.teamBScore)",
                         isLast: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statsRow(label: String, value: String, isLast: Bool) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.cartoonInk.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundColor(AppColors.cartoonInk)
        }
        .padding(.vertical, 7)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AppColors.cartoonInk.opacity(0.12))
                    .frame(height: 1.5)
            }
        }
    }

    // MARK: - Rankings Section

    private var rankingsSection: some View {
        CartoonCard(padding: 14) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Final Standings")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundColor(winnerPrimaryColor.opacity(0.9))
                    .padding(.bottom, 10)

                let allPlayers = buildStandings()
                ForEach(Array(allPlayers.enumerated()), id: \.offset) { idx, entry in
                    standingsRow(rank: idx + 1, name: entry.name, team: entry.team,
                                 teamColor: entry.teamColor, isYou: entry.isYou,
                                 isLast: idx == allPlayers.count - 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct StandingEntry {
        let name: String
        let team: String
        let teamColor: Color
        let isYou: Bool
    }

    private func buildStandings() -> [StandingEntry] {
        let winTeam: Flag.Team? = gameStats.winner == .teamA ? .teamA : (gameStats.winner == .teamB ? .teamB : nil)
        let order: [Flag.Team]
        if let wt = winTeam {
            order = [wt, wt.opposite]
        } else {
            // Draw or no result: list Team A then Team B so the card is never empty.
            order = [.teamA, .teamB]
        }

        var entries: [StandingEntry] = []
        for team in order {
            for p in session.players.filter({ $0.team == team }) {
                entries.append(StandingEntry(
                    name: p.displayName,
                    team: team.rawValue,
                    teamColor: team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB,
                    isYou: p.id == currentPlayer?.id
                ))
            }
        }
        return entries
    }

    private func standingsRow(rank: Int, name: String, team: String, teamColor: Color, isYou: Bool, isLast: Bool) -> some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                .frame(width: 22, alignment: .center)
            Text(name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(AppColors.cartoonInk)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isYou {
                Text("(you)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                    .layoutPriority(1)
            }
            CartoonPill(text: team, color: teamColor)
                .layoutPriority(1)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AppColors.cartoonInk.opacity(0.12))
                    .frame(height: 1.5)
            }
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: AppSpacing.sm) {
            if canManageNextRound {
                Button(action: { HapticFeedbackManager.shared.selection(); onPlayAgain() }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "arrow.clockwise").font(.title3)
                        Text("Play Again")
                    }
                }
                .buttonStyle(CartoonButtonStyle(accent: AppColors.cartoonSun, textColor: AppColors.cartoonInkOnSunFill, borderColor: AppColors.cartoonInkOnSunFill))
            }

            Button(action: { HapticFeedbackManager.shared.selection(); showShareSheet = true }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "square.and.arrow.up").font(.title3)
                    Text("Share Results")
                }
            }
            .buttonStyle(CartoonSecondaryButtonStyle())

            if canManageNextRound {
                Button(action: { HapticFeedbackManager.shared.selection(); onBackToLobby() }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "house.fill").font(.title3)
                        Text("Back to Lobby")
                    }
                }
                .buttonStyle(CartoonSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
    
    private var shareText: String {
        let duration = timeString(from: gameStats.totalGameDuration())
        let finalScore = "\(session.teamAScore) - \(session.teamBScore)"

        return """
        🎮 Touch Grass - Capture The Flag Game Results
        
        \(outcome.title)
        Final Score: \(finalScore)
        Duration: \(duration)
        
        Played on Touch Grass!
        """
    }
    
    // MARK: - Computed Properties

    private var outcome: GameEndOutcomeDisplay {
        GameEndOutcomeDisplay.display(
            gameType: session.gameType,
            winner: gameStats.winner,
            session: session,
            gameStats: gameStats
        )
    }

    private var badgeIcon: String {
        if outcome.isDraw { return "clock.fill" }
        if outcome.isNeutral { return "flag.checkered" }
        return "trophy.fill"
    }

    private var badgeLeading: String {
        if outcome.isDraw { return "Time ran out" }
        if outcome.isNeutral { return "Game ended" }
        return "Flag scored"
    }

    private var winnerPrimaryColor: Color {
        switch gameStats.winner {
        case .teamA:  return AppColors.ctfTeamA
        case .teamB:  return AppColors.ctfTeamB
        default:      return AppColors.ctfPrimary
        }
    }

    private var winnerDarkColor: Color {
        switch gameStats.winner {
        case .teamA:  return AppColors.ctfDark
        case .teamB:  return AppColors.manhuntDark
        default:      return AppColors.ctfDark
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
