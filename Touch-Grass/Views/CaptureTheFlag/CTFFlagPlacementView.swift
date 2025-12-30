//
//  CTFFlagPlacementView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import CoreLocation
import MapKit

struct CTFFlagPlacementView: View {
    @ObservedObject var gameService: GameService
    @ObservedObject var locationService: LocationService
    
    @State private var countdownNumber: Int? = nil
    @State private var showCountdown: Bool = false
    @State private var countdownColor: Color = .blue
    @State private var hasStartedCountdown: Bool = false
    
    // Safe zone placement states
    @State private var showSafeZonePlacement: Bool = false
    @State private var safeZoneRadius: Double = 15.0 // Default ~15 meters around flag
    @State private var safeZoneCenter: CLLocationCoordinate2D? = nil
    @State private var mapType: MKMapType = .standard
    @State private var flagPlacedButNotConfirmed: Bool = false // Track if flag is placed but safe zone not confirmed
    @State private var countdownSeconds: Int = 60 // 1 minute countdown
    
    var body: some View {
        ZStack {
            // Background
            AppColors.backgroundPrimary
                .ignoresSafeArea()
            
            if let session = gameService.session,
               let currentPlayer = gameService.currentPlayer {
                
                // Check if both flags are placed
                let bothFlagsPlaced = session.teamAFlagPlaced && session.teamBFlagPlaced
                let isFlagPlayer = currentPlayer.isFlag
                let isTeamLeader = currentPlayer.isTeamLeader
                let playerTeam = currentPlayer.team
                let teamSafeZone = playerTeam == .teamA ? session.teamASafeZone : session.teamBSafeZone
                
                if showCountdown {
                    // Countdown animation (only on non-flag devices)
                    if !isFlagPlayer {
                    countdownView
                    } else {
                        // Flag players see waiting view during countdown
                        flagPlayerWaitingView(session: session, player: currentPlayer, team: playerTeam)
                    }
                } else if bothFlagsPlaced && !hasStartedCountdown {
                    // Check if safe zones need to be placed
                    let teamASafeZonePlaced = session.teamASafeZone != nil
                    let teamBSafeZonePlaced = session.teamBSafeZone != nil
                    let bothSafeZonesPlaced = teamASafeZonePlaced && teamBSafeZonePlaced
                    
                    // Check if this flag player has placed flag but not confirmed safe zone
                    let teamFlagPlaced = playerTeam == .teamA ? session.teamAFlagPlaced : session.teamBFlagPlaced
                    let needsSafeZoneConfirmation = isFlagPlayer && isTeamLeader && teamFlagPlaced && teamSafeZone == nil
                    
                    if needsSafeZoneConfirmation {
                        // Flag player (who is also team leader) needs to confirm safe zone
                        safeZoneConfirmationView(session: session, player: currentPlayer, team: playerTeam)
                    } else if !bothSafeZonesPlaced && !isFlagPlayer && isTeamLeader && teamSafeZone == nil {
                        // Team leader (non-flag) needs to place safe zone
                        safeZonePlacementView(session: session, player: currentPlayer, team: playerTeam)
                    } else if !bothSafeZonesPlaced {
                        // Waiting for safe zones to be placed
                        waitingForSafeZonesView(session: session)
                    } else {
                        // Both flags and safe zones placed - show countdown (only on non-flag devices)
                    Color.clear
                        .onAppear {
                            hasStartedCountdown = true
                            startCountdown()
                            }
                        }
                } else if isFlagPlayer {
                    // Flag player view - check if flag is already placed
                    let teamFlagPlaced = playerTeam == .teamA ? session.teamAFlagPlaced : session.teamBFlagPlaced
                    if teamFlagPlaced {
                        // Flag is placed, show "Flag Placed" button to proceed to safe zone
                        flagPlacedView(session: session, player: currentPlayer, team: playerTeam)
                    } else {
                        // Flag not yet placed
                    flagPlayerView(session: session, player: currentPlayer, team: playerTeam)
                    }
                } else {
                    // Waiting view for non-flag players
                    waitingView(session: session)
                }
            } else {
                // No session or current player - show error state
                VStack(spacing: AppSpacing.lg) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Unable to Load Game")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(AppColors.textPrimary)
                    
                    Text("Please return to the lobby")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Flag Player View
    
    private func flagPlayerView(session: GameSession, player: Player, team: Flag.Team?) -> some View {
        let teamColor = team == .teamA ? Color.blue : Color.red
        let teamName = team == .teamA ? "Team A (Blue)" : "Team B (Red)"
        
        return VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Large flag icon
            Image(systemName: "flag.fill")
                .font(.system(size: 120, weight: .bold))
                .foregroundColor(teamColor)
                .shadow(color: teamColor.opacity(0.5), radius: 20, x: 0, y: 10)
            
            // Main message
            VStack(spacing: AppSpacing.md) {
                Text("Place This Team Flag!")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(teamColor)
                    .multilineTextAlignment(.center)
                
                Text(teamName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                
                Text("Move to your desired location and tap the button below to place your flag")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
                
                // Show location status
                if locationService.coordinate == nil {
                    Text("Waiting for location...")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary.opacity(0.7))
                        .padding(.top, AppSpacing.sm)
                }
            }
            
            Spacer()
            
            // Place Flag Button
            Button(action: {
                HapticFeedbackManager.shared.selection()
                confirmFlagPlacement()
            }) {
                Text("Place Flag Here")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        LinearGradient(
                            colors: [teamColor, teamColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: teamColor.opacity(0.5), radius: 15, x: 0, y: 8)
            }
            .disabled(locationService.coordinate == nil)
            .opacity(locationService.coordinate == nil ? 0.6 : 1.0)
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - Flag Placed View (shows "Flag Placed" button)
    
    private func flagPlacedView(session: GameSession, player: Player, team: Flag.Team?) -> some View {
        let teamColor = team == .teamA ? Color.blue : Color.red
        let teamName = team == .teamA ? "Team A (Blue)" : "Team B (Red)"
        
        return VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Checkmark icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 120, weight: .bold))
                .foregroundColor(teamColor)
                .shadow(color: teamColor.opacity(0.5), radius: 20, x: 0, y: 10)
            
            // Main message
            VStack(spacing: AppSpacing.md) {
                Text("Flag Placed!")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(teamColor)
                    .multilineTextAlignment(.center)
                
                Text(teamName)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
                
                Text("Ready to set up safe zone")
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)
            }
            
            Spacer()
            
            // Flag Placed Button - proceeds to safe zone placement
            Button(action: {
                HapticFeedbackManager.shared.selection()
                // This will trigger safe zone confirmation view
                flagPlacedButNotConfirmed = true
            }) {
                Text("Flag Placed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.lg)
                    .background(
                        LinearGradient(
                            colors: [teamColor, teamColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(20)
                    .shadow(color: teamColor.opacity(0.5), radius: 15, x: 0, y: 8)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    // MARK: - Flag Player Waiting View (during countdown)
    
    private func flagPlayerWaitingView(session: GameSession, player: Player, team: Flag.Team?) -> some View {
        let teamColor = team == .teamA ? Color.blue : Color.red
        let _ = team == .teamA ? "Team A (Blue)" : "Team B (Red)" // Team name (for future use)
        
        return VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            Image(systemName: "hourglass")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(teamColor)
                .symbolEffect(.pulse, isActive: true)
            
            Text("Game Starting Soon")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(teamColor)
            
            Text("Waiting for countdown to finish...")
                .font(.system(size: 20))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            Spacer()
        }
    }
    
    // MARK: - Waiting View
    
    private func waitingView(session: GameSession) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Waiting icon
            Image(systemName: "hourglass")
                .font(.system(size: 80, weight: .light))
                .foregroundColor(AppColors.textSecondary)
                .symbolEffect(.pulse, isActive: true)
            
            // Main message
            VStack(spacing: AppSpacing.md) {
                Text("Waiting for Teams to Place Flags")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Flag players are choosing their starting positions")
                    .font(.system(size: 18))
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.xl)
            
            Spacer()
            
            // Team status checkboxes
            VStack(spacing: AppSpacing.lg) {
                teamStatusRow(
                    teamName: "Team A (Blue)",
                    isPlaced: session.teamAFlagPlaced,
                    color: .blue
                )
                
                teamStatusRow(
                    teamName: "Team B (Red)",
                    isPlaced: session.teamBFlagPlaced,
                    color: .red
                )
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.xl)
        }
    }
    
    private func teamStatusRow(teamName: String, isPlaced: Bool, color: Color) -> some View {
        HStack(spacing: AppSpacing.md) {
            // Checkbox
            ZStack {
                Circle()
                    .fill(isPlaced ? color : Color.clear)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Circle()
                            .stroke(color, lineWidth: 3)
                    )
                
                if isPlaced {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            Text(teamName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isPlaced ? color : AppColors.textSecondary)
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isPlaced ? color.opacity(0.1) : AppColors.backgroundSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isPlaced ? color.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
        .animation(.spring(response: 0.3), value: isPlaced)
    }
    
    // MARK: - Safe Zone Confirmation View (for flag players who are team leaders)
    
    private func safeZoneConfirmationView(session: GameSession, player: Player, team: Flag.Team?) -> some View {
        let teamColor = team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB
        let teamName = team == .teamA ? "Team A" : "Team B"
        
        // Get flag player location for this team
        let flagPlayer = session.players.first { $0.isFlag && $0.team == team }
        let flagLocation = flagPlayer?.coordinate ?? locationService.coordinate
        
        // Create preview safe zone to show on map
        let previewSafeZone = flagLocation.map { location in
            GameSession.SafeZone(center: location, radius: safeZoneRadius)
        }
        
        return ZStack {
            // Map view showing flag location and safe zone preview
            if flagLocation != nil {
                MapViewRepresentable(
                    userCoordinate: locationService.coordinate,
                    bubbleCenter: session.bubble?.center,
                    bubbleRadius: session.bubble?.startRadius,
                    warningLevel: .none,
                    players: [], // Don't show flag players during placement
                    currentPlayerId: player.id,
                    currentPlayerRole: player.role,
                    gameType: .captureTheFlag,
                    flags: [],
                    teamABase: session.teamABase,
                    teamBBase: session.teamBBase,
                    teamASafeZone: team == .teamA ? previewSafeZone : nil, // Show preview safe zone
                    teamBSafeZone: team == .teamB ? previewSafeZone : nil, // Show preview safe zone
                    isPingActive: false,
                    zoneRadius: session.bubble?.startRadius,
                    mapType: $mapType,
                    showPlayerLabels: .constant(true),
                    zoomToBubbleTrigger: .constant(false),
                    centerOnPlayerTrigger: .constant(false)
                )
                .ignoresSafeArea()
            }
            
            // UI Overlay
            VStack(spacing: AppSpacing.lg) {
                // Top header
                VStack(spacing: AppSpacing.sm) {
                    Text("This is the Flag")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(teamColor)
                    
                    Text("and the Safe Zone")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(teamColor)
                    
                    Text(teamName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Safe zone: ~\(Int(safeZoneRadius))m around flag")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
                .padding(.top, AppSpacing.xl)
                .padding(.horizontal, AppSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.backgroundPrimary.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                
                Spacer()
                
                // Bottom button
                VStack(spacing: AppSpacing.md) {
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        confirmSafeZonePlacement(aroundFlag: flagLocation)
                    }) {
                        Text("Proceed")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [teamColor, teamColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: teamColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(flagLocation == nil)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.backgroundPrimary.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
                )
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            }
        }
    }
    
    // MARK: - Safe Zone Placement View
    
    private func safeZonePlacementView(session: GameSession, player: Player, team: Flag.Team?) -> some View {
        let teamColor = team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB
        let teamName = team == .teamA ? "Team A" : "Team B"
        
        // Get flag player location for this team
        let flagPlayer = session.players.first { $0.isFlag && $0.team == team }
        let flagLocation = flagPlayer?.coordinate ?? locationService.coordinate
        
        // Create preview safe zone to show on map
        let previewSafeZone = flagLocation.map { location in
            GameSession.SafeZone(center: location, radius: safeZoneRadius)
        }
        
        return ZStack {
            // Map view showing flag location and safe zone preview
            if flagLocation != nil {
                MapViewRepresentable(
                    userCoordinate: locationService.coordinate,
                    bubbleCenter: session.bubble?.center,
                    bubbleRadius: session.bubble?.startRadius,
                    warningLevel: .none,
                    players: flagPlayer != nil ? [flagPlayer!] : [],
                    currentPlayerId: player.id,
                    currentPlayerRole: player.role,
                    gameType: .captureTheFlag,
                    flags: [],
                    teamABase: session.teamABase,
                    teamBBase: session.teamBBase,
                    teamASafeZone: team == .teamA ? previewSafeZone : nil, // Show preview safe zone
                    teamBSafeZone: team == .teamB ? previewSafeZone : nil, // Show preview safe zone
                    isPingActive: false,
                    zoneRadius: session.bubble?.startRadius,
                    mapType: $mapType,
                    showPlayerLabels: .constant(true),
                    zoomToBubbleTrigger: .constant(false),
                    centerOnPlayerTrigger: .constant(false)
                )
                .ignoresSafeArea()
            }
            
            // UI Overlay
            VStack(spacing: AppSpacing.lg) {
                // Top header
                VStack(spacing: AppSpacing.sm) {
                    Text("Place Safe Zone")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(teamColor)
                    
                    Text(teamName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(AppColors.textSecondary)
                    
                    Text("Safe zone will be ~\(Int(safeZoneRadius))m around your flag")
                        .font(.system(size: 16))
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
                .padding(.top, AppSpacing.xl)
                .padding(.horizontal, AppSpacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.backgroundPrimary.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
                )
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.md)
                
                Spacer()
                
                // Bottom button
                VStack(spacing: AppSpacing.md) {
                    // Radius info
                    Text("Radius: \(Int(safeZoneRadius))m")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(teamColor)
                    
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        confirmSafeZonePlacement(aroundFlag: flagLocation)
                    }) {
                        Text("Place Safe Zone Around Flag")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [teamColor, teamColor.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(16)
                            .shadow(color: teamColor.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .disabled(flagLocation == nil)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppColors.backgroundPrimary.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -5)
                )
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.md)
            }
        }
    }
    
    
    // MARK: - Waiting for Safe Zones View
    
    private func waitingForSafeZonesView(session: GameSession) -> some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            
            // Waiting icon
            Image(systemName: "hourglass")
                .font(.system(size: 80))
                .foregroundColor(AppColors.textSecondary)
                .symbolEffect(.pulse, isActive: true)
            
            Text("Waiting for Safe Zones")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(AppColors.textPrimary)
            
            Text("Team leaders are placing safe zones...")
                .font(.system(size: 20))
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            
            // Status rows
            VStack(spacing: AppSpacing.md) {
                teamStatusRow(
                    teamName: "Team A Safe Zone",
                    isPlaced: session.teamASafeZone != nil,
                    color: AppColors.ctfTeamA
                )
                teamStatusRow(
                    teamName: "Team B Safe Zone",
                    isPlaced: session.teamBSafeZone != nil,
                    color: AppColors.ctfTeamB
                )
            }
            .padding(.horizontal, AppSpacing.xl)
            
            Spacer()
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.xl)
    }
    
    // MARK: - Countdown View (1 minute countdown, only on non-flag devices)
    
    private var countdownView: some View {
        ZStack {
            // Color wash background - animated
            countdownColor
                .ignoresSafeArea()
                .opacity(0.4)
                .animation(.easeInOut(duration: 0.5), value: countdownColor)
            
            VStack(spacing: AppSpacing.xl) {
                Text("Game Starting In")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(countdownColor)
                    .opacity(0.9)
                
                // Show countdown in MM:SS format
                Text(formatCountdown(countdownSeconds))
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                        .foregroundColor(countdownColor)
                        .shadow(color: countdownColor.opacity(0.5), radius: 20, x: 0, y: 10)
                    .monospacedDigit()
            }
        }
    }
    
    private func formatCountdown(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    // MARK: - Functions
    
    private func confirmSafeZonePlacement(aroundFlag flagLocation: CLLocationCoordinate2D?) {
        guard let currentPlayer = gameService.currentPlayer,
              let playerTeam = currentPlayer.team,
              currentPlayer.isTeamLeader else {
            print("⚠️ Cannot place safe zone: Missing requirements")
            return
        }
        
        // Use flag location if provided, otherwise use current location
        let safeZoneCenter: CLLocationCoordinate2D
        if let flagLoc = flagLocation {
            safeZoneCenter = flagLoc
        } else if let currentLoc = locationService.coordinate {
            safeZoneCenter = currentLoc
        } else {
            print("⚠️ Cannot place safe zone: No location available")
            return
        }
        
        // Validate coordinate
        guard safeZoneCenter.latitude >= -90 && safeZoneCenter.latitude <= 90,
              safeZoneCenter.longitude >= -180 && safeZoneCenter.longitude <= 180,
              safeZoneCenter.latitude.isFinite && safeZoneCenter.longitude.isFinite else {
            print("⚠️ Cannot place safe zone: Invalid coordinate values")
            return
        }
        
        // Use GameService method which includes validation
        // Default radius is ~15 meters around the flag
        gameService.placeSafeZone(team: playerTeam, center: safeZoneCenter, radius: safeZoneRadius)
    }
    
    private func confirmFlagPlacement() {
        guard var session = gameService.session,
              let currentPlayer = gameService.currentPlayer,
              let playerTeam = currentPlayer.team,
              currentPlayer.isFlag else {
            return
        }
        
        // Update flag placement status
        if playerTeam == .teamA {
            session.teamAFlagPlaced = true
        } else if playerTeam == .teamB {
            session.teamBFlagPlaced = true
        }
        
        // Update flag player's location to current location
        // Validate location before updating
        guard let currentLocation = locationService.coordinate else {
            print("⚠️ Cannot place flag: Location not available")
            return
        }
        
        // Validate coordinate is within reasonable bounds
        guard currentLocation.latitude >= -90 && currentLocation.latitude <= 90,
              currentLocation.longitude >= -180 && currentLocation.longitude <= 180,
              currentLocation.latitude.isFinite && currentLocation.longitude.isFinite else {
            print("⚠️ Cannot place flag: Invalid coordinate values")
            return
        }
        
        // Update player location
        if let playerIndex = session.players.firstIndex(where: { $0.id == currentPlayer.id }) {
            session.players[playerIndex].latitude = currentLocation.latitude
            session.players[playerIndex].longitude = currentLocation.longitude
        }
        
        // CRASH FIX: Ensure state modification happens on MainActor
        Task { @MainActor in
            gameService.session = session
            
            // Sync to Firestore
            Task {
                do {
                    if let session = gameService.session {
                        try await gameService.firestore.updateSession(session)
                    }
                } catch {
                    print("❌ Error syncing flag placement: \(error)")
                }
            }
        }
    }
    
    private func startCountdown() {
        guard let session = gameService.session,
              session.gameState == .flagPlacement,
              session.teamAFlagPlaced && session.teamBFlagPlaced,
              session.teamASafeZone != nil && session.teamBSafeZone != nil else {
            return
        }
        
        // Prevent multiple countdowns
        guard !hasStartedCountdown else { return }
        
        // Start with blue (Team A color)
        countdownColor = .blue
        countdownSeconds = 60 // 1 minute
        
        // Show countdown view with color wash
        withAnimation(.easeInOut(duration: 0.5)) {
            showCountdown = true
        }
        
        // Start 1 minute countdown
        var remainingSeconds = 60
        countdownSeconds = remainingSeconds
        HapticFeedbackManager.shared.selection()
        
        // Update countdown every second
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remainingSeconds -= 1
            countdownSeconds = remainingSeconds
            
            // Haptic feedback at key moments
            if remainingSeconds == 30 || remainingSeconds == 10 || remainingSeconds <= 5 {
                Task { @MainActor in
            HapticFeedbackManager.shared.selection()
                }
        }
        
            // Alternate colors
            withAnimation(.easeInOut(duration: 0.5)) {
                countdownColor = remainingSeconds % 2 == 0 ? .blue : .red
            }
            
            // When countdown reaches 0, start the game
            if remainingSeconds <= 0 {
                timer.invalidate()
                Task { @MainActor in
            HapticFeedbackManager.shared.playerCaught()
        }
        
            // Transition to active game
            Task { @MainActor in
                guard var session = gameService.session,
                      session.gameState == .flagPlacement else {
                    print("⚠️ Cannot start game: Session state changed during countdown")
                    return
                }
                
                // Verify both flags and safe zones are placed
                guard session.teamAFlagPlaced && session.teamBFlagPlaced,
                      session.teamASafeZone != nil && session.teamBSafeZone != nil else {
                    print("⚠️ Cannot start game: Flags or safe zones not fully placed")
                    return
                }
                
                // CRASH FIX: State modifications are already on MainActor via outer Task
                session.gameState = .active
                gameService.session = session
                gameService.gameState = .active
                
                // Sync to Firestore
                Task {
                    do {
                        if let session = gameService.session {
                            try await gameService.firestore.updateSession(session)
                        }
                    } catch {
                        print("❌ Error syncing game start: \(error)")
                    }
                }
            }
            }
        }
        
        // Store timer reference (would need to add @State for timer if we want to cancel it)
        RunLoop.current.add(timer, forMode: .common)
    }
}


