//
//  ZombieTagActiveGameView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import MapKit

struct ZombieTagActiveGameView: View {
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
    @StateObject private var obfuscationService = LocationObfuscationService()
    
    // (Zone-phase announcements now use gameService.announcementManager)
    
    // Fortnite-style zone notification state
    @State private var showZoneNotification: Bool = false
    @State private var zoneNotificationTitle: String = ""
    @State private var zoneNotificationCountdown: TimeInterval = 0
    @State private var zoneNotificationIcon: String = ""
    @State private var zoneNotificationColor: Color = .orange
    @State private var zoneNotificationTimer: Timer?
    
    var body: some View {
        let bubbleCenter = gameService.session?.bubble?.center
        let bubbleRadius = currentBubbleRadius
        
        return ZStack {
            // Proximity warning overlay (screen flash when zombie very close)
            if gameService.proximityWarningLevel == .danger && gameService.shouldFlashScreen {
                Color.red.opacity(0.3)
                    .ignoresSafeArea()
                    .animation(.easeOut(duration: 0.1), value: gameService.shouldFlashScreen)
            }
            
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
                teamASafeZone: nil,
                teamBSafeZone: nil,
                isPingActive: obfuscationService.isPingActive,
                bubbleEpoch: obfuscationService.bubbleEpoch,
                zoneRadius: bubbleRadius,
                obfuscationService: obfuscationService,
                mapType: $mapType,
                showPlayerLabels: $showPlayerLabels,
                zoomToBubbleTrigger: $zoomToBubbleTrigger,
                centerOnPlayerTrigger: $centerOnPlayerTrigger,
                bubble: gameService.session?.bubble // Pass bubble for new zone system (must be last)
            )
            .ignoresSafeArea()
            .onAppear { refreshObfuscationSnapshots() }
            .onChange(of: obfuscationService.bubbleEpoch) { _, _ in refreshObfuscationSnapshots() }
            .onChange(of: gameService.currentPlayer?.id) { _, _ in refreshObfuscationSnapshots() }
            .onChange(of: gameService.currentPlayer?.role) { _, _ in refreshObfuscationSnapshots() }
            .onChange(of: rosterObfuscationSignature) { _, _ in refreshObfuscationSnapshots() }
            
            // Game HUD Overlay - Using absolute positioning for fixed elements
            GeometryReader { geometry in
                let topSecondRow = ActiveGameTopChromeMetrics.stripHeight(for: geometry.safeAreaInsets.top) + AppSpacing.sm
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

                // Compass region (middle-right). Zombies get the new
                // pulse ability whenever alive in an active game; humans
                // keep the zone-gated passive nearest-zombie compass.
                if shouldShowCompassOverlay {
                    HStack {
                        Spacer()
                        compassOverlayContent
                            .padding(.trailing, AppSpacing.md + ActiveGameMapHubMetrics.idleHubWidth)
                            .padding(.top, topSecondRow)
                    }
                }
                
                // Bottom Section - Only functional buttons (tag, end game)
                VStack {
                    Spacer()
                    
                    bottomFunctionalButtons
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.md)
                }
                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .activeGameStatusBarHidden()
        // Note: allowsHitTesting removed - buttons need to be interactive!
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
    
    // MARK: - Obfuscation snapshots
    
    private func refreshObfuscationSnapshots() {
        guard let session = gameService.session,
              let viewer = gameService.currentPlayer else { return }
        obfuscationService.refreshSnapshots(
            players: session.players,
            viewerId: viewer.id,
            viewerRole: viewer.role,
            gameType: session.gameType
        )
    }
    
    /// Stable signature over the roster that flips when a player's id,
    /// role, alive state, or flag flag changes. Catches in-place mutations
    /// (e.g. a human being converted to zombie) that don't reorder the id
    /// list and therefore wouldn't trip an id-only `.onChange`.
    private var rosterObfuscationSignature: [String] {
        gameService.session?.players.map { "\($0.id)|\($0.role.rawValue)|\($0.isAlive ? 1 : 0)|\($0.isFlag ? 1 : 0)" }
            ?? []
    }
    
    // MARK: - Top HUD
    
    private var topHUD: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: Zone timer and Role badge
            HStack(spacing: AppSpacing.sm) {
                // Combined Zone Notification & Timer Display
                combinedZoneTimerCard
                    .layoutPriority(1)
                
                // Role Badge (ZombieTag: ZOMBIE or HUMAN)
                if let currentPlayer = gameService.currentPlayer, currentPlayer.isAlive {
                    let roleText = currentPlayer.role == .zombie ? "ZOMBIE" : "HUMAN"
                    let roleColor = currentPlayer.role == .zombie ? AppColors.zombiePrimary : AppColors.humanPrimary
                    
                    CartoonPill(text: roleText, color: roleColor)
                        .layoutPriority(2)
                } else {
                    // Fallback for eliminated players
                    CartoonPill(text: "ELIMINATED", color: AppColors.error)
                        .layoutPriority(2)
                }
            }
            
            // Second row: Zone, safe-area, and player status in one compact line
            HStack(spacing: AppSpacing.sm) {
                // Zone Info (compact version)
                if let bubble = gameService.session?.bubble {
                    compactZoneInfoRow(bubble: bubble)
                }
                
                if let bubble = gameService.session?.bubble, bubble.usesNewZoneSystem {
                    if let distanceToSafe = distanceToSafeArea {
                        let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: currentTime)
                        compactSafeAreaRow(distance: distanceToSafe, isClosing: runtimeState.phaseState == .closing)
                    }
                } else if gameService.isOutOfBounds || gameService.currentPlayer?.isAlive == false {
                    compactOutOfBoundsRow()
                }
                
                // Player Count (compact version)
                if let session = gameService.session {
                    compactPlayersRow(session: session)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 6)
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
        .onChange(of: currentBubbleRadius) { oldValue, newValue in
            // Trigger pulse animation when zone shrinks
            if let old = oldValue, let new = newValue, new < old {
                zoneShrinkPulse = true
                HapticFeedbackManager.shared.selection()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    zoneShrinkPulse = false
                }
            }
        }
        .onAppear {
            // Only start timer if game is active
            if gameService.gameState == .active {
                startTimer()
            }
            startZoneNotificationTimer()
        }
        .onDisappear {
            stopTimer()
            stopZoneNotificationTimer()
        }
        .onChange(of: gameService.gameState) { oldValue, newValue in
            // Start timer when game becomes active, stop when it's not
            if newValue == .active && timer == nil {
                startTimer()
            } else if newValue != .active {
                stopTimer()
            }
        }
        .onChange(of: gameService.session?.bubble?.warningStartTime) { oldValue, newValue in
            if newValue != nil && oldValue == nil {
                gameService.announcementManager.post("Zone closes soon.", type: .warning)
                HapticFeedbackManager.shared.warning()
            }
        }
        .onChange(of: gameService.session?.bubble?.isClosing) { oldValue, newValue in
            if newValue == true && oldValue == false {
                gameService.announcementManager.post("Zone closing.", type: .warning)
                HapticFeedbackManager.shared.zoneShrink()
            }
        }
        .onChange(of: gameService.session?.bubble?.usesNewZoneSystem) { oldValue, newValue in
            if newValue == true {
                startZoneNotificationTimer()
            } else {
                stopZoneNotificationTimer()
            }
        }
    }
    
    private var timerDisplay: some View {
        Group {
            // Only show timer when game is active and showTimer is enabled
            if gameService.gameState == .active,
               let bubble = gameService.session?.bubble,
               bubble.showTimer {
                let elapsed = currentTime.timeIntervalSince(bubble.startTime)
                let remaining = max(0, bubble.duration - elapsed)
                let progress = bubble.duration > 0 ? elapsed / bubble.duration : 0
                
                // Start timer when this view appears and game is active
                let _ = {
                    if timer == nil && gameService.gameState == .active {
                        startTimer()
                    }
                }()
                
                // Milestone markers (75%, 50%, 25%, 10%)
                let milestones: [Double] = [0.75, 0.5, 0.25, 0.1]
                let _ = milestones.last { progress >= $0 } ?? 0
                
                // Circular progress indicator
                ZStack {
                    // Background circle
                    Circle()
                        .stroke(AppColors.textSecondary.opacity(0.2), lineWidth: 4)
                        .frame(width: 50, height: 50)
                    
                    // Progress circle
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            remaining < 60 ?
                            LinearGradient(
                                colors: [
                                    AppColors.zombiePrimary,
                                    AppColors.zombieSecondary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    AppColors.textPrimary.opacity(0.6),
                                    AppColors.textPrimary.opacity(0.4)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 50, height: 50)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    
                    // Milestone indicator dots
                    ForEach(milestones, id: \.self) { milestone in
                        if progress >= milestone {
                            Circle()
                                .fill(remaining < 60 ? AppColors.zombiePrimary : AppColors.textPrimary)
                                .frame(width: 6, height: 6)
                                .offset(
                                    x: cos((milestone * 360 - 90) * .pi / 180) * 25,
                                    y: sin((milestone * 360 - 90) * .pi / 180) * 25
                                )
                        }
                    }
                    
                    // Time text
                    VStack(spacing: 0) {
                        if remaining > 0 {
                            Text(timeString(from: remaining))
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(
                                    remaining < 60 ?
                                    LinearGradient(
                                        colors: [
                                            AppColors.zombiePrimary,
                                            AppColors.zombieSecondary
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ) :
                                    LinearGradient(
                                        colors: [Color.primary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .scaleEffect(timerPulseScale)
                        } else {
                            Text("UP")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.zombiePrimary)
                        }
                    }
                }
                .frame(width: 50, height: 50)
                .onChange(of: remaining) { oldValue, newValue in
                    let remainingInt = Int(newValue)
                    // Haptic feedback at thresholds
                    if remainingInt != lastHapticThreshold {
                        if remainingInt == 60 || remainingInt == 30 || remainingInt == 10 {
                            HapticFeedbackManager.shared.selection()
                        }
                        lastHapticThreshold = remainingInt
                    }
                    
                    if newValue < 60 && newValue > 0 {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            timerPulseScale = 1.1
                        }
                    } else {
                        withAnimation {
                            timerPulseScale = 1.0
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Compact Zone Info Card
    
    @State private var zoneShrinkPulse: Bool = false
    
    private func compactZoneInfoCard(bubble: Bubble) -> some View {
        let distance = gameService.distanceToEdge ?? 0
        let isAlive = gameService.currentPlayer?.isAlive == true
        let currentRadius = currentBubbleRadius ?? 0
        let shrinkProgress = 1.0 - (currentRadius / bubble.startRadius)
        
        return HStack(spacing: AppSpacing.sm) {
            // Bubble Radius with shrink indicator
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8, weight: .black, design: .rounded))
                        .foregroundColor(bubbleColor)
                        .symbolEffect(.pulse, isActive: zoneShrinkPulse)
                    Text("\(Int(currentRadius))m")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                }
                
                // Shrink progress bar (ZombieTag colors)
                GeometryReader { geometry in
                    let progressColors = [AppColors.zombiePrimary, AppColors.zombieSecondary]
                    
                    return ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(AppColors.textSecondary.opacity(0.2))
                            .frame(height: 2)
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: progressColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * shrinkProgress, height: 2)
                    }
                }
                .frame(height: 2)
            }
            
            // Divider
            if isAlive {
                Rectangle()
                    .fill(AppColors.cartoonInk.opacity(0.22))
                    .frame(width: 2, height: 16)
            }
            
            // Distance to Edge (only if alive)
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
        .onChange(of: currentBubbleRadius) { oldValue, newValue in
            // Trigger pulse animation when zone shrinks
            if let old = oldValue, let new = newValue, new < old {
                zoneShrinkPulse = true
                HapticFeedbackManager.shared.selection()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    zoneShrinkPulse = false
                }
            }
        }
    }
    
    // MARK: - Compact Players Card
    
    private func compactPlayersCard(session: GameSession) -> some View {
        let alivePlayers = session.players.filter { $0.isAlive }
        let zombies = alivePlayers.filter { $0.role == .zombie }
        let humans = alivePlayers.filter { $0.role == .human }
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
            
            // Role breakdown: Show zombies and humans
            if !zombies.isEmpty && !humans.isEmpty {
                HStack(spacing: 6) {
                    // Zombies
                    HStack(spacing: 2) {
                        Circle()
                            .fill(AppColors.zombiePrimary)
                            .frame(width: 6, height: 6)
                        Text("\(zombies.count)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.zombiePrimary)
                    }
                    
                    // Humans
                    HStack(spacing: 2) {
                        Circle()
                            .fill(AppColors.humanPrimary)
                            .frame(width: 6, height: 6)
                        Text("\(humans.count)")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.humanPrimary)
                    }
                }
            }
            
            // Eliminated count (if any)
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
            // Infect Button (for zombies when BLE connection established with a human)
            if let currentPlayer = gameService.currentPlayer,
               currentPlayer.role == .zombie,
               currentPlayer.isAlive,
               let taggablePlayerId = gameService.canTagPlayerId,
               let taggablePlayer = gameService.session?.players.first(where: { $0.id == taggablePlayerId }),
               taggablePlayer.role == .human,
               taggablePlayer.isAlive {
                infectButton(player: taggablePlayer)
            }
            
            // Infection Request Alert (for humans)
            if let tagRequest = gameService.pendingTagRequest {
                infectionRequestAlert(request: tagRequest)
            }
            
            // Out of Bounds Indicator
            if gameService.isOutOfBounds || gameService.currentPlayer?.isAlive == false {
                outOfBoundsCard
            }
            
            // Phase 5: New Zone System Feedback (only for new zone system)
            if let bubble = gameService.session?.bubble, bubble.usesNewZoneSystem {
                // Combined Zone Status and Safe Area Indicator
                combinedZoneIndicator(bubble: bubble)
            }
        }
    }
    
    // MARK: - Infect Button
    
    private func infectButton(player: Player) -> some View {
        let buttonText = "Infect \(player.displayName)"
        return Button(action: {
            gameService.requestTag(playerId: player.id)
        }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                Text(buttonText)
            }
        }
        .buttonStyle(CartoonButtonStyle(accent: AppColors.zombiePrimary))
    }
    
    // MARK: - Infection Request Alert
    
    private func infectionRequestAlert(request: BluetoothTagService.TagRequest) -> some View {
        let alertText = "\(request.fromPlayerName) wants to infect you!"
        let alertColor = AppColors.zombiePrimary
        
        return VStack(spacing: AppSpacing.sm) {
            Text(alertText)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
                .multilineTextAlignment(.center)
            
            HStack(spacing: AppSpacing.md) {
                Button(action: {
                    gameService.rejectTag()
                }) {
                    Text("Reject")
                }
                .buttonStyle(CartoonButtonStyle(accent: AppColors.error, cornerRadius: 14))
                
                Button(action: {
                    gameService.confirmTag(playerId: request.fromPlayerId)
                }) {
                    Text("Confirm")
                }
                .buttonStyle(CartoonButtonStyle(accent: alertColor, cornerRadius: 14))
            }
        }
        .padding()
        .cartoonCard(cornerRadius: 18)
    }
    
    // MARK: - Distance Indicators
    
    private var distanceIndicators: some View {
        return Group {
            if let currentPlayer = gameService.currentPlayer, currentPlayer.isAlive {
                // ZombieTag: Humans see nearest zombie, Zombies see nearest human
                if currentPlayer.role == .human, let distance = gameService.nearestHunterDistance {
                    distanceIndicator(
                        label: "Nearest Zombie",
                        distance: distance,
                        isDanger: distance < 20
                    )
                } else if currentPlayer.role == .zombie, let distance = gameService.nearestHiderDistance {
                    distanceIndicator(
                        label: "Nearest Human",
                        distance: distance,
                        isDanger: false
                    )
                }
            }
        }
    }
    
    private func distanceIndicator(label: String, distance: Double, isDanger: Bool) -> some View {
        HStack {
            Image(systemName: isDanger ? "exclamationmark.triangle.fill" : "location.fill")
                .foregroundColor(proximityColor(for: distance))
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
            Spacer()
            Text("\(Int(distance))m")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(proximityColor(for: distance))
        }
        .padding()
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
    }
    
    private func proximityColor(for distance: Double) -> Color {
        if distance < 10 {
            return .red
        } else if distance < 20 {
            return .orange
        } else if distance < 50 {
            return .yellow
        } else {
            return .green
        }
    }
    
    // MARK: - Phase 5: New Zone System Feedback
    
    // Phase 5: Combined Zone Status and Safe Area Indicator
    private func combinedZoneIndicator(bubble: Bubble) -> some View {
        let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: currentTime)
        let phaseName: String = {
            if runtimeState.phaseState == .rotation {
                return "Rotation"
            } else if runtimeState.phaseState == .closing {
                return "Closing"
            } else if runtimeState.phaseState == .openingGrace {
                return "Opening"
            } else {
                return "Active"
            }
        }()
        
        let distanceToSafe = distanceToSafeArea
        let distanceFromEdge = distanceToSafe.map { abs($0) } ?? nil
        let isInside = distanceToSafe.map { $0 < 0 } ?? false
        let primaryColor = runtimeState.phaseState == .closing ? AppColors.error : AppColors.zombiePrimary
        let safeAreaColor = isInside ? AppColors.success : (distanceFromEdge.map { $0 < 50 ? AppColors.error : primaryColor } ?? primaryColor)
        
        return HStack(spacing: 12) {
            // Phase indicator
            HStack(spacing: 6) {
                Image(systemName: runtimeState.phaseState == .closing ? "arrow.triangle.2.circlepath" : "circle.fill")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryColor)
                Text(phaseName)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
            }
            
            // Divider
            Rectangle()
                .fill(AppColors.cartoonInk.opacity(0.22))
                .frame(width: 2)
            
            // Safe Area distance
            HStack(spacing: 6) {
                Image(systemName: isInside ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(safeAreaColor)
                if let distance = distanceFromEdge {
                    Text(isInside ? "Inside" : "\(Int(distance))m")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(safeAreaColor)
                } else {
                    Text("-")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                }
            }
        }
        .padding()
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
    }
    
    // Phase 5: Boundary Speed Indicator
    private func boundarySpeedIndicator(speed: Double) -> some View {
        let speedKmh = speed * 3.6 // Convert m/s to km/h
        let color = speed > 2.0 ? AppColors.error : (speed > 1.0 ? AppColors.zombieSecondary : AppColors.zombiePrimary)
        
        return HStack {
            Image(systemName: "speedometer")
                .foregroundColor(color)
            Text("Boundary Speed")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
            Spacer()
            Text("\(String(format: "%.1f", speedKmh)) km/h")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding()
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
    }
    
    private func playersStatusCard(session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: "person.2.fill")
                Text("Players")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Spacer()
                Text("\(session.players.filter { $0.isAlive }.count)/\(session.players.count)")
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            
            // Show eliminated count if any
            if session.players.contains(where: { !$0.isAlive }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.error)
                        .font(.caption)
                    Text("\(session.players.filter { !$0.isAlive }.count) eliminated")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                }
            }
            
            // Show infected count if any (for zombies)
            if let currentPlayer = gameService.currentPlayer,
               currentPlayer.role == .zombie,
               !gameService.caughtPlayers.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.success)
                        .font(.caption)
                    Text("\(gameService.caughtPlayers.count) infected")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
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
        guard let bubble = gameService.session?.bubble else { return nil }
        if bubble.usesNewZoneSystem {
            return ZoneService.deriveRuntimeZoneState(for: bubble, now: currentTime).currentActiveZone.radiusMeters
        } else {
            return bubble.currentRadius(at: currentTime)
        }
    }
    
    // Phase 5: Distance to Safe Area (for new zone system)
    private var distanceToSafeArea: Double? {
        guard let bubble = gameService.session?.bubble,
              bubble.usesNewZoneSystem,
              let playerCoord = locationService.coordinate else {
            return nil
        }
        
        let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: currentTime)
        return runtimeState.distanceToEdge(from: playerCoord)
    }
    
    // Phase 5: Boundary Speed (for new zone system)
    private var boundarySpeed: Double? {
        guard let bubble = gameService.session?.bubble,
              bubble.usesNewZoneSystem,
              bubble.isClosing || bubble.isContinuousMode else {
            return nil
        }
        
        // Get speed from current phase or bubble
        if let lastPhase = bubble.phaseHistory.last,
           lastPhase.phaseNumber == bubble.currentPhaseNumber {
            return lastPhase.closingSpeed
        }
        return bubble.closingSpeed > 0 ? bubble.closingSpeed : nil
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
    
    // MARK: - Compass

    /// True if either the zombie's pulse ability OR the human's passive
    /// compass should render in the overlay slot.
    private var shouldShowCompassOverlay: Bool {
        gameService.canShowCompassAbility || shouldShowPreyPassiveCompass
    }

    /// Human-only passive nearest-zombie compass. Zone-gated as before.
    private var shouldShowPreyPassiveCompass: Bool {
        guard let player = gameService.currentPlayer, player.isAlive,
              player.role == .human else {
            return false
        }
        guard let bubble = gameService.session?.bubble,
              let currentRadius = currentBubbleRadius else { return false }
        let shrinkRatio = currentRadius / bubble.startRadius
        return shrinkRatio < 0.3
    }

    @ViewBuilder
    private var compassOverlayContent: some View {
        if gameService.canShowCompassAbility, let skin = PulseSkin(gameType: .zombieTag) {
            let pulseCommit = gameService.compassPulseLastResult.flatMap { result -> CompassPulseCommit? in
                if case .success(let commit) = result { return commit }
                return nil
            }
            PredatorPulseControl(
                skin: skin,
                cooldownRemaining: gameService.compassCooldownRemaining(),
                cooldownTotal: gameService.compassCooldownTotal(),
                inFlight: gameService.compassPulseInFlight,
                hasEligiblePrey: gameService.compassHasEligiblePrey,
                lastResult: gameService.compassPulseLastResult,
                resultBearing: pulseCommit.flatMap { gameService.compassBearing(for: $0) },
                headingDegreesFromNorth: locationService.headingDegreesFromNorth,
                onTap: { Task { await gameService.requestCompassPulse() } }
            )
        } else if shouldShowPreyPassiveCompass,
                  let direction = gameService.nearestHunterDirection,
                  let distance = gameService.nearestHunterDistance {
            CompassView(
                direction: direction,
                distance: distance,
                threatType: .hunter,
                isVisible: true,
                headingDegreesFromNorth: locationService.headingDegreesFromNorth
            )
        }
    }
    
    // MARK: - Compact Top HUD Rows
    
    private func compactZoneInfoRow(bubble: Bubble) -> some View {
        let distance = gameService.distanceToEdge ?? 0
        let isAlive = gameService.currentPlayer?.isAlive == true
        
        if bubble.usesNewZoneSystem {
            let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: currentTime)
            let currentRadius = runtimeState.currentActiveZone.radiusMeters
            let distanceFromEdge = abs(distance)
            let isOutside = distance > 0
            
            return HStack(spacing: 6) {
                Image(systemName: runtimeState.phaseState == .closing ? "arrow.triangle.2.circlepath" : "circle.fill")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(bubbleColor)
                Text("\(Int(currentRadius))m")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                
                if isAlive {
                    Text("•")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                    Image(systemName: isOutside ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                    Text("\(Int(distanceFromEdge))m")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                }
            }
        } else {
            // Legacy system
            let currentRadius = currentBubbleRadius ?? 0
            let distanceFromEdge = abs(distance)
            let isOutside = distance > 0
            
            return HStack(spacing: 6) {
                Image(systemName: "circle.fill")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(bubbleColor)
                Text("\(Int(currentRadius))m")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                
                if isAlive {
                    Text("•")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                    Image(systemName: isOutside ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                    Text("\(Int(distanceFromEdge))m")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(isOutside ? AppColors.error : AppColors.success)
                }
            }
        }
    }
    
    private func compactPlayersRow(session: GameSession) -> some View {
        let alivePlayers = session.players.filter { $0.isAlive }
        let zombies = alivePlayers.filter { $0.role == .zombie }
        let humans = alivePlayers.filter { $0.role == .human }
        
        return HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
            Text("\(alivePlayers.count)/\(session.players.count)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
            
            if !zombies.isEmpty && !humans.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.zombiePrimary)
                        .frame(width: 4, height: 4)
                    Text("\(zombies.count)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.zombiePrimary)
                    
                    Circle()
                        .fill(AppColors.humanPrimary)
                        .frame(width: 4, height: 4)
                    Text("\(humans.count)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.humanPrimary)
                }
            }
        }
    }
    
    private func compactSafeAreaRow(distance: Double, isClosing: Bool) -> some View {
        let distanceFromEdge = abs(distance)
        let isInside = distance < 0
        let primaryColor = isClosing ? AppColors.error : AppColors.zombiePrimary
        let safeAreaColor = isInside ? AppColors.success : (distanceFromEdge < 50 ? AppColors.error : primaryColor)
        
        return HStack(spacing: 6) {
            Image(systemName: isInside ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(safeAreaColor)
            Text(isInside ? "Inside" : "\(Int(distanceFromEdge))m to safe")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(safeAreaColor)
        }
    }
    
    private func compactOutOfBoundsRow() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(AppColors.error)
            Text(gameService.currentPlayer?.isAlive == false ? "ELIMINATED" : "OUT OF BOUNDS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(AppColors.error)
        }
    }
    
    private var bottomFunctionalButtons: some View {
        VStack(spacing: 12) {
            // Infect Button (for zombies when BLE connection established with a human)
            if let currentPlayer = gameService.currentPlayer,
               currentPlayer.role == .zombie,
               currentPlayer.isAlive,
               let taggablePlayerId = gameService.canTagPlayerId,
               let taggablePlayer = gameService.session?.players.first(where: { $0.id == taggablePlayerId }),
               taggablePlayer.role == .human,
               taggablePlayer.isAlive {
                infectButton(player: taggablePlayer)
            }
            
            // Infection Request Alert (for humans)
            if let tagRequest = gameService.pendingTagRequest {
                infectionRequestAlert(request: tagRequest)
            }
        }
    }
    
    // MARK: - Combined Zone Timer Card
    
    private var combinedZoneTimerCard: some View {
        Group {
            if gameService.gameState == .active,
               let bubble = gameService.session?.bubble,
               bubble.usesNewZoneSystem,
               showZoneNotification {
                // Show zone notification with countdown timer (time until next stage)
                HStack(spacing: 12) {
                    Image(systemName: zoneNotificationIcon)
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(zoneNotificationColor)
                    
                    Text(zoneNotificationTitle)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    
                    Text(formatCountdown(zoneNotificationCountdown))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(zoneNotificationColor)
                        .lineLimit(1)
                    
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else if gameService.gameState == .active,
                      let bubble = gameService.session?.bubble,
                      bubble.showTimer {
                // Fallback: Show regular game timer if zone system not active or timer enabled
                let elapsed = currentTime.timeIntervalSince(bubble.startTime)
                let remaining = max(0, bubble.duration - elapsed)
                
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                    
                    Text(timeString(from: remaining))
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(remaining < 60 ? AppColors.zombiePrimary : AppColors.cartoonInk)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            } else {
                EmptyView()
            }
        }
    }
    
    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "%d", secs)
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
    
    // MARK: - Proximity Warning Banner
    
    @State private var proximityPulseScale: CGFloat = 1.0
    
    private func proximityWarningBanner(distance: Double, level: GameService.ProximityWarningLevel) -> some View {
        let (color, icon, message) = proximityWarningContent(distance: distance, level: level)
        
        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("\(Int(distance))m away")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Spacer()
            
            // Distance indicator bar
            if level == .danger || level == .warning {
                GeometryReader { geometry in
                    let progress = min(1.0, distance / 50.0) // Normalize to 50m max
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: geometry.size.width * progress)
                        Spacer()
                    }
                }
                .frame(width: 40, height: 4)
                .background(Color.white.opacity(0.2))
                .cornerRadius(2)
            }
        }
        .padding()
        .background(level == .safe || level == .caution ? color : AppColors.zombiePrimary)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: level == .danger ? 3 : 2)
        )
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.18))
                .offset(x: 4, y: 4)
        )
        .scaleEffect(proximityPulseScale)
        .onAppear {
            if level == .danger {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    proximityPulseScale = 1.02
                }
            }
        }
        .onChange(of: level) { oldValue, newValue in
            if newValue == .danger {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    proximityPulseScale = 1.02
                }
            } else {
                withAnimation {
                    proximityPulseScale = 1.0
                }
            }
        }
    }
    
    private func proximityWarningContent(distance: Double, level: GameService.ProximityWarningLevel) -> (Color, String, String) {
        switch level {
        case .danger:
            return (.red, "exclamationmark.triangle.fill", "Zombie Very Close!")
        case .warning:
            return (.orange, "exclamationmark.circle.fill", "Zombie Nearby")
        case .caution:
            return (.yellow, "eye.fill", "Zombie Detected")
        case .safe:
            return (.green, "checkmark.circle.fill", "Safe Distance")
        case .none:
            return (.gray, "circle.fill", "")
        }
    }
    
    // MARK: - Zone Notification Timer
    
    private func startZoneNotificationTimer() {
        stopZoneNotificationTimer() // Stop any existing timer
        
        guard gameService.session?.bubble?.usesNewZoneSystem == true else {
            showZoneNotification = false
            return
        }
        
        // Update notification every second
        zoneNotificationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateZoneNotification()
            }
        }
        
        // Initial update
        updateZoneNotification()
    }
    
    private func stopZoneNotificationTimer() {
        zoneNotificationTimer?.invalidate()
        zoneNotificationTimer = nil
    }
    
    private func updateZoneNotification() {
        guard let bubble = gameService.session?.bubble,
              bubble.usesNewZoneSystem else {
            showZoneNotification = false
            return
        }
        
        let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble)
        let remaining = max(0, runtimeState.timeRemainingInPhase ?? 0)
        showZoneNotification = runtimeState.scheduleIsEnabled && runtimeState.scheduleIsValid
        
        switch runtimeState.phaseState {
        case .openingGrace:
            zoneNotificationTitle = "First zone reveals in"
            zoneNotificationIcon = "circle.dashed"
            zoneNotificationColor = Color.orange
        case .rotation:
            zoneNotificationTitle = "Zone closes in"
            zoneNotificationIcon = "arrow.triangle.2.circlepath"
            zoneNotificationColor = AppColors.zombiePrimary
        case .closing:
            zoneNotificationTitle = "Zone closing"
            zoneNotificationIcon = "arrow.triangle.2.circlepath"
            zoneNotificationColor = Color.red
        case .complete:
            zoneNotificationTitle = "New safe zone active"
            zoneNotificationIcon = "checkmark.circle.fill"
            zoneNotificationColor = AppColors.success
        }
        zoneNotificationCountdown = remaining
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
