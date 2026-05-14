//
//  ButtonStyles.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import UIKit

// MARK: - Tap Depression Helper

/// Keeps pressed visuals on screen briefly enough for normal quick taps to read.
/// SwiftUI's `configuration.isPressed` can flip back too quickly for the cartoon
/// "button face sinks into shadow" effect to be visible on tap.
struct TapDepressionStateView<Content: View>: View {
    let isPressed: Bool
    var minimumDuration: TimeInterval = 0.12
    @ViewBuilder let content: (Bool) -> Content

    @State private var visualPressed = false
    @State private var pressedBeganAt: Date?
    @State private var releaseTask: Task<Void, Never>?

    var body: some View {
        content(visualPressed)
            .onAppear {
                updateVisualPressed(isPressed)
            }
            .onChange(of: isPressed) { _, newValue in
                updateVisualPressed(newValue)
            }
            .onDisappear {
                releaseTask?.cancel()
            }
    }

    private func updateVisualPressed(_ pressed: Bool) {
        releaseTask?.cancel()

        if pressed {
            pressedBeganAt = Date()
            visualPressed = true
            return
        }

        let elapsed = pressedBeganAt.map { Date().timeIntervalSince($0) } ?? minimumDuration
        let remaining = max(0, minimumDuration - elapsed)

        releaseTask = Task { @MainActor in
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            visualPressed = false
            pressedBeganAt = nil
        }
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    var accentColor: Color = AppColors.manhuntPrimary
    var isDisabled: Bool = false
    private let offset: CGFloat = 5
    
    func makeBody(configuration: Configuration) -> some View {
        TapDepressionStateView(isPressed: configuration.isPressed) { visualPressed in
            configuration.label
                .foregroundColor(isDisabled ? Color.white.opacity(0.7) : .white)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(isDisabled ? Color(white: 0.85) : accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppColors.cartoonInk, lineWidth: 2.5)
                )
                .scaleEffect(visualPressed ? 0.96 : 1.0)
                .offset(
                    x: visualPressed ? offset : 0,
                    y: visualPressed ? offset : 0
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppColors.cartoonShadow)
                        .offset(x: offset, y: offset)
                )
                .opacity(isDisabled ? 0.65 : 1.0)
                .onChange(of: configuration.isPressed) { _, isPressed in
                    if isPressed && !isDisabled {
                        HapticFeedbackManager.shared.impact(style: .medium)
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.72), value: visualPressed)
        }
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    var accentColor: Color = AppColors.manhuntPrimary
    private let offset: CGFloat = 4
    
    func makeBody(configuration: Configuration) -> some View {
        TapDepressionStateView(isPressed: configuration.isPressed) { visualPressed in
            configuration.label
                .foregroundColor(AppColors.cartoonInk)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(0.5)
                .textCase(.uppercase)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .background(AppColors.cartoonCream)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.cartoonInk, lineWidth: 2)
                )
                .scaleEffect(visualPressed ? 0.96 : 1.0)
                .offset(
                    x: visualPressed ? offset : 0,
                    y: visualPressed ? offset : 0
                )
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.cartoonShadow)
                        .offset(x: offset, y: offset)
                )
                .onChange(of: configuration.isPressed) { _, isPressed in
                    if isPressed {
                        HapticFeedbackManager.shared.impact(style: .light)
                    }
                }
                .animation(.spring(response: 0.2, dampingFraction: 0.72), value: visualPressed)
        }
    }
}

// MARK: - Icon Button Style

struct IconButtonStyle: ButtonStyle {
    var size: CGFloat = 40
    var color: Color = AppColors.manhuntPrimary
    var backgroundColor: Color? = nil
    private let offset: CGFloat = 3
    
    func makeBody(configuration: Configuration) -> some View {
        TapDepressionStateView(isPressed: configuration.isPressed, minimumDuration: 0.1) { visualPressed in
            configuration.label
                .frame(width: size, height: size)
                .background(backgroundColor ?? color)
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))
                .offset(
                    x: visualPressed ? offset : 0,
                    y: visualPressed ? offset : 0
                )
                .background(
                    Circle()
                        .fill(AppColors.cartoonShadow)
                        .offset(x: offset, y: offset)
                )
                .onChange(of: configuration.isPressed) { _, isPressed in
                    if isPressed {
                        HapticFeedbackManager.shared.impact(style: .light)
                    }
                }
                .animation(.linear(duration: 0.08), value: visualPressed)
        }
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
            // OPTIMIZATION: Single, fast scale animation for instant feedback
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            // OPTIMIZATION: Subtle brightness for visual feedback without competing animations
            .brightness(configuration.isPressed ? -0.1 : 0)
            // OPTIMIZATION: Remove overlays - they cause animation conflicts
            // OPTIMIZATION: Simplified shadow for better performance
            .shadow(
                color: accentColor.opacity(configuration.isPressed ? 0.6 : 0.4),
                radius: configuration.isPressed ? 12 : 20,
                x: 0,
                y: configuration.isPressed ? 3 : 6
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    // OPTIMIZATION: Light haptic feels more responsive
                    HapticFeedbackManager.shared.impact(style: .light)
                }
            }
            // OPTIMIZATION: Fast spring animation (0.1s) for instant feel
            .animation(.spring(response: 0.1, dampingFraction: 0.7), value: configuration.isPressed)
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

// MARK: - Cartoon Card Button Style

/// Press-effect style for cards that self-style their own background/border.
/// Adds the background shadow rect and sinks the card face on press.
struct CartoonCardButtonStyle: ButtonStyle {
    var isDisabled: Bool = false
    var cornerRadius: CGFloat = 18
    private let offset: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        TapDepressionStateView(isPressed: configuration.isPressed) { visualPressed in
            configuration.label
                .scaleEffect(visualPressed ? 0.97 : 1.0)
                .offset(
                    x: visualPressed ? offset : 0,
                    y: visualPressed ? offset : 0
                )
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(AppColors.cartoonShadow)
                        .offset(x: offset, y: offset)
                )
                .animation(.spring(response: 0.2, dampingFraction: 0.72), value: visualPressed)
                .onChange(of: configuration.isPressed) { _, pressed in
                    if pressed && !isDisabled {
                        HapticFeedbackManager.shared.impact(style: .light)
                    }
                }
        }
    }
}

// MARK: - Back Button Style (for lobby back buttons)

struct BackButtonStyle: ButtonStyle {
    var accentColor: Color = AppColors.manhuntPrimary
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Subtle scale (5% smaller)
            .brightness(configuration.isPressed ? -0.25 : 0) // Stronger brightness change
            .opacity(configuration.isPressed ? 0.7 : 1.0) // More noticeable opacity change
            .overlay(
                // Flash overlay on press - more visible
                Capsule()
                    .fill(accentColor.opacity(configuration.isPressed ? 0.6 : 0))
                    .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
            )
            .overlay(
                // White flash for extra visibility
                Capsule()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.4 : 0))
                    .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            )
            .shadow(
                color: accentColor.opacity(configuration.isPressed ? 0.7 : 0.2),
                radius: configuration.isPressed ? 10 : 4,
                x: 0,
                y: configuration.isPressed ? 1 : 1
            )
            .shadow(
                color: Color.black.opacity(configuration.isPressed ? 0.3 : 0.1),
                radius: configuration.isPressed ? 6 : 2,
                x: 0,
                y: configuration.isPressed ? 1 : 1
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticFeedbackManager.shared.impact(style: .medium)
                }
            }
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed) // Snappier animation
    }
}
