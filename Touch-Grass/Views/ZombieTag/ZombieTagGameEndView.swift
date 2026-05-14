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
    let gameService: GameService
    let onPlayAgain: () -> Void
    let onBackToLobby: () -> Void
    
    var body: some View {
        ZStack {
            ThemeBackgroundView(
                primaryColor: AppColors.zombiePrimary,
                secondaryColor: AppColors.zombieSecondary,
                lightColor: AppColors.zombieLight
            )
            
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
    
    private var winnerSection: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: winnerIcon)
                .font(.system(size: 60))
                .foregroundStyle(winnerGradient)
                .symbolEffect(.bounce, options: .repeating)

            Text(outcome.eyebrow)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(2.2)
                .foregroundColor(AppColors.cartoonInk.opacity(0.55))

            Text(outcome.title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(winnerGradient)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.55)
                .lineLimit(2)

            Text(outcome.subtitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity)
        .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
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
                HStack(alignment: .firstTextBaseline) {
                    Text("Longest Survival:")
                        .font(AppTypography.bodyMedium())
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: AppSpacing.sm)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(player.displayName)
                            .font(AppTypography.labelSmall())
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .multilineTextAlignment(.trailing)
                        Text(timeString(from: longest.time))
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
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
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(count)")
                                .font(AppTypography.labelSmall())
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.zombiePrimary)
                                .layoutPriority(1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
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
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if player.id == currentPlayer?.id {
                            Text("(You)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                                .layoutPriority(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if player.id == currentPlayer?.id {
                            Text("(You)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                                .layoutPriority(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .minimumScaleFactor(0.75)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if player.id == currentPlayer?.id {
                            Text("(You)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                                .layoutPriority(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
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
            .buttonStyle(CartoonButtonStyle(accent: AppColors.zombiePrimary))
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
            .buttonStyle(CartoonSecondaryButtonStyle())
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
            .buttonStyle(CartoonSecondaryButtonStyle())
            .accessibilityLabel("Back to lobby")
            .accessibilityHint("Returns to the game lobby")
        }
        .frame(maxWidth: .infinity)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [shareText])
        }
    }
    
    private var shareText: String {
        let duration = timeString(from: gameStats.totalGameDuration())
        let catches = gameStats.catches.count

        return """
        🎮 Touch Grass - Zombie Tag Game Results
        
        \(outcome.title)
        Duration: \(duration)
        Total Infections: \(catches)
        
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

    private var winnerIcon: String {
        switch gameStats.winner {
        case .hunters:
            return "figure.walk.motion"
        case .hiders, .timeUp:
            return "figure.run"
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
        case .hiders, .timeUp:
            return LinearGradient(
                colors: [AppColors.humanPrimary, AppColors.humanSecondary],
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
