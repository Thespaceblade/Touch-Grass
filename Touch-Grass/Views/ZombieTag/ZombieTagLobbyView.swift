//
//  ZombieTagLobbyView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//
import SwiftUI
import CoreLocation

struct ZombieTagLobbyView: View {
    @ObservedObject var viewModel: GameViewModel
    let onBackToMenu: () -> Void
    #if DEBUG
    @State private var showDebugTestPanel = false
    #endif
    
    @State private var showBubbleSettings = false
    @State private var showJoinGameInput = false
    @State private var showZombieManagement = false
    @State private var showGameInfo = false
    @State private var showNoProfileNameAlert: Bool = false
    @State private var showExitConfirmation: Bool = false
    @State private var gameCode: String = ""
    @State private var bubbleStartRadius: Double = 300
    @State private var bubbleDuration: Double = 300
    @State private var zombieCount: Int = 1
    @State private var contentAppeared: Bool = false
    
    // Hardcoded ZombieTag theme properties
    private var primaryColor: Color {
        AppColors.zombiePrimary
    }
    
    private var secondaryColor: Color {
        AppColors.zombieSecondary
    }
    
    private var lightColor: Color {
        AppColors.zombieLight
    }
    
    private var gameTagline: String {
        "One Infects All"
    }
    
    var body: some View {
        ZStack {
            // Aesthetic Gradient Background
            aestheticBackground
                .ignoresSafeArea()
            
            // Lobby Content Panel
            lobbyContentPanel
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.gameService.session?.id)
        .onAppear {
            // Reset all state when view appears to ensure clean start for this game mode
            bubbleStartRadius = 300
            bubbleDuration = 300
            zombieCount = 1
            gameCode = ""
            showBubbleSettings = false
            showJoinGameInput = false
            showZombieManagement = false
            showGameInfo = false
            
            // Staggered entrance animation
            withAnimation(.smoothTransition.delay(0.1)) {
                contentAppeared = true
            }
        }
        .onChange(of: viewModel.gameService.session?.gameType) { oldValue, newValue in
            // If game type changes, reset all configuration state
            if oldValue != nil && oldValue != newValue {
                bubbleStartRadius = 300
                bubbleDuration = 300
                zombieCount = 1
                gameCode = ""
                showBubbleSettings = false
                showJoinGameInput = false
                showZombieManagement = false
            }
        }
        .sheet(isPresented: $showBubbleSettings) {
            ZombieTagBubbleSettingsView(
                startRadius: $bubbleStartRadius,
                duration: $bubbleDuration,
                zombieCount: $zombieCount,
                onStart: { selectedCenter in
                    print("⚙️ ZombieTagLobbyView: Configure game button pressed")
                    print("   Selected center: \(selectedCenter.latitude), \(selectedCenter.longitude)")
                    // Configure game first, then dismiss sheet
                    viewModel.configureGame(
                        bubbleStartRadius: bubbleStartRadius,
                        duration: bubbleDuration,
                        hunterCount: zombieCount,
                        center: selectedCenter,
                        scoreLimit: nil,
                        teamABase: nil,
                        teamBBase: nil
                    )
                    // Dismiss sheet after configuration
                    showBubbleSettings = false
                },
                userLocation: viewModel.locationService.coordinate,
                maxPlayers: viewModel.gameService.session?.players.count ?? 1
            )
        }
        .sheet(isPresented: $showZombieManagement) {
            if let session = viewModel.gameService.session {
                ZombieTagRoleManagementView(
                    session: session,
                    currentPlayer: viewModel.gameService.currentPlayer,
                    onSetZombie: { playerId in
                        // Note: setHunter is used internally for zombie role assignment
                        viewModel.gameService.setHunter(playerId: playerId)
                    }
                )
            }
        }
        .sheet(isPresented: $showGameInfo) {
            ZombieTagInfoView()
        }
        .alert("Profile Name Required", isPresented: $showNoProfileNameAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please add your name to your profile to start a game. You can update your profile name in the Profile tab.")
        }
        .alert("Exit Lobby", isPresented: $showExitConfirmation) {
            Button("Yes", role: .destructive) {
                // Reset game state to lobby before going back to prevent showing game over screen
                viewModel.gameService.gameState = .lobby
                if var session = viewModel.gameService.session {
                    session.gameState = .lobby
                    viewModel.gameService.session = session
                }
                // End the game session and go back to menu
                viewModel.gameService.endGame()
                onBackToMenu()
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Going back to main menu will close this lobby. Are you sure?")
        }
        #if DEBUG
        .debugButton(showDebugTestPanel: $showDebugTestPanel, viewModel: viewModel)
        .sheet(isPresented: $showDebugTestPanel) {
            DebugTestPanelView(viewModel: viewModel)
        }
        #endif
    }
    
    // MARK: - Aesthetic Background (Dynamic Theme)
    
    private var aestheticBackground: some View {
        ZStack {
            // Base gradient (dynamic based on game type)
            LinearGradient(
                colors: [
                    primaryColor.opacity(0.2),
                    secondaryColor.opacity(0.15),
                    lightColor.opacity(0.1),
                    AppColors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Simple animated accent circles (lightweight)
            GeometryReader { geometry in
                let size = max(geometry.size.width, geometry.size.height)
                
                // Top-left accent
                Circle()
                    .fill(primaryColor.opacity(0.15))
                    .frame(width: size * 0.6, height: size * 0.6)
                    .offset(x: -size * 0.2, y: -size * 0.2)
                    .blur(radius: 60)
                
                // Bottom-right accent
                Circle()
                    .fill(secondaryColor.opacity(0.12))
                    .frame(width: size * 0.5, height: size * 0.5)
                    .offset(x: size * 0.3, y: size * 0.4)
                    .blur(radius: 50)
            }
            .allowsHitTesting(false)
        }
    }
    
    // MARK: - Lobby Content Panel
    
    private var lobbyContentPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        // Show confirmation if there's an active session
                        if viewModel.gameService.session != nil {
                            showExitConfirmation = true
                        } else {
                            // No session, just go back
                            onBackToMenu()
                        }
                    }) {
                        HStack(spacing: AppSpacing.xs) {
                            Image(systemName: "chevron.left")
                                .font(.body)
                            Text("Back to Games")
                                .font(AppTypography.bodyMedium())
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            Capsule()
                                .fill(primaryColor.opacity(0.1))
                        )
                    }
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)
                    
