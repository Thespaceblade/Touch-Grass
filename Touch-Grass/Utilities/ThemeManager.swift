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
    enum ThemePreference: String, CaseIterable {
        case light = "light"
        case dark = "dark"
        case system = "system"
        
        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .system: return "System"
            }
        }
        
        var icon: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .system: return "circle.lefthalf.filled"
            }
        }
    }
    
    @Published var themePreference: ThemePreference = .system {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: "themePreference")
            updateColorScheme()
        }
    }
    
    @Published var colorScheme: ColorScheme = .dark
    
    static let shared = ThemeManager()
    
    private let themePreferenceKey = "themePreference"
    
    private init() {
        // Load saved theme preference
        if let savedPreference = UserDefaults.standard.string(forKey: themePreferenceKey),
           let preference = ThemePreference(rawValue: savedPreference) {
            themePreference = preference
        } else {
            themePreference = .system // Default to system
        }
        
        // Initialize color scheme based on preference
        updateColorScheme()
        
        // Observe system theme changes if using system preference
        if themePreference == .system {
            Task { @MainActor in
                self.setupSystemThemeObserver()
            }
        }
    }
    
    private func updateColorScheme() {
        withAnimation {
            switch themePreference {
            case .light:
                colorScheme = .light
            case .dark:
                colorScheme = .dark
            case .system:
                detectSystemTheme()
            }
        }
    }
    
    private func detectSystemTheme() {
        // Auto-detect system theme
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let userInterfaceStyle = windowScene.traitCollection.userInterfaceStyle
            let detectedScheme: ColorScheme = userInterfaceStyle == .dark ? .dark : .light
            if detectedScheme != colorScheme {
                colorScheme = detectedScheme
            }
        } else {
            // Fallback to dark if unable to detect
            colorScheme = .dark
        }
    }
    
    private func setupSystemThemeObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.themePreference == .system {
                    self.detectSystemTheme()
                }
            }
        }
    }
    
    func toggle() {
        // Legacy toggle function - cycles through preferences
        switch themePreference {
        case .light:
            themePreference = .dark
        case .dark:
            themePreference = .system
        case .system:
            themePreference = .light
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
