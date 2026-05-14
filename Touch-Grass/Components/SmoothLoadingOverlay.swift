//
//  SmoothLoadingOverlay.swift
//  Touch-Grass
//
//  Created on 12/30/25.
//

import SwiftUI

/// Smooth loading overlay that provides a subtle, elegant loading experience
/// Uses blur and gradient fade instead of obvious loading indicators
struct SmoothLoadingOverlay: View {
    let message: String?
    let showProgress: Bool
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var gradientOffset: CGFloat = 0.0
    
    init(message: String? = nil, showProgress: Bool = false) {
        self.message = message
        self.showProgress = showProgress
    }
    
    var body: some View {
        ZStack {
            // Background blur overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            // Subtle gradient overlay for depth
            LinearGradient(
                colors: [
                    AppColors.grassPrimary.opacity(0.1),
                    AppColors.grassPrimary.opacity(0.05),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .offset(x: gradientOffset * 100, y: gradientOffset * 50)
            
            // Optional message and progress indicator
            if message != nil || showProgress {
                VStack(spacing: AppSpacing.md) {
                    if showProgress {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppColors.grassPrimary))
                            .scaleEffect(1.2 * pulseScale)
                    }
                    
                    if let message = message {
                        Text(message)
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(AppSpacing.xl)
                .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
                .padding(.horizontal, AppSpacing.xl)
            }
        }
        .opacity(0.92)
        .onAppear {
            // Gentle pulse animation
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.05
            }
            
            // Subtle gradient movement
            withAnimation(
                .linear(duration: 4.0)
                .repeatForever(autoreverses: true)
            ) {
                gradientOffset = 0.3
            }
        }
    }
}
