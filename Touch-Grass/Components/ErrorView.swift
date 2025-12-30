//
//  ErrorView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ErrorView: View {
    let title: String
    let message: String
    let retryAction: (() -> Void)?
    let dismissAction: (() -> Void)?
    
    init(
        title: String = "Something Went Wrong",
        message: String,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.retryAction = retryAction
        self.dismissAction = dismissAction
    }
    
    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Error Icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppColors.error)
                .symbolEffect(.pulse, options: .repeating)
            
            // Title
            Text(title)
                .font(AppTypography.headlineLarge())
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Message
            Text(message)
                .font(AppTypography.bodyMedium())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.md)
            
            // Actions
            VStack(spacing: AppSpacing.sm) {
                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                            Text("Try Again")
                                .font(AppTypography.labelLarge())
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [AppColors.manhuntPrimary, AppColors.manhuntSecondary],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if let dismissAction = dismissAction {
                    Button(action: dismissAction) {
                        Text("Dismiss")
                            .font(AppTypography.labelMedium())
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.vertical, AppSpacing.sm)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, AppSpacing.lg)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 400)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - View Extension

extension View {
    func errorOverlay(
        title: String = "Something Went Wrong",
        message: String,
        isVisible: Bool,
        retryAction: (() -> Void)? = nil,
        dismissAction: (() -> Void)? = nil
    ) -> some View {
        ZStack {
            self
            if isVisible {
                ErrorView(
                    title: title,
                    message: message,
                    retryAction: retryAction,
                    dismissAction: dismissAction
                )
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
}





