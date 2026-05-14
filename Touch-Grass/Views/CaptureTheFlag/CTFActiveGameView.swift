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
    
    // Flag capture confirmation dialogs
    @State private var pendingFlagCapture: String? = nil // Flag player ID pending capture confirmation
    @State private var showCaptureConfirmation: Bool = false
    @State private var captureConfirmationTeam: Flag.Team? = nil
    
    // Undo window for flag capture (5 second window)
    @State private var lastFlagCapture: (flagPlayerId: String, timestamp: Date)? = nil
    @State private var captureUndoTimer: Timer? = nil
    
    var body: some View {
        Group {
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
            // VISIBILITY RULES: Filter players based on team and elimination status
            let visiblePlayers = getVisiblePlayers(for: gameService.session, currentPlayer: gameService.currentPlayer)
            let visibleSafeZones = getVisibleSafeZones(for: gameService.session, currentPlayer: gameService.currentPlayer)
            
            MapViewRepresentable(
                userCoordinate: locationService.coordinate,
                bubbleCenter: bubbleCenter,
                bubbleRadius: bubbleRadius,
                warningLevel: gameService.warningLevel,
                players: visiblePlayers,
                currentPlayerId: gameService.currentPlayer?.id,
                currentPlayerRole: gameService.currentPlayer?.role,
                gameType: gameService.session?.gameType,
                flags: gameService.session?.flags ?? [],
                teamABase: gameService.session?.teamABase,
                teamBBase: gameService.session?.teamBBase,
                teamASafeZone: visibleSafeZones.teamA,
                teamBSafeZone: visibleSafeZones.teamB,
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
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ActiveGameStatusStrip(safeAreaTop: geometry.safeAreaInsets.top)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            topHUD
                                .frame(maxWidth: max(0, geometry.size.width - ActiveGameMapHubMetrics.idleHubWidth - AppSpacing.md * 2 - AppSpacing.sm),
                                       alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 8)

                            ActiveGameMapHubView(
                                mapType: $mapType,
                                showPlayerLabels: $showPlayerLabels,
                                onZoomToBubble: { zoomToBubbleTrigger = true },
                                onCenterOnPlayer: { centerOnPlayerTrigger = true },
                                bubbleExists: gameService.session?.bubble != nil,
                                playerLocationExists: locationService.coordinate != nil,
                                gameType: gameService.session?.gameType,
                                onEndGame: { gameService.endGame() },
                                announcementManager: gameService.announcementManager
                            )
                        }
                        .padding(.leading, AppSpacing.md)
                        .padding(.trailing, AppSpacing.sm)
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
                .activeGameStatusBarHidden()
                // Note: allowsHitTesting removed - buttons need to be interactive!
            }
            
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
                if viewModel != nil, !ScreenshotScenario.isActive {
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        showDebugTestPanel = true
                    }) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(IconButtonStyle(size: 34, color: AppColors.grassPrimary))
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
        .alert("Confirm Flag Capture", isPresented: $showCaptureConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingFlagCapture = nil
                captureConfirmationTeam = nil
            }
            Button("Capture") {
                if let flagPlayerId = pendingFlagCapture {
                    gameService.capturePlayerFlag(flagPlayerId: flagPlayerId)
                    // Store for undo window
                    lastFlagCapture = (flagPlayerId: flagPlayerId, timestamp: Date())
                    // Start undo timer (5 second window)
                    captureUndoTimer?.invalidate()
                    captureUndoTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
                        lastFlagCapture = nil
                    }
                }
                pendingFlagCapture = nil
                captureConfirmationTeam = nil
            }
        } message: {
            if let team = captureConfirmationTeam {
                Text("Are you sure you want to capture the \(team.rawValue) flag? This action cannot be undone.")
            } else {
                Text("Are you sure you want to capture this flag? This action cannot be undone.")
            }
        }
        .alert("Undo Flag Capture?", isPresented: Binding(
            get: { lastFlagCapture != nil && Date().timeIntervalSince(lastFlagCapture!.timestamp) < 5.0 },
            set: { if !$0 { 
                lastFlagCapture = nil
                captureUndoTimer?.invalidate()
            } }
        )) {
            Button("Keep Captured") {
                lastFlagCapture = nil
                captureUndoTimer?.invalidate()
            }
            Button("Undo", role: .destructive) {
                if let capture = lastFlagCapture {
                    // Return the flag
                    gameService.returnPlayerFlag(flagPlayerId: capture.flagPlayerId)
                    lastFlagCapture = nil
                    captureUndoTimer?.invalidate()
                }
            }
        } message: {
            Text("You just captured a flag. Tap 'Undo' within 5 seconds to return it.")
        }
    }
    
    // MARK: - Top HUD
    
    private var topHUD: some View {
        HStack(spacing: 6) {
            // Zone chip
            if let bubble = gameService.session?.bubble {
                CartoonHudChip(label: "Zone", value: "\(Int(currentBubbleRadius ?? 0))m", accent: AppColors.ctfPrimary)
                    .fixedSize(horizontal: true, vertical: false)
            }

            // Alive chip
            if let session = gameService.session {
                let aliveCount = session.players.filter { $0.isAlive }.count
                CartoonHudChip(label: "Alive", value: "\(aliveCount)/\(session.players.count)", accent: AppColors.grassPrimary)
                    .fixedSize(horizontal: true, vertical: false)
            }

            // Team badge
            if let currentPlayer = gameService.currentPlayer, currentPlayer.isAlive {
                let teamText = currentPlayer.role == .teamA ? "TEAM A" : "TEAM B"
                let teamColor = currentPlayer.role == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB
                CartoonPill(text: teamText, color: teamColor)
            } else {
                CartoonPill(text: "ELIMINATED", color: AppColors.error)
            }
        }
        .onAppear {
            if gameService.gameState == .active { startTimer() }
        }
        .onDisappear { stopTimer() }
        .onChange(of: gameService.gameState) { oldValue, newValue in
            if newValue == .active && timer == nil {
                startTimer()
            } else if newValue != .active {
                stopTimer()
            }
        }
    }
    
    private var timerDisplay: some View {
        // CTF has no time limit - return empty view
        EmptyView()
    }
    
    // MARK: - CTF Score Display
    
    private func ctfScoreDisplay(session: GameSession) -> some View {
        HStack(spacing: 6) {
            CartoonHudChip(label: "Team A", value: "\(session.teamAScore)", accent: AppColors.ctfTeamA)
            CartoonHudChip(label: "Team B", value: "\(session.teamBScore)", accent: AppColors.ctfTeamB)
        }
    }
    
    // MARK: - CTF Flag Status Panel
    
    private func ctfFlagStatusPanel(session: GameSession) -> some View {
        HStack(spacing: 6) {
            CartoonFlagStatusChip(
                team: "A",
                statusText: flagStatusText(team: .teamA, session: session),
                teamColor: AppColors.ctfTeamA
            )
            CartoonFlagStatusChip(
                team: "B",
                statusText: flagStatusText(team: .teamB, session: session),
                teamColor: AppColors.ctfTeamB
            )
        }
    }

    private func flagStatusText(team: Flag.Team, session: GameSession) -> String {
        let flagPlayer = session.players.first { $0.team == team && $0.isFlag }
        guard let fp = flagPlayer else { return "No Flag" }
        if let carrierId = session.flagCarriers[fp.id],
           let carrier = session.players.first(where: { $0.id == carrierId }) {
            if carrierId == gameService.currentPlayer?.id { return "Carried by You" }
            return "Carried by \(carrier.displayName)"
        }
        return "At Base"
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
                                pendingFlagCapture = teamAFlag.id
                                captureConfirmationTeam = .teamA
                                showCaptureConfirmation = true
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill").font(.title3)
                                    Text("Capture Team A Flag")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: AppColors.ctfTeamA))
                        }

                        // Take Possession button
                        if teamAFlag.team == playerTeam,
                           let enemyCarrierId = session.flagCarriers[teamAFlag.id],
                           let enemyCarrier = session.players.first(where: { $0.id == enemyCarrierId }),
                           enemyCarrier.team != playerTeam,
                           currentPlayer.id != enemyCarrierId {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.takePossessionOfFlag(flagPlayerId: teamAFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill").font(.title3)
                                    Text("Take Possession")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: AppColors.ctfTeamA))
                        }

                        // Return button
                        if teamAFlag.team == playerTeam,
                           let carrierId = session.flagCarriers[teamAFlag.id],
                           carrierId == currentPlayer.id {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.returnPlayerFlag(flagPlayerId: teamAFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.title3)
                                    Text("Return Team A Flag")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: AppColors.ctfTeamA))
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
                                pendingFlagCapture = teamBFlag.id
                                captureConfirmationTeam = .teamB
                                showCaptureConfirmation = true
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill").font(.title3)
                                    Text("Capture Team B Flag")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: AppColors.ctfTeamB))
                        }

                        // Take Possession button
                        if teamBFlag.team == playerTeam,
                           let enemyCarrierId = session.flagCarriers[teamBFlag.id],
                           let enemyCarrier = session.players.first(where: { $0.id == enemyCarrierId }),
                           enemyCarrier.team != playerTeam,
                           currentPlayer.id != enemyCarrierId {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.takePossessionOfFlag(flagPlayerId: teamBFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "hand.raised.fill").font(.title3)
                                    Text("Take Possession")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: AppColors.ctfTeamB))
                        }

                        // Return button
                        if teamBFlag.team == playerTeam,
                           let carrierId = session.flagCarriers[teamBFlag.id],
                           carrierId == currentPlayer.id {
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                gameService.returnPlayerFlag(flagPlayerId: teamBFlag.id)
                            }) {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "arrow.uturn.backward.circle.fill").font(.title3)
                                    Text("Return Team B Flag")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: AppColors.ctfTeamB))
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
                                    Image(systemName: "target").font(.title3)
                                    Text("Score \(flagTeam.rawValue) Flag!")
                                }
                            }
                            .buttonStyle(CartoonButtonStyle(accent: AppColors.grassPrimary))
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
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .foregroundColor(bubbleColor)
                Text("\(Int(currentRadius))m")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
            }
            
            // Divider
            if isAlive {
                Rectangle()
                    .fill(AppColors.cartoonInk.opacity(0.22))
                    .frame(width: 2, height: 16)
            }
            
            // Distance to Edge
            if isAlive {
                let distanceFromEdge = abs(distance) // Always show positive distance from edge
                let isOutside = distance > 0
                HStack(spacing: 4) {
                    Image(systemName: isOutside ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                    Text("\(Int(distanceFromEdge))m")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cartoonCream)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2))
        .background(
            Capsule()
                .fill(Color(white: 0.18))
                .offset(x: 3, y: 3)
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
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                Text("\(alivePlayers.count)/\(session.players.count)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
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
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.ctfTeamA)
                    }
                    
                    // Team B
                    HStack(spacing: 2) {
                        Circle()
                            .fill(AppColors.ctfTeamB)
                            .frame(width: 6, height: 6)
                        Text("\(teamBPlayers.count)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.ctfTeamB)
                    }
                }
            }
            
            // Eliminated count
            if !eliminated.isEmpty {
                HStack(spacing: 2) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.error)
                    Text("\(eliminated.count)")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.error)
                }
            }
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColors.cartoonCream)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2))
        .background(
            Capsule()
                .fill(Color(white: 0.18))
                .offset(x: 3, y: 3)
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
        }
    }
    
    private var warningBanner: some View {
        HStack {
            Image(systemName: warningIcon)
                .foregroundColor(warningColor)
            Text(warningText)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
    }
    
    private var outOfBoundsCard: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(gameService.currentPlayer?.isAlive == false ? "ELIMINATED" : "OUT OF BOUNDS")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .tracking(0.5)
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.error)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.18))
                .offset(x: 4, y: 4)
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
        }
        .buttonStyle(CartoonButtonStyle(accent: AppColors.error))
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
        case .danger: return "DANGER - Near Edge!"
        case .warning: return "Warning - Getting Close"
        case .safe: return "Safe Distance"
        case .none: return ""
        }
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
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(AppColors.warning)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Connection Issue")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                Text(message)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.68))
            }
            
            Spacer()
        }
        .padding()
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
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
                    .shadow(color: AppColors.cartoonInk, radius: 0, x: 6, y: 6)
                
                // Team name
                Text(teamName)
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppColors.cartoonInk, radius: 0, x: 4, y: 4)
                
                // Status
                if isCaptured {
                    if let carrierId = session.flagCarriers[player.id],
                       let carrier = session.players.first(where: { $0.id == carrierId }) {
                        Text("Carried by \(carrier.displayName)")
                            .font(.system(size: 27, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                            .padding(.top, AppSpacing.lg)
                            .padding(AppSpacing.lg)
                            .cartoonCard(cornerRadius: 18)
                    }
                } else {
                    Text("At Base")
                        .font(.system(size: 27, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                        .padding(.top, AppSpacing.lg)
                        .padding(AppSpacing.lg)
                        .cartoonCard(cornerRadius: 18)
                }
                
                Spacer()
                
                // Flag Acquired Animation
                if showFlagAcquired, flagAcquiredTeam != nil {
                    VStack(spacing: AppSpacing.md) {
                        Text("Flag Acquired!")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                            .scaleEffect(flagAcquiredAnimationScale)
                            .animation(.spring(response: 0.5, dampingFraction: 0.6).repeatForever(autoreverses: true), value: flagAcquiredAnimationScale)
                        
                        Text("Bring to Opposing Side to Capture")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.xl)
                    }
                    .padding(AppSpacing.xl)
                    .cartoonCard(cornerRadius: 20)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.xl)
                }
                
                // Manual override buttons for edge cases (BLE failure, GPS issues, etc.)
                flagPhoneManualButtons(session: session, player: player)
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
    
    // MARK: - Flag Phone Manual Buttons (Edge Case Handling)
    
    /// Manual override buttons for flag phone to handle BLE failures and edge cases
    private func flagPhoneManualButtons(session: GameSession, player: Player) -> some View {
        let isCaptured = session.flagCarriers[player.id] != nil
        let flagTeam = player.team ?? .teamA
        let teamColor = flagTeam == .teamA ? Color.blue : Color.red
        
        return VStack(spacing: AppSpacing.md) {
            // Manual override section
            VStack(spacing: AppSpacing.sm) {
                Text("Manual Override")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                
                Text("Use if BLE/GPS fails")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.68))
            }
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xs)
            
            if !isCaptured {
                // Flag is at base - show "Flag Captured" button
                Button(action: {
                    HapticFeedbackManager.shared.selection()
                    // Manually mark flag as captured
                    // Find an enemy player to use as carrier (or use first enemy player)
                    if let enemyPlayer = session.players.first(where: { $0.team != flagTeam && $0.isAlive }) {
                        // Use enemy player as carrier
                        if var session = gameService.session,
                           let _ = session.players.firstIndex(where: { $0.id == player.id }) {
                            session.flagCarriers[player.id] = enemyPlayer.id
                            gameService.session = session
                            
                            // Sync to Firestore
                            Task {
                                do {
                                    try await gameService.firestore.updateSession(session)
                                    print("✅ Manual override: Flag marked as captured by \(enemyPlayer.displayName)")
                                } catch {
                                    print("❌ Error syncing manual flag capture: \(error)")
                                }
                            }
                        }
                    } else {
                        print("⚠️ Cannot manually capture: No enemy players found")
                    }
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "hand.raised.fill")
                            .font(.title3)
                        Text("Flag Captured")
                    }
                }
                .buttonStyle(CartoonButtonStyle(accent: AppColors.error))
            } else {
                // Flag is captured - show "Flag Returned" and "Flag Scored" buttons
                VStack(spacing: AppSpacing.sm) {
                    // Flag Returned button
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        // Manually return flag to base
                        gameService.returnPlayerFlag(flagPlayerId: player.id)
                    }) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.title3)
                            Text("Flag Returned")
                        }
                    }
                    .buttonStyle(CartoonButtonStyle(accent: teamColor))
                    
                    // Flag Scored button (if at enemy safe zone)
                    if let currentLocation = locationService.coordinate {
                        // Check if flag is in enemy safe zone
                        let enemySafeZone = flagTeam == .teamA ? session.teamBSafeZone : session.teamASafeZone
                        if let safeZone = enemySafeZone {
                            let safeZoneLocation = CLLocation(latitude: safeZone.center.latitude, longitude: safeZone.center.longitude)
                            let flagLocation = CLLocation(latitude: currentLocation.latitude, longitude: currentLocation.longitude)
                            let distance = flagLocation.distance(from: safeZoneLocation)
                            
                            // Show "Flag Scored" if within safe zone radius
                            if distance <= safeZone.radius {
                                Button(action: {
                                    HapticFeedbackManager.shared.selection()
                                    // Manually score flag
                                    if let carrierId = session.flagCarriers[player.id],
                                       let _ = session.players.first(where: { $0.id == carrierId }) {
                                        // Score the flag using the carrier's context
                                        gameService.scorePlayerFlag(flagPlayerId: player.id)
                                    }
                                }) {
                                    HStack(spacing: AppSpacing.sm) {
                                        Image(systemName: "flag.checkered")
                                            .font(.title3)
                                        Text("Flag Scored")
                                    }
                                }
                                .buttonStyle(CartoonButtonStyle(accent: AppColors.grassPrimary))
                            }
                        }
                    }
                }
            }
            
            // Check Win Condition button (always available)
            Button(action: {
                HapticFeedbackManager.shared.selection()
                // Manually trigger win condition check
                gameService.checkGameOver()
            }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "trophy.fill")
                        .font(.title3)
                    Text("Check Win Condition")
                }
            }
            .buttonStyle(CartoonButtonStyle(accent: AppColors.cartoonSun, textColor: AppColors.cartoonInkOnSunFill, borderColor: AppColors.cartoonInkOnSunFill))
        }
        .padding(AppSpacing.lg)
        .cartoonCard(cornerRadius: 20)
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.xl)
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
            CartoonMedallion(background: AppColors.error, size: 98, borderWidth: 3) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            // Title
            Text("Connection Lost")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: AppColors.cartoonInk, radius: 0, x: 4, y: 4)
            
            // Message
            VStack(spacing: AppSpacing.md) {
                Text("Manual Mode")
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                
                Text("Game continues manually")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                Text("Reconnecting...")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.6))
                    .padding(.top, AppSpacing.sm)
            }
            .padding(AppSpacing.xl)
            .cartoonCard(cornerRadius: 20)
            
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
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(teamName) Flag Disconnected")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Manual mode - game continues")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(teamColor)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.18))
                .offset(x: 4, y: 4)
        )
        .padding(.horizontal, AppSpacing.md)
    }
    
    // MARK: - Visibility Helpers
    
    /// Get players visible to current player based on team and elimination status
    /// RULES:
    /// - Eliminated players see NO enemy info (spectator mode)
    /// - Alive players see teammates and flag players (enemy safe zones hidden)
    /// - Prevents safe zone discovery through movement vectors
    private func getVisiblePlayers(for session: GameSession?, currentPlayer: Player?) -> [Player] {
        guard let session = session, let currentPlayer = currentPlayer else {
            return []
        }
        
        // Eliminated players (spectators) - hide all enemy info
        if !currentPlayer.isAlive {
            // Spectators see only their own team and flag players (no enemy locations)
            return session.players.filter { player in
                // Always show own player
                if player.id == currentPlayer.id {
                    return true
                }
                // Show teammates
                if player.team == currentPlayer.team {
                    return true
                }
                // Show flag players (they're marked on map anyway)
                if player.isFlag {
                    return true
                }
                // Hide all other enemy players
                return false
            }
        }
        
        // Alive players - see teammates and flag players, but not regular enemy players
        return session.players.filter { player in
            // Always show own player
            if player.id == currentPlayer.id {
                return true
            }
            // Show teammates
            if player.team == currentPlayer.team {
                return true
            }
            // Show flag players (they're the objectives)
            if player.isFlag {
                return true
            }
            // Hide regular enemy players to prevent safe zone discovery
            return false
        }
    }
    
    /// Get safe zones visible to current player
    /// RULES:
    /// - Players see their own team's safe zone
    /// - Players see enemy safe zones only when both flags are in that zone (win condition visible)
    /// - Eliminated players see no safe zones
    private func getVisibleSafeZones(for session: GameSession?, currentPlayer: Player?) -> (teamA: GameSession.SafeZone?, teamB: GameSession.SafeZone?) {
        guard let session = session, let currentPlayer = currentPlayer else {
            return (nil, nil)
        }
        
        // Eliminated players see no safe zones
        if !currentPlayer.isAlive {
            return (nil, nil)
        }
        
        let playerTeam = currentPlayer.team
        
        // Players always see their own team's safe zone
        let ownSafeZone = playerTeam == .teamA ? session.teamASafeZone : session.teamBSafeZone
        
        // Check if enemy safe zone should be visible (both flags in enemy safe zone = win condition)
        let enemySafeZone: GameSession.SafeZone?
        if let teamAFlag = session.players.first(where: { $0.team == .teamA && $0.isFlag }),
           let teamBFlag = session.players.first(where: { $0.team == .teamB && $0.isFlag }) {
            let enemySafeZoneToCheck = playerTeam == .teamA ? session.teamBSafeZone : session.teamASafeZone
            
            if let enemyZone = enemySafeZoneToCheck {
                let flagALocation = teamAFlag.location
                let flagBLocation = teamBFlag.location
                let safeZoneLocation = CLLocation(latitude: enemyZone.center.latitude, longitude: enemyZone.center.longitude)
                
                let distanceA = flagALocation.distance(from: safeZoneLocation)
                let distanceB = flagBLocation.distance(from: safeZoneLocation)
                
                // Only show enemy safe zone if both flags are in it (win condition visible)
                if distanceA <= enemyZone.radius && distanceB <= enemyZone.radius {
                    enemySafeZone = enemyZone
                } else {
                    enemySafeZone = nil // Hide enemy safe zone to prevent discovery
                }
            } else {
                enemySafeZone = nil
            }
        } else {
            enemySafeZone = nil
        }
        
        return (
            teamA: playerTeam == .teamA ? ownSafeZone : enemySafeZone,
            teamB: playerTeam == .teamB ? ownSafeZone : enemySafeZone
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
}