                        // Centered Header
                lobbyHeader
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xs)
                
                        // Content Cards (only show if session exists)
                if let session = viewModel.gameService.session {
                            VStack(spacing: AppSpacing.lg) {
                    sessionInfoCard(session: session)
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                
                                if !session.players.isEmpty {
                    playerListCard(session: session)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .top).combined(with: .opacity),
                                    removal: .move(edge: .top).combined(with: .opacity)
                                ))
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                        }
                        
                        // Centered Controls
                lobbyControls
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.top, AppSpacing.lg)
                    
                    Spacer()
                    .frame(height: AppSpacing.lg)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.gameService.session?.id)
    }
    
    private var lobbyHeader: some View {
        ZStack {
            // Game Title - Dynamic based on game type
        VStack(spacing: AppSpacing.sm) {
                // Game Logo/Title
                gameTitleView
                    .frame(maxWidth: .infinity)
                    .transition(.scale.combined(with: .opacity))
            
            // Tagline (dynamic)
            Text(gameTagline)
                .font(AppTypography.headlineSmall())
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, -AppSpacing.sm)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    Capsule()
                        .fill(primaryColor.opacity(0.1))
                        .overlay(
                            Capsule()
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            primaryColor.opacity(0.3),
                                            secondaryColor.opacity(0.3)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            
                // Decorative line (dynamic theme)
                HStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    primaryColor.opacity(0.6),
                                    secondaryColor.opacity(0.6),
                                    Color.clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 2)
                        .padding(.horizontal, AppSpacing.lg)
                }
                .padding(.top, AppSpacing.sm)
                .transition(.opacity)
            }
            .multilineTextAlignment(.center)
            
            // Info Button - Overlay in top right
            HStack {
                Spacer()
                VStack {
                    Button(action: {
                        showGameInfo = true
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(primaryColor)
                            .padding(8)
                            .background(
                                Circle()
                                    .fill(primaryColor.opacity(0.1))
                            )
                    }
                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
        }
    }
    
    // ZombieTag game logo view (similar to Touch Grass logo proportions)
    private var gameTitleView: some View {
        ZStack {
            // Outer glow effect
            Image("ZombieTag")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 650, maxHeight: 280)
                .blur(radius: 20)
                .opacity(0.6)
                .offset(y: 4)
            
            // Middle glow layer
            Image("ZombieTag")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 650, maxHeight: 280)
                .blur(radius: 10)
                .opacity(0.5)
                .offset(y: 2)
            
            // Main logo
            Image("ZombieTag")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 650, maxHeight: 280)
                .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                .shadow(color: primaryColor.opacity(0.7), radius: 25, x: 0, y: 0)
                .shadow(color: secondaryColor.opacity(0.5), radius: 35, x: 0, y: 0)
        }
    }
    
    private func sessionInfoCard(session: GameSession) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Top Section: Status and Players (Horizontal)
            HStack(spacing: AppSpacing.lg) {
                // Status Badge
                VStack(spacing: AppSpacing.xs) {
                    Text("Status")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    Text(session.gameState.rawValue.capitalized)
                        .font(AppTypography.labelMedium())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(stateColor(for: session.gameState))
                        )
                }
                
                Divider()
                    .frame(height: 40)
                
                // Players Count
                VStack(spacing: AppSpacing.xs) {
                    Text("Players")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    HStack(spacing: 4) {
                        Text("\(session.players.count)")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                        Text("/")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(GameService.maxPlayersPerSession)")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Spacer()
            }
            
            // Join Code Section (only show if host)
            if let currentPlayer = viewModel.gameService.currentPlayer,
               currentPlayer.id == session.hostId {
                VStack(spacing: AppSpacing.sm) {
                    HStack {
                        Image(systemName: "number")
                            .foregroundColor(primaryColor)
                            .font(.caption)
                        Text("Join Code")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        Spacer()
                    }
                    
                    HStack(spacing: AppSpacing.md) {
                        // Join code - clean format with separator
                        Text(formatJoinCode(session.joinCode))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(primaryColor)
                            .tracking(2)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(primaryColor.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(primaryColor.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        
                        // Action buttons
                        HStack(spacing: AppSpacing.xs) {
                            // Copy button
                            Button(action: {
                                UIPasteboard.general.string = session.joinCode
                                HapticFeedbackManager.shared.selection()
                            }) {
                                Image(systemName: "doc.on.doc.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(primaryColor)
                                            .shadow(color: primaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            
                            // Share button
                            ShareLink(item: shareText(for: session)) {
                                Image(systemName: "square.and.arrow.up.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 14, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(secondaryColor)
                                            .shadow(color: secondaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
                                    )
                            }
                        }
                    }
                }
            }
            
            // Bubble Info (if configured)
            if let bubble = viewModel.gameService.session?.bubble {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "circle.grid.cross.fill")
                        .foregroundColor(AppColors.bubbleSafe)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Play Zone")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        HStack(spacing: 6) {
                            Text("\(Int(bubble.startRadius))m")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.textPrimary)
                            Text("→")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppColors.textSecondary)
                            Text("0m")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duration")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        Text(timeString(from: bubble.duration))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                    }
                }
                .padding(AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.bubbleSafe.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(AppColors.bubbleSafe.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 12, x: 0, y: 4)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.gameService.session?.gameState)
    }
    
    // Helper function to format join code with separator
    private func formatJoinCode(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let first = String(code.prefix(3))
        let second = String(code.suffix(3))
        return "\(first) \(second)"
    }
    
    // Helper function to format time
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if minutes > 0 {
            return "\(minutes)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
    
    private func playerListCard(session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.humanPrimary)
                    .font(.title3)
                Text("Players")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)
            }
            
            Divider()
            
            // Role distribution summary
            let zombies = session.players.filter { $0.role == .zombie && $0.isAlive }
            let humans = session.players.filter { $0.role == .human && $0.isAlive }
            let eliminated = session.players.filter { !$0.isAlive }
            
            if !session.players.isEmpty {
                HStack(spacing: AppSpacing.md) {
                    // Zombies count
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk.motion")
                            .font(.caption)
                            .foregroundColor(AppColors.zombiePrimary)
                        Text("\(zombies.count)")
                            .font(AppTypography.labelSmall())
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.zombiePrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.zombiePrimary.opacity(0.15))
                    )
                    
                    // Humans count
                    HStack(spacing: 4) {
                        Image(systemName: "figure.run")
                            .font(.caption)
                            .foregroundColor(AppColors.humanPrimary)
                        Text("\(humans.count)")
                            .font(AppTypography.labelSmall())
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.humanPrimary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.humanPrimary.opacity(0.15))
                    )
                    
                    // Eliminated count
                    if !eliminated.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(AppColors.error)
                            Text("\(eliminated.count)")
                                .font(AppTypography.labelSmall())
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.error)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(AppColors.error.opacity(0.15))
                        )
                    }
                    
                    Spacer()
                }
                .padding(.bottom, AppSpacing.xs)
            }
            
            Divider()
                .padding(.vertical, AppSpacing.xs)
            
            // Player List
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                ForEach(session.players) { player in
                    HStack(spacing: AppSpacing.sm) {
                        // Profile picture or role icon
                        Group {
                            if let profilePicBase64 = player.profilePictureBase64,
                               let imageData = Data(base64Encoded: profilePicBase64),
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 36, height: 36)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(roleColor(for: player.role), lineWidth: 2)
                                    )
                            } else {
                                // Role icon fallback
                                ZStack {
                                    Circle()
                                        .fill(roleColor(for: player.role).opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: player.role == .zombie ? "figure.walk.motion" : "figure.run")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(roleColor(for: player.role))
                                }
                            }
                        }
                        
                        // Player name
                        Text(player.displayName)
                            .font(AppTypography.bodyMedium())
                            .fontWeight(.medium)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer(minLength: AppSpacing.xs)
                        
                        // Role badge
                        Text(player.role == .zombie ? "Zombie" : "Human")
                            .font(AppTypography.caption())
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                roleColor(for: player.role),
                                                roleColor(for: player.role).opacity(0.8)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        
                        // Role switch button (if host)
                        if let currentPlayer = viewModel.gameService.currentPlayer,
                           let session = viewModel.gameService.session,
                           currentPlayer.id == session.hostId {
                            Button(action: {
                                // Simply call setHunter - it handles toggling the role (works for zombie tag too)
                                viewModel.gameService.setHunter(playerId: player.id)
                            }) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(primaryColor)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // You badge
                        if player.id == viewModel.gameService.currentPlayer?.id {
                            Text("You")
                                .font(AppTypography.caption())
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(primaryColor)
                                        .shadow(color: primaryColor.opacity(0.5), radius: 2, x: 0, y: 1)
                                )
                        }
                        
                        // Eliminated indicator
                        if !player.isAlive {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.error)
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(player.id == viewModel.gameService.currentPlayer?.id ? primaryColor.opacity(0.1) : AppColors.backgroundSecondary)
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: session.players.count)
    }
    
    private var lobbyControls: some View {
        VStack(spacing: AppSpacing.md) {
            if viewModel.gameService.session == nil {
                // Join Game Input Box (animated)
                if showJoinGameInput {
                    joinGameInputBox
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9))
                        ))
                }
                
                // Create Game and Join Game Cards (beautified like game cards)
                VStack(spacing: AppSpacing.md) {
                    // Create Game Card
                Button(action: {
                    HapticFeedbackManager.shared.selection()
                    // Check if profile has a name
                    if ProfileService.shared.displayName.isEmpty {
                        showNoProfileNameAlert = true
                    } else {
                        viewModel.selectedGameType = .zombieTag
                        viewModel.createSession()
                    }
                }) {
                        HStack(spacing: AppSpacing.md) {
                        Image(systemName: "plus.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(primaryColor)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(primaryColor.opacity(0.15))
                                )
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Create Game")
                                    .font(AppTypography.headlineSmall())
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Text("Start a new Zombie Tag session")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer(minLength: AppSpacing.xs)
                            
                            Image(systemName: "chevron.right")
                                .font(.body)
                                .foregroundColor(primaryColor)
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(showJoinGameInput)
                    .opacity(showJoinGameInput ? 0.6 : 1.0)
                    .accessibilityLabel("Create game")
                    .accessibilityHint("Creates a new Zombie Tag game session")
                    
                    // Join Game Card
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showJoinGameInput.toggle()
                            if !showJoinGameInput {
                                gameCode = ""
                            }
                        }
                    }) {
                        HStack(spacing: AppSpacing.md) {
                            Image(systemName: showJoinGameInput ? "xmark.circle.fill" : "person.2.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(secondaryColor)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(secondaryColor.opacity(0.15))
                                )
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text(showJoinGameInput ? "Cancel" : "Join Game")
                                    .font(AppTypography.headlineSmall())
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                
                                Text(showJoinGameInput ? "Close join code input" : "Enter a game code to join")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Spacer(minLength: AppSpacing.xs)
                            
                            Image(systemName: showJoinGameInput ? "xmark" : "chevron.right")
                                .font(.body)
                                .foregroundColor(secondaryColor)
                        }
                    .padding(AppSpacing.md)
                    .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            } else if viewModel.gameService.session?.gameState == .lobby {
                VStack(spacing: AppSpacing.md) {
                    // Configure Game Button (if bubble not configured) OR Checkmark (if configured)
                    if viewModel.gameService.session?.bubble == nil {
                        Button(action: { showBubbleSettings = true }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                    .symbolEffect(.bounce, value: showBubbleSettings)
                                Text("Configure Game")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                primaryColor,
                                                secondaryColor
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .shadow(color: primaryColor.opacity(0.4), radius: 12, x: 0, y: 6)
                            )
                        }
                        .disabled(viewModel.locationService.coordinate == nil)
                        .opacity(viewModel.locationService.coordinate == nil ? 0.6 : 1.0)
                        .buttonStyle(ScaleButtonStyle())
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    } else {
                        // Game configured - show checkmark button that can be tapped to reconfigure (host only)
                        if let currentPlayer = viewModel.gameService.currentPlayer,
                           let session = viewModel.gameService.session,
                           currentPlayer.id == session.hostId {
                            Button(action: { showBubbleSettings = true }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(AppColors.success)
                                    Text("Game Configured")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    Image(systemName: "gearshape")
                                        .font(.body)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(AppColors.success.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(AppColors.success.opacity(0.3), lineWidth: 2)
                                        )
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        } else {
                            // Non-host sees read-only "Game Configured" indicator
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(AppColors.success)
                                Text("Game Configured")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(AppColors.success.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(AppColors.success.opacity(0.3), lineWidth: 2)
                                    )
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                        
                        // Host Controls (only host can see these)
                        if let currentPlayer = viewModel.gameService.currentPlayer,
                           let session = viewModel.gameService.session,
                           currentPlayer.id == session.hostId {
                            VStack(spacing: AppSpacing.md) {
                                // Manage Zombies Button
                                Button(action: { showZombieManagement = true }) {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(systemName: "person.2.badge.gearshape.fill")
                                            .font(.title3)
                                        Text("Manage Zombies")
                                            .font(AppTypography.labelLarge())
                                            .fontWeight(.semibold)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .foregroundColor(primaryColor)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(primaryColor.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(primaryColor.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(ScaleButtonStyle())
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                        
                        // Begin Game Button (visible to all, but only host can start)
                        if let currentPlayer = viewModel.gameService.currentPlayer,
                           let session = viewModel.gameService.session {
                            let isHost = currentPlayer.id == session.hostId
                            Button(action: {
                                if isHost {
                                    HapticFeedbackManager.shared.selection()
                                    print("🎮 ZombieTagLobbyView: Begin game button pressed")
                                    viewModel.beginGame()
                                }
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.title3)
                                        .symbolEffect(.bounce, value: viewModel.gameService.gameState)
                                    Text("Begin Game")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(
                                            LinearGradient(
                                                colors: isHost ? [
                                                    primaryColor,
                                                    secondaryColor
                                                ] : [
                                                    AppColors.textSecondary.opacity(0.5),
                                                    AppColors.textSecondary.opacity(0.3)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .shadow(color: isHost ? primaryColor.opacity(0.4) : Color.clear, radius: 12, x: 0, y: 6)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(!isHost || viewModel.isBeginningGame)
                            .opacity((isHost && !viewModel.isBeginningGame) ? 1.0 : 0.6)
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                    }
                }
            }
            
            // Location Permission Button
            if viewModel.locationService.authorization != .authorizedAlways {
                Button(action: { viewModel.locationService.requestPermission() }) {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "location.fill")
                            .symbolEffect(.pulse, options: .repeating)
                        Text("Enable Location")
                    }
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textSecondary)
                    .padding(.vertical, AppSpacing.sm)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.gameService.session?.id)
    }
    
    // MARK: - Join Game Input Box
    
    private var joinGameInputBox: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "number.square.fill")
                    .foregroundColor(primaryColor)
                    .font(.title2)
                Text("Enter Game Code")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            HStack(spacing: AppSpacing.sm) {
                TextField("000000", text: $gameCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.backgroundSecondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                gameCode.isEmpty ? AppColors.textSecondary.opacity(0.3) : AppColors.zombiePrimary,
                                lineWidth: 2
                            )
                    )
                    .onChange(of: gameCode) { oldValue, newValue in
                        // Limit to 6 digits and only numbers
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered.count <= 6 {
                            gameCode = filtered
                        } else {
                            gameCode = String(filtered.prefix(6))
                        }
                    }
                
                Button(action: {
                    print("🔍 Joining game with code: \(gameCode)")
                    viewModel.joinGame(joinCode: gameCode)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showJoinGameInput = false
                        gameCode = ""
                    }
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(gameCode.isEmpty ? AppColors.textSecondary : AppColors.zombiePrimary)
                        .frame(width: 44, height: 44)
                }
                .disabled(gameCode.isEmpty)
            }
            
            Text("Enter the game code shared by the host")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
        )
    }
    
    // MARK: - Button Style
    
    struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
    
    // MARK: - Helpers
    
    private func stateColor(for state: GameState) -> Color {
        switch state {
        case .lobby: return AppColors.neutral
        case .active: return AppColors.success
        case .ended: return AppColors.error
        case .flagPlacement: return AppColors.neutral
        }
    }
    
    private func roleColor(for role: PlayerRole) -> Color {
        switch role {
        case .zombie: return AppColors.zombiePrimary
        case .human: return AppColors.humanPrimary
        default: return AppColors.textSecondary
        }
    }
    
    // MARK: - Share Helper
    
    private func shareText(for session: GameSession) -> String {
        let bubbleInfo = session.bubble != nil ? "Game is configured and ready!" : "Waiting for host to configure game."
        return """
        🎮 Join my Touch Grass game!
        
        Game Code: \(session.joinCode)
        
        \(bubbleInfo)
        
        Open Touch Grass and enter the code to join!
        """
    }
}
