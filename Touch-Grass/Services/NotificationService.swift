//
//  NotificationService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/28/25.
//

import Foundation
import UserNotifications

@MainActor
final class NotificationService {
    static let shared = NotificationService()
    
    private let notificationCenter = UNUserNotificationCenter.current()
    
    private init() {
        // Configure notification categories and actions
        setupNotificationCategories()
    }
    
    // MARK: - Permission Request
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                print("✅ Notification permission granted")
            } else {
                print("❌ Notification permission denied")
            }
            return granted
        } catch {
            print("❌ Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func checkPermissionStatus() async -> UNAuthorizationStatus {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus
    }
    
    // MARK: - Notification Categories
    
    private func setupNotificationCategories() {
        // CTF Flag Capture category
        let captureAction = UNNotificationAction(
            identifier: "FLAG_CAPTURED_ACTION",
            title: "View Game",
            options: [.foreground]
        )
        
        let flagCaptureCategory = UNNotificationCategory(
            identifier: "FLAG_CAPTURE",
            actions: [captureAction],
            intentIdentifiers: [],
            options: []
        )
        
        // CTF Flag Return category
        let returnAction = UNNotificationAction(
            identifier: "FLAG_RETURNED_ACTION",
            title: "View Game",
            options: [.foreground]
        )
        
        let flagReturnCategory = UNNotificationCategory(
            identifier: "FLAG_RETURN",
            actions: [returnAction],
            intentIdentifiers: [],
            options: []
        )
        
        // CTF Flag Disconnect category
        let disconnectCategory = UNNotificationCategory(
            identifier: "FLAG_DISCONNECT",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            flagCaptureCategory,
            flagReturnCategory,
            disconnectCategory
        ])
    }
    
    // MARK: - CTF Flag Notifications
    
    func notifyFlagCaptured(team: Flag.Team, capturedBy: String, isYourFlag: Bool) {
        let title: String
        let body: String
        
        if isYourFlag {
            title = "🚩 Your Flag Was Captured!"
            body = "\(capturedBy) captured your team's flag. Defend your base!"
        } else {
            title = "🎯 Flag Captured!"
            body = "You captured \(team == .teamA ? "Team A" : "Team B")'s flag! Bring it to your base."
        }
        
        sendNotification(
            identifier: "flag_captured_\(team.rawValue)_\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            categoryIdentifier: "FLAG_CAPTURE",
            sound: .default
        )
    }
    
    func notifyFlagReturned(team: Flag.Team, returnedBy: String, isYourFlag: Bool) {
        let title: String
        let body: String
        
        if isYourFlag {
            title = "✅ Your Flag Was Returned!"
            body = "\(returnedBy) returned your team's flag to base."
        } else {
            title = "🔄 Flag Returned"
            body = "\(team == .teamA ? "Team A" : "Team B")'s flag was returned to their base."
        }
        
        sendNotification(
            identifier: "flag_returned_\(team.rawValue)_\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            categoryIdentifier: "FLAG_RETURN",
            sound: .default
        )
    }
    
    func notifyFlagDisconnected(team: Flag.Team) {
        let title = "⚠️ Flag Disconnected"
        let body = "\(team == .teamA ? "Team A" : "Team B")'s flag phone lost connection. Game continues in manual mode."
        
        sendNotification(
            identifier: "flag_disconnected_\(team.rawValue)_\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            categoryIdentifier: "FLAG_DISCONNECT",
            sound: .default
        )
    }
    
    func notifyFlagReconnected(team: Flag.Team) {
        let title = "✅ Flag Reconnected"
        let body = "\(team == .teamA ? "Team A" : "Team B")'s flag phone reconnected."
        
        sendNotification(
            identifier: "flag_reconnected_\(team.rawValue)_\(Date().timeIntervalSince1970)",
            title: title,
            body: body,
            categoryIdentifier: "FLAG_DISCONNECT",
            sound: nil // Silent notification for reconnection
        )
    }
    
    // MARK: - Generic Notification
    
    func sendNotification(
        identifier: String,
        title: String,
        body: String,
        categoryIdentifier: String,
        sound: UNNotificationSound?
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.categoryIdentifier = categoryIdentifier
        content.sound = sound
        content.badge = 1
        
        // Trigger immediately
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error)")
            } else {
                print("✅ Notification scheduled: \(title)")
            }
        }
    }
    
    // MARK: - Cleanup
    
    func removeAllPendingNotifications() {
        notificationCenter.removeAllPendingNotificationRequests()
        print("🗑️ Removed all pending notifications")
    }
    
    func removeDeliveredNotifications() {
        notificationCenter.removeAllDeliveredNotifications()
        print("🗑️ Removed all delivered notifications")
    }
}

