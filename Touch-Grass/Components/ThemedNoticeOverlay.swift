//
//  ThemedNoticeOverlay.swift
//  Touch-Grass
//
//  Themed replacement for native `.alert(...)` calls. Uses the same cartoon
//  card / ink stroke / gradient header as ThemedExitLobbyConfirmation and
//  ThemedInGameConfirmation, but supports flexible button configurations
//  (single OK, cancel/confirm, multi-action) and accepts arbitrary header
//  copy so it can stand in for a wide range of system alerts.
//

import SwiftUI

// MARK: - Notice configuration

struct ThemedNoticeButton: Identifiable {
    enum Role {
        case primary
        case secondary
        case destructive
    }

    let id = UUID()
    let title: String
    let icon: String?
    let role: Role
    let action: () -> Void

    init(title: String, icon: String? = nil, role: Role = .primary, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.role = role
        self.action = action
    }

    static func ok(action: @escaping () -> Void = {}) -> ThemedNoticeButton {
        ThemedNoticeButton(title: "OK", icon: "checkmark", role: .primary, action: action)
    }

    static func cancel(action: @escaping () -> Void = {}) -> ThemedNoticeButton {
        ThemedNoticeButton(title: "Cancel", icon: "arrow.uturn.left", role: .secondary, action: action)
    }
}

// MARK: - Overlay view

struct ThemedNoticeOverlay: View {
    @Binding var isPresented: Bool
    let primaryColor: Color
    let secondaryColor: Color
    let iconName: String
    let headerTitle: String
    let headerSubtitle: String
    let title: String
    let message: String
    let buttons: [ThemedNoticeButton]
    /// When non-nil, buttons styled with `.destructive` use this color
    /// for their primary accent. Defaults to `AppColors.error` so destructive
    /// actions read consistently across the app.
    var destructiveAccent: Color = AppColors.error

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture { dismissOnBackdrop() }

            CartoonCard(padding: 0, cornerRadius: 18, shadowOffset: 6) {
                VStack(spacing: 0) {
                    header

                    VStack(spacing: AppSpacing.md) {
                        Text(title)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk)
                            .multilineTextAlignment(.center)

                        if !message.isEmpty {
                            Text(message)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(AppColors.cartoonInk.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        VStack(spacing: AppSpacing.sm) {
                            ForEach(buttons) { button in
                                renderButton(button)
                            }
                        }
                    }
                    .padding(AppSpacing.lg)
                }
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    @ViewBuilder
    private func renderButton(_ button: ThemedNoticeButton) -> some View {
        Button {
            HapticFeedbackManager.shared.selection()
            isPresented = false
            button.action()
        } label: {
            if let icon = button.icon {
                Label(button.title, systemImage: icon)
            } else {
                Text(button.title)
            }
        }
        .applyNoticeButtonStyle(role: button.role, primary: primaryColor, destructive: destructiveAccent)
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text(headerSubtitle)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(.white.opacity(0.88))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
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

    private func dismissOnBackdrop() {
        // Backdrop tap only dismisses notices that have a cancel-style action.
        // A single-button notice (just OK) requires the explicit tap.
        guard buttons.contains(where: { $0.role == .secondary }) else { return }
        HapticFeedbackManager.shared.selection()
        isPresented = false
    }
}

// MARK: - Button style routing

private extension View {
    @ViewBuilder
    func applyNoticeButtonStyle(role: ThemedNoticeButton.Role, primary: Color, destructive: Color) -> some View {
        switch role {
        case .primary:
            buttonStyle(PrimaryButtonStyle(accentColor: primary))
        case .destructive:
            buttonStyle(PrimaryButtonStyle(accentColor: destructive))
        case .secondary:
            buttonStyle(SecondaryButtonStyle(accentColor: primary))
        }
    }
}

// MARK: - View modifier

extension View {
    func themedNotice(
        isPresented: Binding<Bool>,
        primaryColor: Color,
        secondaryColor: Color,
        iconName: String,
        headerTitle: String,
        headerSubtitle: String,
        title: String,
        message: String,
        buttons: [ThemedNoticeButton]
    ) -> some View {
        cartoonPopupOverlay(isPresented: isPresented) {
            ThemedNoticeOverlay(
                isPresented: isPresented,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                iconName: iconName,
                headerTitle: headerTitle,
                headerSubtitle: headerSubtitle,
                title: title,
                message: message,
                buttons: buttons
            )
        }
    }
}

// MARK: - Shared cartoon popup presentation

extension AnyTransition {
    /// Cartoon pop-in / pop-out: card scales up from below with a quick
    /// rise on insert, then shrinks and fades on dismiss. The bouncy
    /// spring is supplied by `cartoonPopupOverlay`.
    static var cartoonPopup: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.65, anchor: .center)
                .combined(with: .opacity)
                .combined(with: .offset(y: 24)),
            removal: .scale(scale: 0.9, anchor: .center)
                .combined(with: .opacity)
        )
    }
}

extension View {
    /// Hosts a themed popup inside an overlay with the shared cartoon
    /// in/out animation. The popup view is responsible for its own
    /// backdrop (dim layer) and tap-to-dismiss behavior; this helper
    /// only owns the conditional rendering and transition.
    func cartoonPopupOverlay<Popup: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder popup: () -> Popup
    ) -> some View {
        overlay {
            ZStack {
                if isPresented.wrappedValue {
                    popup()
                        .transition(.cartoonPopup)
                        .zIndex(1000)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.68), value: isPresented.wrappedValue)
        }
    }
}
