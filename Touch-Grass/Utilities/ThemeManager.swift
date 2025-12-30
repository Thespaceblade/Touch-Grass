//
//  ThemeManager.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import Combine
import UIKit
@MainActor
class ThemeManager: ObservableObject {
    @Published var colorScheme: ColorScheme = .dark
    
    static let shared = ThemeManager()
    
    private init() {
        // Auto-detect system theme
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let userInterfaceStyle = windowScene.traitCollection.userInterfaceStyle
            colorScheme = userInterfaceStyle == .dark ? .dark : .light
        }
    }
    
    func toggle() {
        withAnimation {
            colorScheme = colorScheme == .dark ? .light : .dark
        }
    }
}

// MARK: - View Modifiers for Theming

struct ThemedBackground: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(
                AppColors.backgroundPrimary
            )
    }
}

extension View {
    func themedBackground() -> some View {
        modifier(ThemedBackground())
    }
}
