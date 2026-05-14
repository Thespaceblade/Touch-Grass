//
//  AppColors.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import UIKit

// MARK: - Dynamic Color Helpers

/// Build a SwiftUI `Color` that resolves differently in light vs dark traits.
/// Used to give the cartoon palette a parallel "night" authoring without
/// rewriting every call site that already references `AppColors.cartoonInk`,
/// `AppColors.cartoonCream`, etc.
private func dyn(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { traits in
        traits.userInterfaceStyle == .dark ? dark : light
    })
}

private func hex(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
    UIColor(red: r, green: g, blue: b, alpha: 1)
}

struct AppColors {
    // MARK: - Primary Game Colors
    
    // Bubble Colors (gradient from safe to danger)
    static let bubbleSafe = Color(red: 0.0, green: 0.7, blue: 1.0) // Cyan blue
    static let bubbleWarning = Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow
    static let bubbleDanger = Color(red: 1.0, green: 0.3, blue: 0.2) // Red-orange
    static let bubbleCritical = Color(red: 0.9, green: 0.1, blue: 0.1) // Deep red
    
    // Role Colors
    // Standardized Manhunt palette: seeker/hunter = red, hider = blue.
    static let hunterPrimary = manhuntPrimary
    static let hunterSecondary = manhuntSecondary
    static let hiderPrimary = Color(red: 0.2, green: 0.6, blue: 1.0) // Blue
    static let hiderSecondary = Color(red: 0.4, green: 0.8, blue: 1.0) // Light blue
    
    // Status Colors
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
    static let info = Color.blue
    static let neutral = Color.gray
    
    // MARK: - Green Theme Colors (Touch Grass Brand)
    
    static let grassPrimary = Color(red: 0.2, green: 0.7, blue: 0.3) // Vibrant green
    static let grassSecondary = Color(red: 0.3, green: 0.8, blue: 0.4) // Light green
    static let grassDark = Color(red: 0.1, green: 0.5, blue: 0.2) // Dark green
    static let grassLight = Color(red: 0.4, green: 0.9, blue: 0.5) // Very light green
    
    // MARK: - Manhunt Theme Colors
    
    static let manhuntPrimary = Color(red: 0.8, green: 0.2, blue: 0.2) // Deep red
    static let manhuntSecondary = Color(red: 1.0, green: 0.3, blue: 0.3) // Bright red
    static let manhuntDark = Color(red: 0.6, green: 0.1, blue: 0.1) // Dark red
    static let manhuntLight = Color(red: 1.0, green: 0.5, blue: 0.4) // Light red-orange
    
    // MARK: - Zombie Tag Theme Colors (Dark Zombie Green)
    
    // Main zombie green - dark, sickly green like rotting vegetation
    static let zombiePrimary = Color(red: 0.133, green: 0.333, blue: 0.133) // #225522 - Dark zombie green
    static let zombieSecondary = Color(red: 0.267, green: 0.533, blue: 0.267) // #448844 - Medium zombie green
    static let zombieDark = Color(red: 0.067, green: 0.169, blue: 0.067) // #112B11 - Very dark green (shadows)
    static let zombieLight = Color(red: 0.4, green: 0.667, blue: 0.4) // #66AA66 - Light green (glow)
    static let zombieDecay = Color(red: 0.667, green: 0.733, blue: 0.267) // #AABB44 - Decay yellow-green
    
    // Human colors (blue to contrast with zombie green)
    static let humanPrimary = Color(red: 0.2, green: 0.6, blue: 1.0) // Blue (for humans)
    static let humanSecondary = Color(red: 0.4, green: 0.8, blue: 1.0) // Light blue
    
    // MARK: - Capture The Flag Theme Colors (Blue Theme)
    
