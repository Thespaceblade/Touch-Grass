//
//  ManhuntLobbyView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//
import SwiftUI
import CoreLocation

struct ManhuntLobbyView: View {
    @ObservedObject var viewModel: GameViewModel
    let onBackToMenu: () -> Void
    #if DEBUG
    @State private var showDebugTestPanel = false
    #endif
    
    @State private var showBubbleSettings = false
    @State private var showJoinGameInput = false
    @State private var showHunterManagement = false
    @State private var showGameInfo = false
    @State private var gameCode: String = ""
    @State private var bubbleStartRadius: Double = 300
    @State private var bubbleDuration: Double = 900 // Default 15 minutes
    @State private var hunterCount: Int = 1
    @State private var enableShrinking: Bool = true // Default to shrinking enabled
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var showNoProfileNameAlert: Bool = false
    @State private var showExitConfirmation: Bool = false
    @State private var showCountdown: Bool = false
    @State private var countdownStartTime: Date?
    @State private var countdownCompleted: Bool = false
    @State private var hasCopiedJoinCode: Bool = false
    @State private var resetCopiedJoinCodeTask: Task<Void, Never>? = nil
    
    // OPTIMIZATION: Cache gameService state to reduce re-renders
    @State private var cachedGameState: GameState = .lobby
    @State private var cachedSession: GameSession? = nil
    
    // Hardcoded Manhunt theme properties
    private var primaryColor: Color {
        AppColors.manhuntPrimary
    }
    
    private var secondaryColor: Color {
        AppColors.manhuntSecondary
    }
    
    private var lightColor: Color {
        AppColors.manhuntLight
    }
    
    private var gameTagline: String {
        "Run, Hide, Survive"
    }
    
