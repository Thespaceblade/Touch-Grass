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
    let onPlayAgain: () -> Void
    let onBackToLobby: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient (CTF theme)
            LinearGradient(
                colors: [
                    AppColors.ctfPrimary.opacity(0.2),
                    AppColors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: AppSpacing.xl) {
                    Spacer()
                        .frame(height: AppSpacing.lg)
                    
                    // Winner announcement
                    winnerSection
                    
                    // Game statistics
                    statsSection
                    
                    // Player rankings
                    rankingsSection
                    
                    // Action buttons
                    actionButtons
                    
                    Spacer()
                        .frame(height: AppSpacing.lg)
                }
                .padding(.horizontal, AppSpacing.md)
            }
        }
    }
    
    private var winnerSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Winner icon
            Image(systemName: winnerIcon)
                .font(.system(size: 60))
                .foregroundStyle(winnerGradient)
                .symbolEffect(.bounce, options: .repeating)
            
            // Winner text
            Text(winnerText)
                .font(AppTypography.displayMedium())
                .foregroundStyle(winnerGradient)
                .multilineTextAlignment(.center)
            
            // Subtitle
            Text(winnerSubtitle)
                .font(AppTypography.bodyMedium())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Game Statistics")
                .font(AppTypography.headlineSmall())
                .fontWeight(.bold)
            
            Divider()
            
            // Game duration
            HStack {
                Text("Game Duration:")
                    .font(AppTypography.bodyMedium())
                Spacer()
                Text(timeString(from: gameStats.totalGameDuration()))
                    .font(AppTypography.labelMedium())
                    .fontWeight(.semibold)
            }
            
            // Final scores (CTF-specific)
            HStack {
                Text("Final Score:")
                    .font(AppTypography.bodyMedium())
                Spacer()
                HStack(spacing: AppSpacing.sm) {
                    Text("\(session.teamAScore)")
                        .font(AppTypography.labelMedium())
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.ctfTeamA)
                    Text("-")
                        .font(AppTypography.labelMedium())
                        .foregroundColor(AppColors.textSecondary)
                    Text("\(session.teamBScore)")
                        .font(AppTypography.labelMedium())
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.ctfTeamB)
                }
            }
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    private var rankingsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Final Standings")
                .font(AppTypography.headlineSmall())
                .fontWeight(.bold)
            
            Divider()
            
            // CTF: Show winning team
            let winningTeam = gameStats.winner == .teamA ? Flag.Team.teamA : (gameStats.winner == .teamB ? Flag.Team.teamB : nil)
            if let team = winningTeam {
                let teamPlayers = session.players.filter { $0.team == team }
                Text("Winning Team: \(team.rawValue)")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB)
                
                ForEach(teamPlayers) { player in
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB)
                        Text(player.displayName)
                            .font(AppTypography.bodyMedium())
                        if player.id == currentPlayer?.id {
                            Text("(You)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            
            // CTF: No eliminated players - show losing team instead
            let losingTeam = gameStats.winner == .teamA ? Flag.Team.teamB : (gameStats.winner == .teamB ? Flag.Team.teamA : nil)
            if let team = losingTeam {
                Divider()
                Text("Losing Team: \(team.rawValue)")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB)
                
                let teamPlayers = session.players.filter { $0.team == team }
                ForEach(teamPlayers) { player in
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(team == .teamA ? AppColors.ctfTeamA.opacity(0.5) : AppColors.ctfTeamB.opacity(0.5))
                        Text(player.displayName)
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textSecondary)
                        if player.id == currentPlayer?.id {
                            Text("(You)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    @State private var showShareSheet = false
    
    private var actionButtons: some View {
        VStack(spacing: AppSpacing.md) {
            // Play Again button
            Button(action: {
                HapticFeedbackManager.shared.selection()
                onPlayAgain()
            }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                    Text("Play Again")
                        .font(AppTypography.labelLarge())
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Play again")
            .accessibilityHint("Starts a new game with the same settings")
            
            // Share button
            Button(action: {
                HapticFeedbackManager.shared.selection()
                showShareSheet = true
            }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                    Text("Share Results")
                        .font(AppTypography.labelLarge())
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Share results")
            .accessibilityHint("Share your game results")
            
            // Back to Lobby button
            Button(action: {
                HapticFeedbackManager.shared.selection()
                onBackToLobby()
            }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "house.fill")
                        .font(.title3)
                    Text("Back to Lobby")
                        .font(AppTypography.labelLarge())
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("Back to lobby")
            .accessibilityHint("Returns to the game lobby")
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
    
    private var shareText: String {
        let winnerText: String
        winnerText = gameStats.winner == .teamA ? "Team A" : (gameStats.winner == .teamB ? "Team B" : "Time's Up")
        let duration = timeString(from: gameStats.totalGameDuration())
        let gameTypeName = "Capture The Flag"
        let finalScore = "\(session.teamAScore) - \(session.teamBScore)"
        
        return """
        🎮 Touch Grass - \(gameTypeName) Game Results
        
        Winner: \(winnerText)
        Final Score: \(finalScore)
        Duration: \(duration)
        
        Played on Touch Grass!
        """
    }
    
    // MARK: - Computed Properties
    
    private var winnerText: String {
        switch gameStats.winner {
        case .teamA:
            return "🏆 Team A Wins!"
        case .teamB:
            return "🏆 Team B Wins!"
        case .timeUp:
            return "⏰ Time's Up!"
        case .none:
            return "Game Over"
        default:
            return "Game Over"
        }
    }
    
    private var winnerSubtitle: String {
        switch gameStats.winner {
        case .teamA:
            return "Team A captured both flags!"
        case .teamB:
            return "Team B captured both flags!"
        case .timeUp:
            return "Time ran out!"
        case .none:
            return "The game has ended."
        default:
            return "The game has ended."
        }
    }
    
    private var winnerIcon: String {
        switch gameStats.winner {
        case .teamA, .teamB:
            return "flag.fill"
        case .timeUp:
            return "clock.fill"
        case .none:
            return "flag.fill"
        default:
            return "flag.fill"
        }
    }
    
    private var winnerGradient: LinearGradient {
        switch gameStats.winner {
        case .teamA:
            return LinearGradient(
                colors: [AppColors.ctfTeamA, AppColors.ctfTeamASecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .teamB:
            return LinearGradient(
                colors: [AppColors.ctfTeamB, AppColors.ctfTeamBSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .timeUp, .none:
            return LinearGradient(
                colors: [AppColors.textPrimary, AppColors.textSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [AppColors.textPrimary, AppColors.textSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
