//
//  ManhuntActiveGameView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import MapKit

struct ManhuntActiveGameView: View {
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
    @State private var lastBubbleRadius: Double?
    @State private var currentTime: Date = Date()
    @State private var lastPhaseNumber: Int = -1
    @State private var lastWarningState: Bool = false
    @State private var lastClosingState: Bool = false
    
    // Fortnite-style zone notification state
    @State private var showZoneNotification: Bool = false
    @State private var zoneNotificationTitle: String = ""
    @State private var zoneNotificationCountdown: TimeInterval = 0
    @State private var zoneNotificationIcon: String = ""
    @State private var zoneNotificationColor: Color = .orange
    @State private var zoneNotificationTimer: Timer?
    @State private var timer: Timer?
    @State private var toastMessage: AppToastMessage? = nil
    @State private var showHonorConfirm: Bool = false
    @StateObject private var obfuscationService = LocationObfuscationService()
    @State private var showEliminationScreen: Bool = false
    @State private var wasAlive: Bool = true
    @State private var compassHubExpanded: Bool = false
    @State private var compassForceClose: Int = 0
    @State private var notificationsHubExpanded: Bool = false
    @State private var notificationsForceClose: Int = 0
    @State private var optionsHubExpanded: Bool = false
    @State private var optionsForceClose: Int = 0
    @State private var showOptionsEndGameConfirm: Bool = false
    
    /// Host-only: drives hub `onEndGame` and options modal.
    private var isManhuntHost: Bool {
        guard let session = gameService.session else { return false }
        return session.isDeviceHost(gameService.currentPlayer)
    }
    
