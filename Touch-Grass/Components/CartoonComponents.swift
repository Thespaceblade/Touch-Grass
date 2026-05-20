//
//  CartoonComponents.swift
//  Touch-Grass
//
//  Cartoon design system primitives.
//  Vocabulary: cream surface, 2.5px ink stroke, hard offset shadow.
//
//  Shadow technique: a plain filled RoundedRect (no border) sits as a
//  .background() behind every card/button, offset down-right. Only the
//  narrow strip that peeks past the card edge is visible, no duplicate
//  outline, no "two boxes" look.
//

import SwiftUI
import CoreLocation

// MARK: - Tokens

private let inkColor    = AppColors.cartoonInk
private let creamColor  = AppColors.cartoonCream
// Dynamic: dark warm-gray in day, cool near-black in night so the offset
// doesn't read as a hard black brick on dark panels.
private var shadowColor: Color { AppColors.cartoonShadow }

// MARK: - Helpers

/// Plain shadow shape used by every component.
private func shadowRect(cornerRadius: CGFloat, offset: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        .fill(shadowColor)
        .offset(x: offset, y: offset)
}

private func shadowCapsule(offset: CGFloat) -> some View {
    Capsule()
        .fill(shadowColor)
        .offset(x: offset, y: offset)
}

private func shadowCircle(offset: CGFloat) -> some View {
    Circle()
        .fill(shadowColor)
        .offset(x: offset, y: offset)
}

// MARK: - CartoonCardStyle (ViewModifier)

struct CartoonCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    var shadowOffset: CGFloat = 5
    var borderWidth: CGFloat  = 2.5

    func body(content: Content) -> some View {
        content
            .background(creamColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(inkColor, lineWidth: borderWidth)
            )
            .background(shadowRect(cornerRadius: cornerRadius, offset: shadowOffset))
    }
}

extension View {
    func cartoonCard(
        cornerRadius: CGFloat = 16,
        shadowOffset: CGFloat = 5,
        borderWidth: CGFloat = 2.5
    ) -> some View {
        modifier(CartoonCardStyle(
            cornerRadius: cornerRadius,
            shadowOffset: shadowOffset,
            borderWidth: borderWidth
        ))
    }
}

// MARK: - CartoonCard

struct CartoonCard<Content: View>: View {
    var padding: CGFloat    = 14
    var cornerRadius: CGFloat = 16
    var shadowOffset: CGFloat = 5
    var borderWidth: CGFloat  = 2.5
    var background: Color     = AppColors.cartoonCream
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(inkColor, lineWidth: borderWidth)
            )
            .background(shadowRect(cornerRadius: cornerRadius, offset: shadowOffset))
    }
}

// MARK: - AnimatedEllipsisText

/// Inline label that cycles a trailing ellipsis (`.` → `..` → `...`) on a
/// short cadence to communicate ongoing waiting. Inherits `font`,
/// `foregroundColor`, and other Text-environment modifiers from the
/// enclosing view, so it drops in wherever a `Text` would.
struct AnimatedEllipsisText: View {
    let text: String
    let period: TimeInterval

    init(_ text: String, period: TimeInterval = 0.45) {
        self.text = text
        self.period = period
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: period)) { context in
            let step = Int(context.date.timeIntervalSinceReferenceDate / period) % 3
            Text(text + String(repeating: ".", count: step + 1))
        }
    }
}

// MARK: - Themed Exit Lobby Confirmation

struct ThemedExitLobbyConfirmationOverlay: View {
    @Binding var isPresented: Bool
    let primaryColor: Color
    let secondaryColor: Color
    let iconName: String
    /// When true, copy warns that leaving will end the session for
    /// everyone (host path). Non-hosts get reassuring "you're just
    /// leaving" copy and the lobby continues for the rest of the players.
    var isHost: Bool = false
    let onConfirm: () -> Void

    private var bodyMessage: String {
        isHost
            ? "Leaving will end the game for everyone in this lobby."
            : "You'll leave this lobby and head back to the game picker."
    }

