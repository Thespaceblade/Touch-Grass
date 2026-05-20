import SwiftUI
import MapKit
import UIKit
import UserNotifications

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @ObservedObject private var themeManager = ThemeManager.shared
    // OPTIMIZATION: Don't observe ProfileService from ContentView (it causes unnecessary re-renders)
    private let profileService = ProfileService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var selectedTab: Int = 0
    @State private var previousGame: GameType? = nil
    @State private var isInitialLoad: Bool = true
    @State private var isTransitioning: Bool = false
    @State private var profileTabIconUpdateTask: Task<Void, Never>? = nil
    #if DEBUG
    @State private var showDebugTestPanel = false
    #endif
    
    var body: some View {
        ZStack {
            // Persistent background, always on screen at full opacity so it never
            // flashes white during page transitions. The landscape inside each tab/
            // lobby view is additive on top of this layer.
            AppColors.backgroundPrimary
                .ignoresSafeArea()
            LandscapeBackground()
                .drawingGroup()
                .ignoresSafeArea(.all)
            AestheticBackground(gradientOffset: 0, pulseScale: 1.0)
                .ignoresSafeArea(.all)
                .allowsHitTesting(false)

            // Home or Game View, only the content cross-fades, not the background
            Group {
                if viewModel.selectedGame == nil {
                    homeView
                        .transition(.opacity)
                } else {
                    gameView
                        .transition(.opacity)
                }
            }
        }
        // Theme: Light / Dark / System (`nil` = follow system). Dynamic cartoon
        // tokens in `AppColors` re-author cream/ink/pastel surfaces for night;
        // the landscape already swaps to its moon-and-stars branch when the
        // trait flips. Default preference is Light to preserve existing
        // behavior on upgrade, users opt in from Settings → Appearance.
        .preferredColorScheme(themeManager.preferredColorScheme)
        .onReceive(NotificationCenter.default.publisher(for: ThemeManager.didChangeNotification)) { _ in
            // UITabBar appearance is built from `AppColors.cartoonInk` etc.
            // These are dynamic UIColors and re-resolve when the trait
            // collection changes, but rebuild the proxy explicitly so the
            // visible tab bar refreshes immediately after the user picks a
            // new theme, rather than waiting for the next layout pass.
            setupTabBarAppearance()
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.selectedGame?.rawValue)
        .appToast($viewModel.activeToast)
        .themedNotice(
            isPresented: Binding(
                get: { viewModel.showGameOverAlert },
                set: { viewModel.showGameOverAlert = $0 }
            ),
            primaryColor: AppColors.error,
            secondaryColor: AppColors.error.opacity(0.7),
            iconName: "xmark.circle.fill",
            headerTitle: "Game Over",
            headerSubtitle: "You're out",
            title: "Game Over",
            message: viewModel.gameOverMessage,
            buttons: [
                ThemedNoticeButton(title: "OK", icon: "checkmark", role: .secondary) {
                    Task { @MainActor in
                        let gameService = viewModel.gameService
                        if gameService.gameState == .ended {
                            gameService.endGame()
                        }
                    }
                },
                ThemedNoticeButton(title: "Play Again", icon: "arrow.clockwise", role: .primary) {
                    viewModel.playAgain()
                }
            ]
        )
        .themedNotice(
            isPresented: sessionEndedNoticeBinding,
            primaryColor: sessionEndedPrimaryColor,
            secondaryColor: sessionEndedSecondaryColor,
            iconName: "rectangle.portrait.and.arrow.right",
            headerTitle: sessionEndedHeaderTitle,
            headerSubtitle: "Session ended",
            title: viewModel.sessionEndedNotice?.title ?? "Game Closed",
            message: viewModel.sessionEndedNotice?.message ?? "",
            buttons: [
                ThemedNoticeButton(title: "Back to Games", icon: "gamecontroller.fill", role: .primary) {
                    viewModel.dismissSessionEndedNotice()
                    withAnimation(.easeOut(duration: 0.25)) {
                        viewModel.selectedGame = nil
                        selectedTab = 0
                    }
                }
            ]
        )
    }
    
    // MARK: - Home View
    
    private var homeView: some View {
        TabView(selection: $selectedTab) {
            GameSelectionView { gameType in
                guard AppReleaseConfiguration.isGameModeAvailable(gameType) else { return }

                // Prevent multiple rapid taps
                guard !isTransitioning else {
                    #if DEBUG
                    print("🔍 DEBUG: ContentView - GameSelectionView callback blocked (already transitioning)")
                    #endif
                    return
                }
                
                #if DEBUG
                print("🔍 DEBUG: ContentView - GameSelectionView callback triggered for \(gameType)")
                print("🔍 DEBUG: ContentView - Current selectedGame: \(String(describing: viewModel.selectedGame))")
                print("🔍 DEBUG: ContentView - Setting isTransitioning = true")
                #endif
                
                // OPTIMIZATION: Set transition flag and change state immediately
                isTransitioning = true
                // OPTIMIZATION: Removed duplicate haptic - button style handles it
                
                // OPTIMIZATION: Instant state change with fast animation for responsive feel
                #if DEBUG
                print("🔍 DEBUG: ContentView - Starting animation block")
                #endif
                withAnimation(.easeOut(duration: 0.2)) {
                    previousGame = viewModel.selectedGame
                    viewModel.selectedGame = gameType
                    viewModel.selectedGameType = gameType
                    isInitialLoad = false
                    #if DEBUG
                    print("🔍 DEBUG: ContentView - Animation block: selectedGame set to \(gameType)")
                    #endif
                }
                
                #if DEBUG
                print("🔍 DEBUG: ContentView - Animation block completed, starting service initialization")
                #endif
                
                // OPTIMIZATION: Initialize services AFTER transition completes for smooth animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    Task { @MainActor in
                        await viewModel.ensureServicesInitialized()
                        #if DEBUG
                        print("🔍 DEBUG: ContentView - Service initialization completed")
                        #endif
                    }
                    
                    isTransitioning = false
                    #if DEBUG
                    print("🔍 DEBUG: ContentView - isTransitioning reset to false")
                    #endif
                }
            }
            .tabItem {
                Label("Game", systemImage: "gamecontroller.fill")
            }
            .tag(0)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(1)
                #if DEBUG
                .overlay(alignment: .topTrailing) {
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        showDebugTestPanel = true
                    }) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(IconButtonStyle(size: 36, color: AppColors.grassPrimary))
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
                #endif
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        #if DEBUG
        .sheet(isPresented: $showDebugTestPanel) {
            DebugTestPanelView(viewModel: viewModel)
        }
        #endif
        .onChange(of: selectedTab) { _, _ in
            // SwiftUI re-applies the tabItem SF Symbol when the selected tab changes,
            // which wipes the custom avatar we set on the UITabBarItem. Re-apply
            // on the next run loop so the profile photo stays consistent on every tab.
            DispatchQueue.main.async {
                updateProfileTabIcon()
            }
        }
        .onAppear {
            setupTabBarAppearance()
            updateProfileTabIcon()
            // Warm the disk cache; tab icon refreshes via ProfilePictureUpdated when ready.
            profileService.preloadProfilePicture()
            // Attempt to rehydrate an active lobby from the local
            // snapshot. No-op if there is no snapshot or it can't be
            // restored; in that case the snapshot is cleared by the
            // GameService so this is safe to call on every appear.
            Task { @MainActor in
                await viewModel.resumeActiveSessionIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .profilePictureUpdated)) { _ in
            updateProfileTabIcon()
        }
    }
    
    // MARK: - Game View
    
    private var gameView: some View {
        let _ = {
            #if DEBUG
            print("🔍 DEBUG: ContentView gameView computed - selectedGame: \(String(describing: viewModel.selectedGame))")
            #endif
        }()
        
        return ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()
            
            if viewModel.isServicesInitializing {
                LobbySkeletonView()
                    .transition(.opacity)
            } else if let gameType = viewModel.selectedGame {
                #if DEBUG
                let _ = print("🔍 DEBUG: ContentView gameView - Creating lobby view for \(gameType)")
                #endif
                switch gameType {
                case .manhunt:
                    ManhuntLobbyView(
                            viewModel: viewModel,
                            onBackToMenu: {
                            #if DEBUG
                            print("🔍 DEBUG: ContentView - ManhuntLobbyView onBackToMenu called")
                            #endif
                            Task { @MainActor in
                                guard !isTransitioning else { return }
                                isTransitioning = true
                                
                                withAnimation(.easeOut(duration: 0.25)) {
                                    previousGame = viewModel.selectedGame
                                    viewModel.selectedGame = nil
                                    #if DEBUG
                                    print("🔍 DEBUG: ContentView - Back to menu: selectedGame set to nil")
                                    #endif
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isTransitioning = false
                                }
                            }
                        }
                    )
                case .zombieTag:
                    ZombieTagLobbyView(
                        viewModel: viewModel,
                        onBackToMenu: {
                            #if DEBUG
                            print("🔍 DEBUG: ContentView - ZombieTagLobbyView onBackToMenu called")
                            #endif
                            Task { @MainActor in
                                guard !isTransitioning else { return }
                                isTransitioning = true
                                
                                withAnimation(.easeOut(duration: 0.25)) {
                                    previousGame = viewModel.selectedGame
                                    viewModel.selectedGame = nil
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isTransitioning = false
                                }
                            }
                        }
                    )
                case .captureTheFlag:
                    CTFLobbyView(
                        viewModel: viewModel,
                        onBackToMenu: {
                            #if DEBUG
                            print("🔍 DEBUG: ContentView - CTFLobbyView onBackToMenu called")
                            #endif
                            Task { @MainActor in
                                guard !isTransitioning else { return }
                                isTransitioning = true
                                
                                withAnimation(.easeOut(duration: 0.25)) {
                                    previousGame = viewModel.selectedGame
                                    viewModel.selectedGame = nil
                                }
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isTransitioning = false
                                }
                            }
                        }
                    )
                }
            }
        }
        .overlay {
            if let loadingMessage = activeLoadingMessage {
                SmoothLoadingOverlay(message: loadingMessage, showProgress: true)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Initialize services if needed (for cases where view appears without going through game selection)
            if viewModel.selectedGame != nil {
                Task { @MainActor in
                    await viewModel.ensureServicesInitialized()
                }
            }
            if let game = viewModel.selectedGame {
                viewModel.selectedGameType = game
            }
        }
        .onChange(of: viewModel.selectedGame) { oldValue, newValue in
            if newValue == nil {
                // Back to main menu - detach so the local lobby (and its
                // resume snapshot) survive. Explicit Leave still uses
                // `leaveSession()` from the lobby's exit confirmation.
                if oldValue != nil {
                    Task { @MainActor in
                        viewModel.gameService.detachFromSession()
                    }
                }
                withAnimation(.easeOut(duration: 0.25)) {
                    selectedTab = 0
                }
            } else {
                // Handle game switching
                if oldValue != nil && oldValue != newValue {
                    // Mode switch is destructive: the previous session
                    // does not survive a different game type selection.
                    Task { @MainActor in
                        viewModel.gameService.clearSession()
                    }
                    previousGame = oldValue
                }
                // Initialize services asynchronously
                Task { @MainActor in
                    await viewModel.ensureServicesInitialized()
                }
                viewModel.selectedGameType = newValue!
                isInitialLoad = false
            }
                    }
                    .onAppear {
            // Mark initial load complete immediately to ensure view appears
            isInitialLoad = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                UNUserNotificationCenter.current().setBadgeCount(0)
            }
        }
    }
    
    // MARK: - Transition Helpers
    
    private var activeLoadingMessage: String? {
        if viewModel.isServicesInitializing {
            return "Initializing game services..."
        }
        if viewModel.isCreatingSession {
            return "Creating game..."
        }
        if viewModel.isJoiningGame {
            return "Joining game..."
        }
        return nil
    }

    private var sessionEndedNoticeBinding: Binding<Bool> {
        Binding(
            get: { viewModel.sessionEndedNotice != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.dismissSessionEndedNotice()
                }
            }
        )
    }

    private var sessionEndedGameType: GameType {
        viewModel.sessionEndedNotice?.gameType ?? viewModel.selectedGameType
    }

    private var sessionEndedPrimaryColor: Color {
        switch sessionEndedGameType {
        case .manhunt: return AppColors.manhuntPrimary
        case .zombieTag: return AppColors.zombiePrimary
        case .captureTheFlag: return AppColors.ctfPrimary
        }
    }

    private var sessionEndedSecondaryColor: Color {
        switch sessionEndedGameType {
        case .manhunt: return AppColors.manhuntSecondary
        case .zombieTag: return AppColors.zombieSecondary
        case .captureTheFlag: return AppColors.ctfSecondary
        }
    }

    private var sessionEndedHeaderTitle: String {
        switch sessionEndedGameType {
        case .manhunt: return "Manhunt"
        case .zombieTag: return "Zombie Tag"
        case .captureTheFlag: return "Capture The Flag"
        }
    }
    
}

