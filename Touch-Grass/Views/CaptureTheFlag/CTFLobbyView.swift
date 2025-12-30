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
    @State private var pendingAlertAction: GameService.BeginGameErrorAction? = nil
    @State private var showNoProfileNameAlert: Bool = false
    @State private var showExitConfirmation: Bool = false
    @State private var gameCode: String = ""
    @State private var bubbleStartRadius: Double = 300
    @State private var teamABase: CLLocationCoordinate2D? = nil
    @State private var teamBBase: CLLocationCoordinate2D? = nil
    @State private var contentAppeared: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var logoGlow: CGFloat = 0.5
    
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
        ZStack {
            // Aesthetic Gradient Background
            aestheticBackground
                .ignoresSafeArea()
            
            // Lobby Content Panel
            lobbyContentPanel
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.gameService.session?.id)
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
            
            // Staggered entrance animation
            withAnimation(.smoothTransition.delay(0.1)) {
                contentAppeared = true
            }
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
        .alert("Cannot Begin Game", isPresented: $viewModel.showGameOverAlert) {
            // Primary action button based on error type
            if let action = pendingAlertAction {
                switch action {
                case .openSettings:
                    Button("Open Settings") {
                        viewModel.showGameOverAlert = false
                        showBubbleSettings = true
                        pendingAlertAction = nil
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.showGameOverAlert = false
                        pendingAlertAction = nil
                    }
                case .openTeamManagement:
                    Button("Manage Teams") {
                        viewModel.showGameOverAlert = false
                        showTeamManagement = true
                        pendingAlertAction = nil
                    }
                    Button("Cancel", role: .cancel) {
                        viewModel.showGameOverAlert = false
                        pendingAlertAction = nil
                    }
                case .openSessionSetup:
                    Button("OK", role: .cancel) {
                        viewModel.showGameOverAlert = false
                        pendingAlertAction = nil
                    }
                case .dismiss:
                    Button("OK") {
                        viewModel.showGameOverAlert = false
                        pendingAlertAction = nil
                    }
                }
            } else {
                Button("OK") {
                    viewModel.showGameOverAlert = false
                    pendingAlertAction = nil
                }
            }
        } message: {
            Text(viewModel.gameOverMessage)
        }
        .onChange(of: viewModel.gameService.beginGameError) { oldValue, newValue in
            if let error = newValue {
                viewModel.gameOverMessage = error
                pendingAlertAction = viewModel.gameService.beginGameErrorAction
                viewModel.showGameOverAlert = true
            }
        }
        .onChange(of: viewModel.gameService.beginGameErrorAction) { oldValue, newValue in
            // Update pending action when it changes
            pendingAlertAction = newValue
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
        .alert("Profile Name Required", isPresented: $showNoProfileNameAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please add your name to your profile to start a game. You can update your profile name in the Profile tab.")
        }
        .alert("Exit Lobby", isPresented: $showExitConfirmation) {
            Button("Yes", role: .destructive) {
                // CRASH FIX: Wrap state modifications in Task to avoid "Modifying state during view update"
                Task { @MainActor in
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
            }
            Button("No", role: .cancel) { }
        } message: {
            Text("Going back to main menu will close this lobby. Are you sure?")
        }
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
    
    // CTF game title view (logo-based) - matches Touch Grass logo size and styling
    private var gameTitleView: some View {
        ZStack {
            // Outer glow effect (more pronounced for title screen)
            Image("CTF")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 650, maxHeight: 280)
                .blur(radius: 20 * logoGlow)
                .opacity(0.7 * logoGlow)
                .offset(y: 4)
            
            // Middle glow layer
            Image("CTF")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 650, maxHeight: 280)
                .blur(radius: 10 * logoGlow)
                .opacity(0.5 * logoGlow)
                .offset(y: 2)
            
            // Main logo (with pulsing animation)
            Image("CTF")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 650, maxHeight: 280)
                .scaleEffect(pulseScale)
                .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                .shadow(color: primaryColor.opacity(0.7 * logoGlow), radius: 25 * logoGlow, x: 0, y: 0)
                .shadow(color: secondaryColor.opacity(0.5 * logoGlow), radius: 35 * logoGlow, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            // Animate logo glow
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                logoGlow = 1.0
            }
            // Subtle pulse animation
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.02
            }
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
                    .foregroundColor(primaryColor)
                    .font(.title3)
                Text("Players")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Info icon
                Button(action: {
                    showPlayerListInfo = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(primaryColor)
                }
            }
            
            Divider()
            
            // Team distribution summary
            let teamAPlayers = session.players.filter { $0.role == .teamA && $0.isAlive }
            let teamBPlayers = session.players.filter { $0.role == .teamB && $0.isAlive }
            let eliminated = session.players.filter { !$0.isAlive }
            
            if !session.players.isEmpty {
                HStack(spacing: AppSpacing.md) {
                    // Team A count
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.ctfTeamA)
                        Text("A")
                            .font(AppTypography.labelSmall())
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.ctfTeamA)
                        Text("\(teamAPlayers.count)")
                            .font(AppTypography.labelSmall())
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.ctfTeamA)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.ctfTeamA.opacity(0.15))
                    )
                    
                    // Team B count
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.ctfTeamB)
                        Text("B")
                            .font(AppTypography.labelSmall())
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.ctfTeamB)
                        Text("\(teamBPlayers.count)")
                            .font(AppTypography.labelSmall())
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.ctfTeamB)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(AppColors.ctfTeamB.opacity(0.15))
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
                    let isHost = viewModel.gameService.currentPlayer?.id == session.hostId
                    let isSelf = player.id == viewModel.gameService.currentPlayer?.id
                    let canManageFlag = isHost || isSelf // Host or self can set flag
                    let canManageLeader = isHost // Only host can set team leader
                    
                HStack(spacing: AppSpacing.sm) {
                        // Flag button (if can manage)
                        if canManageFlag && (player.role == .teamA || player.role == .teamB) {
                            Button(action: {
                                viewModel.gameService.setFlag(playerId: player.id, isFlag: !player.isFlag)
                            }) {
                                Image(systemName: player.isFlag ? "flag.fill" : "flag")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(player.isFlag ? teamColor(for: player.role) : AppColors.textSecondary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
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
                                Image(systemName: player.isTeamLeader ? "star.fill" : "star")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(player.isTeamLeader ? AppColors.ctfPrimary : AppColors.textSecondary)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
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
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(primaryColor)
                                    .frame(width: 28, height: 28)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // Leader badge (replaces team badge when player is team leader)
                        if player.isTeamLeader {
                            Text("LEADER")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(AppColors.ctfPrimary)
                                )
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
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(player.isFlag ? teamColor(for: player.role).opacity(0.5) : Color.clear, lineWidth: 2)
                            )
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
                        viewModel.selectedGameType = .captureTheFlag
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
                                
                                Text("Start a new Capture The Flag session")
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
                    .accessibilityHint("Creates a new Capture The Flag game session")
                    
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
                                // Manage Teams Button
                                Button(action: { showTeamManagement = true }) {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(systemName: "person.2.badge.gearshape.fill")
                                            .font(.title3)
                                        Text("Manage Teams")
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
                        if let session = viewModel.gameService.session {
                            let currentPlayer = viewModel.gameService.currentPlayer
                            let isHost = currentPlayer?.id == session.hostId
                            Button(action: {
                                if isHost == true {
                                    HapticFeedbackManager.shared.selection()
                                    print("🎮 CTFLobbyView: Begin game button pressed")
                                    withAnimation(.smoothTransition) {
                                        viewModel.beginGame()
                                    }
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
                                                colors: (isHost == true) ? [
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
                                        .shadow(color: (isHost == true) ? primaryColor.opacity(0.4) : Color.clear, radius: 12, x: 0, y: 6)
                                )
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .disabled(isHost != true || viewModel.isBeginningGame)
                            .opacity((isHost == true && !viewModel.isBeginningGame) ? 1.0 : 0.6)
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
                                gameCode.isEmpty ? AppColors.textSecondary.opacity(0.3) : primaryColor,
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
                    guard gameCode.count == 6 else {
                        return
                    }
                    
                    guard gameCode.allSatisfy({ $0.isNumber }) else {
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
                        .font(.title2)
                        .foregroundColor(gameCode.isEmpty ? AppColors.textSecondary : primaryColor)
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
    
    private func teamColor(for role: PlayerRole) -> Color {
        switch role {
        case .teamA: return AppColors.ctfTeamA
        case .teamB: return AppColors.ctfTeamB
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