    private var confirmTitle: String {
        isHost ? "End Game" : "Leave Lobby"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            CartoonCard(padding: 0, cornerRadius: 18, shadowOffset: 6) {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: AppSpacing.md) {
                        Text("Exit Lobby?")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                            .multilineTextAlignment(.center)

                        Text(bodyMessage)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: AppSpacing.sm) {
                            Button {
                                dismiss()
                            } label: {
                                Label("Stay Here", systemImage: "arrow.uturn.left")
                            }
                            .buttonStyle(SecondaryButtonStyle(accentColor: primaryColor))

                            Button {
                                isPresented = false
                                HapticFeedbackManager.shared.warning()
                                onConfirm()
                            } label: {
                                Label(confirmTitle, systemImage: "rectangle.portrait.and.arrow.right")
                            }
                            .buttonStyle(PrimaryButtonStyle(accentColor: primaryColor))
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(AppColors.cartoonInk)
                    .frame(width: 48, height: 48)
                    .background(AppColors.cartoonCream)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Lobby in Progress")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text("Are you sure?")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
        }
        .frame(height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2.5)
        )
    }

    private func dismiss() {
        HapticFeedbackManager.shared.selection()
        isPresented = false
    }
}

// MARK: - Themed In-Game Confirmation

/// Full-screen dim + cartoon card for destructive or high-stakes in-game actions (e.g. manual tag confirm).
struct ThemedInGameConfirmationOverlay: View {
    @Binding var isPresented: Bool
    let primaryColor: Color
    let secondaryColor: Color
    let iconName: String
    let headerTitle: String
    let headerSubtitle: String
    let title: String
    let message: String
    let cancelTitle: String
    let confirmTitle: String
    let confirmAccentColor: Color
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture {
                    dismiss()
                }

            CartoonCard(padding: 0, cornerRadius: 18, shadowOffset: 6) {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: AppSpacing.md) {
                        Text(title)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                            .multilineTextAlignment(.center)

                        Text(message)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.78))
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(spacing: AppSpacing.sm) {
                            Button {
                                dismiss()
                            } label: {
                                Label(cancelTitle, systemImage: "arrow.uturn.left")
                            }
                            .buttonStyle(SecondaryButtonStyle(accentColor: primaryColor))

                            Button {
                                isPresented = false
                                HapticFeedbackManager.shared.warning()
                                onConfirm()
                            } label: {
                                Label(confirmTitle, systemImage: "hand.raised.fill")
                            }
                            .buttonStyle(PrimaryButtonStyle(accentColor: confirmAccentColor))
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private var header: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [primaryColor, secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            HStack(spacing: AppSpacing.sm) {
                Image(systemName: iconName)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(AppColors.cartoonInk)
                    .frame(width: 48, height: 48)
                    .background(AppColors.cartoonCream)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(headerTitle)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)

                    Text(headerSubtitle)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
        }
        .frame(height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(AppColors.cartoonInk, lineWidth: 2.5)
        )
    }

    private func dismiss() {
        HapticFeedbackManager.shared.selection()
        isPresented = false
    }
}

extension View {
    func themedExitLobbyConfirmation(
        isPresented: Binding<Bool>,
        primaryColor: Color,
        secondaryColor: Color,
        iconName: String,
        isHost: Bool = false,
        onConfirm: @escaping () -> Void
    ) -> some View {
        cartoonPopupOverlay(isPresented: isPresented) {
            ThemedExitLobbyConfirmationOverlay(
                isPresented: isPresented,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                iconName: iconName,
                isHost: isHost,
                onConfirm: onConfirm
            )
        }
    }

    func themedInGameConfirmation(
        isPresented: Binding<Bool>,
        primaryColor: Color,
        secondaryColor: Color,
        iconName: String,
        headerTitle: String,
        headerSubtitle: String,
        title: String,
        message: String,
        cancelTitle: String,
        confirmTitle: String,
        confirmAccentColor: Color,
        onConfirm: @escaping () -> Void
    ) -> some View {
        cartoonPopupOverlay(isPresented: isPresented) {
            ThemedInGameConfirmationOverlay(
                isPresented: isPresented,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                iconName: iconName,
                headerTitle: headerTitle,
                headerSubtitle: headerSubtitle,
                title: title,
                message: message,
                cancelTitle: cancelTitle,
                confirmTitle: confirmTitle,
                confirmAccentColor: confirmAccentColor,
                onConfirm: onConfirm
            )
        }
    }
}

// MARK: - CartoonButtonStyle

struct CartoonButtonStyle: ButtonStyle {
    var accent: Color      = AppColors.grassPrimary
    var textColor: Color   = .white
    /// When non-nil, used for the ink stroke instead of dynamic `cartoonInk` (e.g. dark stroke on `cartoonSun` fills in night mode).
    var borderColor: Color? = nil
    var isDisabled: Bool   = false
    var borderWidth: CGFloat = 2.5
    var cornerRadius: CGFloat = 16
    private let offset: CGFloat = 5

