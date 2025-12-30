//
//  ZombieTagInfoView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ZombieTagInfoView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    // Header
                    headerSection
                    
                    // What is Zombie Tag?
                    whatIsZombieTagSection
                    
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
                        AppColors.zombiePrimary.opacity(0.1),
                        AppColors.zombieSecondary.opacity(0.05),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("ZombieTag Guide")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.zombiePrimary)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppSpacing.md) {
            // ZombieTag Logo (will use SF Symbol until logo is created)
            ZStack {
                // Glow effect
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(AppColors.zombiePrimary)
                    .blur(radius: 8)
                    .opacity(0.5)
                
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundColor(AppColors.zombiePrimary)
                    .shadow(color: AppColors.zombiePrimary.opacity(0.5), radius: 10, x: 0, y: 0)
            }
            // TODO: Replace with actual ZombieTag logo image when available
            // Image("ZombieTag")
            //     .resizable()
            //     .aspectRatio(contentMode: .fit)
            //     .frame(width: 80, height: 80)
            
            Text("Infect, Survive, Win")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.zombiePrimary,
                            AppColors.zombieSecondary
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, AppSpacing.md)
    }
    
    // MARK: - What is Zombie Tag?
    
    private var whatIsZombieTagSection: some View {
        infoSection(
            title: "What is ZombieTag?",
            icon: "questionmark.circle.fill",
            content: {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("ZombieTag is a location-based infection game where one player starts as a zombie and infects others:")
                        .font(AppTypography.bodyMedium())
                    
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Text("•")
                            .foregroundColor(AppColors.zombiePrimary)
                        Text("**Zombies**: Infect humans by tagging them. Once infected, humans become zombies and join your team.")
                            .font(AppTypography.bodyMedium())
                    }
                    
                    HStack(alignment: .top, spacing: AppSpacing.sm) {
                        Text("•")
                            .foregroundColor(AppColors.zombiePrimary)
                        Text("**Humans**: Survive as long as possible! Avoid zombies and stay alive until time runs out.")
                            .font(AppTypography.bodyMedium())
                    }
                    
                    Text("The game takes place in a shrinking play zone. As zombies infect more humans, the zombie team grows. Last human standing wins!")
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
                        description: "Set the starting radius and game duration. The zone will shrink over time, forcing players together."
                    )
                    
                    stepCard(
                        number: "3",
                        title: "Game Begins",
                        description: "One random player starts as a zombie. Everyone else is human. The infection begins!"
                    )
                    
                    stepCard(
                        number: "4",
                        title: "Infect or Survive",
                        description: "Zombies chase humans to infect them. Humans run and hide. Each infection grows the zombie team!"
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
                        role: "Zombie",
                        icon: "figure.walk.motion",
                        color: AppColors.zombiePrimary,
                        description: "Your goal is to infect all humans. Tag humans when within 10 meters to turn them into zombies. Work together with other zombies to corner humans!",
                        abilities: [
                            "See all player locations on the map",
                            "Compass points to nearest human",
                            "Distance indicator shows how far",
                            "Infect humans when within 10m",
                            "Cannot be eliminated by zone"
                        ]
                    )
                    
                    roleCard(
                        role: "Human",
                        icon: "figure.run",
                        color: AppColors.humanPrimary,
                        description: "Your goal is to survive! Avoid zombies and stay alive until time runs out. Use the compass to know when zombies are nearby and run for your life!",
                        abilities: [
                            "See all player locations on the map",
                            "Compass warns of nearby zombies",
                            "Distance indicator shows threat level",
                            "Stay within the shrinking zone",
                            "Win if time runs out with humans alive"
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
                        description: "The play zone starts large and gradually shrinks over time. Humans outside the zone are eliminated. Zombies are immune to zone elimination. The zone color changes from blue (safe) to yellow (warning) to red (danger) as it shrinks."
                    )
                    
                    mechanicCard(
                        title: "Infection System",
                        icon: "hand.tap.fill",
                        description: "Zombies infect humans by getting within 10 meters. When close enough, an 'Infect' button appears. Both players must confirm the infection via Bluetooth. Infected humans immediately become zombies and join the zombie team!"
                    )
                    
                    mechanicCard(
                        title: "Growing Zombie Team",
                        icon: "person.2.fill",
                        description: "Each human that gets infected becomes a zombie. The zombie team grows with each infection, making it harder for remaining humans to survive. Work together as zombies to corner the last humans!"
                    )
                    
                    mechanicCard(
                        title: "Game Over",
                        icon: "flag.checkered",
                        description: "The game ends when: time runs out (humans win if any survive), all humans are infected (zombies win), or all players are eliminated. Winners are determined based on survival time and infections."
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
                        title: "For Humans",
                        tips: [
                            "Stay near the center of the zone to avoid being pushed out",
                            "Use buildings and obstacles to break line of sight",
                            "Watch the compass - if it turns red, run!",
                            "Split up from other humans to make it harder for zombies",
                            "The zone will shrink - plan your escape routes",
                            "Every second counts - survive until time runs out!"
                        ]
                    )
                    
                    Divider()
                        .padding(.vertical, AppSpacing.sm)
                    
                    tipItem(
                        title: "For Zombies",
                        tips: [
                            "Work together with other zombies to corner humans",
                            "Use the compass to track the nearest human",
                            "Cut off escape routes as the zone shrinks",
                            "Spread out to cover more area",
                            "Each infection makes your team stronger",
                            "Be patient - the zone will force humans to you"
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
                    .foregroundColor(AppColors.zombiePrimary)
                
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
                                    AppColors.zombiePrimary.opacity(0.3),
                                    AppColors.zombieSecondary.opacity(0.2)
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
                                    AppColors.zombiePrimary,
                                    AppColors.zombieSecondary
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
                .foregroundColor(AppColors.zombiePrimary)
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
                .fill(AppColors.zombiePrimary.opacity(0.05))
        )
    }
    
    private func tipItem(title: String, tips: [String]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppColors.zombiePrimary)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                        Text("•")
                            .foregroundColor(AppColors.zombiePrimary)
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