// MARK: - Tab Bar Setup

extension ContentView {
    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        // Subtle top hairline so the tab bar is visually distinct without a bezel
        appearance.shadowColor = UIColor(AppColors.cartoonInk).withAlphaComponent(0.18)

        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.grassPrimary)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.grassPrimary),
            .font: UIFont.systemFont(ofSize: 12, weight: .black)
        ]

        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.cartoonInk)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.cartoonInk),
            .font: UIFont.systemFont(ofSize: 12, weight: .bold)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().isTranslucent = true
        UITabBar.appearance().tintColor = UIColor(AppColors.grassPrimary)
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppColors.cartoonInk)
    }
    
    private func updateProfileTabIcon() {
        profileTabIconUpdateTask?.cancel()

        profileTabIconUpdateTask = Task { @MainActor in
            // Memory cache first; if the user has a saved photo but hasn't opened
            // Profile yet, load from disk so the tab icon isn't stuck on person.fill.
            var profileImage = profileService.loadProfilePicture()
            if profileImage == nil {
                profileImage = await profileService.loadProfilePictureAsync()
            }

            guard !Task.isCancelled else { return }
            applyProfileTabBarIcon(profileImage: profileImage)
        }
    }

    private func applyProfileTabBarIcon(profileImage: UIImage?) {
        let processedIcon: UIImage? = profileImage.map {
            $0.circularPaddedIcon(diameter: 28, inset: 2)
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let tabBarController = window.rootViewController?.findTabBarController(),
              let items = tabBarController.tabBar.items,
              items.count > 1 else {
            return
        }

        if let processedIcon {
            items[1].image = processedIcon.withRenderingMode(.alwaysOriginal)
            items[1].selectedImage = processedIcon.withRenderingMode(.alwaysOriginal)
        } else {
            let fallback = UIImage(systemName: "person.fill")
            items[1].image = fallback
            items[1].selectedImage = fallback
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
        let size = min(self.size.width, self.size.height)
        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return self }
        
        context.addEllipse(in: rect)
        context.clip()
        draw(in: rect)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
    
    /// Creates a circular icon with a transparent inset padding so it won't look cropped in a UITabBar.
    func circularPaddedIcon(diameter: CGFloat, inset: CGFloat) -> UIImage {
        let canvas = CGSize(width: diameter, height: diameter)
        let drawRect = CGRect(x: inset, y: inset, width: diameter - 2 * inset, height: diameter - 2 * inset)
        
        UIGraphicsBeginImageContextWithOptions(canvas, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        
        guard let ctx = UIGraphicsGetCurrentContext() else { return self }
        
        ctx.addEllipse(in: drawRect)
        ctx.clip()
        
        // Aspect-fill into drawRect
        let scale = max(drawRect.width / size.width, drawRect.height / size.height)
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: drawRect.midX - scaledSize.width / 2,
            y: drawRect.midY - scaledSize.height / 2
        )
        let target = CGRect(origin: origin, size: scaledSize)
        draw(in: target)
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
