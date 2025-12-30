//
//  AestheticBackground.swift
//  Touch-Grass
//
//  Optimized background view extracted from GameSelectionView for better performance
//

import SwiftUI

struct AestheticBackground: View {
    let gradientOffset: CGFloat // Not used, but kept for API compatibility
    let pulseScale: CGFloat // Not used, but kept for API compatibility
    
    var body: some View {
        // Static background gradient - no animations for best performance
        LinearGradient(
            colors: [
                AppColors.grassPrimary.opacity(0.12),
                AppColors.grassSecondary.opacity(0.08),
                AppColors.backgroundPrimary
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false) // TOUCH FIX: Don't block touches - background shouldn't intercept
    }
}

