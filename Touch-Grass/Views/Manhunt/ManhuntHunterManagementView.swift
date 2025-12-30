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
                // Background
                LinearGradient(
                    colors: [
                        AppColors.hunterPrimary.opacity(0.1),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Header Info
                        VStack(spacing: AppSpacing.md) {
                            Text("Manage Hunters")
                                .font(AppTypography.displaySmall())
                                .foregroundColor(AppColors.textPrimary)
                            
                            // Visual balance indicator
                            HStack(spacing: AppSpacing.lg) {
                                // Hunters
                                VStack(spacing: AppSpacing.xs) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "target")
                                            .font(.caption)
                                            .foregroundColor(AppColors.hunterPrimary)
                                        Text("\(currentHunters.count)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(AppColors.hunterPrimary)
                                    }
                                    Text("Hunters")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.hunterPrimary.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.hunterPrimary.opacity(0.3), lineWidth: 2)
                                        )
                                )
                                
                                // VS divider
                                Text("vs")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textTertiary)
                                
                                // Hiders
                                VStack(spacing: AppSpacing.xs) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "eye.slash.fill")
                                            .font(.caption)
                                            .foregroundColor(AppColors.hiderPrimary)
                                        Text("\(currentHiders.count)")
                                            .font(.system(size: 24, weight: .bold))
                                            .foregroundColor(AppColors.hiderPrimary)
                                    }
                                    Text("Hiders")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                }
                                .padding(.horizontal, AppSpacing.md)
                                .padding(.vertical, AppSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.hiderPrimary.opacity(0.15))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(AppColors.hiderPrimary.opacity(0.3), lineWidth: 2)
                                        )
                                )
                            }
                            
                            // Balance status
                            let ratio = currentHunters.count > 0 ? Double(currentHiders.count) / Double(currentHunters.count) : 0
                            let isBalanced = ratio >= 1.0 && ratio <= 3.0 // 1:1 to 1:3 ratio is balanced
                            
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: isBalanced ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(isBalanced ? AppColors.success : AppColors.warning)
                                    .font(.caption)
                                Text(isBalanced ? "Balanced teams" : "Unbalanced - adjust roles")
                                    .font(AppTypography.caption())
                                    .foregroundColor(isBalanced ? AppColors.success : AppColors.warning)
                            }
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(
                                Capsule()
                                    .fill((isBalanced ? AppColors.success : AppColors.warning).opacity(0.15))
                            )
                            
                            Text("Target: \(session.hunterCount) hunter\(session.hunterCount == 1 ? "" : "s")")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.top, AppSpacing.md)
                        
                        // Hunters Section
                        if !currentHunters.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Image(systemName: "figure.walk.motion")
                                        .foregroundColor(AppColors.hunterPrimary)
                                    Text("Hunters")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(currentHunters.count)")
                                        .font(AppTypography.labelMedium())
                                        .foregroundColor(AppColors.hunterPrimary)
                                }
                                
                                ForEach(currentHunters) { player in
                                    playerRow(player: player, isHunter: true)
                                }
                            }
                            .padding(AppSpacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                            )
                        }
                        
                        // Hiders Section
                        if !currentHiders.isEmpty {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Image(systemName: "figure.run")
                                        .foregroundColor(AppColors.hiderPrimary)
                                    Text("Hiders")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text("\(currentHiders.count)")
                                        .font(AppTypography.labelMedium())
                                        .foregroundColor(AppColors.hiderPrimary)
                                }
                                
                                ForEach(currentHiders) { player in
                                    playerRow(player: player, isHunter: false)
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
                            
                            if currentHunters.count != session.hunterCount {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption)
                                    Text("Current hunter count (\(currentHunters.count)) doesn't match target (\(session.hunterCount))")
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
                        .foregroundColor(AppColors.hunterPrimary)
                }
            }
        }
    }
    
    private func playerRow(player: Player, isHunter: Bool) -> some View {
        Button(action: {
            onSetHunter(player.id)
        }) {
            HStack(spacing: AppSpacing.sm) {
                // Role indicator
                Circle()
                    .fill(isHunter ? AppColors.hunterPrimary : AppColors.hiderPrimary)
                    .frame(width: 16, height: 16)
                
                // Player name
                Text(player.displayName)
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                // Current role badge
                Text(isHunter ? "Hunter" : "Hider")
                    .font(AppTypography.caption())
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isHunter ? AppColors.hunterPrimary : AppColors.hiderPrimary)
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
                                .fill(AppColors.hunterPrimary)
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