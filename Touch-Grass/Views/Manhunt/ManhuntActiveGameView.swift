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
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var showHonorConfirm: Bool = false
    @StateObject private var obfuscationService = LocationObfuscationService()
    @State private var showEliminationScreen: Bool = false
    @State private var wasAlive: Bool = true
    
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
            
            // Game HUD Overlay - Using absolute positioning for fixed elements
            GeometryReader { geometry in
                let topSecondRow = ActiveGameTopChromeMetrics.stripHeight(for: geometry.safeAreaInsets.top) + AppSpacing.sm
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ActiveGameStatusStrip(safeAreaTop: geometry.safeAreaInsets.top)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .top, spacing: AppSpacing.sm) {
                            topHUD
                                .frame(maxWidth: geometry.size.width * 0.65, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 8)

                            MapControlsView(
                                mapType: $mapType,
                                showPlayerLabels: $showPlayerLabels,
                                onZoomToBubble: { zoomToBubbleTrigger = true },
                                onCenterOnPlayer: { centerOnPlayerTrigger = true },
                                bubbleExists: gameService.session?.bubble != nil,
                                playerLocationExists: locationService.coordinate != nil,
                                gameType: gameService.session?.gameType,
                                onEndGame: { gameService.endGame() }
                            )
                        }
                        .padding(.leading, AppSpacing.md)
                        .padding(.trailing, AppSpacing.sm)
                    }

                // Compass region (middle-right). For predators (hunters)
                // the new pulse ability is always available when alive in
                // an active game; for prey (hiders) the passive nearest-
                // threat compass stays zone-gated as before.
                if shouldShowCompassOverlay {
                    HStack {
                        Spacer()
                        compassOverlayContent
                            .padding(.trailing, AppSpacing.md + 60) // Space for map icon
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
            
            // Announcement Feed (bottom-leading)
            VStack {
                Spacer()
                HStack {
                    GameAnnouncementOverlay(manager: gameService.announcementManager)
                        .padding(.leading, AppSpacing.md)
                        .padding(.bottom, AppSpacing.lg + 60)
                    Spacer()
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
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
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
    
    private var topHUD: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: Zone timer and Role badge
            HStack(spacing: AppSpacing.sm) {
                // Combined Zone Notification & Timer Display
                combinedZoneTimerCard
                    .layoutPriority(1)
                
                // Role Badge (Manhunt: HUNTER or HIDER)
                if let currentPlayer = gameService.currentPlayer, currentPlayer.isAlive {
                    let roleText = currentPlayer.role == .hunter ? "HUNTER" : "HIDER"
                    let roleColor = currentPlayer.role == .hunter ? AppColors.hunterPrimary : AppColors.hiderPrimary
                    
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
                errorMessage = "Cannot tag: Player information not available."
                showErrorAlert = true
                return
            }
            
            guard currentPlayer.role == .hunter else {
                errorMessage = "Only hunters can tag players."
                showErrorAlert = true
                return
            }
            
            guard currentPlayer.isAlive else {
                errorMessage = "You cannot tag players after being eliminated."
                showErrorAlert = true
                return
            }
            
            guard player.role == .hider else {
                errorMessage = "You can only tag hiders, not other hunters."
                showErrorAlert = true
                return
            }
            
            guard player.isAlive else {
                errorMessage = "\(player.displayName) has already been eliminated."
                showErrorAlert = true
                return
            }
            
            guard gameService.canTagPlayerId == player.id else {
                errorMessage = "Cannot tag \(player.displayName): Not close enough. You need to be within Bluetooth range (about 5 meters)."
                showErrorAlert = true
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
                    Text("—")
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
    
    private var endGameButton: some View {
        Button(action: {
            // Verify conditions before ending game
            guard let session = gameService.session else {
                errorMessage = "Cannot end game: No active session."
                showErrorAlert = true
                return
            }
            
            guard let currentPlayer = gameService.currentPlayer else {
                errorMessage = "Cannot end game: Player information not available."
                showErrorAlert = true
                return
            }
            
            guard currentPlayer.id == session.hostId else {
                errorMessage = "Only the host can end the game."
                showErrorAlert = true
                return
            }
            
            guard gameService.gameState == .active else {
                errorMessage = "Game is not currently active."
                showErrorAlert = true
                return
            }
            
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

    /// True if the compass region should render anything — either the
    /// hunter's pulse ability or the hider's zone-gated passive compass.
    private var shouldShowCompassOverlay: Bool {
        gameService.canShowCompassAbility || shouldShowPreyPassiveCompass
    }

    /// Hider-only passive nearest-hunter compass. Zone-gated to "later in
    /// the game" so it doesn't dominate the early UI.
    private var shouldShowPreyPassiveCompass: Bool {
        guard let player = gameService.currentPlayer, player.isAlive,
              player.role == .hider else {
            return false
        }
        guard let bubble = gameService.session?.bubble,
              let currentRadius = currentBubbleRadius else { return false }
        let shrinkRatio = currentRadius / bubble.startRadius
        return shrinkRatio < 0.3
    }

    @ViewBuilder
    private var compassOverlayContent: some View {
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
                onTap: { Task { await gameService.requestCompassPulse() } }
            )
        } else if shouldShowPreyPassiveCompass,
                  let direction = gameService.nearestHunterDirection,
                  let distance = gameService.nearestHunterDistance {
            CompassView(
                direction: direction,
                distance: distance,
                threatType: .hunter,
                isVisible: true
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
        let hunters = alivePlayers.filter { $0.role == .hunter }
        let hiders = alivePlayers.filter { $0.role == .hider }
        
        return HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
            Text("\(alivePlayers.count)/\(session.players.count)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
            
            if !hunters.isEmpty && !hiders.isEmpty {
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.hunterPrimary)
                        .frame(width: 4, height: 4)
                    Text("\(hunters.count)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.hunterPrimary)
                    
                    Circle()
                        .fill(AppColors.hiderPrimary)
                        .frame(width: 4, height: 4)
                    Text("\(hiders.count)")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.hiderPrimary)
                }
            }
        }
    }
    
    private func compactSafeAreaRow(distance: Double, isClosing: Bool) -> some View {
        let distanceFromEdge = abs(distance)
        let isInside = distance < 0
        let primaryColor = isClosing ? AppColors.error : AppColors.hunterPrimary
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
            
            // Honor self-tag (for alive hiders when BLE isn't an option)
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
        .alert("Confirm tag", isPresented: $showHonorConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("I got tagged", role: .destructive) {
                gameService.honorReportTagged()
            }
        } message: {
            Text("This will remove you from the game. You can't undo this.")
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
    
    private var combinedZoneTimerCard: some View {
        Group {
            if gameService.gameState == .active,
               let bubble = gameService.session?.bubble,
               bubble.usesNewZoneSystem,
               bubble.enableShrinking,
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
                        .foregroundColor(remaining < 60 ? AppColors.hunterPrimary : AppColors.cartoonInk)
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
