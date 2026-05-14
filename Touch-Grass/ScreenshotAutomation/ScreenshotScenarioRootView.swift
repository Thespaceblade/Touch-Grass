//
//  ScreenshotScenarioRootView.swift
//  Touch-Grass
//
//  DEBUG-only root view that renders the real SwiftUI screen for a marketing
//  screenshot scenario. The hierarchy here is intentionally as close as
//  possible to what `ContentView` would mount: we want the captured pixels
//  to match what ships, not a mock.
//

#if DEBUG
import SwiftUI

struct ScreenshotScenarioRootView: View {
    let scenario: ScreenshotScenario

    @StateObject private var viewModel: GameViewModel

    init(scenario: ScreenshotScenario) {
        self.scenario = scenario
        _viewModel = StateObject(wrappedValue: ScreenshotSeedFactory.makeViewModel(for: scenario))
    }

    var body: some View {
        ZStack {
            AppColors.backgroundPrimary
                .ignoresSafeArea()

            scenarioContent
        }
        .preferredColorScheme(.light)
        .accessibilityIdentifier(scenario.readyAccessibilityIdentifier)
    }

    @ViewBuilder
    private var scenarioContent: some View {
        switch scenario {
        case .gameSelection:
            GameSelectionView { _ in }

        case .ctfLobby:
            CTFLobbyView(viewModel: viewModel, onBackToMenu: {})

        case .ctfActive:
            CTFActiveGameView(
                gameService: viewModel.gameService,
                locationService: viewModel.locationService,
                viewModel: viewModel
            )

        case .zombieActive:
            ZombieTagActiveGameView(
                gameService: viewModel.gameService,
                locationService: viewModel.locationService,
                viewModel: viewModel
            )

        case .manhuntActive:
            ManhuntActiveGameView(
                gameService: viewModel.gameService,
                locationService: viewModel.locationService,
                viewModel: viewModel
            )

        case .resultsShare:
            if let session = viewModel.gameService.session,
               let stats = viewModel.gameService.gameStats {
                CTFGameEndView(
                    session: session,
                    gameStats: stats,
                    currentPlayer: viewModel.gameService.currentPlayer,
                    gameService: viewModel.gameService,
                    onPlayAgain: {},
                    onBackToLobby: {}
                )
            } else {
                Text("Seed missing for resultsShare scenario")
            }
        }
    }
}
#endif
