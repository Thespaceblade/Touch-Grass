//
//  ManhuntRoleManagementView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ManhuntHunterManagementView: View {
    let session: GameSession
    let currentPlayer: Player?
    let onSetHunter: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    private var currentHunters: [Player] {
        session.players.filter { $0.role == .hunter }
    }
    
    private var currentHiders: [Player] {
        session.players.filter { $0.role == .hider }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeBackgroundView(
                    primaryColor: AppColors.hunterPrimary,
                    secondaryColor: AppColors.hunterSecondary,
                    lightColor: AppColors.manhuntLight
                )
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        VStack(spacing: AppSpacing.md) {
                            CartoonConfigurationHero(
                                iconName: "target",
                                title: "Manage Hunters",
                                subtitle: "Tap players to switch Hunter and Hider roles.",
                                badge: "Target: \(session.hunterCount) hunter\(session.hunterCount == 1 ? "" : "s")",
                                accent: AppColors.hunterPrimary
                            )
                            
                            roleMatchupCard
                            
                            // Balance status
                            let ratio = currentHunters.count > 0 ? Double(currentHiders.count) / Double(currentHunters.count) : 0
                            let isBalanced = ratio >= 1.0 && ratio <= 3.0 // 1:1 to 1:3 ratio is balanced
                            
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(isBalanced ? AppColors.success : AppColors.warning)
                                    .font(.caption)
                                Text(isBalanced ? "Balanced teams" : "Unbalanced - adjust roles")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(AppColors.cartoonInk)
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                Capsule()
                                    .fill((isBalanced ? AppColors.success : AppColors.warning).opacity(0.15))
                            )
                            .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 1.5))
                            
                            Text("Target: \(session.hunterCount) hunter\(session.hunterCount == 1 ? "" : "s")")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk.opacity(0.62))
                        }
                        .padding(.top, AppSpacing.md)
                        
                        // Hunters Section
                        if !currentHunters.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                roleSectionHeader(
                                    title: "Hunters",
                                    count: currentHunters.count,
                                    iconName: "figure.walk.motion",
                                    accent: AppColors.hunterPrimary
                                )
                                
                                ForEach(currentHunters) { player in
                                    playerRow(player: player, isHunter: true)
                                }
                            }
                            .padding(AppSpacing.md)
                            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
                        }
                        
                        // Hiders Section
                        if !currentHiders.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                roleSectionHeader(
                                    title: "Hiders",
                                    count: currentHiders.count,
                                    iconName: "figure.run",
                                    accent: AppColors.hiderPrimary
                                )
                                
                                ForEach(currentHiders) { player in
                                    playerRow(player: player, isHunter: false)
                                }
                            }
                            .padding(AppSpacing.md)
                            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
                        }
                        
                        // Info Text
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppColors.hunterPrimary)
                                    .font(.caption)
                                Text("Tap a player to toggle their role")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                            }
                            
                            if currentHunters.count != session.hunterCount {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption)
                                    Text("Current hunter count (\(currentHunters.count)) doesn't match target (\(session.hunterCount))")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(AppColors.cartoonInk.opacity(0.72))
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .cartoonCard(cornerRadius: 14, shadowOffset: 3, borderWidth: 2)
                        
                        Spacer()
                            .frame(height: AppSpacing.lg)
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
                .safeAreaPadding(.bottom, AppSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var roleMatchupCard: some View {
        HStack(spacing: AppSpacing.md) {
            roleCountTile(
                title: "Hunters",
                count: currentHunters.count,
                iconName: "target",
                accent: AppColors.hunterPrimary
            )
            
            Text("VS")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .tracking(0.8)
                .foregroundColor(AppColors.cartoonInkOnSunFill)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(AppColors.cartoonSun)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(AppColors.cartoonInkOnSunFill, lineWidth: 2))
            
            roleCountTile(
                title: "Hiders",
                count: currentHiders.count,
                iconName: "eye.slash.fill",
                accent: AppColors.hiderPrimary
            )
        }
        .padding(AppSpacing.sm)
        .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
    }
    
    private func roleCountTile(title: String, count: Int, iconName: String, accent: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            CartoonMedallion(background: accent, size: 34) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text("\(count)")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(1)
            
            Text(title)
                .font(.system(size: 11, weight: .black, design: .rounded))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundColor(AppColors.cartoonInk.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .background(accent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.cartoonInk.opacity(0.7), lineWidth: 1.5)
        )
    }
    
    private func roleSectionHeader(title: String, count: Int, iconName: String, accent: Color) -> some View {
        HStack(spacing: AppSpacing.sm) {
            CartoonMedallion(background: accent, size: 32) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundColor(AppColors.cartoonInk)
            
            Spacer()
            
            CartoonPill(text: "\(count)", color: accent)
        }
    }
    
    private func playerRow(player: Player, isHunter: Bool) -> some View {
        Button(action: {
            onSetHunter(player.id)
        }) {
            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: isHunter ? AppColors.hunterPrimary : AppColors.hiderPrimary, size: 32) {
                    Image(systemName: isHunter ? "target" : "eye.slash.fill")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                // Player name
                Text(player.displayName)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer()
                
                // Current role badge
                CartoonPill(text: isHunter ? "Hunter" : "Hider", color: isHunter ? AppColors.hunterPrimary : AppColors.hiderPrimary)
                
                // You badge
                if player.id == currentPlayer?.id {
                    CartoonPill(text: "You", color: AppColors.cartoonSun, textColor: AppColors.cartoonInkOnSunFill, strokeColor: AppColors.cartoonInkOnSunFill)
                }
                
                // Toggle icon
                CartoonMedallion(background: AppColors.cartoonSun, size: 30) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                }
            }
            .padding(AppSpacing.sm)
            .cartoonCard(cornerRadius: 12, shadowOffset: 3, borderWidth: 1.75)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
