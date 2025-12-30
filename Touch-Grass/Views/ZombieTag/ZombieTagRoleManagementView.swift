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
                // Background
                LinearGradient(
                    colors: [
                        AppColors.zombiePrimary.opacity(0.1),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Header Info
                        VStack(spacing: AppSpacing.sm) {
                            Text("Manage Zombies")
                                .font(AppTypography.displaySmall())
                                .foregroundColor(AppColors.textPrimary)
                            
                            Text("Current: \(currentZombies.count) zombie\(currentZombies.count == 1 ? "" : "s")")
                                .font(AppTypography.bodyMedium())
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text("Target: \(session.hunterCount) zombie\(session.hunterCount == 1 ? "" : "s")")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.top, AppSpacing.md)
                        
                        // Zombies Section
                        if !currentZombies.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Image(systemName: "figure.walk.motion")
                                        .foregroundColor(AppColors.zombiePrimary)
                                    Text("Zombies")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(currentZombies.count)")
                                        .font(AppTypography.labelMedium())
                                        .foregroundColor(AppColors.zombiePrimary)
                                }
                                
                                ForEach(currentZombies) { player in
                                    playerRow(player: player, isZombie: true)
                                }
                            }
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                            )
                        }
                        
                        // Humans Section
                        if !currentHumans.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Image(systemName: "figure.run")
                                        .foregroundColor(AppColors.humanPrimary)
                                    Text("Humans")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(currentHumans.count)")
                                        .font(AppTypography.labelMedium())
                                        .foregroundColor(AppColors.humanPrimary)
                                }
                                
                                ForEach(currentHumans) { player in
                                    playerRow(player: player, isZombie: false)
                                }
                            }
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                            )
                        }
                        
                        // Info Text
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.caption)
                                Text("Tap a player to toggle their role")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
                            }
                            
                            if currentZombies.count != session.hunterCount {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption)
                                    Text("Current zombie count (\(currentZombies.count)) doesn't match target (\(session.hunterCount))")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.warning)
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(AppColors.backgroundSecondary)
                        )
                        
                        Spacer()
                            .frame(height: AppSpacing.lg)
                    }
                    .padding(.horizontal, AppSpacing.md)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(AppColors.zombiePrimary)
                }
            }
        }
    }
    
    private func playerRow(player: Player, isZombie: Bool) -> some View {
        Button(action: {
            onSetZombie(player.id)
        }) {
            HStack(spacing: AppSpacing.sm) {
                // Role indicator
                Circle()
                    .fill(isZombie ? AppColors.zombiePrimary : AppColors.humanPrimary)
                    .frame(width: 16, height: 16)
                
                // Player name
                Text(player.displayName)
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Current role badge
                Text(isZombie ? "Zombie" : "Human")
                    .font(AppTypography.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isZombie ? AppColors.zombiePrimary : AppColors.humanPrimary)
                    )
                
                // You badge
                if player.id == currentPlayer?.id {
                    Text("You")
                        .font(AppTypography.caption())
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(AppColors.zombiePrimary)
                        )
                }
                
                // Toggle icon
                Image(systemName: "arrow.left.arrow.right")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppColors.backgroundSecondary)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}