//
//  AestheticBackground.swift
//  Touch-Grass
//
//  A subtle gradient wash layered over the persistent `LandscapeBackground`
//  in `ContentView` and several lobbies. In day mode it ties everything
//  to the grass-green brand with a soft warm wash. In night mode it
//  becomes a near-transparent cool moonlit wash so the night landscape
//  (moon, stars, silhouettes) reads through cleanly instead of being
//  flattened by an opaque green-on-dark tint.
//

import SwiftUI

struct AestheticBackground: View {
    let gradientOffset: CGFloat // Not used, but kept for API compatibility
    let pulseScale: CGFloat // Not used, but kept for API compatibility

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false) // TOUCH FIX: Don't block touches - background shouldn't intercept
    }

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            // Night: barely-there cool wash so the moon/stars/silhouettes
            // dominate. No opaque bottom stop, let the landscape breathe.
            return [
                AppColors.ctfPrimary.opacity(0.05),
                AppColors.grassPrimary.opacity(0.03),
                Color.clear
            ]
        } else {
            // Day: warm grass-tinted wash that anchors content to a soft
            // surface and prevents a stark white flash during transitions.
            return [
                AppColors.grassPrimary.opacity(0.12),
                AppColors.grassSecondary.opacity(0.08),
                AppColors.backgroundPrimary
            ]
        }
    }
}
