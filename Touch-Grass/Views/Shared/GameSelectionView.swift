//
//  GameSelectionView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import UIKit

enum GameType: String, Identifiable {
    case manhunt = "Manhunt"
    case zombieTag = "Zombie Tag"
    case captureTheFlag = "Capture The Flag"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .manhunt:
            return "Location-based hide & seek with a shrinking play zone"
        case .zombieTag:
            return "One zombie infects others; last human wins"
        case .captureTheFlag:
            return "Two teams compete to capture and return the enemy flag"
        }
    }
    
    var icon: String {
        switch self {
        case .manhunt:
            return "person.2.fill"
        case .zombieTag:
            return "figure.walk.motion"
        case .captureTheFlag:
            return "flag.fill"
        }
    }
}

struct GameSelectionView: View {
    let onSelectGame: (GameType) -> Void
    
    @State private var splashPhase: SplashPhase = .complete
    
    enum SplashPhase {
        case complete
    }
    
    var body: some View {
        ZStack {
                // Aesthetic Gradient Background (simplified for performance)
                AestheticBackground(
                    gradientOffset: 0, // Static value for performance
                    pulseScale: 1.0 // Static value for performance
                )
                .ignoresSafeArea()
                .allowsHitTesting(false) // TOUCH FIX: Ensure background doesn't block touches on home screen
            
                // Splash logo removed - content shows immediately for best performance
                
                // Content (no scroll needed)
            VStack(spacing: 0) {
                    // Hero Section (Logo at top)
                    HeroSectionView(
                        logoGlow: 1.0,
                        pulseScale: 1.0
                    )
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xs)
                
                    // Decorative Divider
                    DecorativeDividerView()
                    .padding(.horizontal, AppSpacing.xl)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.md)
                    
                    // Games Section
                    VStack(spacing: AppSpacing.sm) {
                        // Game Cards
                    VStack(spacing: AppSpacing.md) {
                        gameCard(.manhunt)
                        gameCard(.zombieTag)
                        gameCard(.captureTheFlag)
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .frame(maxWidth: .infinity)
                    .padding(.bottom, AppSpacing.xl)
            }
            .onAppear {
                startSplashAnimation()
            }
            .onDisappear {
                // Reset animations to reduce background work
            }
        }
    }
    
    // MARK: - Splash Animation (simplified)
    
    private func startSplashAnimation() {
        // No animation - content shows immediately for best performance
        splashPhase = .complete
    }
    
    // MARK: - Game Cards (Premium Design)
    
    // Helper functions to simplify complex expressions for compiler
    private func iconGradientColors(for gameType: GameType) -> [Color] {
        switch gameType {
        case .manhunt:
            return [AppColors.manhuntPrimary.opacity(0.5), AppColors.manhuntSecondary.opacity(0.4)]
        case .zombieTag:
            return [AppColors.zombiePrimary.opacity(0.5), AppColors.zombieSecondary.opacity(0.4)]
        case .captureTheFlag:
            return [AppColors.ctfPrimary.opacity(0.5), AppColors.ctfSecondary.opacity(0.4)]
        }
    }
    
    private func iconMainGradientColors(for gameType: GameType) -> [Color] {
        switch gameType {
        case .manhunt:
            return [AppColors.manhuntPrimary.opacity(0.4), AppColors.manhuntSecondary.opacity(0.35)]
        case .zombieTag:
            return [AppColors.zombiePrimary.opacity(0.4), AppColors.zombieSecondary.opacity(0.35)]
        case .captureTheFlag:
            return [AppColors.ctfPrimary.opacity(0.4), AppColors.ctfSecondary.opacity(0.35)]
        }
    }
    
    private func iconStrokeGradientColors(for gameType: GameType) -> [Color] {
        switch gameType {
        case .manhunt:
            return [AppColors.manhuntPrimary.opacity(0.8), AppColors.manhuntSecondary.opacity(0.7)]
        case .zombieTag:
            return [AppColors.zombiePrimary.opacity(0.8), AppColors.zombieSecondary.opacity(0.7)]
        case .captureTheFlag:
            return [AppColors.ctfPrimary.opacity(0.8), AppColors.ctfSecondary.opacity(0.7)]
        }
    }
    
