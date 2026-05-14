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
        color: Color = AppColors.cartoonInk,
        style: CardStyle = .standard
    ) {
        self.title = title
        self.value = value
        self.icon = icon
        self.color = color
        self.style = style
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.3)
                    .foregroundColor(AppColors.cartoonInk.opacity(0.5))
            }

            Text(value)
                .font(.system(
                    size: style == .prominent ? 26 : 22,
                    weight: .black,
                    design: .monospaced
                ))
                .foregroundColor(AppColors.cartoonInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppSpacing.md)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2)
        )
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(white: 0.18)).offset(x: 3, y: 3))
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
                color: AppColors.cartoonInk
            )
            StatCard(
                title: "Distance to Edge",
                value: "45m",
                icon: "location.fill",
                color: AppColors.manhuntPrimary
            )
        }
        .padding()
        .background(AppColors.cartoonCream)
        .previewLayout(.sizeThatFits)
    }
}
