//
//  AppColors.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct AppColors {
    // MARK: - Primary Game Colors
    
    // Bubble Colors (gradient from safe to danger)
    static let bubbleSafe = Color(red: 0.0, green: 0.7, blue: 1.0) // Cyan blue
    static let bubbleWarning = Color(red: 1.0, green: 0.8, blue: 0.0) // Yellow
    static let bubbleDanger = Color(red: 1.0, green: 0.3, blue: 0.2) // Red-orange
    static let bubbleCritical = Color(red: 0.9, green: 0.1, blue: 0.1) // Deep red
    
    // Role Colors
    static let hunterPrimary = Color(red: 1.0, green: 0.4, blue: 0.2) // Orange-red
    static let hunterSecondary = Color(red: 1.0, green: 0.6, blue: 0.3) // Light orange
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
