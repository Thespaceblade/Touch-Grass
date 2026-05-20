//
//  ManhuntPreGameCountdownModel.swift
//  Touch-Grass
//

import Foundation
import Combine
import UIKit

/// Shared 180s pre-game countdown clock for hunter full-screen and hider map banner.
@MainActor
final class ManhuntPreGameCountdownModel: ObservableObject {
    static let duration: TimeInterval = 180.0

    @Published private(set) var timeRemaining: TimeInterval = duration
    @Published private(set) var showGoScreen: Bool = false

    private var timer: Timer?
    private var lastHapticSecond: Int = -1
    private var onComplete: (() -> Void)?

    func start(onComplete: @escaping () -> Void) {
        stop()
        self.onComplete = onComplete
        timeRemaining = Self.duration
        showGoScreen = false
        lastHapticSecond = -1

        HapticFeedbackManager.shared.selection()

        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            Task { @MainActor in
                self.tick()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastHapticSecond = -1
        onComplete = nil
    }

    private func tick() {
        timeRemaining -= 0.1

        let remainingSeconds = Int(timeRemaining)

        if remainingSeconds != lastHapticSecond {
            lastHapticSecond = remainingSeconds

            if remainingSeconds > 30 && remainingSeconds % 30 == 0 {
                HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
            } else if remainingSeconds == 15 {
                HapticFeedbackManager.shared.impact(style: .heavy)
            } else if remainingSeconds >= 1 && remainingSeconds <= 10 {
                if remainingSeconds == 10 || remainingSeconds == 7 || remainingSeconds == 4 || remainingSeconds == 2 || remainingSeconds == 1 {
                    HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
                } else {
                    HapticFeedbackManager.shared.impact(style: .heavy)
                }
            } else if remainingSeconds == 0 {
                showGoScreen = true
                HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    HapticFeedbackManager.shared.doubleHaptic(style: .heavy)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.finish()
                    }
                }
                return
            }
        }
    }

    private func finish() {
        stop()
        onComplete?()
    }

    func timeString(from seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