    static let ctfPrimary = Color(red: 0.2, green: 0.5, blue: 1.0) // Vibrant blue
    static let ctfSecondary = Color(red: 0.3, green: 0.6, blue: 1.0) // Bright blue
    static let ctfDark = Color(red: 0.1, green: 0.3, blue: 0.8) // Dark blue
    static let ctfLight = Color(red: 0.4, green: 0.7, blue: 1.0) // Light blue
    static let ctfTeamA = Color(red: 0.2, green: 0.5, blue: 1.0) // Team A - Blue
    static let ctfTeamB = Color(red: 0.8, green: 0.3, blue: 0.2) // Team B - Red/Orange
    static let ctfTeamASecondary = Color(red: 0.3, green: 0.6, blue: 1.0) // Team A secondary
    static let ctfTeamBSecondary = Color(red: 1.0, green: 0.4, blue: 0.3) // Team B secondary
    
    // MARK: - Background Colors
    
    static let backgroundPrimary = Color(UIColor.systemBackground)
    static let backgroundSecondary = Color(UIColor.secondarySystemBackground)
    static let backgroundTertiary = Color(UIColor.tertiarySystemBackground)
    
    // Card/Overlay Colors
    static let cardBackground = Color(UIColor.secondarySystemBackground)
    static let overlayBackground = Color.black.opacity(0.6)
    
    // MARK: - Text Colors
    
    static let textPrimary = Color(UIColor.label)
    static let textSecondary = Color(UIColor.secondaryLabel)
    static let textTertiary = Color(UIColor.tertiaryLabel)
    static let textInverse = Color.white
    
    // MARK: - Bubble Gradient
    
    static func bubbleGradient(for warningLevel: GameService.WarningLevel) -> LinearGradient {
        switch warningLevel {
        case .none:
            return LinearGradient(
                colors: [bubbleSafe.opacity(0.3), bubbleSafe.opacity(0.1)],
                startPoint: .center,
                endPoint: .bottom
            )
        case .safe:
            return LinearGradient(
                colors: [bubbleWarning.opacity(0.3), bubbleWarning.opacity(0.1)],
                startPoint: .center,
                endPoint: .bottom
            )
        case .warning:
            return LinearGradient(
                colors: [bubbleDanger.opacity(0.4), bubbleDanger.opacity(0.15)],
                startPoint: .center,
                endPoint: .bottom
            )
        case .danger:
            return LinearGradient(
                colors: [bubbleCritical.opacity(0.5), bubbleCritical.opacity(0.2)],
                startPoint: .center,
                endPoint: .bottom
            )
        }
    }
    
    // MARK: - Role Gradient
    
