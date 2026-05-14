//
//  LobbySkeletonView.swift
//  Touch-Grass
//
//  Created on 12/31/25.
//

import SwiftUI

/// Skeleton screen for lobby views while loading
/// Shows placeholder structure with shimmer effect
struct LobbySkeletonView: View {
    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            // Game code placeholder
            VStack(spacing: AppSpacing.md) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.textSecondary.opacity(0.2))
                    .frame(height: 60)
                    .shimmer()
                
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.textSecondary.opacity(0.15))
                    .frame(height: 20)
                    .frame(width: 150)
                    .shimmer()
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.top, AppSpacing.lg)
            
            // Player list placeholder
            VStack(spacing: AppSpacing.md) {
                ForEach(0..<4) { _ in
                    HStack(spacing: AppSpacing.md) {
                        // Profile picture placeholder
                        Circle()
                            .fill(AppColors.textSecondary.opacity(0.2))
                            .frame(width: 50, height: 50)
                            .shimmer()
                        
                        // Name placeholder
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(AppColors.textSecondary.opacity(0.2))
                                .frame(height: 16)
                                .frame(width: 120)
                                .shimmer()
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(AppColors.textSecondary.opacity(0.15))
                                .frame(height: 12)
                                .frame(width: 80)
                                .shimmer()
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.backgroundPrimary.opacity(0.5))
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)
            
            Spacer()
            
            // Button placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(AppColors.textSecondary.opacity(0.2))
                .frame(height: 50)
                .padding(.horizontal, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .shimmer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}










