//
//  ButtonStyles.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import UIKit

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    var accentColor: Color = AppColors.manhuntPrimary
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [
                                accentColor,
                                accentColor == AppColors.manhuntPrimary ? AppColors.manhuntSecondary : accentColor.opacity(0.8)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(
                        color: accentColor.opacity(isDisabled ? 0 : AppColors.Opacity.regular),
                        radius: configuration.isPressed ? 8 : 12,
                        x: 0,
                        y: configuration.isPressed ? 3 : 6
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(isDisabled ? 0.6 : 1.0)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && !isDisabled {
                    HapticFeedbackManager.shared.impact(style: .medium)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    var accentColor: Color = AppColors.manhuntPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(accentColor)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(
                Capsule()
                    .fill(accentColor.opacity(AppColors.Opacity.light))
                    .overlay(
                        Capsule()
                            .stroke(accentColor.opacity(AppColors.Opacity.regular), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.impact(style: .light)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 40
    var color: Color = AppColors.manhuntPrimary
    var backgroundColor: Color? = nil
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(backgroundColor ?? color.opacity(AppColors.Opacity.light))
                    .shadow(
                        color: Color.black.opacity(configuration.isPressed ? 0.1 : 0.2),
                        radius: configuration.isPressed ? 2 : 3,
                        x: 0,
                        y: configuration.isPressed ? 1 : 2
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.impact(style: .light)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Scale Button Style (for game cards)

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.impact(style: .light)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Premium Card Button Style (for game cards with glow)

struct PremiumCardButtonStyle: ButtonStyle {
    var accentColor: Color = AppColors.grassPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .shadow(
                color: accentColor.opacity(configuration.isPressed ? 0.4 : 0.5),
                radius: configuration.isPressed ? 8 : 15,
                x: 0,
                y: configuration.isPressed ? 3 : 8
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.15 : 0.2),
                radius: configuration.isPressed ? 5 : 10,
                x: 0,
                y: configuration.isPressed ? 2 : 5
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.impact(style: .medium)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Ripple Button Style

struct RippleButtonStyle: ButtonStyle {
    var accentColor: Color = AppColors.grassPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .overlay(
                Circle()
                    .fill(accentColor.opacity(0.3))
                    .frame(width: configuration.isPressed ? 200 : 0, height: configuration.isPressed ? 200 : 0)
                    .opacity(configuration.isPressed ? 0 : 1)
                    .animation(.easeOut(duration: 0.4), value: configuration.isPressed)
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.impact(style: .light)
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}


