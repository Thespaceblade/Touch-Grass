//
//  ZombieTagRoleManagementView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ZombieTagRoleManagementView: View {
    let session: GameSession
    let currentPlayer: Player?
    let onSetZombie: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    private var currentZombies: [Player] {
        session.players.filter { $0.role == .zombie }
    }
    
    private var currentHumans: [Player] {
        session.players.filter { $0.role == .human }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeBackgroundView(
                    primaryColor: AppColors.zombiePrimary,
                    secondaryColor: AppColors.zombieSecondary,
                    lightColor: AppColors.zombieLight
                )
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        CartoonConfigurationHero(
                            iconName: "figure.walk.motion",
                            title: "Manage Zombies",
                            subtitle: "Tap players to switch Zombie and Human roles.",
                            badge: "Target: \(session.hunterCount) zombie\(session.hunterCount == 1 ? "" : "s")",
                            accent: AppColors.zombiePrimary
                        )
                        .padding(.top, AppSpacing.md)
                        
                        roleMatchupCard
                        
                        // Zombies Section
                        if !currentZombies.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                roleSectionHeader(
                                    title: "Zombies",
                                    count: currentZombies.count,
                                    iconName: "figure.walk.motion",
                                    accent: AppColors.zombiePrimary
                                )
                                
                                ForEach(currentZombies) { player in
                                    playerRow(player: player, isZombie: true)
                                }
                            }
                            .padding(AppSpacing.md)
                            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
                        }
                        
                        // Humans Section
                        if !currentHumans.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                roleSectionHeader(
                                    title: "Humans",
                                    count: currentHumans.count,
                                    iconName: "figure.run",
                                    accent: AppColors.humanPrimary
                                )
                                
                                ForEach(currentHumans) { player in
                                    playerRow(player: player, isZombie: false)
                                }
                            }
                            .padding(AppSpacing.md)
                            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
                        }
                        
                        // Info Text
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppColors.zombiePrimary)
                                    .font(.caption)
                                Text("Tap a player to toggle their role")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                            }
                            
                            if currentZombies.count != session.hunterCount {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption)
                                    Text("Current zombie count (\(currentZombies.count)) doesn't match target (\(session.hunterCount))")
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
                    CartoonSheetToolbarButton(
                        title: "Done",
                        systemImage: "checkmark",
                        style: .primary,
                        accent: AppColors.zombiePrimary,
                        action: { dismiss() }
                    )
                }
            }
        }
    }
    
    private var roleMatchupCard: some View {
        HStack(spacing: AppSpacing.md) {
            roleCountTile(
                title: "Zombies",
                count: currentZombies.count,
                iconName: "figure.walk.motion",
                accent: AppColors.zombiePrimary
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
                title: "Humans",
                count: currentHumans.count,
                iconName: "figure.run",
                accent: AppColors.humanPrimary
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
    
    private func playerRow(player: Player, isZombie: Bool) -> some View {
        Button(action: {
            onSetZombie(player.id)
        }) {
            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: isZombie ? AppColors.zombiePrimary : AppColors.humanPrimary, size: 32) {
                    Image(systemName: isZombie ? "figure.walk.motion" : "figure.run")
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
                CartoonPill(text: isZombie ? "Zombie" : "Human", color: isZombie ? AppColors.zombiePrimary : AppColors.humanPrimary)
                
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
