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
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(AppSpacing.xl)
                .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
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













