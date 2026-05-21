//
//  ManhuntHiderCountdownBanner.swift
//  Touch-Grass
//

import SwiftUI

/// Compact pre-game countdown row below the status strip so hiders keep the map and HUD visible.
struct ManhuntHiderPreGameCountdownStrip: View {
    @ObservedObject var countdown: ManhuntPreGameCountdownModel

    private var primaryColor: Color { AppColors.manhuntPrimary }

    var body: some View {
        Group {
            if countdown.showGoScreen {
                goContent
            } else {
                countdownContent
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
        .cartoonCard(cornerRadius: 14, shadowOffset: 4, borderWidth: 2)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var countdownContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(primaryColor)
                Text("Starts in \(countdown.timeString(from: countdown.timeRemaining))")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                    .monospacedDigit()
            }
            Text("Hide and stay inside the play zone")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.cartoonInk.opacity(0.65))
        }
    }

    private var goContent: some View {
        Text("GO!")
            .font(.system(size: 28, weight: .bold, design: .rounded))
            .foregroundColor(primaryColor)
            .frame(maxWidth: .infinity)
    }

    private var accessibilityLabel: String {
        if countdown.showGoScreen {
            return "Go"
        }
        return "Game starts in \(countdown.timeString(from: countdown.timeRemaining)). Hide and stay inside the play zone."
    }
}
