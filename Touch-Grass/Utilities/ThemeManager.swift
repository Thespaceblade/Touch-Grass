//
//  ThemeManager.swift
//  Touch-Grass
//
//  Owns the user's appearance preference (Light / Dark / System).
//
//  Storage shape: `Light`, `Dark`, `System`. Resolution shape: `ColorScheme?`
//  (`nil` = follow system). Applied at the root via
//  `.preferredColorScheme(themeManager.preferredColorScheme)` so SwiftUI
//  propagates the trait to every view, including the UITabBar trait
//  collection, UIKit dynamic colors then resolve automatically.
//

import SwiftUI
import Combine

@MainActor
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// Posted after `preference` changes so UIKit appearance proxies
    /// (e.g. `UITabBarAppearance`) can be rebuilt against the new trait
    /// collection if they don't naturally re-resolve dynamic colors.
    static let didChangeNotification = Notification.Name("ThemeManagerDidChange")

    enum Preference: String, CaseIterable, Identifiable {
        case light
        case dark
        case system

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .light:  return "Light"
            case .dark:   return "Dark"
            case .system: return "System"
            }
        }

        var iconName: String {
            switch self {
            case .light:  return "sun.max.fill"
            case .dark:   return "moon.stars.fill"
            case .system: return "circle.lefthalf.filled"
            }
        }

        /// The override SwiftUI should apply. `nil` means "follow system".
        var colorScheme: ColorScheme? {
            switch self {
            case .light:  return .light
            case .dark:   return .dark
            case .system: return nil
            }
        }
    }

    private let storageKey = "themePreference"

    @Published var preference: Preference {
        didSet {
            guard oldValue != preference else { return }
            UserDefaults.standard.set(preference.rawValue, forKey: storageKey)
            NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
        }
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = Preference(rawValue: raw) {
            preference = saved
        } else {
            // Default to Light to preserve the current cartoon-light experience on
            // upgrade; users opt in to Dark or System from Settings.
            preference = .light
        }
    }

    /// Bind this at the app/root level: `.preferredColorScheme(themeManager.preferredColorScheme)`.
    var preferredColorScheme: ColorScheme? {
        preference.colorScheme
    }
}
