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
                zoneRadius: bubbleRadius,
                mapType: $mapType,
                showPlayerLabels: $showPlayerLabels,
                zoomToBubbleTrigger: $zoomToBubbleTrigger,
                centerOnPlayerTrigger: $centerOnPlayerTrigger
            )
            .ignoresSafeArea()
            
            // Game HUD Overlay - Using absolute positioning for fixed elements
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    // Top HUD - Timer and Status (FIXED position, top-left, constrained width)
                    topHUD
                        .padding(.leading, AppSpacing.md)
                        .padding(.top, AppSpacing.md)
                        .frame(maxWidth: geometry.size.width * 0.65) // Constrain to ~65% of screen width
                        .fixedSize(horizontal: false, vertical: true)
                    
                    // Compass (middle-right) - only show when zone is small enough (later in game)
                if shouldShowCompass {
                    HStack {
                        Spacer()
                        compassView
                            .padding(.trailing, AppSpacing.md + 60) // Space for map icon
                            .padding(.top, AppSpacing.md)
                    }
                }
                
                // Map Controls (FIXED position, top-right corner, closer to edge)
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
                    .padding(.trailing, AppSpacing.sm) // Closer to right edge
                    .padding(.top, AppSpacing.md)
                }
                
                // Bottom Section - Stacked to prevent overlap
                VStack {
                    Spacer()
                    
                    VStack(spacing: AppSpacing.sm) {
                        // Bottom Panel - Zone info, Players (closer to bottom)
                        HStack(alignment: .bottom, spacing: AppSpacing.sm) {
                            // Zone Info (left side)
                            if let bubble = gameService.session?.bubble {
                                compactZoneInfoCard(bubble: bubble)
                            }
                            
                            Spacer()
                            
                            // Players Count (right side)
                            if let session = gameService.session {
                                compactPlayersCard(session: session)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Bottom Stats Panel (warnings, out of bounds, etc.) - BELOW zone info
                        bottomStatsPanel
                            .padding(.horizontal, AppSpacing.md)
                    }
                    .padding(.bottom, AppSpacing.md)
                }
                }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Note: allowsHitTesting removed - buttons need to be interactive!
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
    
    // MARK: - Top HUD
    
    private var topHUD: some View {
        HStack(spacing: AppSpacing.sm) {
            // Timer Display
            timerDisplay
            
            // Role Badge (ZombieTag: ZOMBIE or HUMAN)
            if let currentPlayer = gameService.currentPlayer, currentPlayer.isAlive {
                let roleText = currentPlayer.role == .zombie ? "ZOMBIE" : "HUMAN"
                let roleColor = currentPlayer.role == .zombie ? AppColors.zombiePrimary : AppColors.humanPrimary
                let roleGradient = AppColors.roleGradient(for: currentPlayer.role)
                
                Text(roleText)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(roleGradient)
                            .shadow(color: roleColor.opacity(0.5), radius: 4, x: 0, y: 2)
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
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private var timerDisplay: some View {
        Group {
            if let bubble = gameService.session?.bubble {
                let elapsed = currentTime.timeIntervalSince(bubble.startTime)
                let remaining = max(0, bubble.duration - elapsed)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Time Remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if remaining > 0 {
                        Text(timeString(from: remaining))
                            .font(.title2)
                            .fontWeight(.bold)
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
                            .minimumScaleFactor(0.7)
                            .scaleEffect(timerPulseScale)
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
                                        timerPulseScale = 1.05
                                    }
                                } else {
                                    withAnimation {
                                        timerPulseScale = 1.0
                                    }
                                }
                            }
                    } else {
                        Text("TIME UP")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        AppColors.zombiePrimary,
                                        AppColors.zombieSecondary
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .symbolEffect(.pulse, options: .repeating)
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
                        .font(.system(size: 8))
                        .foregroundColor(bubbleColor)
                        .symbolEffect(.pulse, isActive: zoneShrinkPulse)
                    Text("\(Int(currentRadius))m")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
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
                    .fill(AppColors.textSecondary.opacity(0.3))
                    .frame(width: 1, height: 16)
            }
            
            // Distance to Edge (only if alive)
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("\(alivePlayers.count)/\(session.players.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
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
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.zombiePrimary)
                    }
                    
                    // Humans
                    HStack(spacing: 2) {
                        Circle()
                            .fill(AppColors.humanPrimary)
                            .frame(width: 6, height: 6)
                        Text("\(humans.count)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppColors.humanPrimary)
                    }
                }
            }
            
            // Eliminated count (if any)
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
            
            // Distance Indicators
            distanceIndicators
            
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
    
    // MARK: - Infect Button
    
    private func infectButton(player: Player) -> some View {
        let buttonText = "Infect \(player.displayName)"
        let buttonColors = [AppColors.zombiePrimary, AppColors.zombieSecondary]
        let shadowColor = AppColors.zombiePrimary
        
        return Button(action: {
            gameService.requestTag(playerId: player.id)
        }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "hand.tap.fill")
                    .font(.title3)
                Text(buttonText)
                    .font(AppTypography.labelLarge())
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: buttonColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
            .shadow(color: shadowColor.opacity(0.4), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(ScaleButtonStyle())
    }
    
    // MARK: - Infection Request Alert
    
    private func infectionRequestAlert(request: BluetoothTagService.TagRequest) -> some View {
        let alertText = "\(request.fromPlayerName) wants to infect you!"
        let alertColor = AppColors.zombiePrimary
        
        return VStack(spacing: AppSpacing.sm) {
            Text(alertText)
                .font(AppTypography.labelLarge())
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            HStack(spacing: AppSpacing.md) {
                Button(action: {
                    gameService.rejectTag()
                }) {
                    Text("Reject")
                        .font(AppTypography.labelMedium())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    gameService.confirmTag(playerId: request.fromPlayerId)
                }) {
                    Text("Confirm")
                        .font(AppTypography.labelMedium())
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(alertColor)
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
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
                .font(AppTypography.bodySmall())
            Spacer()
            Text("\(Int(distance))m")
                .font(AppTypography.labelMedium())
                .fontWeight(.bold)
                .foregroundColor(proximityColor(for: distance))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(proximityColor(for: distance).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(proximityColor(for: distance), lineWidth: 2)
                )
        )
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
    
    private func playersStatusCard(session: GameSession) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Image(systemName: "person.2.fill")
                Text("Players")
                    .font(AppTypography.labelMedium())
                Spacer()
                Text("\(session.players.filter { $0.isAlive }.count)/\(session.players.count)")
                    .font(AppTypography.labelLarge())
                    .fontWeight(.bold)
            }
            
            // Show eliminated count if any
            if session.players.contains(where: { !$0.isAlive }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.error)
                        .font(.caption)
                    Text("\(session.players.filter { !$0.isAlive }.count) eliminated")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
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
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
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
        gameService.session?.bubble?.currentRadius(at: currentTime)
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
        let zombieGradient = LinearGradient(
            colors: [
                AppColors.zombiePrimary,
                AppColors.zombieSecondary
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
                .fill(type == .elimination ? zombieGradient : successGradient)
                .shadow(color: (type == .elimination ? AppColors.zombiePrimary : AppColors.success).opacity(0.5), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, AppSpacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
    }
    
    // MARK: - Compass
    
    private var shouldShowCompass: Bool {
        // Show compass when zone is small enough (less than 30% of start radius)
        // This makes it appear "later in the game" as requested
        guard let bubble = gameService.session?.bubble,
              let currentRadius = currentBubbleRadius else { return false }
        
        let shrinkRatio = currentRadius / bubble.startRadius
        return shrinkRatio < 0.3 // Show when zone is less than 30% of original size
    }
    
    private var compassView: some View {
        Group {
            if let currentPlayer = gameService.currentPlayer, currentPlayer.isAlive {
                if currentPlayer.role == .human,
                   let direction = gameService.nearestHunterDirection,
                   let distance = gameService.nearestHunterDistance {
                    CompassView(
                        direction: direction,
                        distance: distance,
                        threatType: .hunter,
                        isVisible: true
                    )
                } else if currentPlayer.role == .zombie,
                          let direction = gameService.nearestHiderDirection,
                          let distance = gameService.nearestHiderDistance {
                    CompassView(
                        direction: direction,
                        distance: distance,
                        threatType: .hider,
                        isVisible: true
                    )
                }
            }
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
    
    // MARK: - Proximity Warning Banner
    
    @State private var proximityPulseScale: CGFloat = 1.0
    
    private func proximityWarningBanner(distance: Double, level: GameService.ProximityWarningLevel) -> some View {
        let (color, icon, message) = proximityWarningContent(distance: distance, level: level)
        
        // Use ZombieTag green gradient for danger levels
        let zombieGradient = LinearGradient(
            colors: [
                AppColors.zombiePrimary,
                AppColors.zombieSecondary
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        
        let useGradient = level == .danger || level == .warning
        
        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .symbolEffect(.pulse, options: .repeating)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(AppTypography.labelLarge())
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\(Int(distance))m away")
                    .font(AppTypography.bodySmall())
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
        .background(
            ZStack {
                if useGradient {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(zombieGradient)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.2))
                }
                
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        useGradient ?
                        LinearGradient(
                            colors: [AppColors.zombiePrimary, AppColors.zombieSecondary],
                            startPoint: .leading,
                            endPoint: .trailing
                        ) :
                        LinearGradient(colors: [color], startPoint: .leading, endPoint: .trailing),
                        lineWidth: level == .danger ? 3 : 2
                    )
            }
        )
        .shadow(color: (useGradient ? AppColors.zombiePrimary : color).opacity(0.5), radius: level == .danger ? 12 : 8, x: 0, y: 4)
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
            return (.red, "exclamationmark.triangle.fill", "⚠️ ZOMBIE VERY CLOSE!")
        case .warning:
            return (.orange, "exclamationmark.circle.fill", "⚠️ Zombie Nearby")
        case .caution:
            return (.yellow, "eye.fill", "👁️ Zombie Detected")
        case .safe:
            return (.green, "checkmark.circle.fill", "✓ Safe Distance")
        case .none:
            return (.gray, "circle.fill", "")
        }
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
