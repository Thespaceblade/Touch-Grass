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
    var maxLogoHeight: CGFloat = 220
    
    var body: some View {
        VStack(spacing: 0) {
            // Touch Grass Logo
            ZStack {
                Image("Touch Grass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 650, maxHeight: maxLogoHeight)
                    .scaleEffect(pulseScale)
                    .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
            }
            .drawingGroup()
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .allowsHitTesting(false)
    }
}

