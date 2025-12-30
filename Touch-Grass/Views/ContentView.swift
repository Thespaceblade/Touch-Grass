import SwiftUI
import MapKit
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    @ObservedObject private var profileService = ProfileService.shared
    
    @State private var selectedGame: GameType? = nil
    @State private var selectedTab: Int = 0
    #if DEBUG
    @State private var showDebugTestPanel = false
    #endif
    
    var body: some View {
            Group {
            if shouldShowTabBar {
                // Standard Apple TabView with green styling (only visible on home screen)
                TabView(selection: $selectedTab) {
                    gameContentView
                        .tabItem {
                            Label("Game", systemImage: "gamecontroller.fill")
                        }
                        .tag(0)
                    
                    // Profile tab - always render to ensure tab appears in tab bar
                    // PERFORMANCE: ProfileView uses lazy loading internally if needed
                    ProfileView()
                        .id("profile") // Cache profile view identity
                        .tabItem {
                            Label("Profile", systemImage: "person.fill")
                        }
                        .tag(1)
                        #if DEBUG
                        .overlay(alignment: .topTrailing) {
                            // Debug test panel button in top right
                            Button(action: {
                                HapticFeedbackManager.shared.selection()
                                showDebugTestPanel = true
                            }) {
                                Image(systemName: "testtube.2")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(AppColors.grassPrimary)
                                            .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                                    )
                            }
                            .padding(.top, 8)
                            .padding(.trailing, 16)
                        }
                        #endif
                }
                #if DEBUG
                .sheet(isPresented: $showDebugTestPanel) {
                    DebugTestPanelView(viewModel: viewModel)
                }
                #endif
                .onAppear {
                    // Style the TabView to be green
                    let appearance = UITabBarAppearance()
                    appearance.configureWithOpaqueBackground()
                    appearance.backgroundColor = UIColor(AppColors.backgroundPrimary)
                    
                    // Set selected tab color to green
                    appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.grassPrimary)
                    appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(AppColors.grassPrimary)]
                    
                    // Set unselected tab color
                    appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
                    appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(AppColors.textSecondary)]
                    
                    UITabBar.appearance().standardAppearance = appearance
                    UITabBar.appearance().scrollEdgeAppearance = appearance
                    
                    // Update profile tab icon with profile picture if available
                    updateProfileTabIcon()
                }
                .onChange(of: selectedTab) { _, newTab in
                    // PERFORMANCE: Only update icon when switching to profile tab
                    if newTab == 1 {
                        updateProfileTabIcon()
                    }
                }
                .onChange(of: profileService.displayName) { _, _ in
                    // Update tab icon when profile changes (only if profile tab is visible)
                    if selectedTab == 1 {
                        updateProfileTabIcon()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ProfilePictureUpdated"))) { _ in
                    // Update tab icon when profile picture is updated (only if profile tab is visible)
                    if selectedTab == 1 {
                        updateProfileTabIcon()
                    }
                }
                .preferredColorScheme(themeManager.colorScheme)
            } else {
                // No tab bar - just show game content (lobby, active game, etc.)
                // When a game is selected, always show game content
                gameContentView
                    .preferredColorScheme(themeManager.colorScheme)
            }
        }
        .onAppear {
            // Ensure services are initialized if game is already selected (e.g., app restored)
            if selectedGame != nil {
                viewModel.ensureServicesInitialized()
            }
        }
        .onChange(of: selectedGame) { oldValue, newValue in
            // Initialize services when game is selected (before view body accesses them)
            if newValue != nil {
                viewModel.ensureServicesInitialized()
                
                // If switching between game modes (oldValue != nil and different from newValue),
                // completely clear the previous session to ensure isolation
                if let oldGameType = oldValue, oldGameType != newValue {
                    print("🔄 Switching game modes: \(oldGameType.rawValue) -> \(newValue!.rawValue)")
                    // Completely clear the previous game mode's session
                    viewModel.gameService.clearSession()
                }
                
                // If coming from main screen (oldValue was nil), reset gameState to lobby
                // This prevents game over screen from showing when entering a game
                if oldValue == nil {
                    let gameService = viewModel.gameService
                    if gameService.gameState == .ended {
                        // Reset game state to lobby when coming from main screen
                        if var session = gameService.session {
                            session.gameState = .lobby
                            gameService.session = session
                        }
                        gameService.gameState = .lobby
                    }
                }
            } else {
                // Returning to home screen - clear any existing session
                if oldValue != nil {
                    print("🏠 Returning to home screen - clearing session")
                    viewModel.gameService.clearSession()
                }
                // Reset to game tab when returning to home screen
                selectedTab = 0
            }
            #if DEBUG
            DebugLogger.log("🔄 ContentView: selectedGame changed from \(oldValue?.rawValue ?? "nil") to \(newValue?.rawValue ?? "nil")")
            #endif
        }
    }
    
    // MARK: - Tab Bar Visibility
    
    private var shouldShowTabBar: Bool {
        // Only show tab bar on the main home screen (game selection screen)
        // Hide it on all other screens (lobby, active game, end screens)
        // Users can switch between Game and Profile tabs on the home screen
        // Once they leave the home screen, they use back arrows to navigate
        return selectedGame == nil
    }
    
    @ViewBuilder
    private var gameContentView: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()
                .allowsHitTesting(false) // CRASH FIX: Don't block touches - background shouldn't intercept
            
            // PERFORMANCE: Optimized routing - only access services when game is selected
            if selectedGame == nil {
                // Game Selection Menu - no services needed yet
                GameSelectionView { gameType in
                    // PERFORMANCE: No animation for game selection - instant transition for better responsiveness
                    selectedGame = gameType
                }
                .transition(.opacity) // PERFORMANCE: Simple fade transition
                #if DEBUG
                .debugButton(showDebugTestPanel: $showDebugTestPanel, viewModel: viewModel)
                #endif
            } else {
                // Game is selected - ensure services are initialized
                // Accessing gameService will trigger lazy initialization if needed
                let gameService = viewModel.gameService
                let gameState = gameService.gameState
                
                if gameState == .ended {
                // Game End Screen - route to game-specific view
                    if let session = gameService.session,
                       let stats = gameService.gameStats {
                    switch selectedGame {
                    case .zombieTag:
                        ZombieTagGameEndView(
                            session: session,
                            gameStats: stats,
                            currentPlayer: gameService.currentPlayer,
                            onPlayAgain: {
                                viewModel.playAgain()
                            },
                            onBackToLobby: {
                                // Reset game state to lobby so we don't return to game end screen
                                let gameService = viewModel.gameService
                                if var session = gameService.session {
                                    session.gameState = .lobby
                                    gameService.session = session
                                }
                                gameService.gameState = .lobby
                                // PERFORMANCE: No animation for faster navigation
                                selectedGame = nil
                            }
                        )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    case .captureTheFlag:
                        CTFGameEndView(
                            session: session,
                            gameStats: stats,
                            currentPlayer: gameService.currentPlayer,
                            onPlayAgain: {
                                viewModel.playAgain()
                            },
                            onBackToLobby: {
                                // Reset game state to lobby so we don't return to game end screen
                                let gameService = viewModel.gameService
                                if var session = gameService.session {
                                    session.gameState = .lobby
                                    gameService.session = session
                                }
                                gameService.gameState = .lobby
                                // PERFORMANCE: No animation for faster navigation
                                selectedGame = nil
                            }
                        )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    case .manhunt, .none:
                        ManhuntGameEndView(
                            session: session,
                            gameStats: stats,
                            currentPlayer: gameService.currentPlayer,
                            onPlayAgain: {
                                viewModel.playAgain()
                            },
                            onBackToLobby: {
                                // Reset game state to lobby so we don't return to game end screen
                                let gameService = viewModel.gameService
                                if var session = gameService.session {
                                    session.gameState = .lobby
                                    gameService.session = session
                                }
                                gameService.gameState = .lobby
                                // PERFORMANCE: No animation for faster navigation
                                selectedGame = nil
                            }
                        )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    }
                } else {
                    // Fallback: If game ended but no session/stats, go back to lobby
                    switch selectedGame {
                    case .zombieTag:
                        ZombieTagLobbyView(
                            viewModel: viewModel,
                            onBackToMenu: {
                                // PERFORMANCE: No animation for faster navigation
                                selectedGame = nil
                                viewModel.gameService.endGame()
                            }
                        )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    case .captureTheFlag:
                        CTFLobbyView(
                            viewModel: viewModel,
                            onBackToMenu: {
                                // PERFORMANCE: No animation for faster navigation
                                selectedGame = nil
                                viewModel.gameService.endGame()
                            }
                        )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    case .manhunt, .none:
                        ManhuntLobbyView(
                            viewModel: viewModel,
                            onBackToMenu: {
                                // PERFORMANCE: No animation for faster navigation
                                selectedGame = nil
                                viewModel.gameService.endGame()
                            }
                        )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    }
                }
            } else if let currentPlayer = gameService.currentPlayer,
                      !currentPlayer.isAlive,
                          gameState == .active {
                // Spectator Mode (player eliminated but game still active)
                SpectatorView(
                    gameService: gameService,
                    locationService: viewModel.locationService
                )
                    .transition(.opacity) // PERFORMANCE: Simpler transition
                    } else if gameState == .flagPlacement {
                        // CTF Flag Placement Screen
                        if let session = gameService.session,
                           session.gameType == .captureTheFlag {
                            CTFFlagPlacementView(
                                gameService: gameService,
                                locationService: viewModel.locationService
                            )
                            .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                        } else {
                            // Fallback - shouldn't happen
                            EmptyView()
                        }
                    } else if gameState == .active {
                // Full-screen active game - route to game-specific view
                // Determine game type from session if selectedGame is nil
                let gameType = selectedGame ?? gameService.session?.gameType ?? .manhunt
                
                switch gameType {
                case .zombieTag:
                    ZombieTagActiveGameView(
                        gameService: gameService,
                            locationService: viewModel.locationService,
                            viewModel: viewModel
                    )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    .onAppear {
                        if selectedGame == nil {
                            selectedGame = .zombieTag
                        }
                    }
                case .captureTheFlag:
                    CTFActiveGameView(
                        gameService: gameService,
                        locationService: viewModel.locationService
                    )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    .onAppear {
                        if selectedGame == nil {
                            selectedGame = .captureTheFlag
                        }
                    }
                case .manhunt:
                    ManhuntActiveGameView(
                        gameService: gameService,
                            locationService: viewModel.locationService,
                            viewModel: viewModel
                    )
                        .transition(.opacity) // PERFORMANCE: Simpler transition for better performance
                    .onAppear {
                        if selectedGame == nil {
                            selectedGame = .manhunt
                        }
                    }
                }
            } else {
                // Lobby/Menu screen for selected game - route to game-specific view
                switch selectedGame {
                case .zombieTag:
                    ZombieTagLobbyView(
                        viewModel: viewModel,
                        onBackToMenu: {
                            // PERFORMANCE: No animation for faster navigation
                            selectedGame = nil
                            gameService.endGame()
                        }
                    )
                    .transition(.opacity) // PERFORMANCE: Simpler transition
                    // PERFORMANCE: Removed redundant onAppear/onChange - game type is set in parent view
                case .captureTheFlag:
                    CTFLobbyView(
                        viewModel: viewModel,
                        onBackToMenu: {
                            // PERFORMANCE: No animation for faster navigation
                            selectedGame = nil
                            gameService.endGame()
                        }
                    )
                    .transition(.opacity) // PERFORMANCE: Simpler transition
                    // PERFORMANCE: Removed redundant onAppear/onChange - game type is set in parent view
                case .manhunt, .none:
                    ManhuntLobbyView(
                        viewModel: viewModel,
                        onBackToMenu: {
                            // PERFORMANCE: No animation for faster navigation
                            selectedGame = nil
                            gameService.endGame()
                        }
                    )
                    .transition(.opacity) // PERFORMANCE: Simpler transition
                    .onAppear {
                        // Set game type when lobby appears
                        if let gameType = selectedGame {
                            viewModel.selectedGameType = gameType
                        }
                    }
                    .onChange(of: selectedGame) { oldValue, newValue in
                        // Update game type when selection changes
                        if let gameType = newValue {
                            viewModel.selectedGameType = gameType
                            }
                        }
                    }
                }
            }
        }
        .alert("Game Over", isPresented: $viewModel.showGameOverAlert) {
            Button("OK") {
                // Only end game if it's actually over, not for begin game errors
                let gameService = viewModel.gameService
                if gameService.gameState == .ended {
                    gameService.endGame()
                }
            }
            if viewModel.gameService.gameState == .ended {
                Button("Play Again") {
                    viewModel.playAgain()
                }
            }
        } message: {
            Text(viewModel.gameOverMessage)
        }
    }
    
    // MARK: - Profile Tab Icon Update
    
    private func updateProfileTabIcon() {
        // PERFORMANCE: Only update once immediately instead of multiple delayed attempts
        updateTabIconOnce()
    }
    
    private func updateTabIconOnce() {
        // Try multiple ways to find the tab bar controller
        var tabBarController: UITabBarController?
        
        // Method 1: From window scene
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            tabBarController = window.rootViewController?.findTabBarController()
        }
        
        // Method 2: From key window (iOS 15+ compatible)
        if tabBarController == nil,
           let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let keyWindow = windowScene.windows.first(where: { $0.isKeyWindow }) {
            tabBarController = keyWindow.rootViewController?.findTabBarController()
        }
        
        guard let tabBar = tabBarController?.tabBar,
              tabBar.items?.count ?? 0 > 1 else {
            return
        }
        
        // Get profile picture or use default icon
        if let profileImage = profileService.loadProfilePicture() {
            // Resize and make circular for tab bar
            let tabBarIconSize: CGFloat = 28
            let resizedImage = profileImage.resized(to: CGSize(width: tabBarIconSize, height: tabBarIconSize))
            let circularImage = resizedImage.circularImage()
            
            // Set as tab bar item image with alwaysOriginal to prevent tinting
            tabBar.items?[1].image = circularImage.withRenderingMode(.alwaysOriginal)
            tabBar.items?[1].selectedImage = circularImage.withRenderingMode(.alwaysOriginal)
        } else {
            // Use default system icon
            tabBar.items?[1].image = UIImage(systemName: "person.fill")
            tabBar.items?[1].selectedImage = UIImage(systemName: "person.fill")
        }
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
    func findTabBarController() -> UITabBarController? {
        if let tabBarController = self as? UITabBarController {
            return tabBarController
        }
        
        for child in children {
            if let tabBarController = child.findTabBarController() {
                return tabBarController
            }
        }
        
        return nil
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
    
    func circularImage() -> UIImage {
        let size = min(size.width, size.height)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        
        // Create circular clipping path
        context.addEllipse(in: rect)
        context.clip()
        
        // Draw image
        draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}

// MARK: - TabBarIconUpdater

// REMOVED: TabBarIconUpdater - redundant and causes performance issues
// Icon updates are now handled directly in ContentView's updateProfileTabIcon() method