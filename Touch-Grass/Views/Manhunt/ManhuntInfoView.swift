//
//  ManhuntInfoView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ManhuntInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Header
                    headerSection
                    
                    // What is Manhunt?
                    whatIsManhuntSection
                    
                    // How It Works
                    howItWorksSection
                    
                    // Roles
                    rolesSection
                    
                    // Game Mechanics
                    gameMechanicsSection
                    
                    // Tips & Strategy
                    tipsSection
                }
                .padding(AppSpacing.lg)
            }
            .background(
                LinearGradient(
                    colors: [
                        AppColors.manhuntPrimary.opacity(0.1),
                        AppColors.manhuntSecondary.opacity(0.05),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Manhunt Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.manhuntPrimary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            // Manhunt Logo
            ZStack {
                // Glow effect
                Image("Manhunt")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .blur(radius: 8)
                    .opacity(0.5)
                
                Image("Manhunt")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .shadow(color: AppColors.manhuntPrimary.opacity(0.5), radius: 10, x: 0, y: 0)
            }
            
            Text("Run, Hide, Survive")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.manhuntPrimary,
                            AppColors.manhuntSecondary
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppSpacing.md)
    }
    
    // MARK: - What is Manhunt?
    
    private var whatIsManhuntSection: some View {
        infoSection(
            title: "What is Manhunt?",
            icon: "questionmark.circle.fill",
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Manhunt is a location-based hide & seek game where players are divided into two teams:")
                        .font(AppTypography.bodyMedium())
                    
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Text("•")
                            .foregroundColor(AppColors.manhuntPrimary)
                        Text("**Hunters**: Track down and catch hiders using proximity detection")
                            .font(AppTypography.bodyMedium())
                    }
                    
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Text("•")
                            .foregroundColor(AppColors.manhuntPrimary)
                        Text("**Hiders**: Evade hunters and stay alive as long as possible")
                            .font(AppTypography.bodyMedium())
                    }
                    
                    Text("The game takes place in a shrinking play zone that forces players closer together, creating intense, fast-paced gameplay.")
                        .font(AppTypography.bodyMedium())
                        .padding(.top, AppSpacing.xs)
                }
            }
        )
    }
    
    // MARK: - How It Works
    
    private var howItWorksSection: some View {
        infoSection(
            title: "How It Works",
            icon: "play.circle.fill",
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    stepCard(
                        number: "1",
                        title: "Create or Join a Game",
                        description: "Host creates a session and shares the join code. Players join using the code."
                    )
                    
                    stepCard(
                        number: "2",
                        title: "Configure the Play Zone",
                        description: "Set the starting radius, ending radius, and game duration. The zone will shrink over time."
                    )
                    
                    stepCard(
                        number: "3",
                        title: "Assign Roles",
                        description: "Choose how many hunters vs hiders. The host can manually assign roles or let the app assign them."
                    )
                    
                    stepCard(
                        number: "4",
                        title: "Begin the Hunt",
                        description: "Once the game starts, all players' locations are shared in real-time. Hunters chase, hiders hide!"
                    )
                }
            }
        )
    }
    
    // MARK: - Roles
    
    private var rolesSection: some View {
        infoSection(
            title: "Roles",
            icon: "person.2.fill",
            content: {
                VStack(spacing: AppSpacing.md) {
                    roleCard(
                        role: "Hunter",
                        icon: "target",
                        color: AppColors.manhuntPrimary,
                        description: "Your goal is to catch hiders by getting within 10 meters of them. Use the map to track hider locations and the compass to find the nearest target.",
                        abilities: [
                            "See all player locations on the map",
                            "Compass points to nearest hider",
                            "Distance indicator shows how far",
                            "Tag hiders when within 10m"
                        ]
                    )
                    
                    roleCard(
                        role: "Hider",
                        icon: "eye.slash.fill",
                        color: AppColors.hiderPrimary,
                        description: "Your goal is to survive as long as possible. Avoid hunters, stay within the play zone, and use the compass to know when danger is near.",
                        abilities: [
                            "See all player locations on the map",
                            "Compass warns of nearby hunters",
                            "Distance indicator shows threat level",
                            "Stay within the shrinking zone"
                        ]
                    )
                }
            }
        )
    }
    
    // MARK: - Game Mechanics
    
    private var gameMechanicsSection: some View {
        infoSection(
            title: "Game Mechanics",
            icon: "gearshape.fill",
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    mechanicCard(
                        title: "Shrinking Play Zone",
                        icon: "circle.grid.cross.fill",
                        description: "The play zone starts large and gradually shrinks over time. Players outside the zone are eliminated. The zone color changes from blue (safe) to yellow (warning) to red (danger) as it shrinks."
                    )
                    
                    mechanicCard(
                        title: "Proximity Catching",
                        icon: "location.fill",
                        description: "Hunters catch hiders by getting within 10 meters. When close enough, a tag button appears. Both players must confirm the tag via Bluetooth for it to count."
                    )
                    
                    mechanicCard(
                        title: "Elimination",
                        icon: "xmark.circle.fill",
                        description: "Players are eliminated if they leave the play zone or are caught by a hunter. Eliminated players enter spectator mode and can watch the rest of the game."
                    )
                    
                    mechanicCard(
                        title: "Game Over",
                        icon: "flag.checkered",
                        description: "The game ends when: time runs out, all hiders are caught, or all players are eliminated. Winners are determined based on survival time and catches."
                    )
                }
            }
        )
    }
    
    // MARK: - Tips & Strategy
    
    private var tipsSection: some View {
        infoSection(
            title: "Tips & Strategy",
            icon: "lightbulb.fill",
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    tipItem(
                        title: "For Hiders",
                        tips: [
                            "Stay near the center of the zone to avoid being pushed out",
                            "Use buildings and obstacles to break line of sight",
                            "Watch the compass - if it turns red, run!",
                            "Move strategically, not randomly"
                        ]
                    )
                    
                    Divider()
                        .padding(.vertical, AppSpacing.sm)
                    
                    tipItem(
                        title: "For Hunters",
                        tips: [
                            "Work together to corner hiders",
                            "Use the compass to track the nearest target",
                            "Cut off escape routes as the zone shrinks",
                            "Be patient - the zone will force hiders to you"
                        ]
                    )
                }
            }
        )
    }
    
    // MARK: - Helper Views
    
    private func infoSection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(AppColors.manhuntPrimary)
                
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            content()
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppColors.manhuntPrimary.opacity(0.3),
                                    AppColors.manhuntSecondary.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
    
    private func stepCard(number: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            // Number badge
            Text(number)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.manhuntPrimary,
                                    AppColors.manhuntSecondary
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    private func roleCard(role: String, icon: String, color: Color, description: String, abilities: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Text(role)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }
            
            Text(description)
                .font(AppTypography.bodyMedium())
                .foregroundColor(AppColors.textSecondary)
            
            Divider()
                .padding(.vertical, AppSpacing.xs)
            
            Text("Abilities:")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.textPrimary)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(abilities, id: \.self) { ability in
                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(color)
                        Text(ability)
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func mechanicCard(title: String, icon: String, description: String) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(AppColors.manhuntPrimary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                
                Text(description)
                    .font(AppTypography.bodySmall())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.manhuntPrimary.opacity(0.05))
        )
    }
    
    private func tipItem(title: String, tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.manhuntPrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                        Text("•")
                            .foregroundColor(AppColors.manhuntPrimary)
                            .fontWeight(.bold)
                        Text(tip)
                            .font(AppTypography.bodyMedium())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }
        }
    }
}