    private func titleGradientColors(for gameType: GameType) -> [Color] {
        switch gameType {
        case .manhunt:
            return [AppColors.manhuntLight, AppColors.manhuntSecondary, AppColors.manhuntPrimary]
        case .zombieTag:
            return [AppColors.zombieLight, AppColors.zombieSecondary, AppColors.zombiePrimary]
        case .captureTheFlag:
            return [AppColors.ctfLight, AppColors.ctfSecondary, AppColors.ctfPrimary]
        }
    }
    
    private func titleGlowColors(for gameType: GameType) -> (outer: [Color], middle: [Color]) {
        switch gameType {
        case .manhunt:
            return (
                outer: [AppColors.manhuntLight.opacity(0.8), AppColors.manhuntSecondary.opacity(0.7)],
                middle: [AppColors.manhuntLight.opacity(0.9), AppColors.manhuntSecondary.opacity(0.8)]
            )
        case .zombieTag:
            return (
                outer: [AppColors.zombieLight.opacity(0.8), AppColors.zombieSecondary.opacity(0.7)],
                middle: [AppColors.zombieLight.opacity(0.9), AppColors.zombieSecondary.opacity(0.8)]
            )
        case .captureTheFlag:
            return (
                outer: [AppColors.ctfLight.opacity(0.8), AppColors.ctfSecondary.opacity(0.7)],
                middle: [AppColors.ctfLight.opacity(0.9), AppColors.ctfSecondary.opacity(0.8)]
            )
        }
    }
    
    private func cardBackgroundGradientColors(for gameType: GameType) -> [Color] {
        switch gameType {
        case .manhunt:
            return [
                AppColors.manhuntPrimary.opacity(0.25),
                AppColors.manhuntSecondary.opacity(0.2),
                AppColors.manhuntLight.opacity(0.15)
            ]
        case .zombieTag:
            return [
                AppColors.zombiePrimary.opacity(0.3),
                AppColors.zombieSecondary.opacity(0.25),
                AppColors.zombieLight.opacity(0.2)
            ]
        case .captureTheFlag:
            return [
                AppColors.ctfPrimary.opacity(0.25),
                AppColors.ctfSecondary.opacity(0.2),
                AppColors.ctfLight.opacity(0.15)
            ]
        }
    }
    
    private func cardStrokeGradientColors(for gameType: GameType) -> [Color] {
        switch gameType {
        case .manhunt:
            return [
                AppColors.manhuntPrimary.opacity(0.8),
                AppColors.manhuntSecondary.opacity(0.7),
                AppColors.manhuntLight.opacity(0.6)
            ]
        case .zombieTag:
            return [
                AppColors.zombiePrimary.opacity(0.8),
                AppColors.zombieSecondary.opacity(0.7),
                AppColors.zombieLight.opacity(0.6)
            ]
        case .captureTheFlag:
            return [
                AppColors.ctfPrimary.opacity(0.8),
                AppColors.ctfSecondary.opacity(0.7),
                AppColors.ctfLight.opacity(0.6)
            ]
        }
    }
    
    private func accentColor(for gameType: GameType) -> Color {
        switch gameType {
        case .manhunt: return AppColors.manhuntPrimary
        case .zombieTag: return AppColors.zombiePrimary
        case .captureTheFlag: return AppColors.ctfPrimary
        }
    }
    
    private func shadowColor(for gameType: GameType) -> Color {
        switch gameType {
        case .manhunt: return AppColors.manhuntPrimary
        case .zombieTag: return AppColors.zombiePrimary
        case .captureTheFlag: return AppColors.ctfPrimary
        }
    }
    
