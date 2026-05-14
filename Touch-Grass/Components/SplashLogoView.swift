//
//  SplashLogoView.swift
//  Touch-Grass
//
//  Optimized splash logo view extracted from GameSelectionView
//

import SwiftUI

struct SplashLogoView: View {
    let logoGlow: CGFloat
    
    var body: some View {
        ZStack {
            // Outer glow
            Image("Touch Grass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 130)
                .blur(radius: 20 * logoGlow)
                .opacity(0.7 * logoGlow)
                .offset(y: 4)
            
            // Middle glow
            Image("Touch Grass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 130)
                .blur(radius: 10 * logoGlow)
                .opacity(0.5 * logoGlow)
                .offset(y: 2)
            
            // Main logo
            Image("Touch Grass")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 130)
                .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
                .shadow(color: AppColors.grassPrimary.opacity(0.7 * logoGlow), radius: 25 * logoGlow, x: 0, y: 0)
                .shadow(color: AppColors.grassSecondary.opacity(0.5 * logoGlow), radius: 35 * logoGlow, x: 0, y: 0)
        }
    }
}













