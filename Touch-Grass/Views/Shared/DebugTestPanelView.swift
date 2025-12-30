//
//  DebugTestPanelView.swift
//  Touch-Grass
//
//  Debug-only test panel with organized test categories
//

import SwiftUI
import CoreLocation
import Combine

#if DEBUG
struct DebugTestPanelView: View {
    // Use the shared GameViewModel from ContentView instead of creating a new one
    @ObservedObject var viewModel: GameViewModel
    @ObservedObject private var profileService = ProfileService.shared
    @StateObject private var bluetoothService = BluetoothTagService()
    
    @State private var selectedCategory: TestCategory = .game
    @State private var showBluetoothTest = false
    @State private var showProfileTest = false
    
    enum TestCategory: String, CaseIterable {
        case game = "Game"
        case profile = "Profile"
        case bluetooth = "Bluetooth"
        case location = "Location"
        
        var icon: String {
            switch self {
            case .game: return "gamecontroller.fill"
            case .profile: return "person.fill"
            case .bluetooth: return "antenna.radiowaves.left.and.right"
            case .location: return "location.fill"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.sm) {
                        ForEach(TestCategory.allCases, id: \.self) { category in
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedCategory = category
                                }
                            }) {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: category.icon)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(category.rawValue)
                                        .font(AppTypography.labelMedium())
                                }
                                .foregroundColor(selectedCategory == category ? .white : AppColors.textPrimary)
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedCategory == category ? AppColors.grassPrimary : AppColors.backgroundSecondary)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
                .background(AppColors.backgroundPrimary)
                
                Divider()
                
                // Test Content
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        switch selectedCategory {
                        case .game:
                            gameTestsView
                        case .profile:
                            profileTestsView
                        case .bluetooth:
                            bluetoothTestsView
                        case .location:
                            locationTestsView
                        }
                    }
                    .padding(AppSpacing.md)
                }
            }
            .background(AppColors.backgroundPrimary)
            .navigationTitle("Debug Tests")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showBluetoothTest) {
            BluetoothTestView()
        }
    }
    
    // MARK: - Game Tests
    
    private var gameTestsView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Game Tests")
                .font(AppTypography.headlineLarge())
                .foregroundColor(AppColors.textPrimary)
            
            // Current Session Info
            if let session = viewModel.gameService.session {
                testCard(title: "Current Session", icon: "info.circle.fill") {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Game Type: \(session.gameType.rawValue)")
                            .font(AppTypography.bodyMedium())
                        Text("State: \(session.gameState.rawValue)")
                            .font(AppTypography.bodyMedium())
                        Text("Players: \(session.players.count)")
                            .font(AppTypography.bodyMedium())
                        Text("Join Code: \(session.joinCode)")
                            .font(AppTypography.bodyMedium())
                        if let bubble = session.bubble {
                            Text("Bubble: \(Int(bubble.startRadius))m radius")
                                .font(AppTypography.bodyMedium())
                        } else {
                            Text("Bubble: Not configured")
                                .font(AppTypography.bodyMedium())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }
            }
            
            // Session Creation Tests
            testCard(title: "Session Management", icon: "plus.circle.fill") {
                VStack(spacing: AppSpacing.md) {
                    testButton(title: "Create Manhunt Session", color: AppColors.manhuntPrimary) {
                        createTestSession(gameType: .manhunt)
                    }
                    
                    testButton(title: "Create CTF Session", color: AppColors.ctfPrimary) {
                        createTestSession(gameType: .captureTheFlag)
                    }
                    
                    testButton(title: "Create Zombie Tag Session", color: AppColors.zombiePrimary) {
                        createTestSession(gameType: .zombieTag)
                    }
                    
                    if viewModel.gameService.session != nil {
                        testButton(title: "Clear Session", color: .red) {
                            viewModel.gameService.clearSession()
                        }
                    }
                }
            }
            
            // Game State Tests
            testCard(title: "Game State", icon: "arrow.triangle.2.circlepath") {
                VStack(spacing: AppSpacing.md) {
                    if let session = viewModel.gameService.session {
                        Text("Current State: \(session.gameState.rawValue)")
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textSecondary)
                        
                        testButton(title: "Force Lobby", color: .blue) {
                            forceGameState(.lobby)
                        }
                        
                        testButton(title: "Force Active", color: .green) {
                            forceGameState(.active)
                        }
                        
                        testButton(title: "Force Ended", color: .orange) {
                            forceGameState(.ended)
                        }
                    } else {
                        Text("No active session")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            // Player Management Tests
            testCard(title: "Player Management", icon: "person.2.fill") {
                VStack(spacing: AppSpacing.md) {
                    if let session = viewModel.gameService.session {
                        Text("Players: \(session.players.count) / \(GameService.maxPlayersPerSession)")
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textSecondary)
                        
                        if session.players.count < GameService.maxPlayersPerSession {
                            testButton(title: "Add Fake Player", color: .purple) {
                                addFakePlayer()
                            }
                        } else {
                            Text("Max players reached")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        
                        if session.players.count > 1 {
                            testButton(title: "Remove Last Player", color: .red) {
                                removeLastPlayer()
                            }
                        }
                        
                        // Add multiple players at once (only show if there's room for at least 2 players)
                        let remainingSlots = GameService.maxPlayersPerSession - session.players.count
                        if remainingSlots >= 2 {
                            testButton(title: "Add \(min(5, remainingSlots)) Fake Players", color: .purple) {
                                addMultipleFakePlayers(count: min(5, remainingSlots))
                            }
                        }
                    } else {
                        Text("Create a session first")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
            
            // Bubble Tests
            testCard(title: "Bubble Configuration", icon: "circle.dashed") {
                VStack(spacing: AppSpacing.md) {
                    if let session = viewModel.gameService.session {
                        if let bubble = session.bubble {
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Radius: \(Int(bubble.startRadius))m")
                                Text("Duration: \(Int(bubble.duration))s")
                                Text("Shrink Interval: \(Int(bubble.shrinkInterval))s")
                            }
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            testButton(title: "Update Bubble", color: .cyan) {
                                updateTestBubble()
                            }
                        } else {
                            testButton(title: "Add Test Bubble", color: .cyan) {
                                addTestBubble()
                            }
                        }
                    } else {
                        Text("Create a session first")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Profile Tests
    
    private var profileTestsView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Profile Tests")
                .font(AppTypography.headlineLarge())
                .foregroundColor(AppColors.textPrimary)
            
            // Profile Info
            testCard(title: "Profile Information", icon: "person.circle.fill") {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Display Name: \(profileService.displayName.isEmpty ? "Not Set" : profileService.displayName)")
                        .font(AppTypography.bodyMedium())
                    
                    Text("Profile Picture: \(profileService.loadProfilePicture() != nil ? "Set" : "Not Set")")
                        .font(AppTypography.bodyMedium())
                    
                    Text("User ID: \(UIDevice.current.identifierForVendor?.uuidString ?? "Unknown")")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // Profile Actions
            testCard(title: "Profile Actions", icon: "slider.horizontal.3") {
                VStack(spacing: AppSpacing.md) {
                    testButton(title: "Set Test Name", color: .blue) {
                        profileService.saveProfile(name: "Test User \(Int.random(in: 1...1000))")
                    }
                    
                    testButton(title: "Clear Name", color: .red) {
                        profileService.saveProfile(name: "")
                    }
                    
                    testButton(title: "Reset Profile", color: .orange) {
                        resetProfile()
                    }
                }
            }
            
            // Stats Tests
            testCard(title: "Statistics", icon: "chart.bar.fill") {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text("Games Played: \(profileService.totalGamesPlayed)")
                        .font(AppTypography.bodyMedium())
                    
                    Text("Wins: \(profileService.totalWins)")
                        .font(AppTypography.bodyMedium())
                    
                    testButton(title: "Increment Games", color: .green) {
                        incrementGamesPlayed()
                    }
                    
                    testButton(title: "Increment Wins", color: .green) {
                        incrementWins()
                    }
                    
                    testButton(title: "Reset Stats", color: .red) {
                        resetStats()
                    }
                }
            }
        }
    }
    
    // MARK: - Bluetooth Tests
    
    private var bluetoothTestsView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Bluetooth Tests")
                .font(AppTypography.headlineLarge())
                .foregroundColor(AppColors.textPrimary)
            
            // Status
            testCard(title: "Bluetooth Status", icon: "antenna.radiowaves.left.and.right") {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Circle()
                            .fill(bluetoothService.isAdvertising ? .green : .red)
                            .frame(width: 12, height: 12)
                        Text("Advertising: \(bluetoothService.isAdvertising ? "ON" : "OFF")")
                            .font(AppTypography.bodyMedium())
                    }
                    
                    HStack {
                        Circle()
                            .fill(bluetoothService.isScanning ? .green : .red)
                            .frame(width: 12, height: 12)
                        Text("Scanning: \(bluetoothService.isScanning ? "ON" : "OFF")")
                            .font(AppTypography.bodyMedium())
                    }
                    
                    Text("Nearby Players: \(bluetoothService.nearbyPlayers.count)")
                        .font(AppTypography.bodyMedium())
                }
            }
            
            // Actions
            testCard(title: "Bluetooth Actions", icon: "power") {
                VStack(spacing: AppSpacing.md) {
                    testButton(title: "Open Full BLE Test", color: .blue) {
                        showBluetoothTest = true
                    }
                    
                    testButton(title: "Start BLE", color: .green) {
                        bluetoothService.start(playerId: UUID().uuidString, playerName: "Test Player")
                    }
                    
                    testButton(title: "Stop BLE", color: .red) {
                        bluetoothService.stop()
                    }
                }
            }
        }
    }
    
    // MARK: - Location Tests
    
    private var locationTestsView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Location Tests")
                .font(AppTypography.headlineLarge())
                .foregroundColor(AppColors.textPrimary)
            
            // Location Status
            testCard(title: "Location Status", icon: "location.fill") {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    if let coordinate = viewModel.locationService.coordinate {
                        Text("Latitude: \(coordinate.latitude, specifier: "%.6f")")
                            .font(AppTypography.bodyMedium())
                        
                        Text("Longitude: \(coordinate.longitude, specifier: "%.6f")")
                            .font(AppTypography.bodyMedium())
                    } else {
                        Text("Location not available")
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    Text("Location Service Active: \(viewModel.locationService.coordinate != nil ? "Yes" : "No")")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            
            // Location Actions
            testCard(title: "Location Actions", icon: "location.circle.fill") {
                VStack(spacing: AppSpacing.md) {
                    testButton(title: "Request Permission", color: .blue) {
                        viewModel.locationService.requestPermission()
                    }
                    
                    testButton(title: "Start Updates", color: .green) {
                        viewModel.locationService.start()
                    }
                    
                    testButton(title: "Stop Updates", color: .red) {
                        viewModel.locationService.stop()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func testCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.grassPrimary)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)
            }
            
            content()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.backgroundSecondary)
        )
    }
    
    private func testButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedbackManager.shared.selection()
            action()
        }) {
            Text(title)
                .font(AppTypography.bodyMedium())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color)
                )
        }
    }
    
    // MARK: - Test Actions
    
    private func createTestSession(gameType: GameType) {
        // Always clear existing session first to ensure clean state
        if viewModel.gameService.session != nil {
            viewModel.gameService.clearSession()
            // Wait a moment for cleanup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                createNewSession(gameType: gameType)
            }
        } else {
            createNewSession(gameType: gameType)
        }
    }
    
    private func createNewSession(gameType: GameType) {
        viewModel.selectedGameType = gameType
        viewModel.ensureServicesInitialized()
        viewModel.createSession()
    }
    
    private func addFakePlayer() {
        guard var session = viewModel.gameService.session else {
            print("⚠️ Debug: No session to add player to")
            return
        }
        
        guard session.players.count < GameService.maxPlayersPerSession else {
            print("⚠️ Debug: Max players reached (\(GameService.maxPlayersPerSession))")
            return
        }
        
                // Determine appropriate role based on game type
                // NOTE: Roles will be reassigned when game starts via beginGame()
                // - Manhunt: assignRandomHunters() will assign hunters from all players
                // - Zombie Tag: assignZombieTagRoles() will assign one zombie from all players
                // - CTF: assignCTFTeams() will balance teams
                // So initial role doesn't matter - it's just a placeholder
                let role: PlayerRole
                switch session.gameType {
                case .manhunt:
                    // Add as hider by default (will be reassigned when game starts)
                    role = .hider
                case .zombieTag:
                    // Add as human by default (will be reassigned when game starts)
                    role = .human
                case .captureTheFlag:
                    // Alternate between teams (teams may be rebalanced when game starts)
                    let teamACount = session.players.filter { $0.role == .teamA }.count
                    let teamBCount = session.players.filter { $0.role == .teamB }.count
                    role = teamACount <= teamBCount ? .teamA : .teamB
                }
        
        let baseLocation = session.players.first?.coordinate ?? viewModel.locationService.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Ensure base location is valid
        let safeLatitude = baseLocation.latitude.isFinite && baseLocation.latitude >= -90 && baseLocation.latitude <= 90 
            ? baseLocation.latitude 
            : 37.7749
        let safeLongitude = baseLocation.longitude.isFinite && baseLocation.longitude >= -180 && baseLocation.longitude <= 180
            ? baseLocation.longitude
            : -122.4194
        
        // Generate random offset within valid range
        let latOffset = Double.random(in: -0.001...0.001)
        let lonOffset = Double.random(in: -0.001...0.001)
        
        let fakePlayer = Player(
            id: UUID().uuidString, // Explicitly generate ID
            displayName: "Fake Player \(session.players.count + 1)",
            latitude: safeLatitude + latOffset,
            longitude: safeLongitude + lonOffset,
            role: role,
            isAlive: true,
            lastUpdated: Date(),
            profilePictureBase64: nil
        )
        
        // Validate the player was created correctly
        guard fakePlayer.id.isEmpty == false,
              fakePlayer.latitude.isFinite && fakePlayer.longitude.isFinite,
              fakePlayer.latitude >= -90 && fakePlayer.latitude <= 90,
              fakePlayer.longitude >= -180 && fakePlayer.longitude <= 180 else {
            print("❌ Debug: Failed to create valid fake player")
            return
        }
        
        // Add player to session
        session.players.append(fakePlayer)
        
        // Set isUpdatingSession flag to prevent listener from overwriting
        // Then update session and sync to Firestore
        Task { @MainActor in
            // Temporarily set flag (we'll use a workaround since it's private)
            let updatedSession = session
            viewModel.gameService.session = updatedSession
            
            // Manually sync to Firestore to ensure it's updated immediately
            do {
                try await viewModel.gameService.firestore.updateSession(updatedSession)
                print("✅ Debug: Added fake player \(fakePlayer.displayName) to session and Firestore")
            } catch {
                print("⚠️ Debug: Failed to sync player to Firestore: \(error)")
            }
        }
    }
    
    private func addMultipleFakePlayers(count: Int) {
        Task { @MainActor in
            guard let session = viewModel.gameService.session else {
                print("⚠️ Debug: No session to add players to")
                return
            }
            
            let maxToAdd = min(count, GameService.maxPlayersPerSession - session.players.count)
            guard maxToAdd > 0 else {
                print("⚠️ Debug: Cannot add players - max reached")
                return
            }
            
            // Add players sequentially to ensure correct numbering
            for i in 1...maxToAdd {
                // Re-fetch session to get updated player count
                guard var currentSession = viewModel.gameService.session else {
                    print("⚠️ Debug: Session disappeared while adding players")
                    break
                }
                
                guard currentSession.players.count < GameService.maxPlayersPerSession else {
                    print("⚠️ Debug: Max players reached while adding")
                    break
                }
                
                // Determine appropriate role based on game type
                // NOTE: Roles will be reassigned when game starts via beginGame()
                // - Manhunt: assignRandomHunters() will assign hunters from all players
                // - Zombie Tag: assignZombieTagRoles() will assign one zombie from all players
                // - CTF: assignCTFTeams() will balance teams
                // So initial role doesn't matter - it's just a placeholder
                let role: PlayerRole
                switch currentSession.gameType {
                case .manhunt:
                    role = .hider // Will be reassigned when game starts
                case .zombieTag:
                    role = .human // Will be reassigned when game starts
                case .captureTheFlag:
                    let teamACount = currentSession.players.filter { $0.role == .teamA }.count
                    let teamBCount = currentSession.players.filter { $0.role == .teamB }.count
                    role = teamACount <= teamBCount ? .teamA : .teamB // Teams may be rebalanced
                }
                
                let baseLocation = currentSession.players.first?.coordinate ?? viewModel.locationService.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                
                // Ensure base location is valid
                let safeLatitude = baseLocation.latitude.isFinite && baseLocation.latitude >= -90 && baseLocation.latitude <= 90 
                    ? baseLocation.latitude 
                    : 37.7749
                let safeLongitude = baseLocation.longitude.isFinite && baseLocation.longitude >= -180 && baseLocation.longitude <= 180
                    ? baseLocation.longitude
                    : -122.4194
                
                // Generate random offset within valid range
                let latOffset = Double.random(in: -0.001...0.001)
                let lonOffset = Double.random(in: -0.001...0.001)
                
                let fakePlayer = Player(
                    id: UUID().uuidString,
                    displayName: "Fake Player \(currentSession.players.count + 1)",
                    latitude: safeLatitude + latOffset,
                    longitude: safeLongitude + lonOffset,
                    role: role,
                    isAlive: true,
                    lastUpdated: Date(),
                    profilePictureBase64: nil
                )
                
                // Validate the player was created correctly
                guard fakePlayer.id.isEmpty == false,
                      fakePlayer.latitude.isFinite && fakePlayer.longitude.isFinite,
                      fakePlayer.latitude >= -90 && fakePlayer.latitude <= 90,
                      fakePlayer.longitude >= -180 && fakePlayer.longitude <= 180 else {
                    print("❌ Debug: Failed to create valid fake player \(i)")
                    continue
                }
                
                // Add player to session
                currentSession.players.append(fakePlayer)
                
                // Update session immediately
                viewModel.gameService.session = currentSession
                
                // Sync to Firestore
                do {
                    try await viewModel.gameService.firestore.updateSession(currentSession)
                    print("✅ Debug: Added fake player \(fakePlayer.displayName) to session and Firestore (\(i)/\(maxToAdd))")
                } catch {
                    print("⚠️ Debug: Failed to sync player \(i) to Firestore: \(error)")
                }
                
                // Small delay to ensure Firestore update completes before next iteration
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    private func removeLastPlayer() {
        guard var session = viewModel.gameService.session,
              !session.players.isEmpty,
              session.players.count > 1 else {
            print("⚠️ Debug: Cannot remove player - need at least 1 player (host)")
            return
        }
        
        let removedPlayer = session.players.removeLast()
        
        // Update session and sync to Firestore
        Task { @MainActor in
            viewModel.gameService.session = session
            
            // Manually sync to Firestore to ensure it's updated immediately
            do {
                try await viewModel.gameService.firestore.updateSession(session)
                print("✅ Debug: Removed player \(removedPlayer.displayName) from session and Firestore")
            } catch {
                print("⚠️ Debug: Failed to sync player removal to Firestore: \(error)")
            }
        }
    }
    
    private func addTestBubble() {
        guard let session = viewModel.gameService.session else {
            print("⚠️ Debug: No session to add bubble to")
            return
        }
        
        let center = viewModel.locationService.coordinate ?? session.players.first?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        let bubble = Bubble(
            centerLatitude: center.latitude,
            centerLongitude: center.longitude,
            startRadius: 500.0,
            startTime: Date(),
            shrinkInterval: 180.0,
            duration: 1800.0
        )
        
        // Use GameService's configureGame method to properly set bubble and sync to Firestore
        viewModel.gameService.configureGame(bubble: bubble, hunterCount: session.hunterCount)
        
        print("✅ Debug: Added test bubble to session")
    }
    
    private func updateTestBubble() {
        guard let session = viewModel.gameService.session,
              var bubble = session.bubble else {
            print("⚠️ Debug: No bubble to update")
            return
        }
        
        let center = viewModel.locationService.coordinate ?? session.players.first?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        
        // Validate coordinates before updating
        guard center.latitude.isFinite && center.longitude.isFinite,
              center.latitude >= -90 && center.latitude <= 90,
              center.longitude >= -180 && center.longitude <= 180 else {
            print("❌ Debug: Invalid coordinates for bubble update")
            return
        }
        
        bubble.centerLatitude = center.latitude
        bubble.centerLongitude = center.longitude
        
        // Use GameService's configureGame method to properly update bubble and sync to Firestore
        viewModel.gameService.configureGame(bubble: bubble, hunterCount: session.hunterCount)
        
        print("✅ Debug: Updated bubble center to (\(center.latitude), \(center.longitude))")
    }
    
    // MARK: - Helper Functions
    
    private func forceGameState(_ state: GameState) {
        guard var session = viewModel.gameService.session else {
            print("⚠️ Debug: No session to update state")
            return
        }
        
        // Update both gameState and session.gameState
        viewModel.gameService.gameState = state
        session.gameState = state
        viewModel.gameService.session = session
        
        // Sync to Firestore
        Task { @MainActor in
            do {
                try await viewModel.gameService.firestore.updateSession(session)
                print("✅ Debug: Forced game state to \(state.rawValue) and synced to Firestore")
            } catch {
                print("⚠️ Debug: Failed to sync game state to Firestore: \(error)")
            }
        }
    }
    
    private func resetProfile() {
        // Clear profile name
        profileService.saveProfile(name: "")
        
        // Clear profile picture by removing the file
        if let fileName = UserDefaults.standard.string(forKey: "userProfilePictureFileName") {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: fileURL)
            UserDefaults.standard.removeObject(forKey: "userProfilePictureFileName")
        }
        
        print("✅ Debug: Reset profile (name and picture)")
    }
    
    private func incrementGamesPlayed() {
        let current = profileService.totalGamesPlayed
        UserDefaults.standard.set(current + 1, forKey: "totalGamesPlayed")
        // Force UI update by triggering objectWillChange
        profileService.objectWillChange.send()
        print("✅ Debug: Incremented games played to \(current + 1)")
    }
    
    private func incrementWins() {
        let current = profileService.totalWins
        UserDefaults.standard.set(current + 1, forKey: "totalWins")
        // Force UI update by triggering objectWillChange
        profileService.objectWillChange.send()
        print("✅ Debug: Incremented wins to \(current + 1)")
    }
    
    private func resetStats() {
        UserDefaults.standard.set(0, forKey: "totalGamesPlayed")
        UserDefaults.standard.set(0, forKey: "totalWins")
        // Force UI update by triggering objectWillChange
        profileService.objectWillChange.send()
        print("✅ Debug: Reset all statistics")
    }
}
#endif