    static func roleGradient(for role: PlayerRole) -> LinearGradient {
        switch role {
        case .hunter:
            return LinearGradient(
                colors: [hunterPrimary, hunterSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .hider:
            return LinearGradient(
                colors: [hiderPrimary, hiderSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .zombie:
            return LinearGradient(
                colors: [zombiePrimary, zombieSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .human:
            return LinearGradient(
                colors: [humanPrimary, humanSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .teamA:
            return LinearGradient(
                colors: [ctfTeamA, ctfTeamASecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .teamB:
            return LinearGradient(
                colors: [ctfTeamB, ctfTeamBSecondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // MARK: - Button Colors
    
    static let buttonPrimary = manhuntPrimary
    static let buttonSecondary = backgroundSecondary
    static let buttonTertiary = textSecondary
    
    // MARK: - Cartoon Design Tokens
    //
    // Day vocabulary: cream paper, near-black ink, sunny yellows, soft pastels.
    // Night vocabulary (dark trait): moonlit navy panels, pale moon-paper ink,
    // cool moon-gold, and muted variants of mint/rose/cloud so tinted surfaces
    // (location card, exit confirmation header, profile avatar default, etc.)
    // remain readable without inverting their *meaning*. Game/role/bubble
    // ramps are intentionally not changed, semantics stay stable at night.
    //
    // Because these are dynamic UIColors, every existing call site of the
    // form `.foregroundColor(AppColors.cartoonInk)` or
    // `.background(AppColors.cartoonCream)` inherits night mode automatically.

    static let cartoonCream   = dyn(
        light: hex(1.00, 0.980, 0.925), // #FFFAEC, cream paper
        dark:  hex(0.105, 0.137, 0.196) // #1B2332, moonlit slate panel
    )
    static let cartoonCream2  = dyn(
        light: hex(0.957, 0.925, 0.827), // #F4ECD3, warmer cream
        dark:  hex(0.149, 0.184, 0.255)  // #26304D, slightly lifted panel
    )
    static let cartoonInk     = dyn(
        light: hex(0.102, 0.102, 0.102), // #1A1A1A, near-black ink
        dark:  hex(0.937, 0.918, 0.851)  // #EFEAD9, pale moon-paper ink
    )
    static let cartoonSun     = dyn(
        light: hex(1.00, 0.839, 0.271), // #FFD645, bright sun yellow
        dark:  hex(0.961, 0.847, 0.498) // #F5D87F, cooler moon-gold
    )
    static let cartoonSun2    = dyn(
        light: hex(1.00, 0.910, 0.541), // #FFE88A, light sun
        dark:  hex(1.00, 0.890, 0.659)  // #FFE3A8, soft moonlit gold
    )
    static let cartoonMint    = dyn(
        light: hex(0.843, 0.949, 0.851), // #D7F2D9, soft mint
        dark:  hex(0.149, 0.275, 0.220)  // #264638, muted night mint
    )
    static let cartoonRose    = dyn(
        light: hex(1.00, 0.843, 0.824), // #FFD7D2, warm rose
        dark:  hex(0.302, 0.196, 0.235) // #4D323C, dusky night rose
    )
    static let cartoonCloud   = dyn(
        light: hex(0.835, 0.902, 1.00), // #D5E6FF, pale sky cloud
        dark:  hex(0.137, 0.184, 0.290) // #232F4A, deep night blue
    )

    /// Hard cartoon offset shadow. Dark warm-gray in day; in night it cools
    /// and softens so the offset doesn't read as a black brick on dark panels.
    static let cartoonShadow  = dyn(
        light: hex(0.180, 0.180, 0.180), // #2E2E2E, same as legacy Color(white: 0.18)
        dark:  hex(0.020, 0.039, 0.071)  // #050A12, deep night shadow (almost merges)
    )

    /// Text and strokes on warm light fills (`cartoonSun`, `cartoonSun2`). Same
    /// near-black in light and dark; `cartoonInk` becomes pale in dark mode and
    /// must not be used on these backgrounds (it washes out on yellow).
    static let cartoonInkOnSunFill = Color(red: 0.102, green: 0.102, blue: 0.102)

    // MARK: - Opacity Constants

    struct Opacity {
        static let light: Double = 0.1
        static let medium: Double = 0.2
        static let regular: Double = 0.3
        static let semi: Double = 0.5
        static let strong: Double = 0.7
        static let heavy: Double = 0.9
    }
    
    // MARK: - Overlay Colors
    
    static let overlayLight = Color.black.opacity(Opacity.light)
    static let overlayMedium = Color.black.opacity(Opacity.regular)
    static let overlayDark = Color.black.opacity(Opacity.semi)
    static let overlayHeavy = Color.black.opacity(Opacity.strong)
    
    // MARK: - Helper Extensions
    
    static func bubbleColor(for warningLevel: GameService.WarningLevel) -> Color {
        switch warningLevel {
        case .none: return bubbleSafe
        case .safe: return bubbleWarning
        case .warning: return bubbleDanger
        case .danger: return bubbleCritical
        }
    }
}

// MARK: - Color Extensions

extension Color {
    static let appBubbleSafe = AppColors.bubbleSafe
    static let appBubbleWarning = AppColors.bubbleWarning
    static let appBubbleDanger = AppColors.bubbleDanger
    static let appHunter = AppColors.hunterPrimary
    static let appHider = AppColors.hiderPrimary
}
