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
    
    /// Minimum number of players required to begin the game
    var minimumPlayers: Int {
        switch self {
        case .manhunt, .zombieTag:
            return 3
        case .captureTheFlag:
            return 4
        }
    }
    
    var description: String {
        switch self {
        case .manhunt:
            return "Location-based hide and seek"
        case .zombieTag:
            return "Infection tag with friends"
        case .captureTheFlag:
            return "Team-based flag capture"
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
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            let isCompactHeight = geometry.size.height < 760
            
            ZStack {
                // Landscape Background - rendered as cached bitmap for performance
                LandscapeBackground()
                    .drawingGroup() // CRITICAL: Renders all shapes as single image - massive performance boost
                    .ignoresSafeArea(.all)
                    .zIndex(0)
                
                // Aesthetic Gradient Background (same as original)
                AestheticBackground(
                    gradientOffset: 0,
                    pulseScale: 1.0
                )
                .ignoresSafeArea(.all)
                .zIndex(1)
                .allowsHitTesting(false)
            
                // Splash logo removed - content shows immediately for best performance
                
                // Content scrolls inside the TabView safe area so the tab bar cannot cover cards.
                // zIndex(2) keeps cards above AestheticBackground (zIndex 1) so cream is visible.
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                    // Hero Section (Logo at top)
                    HeroSectionView(
                        logoGlow: 1.0,
                        pulseScale: 1.0,
                        maxLogoHeight: isCompactHeight ? 383 : 495
                    )
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, isCompactHeight ? AppSpacing.md : AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xs)
                
                    // Decorative Divider
                    DecorativeDividerView()
                    .padding(.horizontal, AppSpacing.xl)
                        .padding(.top, 2)
                        .padding(.bottom, isCompactHeight ? AppSpacing.xs : AppSpacing.sm)
                    
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
                    .padding(.bottom, AppSpacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .top)
                }
                .safeAreaPadding(.bottom, AppSpacing.md)
                .zIndex(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full screen coverage
    }
    
    // MARK: - Game Cards (Cartoon Design)

    private func accentColor(for gameType: GameType) -> Color {
        switch gameType {
        case .manhunt:         return AppColors.manhuntPrimary
        case .zombieTag:       return AppColors.zombiePrimary
        case .captureTheFlag:  return AppColors.ctfPrimary
        }
    }

    private func artImageName(for gameType: GameType) -> String {
        switch gameType {
        case .manhunt:         return "Manhunt"
        case .zombieTag:       return "ZombieTag"
        case .captureTheFlag:  return "CTF"
        }
    }

    private func gameCardContent(_ gameType: GameType, isDisabled: Bool) -> some View {
        HStack(spacing: 12) {
            // Art thumbnail — 64×64, ink border, tiny hard shadow
            Image(artImageName(for: gameType))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.cartoonInk, lineWidth: 2)
                )
                .shadow(color: AppColors.cartoonInk, radius: 0, x: 1.5, y: 1.5)

            // Title + subtitle
            VStack(alignment: .leading, spacing: 6) {
                Text(gameType.rawValue)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(accentColor(for: gameType))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(gameType.description)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            // Trailing indicator
            if isDisabled {
                CartoonPill(text: "Soon", color: AppColors.cartoonCream2, textColor: AppColors.cartoonInk)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppColors.cartoonInk)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2.5)
        )
        .opacity(isDisabled ? 0.6 : 1)
    }

    private func gameCard(_ gameType: GameType) -> some View {
        let isDisabled = false
        return Button(action: {
            guard !isDisabled else { return }
            onSelectGame(gameType)
        }) {
            gameCardContent(gameType, isDisabled: isDisabled)
        }
        .buttonStyle(CartoonCardButtonStyle(isDisabled: isDisabled))
        .disabled(isDisabled)
        .accessibilityLabel("\(gameType.rawValue) game")
        .accessibilityHint(isDisabled ? "Coming soon" : "Tap to select \(gameType.rawValue)")
    }
}