    @ViewBuilder
    private var activeGameMapHub: some View {
        ActiveGameMapHubView(
            mapType: $mapType,
            showPlayerLabels: $showPlayerLabels,
            onZoomToBubble: { zoomToBubbleTrigger = true },
            onCenterOnPlayer: { centerOnPlayerTrigger = true },
            bubbleExists: gameService.session?.bubble != nil,
            playerLocationExists: locationService.coordinate != nil,
            gameType: gameService.session?.gameType,
            onEndGame: isManhuntHost ? { _ = performHostEndGameIfAllowed() } : nil,
            announcementManager: gameService.announcementManager,
            showCompassButton: shouldShowCompassOverlay,
            onCompassActivated: { active in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    compassHubExpanded = active
                }
            },
            onNotificationsActivated: { active in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    notificationsHubExpanded = active
                }
            },
            notificationsModalPresented: notificationsHubExpanded,
            onOptionsActivated: { active in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
                    optionsHubExpanded = active
                }
            },
            notificationsForceCloseSignal: notificationsForceClose,
            optionsForceCloseSignal: optionsForceClose,
            compassForceCloseSignal: compassForceClose
        )
    }
    
    var body: some View {
        let bubbleCenter = gameService.session?.bubble?.center
        let bubbleRadius = currentBubbleRadius
        
        ZStack {
            // Elimination Screen (full screen overlay when player is eliminated)
            if showEliminationScreen, let currentPlayer = gameService.currentPlayer, !currentPlayer.isAlive {
                ManhuntEliminationView(
                    onSpectate: {
                        showEliminationScreen = false
                    },
                    eliminationReason: gameService.lastEliminationMessage
                )
                .transition(.opacity)
                .zIndex(1000) // Ensure it's on top
            }
            
            // Debug: Ensure view is rendering
            Color.clear
                .onAppear {
                    print("🗺️ ManhuntActiveGameView body appeared")
                    print("   gameState: \(gameService.gameState)")
                    print("   session exists: \(gameService.session != nil)")
                    print("   bubble exists: \(gameService.session?.bubble != nil)")
                    print("   location exists: \(locationService.coordinate != nil)")
                    // Initialize wasAlive state
                    wasAlive = gameService.currentPlayer?.isAlive ?? true
                    
                }
                .onChange(of: gameService.currentPlayer?.isAlive) { oldValue, newValue in
                    // Show elimination screen when player becomes eliminated
                    if wasAlive && newValue == false {
                        showEliminationScreen = true
                    }
                    wasAlive = newValue ?? true
                }
            // Proximity warning overlay (screen flash when hunter very close)
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
            
            // Full-screen compass overlay
            if compassHubExpanded {
                compassFullScreenOverlay
                    .zIndex(200)
                    .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
            }

            // Full-screen notifications modal
            if notificationsHubExpanded {
                notificationsModal
                    .zIndex(201)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            if optionsHubExpanded {
                optionsModal
                    .zIndex(202)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }

            // Game HUD Overlay - Using absolute positioning for fixed elements
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ActiveGameStatusStrip(safeAreaTop: geometry.safeAreaInsets.top)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            topHUD

                            Spacer(minLength: 8)

                            activeGameMapHub
                        }
                        .padding(.leading, AppSpacing.md)
                        .padding(.trailing, AppSpacing.sm)
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
            
            // Tag rejection toast (e.g. wrong role, not close enough)
            if let rejection = gameService.tagRequestRejectedMessage {
                VStack {
                    Spacer()
                    tagRejectionBanner(message: rejection)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.bottom, AppSpacing.xl + 60)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: gameService.tagRequestRejectedMessage)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .activeGameStatusBarHidden()
        // Note: allowsHitTesting removed - buttons need to be interactive!
        .appToast($toastMessage)
        .themedNotice(
            isPresented: $showOptionsEndGameConfirm,
            primaryColor: AppColors.manhuntPrimary,
            secondaryColor: AppColors.manhuntSecondary,
            iconName: "stop.circle.fill",
            headerTitle: "Manhunt",
            headerSubtitle: "Host controls",
            title: "End game?",
            message: "This ends the current game for everyone.",
            buttons: [
                ThemedNoticeButton(title: "Cancel", icon: nil, role: .secondary, action: {}),
                ThemedNoticeButton(title: "End Game", icon: "stop.circle.fill", role: .destructive) {
                    if performHostEndGameIfAllowed() {
                        dismissOptionsHub()
                    }
                }
            ]
        )
        .onChange(of: isManhuntHost) { _, isHost in
            if !isHost { showOptionsEndGameConfirm = false }
        }
        .themedInGameConfirmation(
            isPresented: $showHonorConfirm,
            primaryColor: AppColors.manhuntPrimary,
            secondaryColor: AppColors.manhuntSecondary,
            iconName: "figure.run",
            headerTitle: "Manhunt",
            headerSubtitle: "Bluetooth backup",
            title: "Were you tagged?",
            message: "Use this if a hunter got you but Bluetooth didn’t register the tag. It removes you from the game like a normal catch. You can’t undo this.",
            cancelTitle: "Still hiding",
            confirmTitle: "I'm tagged",
            confirmAccentColor: AppColors.error,
            onConfirm: {
                gameService.honorReportTagged()
            }
        )
        .onChange(of: currentBubbleRadius) { oldValue, newValue in
            // Only detect zone shrink if shrinking is enabled
            guard let bubble = gameService.session?.bubble, bubble.enableShrinking else {
                lastBubbleRadius = newValue
                return
            }
            
            // Detect zone shrink
            if let old = oldValue, let new = newValue, new < old && old > 0 {
                let shrinkAmount = old - new
                if shrinkAmount > 5 {
                    let newRadius = Int(new)
                    gameService.announcementManager.post("Zone shrinking! New radius: \(newRadius)m", type: .zoneShrink)
                    HapticFeedbackManager.shared.selection()
                }
            }
            lastBubbleRadius = newValue
        }
        .onChange(of: gameService.session?.bubble?.warningStartTime) { oldValue, newValue in
            // Only show warning if shrinking is enabled
            guard let bubble = gameService.session?.bubble, bubble.enableShrinking else { return }
            
            // Phase 5: Detect warning phase start
            if newValue != nil && oldValue == nil {
                gameService.announcementManager.post("Zone closes soon.", type: .warning)
                HapticFeedbackManager.shared.warning()
            }
        }
        .onChange(of: gameService.session?.bubble?.isClosing) { oldValue, newValue in
            // Only show closing message if shrinking is enabled
            guard let bubble = gameService.session?.bubble, bubble.enableShrinking else { return }
            
            // Phase 5: Detect closing phase start
            if newValue == true && oldValue == false {
                gameService.announcementManager.post("Zone closing.", type: .warning)
                HapticFeedbackManager.shared.zoneShrink()
            }
        }
        .onAppear {
            lastBubbleRadius = currentBubbleRadius
            startTimer()
            startZoneNotificationTimer()
        }
        .onDisappear {
            stopTimer()
            stopZoneNotificationTimer()
        }
        .onChange(of: gameService.session?.bubble?.usesNewZoneSystem) { oldValue, newValue in
            if newValue == true, let bubble = gameService.session?.bubble, bubble.enableShrinking {
                startZoneNotificationTimer()
            } else {
                stopZoneNotificationTimer()
            }
        }
        .onChange(of: gameService.session?.bubble?.enableShrinking) { oldValue, newValue in
            // Stop zone notifications if shrinking is disabled
            if newValue == false {
                stopZoneNotificationTimer()
                showZoneNotification = false
            } else if newValue == true, let bubble = gameService.session?.bubble, bubble.usesNewZoneSystem {
                // Start notifications if shrinking is enabled and zone system is active
                startZoneNotificationTimer()
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
    
    // MARK: - Obfuscation snapshots
    //
    // The obfuscation service owns opponent location snapshots. We need to
    // refresh them on first load (so the map never falls back to live
    // coordinates) and on every epoch change. We also refresh when the
    // player roster or viewer identity changes so joiners are snapshotted
    // on first sight.
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
    /// role, alive state, or flag flag changes. This catches in-place
    /// session mutations (e.g. a hider being eliminated, a role swap on
    /// game restart) that don't change the ordered id list and therefore
    /// wouldn't fire `.onChange(of: players.map { $0.id })`.
    private var rosterObfuscationSignature: [String] {
        gameService.session?.players.map { "\($0.id)|\($0.role.rawValue)|\($0.isAlive ? 1 : 0)|\($0.isFlag ? 1 : 0)" }
            ?? []
    }
    
    // MARK: - Top HUD
    
    // MARK: - Top HUD (2×2 grid)

    private var topHUD: some View {
        VStack(alignment: .center, spacing: 0) {
            // Role pill header
            hudRolePill
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 7)

            Rectangle()
                .fill(AppColors.cartoonInk.opacity(0.1))
                .frame(height: 1)

            // 2×2 stat grid: zone | position / hunters | hiders
            hudStatGrid
                .padding(.horizontal, 10)
                .padding(.vertical, 8)

            // Timer row — only visible when a countdown is running
            if hasActiveZoneTimer {
                Rectangle()
                    .fill(AppColors.cartoonInk.opacity(0.1))
                    .frame(height: 1)
                hudTimerRow
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
        .onChange(of: currentBubbleRadius) { oldValue, newValue in
            if let old = oldValue, let new = newValue, new < old {
                zoneShrinkPulse = true
                HapticFeedbackManager.shared.selection()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { zoneShrinkPulse = false }
            }
        }
    }

    @ViewBuilder
    private var hudRolePill: some View {
        if let player = gameService.currentPlayer {
            let (text, color): (String, Color) = {
                if !player.isAlive { return ("ELIMINATED", AppColors.error) }
                return player.role == .hunter
                    ? ("HUNTER", AppColors.hunterPrimary)
                    : ("HIDER", AppColors.hiderPrimary)
            }()
            CartoonPill(text: text, color: color)
        }
    }

    private var hudStatGrid: some View {
        let distance      = gameService.distanceToEdge ?? 0
        let isOutside     = distance > 0
        let distanceAbs   = abs(distance)
        let isAlive       = gameService.currentPlayer?.isAlive == true
        let radius        = currentBubbleRadius ?? 0

        let posIcon: String = isOutside ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
        let posColor: Color = isOutside ? AppColors.error : AppColors.success
        let posValue: String = {
            if !isAlive    { return "Out" }
            if isOutside   { return "\(Int(distanceAbs))m" }
            return "Inside"
        }()
        let posLabel: String? = isOutside ? "to edge" : nil

        let hunters = gameService.session?.players.filter { $0.isAlive && $0.role == .hunter }.count ?? 0
        let hiders  = gameService.session?.players.filter { $0.isAlive && $0.role == .hider  }.count ?? 0

        return Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 5) {
            GridRow {
                statCell(sfSymbol: "circle.fill", color: bubbleColor,
                         primary: "\(Int(radius))m", secondary: "zone")
                statCell(sfSymbol: posIcon, color: posColor,
                         primary: posValue, secondary: posLabel)
            }
            GridRow {
                statCell(dotColor: AppColors.hunterPrimary, primary: "\(hunters)", secondary: "hunters")
                statCell(dotColor: AppColors.hiderPrimary,  primary: "\(hiders)",  secondary: "hiders")
            }
        }
    }

    private func statCell(sfSymbol: String, color: Color, primary: String, secondary: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: sfSymbol)
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Text(primary)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .lineLimit(1)
                    .fixedSize()
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.45))
            }
        }
    }

    private func statCell(dotColor: Color, primary: String, secondary: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
                Text(primary)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .lineLimit(1)
                    .fixedSize()
            }
            if let secondary {
                Text(secondary)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.45))
            }
        }
    }

    private var hasActiveZoneTimer: Bool {
        guard gameService.gameState == .active, let bubble = gameService.session?.bubble else { return false }
        if bubble.usesNewZoneSystem && bubble.enableShrinking && showZoneNotification { return true }
        return bubble.showTimer
    }

    @ViewBuilder
    private var hudTimerRow: some View {
        if gameService.gameState == .active,
           let bubble = gameService.session?.bubble,
           bubble.usesNewZoneSystem, bubble.enableShrinking, showZoneNotification {
            HStack(spacing: 5) {
                Image(systemName: zoneNotificationIcon)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(zoneNotificationColor)
                Text(zoneNotificationTitle)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .lineLimit(1)
                Text(formatCountdown(zoneNotificationCountdown))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(zoneNotificationColor)
            }
        } else if gameService.gameState == .active,
                  let bubble = gameService.session?.bubble, bubble.showTimer,
                  bubble.startTime <= currentTime {
            let elapsed   = currentTime.timeIntervalSince(bubble.startTime)
            let remaining = max(0, bubble.duration - elapsed)
            HStack(spacing: 5) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.6))
                Text(timeString(from: remaining))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(remaining < 60 ? AppColors.hunterPrimary : AppColors.cartoonInk)
            }
        }
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
    
    @State private var zoneShrinkPulse: Bool = false
    
    
    
    
    // MARK: - Tag Button
    
    private func tagButton(player: Player) -> some View {
        let buttonText = "Tag \(player.displayName)"
        return Button(action: {
            // Verify conditions before tagging
            guard let currentPlayer = gameService.currentPlayer else {
                showTagError("Cannot tag: Player information not available.")
                return
            }
            
            guard currentPlayer.role == .hunter else {
                showTagError("Only hunters can tag players.")
                return
            }
            
            guard currentPlayer.isAlive else {
                showTagError("You cannot tag players after being eliminated.")
                return
            }
            
            guard player.role == .hider else {
                showTagError("You can only tag hiders, not other hunters.")
                return
            }
            
            guard player.isAlive else {
                showTagError("\(player.displayName) has already been eliminated.")
                return
            }
            
            guard gameService.canTagPlayerId == player.id else {
                showTagError("Not close enough to tag \(player.displayName). Stay within Bluetooth range (about 5 meters).")
                return
            }
            
            gameService.requestTag(playerId: player.id)
        }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                Text(buttonText)
            }
        }
        .buttonStyle(CartoonButtonStyle(accent: AppColors.hunterPrimary))
    }
    
    // MARK: - Tag Request Alert
    
    private func tagRequestAlert(request: BluetoothTagService.TagRequest) -> some View {
        let alertText = "\(request.fromPlayerName) wants to tag you!"
        let alertColor = AppColors.hunterPrimary
        
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
        let primaryColor = runtimeState.phaseState == .closing ? AppColors.error : AppColors.hunterPrimary
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
    
    /// Ends the active session only when the local player is the game host and the game is active.
    @discardableResult
    private func showTagError(_ message: String) {
        toastMessage = AppToastMessage(message: message, type: .error)
    }

    private func performHostEndGameIfAllowed() -> Bool {
        guard let session = gameService.session else {
            showTagError("Cannot end game: No active session.")
            return false
        }
        guard let currentPlayer = gameService.currentPlayer else {
            showTagError("Cannot end game: Player information not available.")
            return false
        }
        guard session.isDeviceHost(currentPlayer) else {
            showTagError("Only the host can end the game.")
            return false
        }
        guard gameService.gameState == .active else {
            showTagError("Game is not currently active.")
            return false
        }
        gameService.endGame()
        return true
    }
    
    private var endGameButton: some View {
        Button(action: {
            _ = performHostEndGameIfAllowed()
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

    /// True if the compass button should appear in the hub.
    private var shouldShowCompassOverlay: Bool {
        gameService.canShowCompassAbility || shouldShowPreyPassiveCompass
    }

    /// Hider-only passive nearest-hunter compass. Zone-gated to later in
    /// the game so it doesn't dominate the early UI.
    private var shouldShowPreyPassiveCompass: Bool {
        guard let player = gameService.currentPlayer, player.isAlive,
              player.role == .hider else { return false }
        guard let bubble = gameService.session?.bubble,
              let currentRadius = currentBubbleRadius else { return false }
        return currentRadius / bubble.startRadius < 0.3
    }

    /// Full-screen blur + large compass, shown when the hub's compass button is active.
    private var compassFullScreenOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissCompassHub()
                }

            compassFullScreenContent
        }
        .overlay(alignment: .top) {
            Text("TAP ANYWHERE TO DISMISS")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.55))
                .tracking(2)
                .padding(.top, 12)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var compassFullScreenContent: some View {
        if gameService.canShowCompassAbility, let skin = PulseSkin(gameType: .manhunt) {
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
            .scaleEffect(2.4)
            .fixedSize(horizontal: true, vertical: true)
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
            .scaleEffect(2.6)
            .fixedSize(horizontal: true, vertical: true)
        }
    }
    
    // MARK: - Hub modal dismissals
    
    private func dismissNotificationsHub() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            notificationsHubExpanded = false
        }
        notificationsForceClose += 1
    }
    
    private func dismissOptionsHub() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            optionsHubExpanded = false
        }
        optionsForceClose += 1
    }
    
    private func dismissCompassHub() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            compassHubExpanded = false
        }
        compassForceClose += 1
    }
    
    // MARK: - Notifications Modal

    @ViewBuilder
    private var notificationsModal: some View {
        ActiveGameHubSquareModalShell(
            title: "Notifications",
            titleIcon: "bell.fill",
            titleIconTint: AppColors.manhuntPrimary,
            onDismiss: dismissNotificationsHub
        ) {
            let entries = gameService.announcementManager.notificationHistory
            if entries.isEmpty {
                VStack(spacing: AppSpacing.sm) {
                    Image(systemName: "tray")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.3))
                    Text("No events yet")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(entries) { entry in
                            notificationRow(entry)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
    }
    
    @ViewBuilder
    private var optionsModal: some View {
        ActiveGameHubSquareModalShell(
            title: "Options",
            titleIcon: "ellipsis.circle.fill",
            titleIconTint: AppColors.manhuntPrimary,
            onDismiss: dismissOptionsHub
        ) {
            VStack(spacing: AppSpacing.md) {
                if isManhuntHost {
                    Button {
                        HapticFeedbackManager.shared.selection()
                        showOptionsEndGameConfirm = true
                    } label: {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "stop.circle.fill")
                            Text("End Game")
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CartoonButtonStyle(accent: AppColors.error))
                    .padding(.top, AppSpacing.sm)
                } else {
                    Text("Only the host can end the game for everyone.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.top, AppSpacing.md)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
        }
    }

    private func notificationRow(_ entry: GameAnnouncement) -> some View {
        HStack(spacing: 0) {
            // Colored left accent bar — instantly communicates notification type
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(entry.type.accentColor)
                .frame(width: 4)
                .padding(.vertical, 6)
                .padding(.leading, 6)

            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: entry.type.accentColor, size: 30) {
                    Image(systemName: entry.type.icon)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.message)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(entry.timestamp, style: .relative)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 9)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(entry.type.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(entry.type.accentColor.opacity(0.3), lineWidth: 1.5)
        )
    }

    
    private var bottomFunctionalButtons: some View {
        VStack(spacing: 12) {
            // Tag Button (for hunters when BLE connection established with a hider)
            if let currentPlayer = gameService.currentPlayer,
               currentPlayer.role == .hunter,
               currentPlayer.isAlive,
               let taggablePlayerId = gameService.canTagPlayerId,
               let taggablePlayer = gameService.session?.players.first(where: { $0.id == taggablePlayerId }),
               taggablePlayer.role == .hider,
               taggablePlayer.isAlive {
                tagButton(player: taggablePlayer)
            }
            
            // Manual tag confirm when BLE didn’t register a real tag
            if let currentPlayer = gameService.currentPlayer,
               currentPlayer.role == .hider,
               currentPlayer.isAlive {
                honorSelfTagButton
            }
            
            // Tag Request Alert (for hiders)
            if let tagRequest = gameService.pendingTagRequest {
                tagRequestAlert(request: tagRequest)
            }
        }
    }
    
    private var honorSelfTagButton: some View {
        Button(action: {
            HapticFeedbackManager.shared.selection()
            showHonorConfirm = true
        }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "hand.raised.fill")
                    .font(.title3)
                Text("I got tagged")
            }
        }
        .buttonStyle(CartoonButtonStyle(accent: AppColors.hiderPrimary))
    }
    
    // MARK: - Combined Zone Timer Card
    
    
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
    
    private func tagRejectionBanner(message: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "hand.raised.slash.fill")
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(AppColors.warning)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))
            
            Text(message)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
                .lineLimit(2)
            
            Spacer()
        }
        .padding()
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
    }
    
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
    
    
    // MARK: - Zone Notification Timer
    
    private func startZoneNotificationTimer() {
        stopZoneNotificationTimer() // Stop any existing timer
        
        guard let bubble = gameService.session?.bubble,
              bubble.usesNewZoneSystem,
              bubble.enableShrinking else {
            print("🔵 Zone Notification Timer: Not starting - zone system not enabled or shrinking disabled")
            showZoneNotification = false
            return
        }
        
        print("🔵 Zone Notification Timer: Starting timer. Phase: \(bubble.currentPhaseNumber)")
        
        // Update notification every second
        zoneNotificationTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateZoneNotification()
            }
        }
        
        // Add timer to main run loop for better reliability
        if let timer = zoneNotificationTimer {
            RunLoop.main.add(timer, forMode: .common)
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
              bubble.usesNewZoneSystem,
              bubble.enableShrinking else {
            print("🔵 Zone Notification: Bubble or zone system not available, or shrinking disabled")
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
            zoneNotificationColor = AppColors.manhuntPrimary
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

// MARK: - Hub modal chrome

private struct ActiveGameHubSquareModalShell<Content: View>: View {
    let title: String
    let titleIcon: String
    let titleIconTint: Color
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let insetW = geo.size.width - AppSpacing.lg * 2
            let insetH = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom - AppSpacing.lg * 2
            let side = max(260, min(min(insetW, insetH), 340))

            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .onTapGesture { onDismiss() }

                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: titleIcon)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(titleIconTint)
                        Text(title)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk)
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(AppColors.cartoonCream2))
                                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))
                                .background(Circle().fill(AppColors.cartoonShadow).offset(x: 2.5, y: 2.5))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)

                    Divider()
                        .background(AppColors.cartoonInk.opacity(0.2))

                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(width: side, height: side)
                .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
            }
        }
    }
}
