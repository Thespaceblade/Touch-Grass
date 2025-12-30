//
//  LoadingOverlay.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct LoadingOverlay: View {
    let message: String?
    let isVisible: Bool
    
    init(message: String? = nil, isVisible: Bool = true) {
        self.message = message
        self.isVisible = isVisible
    }
    
    var body: some View {
        if isVisible {
            ZStack {
                // Background overlay
                Color.black.opacity(AppColors.Opacity.regular)
                    .ignoresSafeArea()
                
                // Loading content
                VStack(spacing: AppSpacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppColors.manhuntPrimary))
                        .scaleEffect(1.5)
                    
                    if let message = message {
                        Text(message)
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.lg)
                    }
                }
                .padding(AppSpacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                        .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                )
                .padding(.horizontal, AppSpacing.xl)
            }
            .transition(.opacity)
            .zIndex(1000)
        }
    }
}

// MARK: - View Extension

extension View {
    func loadingOverlay(message: String? = nil, isVisible: Bool) -> some View {
        ZStack {
            self
            LoadingOverlay(message: message, isVisible: isVisible)
        }
    }
}





