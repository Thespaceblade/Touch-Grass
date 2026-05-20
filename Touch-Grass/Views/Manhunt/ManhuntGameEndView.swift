//
//  ManhuntGameEndView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ManhuntGameEndView: View {
    let session: GameSession
    let gameStats: GameStats
    let currentPlayer: Player?
    let gameService: GameService
    let canManageNextRound: Bool
    let onPlayAgain: () -> Void
    let onBackToLobby: () -> Void
    
    @State private var showCelebration = false
    @State private var confettiOffset: CGFloat = 0
    @State private var trophyScale: CGFloat = 0.5
    @State private var profilePicturesVisible: [Bool] = []
    @State private var borderPulse: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            ThemeBackgroundView(
                primaryColor: AppColors.hunterPrimary,
                secondaryColor: AppColors.hunterSecondary,
                lightColor: AppColors.manhuntLight
            )
            
            // Celebration confetti (if won)
            if showCelebration && hasTeamOutcome {
                celebrationConfetti
            }
            
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
                .padding(.leading, AppSpacing.md)
                .padding(.trailing, AppSpacing.md + 5) // +5 absorbs cartoon shadow right bleed
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

            let won = (gameStats.winner == .hunters && currentPlayer?.role == .hunter) ||
                     ((gameStats.winner == .hiders || gameStats.winner == .timeUp) && currentPlayer?.role == .hider)
            let winningPlayers = getWinningTeamPlayers()
            profilePicturesVisible = Array(repeating: false, count: winningPlayers.count)
            
            // Trigger celebration if won
            if won {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                    showCelebration = true
                    trophyScale = 1.0
                }
                
                // Animate confetti
                withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                    confettiOffset = 360
                }
                
                // Staggered profile picture entrance animation
                for index in 0..<winningPlayers.count {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.2)) {
                        if index < profilePicturesVisible.count {
                            profilePicturesVisible[index] = true
                        }
                    }
                }
                
                // Border pulse animation
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    borderPulse = 1.15
                }
            } else {
                trophyScale = 1.0
                // Still show profile pictures even if current player didn't win
                if hasTeamOutcome {
                    let losingTeamPlayers = getWinningTeamPlayers()
                    for index in 0..<losingTeamPlayers.count {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.1 + 0.2)) {
                            if index < profilePicturesVisible.count {
                                profilePicturesVisible[index] = true
                            }
                        }
                    }
                    
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                        borderPulse = 1.15
                    }
                }
            }
        }
    }
    
    private var winnerSection: some View {
        VStack(spacing: AppSpacing.lg) {
            // Winner profile pictures (if a team survived); otherwise neutral icon.
            if hasTeamOutcome {
                winningTeamProfiles
            } else {
                ZStack {
                    if showCelebration {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        winnerGlowColor.opacity(0.3),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 20,
                                    endRadius: 80
                                )
                            )
                            .frame(width: 160, height: 160)
                            .blur(radius: 20)
                    }
                    
                    Image(systemName: winnerIcon)
                        .font(.system(size: 60))
                        .foregroundStyle(winnerGradient)
                        .scaleEffect(trophyScale)
                        .symbolEffect(.bounce, options: showCelebration ? .repeating : .default)
                }
            }

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
                .scaleEffect(showCelebration ? 1.05 : 1.0)

            Text(outcome.subtitle)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
    }
    
    private var winningTeamProfiles: some View {
        let winningPlayers = getWinningTeamPlayers()
        let teamColor = getTeamColor()
        let teamSecondaryColor = getTeamSecondaryColor()
        let avatarSize: CGFloat = winningPlayers.count <= 3 ? 68 : 54
        let rowSpacing: CGFloat = winningPlayers.count <= 3 ? AppSpacing.sm : AppSpacing.xs

        return ZStack {
            // Decorative glow — kept in `.background` so it never inflates layout width on large teams.
            Color.clear
                .background {
                    if showCelebration {
                        let glowDiameter = min(280, max(200, CGFloat(winningPlayers.count) * 44 + 72))
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        teamColor.opacity(0.2),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 40,
                                    endRadius: glowDiameter * 0.5
                                )
                            )
                            .frame(width: glowDiameter, height: glowDiameter)
                            .blur(radius: 30)
                            .scaleEffect(borderPulse)
                    }
                }

            Group {
                if winningPlayers.count <= 3 {
                    HStack(spacing: rowSpacing) {
                        ForEach(Array(winningPlayers.enumerated()), id: \.element.id) { index, player in
                            profilePictureView(
                                player: player,
                                teamColor: teamColor,
                                teamSecondaryColor: teamSecondaryColor,
                                index: index,
                                size: avatarSize
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: rowSpacing) {
                            ForEach(Array(winningPlayers.enumerated()), id: \.element.id) { index, player in
                                profilePictureView(
                                    player: player,
                                    teamColor: teamColor,
                                    teamSecondaryColor: teamSecondaryColor,
                                    index: index,
                                    size: avatarSize
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.xs)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
    
    private func profilePictureView(
        player: Player,
        teamColor: Color,
        teamSecondaryColor: Color,
        index: Int,
        size: CGFloat = 70
    ) -> some View {
        let isVisible = index < profilePicturesVisible.count ? profilePicturesVisible[index] : false
        let pictureSize = size - 10
        let borderSize = size
        
        return ZStack {
            // Outer glow ring (animated)
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            teamColor.opacity(0.6),
                            teamSecondaryColor.opacity(0.4),
                            teamColor.opacity(0.6)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4
                )
                .frame(width: borderSize, height: borderSize)
                .scaleEffect(borderPulse)
                .opacity(isVisible ? 1.0 : 0.0)
            
            // Middle border ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [teamColor, teamSecondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 3
                )
                .frame(width: borderSize - 4, height: borderSize - 4)
                .opacity(isVisible ? 1.0 : 0.0)
            
            // Profile picture
            Group {
                if let profilePicBase64 = player.profilePictureBase64,
                   let imageData = Data(base64Encoded: profilePicBase64),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: pictureSize, height: pictureSize)
                        .clipShape(Circle())
                } else {
                    // Fallback: role icon
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        teamColor.opacity(0.3),
                                        teamSecondaryColor.opacity(0.2)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: pictureSize, height: pictureSize)
                        
                        Image(systemName: player.role == .hunter ? "target" : "eye.slash.fill")
                            .font(.system(size: pictureSize * 0.4, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [teamColor, teamSecondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
            }
            .scaleEffect(isVisible ? 1.0 : 0.3)
            .opacity(isVisible ? 1.0 : 0.0)
        }
        .animation(
            .spring(response: 0.6, dampingFraction: 0.7)
            .delay(Double(index) * 0.1),
            value: isVisible
        )
    }
    
    private var hasTeamOutcome: Bool {
        switch gameStats.winner {
        case .hunters, .hiders, .timeUp: return true
        default: return false
        }
    }

    private func getWinningTeamPlayers() -> [Player] {
        switch gameStats.winner {
        case .hunters:
            return session.players.filter { $0.role == .hunter && $0.isAlive }
        case .hiders, .timeUp:
            return session.players.filter { $0.role == .hider && $0.isAlive }
        default:
            return []
        }
    }
    
    private func getTeamColor() -> Color {
        switch gameStats.winner {
        case .hunters:
            return AppColors.hunterPrimary
        case .hiders, .timeUp:
            return AppColors.hiderPrimary
        default:
            return AppColors.textPrimary
        }
    }
    
    private func getTeamSecondaryColor() -> Color {
        switch gameStats.winner {
        case .hunters:
            return AppColors.hunterSecondary
        case .hiders, .timeUp:
            return AppColors.hiderSecondary
        default:
            return AppColors.textSecondary
        }
    }
    
    // MARK: - Celebration Effects
    
    private var celebrationConfetti: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<30, id: \.self) { index in
                    Circle()
                        .fill([
                            AppColors.grassPrimary,
                            AppColors.grassSecondary,
                            AppColors.manhuntPrimary,
                            AppColors.ctfPrimary,
                            AppColors.zombiePrimary
                        ][index % 5])
                        .frame(width: 8, height: 8)
                        .offset(
                            x: CGFloat.random(in: 0...geometry.size.width),
                            y: CGFloat(index) * 50 + confettiOffset
                        )
                        .opacity(0.8)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
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
            
            // Total Catches (for Manhunt)
            HStack {
                Text("Total Catches:")
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
            
            // Catches by hunter
            let catchesByHunter = gameStats.catchesByHunter()
            if !catchesByHunter.isEmpty {
                Divider()
                Text("Catches by Hunter:")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
                
                ForEach(Array(catchesByHunter.sorted(by: { $0.value > $1.value })), id: \.key) { hunterId, count in
                    if let hunter = session.players.first(where: { $0.id == hunterId }) {
                        HStack {
                            Text(hunter.displayName)
                                .font(AppTypography.bodySmall())
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .minimumScaleFactor(0.75)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(count)")
                                .font(AppTypography.labelSmall())
                                .fontWeight(.semibold)
                                .foregroundColor(AppColors.hunterPrimary)
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
            
            // Manhunt: Show survivors (hiders) and hunters
            let alivePlayers = session.players.filter { $0.isAlive }
            let hunters = alivePlayers.filter { $0.role == .hunter }
            let hiders = alivePlayers.filter { $0.role == .hider }
            
            if !hunters.isEmpty {
                Text("Hunters")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.hunterPrimary)
                
                ForEach(hunters) { player in
                    HStack {
                        Image(systemName: "figure.walk.motion")
                            .foregroundColor(AppColors.hunterPrimary)
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
            
            if !hiders.isEmpty {
                if !hunters.isEmpty {
                    Divider()
                }
                Text("Hiders")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.hiderPrimary)
                
                ForEach(hiders) { player in
                    HStack {
                        Image(systemName: "figure.run")
                            .foregroundColor(AppColors.hiderPrimary)
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
            if canManageNextRound {
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
                .buttonStyle(CartoonButtonStyle(accent: AppColors.hunterPrimary))
                .accessibilityLabel("Play again")
                .accessibilityHint("Starts a new game with the same settings")
            }
            
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
            if canManageNextRound {
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
        🎮 Touch Grass - Manhunt Game Results
        
        \(outcome.title)
        Duration: \(duration)
        Total Catches: \(catches)
        
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
            return "target"
        case .hiders, .timeUp:
            return "person.2.fill"
        default:
            return "flag.fill"
        }
    }
    
    private var winnerGradient: LinearGradient {
        switch gameStats.winner {
        case .hunters:
            return LinearGradient(
                colors: [AppColors.hunterPrimary, AppColors.hunterSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hiders, .timeUp:
            return LinearGradient(
                colors: [AppColors.hiderPrimary, AppColors.hiderSecondary],
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
    
    private var winnerGlowColor: Color {
        switch gameStats.winner {
        case .hunters:
            return AppColors.hunterPrimary
        case .hiders, .timeUp:
            return AppColors.hiderPrimary
        default:
            return AppColors.textPrimary
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
