//
//  CTFLobbyView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//
import SwiftUI
import CoreLocation
import UIKit

struct CTFLobbyView: View {
    @ObservedObject var viewModel: GameViewModel
    let onBackToMenu: () -> Void
    #if DEBUG
    @State private var showDebugTestPanel = false
    #endif
    
    @State private var showBubbleSettings = false
    @State private var showJoinGameInput = false
    @State private var showTeamManagement = false
    @State private var showGameInfo = false
    @State private var showPlayerListInfo = false
    @State private var showNoProfileNameAlert: Bool = false
    @State private var showExitConfirmation: Bool = false
    @State private var gameCode: String = ""
    @State private var hasCopiedJoinCode: Bool = false
    @State private var resetCopiedJoinCodeTask: Task<Void, Never>? = nil
    @State private var bubbleStartRadius: Double = 300
    @State private var teamABase: CLLocationCoordinate2D? = nil
    @State private var teamBBase: CLLocationCoordinate2D? = nil
    @State private var pulseScale: CGFloat = 1.0
    
    // OPTIMIZATION: Cache gameService state to reduce re-renders
    @State private var cachedGameState: GameState = .lobby
    @State private var cachedSession: GameSession? = nil
    
    // Hardcoded CTF theme properties
    private var primaryColor: Color {
        AppColors.ctfPrimary
    }
    
    private var secondaryColor: Color {
        AppColors.ctfSecondary
    }
    
    private var lightColor: Color {
        AppColors.ctfLight
    }
    
    private var gameTagline: String {
        "Capture, Return, Score"
    }
    
