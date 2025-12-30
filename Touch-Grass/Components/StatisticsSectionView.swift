//
//  StatisticsSectionView.swift
//  Touch-Grass
//
//  Optimized statistics section view extracted from ProfileView
//

import SwiftUI

struct StatisticsSectionView: View {
    let animatedGamesPlayed: Int
    let animatedWins: Int
    let totalPlaytime: TimeInterval
    let totalGamesPlayed: Int
    let totalWins: Int
    
    private func formatPlaytime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.xs) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary.opacity(0.2),
                                    AppColors.grassSecondary.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(AppColors.grassPrimary)
                        .font(.system(size: 18, weight: .semibold))
                }
                
                Text("Statistics")
                    .font(AppTypography.headlineMedium())
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppColors.grassPrimary,
                                AppColors.grassSecondary
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: AppSpacing.md) {
                StatCard(
                    title: "Games Played",
                    value: "\(animatedGamesPlayed)",
                    icon: "gamecontroller.fill",
                    color: AppColors.grassPrimary,
                    style: .standard
                )
                
                StatCard(
                    title: "Wins",
                    value: "\(animatedWins)",
                    icon: "trophy.fill",
                    color: AppColors.grassSecondary,
                    style: .standard
                )
                
                StatCard(
                    title: "Total Playtime",
                    value: formatPlaytime(totalPlaytime),
                    icon: "clock.fill",
                    color: AppColors.manhuntPrimary,
                    style: .standard
                )
                
                StatCard(
                    title: "Win Rate",
                    value: totalGamesPlayed > 0 ? "\(Int((Double(totalWins) / Double(totalGamesPlayed)) * 100))%" : "0%",
                    icon: "chart.bar.fill",
                    color: AppColors.ctfPrimary,
                    style: .standard
                )
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.grassPrimary.opacity(0.1),
                            AppColors.grassSecondary.opacity(0.08),
                            AppColors.backgroundPrimary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary.opacity(0.4),
                                    AppColors.grassSecondary.opacity(0.3),
                                    AppColors.grassLight.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: AppColors.grassPrimary.opacity(0.2), radius: 12, x: 0, y: 6)
                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        )
    }
}

