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
            CartoonMedallion(background: AppColors.error, size: 64, borderWidth: 2.5) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .symbolEffect(.pulse, options: .repeating)
            
            Text(title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(AppColors.cartoonInk)
                .multilineTextAlignment(.center)
            
            Text(message)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            
            VStack(spacing: AppSpacing.sm) {
                if let retryAction = retryAction {
                    Button(action: retryAction) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                            Text("Try Again")
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(CartoonButtonStyle(accent: AppColors.error))
                }
                
                if let dismissAction = dismissAction {
                    Button(action: dismissAction) {
                        Text("Dismiss")
                    }
                    .buttonStyle(CartoonSecondaryButtonStyle())
                }
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: 400)
        .cartoonCard(cornerRadius: 20, shadowOffset: 5, borderWidth: 2.5)
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













