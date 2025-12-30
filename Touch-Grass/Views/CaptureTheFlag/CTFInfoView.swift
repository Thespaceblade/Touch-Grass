//
//  CTFInfoView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct CTFInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // CTF-themed background
                LinearGradient(
                    colors: [
                        AppColors.ctfPrimary.opacity(0.1),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        // Header
                        VStack(spacing: AppSpacing.sm) {
                            Image("CTF")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 64, height: 64)
                            
                            Text("Capture The Flag")
                                .font(AppTypography.displaySmall())
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.ctfPrimary, AppColors.ctfSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .padding(.top, AppSpacing.xl)
                        
                        // Rules Section
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("How to Play")
                                .font(AppTypography.headlineMedium())
                                .foregroundColor(AppColors.textPrimary)
                            
                            ruleCard(
                                icon: "person.2.fill",
                                title: "Teams",
                                description: "Players are split into two teams: Team A (Blue) and Team B (Red). The field is divided by a halfway line with each team's side tinted in their color."
                            )
                            
                            ruleCard(
                                icon: "flag.fill",
                                title: "Flag Players",
                                description: "Each team designates one player as their flag. These flag players choose their starting position before the game begins. The flag player is marked on the map with a flag icon in their team's color."
                            )
                            
                            ruleCard(
                                icon: "mappin.circle.fill",
                                title: "Flag Placement",
                                description: "Before the game starts, flag players move to their desired location and tap 'Place Flag Here' to set their starting position. All players wait for both flags to be placed, then a countdown begins!"
                            )
                            
                            ruleCard(
                                icon: "hand.raised.fill",
                                title: "Capture",
                                description: "Get close to the enemy flag player (when they're at their base) to capture them. The flag player will be marked as captured and you'll carry them with you."
                            )
                            
                            ruleCard(
                                icon: "arrow.uturn.backward",
                                title: "Return",
                                description: "If your team's flag player is captured, get close to them to return them to their base. They'll be freed and can be captured again."
                            )
                            
                            ruleCard(
                                icon: "target",
                                title: "Score",
                                description: "Bring both flags (yours and the enemy's) to your team's safe zone to win!"
                            )
                            
                            ruleCard(
                                icon: "xmark.circle.fill",
                                title: "Tagging",
                                description: "If you're tagged by an enemy player while carrying a flag, you drop the flag player at your location and are temporarily out. The flag player can then be returned by their team or recaptured by the enemy."
                            )
                            
                            ruleCard(
                                icon: "eye.fill",
                                title: "Map Features",
                                description: "The map shows a halfway line dividing the field, team-tinted sides (blue and red), and flag players with colored flag icons. Team bases are marked on the map."
                            )
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        Spacer()
                            .frame(height: AppSpacing.xl)
                    }
                }
            }
            .navigationTitle("Game Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.ctfPrimary)
                }
            }
        }
    }
    
    private func ruleCard(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(AppColors.ctfPrimary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(AppTypography.labelLarge())
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textSecondary)
            }
            
            Spacer()
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.ctfPrimary.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

