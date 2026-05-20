//
//  ToastView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

enum ToastType {
    case success
    case error
    case warning
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .success: return AppColors.success
        case .error: return AppColors.error
        case .warning: return AppColors.warning
        case .info: return AppColors.info
        }
    }
}

/// Identifiable payload for the global toast channel on `GameViewModel`.
/// A new id forces SwiftUI to dismiss-and-re-show when the same message
/// is reported back-to-back (rare, but harmless).
struct AppToastMessage: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let type: ToastType
}

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: type.color, size: 32) {
                    Image(systemName: type.icon)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Text(message)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(AppSpacing.md)
            .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
            .padding(.horizontal, AppSpacing.md)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                // Auto-dismiss after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        isVisible = false
                    }
                }
            }
        }
    }
}

// MARK: - View Extension

extension View {
    func toast(
        message: String,
        type: ToastType,
        isVisible: Binding<Bool>
    ) -> some View {
        ZStack(alignment: .top) {
            self
            VStack {
                ToastView(message: message, type: type, isVisible: isVisible)
                Spacer()
            }
        }
    }

    /// Drives the toast from an optional `AppToastMessage`. The toast is
    /// shown whenever the binding is non-nil and clears itself after the
    /// auto-dismiss window. Use this at the app root so every transient
    /// failure surfaces in one place.
    func appToast(_ toast: Binding<AppToastMessage?>) -> some View {
        modifier(AppToastModifier(toast: toast))
    }
}

private struct AppToastModifier: ViewModifier {
    @Binding var toast: AppToastMessage?
    @State private var isVisible: Bool = false

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content
            if let active = toast {
                VStack {
                    ToastView(message: active.message, type: active.type, isVisible: $isVisible)
                        .id(active.id)
                    Spacer()
                }
                .padding(.top, AppSpacing.sm)
            }
        }
        .onChange(of: toast?.id) { _, newId in
            isVisible = newId != nil
        }
        .onChange(of: isVisible) { _, newValue in
            if !newValue { toast = nil }
        }
        .onAppear {
            isVisible = toast != nil
        }
    }
}













