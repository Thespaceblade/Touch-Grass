//
//  ManhuntHiderCountdownBanner.swift
//  Touch-Grass
//

import SwiftUI

/// Compact pre-game countdown overlay so hiders can see the map and zone.
struct ManhuntHiderCountdownBanner: View {
    @ObservedObject var countdown: ManhuntPreGameCountdownModel
    @ObservedObject var gameService: GameService

    private var primaryColor: Color { AppColors.manhuntPrimary }

    var body: some View {
        VStack(spacing: 0) {
            bannerContent
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.sm)
                .padding(.bottom, AppSpacing.md)
                .frame(maxWidth: .infinity)
                .background(
                    AppColors.cartoonCream.opacity(0.92)
                        .background(.ultraThinMaterial)
                )
                .overlay(
                    Rectangle()
                        .frame(height: 2)
                        .foregroundColor(AppColors.cartoonInk),
                    alignment: .bottom
                )

            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var bannerContent: some View {
        if countdown.showGoScreen {
            Text("GO!")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(primaryColor)
        } else {
            VStack(spacing: AppSpacing.xs) {
                if let player = gameService.currentPlayer {
                    CartoonPill(
                        text: player.role == .hunter ? "HUNTER" : "HIDER",
                        color: player.role == .hunter ? AppColors.hunterPrimary : AppColors.hiderPrimary
                    )
                }

                Text("Game starts in \(countdown.timeString(from: countdown.timeRemaining))")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .monospacedDigit()

                Text("Hide and stay inside the play zone")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
        }
    }
}
