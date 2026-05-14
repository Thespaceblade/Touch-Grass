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
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Section header
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 15, weight: .black))
                    .foregroundColor(AppColors.cartoonInk)
                Text("Statistics")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
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
                    color: AppColors.cartoonSun,
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
                    value: totalGamesPlayed > 0
                        ? "\(Int((Double(totalWins) / Double(totalGamesPlayed)) * 100))%"
                        : "0%",
                    icon: "chart.bar.fill",
                    color: AppColors.ctfPrimary,
                    style: .standard
                )
            }
        }
    }
}
