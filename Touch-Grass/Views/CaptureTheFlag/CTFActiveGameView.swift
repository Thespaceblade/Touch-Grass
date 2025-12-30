//
//  CTFActiveGameView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import MapKit

struct CTFActiveGameView: View {
    @ObservedObject var gameService: GameService
    @ObservedObject var locationService: LocationService
    var viewModel: GameViewModel? = nil // Optional for debug panel
    
    #if DEBUG
    @State private var showDebugTestPanel = false
    #endif
    
    @State private var mapType: MKMapType = .standard
    @State private var showPlayerLabels: Bool = true
    @State private var zoomToBubbleTrigger: Bool = false
    @State private var centerOnPlayerTrigger: Bool = false
    @State private var timerPulseScale: CGFloat = 1.0
    @State private var lastHapticThreshold: Int = -1
    @State private var currentTime: Date = Date()
    @State private var timer: Timer?
    
    // Flag phone states
    @State private var showFlagAcquired: Bool = false
    @State private var flagAcquiredTeam: Flag.Team? = nil
    @State private var flagAcquiredAnimationScale: CGFloat = 1.0
    
    // Notification dismiss timers
    @State private var teamADisconnectDismissTimer: Timer?
    @State private var teamBDisconnectDismissTimer: Timer?
    @State private var showTeamADisconnect: Bool = false
    @State private var showTeamBDisconnect: Bool = false
    
