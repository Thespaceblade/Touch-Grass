//
//  AppReleaseConfiguration.swift
//  Touch-Grass
//
//  App Store vs in-development game availability.
//  Release archives only ship Manhunt; Debug builds keep all modes for local QA.
//

import Foundation

enum AppReleaseConfiguration {
    /// When true, only modes listed in `availableGameModes` are selectable.
    private static var restrictsToAppStoreLineup: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }

    private static let availableGameModes: Set<GameType> = [.manhunt]

    static func isGameModeAvailable(_ gameType: GameType) -> Bool {
        guard restrictsToAppStoreLineup else { return true }
        return availableGameModes.contains(gameType)
    }

    static var unavailableGameModeMessage: String {
        "This game mode is coming soon. Update the app when Capture The Flag and Zombie Tag launch."
    }
}
