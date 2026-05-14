//
//  ThemeBackgroundView.swift
//  Touch-Grass
//
//  Dynamic theme-colored background for lobby views with shared cached landscape
//

import SwiftUI

struct ThemeBackgroundView: View {
    let primaryColor: Color
    let secondaryColor: Color
    let lightColor: Color
    
    var body: some View {
        ZStack {
            // Base gradient with theme colors (shows through landscape)
            LinearGradient(
                colors: [
                    primaryColor.opacity(0.3),
                    secondaryColor.opacity(0.2),
                    lightColor.opacity(0.15),
                    AppColors.backgroundPrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Reuse cached landscape background (rendered once, shared across all lobbies)
            LandscapeBackground()
                .opacity(0.6) // Let theme color show through
                .drawingGroup() // Cache as bitmap - renders once and reuses
                .allowsHitTesting(false)
            
            // Subtle color overlay to reinforce theme
            LinearGradient(
                colors: [
                    primaryColor.opacity(0.15),
                    Color.clear,
                    secondaryColor.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
