//
//  CTFTeamManagementView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import UIKit

struct CTFTeamManagementView: View {
    let session: GameSession
    let currentPlayer: Player?
    let onSetTeam: (String, Flag.Team) -> Void
    let onSetFlag: (String, Bool) -> Void // playerId, isFlag
    let onSetTeamLeader: (String, Bool) -> Void // playerId, isTeamLeader
    
    @Environment(\.dismiss) var dismiss
    
    private var teamAPlayers: [Player] {
        session.players.filter { $0.role == .teamA }
    }
    
    private var teamBPlayers: [Player] {
        session.players.filter { $0.role == .teamB }
    }
    
    private var teamAFlagPlayer: Player? {
        session.players.first { $0.role == .teamA && $0.isFlag }
    }
    
    private var teamBFlagPlayer: Player? {
        session.players.first { $0.role == .teamB && $0.isFlag }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeBackgroundView(
                    primaryColor: AppColors.ctfPrimary,
                    secondaryColor: AppColors.ctfSecondary,
                    lightColor: AppColors.ctfLight
                )
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        VStack(spacing: AppSpacing.sm) {
                            CartoonConfigurationHero(
                                iconName: "flag.2.crossed.fill",
                                title: "Manage Teams",
                                subtitle: "Move players, choose flag players, and assign leaders.",
                                badge: "A \(teamAPlayers.count)  |  B \(teamBPlayers.count)",
                                accent: AppColors.ctfPrimary
                            )
                            
                            if abs(teamAPlayers.count - teamBPlayers.count) > 1 {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption)
                                    Text("Teams are unbalanced")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.warning)
                                }
                            }
                        }
                        .padding(.top, AppSpacing.md)
                        
                        // Team A Section
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(AppColors.ctfTeamA)
                                Text("Team A")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.ctfTeamA)
                                Spacer()
                                Text("\(teamAPlayers.count)")
                                    .font(AppTypography.labelMedium())
                                    .foregroundColor(AppColors.ctfTeamA)
                            }
                            
                            if teamAPlayers.isEmpty {
                                Text("No players assigned")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.vertical, AppSpacing.sm)
                            } else {
                                ForEach(teamAPlayers) { player in
                                    playerRow(player: player, team: .teamA)
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
                        
                        // Team B Section
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(AppColors.ctfTeamB)
                                Text("Team B")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.ctfTeamB)
                                Spacer()
                                Text("\(teamBPlayers.count)")
                                    .font(AppTypography.labelMedium())
                                    .foregroundColor(AppColors.ctfTeamB)
                            }
                            
                            if teamBPlayers.isEmpty {
                                Text("No players assigned")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textTertiary)
                                    .padding(.vertical, AppSpacing.sm)
                            } else {
                                ForEach(teamBPlayers) { player in
                                    playerRow(player: player, team: .teamB)
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
                        
                        // Flag Designation Info
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "flag.fill")
                                    .foregroundColor(AppColors.ctfPrimary)
                                    .font(.caption)
                                Text("Flag Players")
                                    .font(AppTypography.labelMedium())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            
                            Text("Each team needs 1 player to be the flag. Tap the flag icon next to a player to designate them as the flag.")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                            
                            if teamAFlagPlayer == nil || teamBFlagPlayer == nil {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption)
                                    Text(teamAFlagPlayer == nil && teamBFlagPlayer == nil ? "Both teams need a flag player" : teamAFlagPlayer == nil ? "Team A needs a flag player" : "Team B needs a flag player")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.warning)
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .cartoonCard(cornerRadius: 14, shadowOffset: 3, borderWidth: 2)
                        
                        // Team Leader Designation Info
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(AppColors.ctfPrimary)
                                    .font(.caption)
                                Text("Team Leaders")
                                    .font(AppTypography.labelMedium())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            
                            Text("Each team needs 1 leader to place the safe zone. Only the host can designate team leaders. Tap the star icon next to a player to make them the team leader.")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                            
                            let teamALeader = session.players.first { $0.role == .teamA && $0.isTeamLeader }
                            let teamBLeader = session.players.first { $0.role == .teamB && $0.isTeamLeader }
                            
                            if teamALeader == nil || teamBLeader == nil {
                                HStack(spacing: AppSpacing.xs) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppColors.warning)
                                        .font(.caption)
                                    Text(teamALeader == nil && teamBLeader == nil ? "Both teams need a leader" : teamALeader == nil ? "Team A needs a leader" : "Team B needs a leader")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.warning)
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .cartoonCard(cornerRadius: 14, shadowOffset: 3, borderWidth: 2)
                        
                        // Info Text
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            HStack(spacing: AppSpacing.xs) {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.caption)
                                Text("Tap a player to move them to the other team")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textSecondary)
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
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.ctfPrimary)
                }
            }
        }
    }
    
    private func playerRow(player: Player, team: Flag.Team) -> some View {
        let isCurrentTeamFlag = (team == .teamA && teamAFlagPlayer?.id == player.id) || (team == .teamB && teamBFlagPlayer?.id == player.id)
        let canBeFlag = player.id == currentPlayer?.id || currentPlayer?.id == session.hostId // Only self or host can set flag
        let isHost = currentPlayer?.id == session.hostId // Only host can set team leader
        let isCurrentTeamLeader = session.players.first { $0.role == (team == .teamA ? .teamA : .teamB) && $0.isTeamLeader }?.id == player.id
        
        return HStack(spacing: AppSpacing.sm) {
            // Flag designation button (only for players on this team)
            if canBeFlag {
                Button(action: {
                    // Toggle flag status
                    let newFlagStatus = !player.isFlag
                    onSetFlag(player.id, newFlagStatus)
                }) {
                    Image(systemName: player.isFlag ? "flag.fill" : "flag")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(isCurrentTeamFlag ? (team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB) : AppColors.cartoonInk.opacity(0.45))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Show flag icon if this player is the flag (read-only)
                if isCurrentTeamFlag {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB)
                        .frame(width: 32, height: 32)
                } else {
                    Spacer()
                        .frame(width: 32, height: 32)
                }
            }
            
            // Team leader designation button (only host can set)
            if isHost {
                Button(action: {
                    // Toggle team leader status
                    let newLeaderStatus = !player.isTeamLeader
                    onSetTeamLeader(player.id, newLeaderStatus)
                }) {
                    Image(systemName: player.isTeamLeader ? "star.fill" : "star")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(isCurrentTeamLeader ? (team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB) : AppColors.cartoonInk.opacity(0.45))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                // Show star icon if this player is the team leader (read-only)
                if isCurrentTeamLeader {
                    Image(systemName: "star.fill")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB)
                        .frame(width: 32, height: 32)
                } else {
                    Spacer()
                        .frame(width: 32, height: 32)
                }
            }
            
            // Team indicator
            Circle()
                .fill(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB)
                .frame(width: 16, height: 16)
            
            // Profile picture
            Group {
                if let profilePicBase64 = player.profilePictureBase64,
                   let imageData = Data(base64Encoded: profilePicBase64),
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB, lineWidth: 2)
                        )
                } else {
                    // Placeholder if no profile picture
                    Image(systemName: "person.fill")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.55))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppColors.cartoonCream2)
                                .overlay(
                                    Circle()
                                        .stroke(team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB, lineWidth: 2)
                                )
                        )
                }
            }
            
            // Player name
            Text(player.displayName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            
            Spacer()
            
            // Flag badge
            if isCurrentTeamFlag {
                CartoonPill(text: "FLAG", color: team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB)
            }
            
            // You badge
            if player.id == currentPlayer?.id {
                CartoonPill(text: "You", color: AppColors.cartoonSun, textColor: AppColors.cartoonInk)
            }
            
            // Toggle team button
            Button(action: {
                // Move to opposite team
                let newTeam: Flag.Team = team == .teamA ? .teamB : .teamA
                onSetTeam(player.id, newTeam)
            }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.55))
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(AppSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppColors.cartoonCream2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isCurrentTeamFlag ? (team == .teamA ? AppColors.ctfTeamA : AppColors.ctfTeamB) : AppColors.cartoonInk.opacity(0.55), lineWidth: isCurrentTeamFlag ? 2 : 1.5)
                )
        )
    }
}
