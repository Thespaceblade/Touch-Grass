//
//  ScreenshotScenario.swift
//  Touch-Grass
//
//  DEBUG-only routing layer that lets XCTest UI tests render real SwiftUI
//  screens with deterministic seeded state, so we can capture the live app
//  UI for marketing screenshots without depending on Firebase, GPS, or
//  Bluetooth.
//

#if DEBUG
import Foundation

/// One marketing screenshot scenario.
///
/// Each case corresponds to a real screen in the app that we want to
/// capture as a marketing screenshot. The associated `launchArgument`
/// string is the value passed via `-ScreenshotScenario <value>` from
/// the XCTest UI tests.
enum ScreenshotScenario: String, CaseIterable {
    case gameSelection
    case ctfLobby
    case ctfActive
    case zombieActive
    case manhuntActive
    case resultsShare

    /// Launch argument key used by XCTest.
    /// Passed as `-ScreenshotScenario <rawValue>`.
    static let launchArgumentKey = "-ScreenshotScenario"

    /// Accessibility identifier set on the root scenario view. UI tests wait
    /// on this identifier before capturing a screenshot so that we know the
    /// SwiftUI hierarchy has actually mounted.
    var readyAccessibilityIdentifier: String {
        "screenshot-ready-\(rawValue)"
    }

    /// File name (without extension) for the captured screenshot.
    var screenshotBaseName: String {
        rawValue
    }

    /// Parses the current scenario (if any) from `ProcessInfo` launch arguments.
    ///
    /// Returns `nil` when the app was launched normally. When this returns
    /// a non-nil value the app should skip Firebase / Auth bootstrapping and
    /// render `ScreenshotScenarioRootView` instead of the normal `ContentView`.
    static func current() -> ScreenshotScenario? {
        let args = ProcessInfo.processInfo.arguments
        guard let keyIndex = args.firstIndex(of: launchArgumentKey),
              keyIndex + 1 < args.count else {
            return nil
        }
        let raw = args[keyIndex + 1]
        return ScreenshotScenario(rawValue: raw)
    }

    /// Convenience check used early in app startup to avoid touching
    /// real network / auth services when running in screenshot mode.
    static var isActive: Bool {
        current() != nil
    }
}
#endif
