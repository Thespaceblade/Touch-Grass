//
//  ManhuntCountdownView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ManhuntCountdownView: View {
    @ObservedObject var gameService: GameService
    @ObservedObject var locationService: LocationService
    let onCountdownComplete: () -> Void
    
    @State private var timeRemaining: TimeInterval = 180.0 // 3 minutes
    @State private var timer: Timer?
    @State private var pulseScale: CGFloat = 1.0
    @State private var lastHapticSecond: Int = -1 // Track last second we triggered haptic to prevent duplicates
    @State private var showGoScreen: Bool = false
    
    // Hardcoded Manhunt theme properties
    private var primaryColor: Color {
        AppColors.manhuntPrimary
    }
    
    private var secondaryColor: Color {
        AppColors.manhuntSecondary
    }
    
    var body: some View {
        ZStack {
            ThemeBackgroundView(
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                lightColor: AppColors.manhuntLight
            )
            
            if showGoScreen {
                // GO! Screen
                goScreen
                    .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: AppSpacing.xl) {
                    Spacer()
                    
                    // Game Logo
                    Image("Manhunt")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 400, maxHeight: 180)
                        .shadow(color: primaryColor.opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    // Countdown Timer
                    VStack(spacing: AppSpacing.md) {
                        Text("Game Starting In")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                        
                        // Large countdown display
                        Text(timeString(from: timeRemaining))
                            .font(.system(size: 72, weight: .bold, design: .rounded))
                            .foregroundColor(primaryColor)
                            .monospacedDigit()
                            .scaleEffect(pulseScale)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
                    }
                    .padding(.vertical, AppSpacing.xl)
                    .frame(maxWidth: .infinity)
                    .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
                
                // Role indicator
                if let currentPlayer = gameService.currentPlayer {
                    VStack(spacing: AppSpacing.sm) {
                        Text("You are a")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.62))
                        
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: roleIcon(for: currentPlayer.role))
                                .font(.system(size: 19, weight: .black, design: .rounded))
                            
                            Text(roleTitle(for: currentPlayer.role))
                                .font(.system(size: 20, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, AppSpacing.lg)
                        .padding(.vertical, AppSpacing.md)
                        .background(roleColor(for: currentPlayer.role))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2.5))
                        .background(Capsule().fill(Color(white: 0.18)).offset(x: 4, y: 4))
                    }
                }
                
                // Instructions
                VStack(spacing: AppSpacing.xs) {
                    if let role = gameService.currentPlayer?.role {
                        if role == .hunter {
                            instructionText("Find and tag all hiders")
                            instructionText("Use Bluetooth to tag nearby players")
                        } else {
                            instructionText("Hide and avoid the hunters")
                            instructionText("Stay within the play zone")
                        }
                    }
                }
                .padding(.top, AppSpacing.lg)
                
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.xl)
            }
        }
        .onAppear {
            startCountdown()
            // Start pulse animation
            withAnimation {
                pulseScale = 1.1
            }
        }
        .onDisappear {
            stopCountdown()
        }
    }
    
    // MARK: - GO! Screen
    
    private var goScreen: some View {
        ZStack {
            // Full screen colored background
            primaryColor
                .ignoresSafeArea()
            
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                
                Text("GO!")
                    .font(.system(size: 120, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppColors.cartoonInk, radius: 0, x: 5, y: 5)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulseScale)
                
                Spacer()
            }
        }
    }
    
    private func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    private func roleIcon(for role: PlayerRole) -> String {
        switch role {
        case .hunter:
            return "target"
        case .hider:
            return "eye.slash.fill"
        default:
            return "person.fill"
        }
    }
    
    private func roleTitle(for role: PlayerRole) -> String {
        switch role {
        case .hunter:
            return "HUNTER"
        case .hider:
            return "HIDER"
        default:
            return role.rawValue.uppercased()
        }
    }
    
    private func roleColor(for role: PlayerRole) -> Color {
        switch role {
        case .hunter:
            return AppColors.hunterPrimary
        case .hider:
            return AppColors.hiderPrimary
        default:
            return AppColors.textPrimary
        }
    }
    
    private func instructionText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(AppColors.cartoonInk)
            .multilineTextAlignment(.center)
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(AppColors.cartoonCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2))
            .background(Capsule().fill(Color(white: 0.18)).offset(x: 2, y: 2))
    }
    
    private func startCountdown() {
        stopCountdown()
        
        // Haptic when countdown starts
        HapticFeedbackManager.shared.selection()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            Task { @MainActor in
                self.timeRemaining -= 0.1
                
                // Haptic feedback at key moments
                // Use Int(timeRemaining) to check whole seconds only
                let remainingSeconds = Int(self.timeRemaining)
                
                // Only trigger haptic once per second milestone
                if remainingSeconds != self.lastHapticSecond {
                    self.lastHapticSecond = remainingSeconds
                    
                    // Double haptic every 30 seconds until 30 seconds left (300, 270, 240, 210, 180, 150, 120, 90, 60)
                    if remainingSeconds > 30 && remainingSeconds % 30 == 0 {
                        HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
                    } else if remainingSeconds == 15 {
                        // Single haptic at 15 seconds
                        HapticFeedbackManager.shared.impact(style: .heavy)
                    } else if remainingSeconds >= 1 && remainingSeconds <= 10 {
                        // From 10 to 1: haptic every second
                        if remainingSeconds == 10 || remainingSeconds == 7 || remainingSeconds == 4 || remainingSeconds == 2 || remainingSeconds == 1 {
                            // Double haptic at key moments (10, 7, 4, 2, 1)
                            HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
                        } else {
                            // Single haptic for other seconds (9, 8, 6, 5, 3)
                            HapticFeedbackManager.shared.impact(style: .heavy)
                        }
                    } else if remainingSeconds == 0 {
                        // At 0: Show GO! screen with multiple double haptics
                        self.showGoScreen = true
                        // Multiple double haptics for GO!
                        HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
                            // After GO! screen, transition to game
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                self.stopCountdown()
                                self.onCountdownComplete()
                            }
                        }
                        return
                    }
                }
            }
        }
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopCountdown() {
        timer?.invalidate()
        timer = nil
        lastHapticSecond = -1 // Reset haptic tracking
    }
}