    func makeBody(configuration: Configuration) -> some View {
        let strokeColor = borderColor ?? inkColor
        return TapDepressionStateView(isPressed: configuration.isPressed) { visualPressed in
            configuration.label
                .foregroundColor(isDisabled ? Color.white.opacity(0.7) : textColor)
                .font(.system(size: 19, weight: .black, design: .rounded))
                .tracking(0.6)
                .textCase(.uppercase)
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(isDisabled ? Color(white: 0.85) : accent)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(strokeColor, lineWidth: borderWidth)
                )
                // Squish down on press; spring back with slight overshoot on release
                .scaleEffect(visualPressed ? 0.96 : 1.0)
                // Face sinks toward shadow when pressed
                .offset(
                    x: visualPressed ? offset : 0,
                    y: visualPressed ? offset : 0
                )
                // Shadow sits at layout position, face slides on top of it when pressed
                .background(shadowRect(cornerRadius: cornerRadius, offset: offset))
                .opacity(isDisabled ? 0.65 : 1)
                // Fast press-down, springy pop-back on release
                .animation(.spring(response: 0.2, dampingFraction: 0.72), value: visualPressed)
                .onChange(of: configuration.isPressed) { _, pressed in
                    if pressed && !isDisabled {
                        HapticFeedbackManager.shared.impact(style: .medium)
                    }
                }
        }
    }
}

// MARK: - CartoonSecondaryButtonStyle

struct CartoonSecondaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = 14
    var borderWidth: CGFloat  = 2.0
    private let offset: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        TapDepressionStateView(isPressed: configuration.isPressed) { visualPressed in
            configuration.label
                .foregroundColor(inkColor)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(0.5)
                .textCase(.uppercase)
                .padding(.vertical, 12)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity)
                .background(creamColor)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(inkColor, lineWidth: borderWidth)
                )
                .scaleEffect(visualPressed ? 0.96 : 1.0)
                .offset(
                    x: visualPressed ? offset : 0,
                    y: visualPressed ? offset : 0
                )
                .background(shadowRect(cornerRadius: cornerRadius, offset: offset))
                .animation(.spring(response: 0.2, dampingFraction: 0.72), value: visualPressed)
                .onChange(of: configuration.isPressed) { _, pressed in
                    if pressed {
                        HapticFeedbackManager.shared.impact(style: .light)
                    }
                }
        }
    }
}

// MARK: - CartoonSheetToolbarButton

/// Compact cartoon-styled toolbar button for sheet dismissal (Cancel /
/// Done). Mirrors the inline pattern already used in
/// `ZombieTagRoleManagementView` so every themed sheet across the app
/// can share one component instead of duplicating the HStack + style.
struct CartoonSheetToolbarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                Text(title)
            }
        }
        .buttonStyle(CartoonSecondaryButtonStyle(cornerRadius: 12))
    }
}

// MARK: - CartoonPill

struct CartoonPill: View {
    let text: String
    var color: Color = AppColors.grassPrimary
    var textColor: Color = .white
    /// When non-nil, used for the capsule stroke instead of dynamic `cartoonInk`.
    var strokeColor: Color? = nil

    var body: some View {
        let border = strokeColor ?? inkColor
        return Text(text)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .tracking(0.7)
            .textCase(.uppercase)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .foregroundColor(textColor)
            .padding(.vertical, 4)
            .padding(.horizontal, 11)
            .background(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 2))
            .background(shadowCapsule(offset: 2.5))
    }
}

// MARK: - CartoonLobbyActionCard

struct CartoonLobbyActionCard: View {
    let iconName: String
    let title: String
    let subtitle: String
    let accent: Color
    var trailingIconName: String = "chevron.right"

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 27, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonCream)
                .frame(width: 46, height: 46)
                .background(
                    Circle()
                        .fill(accent)
                        .overlay(Circle().stroke(inkColor, lineWidth: 2))
                )

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundColor(inkColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(inkColor.opacity(0.62))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppSpacing.xs)

            Image(systemName: trailingIconName)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(accent)
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
        .background(creamColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(inkColor, lineWidth: 2)
        )
        .background(shadowRect(cornerRadius: 16, offset: 4))
    }
}

// MARK: - Cartoon Join Code Badge

struct CartoonJoinCodeBadge: View {
    let code: String
    let accent: Color

    var body: some View {
        Text(code)
            .font(.system(size: 22, weight: .black, design: .monospaced))
            .foregroundColor(accent)
            .tracking(2)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(AppColors.cartoonCream2)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(inkColor, lineWidth: 2)
            )
            .background(shadowRect(cornerRadius: 12, offset: 3))
    }
}

// MARK: - Cartoon Lobby Icon Button