    var body: some View {
        let _ = {
            #if DEBUG
            let timestamp = Date().timeIntervalSince1970
            print("🔍 DEBUG: [\(String(format: "%.3f", timestamp))] CTFLobbyView body rendering")
            print("🔍 DEBUG:   - viewModel.selectedGame: \(String(describing: viewModel.selectedGame))")
            print("🔍 DEBUG:   - viewModel.isServicesInitializing: \(viewModel.isServicesInitializing)")
            print("🔍 DEBUG:   - cachedSession?.id: \(String(describing: cachedSession?.id))")
            print("🔍 DEBUG:   - cachedGameState: \(cachedGameState)")
            #endif
        }()
        
        return Group {
            // OPTIMIZATION: Use cached session instead of accessing gameService directly
            if cachedSession != nil {
                switch cachedGameState {
                case .flagPlacement:
                    // Show flag placement view
                    CTFFlagPlacementView(
                        gameService: viewModel.gameService,
                        locationService: viewModel.locationService
                    )
                case .active:
                    // Show active game view
                    CTFActiveGameView(
                        gameService: viewModel.gameService,
                        locationService: viewModel.locationService,
                        viewModel: viewModel
                    )
                case .ended:
                    // Show game end view - use cached session
                    if let session = cachedSession,
                       let gameStats = viewModel.gameService.gameStats {
                        CTFGameEndView(
                            session: session,
                            gameStats: gameStats,
                            currentPlayer: viewModel.gameService.currentPlayer,
                            gameService: viewModel.gameService,
                            onPlayAgain: {
                                viewModel.playAgain()
                            },
                            onBackToLobby: {
                                // Return to lobby (playAgain resets to lobby)
                                viewModel.playAgain()
                            }
                        )
                    } else {
                        // Fallback if session/stats not available
                        VStack {
                            Text("Game Ended")
                                .font(.title)
                            Button("Back to Menu") {
                                onBackToMenu()
                            }
                        }
                    }
                case .lobby:
                    // Show lobby content
                    ZStack {
                        LandscapeBackground()
                            .drawingGroup()
                            .ignoresSafeArea(.all)
                            .zIndex(0)
                        AestheticBackground(gradientOffset: 0, pulseScale: 1.0)
                            .ignoresSafeArea(.all)
                            .allowsHitTesting(false)
                            .zIndex(1)
                        lobbyContentPanel.zIndex(2)
                    }
                }
            } else {
                // No session - show lobby content
                ZStack {
                    LandscapeBackground()
                        .drawingGroup()
                        .ignoresSafeArea(.all)
                        .zIndex(0)
                    AestheticBackground(gradientOffset: 0, pulseScale: 1.0)
                        .ignoresSafeArea(.all)
                        .allowsHitTesting(false)
                        .zIndex(1)
                    lobbyContentPanel.zIndex(2)
                }
            }
        }
        // OPTIMIZATION: Remove animation modifiers that cause re-renders - transitions handle animations
        #if DEBUG
        .debugButton(showDebugTestPanel: $showDebugTestPanel, viewModel: viewModel)
        .sheet(isPresented: $showDebugTestPanel) {
            DebugTestPanelView(viewModel: viewModel)
        }
        #endif
        .onAppear {
            // Reset all state when view appears to ensure clean start for this game mode
            bubbleStartRadius = 300
            teamABase = nil
            teamBBase = nil
            gameCode = ""
            showBubbleSettings = false
            showJoinGameInput = false
            showTeamManagement = false
            showGameInfo = false
            
            // OPTIMIZATION: Cache gameService state on appear
            cachedGameState = viewModel.gameService.gameState
            cachedSession = viewModel.gameService.session
        }
        // OPTIMIZATION: Update cached state directly from GameService.
        // `GameService` is nested inside `GameViewModel`, so relying only
        // on `onChange(of: viewModel.gameService.session)` can miss
        // listener-driven roster updates if the parent view is not
        // invalidated first.
        .onReceive(viewModel.gameService.$gameState) { newValue in
            let oldValue = cachedGameState
            guard oldValue != newValue else { return }
            cachedGameState = newValue
        }
        .onReceive(viewModel.gameService.$session) { newValue in
            cachedSession = newValue
        }
        .onChange(of: viewModel.gameService.session?.gameType) { oldValue, newValue in
            // If game type changes, reset all configuration state
            if oldValue != nil && oldValue != newValue {
                bubbleStartRadius = 300
                teamABase = nil
                teamBBase = nil
                gameCode = ""
                showBubbleSettings = false
                showJoinGameInput = false
                showTeamManagement = false
            }
        }
        .themedNotice(
            isPresented: lobbyNoticeBinding,
            primaryColor: primaryColor,
            secondaryColor: AppColors.ctfTeamBSecondary,
            iconName: "exclamationmark.triangle.fill",
            headerTitle: "Capture The Flag",
            headerSubtitle: viewModel.lobbyNotice?.title ?? "",
            title: viewModel.lobbyNotice?.title ?? "",
            message: viewModel.lobbyNotice?.message ?? "",
            buttons: lobbyNoticeButtons
        )
        .onChange(of: viewModel.gameService.beginGameError) { _, newValue in
            if let error = newValue {
                viewModel.presentLobbyNotice(LobbyNotice(
                    title: "Can't begin game",
                    message: error,
                    primaryAction: mappedNoticeAction(from: viewModel.gameService.beginGameErrorAction)
                ))
            }
        }
        .sheet(isPresented: $showBubbleSettings) {
            CTFBubbleSettingsView(
                startRadius: $bubbleStartRadius,
                teamABase: $teamABase,
                teamBBase: $teamBBase,
                onStart: { selectedCenter in
                    print("⚙️ CTFLobbyView: Configure game button pressed")
                    print("   Selected center: \(selectedCenter.latitude), \(selectedCenter.longitude)")
                    // Configure game first, then dismiss sheet
                    viewModel.configureGame(
                        bubbleStartRadius: bubbleStartRadius,
                        duration: nil, // No time limit for CTF
                        hunterCount: 0, // CTF doesn't use hunterCount
                        center: selectedCenter,
                        scoreLimit: nil, // No score limit in CTF
                        teamABase: teamABase,
                        teamBBase: teamBBase
                    )
                    // Dismiss sheet after configuration
                    showBubbleSettings = false
                },
                userLocation: viewModel.locationService.coordinate,
                maxPlayers: viewModel.gameService.session?.players.count ?? 1
            )
        }
        .sheet(isPresented: $showTeamManagement) {
            if let session = viewModel.gameService.session {
                CTFTeamManagementView(
                    session: session,
                    currentPlayer: viewModel.gameService.currentPlayer,
                    onSetTeam: { playerId, team in
                        viewModel.gameService.setTeam(playerId: playerId, team: team)
                    },
                    onSetFlag: { playerId, isFlag in
                        viewModel.gameService.setFlag(playerId: playerId, isFlag: isFlag)
                    },
                    onSetTeamLeader: { playerId, isTeamLeader in
                        viewModel.gameService.setTeamLeader(playerId: playerId, isTeamLeader: isTeamLeader)
                    }
                )
            }
        }
        .sheet(isPresented: $showGameInfo) {
            CTFInfoView()
        }
        .sheet(isPresented: $showPlayerListInfo) {
            playerListInfoSheet
        }
        .themedNotice(
            isPresented: $showNoProfileNameAlert,
            primaryColor: primaryColor,
            secondaryColor: AppColors.ctfTeamBSecondary,
            iconName: "person.crop.circle.badge.exclamationmark.fill",
            headerTitle: "Profile",
            headerSubtitle: "Name required",
            title: "Add a name first",
            message: "Add your name to start a game. You can set your profile name in Settings.",
            buttons: [ThemedNoticeButton.ok()]
        )
        .themedExitLobbyConfirmation(
            isPresented: $showExitConfirmation,
            primaryColor: primaryColor,
            secondaryColor: AppColors.ctfTeamBSecondary,
            iconName: "flag.fill"
        ) {
            Task { @MainActor in
                if await viewModel.leaveCurrentSessionFromUserAction() {
                    onBackToMenu()
                }
            }
        }
        .onChange(of: viewModel.gameService.session?.id) { _, newId in
            if newId != nil && showJoinGameInput {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showJoinGameInput = false
                    gameCode = ""
                }
                viewModel.clearJoinCodeError()
            }
        }
    }
    
    // MARK: - Lobby Content Panel
    
    private var lobbyContentPanel: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Back Button
                HStack {
                    Button(action: {
                        if viewModel.gameService.session != nil {
                            showExitConfirmation = true
                        } else {
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
	                        .background(Capsule().fill(AppColors.cartoonCream))
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
    
    // MARK: - Themed Notice Helpers

    private var lobbyNoticeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.lobbyNotice != nil },
            set: { newValue in
                if !newValue { viewModel.lobbyNotice = nil }
            }
        )
    }

    private var lobbyNoticeButtons: [ThemedNoticeButton] {
        guard let notice = viewModel.lobbyNotice else { return [ThemedNoticeButton.ok()] }
        switch notice.primaryAction {
        case .dismiss:
            return [ThemedNoticeButton.ok()]
        case .openBubbleSettings:
            return [
                ThemedNoticeButton(title: "Cancel", icon: nil, role: .secondary, action: {}),
                ThemedNoticeButton(title: "Open Settings", icon: "gearshape.fill", role: .primary) {
                    showBubbleSettings = true
                }
            ]
        case .openTeamManagement:
            return [
                ThemedNoticeButton(title: "Cancel", icon: nil, role: .secondary, action: {}),
                ThemedNoticeButton(title: "Manage Teams", icon: "person.2.badge.gearshape.fill", role: .primary) {
                    showTeamManagement = true
                }
            ]
        case .openSessionSetup:
            return [ThemedNoticeButton.ok()]
        }
    }

    private func mappedNoticeAction(from action: GameService.BeginGameErrorAction?) -> LobbyNotice.Action {
        switch action {
        case .openSettings: return .openBubbleSettings
        case .openTeamManagement: return .openTeamManagement
        case .openSessionSetup: return .openSessionSetup
        case .dismiss, .none: return .dismiss
        }
    }

    private var lobbyHeader: some View {
        let hasSession = viewModel.gameService.session != nil
        return ZStack {
            // Game Title - Dynamic based on game type
            VStack(spacing: AppSpacing.sm) {
                // Game Logo/Title, smaller when a session exists to save vertical space
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
    
    // CTF game title view (logo-based) - matches Touch Grass logo size and styling
    private func gameTitleView(compact: Bool = false) -> some View {
        let maxH: CGFloat = compact ? 100 : 216
        let maxW: CGFloat = compact ? 360 : 780
        return Image("CTF")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: maxW, maxHeight: maxH)
            .scaleEffect(pulseScale)
            .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
        .frame(maxWidth: .infinity)
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
                    .frame(height: 32)

                // Players Count
                VStack(spacing: AppSpacing.xs) {
                    Text("Players")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    HStack(spacing: 4) {
                        Text("\(session.players.count)")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                        Text("/")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(AppColors.textSecondary)
                        Text("\(GameService.maxPlayersPerSession)")
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                Spacer()
            }

            // Join Code Section (only show if host)
            if let currentPlayer = viewModel.gameService.currentPlayer,
               session.isDeviceHost(currentPlayer) {
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
                                .foregroundColor(AppColors.textSecondary)
                        Text("\(Int(bubble.startRadius))m radius")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                        Spacer()
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.cartoonInk, lineWidth: 2))
        .shadow(color: AppColors.cartoonInk, radius: 0, x: 4, y: 4)
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
                    .foregroundColor(primaryColor)
                    .font(.title3)
                Text("Players (\(session.players.count))")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)

                Spacer()

                // Info icon
	                Button(action: {
	                    showPlayerListInfo = true
	                }) {
	                    CartoonLobbyIconButtonLabel(systemName: "info.circle.fill")
	                }
	                .buttonStyle(IconButtonStyle(size: 30, color: primaryColor))
	            }

            Divider()

            // Player List
            VStack(alignment: .leading, spacing: 6) {
            ForEach(session.players) { player in
                    let isHost = session.isDeviceHost(viewModel.gameService.currentPlayer)
                    let isSelf = player.id == viewModel.gameService.currentPlayer?.id
                    let canManageFlag = isHost || isSelf // Host or self can set flag
                    let canManageLeader = isHost // Only host can set team leader

                HStack(spacing: AppSpacing.sm) {
                        // Flag button (if can manage)
                        if canManageFlag && (player.role == .teamA || player.role == .teamB) {
	                            Button(action: {
	                                viewModel.gameService.setFlag(playerId: player.id, isFlag: !player.isFlag)
	                            }) {
	                                CartoonLobbyIconButtonLabel(systemName: player.isFlag ? "flag.fill" : "flag")
	                            }
	                            .buttonStyle(IconButtonStyle(size: 30, color: player.isFlag ? teamColor(for: player.role) : AppColors.cartoonInk.opacity(0.5)))
                        } else if player.isFlag {
                            // Show flag icon if this player is the flag (read-only)
                            Image(systemName: "flag.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(teamColor(for: player.role))
                                .frame(width: 28, height: 28)
                        } else {
                            // Show empty flag icon for non-flag players
                            Image(systemName: "flag")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.textSecondary.opacity(0.3))
                                .frame(width: 28, height: 28)
                        }
                        
                        // Team leader button (if host)
                        if canManageLeader && (player.role == .teamA || player.role == .teamB) {
	                            Button(action: {
	                                viewModel.gameService.setTeamLeader(playerId: player.id, isTeamLeader: !player.isTeamLeader)
	                            }) {
	                                CartoonLobbyIconButtonLabel(systemName: player.isTeamLeader ? "star.fill" : "star")
	                            }
	                            .buttonStyle(IconButtonStyle(size: 30, color: player.isTeamLeader ? AppColors.ctfPrimary : AppColors.cartoonInk.opacity(0.5)))
                        } else if player.isTeamLeader {
                            // Show star icon if this player is the team leader (read-only)
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.ctfPrimary)
                                .frame(width: 28, height: 28)
                        } else {
                            Spacer()
                                .frame(width: 28, height: 28)
                        }
                        
                        // Profile picture or team icon
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
                                            .stroke(teamColor(for: player.role), lineWidth: 2)
                                    )
                            } else {
                                // Team icon fallback
                                ZStack {
                                    Circle()
                                        .fill(teamColor(for: player.role).opacity(0.2))
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: "flag.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(teamColor(for: player.role))
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
                        
                        // Team badge (only show if not team leader - leader badge replaces it)
                        if !player.isTeamLeader {
                            if player.role == .teamA || player.role == .teamB {
                                Text(player.role == .teamA ? "A" : "B")
                                    .font(AppTypography.caption())
                                    .fontWeight(.bold)
                                    .foregroundColor(teamColor(for: player.role))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(teamColor(for: player.role).opacity(0.15))
                                            .overlay(
                                                Capsule()
                                                    .stroke(teamColor(for: player.role), lineWidth: 1.5)
                                            )
                                    )
                            } else {
                                Text("Unassigned")
                                    .font(AppTypography.caption())
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.textSecondary)
                                    )
                            }
                        }
                        
                        // Team switch button (if host or self, and player is on a team)
                        if (isHost || isSelf) && (player.role == .teamA || player.role == .teamB) {
	                            Button(action: {
	                                let newTeam: Flag.Team = player.role == .teamA ? .teamB : .teamA
	                                viewModel.gameService.setTeam(playerId: player.id, team: newTeam)
	                            }) {
	                                CartoonLobbyIconButtonLabel(systemName: "arrow.left.arrow.right")
	                            }
	                            .buttonStyle(IconButtonStyle(size: 30, color: primaryColor))
	                        }
                        
                        // Leader badge (replaces team badge when player is team leader)
                        if player.isTeamLeader {
                            Text("LEADER")
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(AppColors.ctfPrimary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 1.5))
                        }
                    
                        // You badge
                    if player.id == viewModel.gameService.currentPlayer?.id {
                            Text("You")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                            .background(primaryColor)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 1.5))
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
                            .fill(player.id == viewModel.gameService.currentPlayer?.id ? AppColors.cartoonSun2 : AppColors.cartoonCream2)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(player.isFlag ? teamColor(for: player.role) : AppColors.cartoonInk.opacity(0.25), lineWidth: 2)
                            )
                    )
                }
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.cartoonInk, lineWidth: 2))
        .shadow(color: AppColors.cartoonInk, radius: 0, x: 4, y: 4)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: session.players.count)
    }
    
    private var lobbyControls: some View {
        VStack(spacing: AppSpacing.md) {
            let locationReady = viewModel.locationService.isReadyForGameplay

            LocationPermissionCard(locationService: viewModel.locationService, accent: primaryColor)

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
                        if ProfileService.shared.displayName.isEmpty {
                            showNoProfileNameAlert = true
                        } else {
                            viewModel.selectedGameType = .captureTheFlag
                            viewModel.createSession()
                        }
                    }) {
                        CartoonLobbyActionCard(
                            iconName: "plus.circle.fill",
                            title: "Create Game",
                            subtitle: "Start a new Capture The Flag session",
                            accent: primaryColor
                        )
                    }
                    .buttonStyle(CartoonCardButtonStyle())
                    .disabled(showJoinGameInput || !locationReady)
                    .opacity((showJoinGameInput || !locationReady) ? 0.6 : 1.0)
                    .accessibilityLabel("Create game")
                    .accessibilityHint("Creates a new Capture The Flag game session")

                    // Join Game Card
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            showJoinGameInput.toggle()
                            if !showJoinGameInput { gameCode = "" }
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
                       session.isDeviceHost(currentPlayer),
                       session.bubble == nil {
                        Button(action: { showBubbleSettings = true }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                Text("Configure Game")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .disabled(!locationReady)
                        .buttonStyle(CartoonButtonStyle(accent: AppColors.warning, isDisabled: !locationReady))
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                    } else {
                        // Game configured - show checkmark button that can be tapped to reconfigure (host only)
	                        if let currentPlayer = viewModel.gameService.currentPlayer,
	                           let session = viewModel.gameService.session,
	                           session.isDeviceHost(currentPlayer) {
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
                           session.isDeviceHost(currentPlayer) {
	                            VStack(spacing: AppSpacing.md) {
	                                // Manage Teams Button
	                                Button(action: { showTeamManagement = true }) {
	                                    CartoonLobbyActionCard(
	                                        iconName: "person.2.badge.gearshape.fill",
	                                        title: "Manage Teams",
	                                        subtitle: "Assign teams, flags, and leaders",
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
                        if let session = viewModel.gameService.session {
                            let currentPlayer = viewModel.gameService.currentPlayer
                            let isHost = session.isDeviceHost(currentPlayer)
                            let playerCount = session.players.count
                            let minimumPlayers = session.gameType.minimumPlayers
                            let hasMinimumPlayers = playerCount >= minimumPlayers

                            let teamAPlayers = session.players.filter { $0.role == .teamA }
                            let teamBPlayers = session.players.filter { $0.role == .teamB }
                            let teamAHasLeader = teamAPlayers.contains { $0.isTeamLeader }
                            let teamAHasFlag = teamAPlayers.contains { $0.isFlag }
                            let teamBHasLeader = teamBPlayers.contains { $0.isTeamLeader }
                            let teamBHasFlag = teamBPlayers.contains { $0.isFlag }
                            let hasCTFRequirements = teamAHasLeader && teamAHasFlag && teamBHasLeader && teamBHasFlag

                            let isEnabled = locationReady && (isHost == true) && hasMinimumPlayers && hasCTFRequirements && !viewModel.isBeginningGame

                            Button(action: {
                                if isEnabled {
                                    HapticFeedbackManager.shared.selection()
                                    print("🎮 CTFLobbyView: Begin game button pressed")
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
                                    }
                                    Text(viewModel.isBeginningGame ? "Starting..." : "Begin Game")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: primaryColor, isDisabled: !isEnabled))
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
        JoinGameCodeInput(
            accentColor: primaryColor,
            title: "Enter Game Code",
            code: $gameCode,
            isLocationReady: viewModel.locationService.isReadyForGameplay,
            isJoining: viewModel.isJoiningGame,
            errorState: viewModel.joinCodeError,
            onSubmit: {
                guard viewModel.locationService.isReadyForGameplay else {
                    viewModel.locationService.requestPermission()
                    return
                }
                print("🔍 Joining game with code: \(gameCode)")
                viewModel.joinGame(joinCode: gameCode)
            },
            onClearError: {
                viewModel.clearJoinCodeError()
            }
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
    
    private func teamColor(for role: PlayerRole) -> Color {
        switch role {
        case .teamA: return AppColors.ctfTeamA
        case .teamB: return AppColors.ctfTeamB
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
    
    // MARK: - Player List Info Sheet
    
    private var playerListInfoSheet: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Player List Icons")
                            .font(AppTypography.displaySmall())
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [primaryColor, secondaryColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Understanding the icons and badges in the player list")
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, AppSpacing.md)
                    
                    Divider()
                    
                    // Icon Explanations
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        // Flag Icon
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            VStack(spacing: AppSpacing.xs) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AppColors.ctfTeamA)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "flag")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary.opacity(0.3))
                                    .frame(width: 40, height: 40)
                            }
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Flag Icon")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Filled flag (colored) = This player is the team flag")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Empty flag (gray) = This player is not the flag")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Tap to toggle flag status (host or self only)")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textTertiary)
                                    .italic()
                            }
                        }
                        
                        Divider()
                        
                        // Star Icon
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            VStack(spacing: AppSpacing.xs) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AppColors.ctfPrimary)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: "star")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(AppColors.textSecondary)
                                    .frame(width: 40, height: 40)
                            }
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Team Leader Icon")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Filled star = This player is the team leader")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Empty star = This player is not the team leader")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Tap to toggle leader status (host only)")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textTertiary)
                                    .italic()
                            }
                        }
                        
                        Divider()
                        
                        // Team Badge
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            HStack(spacing: AppSpacing.sm) {
                                Text("A")
                                    .font(AppTypography.caption())
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.ctfTeamA)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.ctfTeamA.opacity(0.15))
                                            .overlay(
                                                Capsule()
                                                    .stroke(AppColors.ctfTeamA, lineWidth: 1.5)
                                            )
                                    )
                                
                                Text("B")
                                    .font(AppTypography.caption())
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.ctfTeamB)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(AppColors.ctfTeamB.opacity(0.15))
                                            .overlay(
                                                Capsule()
                                                    .stroke(AppColors.ctfTeamB, lineWidth: 1.5)
                                            )
                                    )
                            }
                            .frame(width: 100)
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Team Badge")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Shows which team the player is on")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("A = Team A (Blue), B = Team B (Red)")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Hidden when player is team leader (shows LEADER badge instead)")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textTertiary)
                                    .italic()
                            }
                        }
                        
                        Divider()
                        
                        // Leader Badge
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            Text("LEADER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppColors.ctfPrimary)
                                )
                                .frame(width: 60)
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Leader Badge")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Shows when a player is designated as team leader")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Replaces the team badge (A/B) when active")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        
                        Divider()
                        
                        // Team Switch Button
                        HStack(alignment: .top, spacing: AppSpacing.md) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(primaryColor)
                                .frame(width: 40, height: 40)
                            
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Team Switch")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Tap to switch player between Team A and Team B")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Only visible to host or the player themselves")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textTertiary)
                                    .italic()
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.md)
                }
                .padding(AppSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showPlayerListInfo = false
                    }
                    .foregroundColor(primaryColor)
                }
            }
        }
    }
}
