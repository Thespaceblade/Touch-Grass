//
//  LobbyNotice.swift
//  Touch-Grass
//
//  Payload describing a themed, blocking lobby notice. The active lobby
//  view observes `GameViewModel.lobbyNotice` and renders a
//  `ThemedNoticeOverlay` matching the lobby's game theme.
//

import Foundation

struct LobbyNotice: Identifiable, Equatable {
    enum Action: Equatable {
        case dismiss
        case openSessionSetup
        case openTeamManagement
        case openBubbleSettings
    }

    let id = UUID()
    let title: String
    let message: String
    let primaryAction: Action

    init(title: String, message: String, primaryAction: Action = .dismiss) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
    }
}
