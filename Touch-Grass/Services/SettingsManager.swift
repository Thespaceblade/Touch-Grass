//
//  SettingsManager.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/31/25.
//

import Foundation
import Combine
import CoreBluetooth
import CoreLocation
import UserNotifications

@MainActor
class SettingsManager: ObservableObject {
    static let shared = SettingsManager()
    
    // UserDefaults keys
    private let hapticFeedbackEnabledKey = "hapticFeedbackEnabled"
    private let soundEffectsEnabledKey = "soundEffectsEnabled"
    private let defaultGameDurationKey = "defaultGameDuration"
    
    // Haptic Feedback
    @Published var hapticFeedbackEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(hapticFeedbackEnabled, forKey: hapticFeedbackEnabledKey)
        }
    }
    
    // Sound Effects
    @Published var soundEffectsEnabled: Bool = true {
        didSet {
            UserDefaults.standard.set(soundEffectsEnabled, forKey: soundEffectsEnabledKey)
        }
    }
    
    // Default Game Duration (in seconds, nil means use default)
    @Published var defaultGameDuration: TimeInterval? = nil {
        didSet {
            if let duration = defaultGameDuration {
                UserDefaults.standard.set(duration, forKey: defaultGameDurationKey)
            } else {
                UserDefaults.standard.removeObject(forKey: defaultGameDurationKey)
            }
        }
    }
    
    private init() {
        // Load saved preferences
        hapticFeedbackEnabled = UserDefaults.standard.object(forKey: hapticFeedbackEnabledKey) as? Bool ?? true
        soundEffectsEnabled = UserDefaults.standard.object(forKey: soundEffectsEnabledKey) as? Bool ?? true
        
        let duration = UserDefaults.standard.double(forKey: defaultGameDurationKey)
        if duration > 0 {
            defaultGameDuration = duration
        }
    }
    
    // MARK: - Permission Status
    
    func getLocationPermissionStatus() -> String {
        if #available(iOS 14.0, *) {
            let manager = CLLocationManager()
            switch manager.authorizationStatus {
            case .notDetermined:
                return "Not Determined"
            case .restricted:
                return "Restricted"
            case .denied:
                return "Denied"
            case .authorizedWhenInUse:
                return "When In Use"
            case .authorizedAlways:
                return "Always"
            @unknown default:
                return "Unknown"
            }
        } else {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                return "Not Determined"
            case .restricted:
                return "Restricted"
            case .denied:
                return "Denied"
            case .authorizedWhenInUse:
                return "When In Use"
            case .authorizedAlways:
                return "Always"
            @unknown default:
                return "Unknown"
            }
        }
    }
    
    func getBluetoothPermissionStatus() -> String {
        if #available(iOS 13.1, *) {
            // Use CBCentralManager.authorization static property (available iOS 13.1+)
            switch CBCentralManager.authorization {
            case .notDetermined:
                return "Not Determined"
            case .restricted:
                return "Restricted"
            case .denied:
                return "Denied"
            case .allowedAlways:
                return "Allowed"
            @unknown default:
                return "Unknown"
            }
        } else {
            return "Always Allowed"
        }
    }
    
    func getNotificationPermissionStatus() async -> String {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        switch settings.authorizationStatus {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        @unknown default:
            return "Unknown"
        }
    }
    
    // MARK: - Data Management
    
    func clearCache() {
        // Clear image cache in ProfileService
        // Note: ProfileService has its own cache, but we can't directly clear it
        // This is more of a placeholder for future cache clearing
        UserDefaults.standard.synchronize()
    }
    
    func clearAllData() -> [String] {
        var clearedItems: [String] = []
        
        // Clear profile data
        if UserDefaults.standard.string(forKey: "userProfileName") != nil {
            UserDefaults.standard.removeObject(forKey: "userProfileName")
            clearedItems.append("Profile Name")
        }
        
        if UserDefaults.standard.string(forKey: "userProfilePictureFileName") != nil {
            UserDefaults.standard.removeObject(forKey: "userProfilePictureFileName")
            // Also delete the actual image file
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("profile_picture.jpg")
            try? FileManager.default.removeItem(at: fileURL)
            clearedItems.append("Profile Picture")
        }
        
        // Clear game statistics
        if UserDefaults.standard.integer(forKey: "totalGamesPlayed") > 0 {
            UserDefaults.standard.removeObject(forKey: "totalGamesPlayed")
            clearedItems.append("Game Statistics")
        }
        
        if UserDefaults.standard.integer(forKey: "totalWins") > 0 {
            UserDefaults.standard.removeObject(forKey: "totalWins")
        }
        
        if UserDefaults.standard.double(forKey: "totalPlaytime") > 0 {
            UserDefaults.standard.removeObject(forKey: "totalPlaytime")
        }
        
        UserDefaults.standard.synchronize()
        return clearedItems
    }
}