struct CartoonLobbyIconButtonLabel: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundColor(.white)
    }
}

// MARK: - Location Permission Card

struct LocationPermissionCard: View {
    @ObservedObject var locationService: LocationService
    let accent: Color
    var onRequestAdditionalPermissions: (() -> Void)? = nil

    var body: some View {
        if !locationService.hasRequiredGamePermission {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    CartoonMedallion(background: accent, size: 46) {
                        Image(systemName: iconName)
                            .font(.system(size: 21, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text(title)
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .tracking(0.4)
                            .textCase(.uppercase)
                            .foregroundColor(AppColors.cartoonInkOnSunFill)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)

                        Text(message)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInkOnSunFill.opacity(0.78))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: AppSpacing.sm) {
                    permissionStep(number: "1", label: "While Using", isComplete: didCompleteStepOne, isActive: locationService.authorization == .notDetermined)

                    Rectangle()
                        .fill(AppColors.cartoonInkOnSunFill.opacity(0.22))
                        .frame(height: 2)

                    permissionStep(number: "2", label: "Always", isComplete: locationService.authorization == .authorizedAlways, isActive: locationService.authorization == .authorizedWhenInUse)
                }

                Button(action: {
                    HapticFeedbackManager.shared.selection()
                    locationService.requestPermission()
                    onRequestAdditionalPermissions?()
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: buttonIconName)
                        Text(buttonTitle)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(CartoonButtonStyle(accent: accent, textColor: .white, cornerRadius: 14))
            }
            .padding(AppSpacing.md)
            .background(AppColors.cartoonSun2)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppColors.cartoonInkOnSunFill, lineWidth: 2.5)
            )
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppColors.cartoonShadow)
                    .offset(x: 5, y: 5)
            )
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
    }

    private var didCompleteStepOne: Bool {
        locationService.authorization == .authorizedWhenInUse || locationService.authorization == .authorizedAlways
    }

    private var title: String {
        switch locationService.authorization {
        case .notDetermined:
            return "Location Required"
        case .authorizedWhenInUse:
            return "Finish Location Setup"
        case .authorizedAlways:
            return "Finding GPS"
        case .denied, .restricted:
            return "Location Blocked"
        @unknown default:
            return "Location Required"
        }
    }

    private var message: String {
        switch locationService.authorization {
        case .notDetermined:
            return "Step 1 of 2: choose Allow While Using App."
        case .authorizedWhenInUse:
            return "Step 2 of 2: tap again and choose Change to Always Allow."
        case .authorizedAlways:
            return "Permission is ready. Keep this open while GPS finds your position."
        case .denied, .restricted:
            return "Open Settings and set Location to Always before starting."
        @unknown default:
            return "Location is required before starting."
        }
    }

    private var buttonTitle: String {
        switch locationService.authorization {
        case .notDetermined:
            return "Start Step 1"
        case .authorizedWhenInUse:
            return "Start Step 2"
        case .authorizedAlways:
            return "Refresh GPS"
        case .denied, .restricted:
            return "Open Settings"
        @unknown default:
            return "Enable Location"
        }
    }

    private var iconName: String {
        switch locationService.authorization {
        case .denied, .restricted:
            return "exclamationmark.triangle.fill"
        case .authorizedWhenInUse:
            return "location.badge.plus"
        default:
            return "location.fill"
        }
    }

    private var buttonIconName: String {
        switch locationService.authorization {
        case .denied, .restricted:
            return "gearshape.fill"
        case .authorizedAlways:
            return "location.viewfinder"
        default:
            return "location.fill"
        }
    }

    private func permissionStep(number: String, label: String, isComplete: Bool, isActive: Bool) -> some View {
        HStack(spacing: 6) {
            Text(isComplete ? "✓" : number)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(isComplete || isActive ? .white : AppColors.cartoonInk.opacity(0.55))
                .frame(width: 24, height: 24)
                .background(isComplete ? AppColors.success : (isActive ? accent : AppColors.cartoonCream2))
                .clipShape(Circle())
                .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2))

            Text(label)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .textCase(.uppercase)
                .foregroundColor(AppColors.cartoonInkOnSunFill)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }
}

// MARK: - Cartoon Configuration Sheets

