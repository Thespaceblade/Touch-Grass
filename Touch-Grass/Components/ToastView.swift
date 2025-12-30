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

struct ToastView: View {
    let message: String
    let type: ToastType
    @Binding var isVisible: Bool
    
    var body: some View {
        if isVisible {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.title3)
                    .foregroundColor(type.color)
                
                Text(message)
                    .font(AppTypography.bodyMedium())
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(type.color.opacity(AppColors.Opacity.regular), lineWidth: 1)
            )
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
}





