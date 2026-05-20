//
//  ScreenWakeLock.swift
//  Touch-Grass
//

import UIKit

/// Keeps the device awake during active BLE gameplay sessions.
enum ScreenWakeLock {
    static func setEnabled(_ enabled: Bool) {
        UIApplication.shared.isIdleTimerDisabled = enabled
    }
}