struct CartoonConfigurationHero: View {
    let iconName: String
    let title: String
    let subtitle: String
    let badge: String
    let accent: Color

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            CartoonMedallion(background: accent, size: 50, borderWidth: 2.5) {
                Image(systemName: iconName)
                    .font(.system(size: 23, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(title)
                    .font(.system(size: 27, weight: .black, design: .rounded))
                    .tracking(0.3)
                    .foregroundColor(inkColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(subtitle)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(inkColor.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)

                CartoonPill(text: badge, color: accent)
                    .padding(.top, AppSpacing.xs)
            }

            Spacer(minLength: 0)
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(creamColor)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(inkColor, lineWidth: 2.5)
        )
        .background(shadowRect(cornerRadius: 20, offset: 5))
    }
}

struct CartoonSettingHeader: View {
    let iconName: String
    let title: String
    let value: String?
    let accent: Color

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            CartoonMedallion(background: accent, size: 34) {
                Image(systemName: iconName)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .tracking(0.2)
                .foregroundColor(inkColor)
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Spacer(minLength: AppSpacing.xs)

            if let value {
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(accent)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(inkColor, lineWidth: 2))
            }
        }
    }
}

struct CartoonPresetChip: View {
    let title: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .tracking(0.4)
                .textCase(.uppercase)
                .foregroundColor(isSelected ? .white : inkColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.vertical, 8)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? accent : AppColors.cartoonCream2)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(inkColor, lineWidth: 2))
                .background(shadowCapsule(offset: 2.5))
        }
        .buttonStyle(PlainButtonStyle())
        .contentShape(Capsule())
    }
}

struct CartoonSettingDivider: View {
    var body: some View {
        Rectangle()
            .fill(inkColor.opacity(0.18))
            .frame(height: 2)
            .clipShape(Capsule())
    }
}

struct CartoonInfoLine: View {
    let iconName: String
    let text: String
    let accent: Color
    var isSubtle: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(accent)
                .frame(width: 18)
                .padding(.top, 2)

            Text(text)
                .font(.system(size: isSubtle ? 13 : 14, weight: .bold, design: .rounded))
                .foregroundColor(inkColor.opacity(isSubtle ? 0.58 : 0.7))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - CartoonMedallion

struct CartoonMedallion<Content: View>: View {
    var background: Color = AppColors.cartoonCream
    var size: CGFloat = 32
    var borderWidth: CGFloat = 2
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: size, height: size)
            .background(background)
            .clipShape(Circle())
            .overlay(Circle().stroke(inkColor, lineWidth: borderWidth))
            .background(shadowCircle(offset: 2.5))
    }
}

// MARK: - CartoonHudChip

struct CartoonHudChip: View {
    let label: String
    let value: String
    var accent: Color = AppColors.cartoonInk

    var body: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundColor(.white)
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(accent)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(inkColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(creamColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(inkColor, lineWidth: 2)
        )
        .background(shadowRect(cornerRadius: 12, offset: 3))
    }
}

// MARK: - CartoonFlagStatusChip

struct CartoonFlagStatusChip: View {
    let team: String
    let statusText: String
    var teamColor: Color

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11, weight: .bold))
                Text("Team \(team)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .tracking(0.9)
                    .textCase(.uppercase)
            }
            .foregroundColor(.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(teamColor)

            Text(statusText)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(inkColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(creamColor)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(inkColor, lineWidth: 2)
        )
        .background(shadowRect(cornerRadius: 12, offset: 3))
    }
}

// MARK: - CartoonPlayerRow

struct CartoonPlayerRow: View {
    let name: String
    let isYou: Bool
    let team: String
    let teamColor: Color
    let hasFlag: Bool
    let isLeader: Bool
    let isLast: Bool

    var body: some View {
        HStack(spacing: 10) {
            // Avatar medallion
            Text(name.prefix(1).uppercased())
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(teamColor)
                .clipShape(Circle())
                .overlay(Circle().stroke(inkColor, lineWidth: 2))
                .background(shadowCircle(offset: 2))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(inkColor)
                    if isYou {
                        Text("(you)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(inkColor.opacity(0.55))
                    }
                }
                Text(isLeader ? "Team Leader" : "Team \(team)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(inkColor.opacity(0.65))
            }

            Spacer()

            Image(systemName: hasFlag ? "flag.fill" : "flag")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(hasFlag ? teamColor : inkColor.opacity(0.25))

            Image(systemName: isLeader ? "star.fill" : "star")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isLeader ? AppColors.cartoonSun : inkColor.opacity(0.25))

            if isLeader {
                CartoonPill(text: "Leader", color: AppColors.cartoonSun, textColor: AppColors.cartoonInkOnSunFill, strokeColor: AppColors.cartoonInkOnSunFill)
            } else {
                CartoonPill(text: team, color: teamColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(inkColor.opacity(0.12))
                    .frame(height: 1.5)
            }
        }
    }
}
