//
//  HapticFeedbackManager.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import UIKit

@MainActor
final class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()
    
    private init() {}
    
    // MARK: - Impact Feedback
    
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func impact(intensity: CGFloat) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: intensity)
    }
    
    // MARK: - Notification Feedback
    
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }
    
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    // MARK: - Selection Feedback
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // MARK: - Game-Specific Feedback
    
    func playerCaught() {
        // Strong impact for catch
        impact(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(style: .medium)
        }
    }
    
    func playerEliminated() {
        error()
    }
    
    func proximityWarning(distance: Double) {
        // Intensity based on proximity (closer = stronger)
        let intensity = max(0.3, min(1.0, 1.0 - (distance / 50.0)))
        impact(intensity: intensity)
    }
    
    func dangerProximity() {
        // Strong haptic feedback for very close hunter (< 10m)
        impact(style: .heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.impact(style: .heavy)
        }
    }
    
    func zoneShrink() {
        // Medium impact for zone shrink
        impact(style: .medium)
    }
    
    func tagRequest() {
        // Light impact for tag request
        impact(style: .light)
    }
    
    func tagConfirmed() {
        success()
    }
}