    var body: some View {
        // Check if current player is a flag player
        if let currentPlayer = gameService.currentPlayer,
           currentPlayer.isFlag,
           let session = gameService.session {
            // Flag phone view - solid color background with "FLAG" title
            flagPhoneView(session: session, player: currentPlayer)
        } else {
            // Regular player view
            let bubbleCenter = gameService.session?.bubble?.center
            let bubbleRadius = currentBubbleRadius
            
            ZStack {
            // Catch animation overlay
            if gameService.catchAnimationTrigger {
                Color.green.opacity(0.4)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.3), value: gameService.catchAnimationTrigger)
            }
            
            // Elimination animation overlay
            if gameService.eliminationAnimationTrigger {
                Color.red.opacity(0.4)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.3), value: gameService.eliminationAnimationTrigger)
            }
            
            // Full-screen map with bubble and players
            MapViewRepresentable(
                userCoordinate: locationService.coordinate,
                bubbleCenter: bubbleCenter,
                bubbleRadius: bubbleRadius,
                warningLevel: gameService.warningLevel,
                players: gameService.session?.players ?? [],
                currentPlayerId: gameService.currentPlayer?.id,
                currentPlayerRole: gameService.currentPlayer?.role,
                gameType: gameService.session?.gameType,
                flags: gameService.session?.flags ?? [],
                teamABase: gameService.session?.teamABase,
                teamBBase: gameService.session?.teamBBase,
                teamASafeZone: gameService.session?.teamASafeZone,
                teamBSafeZone: gameService.session?.teamBSafeZone,
                isPingActive: false, // CTF doesn't use ping obfuscation
                zoneRadius: bubbleRadius,
                mapType: $mapType,
                showPlayerLabels: $showPlayerLabels,
                zoomToBubbleTrigger: $zoomToBubbleTrigger,
                centerOnPlayerTrigger: $centerOnPlayerTrigger
            )
            .ignoresSafeArea()
            
            // Flag disconnect notifications (for non-flag devices)
            if let session = gameService.session {
                flagDisconnectNotifications(session: session)
            }
            
            // Game HUD Overlay
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Top HUD - Timer and Status
                    topHUD
                        .padding(.leading, AppSpacing.md)
                        .padding(.top, AppSpacing.md)
                        .frame(maxWidth: geometry.size.width * 0.65)
                        .fixedSize(horizontal: false, vertical: true)
                
                // Map Controls
                HStack {
                    Spacer()
                    VStack(alignment: .trailing) {
                        MapControlsView(
                            mapType: $mapType,
                            showPlayerLabels: $showPlayerLabels,
                            onZoomToBubble: { zoomToBubbleTrigger = true },
                            onCenterOnPlayer: { centerOnPlayerTrigger = true },
                            bubbleExists: gameService.session?.bubble != nil,
                            playerLocationExists: locationService.coordinate != nil
                        )
                    }
                    .padding(.trailing, AppSpacing.sm)
                    .padding(.top, AppSpacing.md)
                }
                
                // Bottom Section
                VStack {
                    Spacer()
                    
                    VStack(spacing: AppSpacing.sm) {
                        // CTF Score Display
                        if let session = gameService.session {
                            ctfScoreDisplay(session: session)
                                .padding(.horizontal, AppSpacing.md)
                        }
                        
                        // Bottom Panel - Zone info, Players
                        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                            // Zone Info
                            if let bubble = gameService.session?.bubble {
                                compactZoneInfoCard(bubble: bubble)
                            }
                            
                            Spacer()
                            
                            // Players Count
                            if let session = gameService.session {
                                compactPlayersCard(session: session)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // CTF Flag Status Panel
                        if let session = gameService.session {
                            ctfFlagStatusPanel(session: session)
                                .padding(.horizontal, AppSpacing.md)
                        }
                        
                        // Bottom Stats Panel
                        bottomStatsPanel
                            .padding(.horizontal, AppSpacing.md)
                        
                        // CTF Flag Action Buttons
                        if let session = gameService.session {
                            ctfFlagActionButtons(session: session)
                                .padding(.horizontal, AppSpacing.md)
                        }
                    }
                    .padding(.bottom, AppSpacing.md)
                }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Note: allowsHitTesting removed - buttons need to be interactive!
            }
            
            // Toast Notifications
            VStack {
                if let eliminationMessage = gameService.lastEliminationMessage {
                    toastView(message: eliminationMessage, type: .elimination)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if let catchMessage = gameService.lastCatchMessage {
                    toastView(message: catchMessage, type: .playerCaught)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gameService.lastEliminationMessage)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: gameService.lastCatchMessage)
            
            // Network Error Banner
            if let networkError = gameService.networkError {
                VStack {
                    Spacer()
                    networkErrorBanner(message: networkError)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.lg)
                }
            }
            }
            #if DEBUG
            .overlay(alignment: .topTrailing) {
                if viewModel != nil {
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        showDebugTestPanel = true
                    }) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(AppColors.grassPrimary)
                                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
                            )
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                }
            }
            .sheet(isPresented: $showDebugTestPanel) {
                if let viewModel = viewModel {
                    DebugTestPanelView(viewModel: viewModel)
                }
            }
            #endif
        }
    }
    
    // MARK: - Top HUD
    
    private var topHUD: some View {
        HStack(spacing: AppSpacing.sm) {
            // Timer Display
            timerDisplay
            
            // Team Badge (CTF: TEAM A or TEAM B)
            if let currentPlayer = gameService.currentPlayer, currentPlayer.isAlive {
                let teamText = currentPlayer.role == .teamA ? "TEAM A" : "TEAM B"
                let teamColor = currentPlayer.role == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB
                let teamGradient = currentPlayer.role == .teamA ?
                    LinearGradient(
                        colors: [AppColors.ctfTeamA, AppColors.ctfTeamASecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [AppColors.ctfTeamB, AppColors.ctfTeamBSecondary],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                
                Text(teamText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(teamGradient)
                            .shadow(color: teamColor.opacity(0.5), radius: 4, x: 0, y: 2)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            } else {
                // Fallback for eliminated players
                Text("ELIMINATED")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AppColors.error)
                    )
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var timerDisplay: some View {
        // CTF has no time limit - return empty view
        EmptyView()
    }
    
    // MARK: - CTF Score Display
    
    private func ctfScoreDisplay(session: GameSession) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Team A Score
            VStack(spacing: AppSpacing.xs) {
                Text("Team A")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.ctfTeamA)
                Text("\(session.teamAScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.ctfTeamA)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.ctfTeamA.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.ctfTeamA.opacity(0.3), lineWidth: 2)
                    )
            )
            
            // VS Divider
            Text("VS")
                .font(AppTypography.labelMedium())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
            
            // Team B Score
            VStack(spacing: AppSpacing.xs) {
                Text("Team B")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.ctfTeamB)
                Text("\(session.teamBScore)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.ctfTeamB)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.ctfTeamB.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.ctfTeamB.opacity(0.3), lineWidth: 2)
                    )
            )
        }
    }
    
    // MARK: - CTF Flag Status Panel
    
    private func ctfFlagStatusPanel(session: GameSession) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Flag Status")
                .font(AppTypography.labelLarge())
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
            HStack(spacing: AppSpacing.md) {
                // Team A Flag
                flagStatusCard(
                    team: .teamA,
                    session: session
                )
                
                // Team B Flag
                flagStatusCard(
                    team: .teamB,
                    session: session
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
    
    private func flagStatusCard(team: Flag.Team, session: GameSession) -> some View {
        let teamColor = team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB
        let flagPlayer = session.players.first { $0.team == team && $0.isFlag }
        let isAtBase = flagPlayer != nil && session.flagCarriers[flagPlayer!.id] == nil
        let carrierId = flagPlayer.flatMap { session.flagCarriers[$0.id] }
        let carrierName = carrierId.flatMap { carrierId in
            session.players.first(where: { $0.id == carrierId })?.displayName
        }
        let flagPlayerName = flagPlayer?.displayName ?? "No Flag"
        
        return VStack(spacing: AppSpacing.xs) {
            Image(systemName: "flag.fill")
                .font(.title2)
                .foregroundColor(teamColor)
            
            Text(team.rawValue)
                .font(AppTypography.caption())
                .foregroundColor(teamColor)
            
            if flagPlayer == nil {
                Text("No Flag")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textTertiary)
            } else if isAtBase {
                Text("At Base")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.success)
                Text(flagPlayerName)
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            } else if let carrier = carrierName {
                Text("Carried by")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
                Text(carrier)
                    .font(AppTypography.bodySmall())
                    .fontWeight(.semibold)
                    .foregroundColor(teamColor)
            } else {
                Text("Dropped")
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.warning)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(teamColor.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(teamColor.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - CTF Flag Action Buttons
    
    private func ctfFlagActionButtons(session: GameSession) -> some View {
        Group {
            if let currentPlayer = gameService.currentPlayer,
               currentPlayer.isAlive,
               let playerTeam = currentPlayer.team,
               let playerLocation = locationService.coordinate {
                let playerLoc = CLLocation(latitude: playerLocation.latitude, longitude: playerLocation.longitude)
                let captureDistance: Double = session.catchDistance
                
                // Check player flags (new system)
                // Team A Flag
                if let teamAFlag = session.players.first(where: { $0.team == .teamA && $0.isFlag }) {
                    let flagLocation = teamAFlag.location
                    let distance = playerLoc.distance(from: flagLocation)
                    
                    if distance.isFinite && distance >= 0 && distance <= captureDistance {
                        // Capture button (enemy flag at base)
                        if teamAFlag.team != playerTeam && session.flagCarriers[teamAFlag.id] == nil {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.capturePlayerFlag(flagPlayerId: teamAFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.title3)
                                    Text("Capture Team A Flag")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.ctfPrimary, AppColors.ctfSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: AppColors.ctfPrimary.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        
                        // Take Possession button (your team's flag captured by enemy, you tagged the carrier)
                        if teamAFlag.team == playerTeam,
                           let enemyCarrierId = session.flagCarriers[teamAFlag.id],
                           let enemyCarrier = session.players.first(where: { $0.id == enemyCarrierId }),
                           enemyCarrier.team != playerTeam,
                           currentPlayer.id != enemyCarrierId {
                            // Show "Take Possession" button if flag is captured by enemy and you're not the carrier
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.takePossessionOfFlag(flagPlayerId: teamAFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.title3)
                                    Text("Take Possession")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.ctfTeamA, AppColors.ctfTeamASecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: AppColors.ctfTeamA.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        
                        // Return button (your team's flag captured - you have possession)
                        if teamAFlag.team == playerTeam,
                           let carrierId = session.flagCarriers[teamAFlag.id],
                           carrierId == currentPlayer.id {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.returnPlayerFlag(flagPlayerId: teamAFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.title3)
                                    Text("Return Team A Flag")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.ctfTeamA, AppColors.ctfTeamASecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: AppColors.ctfTeamA.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                
                // Team B Flag
                if let teamBFlag = session.players.first(where: { $0.team == .teamB && $0.isFlag }) {
                    let flagLocation = teamBFlag.location
                    let distance = playerLoc.distance(from: flagLocation)
                    
                    if distance.isFinite && distance >= 0 && distance <= captureDistance {
                        // Capture button (enemy flag at base)
                        if teamBFlag.team != playerTeam && session.flagCarriers[teamBFlag.id] == nil {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.capturePlayerFlag(flagPlayerId: teamBFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.title3)
                                    Text("Capture Team B Flag")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.ctfPrimary, AppColors.ctfSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: AppColors.ctfPrimary.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        
                        // Take Possession button (your team's flag captured by enemy, you tagged the carrier)
                        if teamBFlag.team == playerTeam,
                           let enemyCarrierId = session.flagCarriers[teamBFlag.id],
                           let enemyCarrier = session.players.first(where: { $0.id == enemyCarrierId }),
                           enemyCarrier.team != playerTeam,
                           currentPlayer.id != enemyCarrierId {
                            // Show "Take Possession" button if flag is captured by enemy and you're not the carrier
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.takePossessionOfFlag(flagPlayerId: teamBFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill")
                                        .font(.title3)
                                    Text("Take Possession")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.ctfTeamB, AppColors.ctfTeamBSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: AppColors.ctfTeamB.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                        
                        // Return button (your team's flag captured - you have possession)
                        if teamBFlag.team == playerTeam,
                           let carrierId = session.flagCarriers[teamBFlag.id],
                           carrierId == currentPlayer.id {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.returnPlayerFlag(flagPlayerId: teamBFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                        .font(.title3)
                                    Text("Return Team B Flag")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.ctfTeamB, AppColors.ctfTeamBSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: AppColors.ctfTeamB.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
                
                // Score buttons (when carrying enemy flag at your base)
                if let playerTeam = currentPlayer.team,
                   let playerBase = (playerTeam == .teamA ? session.teamABase : session.teamBBase) {
                    let baseLoc = CLLocation(latitude: playerBase.latitude, longitude: playerBase.longitude)
                    let distanceToBase = playerLoc.distance(from: baseLoc)
                    
                    if distanceToBase.isFinite && distanceToBase >= 0 && distanceToBase <= captureDistance {
                        // Check if carrying enemy flag - find the first matching flag
                        if let (flagPlayerId, carrierId) = session.flagCarriers.first(where: { $0.value == currentPlayer.id }),
                           carrierId == currentPlayer.id,
                           let flagPlayer = session.players.first(where: { $0.id == flagPlayerId }),
                           let flagTeam = flagPlayer.team,
                           flagTeam != playerTeam {
                            // Score button
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.scorePlayerFlag(flagPlayerId: flagPlayerId)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "target")
                                        .font(.title3)
                                    Text("Score \(flagTeam.rawValue) Flag")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.bold)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [AppColors.success, AppColors.success.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .shadow(color: AppColors.success.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Compact Zone Info Card
    
    private func compactZoneInfoCard(bubble: Bubble) -> some View {
        let distance = gameService.distanceToEdge ?? 0
        let isAlive = gameService.currentPlayer?.isAlive == true
        let currentRadius = bubble.startRadius // CTF: Zone doesn't shrink
        
        return HStack(spacing: AppSpacing.sm) {
            // Bubble Radius (no shrink indicator for CTF)
            HStack(spacing: 4) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(bubbleColor)
                Text("\(Int(currentRadius))m")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Divider
            if isAlive {
                Rectangle()
                    .fill(AppColors.textSecondary.opacity(0.3))
                    .frame(width: 1, height: 16)
            }
            
            // Distance to Edge
            if isAlive {
                let distanceFromEdge = abs(distance) // Always show positive distance from edge
                let isOutside = distance > 0
                HStack(spacing: 4) {
                    Image(systemName: isOutside ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                    Text("\(Int(distanceFromEdge))m")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Compact Players Card
    
    private func compactPlayersCard(session: GameSession) -> some View {
        let alivePlayers = session.players.filter { $0.isAlive }
        let teamAPlayers = alivePlayers.filter { $0.role == .teamA }
        let teamBPlayers = alivePlayers.filter { $0.role == .teamB }
        let eliminated = session.players.filter { !$0.isAlive }
        
        return HStack(spacing: AppSpacing.xs) {
            // Total count
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(alivePlayers.count)/\(session.players.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Team breakdown
            if !teamAPlayers.isEmpty && !teamBPlayers.isEmpty {
                HStack(spacing: 6) {
                    // Team A
                    HStack(spacing: 2) {
                        Circle()
                            .fill(AppColors.ctfTeamA)
                            .frame(width: 6, height: 6)
                        Text("\(teamAPlayers.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.ctfTeamA)
                    }
                    
                    // Team B
                    HStack(spacing: 2) {
                        Circle()
                            .fill(AppColors.ctfTeamB)
                            .frame(width: 6, height: 6)
                        Text("\(teamBPlayers.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.ctfTeamB)
                    }
                }
            }
            
            // Eliminated count
            if !eliminated.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(AppColors.error.opacity(0.7))
                    Text("\(eliminated.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppColors.error.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
    
    // MARK: - Bottom Stats Panel
    
    private var bottomStatsPanel: some View {
        VStack(spacing: 12) {
            // Out of Bounds Indicator
            if gameService.isOutOfBounds || gameService.currentPlayer?.isAlive == false {
                outOfBoundsCard
            }
            
            // Warning Banner
            if gameService.warningLevel != .none {
                warningBanner
            }
            
            // End Game Button
            endGameButton
        }
    }
    
    private var warningBanner: some View {
        HStack {
            Image(systemName: warningIcon)
                .foregroundColor(warningColor)
            Text(warningText)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(warningColor)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(warningColor.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(warningColor, lineWidth: 2)
        )
    }
    
    private var outOfBoundsCard: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(gameService.currentPlayer?.isAlive == false ? "ELIMINATED" : "OUT OF BOUNDS")
                .font(AppTypography.labelLarge())
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [AppColors.error, AppColors.error.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var endGameButton: some View {
        Button(action: {
            gameService.endGame()
        }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "stop.circle.fill")
                Text("End Game")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Computed Properties
    
    private var bubbleColor: Color {
        AppColors.bubbleColor(for: gameService.warningLevel)
    }
    
    private var currentBubbleRadius: Double? {
        // CTF: Zone doesn't shrink, so always return start radius
        gameService.session?.bubble?.startRadius
    }
    
    // MARK: - Timer Management
    
    private func startTimer() {
        stopTimer()
        // Update every 1 second - smooth enough for timers but not excessive
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private var warningIcon: String {
        switch gameService.warningLevel {
        case .danger: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.circle.fill"
        case .safe: return "checkmark.circle.fill"
        case .none: return ""
        }
    }
    
    private var warningColor: Color {
        switch gameService.warningLevel {
        case .danger: return .red
        case .warning: return .orange
        case .safe: return .yellow
        case .none: return .clear
        }
    }
    
    private var warningText: String {
        switch gameService.warningLevel {
        case .danger: return "⚠️ DANGER - Near Edge!"
        case .warning: return "⚠️ Warning - Getting Close"
        case .safe: return "✓ Safe Distance"
        case .none: return ""
        }
    }
    
    // MARK: - Toast Notifications
    
    enum ToastType {
        case elimination
        case playerCaught
        
        var color: Color {
            switch self {
            case .elimination: return AppColors.error
            case .playerCaught: return AppColors.success
            }
        }
        
        var icon: String {
            switch self {
            case .elimination: return "xmark.circle.fill"
            case .playerCaught: return "checkmark.circle.fill"
            }
        }
    }
    
    private func toastView(message: String, type: ToastType) -> some View {
        let ctfGradient = LinearGradient(
            colors: [
                AppColors.ctfPrimary,
                AppColors.ctfSecondary
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        let successGradient = LinearGradient(
            colors: [
                AppColors.success,
                AppColors.success.opacity(0.8)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: type.icon)
                .foregroundColor(.white)
                .font(.title3)
            Text(message)
                .font(AppTypography.labelMedium())
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(type == .elimination ? ctfGradient : successGradient)
                .shadow(color: (type == .elimination ? AppColors.ctfPrimary : AppColors.success).opacity(0.5), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - Helpers
    
    private func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    // MARK: - Network Error Banner
    
    private func networkErrorBanner(message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "wifi.slash")
                .font(.title3)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Issue")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text(message)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange, lineWidth: 2)
                )
        )
        .shadow(color: Color.orange.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Flag Phone View
    
    private func flagPhoneView(session: GameSession, player: Player) -> some View {
        let teamColor = player.team == .teamA ? Color.blue : Color.red
        let teamName = player.team == .teamA ? "Team A" : "Team B"
        let isCaptured = session.flagCarriers[player.id] != nil
        let isDisconnected = gameService.flagPhoneDisconnected[player.team ?? .teamA] == true || !gameService.isConnected
        
        return ZStack {
            // Solid color background
            teamColor
                .ignoresSafeArea()
            
            // Disconnect screen overlay
            if isDisconnected {
                flagPhoneDisconnectScreen(teamColor: teamColor, teamName: teamName)
            } else {
            
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                
                // Big "FLAG" title
                Text("FLAG")
                    .font(.system(size: 120, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                
                // Team name
                Text(teamName)
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                
                // Status
                if isCaptured {
                    if let carrierId = session.flagCarriers[player.id],
                       let carrier = session.players.first(where: { $0.id == carrierId }) {
                        Text("Carried by \(carrier.displayName)")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.top, AppSpacing.lg)
                    }
                } else {
                    Text("At Base")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.top, AppSpacing.lg)
                }
                
                Spacer()
                
                // Flag Acquired Animation
                if showFlagAcquired, let acquiredTeam = flagAcquiredTeam {
                    VStack(spacing: AppSpacing.md) {
                        Text("Flag Acquired!")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                            .scaleEffect(flagAcquiredAnimationScale)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true), value: flagAcquiredAnimationScale)
                        
                        Text("Bring to Opposing Side to Capture")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    }
                    .padding(AppSpacing.xl)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(acquiredTeam == .teamA ? Color.blue.opacity(0.3) : Color.red.opacity(0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white, lineWidth: 3)
                            )
                    )
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.xl)
                }
                
                // CTF doesn't use BLE - flag capture happens via GPS proximity buttons on capturing player's device
                // The flag phone just displays status and animations when captured
            }
            }
        }
        .onChange(of: gameService.session?.flagCarriers[player.id]) { oldValue, newValue in
            // Flag capture state changed
            if newValue != nil {
                // Flag was just captured
                if let currentSession = gameService.session {
                    detectCapturingTeam(session: currentSession, flagPlayerId: player.id)
                }
            } else {
                // Flag was returned - reset animation
                showFlagAcquired = false
                flagAcquiredTeam = nil
            }
        }
    }
    
    // CTF doesn't use BLE - flag capture happens via GPS proximity buttons on capturing player's device
    // This function just detects when flag is captured (from session state) and shows animation
    
    private func detectCapturingTeam(session: GameSession, flagPlayerId: String) {
        // When flag is captured, detect which team captured it
        if let carrierId = session.flagCarriers[flagPlayerId],
           let carrier = session.players.first(where: { $0.id == carrierId }) {
            flagAcquiredTeam = carrier.team
            showFlagAcquired = true
            flagAcquiredAnimationScale = 1.2
            
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true)) {
                flagAcquiredAnimationScale = 1.0
            }
            
            HapticFeedbackManager.shared.playerCaught()
        }
    }
    
    // MARK: - Flag Phone Disconnect Screen
    
    private func flagPhoneDisconnectScreen(teamColor: Color, teamName: String) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Disconnect icon
            Image(systemName: "wifi.slash")
                .font(.system(size: 100, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // Title
            Text("Connection Lost")
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
            
            // Message
            VStack(spacing: AppSpacing.md) {
                Text("Manual Mode")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                
                Text("Game continues manually")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                Text("Reconnecting...")
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, AppSpacing.sm)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(teamColor.opacity(0.9))
    }
    
    // MARK: - Flag Disconnect Notifications (for non-flag devices)
    
    private func flagDisconnectNotifications(session: GameSession) -> some View {
        VStack {
            if showTeamADisconnect {
                flagDisconnectBanner(team: .teamA, teamName: "Team A")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if showTeamBDisconnect {
                flagDisconnectBanner(team: .teamB, teamName: "Team B")
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .padding(.top, AppSpacing.md)
        .animation(.spring(response: 0.3), value: showTeamADisconnect)
        .animation(.spring(response: 0.3), value: showTeamBDisconnect)
    }
    
    private func handleDisconnectNotificationChange(team: Flag.Team, isDisconnected: Bool) {
        if team == .teamA {
            if isDisconnected {
                // Show notification
                showTeamADisconnect = true
                // Auto-dismiss after 5 seconds
                teamADisconnectDismissTimer?.invalidate()
                teamADisconnectDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                    withAnimation {
                        showTeamADisconnect = false
                    }
                }
            } else {
                // Hide immediately if reconnected
                teamADisconnectDismissTimer?.invalidate()
                showTeamADisconnect = false
            }
        } else if team == .teamB {
            if isDisconnected {
                // Show notification
                showTeamBDisconnect = true
                // Auto-dismiss after 5 seconds
                teamBDisconnectDismissTimer?.invalidate()
                teamBDisconnectDismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                    withAnimation {
                        showTeamBDisconnect = false
                    }
                }
            } else {
                // Hide immediately if reconnected
                teamBDisconnectDismissTimer?.invalidate()
                showTeamBDisconnect = false
            }
        }
    }
    
    private func flagDisconnectBanner(team: Flag.Team, teamName: String) -> some View {
        let teamColor = team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB
        
        return HStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(teamName) Flag Disconnected")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Manual mode - game continues")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(teamColor)
                .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
        )
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Button Style
    
    struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

