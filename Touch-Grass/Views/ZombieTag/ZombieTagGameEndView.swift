//
//  ZombieTagGameEndView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ZombieTagGameEndView: View {
    let session: GameSession
    let gameStats: GameStats
    let currentPlayer: Player?
    let onPlayAgain: () -> Void
    let onBackToLobby: () -> Void
    
    var body: some View {
        ZStack {
            // Background gradient (ZombieTag theme)
            LinearGradient(
                colors: [
                    AppColors.zombiePrimary.opacity(0.2),
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
            
            // Total Infections (for Zombie Tag)
            HStack {
                Text("Total Infections:")
                    .font(AppTypography.bodyMedium())
                Spacer()
                Text("\(gameStats.catches.count)")
                    .font(AppTypography.labelMedium())
                    .fontWeight(.semibold)
            }
            
            // Longest survival
            if let longest = gameStats.longestSurvival(),
               let player = session.players.first(where: { $0.id == longest.playerId }) {
                Divider()
                HStack {
                    Text("Longest Survival:")
                        .font(AppTypography.bodyMedium())
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(player.displayName)
                            .font(AppTypography.labelSmall())
                            .fontWeight(.semibold)
                        Text(timeString(from: longest.time))
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            // Infections by zombie
            let catchesByHunter = gameStats.catchesByHunter()
            if !catchesByHunter.isEmpty {
                Divider()
                Text("Infections by Zombie:")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                
                ForEach(Array(catchesByHunter.sorted(by: { $0.value > $1.value })), id: \.key) { zombieId, count in
                    if let zombie = session.players.first(where: { $0.id == zombieId }) {
                        HStack {
                            Text(zombie.displayName)
                                .font(AppTypography.bodySmall())
                            Spacer()
                            Text("\(count)")
                                .font(AppTypography.labelSmall())
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.zombiePrimary)
                        }
                    }
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
            
            // Zombie Tag: Show survivors (humans) and zombies
            let alivePlayers = session.players.filter { $0.isAlive }
            let zombies = alivePlayers.filter { $0.role == .zombie }
            let humans = alivePlayers.filter { $0.role == .human }
            
            if !zombies.isEmpty {
                Text("Zombies")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.zombiePrimary)
                
                ForEach(zombies) { player in
                    HStack {
                        Image(systemName: "figure.walk.motion")
                            .foregroundColor(AppColors.zombiePrimary)
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
            
            if !humans.isEmpty {
                if !zombies.isEmpty {
                    Divider()
                }
                Text("Humans")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.humanPrimary)
                
                ForEach(humans) { player in
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundColor(AppColors.humanPrimary)
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
            
            // Eliminated players
            let eliminatedPlayers = session.players.filter { !$0.isAlive }
            if !eliminatedPlayers.isEmpty {
                Divider()
                Text("Eliminated")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                
                ForEach(eliminatedPlayers) { player in
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.error)
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
        winnerText = gameStats.winner == .hunters ? "Zombies" : (gameStats.winner == .hiders ? "Humans" : "Time's Up")
        let duration = timeString(from: gameStats.totalGameDuration())
        let gameTypeName = "Zombie Tag"
        let catches = gameStats.catches.count
        
        return """
        🎮 Touch Grass - \(gameTypeName) Game Results
        
        Winner: \(winnerText)
        Duration: \(duration)
        Total Infections: \(catches)
        
        Played on Touch Grass!
        """
    }
    
    // MARK: - Computed Properties
    
    private var winnerText: String {
        switch gameStats.winner {
        case .hunters:
            return "🧟 Zombies Win!"
        case .hiders:
            return "🏃 Humans Win!"
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
        case .hunters:
            return "All humans were infected!"
        case .hiders:
            return "Some humans survived!"
        case .timeUp:
            return "The zone closed completely!"
        case .none:
            return "The game has ended."
        default:
            return "The game has ended."
        }
    }
    
    private var winnerIcon: String {
        switch gameStats.winner {
        case .hunters:
            return "figure.walk.motion"
        case .hiders:
            return "figure.run"
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
        case .hunters:
            return LinearGradient(
                colors: [AppColors.zombiePrimary, AppColors.zombieSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hiders:
            return LinearGradient(
                colors: [AppColors.humanPrimary, AppColors.humanSecondary],
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
