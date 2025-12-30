//
//  DebugTestButton.swift
//  Touch-Grass
//
//  Debug-only test panel button component
//

import SwiftUI

#if DEBUG
struct DebugTestButton: View {
    @Binding var showDebugTestPanel: Bool
    
    var body: some View {
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

extension View {
    /// Adds a debug test panel button in the top right corner (DEBUG builds only)
    func debugTestButton(showDebugTestPanel: Binding<Bool>) -> some View {
        #if DEBUG
        return self.overlay(alignment: .topTrailing) {
            DebugTestButton(showDebugTestPanel: showDebugTestPanel)
        }
        #else
        return self
        #endif
    }
}
#endif


