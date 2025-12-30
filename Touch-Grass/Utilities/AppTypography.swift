//
//  AppTypography.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import SwiftUI

struct AppTypography {
    // MARK: - Display Fonts (Large Headers)
    
    static func displayLarge() -> Font {
        .system(size: 48, weight: .bold, design: .rounded)
    }
    
    static func displayMedium() -> Font {
        .system(size: 36, weight: .bold, design: .rounded)
    }
    
    static func displaySmall() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    // MARK: - Headline Fonts
    
    static func headlineLarge() -> Font {
        .system(size: 24, weight: .bold, design: .default)
    }
    
    static func headlineMedium() -> Font {
        .system(size: 20, weight: .semibold, design: .default)
    }
    
    static func headlineSmall() -> Font {
        .system(size: 18, weight: .semibold, design: .default)
    }
    
    // MARK: - Body Fonts
    
    static func bodyLarge() -> Font {
        .system(size: 17, weight: .regular, design: .default)
    }
    
    static func bodyMedium() -> Font {
        .system(size: 15, weight: .regular, design: .default)
    }
    
    static func bodySmall() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }
    
    // MARK: - Label Fonts
    
    static func labelLarge() -> Font {
        .system(size: 15, weight: .medium, design: .default)
    }
    
    static func labelMedium() -> Font {
        .system(size: 13, weight: .medium, design: .default)
    }
    
    static func labelSmall() -> Font {
        .system(size: 11, weight: .medium, design: .default)
    }
    
    // MARK: - Monospaced (for numbers/stats)
    
    static func statLarge() -> Font {
        .system(size: 32, weight: .bold, design: .monospaced)
    }
    
    static func statMedium() -> Font {
        .system(size: 24, weight: .semibold, design: .monospaced)
    }
    
    static func statSmall() -> Font {
        .system(size: 18, weight: .semibold, design: .monospaced)
    }
    
    // MARK: - Caption Fonts
    
    static func caption() -> Font {
        .system(size: 12, weight: .regular, design: .default)
    }
    
    static func captionSmall() -> Font {
        .system(size: 10, weight: .regular, design: .default)
    }
}

// MARK: - View Modifiers for Typography

struct TypographyModifier: ViewModifier {
    let font: Font
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

extension View {
    func appTypography(_ font: Font, color: Color = AppColors.textPrimary) -> some View {
        modifier(TypographyModifier(font: font, color: color))
    }
}