    var body: some View {
        let _ = {
            #if DEBUG
            let timestamp = Date().timeIntervalSince1970
            print("🔍 DEBUG: [\(String(format: "%.3f", timestamp))] ManhuntLobbyView body rendering")
            print("🔍 DEBUG:   - viewModel.selectedGame: \(String(describing: viewModel.selectedGame))")
            print("🔍 DEBUG:   - viewModel.isServicesInitializing: \(viewModel.isServicesInitializing)")
            print("🔍 DEBUG:   - viewModel.isCreatingSession: \(viewModel.isCreatingSession)")
            print("🔍 DEBUG:   - cachedSession?.id: \(String(describing: cachedSession?.id))")
            print("🔍 DEBUG:   - cachedGameState: \(cachedGameState)")
            #endif
        }()
        
        return mainContentView
        .onAppear {
            print("🔍 DEBUG: ManhuntLobbyView onAppear called")
            
            // Reset all state when view appears to ensure clean start for this game mode
            bubbleStartRadius = 300
            bubbleDuration = 900
            hunterCount = 1
            enableShrinking = true
            gameCode = ""
            showBubbleSettings = false
            showJoinGameInput = false
            showHunterManagement = false
            showGameInfo = false
            errorMessage = nil
            showErrorAlert = false
            // OPTIMIZATION: Cache gameService state on appear
            cachedGameState = viewModel.gameService.gameState
            cachedSession = viewModel.gameService.session
            
            // Only reset countdown state if game is not active or ended
            if cachedGameState != .active {
                showCountdown = false
                countdownStartTime = nil
                countdownCompleted = false
            }
            
            // If game is already ended, ensure we have the latest session and stats
            if cachedGameState == .ended {
                cachedSession = viewModel.gameService.session
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
                // Check if we haven't already started the countdown
                if countdownStartTime == nil && !countdownCompleted {
                    countdownStartTime = Date()
                    countdownCompleted = false
                    withAnimation(.smoothTransition) {
                        showCountdown = true
                    }
                }
            } else if newValue == .ended {
                // Game ended - ensure countdown is hidden and reset
                showCountdown = false
                countdownStartTime = nil
                countdownCompleted = false
                // Ensure cached session is updated
                cachedSession = viewModel.gameService.session
            } else if newValue != .active {
                // Reset countdown state if game is no longer active
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
            // Use Task to avoid blocking view updates
            Task { @MainActor in
                if oldValue != nil && oldValue != newValue {
                    bubbleStartRadius = 300
                    bubbleDuration = 900
                    hunterCount = 1
                    gameCode = ""
                    showBubbleSettings = false
                    showJoinGameInput = false
                    showHunterManagement = false
                }
            }
        }
        .sheet(isPresented: $showBubbleSettings) {
            ManhuntBubbleSettingsView(
                startRadius: $bubbleStartRadius,
                duration: $bubbleDuration,
                hunterCount: $hunterCount,
                showTimer: .constant(true), // Timer always enabled
                enableShrinking: $enableShrinking,
                onStart: { selectedCenter in
                    print("⚙️ ManhuntLobbyView: Configure game button pressed")
                    print("   Selected center: \(selectedCenter.latitude), \(selectedCenter.longitude)")
                    print("   Enable shrinking: \(enableShrinking)")
                    // Configure game first, then dismiss sheet
                    viewModel.configureGame(
                        bubbleStartRadius: bubbleStartRadius,
                        duration: bubbleDuration,
                        hunterCount: hunterCount,
                        center: selectedCenter,
                        scoreLimit: nil,
                        teamABase: nil,
                        teamBBase: nil,
                        enableShrinking: enableShrinking
                    )
                    // Dismiss sheet after configuration
                    showBubbleSettings = false
                },
                userLocation: viewModel.locationService.coordinate,
                maxPlayers: viewModel.gameService.session?.players.count ?? 1
            )
        }
        .sheet(isPresented: $showHunterManagement) {
            if let session = viewModel.gameService.session {
                ManhuntHunterManagementView(
                    session: session,
                    currentPlayer: viewModel.gameService.currentPlayer,
                    onSetHunter: { playerId in
                        // Note: setHunter is used internally for hunter role assignment
                        viewModel.gameService.setHunter(playerId: playerId)
                    }
                )
            }
        }
        .sheet(isPresented: $showGameInfo) {
            ManhuntInfoView()
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
            iconName: "figure.run"
        ) {
            viewModel.gameService.clearSession()
            onBackToMenu()
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An unknown error occurred.")
        }
        #if DEBUG
        .debugButton(showDebugTestPanel: $showDebugTestPanel, viewModel: viewModel)
        .sheet(isPresented: $showDebugTestPanel) {
            DebugTestPanelView(viewModel: viewModel)
        }
        #endif
    }
    
    // MARK: - Main Content View
    
    private var mainContentView: some View {
        Group {
            // OPTIMIZATION: Use cached gameState instead of accessing gameService directly
            if cachedGameState == .ended {
                // Show game end view when game has ended
                gameEndContentView
            } else if cachedGameState == .active {
                activeGameContentView
            } else {
                lobbyViewContent
            }
        }
    }
    
    // MARK: - Game End Content View
    
    @ViewBuilder
    private var gameEndContentView: some View {
        if let session = viewModel.gameService.session,
           let gameStats = viewModel.gameService.gameStats {
            ManhuntGameEndView(
                session: session,
                gameStats: gameStats,
                currentPlayer: viewModel.gameService.currentPlayer,
                onPlayAgain: {
                    viewModel.playAgain()
                },
                onBackToLobby: {
                    // Reset game state to lobby
                    viewModel.gameService.resetToLobby()
                }
            )
            .transition(.opacity)
        } else {
            // Fallback: Show lobby if stats not available
            lobbyViewContent
        }
    }
    
    @ViewBuilder
    private var activeGameContentView: some View {
        if showCountdown && !countdownCompleted {
            // Show countdown if game just started
            ManhuntCountdownView(
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
            ManhuntActiveGameView(
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
                            // Tighter gap when session is active so everything fits
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
                // Game Logo/Title — smaller when a session exists to save vertical space
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
    
    // Manhunt game logo view — compact mode shrinks it when session panel is visible
    private func gameTitleView(compact: Bool = false) -> some View {
        let maxH: CGFloat = compact ? 100 : 216
        let maxW: CGFloat = compact ? 360 : 780
        return Image("Manhunt")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxW, maxHeight: maxH)
            .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: compact)
    }
    
    private func sessionInfoCard(session: GameSession) -> some View {
        VStack(spacing: AppSpacing.sm) {
            // Top Section: Status and Players (Horizontal)
            HStack(spacing: AppSpacing.md) {
                // Status Badge
                VStack(spacing: 3) {
                    Text("Status")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                    Text(session.gameState.rawValue.capitalized)
                        .font(AppTypography.labelMedium())
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(stateColor(for: session.gameState))
                        )
                }

                Divider()
                    .frame(height: 32)

                // Players Count
                VStack(spacing: 3) {
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
                VStack(spacing: AppSpacing.xs) {
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
            // Compact header
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "person.2.fill")
                    .foregroundColor(AppColors.hiderPrimary)
                    .font(.system(size: 14, weight: .bold))
                Text("Players (\(session.players.count))")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
            }

            Divider()

            // Player List (no redundant role-count row)
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
                                    
                                    Image(systemName: player.role == .hunter ? "target" : "eye.slash.fill")
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
                            .layoutPriority(0)
                        
                        Spacer(minLength: AppSpacing.xs)
                        
                        // Role badge
                        CartoonPill(
                            text: player.role == .hunter ? "Hunter" : "Hider",
                            color: roleColor(for: player.role)
                        )
                        .frame(width: 76)
                        .layoutPriority(1)
                        
                        // Role switch button (if host)
                        if let currentPlayer = viewModel.gameService.currentPlayer,
                           let session = viewModel.gameService.session,
                           currentPlayer.id == session.hostId {
	                            Button(action: {
	                                // Simply call setHunter - it handles toggling the role
	                                viewModel.gameService.setHunter(playerId: player.id)
	                            }) {
	                                CartoonLobbyIconButtonLabel(systemName: "arrow.left.arrow.right")
	                            }
	                            .buttonStyle(IconButtonStyle(size: 30, color: primaryColor))
	                        }
                        
                        // You badge
                        if player.id == viewModel.gameService.currentPlayer?.id {
                            CartoonPill(text: "You", color: AppColors.cartoonSun, textColor: AppColors.cartoonInk)
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
                            viewModel.createSession()
                        }
                    }) {
                        CartoonLobbyActionCard(
                            iconName: "plus.circle.fill",
                            title: "Create Game",
                            subtitle: "Start a new Hunter Tag session",
                            accent: primaryColor
                        )
                    }
                    .buttonStyle(CartoonCardButtonStyle())
                    .disabled(showJoinGameInput || !locationReady)
                    .opacity((showJoinGameInput || !locationReady) ? 0.6 : 1.0)
                    .accessibilityLabel("Create game")
                    .accessibilityHint("Creates a new Hunter Tag game session")
                    
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
                                // Manage Hunters Button
                                Button(action: {
                                    if let session = viewModel.gameService.session,
                                       viewModel.gameService.currentPlayer?.id != session.hostId {
                                        errorMessage = "Only the host can manage hunters."
                                        showErrorAlert = true
                                    } else {
	                                        showHunterManagement = true
	                                    }
	                                }) {
	                                    CartoonLobbyActionCard(
	                                        iconName: "person.2.badge.gearshape.fill",
	                                        title: "Manage Hunters",
	                                        subtitle: "Choose who starts as hunter",
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
                            let hunterSlotsConfigured = session.hunterCount >= 1 && session.hunterCount < playerCount
                            let isEnabled = locationReady && isHost && hasMinimumPlayers && hunterSlotsConfigured && !viewModel.isBeginningGame
                            
                            Button(action: {
                                if isEnabled {
                                    HapticFeedbackManager.shared.selection()
                                    print("🎮 ManhuntLobbyView: Begin game button pressed")
                                    withAnimation(.smoothTransition) {
                                        viewModel.beginGame()
                                    }
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
                CartoonMedallion(background: AppColors.manhuntPrimary, size: 36) {
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
                                gameCode.isEmpty ? AppColors.cartoonInk.opacity(0.35) : AppColors.hiderPrimary,
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

                    guard gameCode.count == 6 else {
                        errorMessage = "Please enter a 6-digit game code."
                        showErrorAlert = true
                        return
                    }
                    
                    guard gameCode.allSatisfy({ $0.isNumber }) else {
                        errorMessage = "Game code must contain only numbers."
                        showErrorAlert = true
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
                .buttonStyle(IconButtonStyle(size: 44, color: (gameCode.count == 6 && viewModel.locationService.isReadyForGameplay) ? AppColors.hiderPrimary : AppColors.cartoonInk.opacity(0.45)))
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
        case .hunter: return AppColors.manhuntPrimary
        case .hider: return AppColors.hiderPrimary
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
