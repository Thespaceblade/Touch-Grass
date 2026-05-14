//
//  AchievementsListView.swift
//  Touch-Grass
//
//  Full list of local achievements with section grouping.
//

import SwiftUI

struct AchievementsListView: View {
    @ObservedObject private var profileService = ProfileService.shared

    var body: some View {
        let stats = profileService.achievementStatsSnapshot()
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(AchievementSection.allCases, id: \.self) { section in
                    let defs = AchievementCatalog.definitions.filter { $0.section == section }
                    if !defs.isEmpty {
                        sectionBlock(section: section, definitions: defs, stats: stats)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
        }
        .navigationTitle("Achievements")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionBlock(
        section: AchievementSection,
        definitions: [AchievementDefinition],
        stats: ProfileAchievementStats
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(section.rawValue)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                .textCase(.uppercase)
                .tracking(0.6)

            CartoonCard(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(definitions.enumerated()), id: \.element.id) { index, def in
                        achievementRow(definition: def, stats: stats, isLast: index == definitions.count - 1)
                    }
                }
            }
        }
    }

    private func achievementRow(
        definition def: AchievementDefinition,
        stats: ProfileAchievementStats,
        isLast: Bool
    ) -> some View {
        let unlocked = def.isUnlocked(stats)
        let color = accentColor(for: def.section)

        return HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle()
                    .fill(unlocked ? color.opacity(0.18) : AppColors.cartoonInk.opacity(0.07))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle().stroke(
                            unlocked ? color : AppColors.cartoonInk.opacity(0.18),
                            lineWidth: 2
                        )
                    )
                Image(systemName: def.iconSystemName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(unlocked ? color : AppColors.cartoonInk.opacity(0.22))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(def.title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(
                        unlocked ? AppColors.cartoonInk : AppColors.cartoonInk.opacity(0.35)
                    )
                Text(def.description)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.45))
                if let progressText = progressSubtitle(def: def, stats: stats) {
                    Text(progressText)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.5))
                }
            }

            Spacer()

            if unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.2))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(AppColors.cartoonInk.opacity(0.12))
                    .frame(height: 1.5)
            }
        }
    }

    private func accentColor(for section: AchievementSection) -> Color {
        switch section {
        case .general: return AppColors.grassPrimary
        case .manhunt: return AppColors.manhuntPrimary
        case .zombieTag: return AppColors.zombiePrimary
        case .captureTheFlag: return AppColors.ctfPrimary
        }
    }

    private func progressSubtitle(def: AchievementDefinition, stats: ProfileAchievementStats) -> String? {
        guard let p = def.progress(stats), p.target > 0 else { return nil }
        if def.id == .marathonRunner {
            let ch = p.current / 3600
            let th = p.target / 3600
            return "\(ch) / \(th) hr"
        }
        return "\(p.current) / \(p.target)"
    }
}

#Preview {
    NavigationStack {
        AchievementsListView()
    }
}
