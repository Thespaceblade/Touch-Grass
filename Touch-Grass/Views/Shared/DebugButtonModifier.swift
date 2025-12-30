//
//  DebugButtonModifier.swift
//  Touch-Grass
//
//  Debug-only button modifier for adding test panel access
//

import SwiftUI

#if DEBUG
struct DebugButtonModifier: ViewModifier {
    @Binding var showDebugTestPanel: Bool
    let viewModel: GameViewModel?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if viewModel != nil {
                    Button(action: {
                        HapticFeedbackManager.shared.selection()
                        showDebugTestPanel = true
                    }) {
                        Image(systemName: "testtube.2")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(AppColors.grassPrimary)
                                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
                            )
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 12)
                }
            }
    }
}

extension View {
    func debugButton(showDebugTestPanel: Binding<Bool>, viewModel: GameViewModel?) -> some View {
        modifier(DebugButtonModifier(showDebugTestPanel: showDebugTestPanel, viewModel: viewModel))
    }
}
#endif

