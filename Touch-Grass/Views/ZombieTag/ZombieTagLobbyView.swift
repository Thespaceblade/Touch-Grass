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
    @State private var bubbleDuration: Double = 900 // Default 15 minutes
    @State private var zombieCount: Int = 1
    @State private var showCountdown: Bool = false
    @State private var countdownStartTime: Date?
    @State private var countdownCompleted: Bool = false
    @State private var errorMessage: String = ""
    @State private var showErrorAlert: Bool = false
    @State private var hasCopiedJoinCode: Bool = false
    @State private var resetCopiedJoinCodeTask: Task<Void, Never>? = nil

    // OPTIMIZATION: Cache gameService state to reduce re-renders
    @State private var cachedGameState: GameState = .lobby
    @State private var cachedSession: GameSession? = nil
    
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
        let _ = {
            #if DEBUG
            let timestamp = Date().timeIntervalSince1970
            print("🔍 DEBUG: [\(String(format: "%.3f", timestamp))] ZombieTagLobbyView body rendering")
            print("🔍 DEBUG:   - viewModel.selectedGame: \(String(describing: viewModel.selectedGame))")
            print("🔍 DEBUG:   - viewModel.isServicesInitializing: \(viewModel.isServicesInitializing)")
            print("🔍 DEBUG:   - cachedSession?.id: \(String(describing: cachedSession?.id))")
            print("🔍 DEBUG:   - cachedGameState: \(cachedGameState)")
            #endif
        }()
        
        mainContentView
        .onAppear {
            // Reset all state when view appears to ensure clean start for this game mode
            bubbleStartRadius = 300
            bubbleDuration = 900
            zombieCount = 1
            gameCode = ""
            showBubbleSettings = false
            showJoinGameInput = false
            showZombieManagement = false
            showGameInfo = false
            
            // OPTIMIZATION: Cache gameService state on appear
            cachedGameState = viewModel.gameService.gameState
            cachedSession = viewModel.gameService.session
            
            // Only reset countdown state if game is not active
            if cachedGameState != .active {
                showCountdown = false
                countdownStartTime = nil
                countdownCompleted = false
            } else {
                skipPreGameCountdownIfNeededForDebug()
            }
            
            // SAFETY: Check for stale sessions from previous app launches (async for performance)
            // If session exists but no bubble is configured, it's likely stale
            Task { @MainActor in
                if let session = cachedSession,
                   session.bubble == nil,
                   cachedGameState == .lobby {
                    // This is a stale session from a previous app launch - clear it
                    print("🧹 Detected stale session on appear, clearing...")
                    viewModel.gameService.clearSession()
                }
            }
        }
        // OPTIMIZATION: Update cached state only when gameState changes
        .onChange(of: viewModel.gameService.gameState) { oldValue, newValue in
            cachedGameState = newValue
            // When game state changes to active, show countdown
            if oldValue != .active && newValue == .active {
                if DebugRuntimeFlags.skipPreGameCountdown {
                    skipPreGameCountdownIfNeededForDebug()
                } else if countdownStartTime == nil && !countdownCompleted {
                    countdownStartTime = Date()
                    countdownCompleted = false
                    withAnimation(.smoothTransition) {
                        showCountdown = true
                    }
                }
            } else if newValue == .ended {
                showCountdown = false
                countdownStartTime = nil
                countdownCompleted = false
                cachedSession = viewModel.gameService.session
            } else if newValue != .active {
                showCountdown = false
                countdownStartTime = nil
                countdownCompleted = false
            }
        }
        // OPTIMIZATION: Update cached session only when it changes
        .onChange(of: viewModel.gameService.session) { oldValue, newValue in
            cachedSession = newValue
        }
        .onChange(of: viewModel.gameService.session?.gameType) { oldValue, newValue in
            // If game type changes, reset all configuration state
            if oldValue != nil && oldValue != newValue {
                bubbleStartRadius = 300
                bubbleDuration = 900
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
                showTimer: .constant(true), // Timer always enabled
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
                        teamBBase: nil,
                        showTimer: true // Timer always enabled
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
            Text("Please add your name to start a game. You can set your profile name in Settings.")
        }
        .themedExitLobbyConfirmation(
            isPresented: $showExitConfirmation,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            iconName: "allergens"
        ) {
            // Completely clear and delete the session from Firestore
            // This ensures the session is deleted immediately
            viewModel.gameService.clearSession()
            onBackToMenu()
        }
        #if DEBUG
        .debugButton(showDebugTestPanel: $showDebugTestPanel, viewModel: viewModel)
        .sheet(isPresented: $showDebugTestPanel) {
            DebugTestPanelView(viewModel: viewModel)
        }
        #endif
    }
    
    private func skipPreGameCountdownIfNeededForDebug() {
        guard DebugRuntimeFlags.skipPreGameCountdown else { return }
        guard viewModel.gameService.gameState == .active, !countdownCompleted else { return }
        viewModel.gameService.startGameTimer()
        countdownCompleted = true
        showCountdown = false
        countdownStartTime = nil
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        Group {
            if cachedGameState == .ended {
                gameEndContentView
            } else if cachedGameState == .active {
                activeGameContentView
            } else {
                lobbyViewContent
            }
        }
    }
    
    @ViewBuilder
    private var gameEndContentView: some View {
        if let session = viewModel.gameService.session,
           let gameStats = viewModel.gameService.gameStats {
            ZombieTagGameEndView(
                session: session,
                gameStats: gameStats,
                currentPlayer: viewModel.gameService.currentPlayer,
                gameService: viewModel.gameService,
                onPlayAgain: {
                    viewModel.playAgain()
                },
                onBackToLobby: {
                    viewModel.gameService.resetToLobby()
                }
            )
        } else {
            lobbyViewContent
        }
    }
    
    @ViewBuilder
    private var activeGameContentView: some View {
        if showCountdown && !countdownCompleted {
            // Show countdown if game just started
            ZombieTagCountdownView(
                gameService: viewModel.gameService,
                locationService: viewModel.locationService,
                onCountdownComplete: {
                    // Start the game timer when countdown completes
                    viewModel.gameService.startGameTimer()
                    // After countdown completes, mark as complete and show active game view
                    withAnimation(.smoothTransition) {
                        countdownCompleted = true
                        showCountdown = false
                    }
                }
            )
            .transition(.opacity)
        } else {
            // Show active game view after countdown completes or if countdown was skipped
            ZombieTagActiveGameView(
                gameService: viewModel.gameService,
                locationService: viewModel.locationService,
                viewModel: viewModel
            )
            .transition(.opacity)
        }
    }
    
    private var lobbyViewContent: some View {
        ZStack {
            // Cartoon landscape background
            LandscapeBackground()
                .drawingGroup()
                .ignoresSafeArea(.all)
                .zIndex(0)

            AestheticBackground(gradientOffset: 0, pulseScale: 1.0)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)
                .zIndex(1)

            // Lobby Content Panel
            lobbyContentPanel
                .zIndex(2)
        }
        .onAppear {
            // Defer motion updates slightly for better initial render performance
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
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 15, weight: .bold))
                            Text("Back to Games")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                        }
                        .foregroundColor(AppColors.cartoonInk)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                        .background(
                            Capsule().fill(AppColors.cartoonCream)
                        )
                        .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2))
                        .background(Capsule().fill(Color(white: 0.18)).offset(x: 2, y: 2))
                    }
                    .buttonStyle(PlainButtonStyle())
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.xs)
                    
                        // Centered Header
                lobbyHeader
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                    // More breathing room between tagline and cards
                    .padding(.bottom, viewModel.gameService.session != nil ? AppSpacing.md : AppSpacing.xs)
                
                        // Content Cards (only show if session exists)
                if let session = viewModel.gameService.session {
                            VStack(spacing: AppSpacing.sm) {
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
                            .padding(.top, viewModel.gameService.session != nil ? AppSpacing.sm : AppSpacing.lg)
                    
                    Spacer()
                    .frame(height: AppSpacing.xl)
            }
        }
        .safeAreaPadding(.bottom, AppSpacing.lg)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.gameService.session?.id)
    }
    
    private var lobbyHeader: some View {
        let hasSession = viewModel.gameService.session != nil
        return ZStack {
            // Game Title - Dynamic based on game type
            VStack(spacing: AppSpacing.sm) {
                // Game Logo/Title
                gameTitleView(compact: hasSession)
                    .frame(maxWidth: .infinity)
                    .transition(.scale.combined(with: .opacity))

                // Tagline (cartoon pill)
                CartoonPill(text: gameTagline, color: primaryColor)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .multilineTextAlignment(.center)

            // Info Button - Overlay in top right
            HStack {
                Spacer()
                VStack {
	                    Button(action: {
	                        showGameInfo = true
	                    }) {
	                        CartoonLobbyIconButtonLabel(systemName: "info.circle.fill")
	                    }
	                    .buttonStyle(IconButtonStyle(size: 42, color: primaryColor))
	                    Spacer()
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.xs)
        }
    }
    
    // ZombieTag game logo view, compact mode shrinks it when session panel is visible
    private func gameTitleView(compact: Bool = false) -> some View {
        let maxH: CGFloat = compact ? 100 : 216
        let maxW: CGFloat = compact ? 360 : 780
        return Image("ZombieTag")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxW, maxHeight: maxH)
            .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: compact)
    }
    
    private func sessionInfoCard(session: GameSession) -> some View {
        VStack(spacing: AppSpacing.sm) {
            // Top Section: Status and Players (Horizontal)
            HStack(spacing: AppSpacing.lg) {
                // Status Badge
                VStack(spacing: AppSpacing.xs) {
                    Text("Status")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.cartoonInk.opacity(0.55))
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
                    .frame(height: 32)

                // Players Count
                VStack(spacing: AppSpacing.xs) {
                    Text("Players")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                    HStack(spacing: 4) {
                        Text("\(session.players.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                        Text("/")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                        Text("\(GameService.maxPlayersPerSession)")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.55))
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
                            .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                        Spacer()
                    }

                    HStack(spacing: AppSpacing.sm) {
                        CartoonJoinCodeBadge(code: formatJoinCode(session.joinCode), accent: primaryColor)

                        HStack(spacing: AppSpacing.sm) {
                            Button(action: {
                                copyJoinCode(session.joinCode)
                            }) {
                                CartoonLobbyIconButtonLabel(systemName: hasCopiedJoinCode ? "checkmark" : "doc.on.doc.fill")
                            }
                            .buttonStyle(IconButtonStyle(size: 42, color: hasCopiedJoinCode ? AppColors.success : primaryColor))

                            ShareLink(item: shareText(for: session)) {
                                CartoonLobbyIconButtonLabel(systemName: "square.and.arrow.up.fill")
                            }
                            .buttonStyle(IconButtonStyle(size: 42, color: secondaryColor))
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
                            .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                        HStack(spacing: 6) {
                            Text("\(Int(bubble.startRadius))m")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk)
                            Text("→")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                            Text("0m")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Duration")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                        Text(timeString(from: bubble.duration))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
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
        .padding(AppSpacing.md)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppColors.cartoonInk, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(white: 0.18)).offset(x: 4, y: 4))
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Header
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.humanPrimary)
                    .font(.title3)
                Text("Players (\(session.players.count))")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)
            }

            Divider()

            // Player List
            VStack(alignment: .leading, spacing: 6) {
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
                            .foregroundColor(AppColors.cartoonInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        Spacer(minLength: AppSpacing.xs)
                        
                        // Role badge
                        CartoonPill(
                            text: player.role == .zombie ? "Zombie" : "Human",
                            color: roleColor(for: player.role)
                        )
                        
                        // Role switch button (if host)
                        if let currentPlayer = viewModel.gameService.currentPlayer,
                           let session = viewModel.gameService.session,
                           currentPlayer.id == session.hostId {
	                            Button(action: {
	                                // Simply call setHunter - it handles toggling the role (works for zombie tag too)
	                                viewModel.gameService.setHunter(playerId: player.id)
	                            }) {
	                                CartoonLobbyIconButtonLabel(systemName: "arrow.left.arrow.right")
	                            }
	                            .buttonStyle(IconButtonStyle(size: 30, color: primaryColor))
	                        }
                        
                        // You badge
                        if player.id == viewModel.gameService.currentPlayer?.id {
                            CartoonPill(text: "You", color: AppColors.cartoonSun, textColor: AppColors.cartoonInkOnSunFill, strokeColor: AppColors.cartoonInkOnSunFill)
                        }
                        
                        // Eliminated indicator
                        if !player.isAlive {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppColors.error)
                                .font(.system(size: 18, weight: .semibold))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(player.id == viewModel.gameService.currentPlayer?.id ? primaryColor.opacity(0.12) : AppColors.cartoonCream.opacity(0.7))
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.cartoonInk, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.18)).offset(x: 4, y: 4))
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: session.players.count)
    }
    
    private var lobbyControls: some View {
        VStack(spacing: AppSpacing.md) {
            let locationReady = viewModel.locationService.isReadyForGameplay

            LocationPermissionCard(
                locationService: viewModel.locationService,
                accent: primaryColor,
                onRequestAdditionalPermissions: {
                    viewModel.requestBluetoothPermissionIfNeeded()
                }
            )

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
                        CartoonLobbyActionCard(
                            iconName: "plus.circle.fill",
                            title: "Create Game",
                            subtitle: "Start a new Zombie Tag session",
                            accent: primaryColor
                        )
                    }
                    .buttonStyle(CartoonCardButtonStyle())
                    .disabled(showJoinGameInput || !locationReady)
                    .opacity((showJoinGameInput || !locationReady) ? 0.6 : 1.0)
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
                        CartoonLobbyActionCard(
                            iconName: showJoinGameInput ? "xmark.circle.fill" : "person.2.circle.fill",
                            title: showJoinGameInput ? "Cancel" : "Join Game",
                            subtitle: showJoinGameInput ? "Close join code input" : "Enter a game code to join",
                            accent: secondaryColor,
                            trailingIconName: showJoinGameInput ? "xmark" : "chevron.right"
                        )
                    }
                    .buttonStyle(CartoonCardButtonStyle())
                    .disabled(!locationReady)
                    .opacity(locationReady ? 1.0 : 0.6)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            } else if viewModel.gameService.session?.gameState == .lobby {
                VStack(spacing: AppSpacing.md) {
                    // Configure Game Button (if bubble not configured) OR Checkmark (if configured)
                    // Only show configure button to host
                    if let currentPlayer = viewModel.gameService.currentPlayer,
                       let session = viewModel.gameService.session,
                       currentPlayer.id == session.hostId,
                       session.bubble == nil {
                        Button(action: { showBubbleSettings = true }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "gearshape.fill").font(.title3)
                                Text("Configure Game")
                                    .font(AppTypography.labelLarge()).fontWeight(.semibold)
                                    .lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.md)
                        }
                        .buttonStyle(CartoonButtonStyle(accent: primaryColor, textColor: .white, isDisabled: !locationReady))
                        .disabled(!locationReady)
                        .opacity(locationReady ? 1.0 : 0.6)
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
	                                CartoonLobbyActionCard(
	                                    iconName: "checkmark.circle.fill",
	                                    title: "Game Configured",
	                                    subtitle: "Tap to edit the play zone",
	                                    accent: AppColors.success,
	                                    trailingIconName: "gearshape.fill"
	                                )
	                            }
	                            .buttonStyle(CartoonCardButtonStyle())
	                            .transition(.asymmetric(
	                                insertion: .move(edge: .bottom).combined(with: .opacity),
	                                removal: .move(edge: .bottom).combined(with: .opacity)
	                            ))
	                        } else {
	                            // Non-host sees read-only "Game Configured" indicator
	                            CartoonLobbyActionCard(
	                                iconName: "checkmark.circle.fill",
	                                title: "Game Configured",
	                                subtitle: "Waiting for the host to start",
	                                accent: AppColors.success,
	                                trailingIconName: "checkmark"
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
	                                    CartoonLobbyActionCard(
	                                        iconName: "person.2.badge.gearshape.fill",
	                                        title: "Manage Zombies",
	                                        subtitle: "Choose who starts infected",
	                                        accent: primaryColor,
	                                        trailingIconName: "slider.horizontal.3"
	                                    )
	                                }
	                                .buttonStyle(CartoonCardButtonStyle())
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
                            let playerCount = session.players.count
                            let minimumPlayers = session.gameType.minimumPlayers
                            let hasMinimumPlayers = playerCount >= minimumPlayers
                            // Check if there's at least one zombie
                            let hasZombie = session.players.contains { $0.role == .zombie }
                            let isEnabled = locationReady && isHost && hasMinimumPlayers && hasZombie && !viewModel.isBeginningGame
                            
                            Button(action: {
                                if isEnabled {
                                    HapticFeedbackManager.shared.selection()
                                    print("🎮 ZombieTagLobbyView: Begin game button pressed")
                                    viewModel.beginGame()
                                }
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    if viewModel.isBeginningGame {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title3)
                                            .symbolEffect(.bounce, value: viewModel.gameService.gameState)
                                    }
                                    Text(viewModel.isBeginningGame ? "Starting..." : "Begin Game")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.md)
                            }
	                            .buttonStyle(CartoonButtonStyle(accent: primaryColor, textColor: .white, isDisabled: !isEnabled))
	                            .disabled(!isEnabled)
	                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.gameService.session?.id)
    }
    
    // MARK: - Join Game Input Box
    
    private var joinGameInputBox: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: primaryColor, size: 36) {
                    Image(systemName: "number")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("Enter Game Code")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            HStack(spacing: AppSpacing.sm) {
                TextField("000000", text: $gameCode)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(AppColors.cartoonInk)
                    .multilineTextAlignment(.center)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled()
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.sm)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.cartoonCream2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                gameCode.isEmpty ? AppColors.cartoonInk.opacity(0.35) : AppColors.zombiePrimary,
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
                    guard viewModel.locationService.isReadyForGameplay else {
                        errorMessage = "Finish the two-step location setup before joining."
                        showErrorAlert = true
                        viewModel.requestRequiredPreGamePermissions()
                        return
                    }

                    print("🔍 Joining game with code: \(gameCode)")
                    viewModel.joinGame(joinCode: gameCode)
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        showJoinGameInput = false
                        gameCode = ""
                    }
                }) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                .buttonStyle(IconButtonStyle(size: 44, color: (gameCode.count == 6 && viewModel.locationService.isReadyForGameplay) ? AppColors.zombiePrimary : AppColors.cartoonInk.opacity(0.45)))
                .disabled(gameCode.count != 6 || !viewModel.locationService.isReadyForGameplay)
            }
            
            Text("Enter the game code shared by the host")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.cartoonInk, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.18)).offset(x: 4, y: 4))
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

    private func copyJoinCode(_ joinCode: String) {
        UIPasteboard.general.string = joinCode
        HapticFeedbackManager.shared.selection()

        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            hasCopiedJoinCode = true
        }

        resetCopiedJoinCodeTask?.cancel()
        resetCopiedJoinCodeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                hasCopiedJoinCode = false
            }
        }
    }
    
    private func shareText(for session: GameSession) -> String {
        let bubbleInfo = session.bubble != nil ? "The game is configured and ready." : "The host is still setting up the game."
        return """
        Join my Touch Grass \(session.gameType.rawValue) game.
        
        Game Code: \(session.joinCode)
        
        \(bubbleInfo)
        
        Open Touch Grass, choose \(session.gameType.rawValue), and enter this code to join.
        """
    }
}
