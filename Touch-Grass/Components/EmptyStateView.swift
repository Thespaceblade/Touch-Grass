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
            CartoonMedallion(background: AppColors.grassPrimary, size: 72, borderWidth: 2.5) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .symbolEffect(.pulse, options: .repeating.speed(0.5))
            
            Text(title)
                .font(.system(size: 25, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 19, weight: .black, design: .rounded))
                        Text(actionTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                .buttonStyle(CartoonButtonStyle(accent: AppColors.grassPrimary))
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 500)
        .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
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













