//
//  DecorativeDividerView.swift
//  Touch-Grass
//
//  Optimized decorative divider view extracted from GameSelectionView
//

import SwiftUI

struct DecorativeDividerView: View {
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // Left decorative line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clear,
                            AppColors.grassPrimary.opacity(0.5),
                            AppColors.grassSecondary.opacity(0.5),
                            AppColors.grassLight.opacity(0.4)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
            
            // Center decorative element with glow
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppColors.grassPrimary.opacity(0.3),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 2,
                            endRadius: 8
                        )
                    )
                    .frame(width: 16, height: 16)
                    .blur(radius: 4)
                
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.grassPrimary,
                                AppColors.grassSecondary,
                                AppColors.grassLight
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 8, height: 8)
                    .shadow(color: AppColors.grassPrimary.opacity(0.6), radius: 4, x: 0, y: 0)
            }
            
            // Right decorative line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.grassLight.opacity(0.4),
                            AppColors.grassPrimary.opacity(0.5),
                            AppColors.grassSecondary.opacity(0.5),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)
        }
        .allowsHitTesting(false) // TOUCH FIX: Decorative divider shouldn't block touches
    }
}