    @ViewBuilder
    private func titleWithGlow(for gameType: GameType) -> some View {
        let glowColors = titleGlowColors(for: gameType)
        let shadowColorValue = shadowColor(for: gameType)
        
        ZStack {
            // Outer glow layer - more intense and brighter
            Text(gameType.rawValue)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(0.5) // Match letter spacing
                .lineLimit(1) // Keep on one line
                .foregroundStyle(
                    LinearGradient(
                        colors: glowColors.outer,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 4)
                .offset(x: 0, y: 1)
            
            // Middle glow layer - brighter
            Text(gameType.rawValue)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(0.5) // Match letter spacing
                .lineLimit(1) // Keep on one line
                .foregroundStyle(
                    LinearGradient(
                        colors: glowColors.middle,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .blur(radius: 2)
                .offset(x: 0, y: 0.5)
            
            // Main text with vibrant, bright gradient starting from brightest color - FIXED SIZE
            Text(gameType.rawValue)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .tracking(0.5) // Letter spacing for better readability
                .lineLimit(1) // Keep on one line
                .foregroundStyle(
                    LinearGradient(
                        colors: titleGradientColors(for: gameType),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .brightness(0.15) // Brighten the text
                .shadow(
                    color: shadowColorValue.opacity(1.0),
                    radius: 12,
                    x: 0,
                    y: 0
                )
                .shadow(
                    color: Color.black.opacity(0.5),
                    radius: 6,
                    x: 0,
                    y: 3
                )
                .shadow(
                    color: shadowColorValue.opacity(0.7),
                    radius: 18,
                    x: 0,
                    y: 0
                )
                .shadow(
                    color: Color.black.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                )
        }
    }
    
    @ViewBuilder
    private func titleText(for gameType: GameType) -> some View {
        let shadowColorValue = shadowColor(for: gameType)
        Text(gameType.rawValue)
            .font(.system(size: 26, weight: .black, design: .rounded))
            .tracking(0.5) // Letter spacing for better readability
            .lineLimit(1) // Keep on one line
            .foregroundStyle(
                LinearGradient(
                    colors: titleGradientColors(for: gameType),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .brightness(0.15) // Brighten the text
            .shadow(
                color: shadowColorValue.opacity(1.0),
                radius: 12,
                x: 0,
                y: 0
            )
            .shadow(
                color: Color.black.opacity(0.5),
                radius: 6,
                x: 0,
                y: 3
            )
            .shadow(
                color: shadowColorValue.opacity(0.7),
                radius: 18,
                x: 0,
                y: 0
            )
            .shadow(
                color: Color.black.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
    }
    
    @ViewBuilder
    private func chevronIcon(for gameType: GameType) -> some View {
        let accentColorValue = accentColor(for: gameType)
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(accentColorValue)
            .padding(8)
            .background(
                Circle()
                    .fill(accentColorValue.opacity(0.2))
            )
    }
    
    @ViewBuilder
    private func gameIcon(for gameType: GameType) -> some View {
        if gameType == .manhunt {
            // Manhunt Logo with Red Glow Effect
            ZStack {
                // Outer glow effect
                Image("Manhunt")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .blur(radius: 8)
                    .opacity(0.6)
                    .offset(x: 0, y: 1)
                
                // Middle glow layer
                Image("Manhunt")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .blur(radius: 4)
                    .opacity(0.5)
                    .offset(x: 0, y: 0.5)
                
                // Main logo
                Image("Manhunt")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .shadow(color: AppColors.manhuntPrimary.opacity(0.7), radius: 10, x: 0, y: 0)
                    .shadow(color: AppColors.manhuntSecondary.opacity(0.5), radius: 15, x: 0, y: 0)
            }
        } else if gameType == .zombieTag {
            // Zombie Tag Logo with Green Glow Effect
            ZStack {
                // Outer glow effect
                Image("ZombieTag")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .blur(radius: 8)
                    .opacity(0.6)
                    .offset(x: 0, y: 1)
                
                // Middle glow layer
                Image("ZombieTag")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .blur(radius: 4)
                    .opacity(0.5)
                    .offset(x: 0, y: 0.5)
                
                // Main logo
                Image("ZombieTag")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .shadow(color: AppColors.zombiePrimary.opacity(0.7), radius: 10, x: 0, y: 0)
                    .shadow(color: AppColors.zombieSecondary.opacity(0.5), radius: 15, x: 0, y: 0)
            }
        } else if gameType == .captureTheFlag {
            // CTF Logo with Blue Glow Effect
            ZStack {
                // Outer glow effect
                Image("CTF")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .blur(radius: 8)
                    .opacity(0.6)
                    .offset(x: 0, y: 1)
                
                // Middle glow layer
                Image("CTF")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .blur(radius: 4)
                    .opacity(0.5)
                    .offset(x: 0, y: 0.5)
                
                // Main logo
                Image("CTF")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                    .shadow(color: AppColors.ctfPrimary.opacity(0.7), radius: 10, x: 0, y: 0)
                    .shadow(color: AppColors.ctfSecondary.opacity(0.5), radius: 15, x: 0, y: 0)
            }
        } else {
            // SF Symbol for other games
            Image(systemName: gameType.icon)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.grassPrimary,
                            AppColors.grassSecondary,
                            AppColors.grassLight
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    private func gameCard(_ gameType: GameType) -> some View {
        Button(action: {
            // Haptic feedback for better UX
            HapticFeedbackManager.shared.selection()
            
            // Immediate visual feedback, then transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.smoothTransition) {
                onSelectGame(gameType)
                }
            }
        }) {
            HStack(spacing: AppSpacing.md) {
                // Icon with Enhanced Background (Red for Manhunt, Green for Zombie Tag, Blue for CTF, Green for others)
                ZStack {
                    // Outer glow - more vibrant
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconGradientColors(for: gameType),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .blur(radius: 5)
                    
                    // Main circle - more vibrant, obvious colors
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: iconMainGradientColors(for: gameType),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: iconStrokeGradientColors(for: gameType),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2.5
                                )
                        )
                    
                    // Icon - Use custom logos with glow effects, or SF Symbol for other games
                    gameIcon(for: gameType)
                }
                
                // Title with gradient - using brightest color on left side - ENHANCED FOR PROMINENCE & BRIGHTNESS
                // All titles use the same 26pt font size - layout accommodates longest title without truncation
                ZStack {
                    let glowColors = titleGlowColors(for: gameType)
                    
                    // Outer glow layer - more intense and brighter
                    Text(gameType.rawValue)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(0.5) // Match letter spacing
                        .lineLimit(1) // Keep on one line
                        .foregroundStyle(
                            LinearGradient(
                                colors: glowColors.outer,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blur(radius: 4)
                        .offset(x: 0, y: 1)
                    
                    // Middle glow layer - brighter
                    Text(gameType.rawValue)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(0.5) // Match letter spacing
                        .lineLimit(1) // Keep on one line
                        .foregroundStyle(
                            LinearGradient(
                                colors: glowColors.middle,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .blur(radius: 2)
                        .offset(x: 0, y: 0.5)
                    
                    // Main text with vibrant, bright gradient starting from brightest color - FIXED SIZE
                    let shadowColorValue = shadowColor(for: gameType)
                    Text(gameType.rawValue)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .tracking(0.5) // Letter spacing for better readability
                        .lineLimit(1) // Keep on one line
                        .foregroundStyle(
                            LinearGradient(
                                colors: titleGradientColors(for: gameType),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .brightness(0.15) // Brighten the text
                        .shadow(
                            color: shadowColorValue.opacity(1.0),
                            radius: 12,
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: Color.black.opacity(0.5),
                            radius: 6,
                            x: 0,
                            y: 3
                        )
                        .shadow(
                            color: shadowColorValue.opacity(0.7),
                            radius: 18,
                            x: 0,
                            y: 0
                        )
                        .shadow(
                            color: Color.black.opacity(0.3),
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8) // Allow text to scale down if needed
                
                Spacer()
                
                // Chevron (Red for Manhunt, Green for Zombie Tag, Blue for CTF, Green for others)
                chevronIcon(for: gameType)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity) // Constrain card to available width
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        // More vibrant, obvious colors - solid background with theme color
                        LinearGradient(
                            colors: cardBackgroundGradientColors(for: gameType),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(
                                LinearGradient(
                                    colors: cardStrokeGradientColors(for: gameType),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )
                    .shadow(color: Color.black.opacity(0.15), radius: 15, x: 0, y: 8)
                    .shadow(
                        color: shadowColor(for: gameType).opacity(0.3),
                        radius: 25, x: 0, y: 0
                    )
            )
        }
        .buttonStyle(PremiumCardButtonStyle(
            accentColor: accentColor(for: gameType)
        ))
        .accessibilityLabel("\(gameType.rawValue) game")
        .accessibilityHint("Tap to select \(gameType.rawValue)")
    }
    
    // MARK: - Button Styles
    
    struct ScaleButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

