//
//  HeroSectionView.swift
//  Touch-Grass
//
//  Optimized hero section view extracted from GameSelectionView
//

import SwiftUI

struct HeroSectionView: View {
    let logoGlow: CGFloat
    let pulseScale: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // Touch Grass Logo
            ZStack {
                // Outer glow effect (more pronounced for title screen)
                Image("Touch Grass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 650, maxHeight: 280)
                    .blur(radius: 20 * logoGlow)
                    .opacity(0.7 * logoGlow)
                    .offset(y: 4)
                
                // Middle glow layer
                Image("Touch Grass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 650, maxHeight: 280)
                    .blur(radius: 10 * logoGlow)
                    .opacity(0.5 * logoGlow)
                    .offset(y: 2)
                
                // Main logo (with pulsing animation)
                Image("Touch Grass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 650, maxHeight: 280)
                    .scaleEffect(pulseScale)
                    .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                    .shadow(color: AppColors.grassPrimary.opacity(0.7 * logoGlow), radius: 25 * logoGlow, x: 0, y: 0)
                    .shadow(color: AppColors.grassSecondary.opacity(0.5 * logoGlow), radius: 35 * logoGlow, x: 0, y: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .allowsHitTesting(false) // TOUCH FIX: Hero section is decorative, shouldn't block touches
    }
}



