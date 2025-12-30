//
//  StatCard.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String?
    let color: Color
    let style: CardStyle
    
    enum CardStyle {
        case compact
        case standard
        case prominent
    }
    
    init(
        title: String,
        value: String,
        icon: String? = nil,
        color: Color = AppColors.textPrimary,
        style: CardStyle = .standard
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.style = style
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(AppTypography.labelSmall())
                        .foregroundColor(color.opacity(0.7))
                }
                Text(title)
                    .appTypography(AppTypography.labelSmall(), color: color.opacity(0.7))
            }
            
            Text(value)
                .appTypography(
                    style == .prominent ? AppTypography.statMedium() : AppTypography.headlineSmall(),
                    color: color
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            color.opacity(0.15),
                            color.opacity(0.1),
                            color.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    color.opacity(0.4),
                                    color.opacity(0.3),
                                    color.opacity(0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: color.opacity(0.2), radius: 8, x: 0, y: 4)
                .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        )
    }
}

// MARK: - Preview

struct StatCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: AppSpacing.md) {
            StatCard(
                title: "Bubble Radius",
                value: "250m",
                icon: "circle.fill",
                color: AppColors.bubbleSafe,
                style: .prominent
            )
            
            StatCard(
                title: "Players Alive",
                value: "5/8",
                icon: "person.2.fill",
                color: AppColors.textPrimary
            )
            
            StatCard(
                title: "Distance to Edge",
                value: "45m",
                icon: "location.fill",
                color: AppColors.warning
            )
        }
        .padding()
        .background(AppColors.backgroundPrimary)
        .previewLayout(.sizeThatFits)
    }
}