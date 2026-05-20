//
//  JoinGameCodeInput.swift
//  Touch-Grass
//
//  Shared join-code input box used by Manhunt, Zombie Tag, and CTF lobbies.
//  Wrong codes surface inline (shake + red border + X icon) instead of via
//  a modal alert. Longer-running failures (sign-in, GPS timeout) are still
//  shown as toasts by the lobby; this view only handles the fixable cases.
//

import SwiftUI

// MARK: - JoinCodeError

/// User-correctable join-code failures that should appear inline on the
/// code input itself rather than as a system alert.
enum JoinCodeError: Equatable {
    case invalidFormat
    case sessionNotFound
    case alreadyStarted
    case wrongGameType(GameType)
    case other(String)

    /// Short caption shown directly under the code field.
    var caption: String {
        switch self {
        case .invalidFormat:
            return "Enter all 6 digits."
        case .sessionNotFound:
            return "No game with that code."
        case .alreadyStarted:
            return "That game already started."
        case .wrongGameType(let type):
            return "That code is for \(type.rawValue)."
        case .other(let message):
            return message
        }
    }

    /// Map a raw error string returned by `GameService.joinGame` to an
    /// inline error category when possible. Returns `nil` when the error
    /// is too situational for inline treatment (sign-in, GPS, etc.) and
    /// the caller should fall back to a toast.
    static func from(gameServiceMessage: String) -> JoinCodeError? {
        let message = gameServiceMessage.lowercased()

        if message.contains("invalid join code") {
            return .invalidFormat
        }
        if message.contains("no session found") || message.contains("session not found") {
            return .sessionNotFound
        }
        if message.contains("already started") {
            return .alreadyStarted
        }
        if message.contains("this join code is for") {
            let knownTypes: [GameType] = [.manhunt, .zombieTag, .captureTheFlag]
            for type in knownTypes {
                if message.contains(type.rawValue.lowercased()) {
                    return .wrongGameType(type)
                }
            }
            return .other("Wrong game mode for that code.")
        }
        if message.contains("not part of this session") || message.contains("could not join") {
            return .sessionNotFound
        }
        return nil
    }
}

// MARK: - JoinGameCodeInput

struct JoinGameCodeInput: View {
    let accentColor: Color
    let title: String
    @Binding var code: String
    var isLocationReady: Bool = true
    var isJoining: Bool = false
    var errorState: JoinCodeError? = nil
    var onSubmit: () -> Void
    var onClearError: () -> Void = {}

    @State private var shakeOffset: CGFloat = 0
    @State private var lastShakenError: JoinCodeError? = nil

    private var fieldStrokeColor: Color {
        if errorState != nil { return AppColors.error }
        return code.isEmpty ? AppColors.cartoonInk.opacity(0.35) : accentColor
    }

    private var submitDisabled: Bool {
        isJoining || code.count != 6 || !isLocationReady
    }

    private var submitButtonColor: Color {
        if errorState != nil { return AppColors.error }
        return submitDisabled ? AppColors.cartoonInk.opacity(0.45) : accentColor
    }

    private var submitIcon: String {
        if errorState != nil { return "xmark" }
        return "arrow.right"
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: accentColor, size: 36) {
                    Image(systemName: "number")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            HStack(spacing: AppSpacing.sm) {
                codeField
                    .offset(x: shakeOffset)

                submitButton
            }

            captionView
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(AppColors.cartoonCream)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(AppColors.cartoonInk, lineWidth: 2))
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color(white: 0.18)).offset(x: 4, y: 4))
        .onChange(of: errorState) { _, newValue in
            if newValue != nil && newValue != lastShakenError {
                triggerShake()
                lastShakenError = newValue
            } else if newValue == nil {
                lastShakenError = nil
            }
        }
    }

    private var codeField: some View {
        TextField("000000", text: $code)
            .font(.system(size: 28, weight: .bold, design: .monospaced))
            .foregroundColor(AppColors.cartoonInk)
            .multilineTextAlignment(.center)
            .keyboardType(.numberPad)
            .autocorrectionDisabled()
            .padding(.horizontal, AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.cartoonCream2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(fieldStrokeColor, lineWidth: errorState != nil ? 2.5 : 2)
            )
            .animation(.easeOut(duration: 0.2), value: errorState)
            .onChange(of: code) { _, newValue in
                let filtered = newValue.filter { $0.isNumber }
                let trimmed = filtered.count > 6 ? String(filtered.prefix(6)) : filtered
                if trimmed != newValue {
                    code = trimmed
                }
                if errorState != nil {
                    onClearError()
                }
            }
    }

    private var submitButton: some View {
        Button(action: handleSubmit) {
            Group {
                if isJoining {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: submitIcon)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
        }
        .buttonStyle(IconButtonStyle(size: 44, color: submitButtonColor))
        .disabled(submitDisabled && errorState == nil)
        .animation(.easeOut(duration: 0.2), value: errorState)
    }

    @ViewBuilder
    private var captionView: some View {
        if let error = errorState {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Text(error.caption)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundColor(AppColors.error)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Text("Enter the game code shared by the host")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func handleSubmit() {
        if errorState != nil {
            HapticFeedbackManager.shared.selection()
            code = ""
            onClearError()
            return
        }
        guard !submitDisabled else { return }
        HapticFeedbackManager.shared.selection()
        onSubmit()
    }

    private func triggerShake() {
        HapticFeedbackManager.shared.error()
        let pattern: [CGFloat] = [-10, 10, -8, 8, -5, 5, 0]
        let stepDuration = 0.045
        for (index, value) in pattern.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * stepDuration) {
                withAnimation(.easeInOut(duration: stepDuration)) {
                    shakeOffset = value
                }
            }
        }
    }
}
