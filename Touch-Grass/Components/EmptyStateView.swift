//
//  EmptyStateView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppColors.manhuntPrimary,
                            AppColors.manhuntSecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .symbolEffect(.pulse, options: .repeating.speed(0.5))
            
            // Title
            Text(title)
                .font(AppTypography.headlineLarge())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(AppTypography.bodyMedium())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            
            // Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                        Text(actionTitle)
                            .font(AppTypography.labelLarge())
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.vertical, AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.manhuntPrimary,
                                        AppColors.manhuntSecondary
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 500)
    }
}

// MARK: - Predefined Empty States

extension EmptyStateView {
    static func noPlayers(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "person.2.fill",
            title: "No Players Yet",
            message: "Invite friends to join your game session",
            actionTitle: "Invite Players",
            action: action
        )
    }
    
    static func noGames(action: @escaping () -> Void) -> EmptyStateView {
        EmptyStateView(
            icon: "gamecontroller.fill",
            title: "No Games Found",
            message: "Create a new game or join an existing one",
            actionTitle: "Create Game",
            action: action
        )
    }
    
    static func noHistory() -> EmptyStateView {
        EmptyStateView(
            icon: "clock.fill",
            title: "No Game History",
            message: "Your completed games will appear here"
        )
    }
}





