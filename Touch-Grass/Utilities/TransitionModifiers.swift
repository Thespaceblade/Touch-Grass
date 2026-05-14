//
//  TransitionModifiers.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/27/25.
//

import SwiftUI

extension AnyTransition {
    // MARK: - Game Selection → Lobby Transition
    /// Card expansion effect - card appears to grow and fill screen
    static var cardExpand: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9)
                .combined(with: .move(edge: .trailing))
                .combined(with: .opacity),
            removal: .scale(scale: 1.1)
                .combined(with: .move(edge: .leading))
                .combined(with: .opacity)
        )
    }
    
    // MARK: - Lobby → Active Game Transition
    /// Map reveal effect - map expands from center
    static var mapReveal: AnyTransition {
        .scale(scale: 0.3)
            .combined(with: .opacity)
    }
    
    // MARK: - Active Game → Game End Transition
    /// Celebration effect - end screen pops in with bounce
    static var celebration: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.8)
                .combined(with: .opacity),
            removal: .scale(scale: 1.1)
                .combined(with: .opacity)
        )
    }
    
    // MARK: - Back Navigation Transition
    /// Reverse slide - smooth return to previous screen
    static var reverseSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .leading)
                .combined(with: .opacity),
            removal: .move(edge: .trailing)
                .combined(with: .opacity)
        )
    }
    
    // MARK: - Slide and Scale (General Purpose)
    /// Combined slide and scale for smooth transitions
    static var slideAndScale: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing)
                .combined(with: .scale(scale: 0.95))
                .combined(with: .opacity),
            removal: .move(edge: .leading)
                .combined(with: .scale(scale: 0.95))
                .combined(with: .opacity)
        )
    }
    
    // MARK: - Fade with Scale (Subtle)
    /// Subtle fade with slight scale for gentle transitions
    static var fadeScale: AnyTransition {
        .scale(scale: 0.98)
            .combined(with: .opacity)
    }
}

// MARK: - Animation Presets

extension Animation {
    /// Smooth spring animation for screen transitions (optimized for performance)
    static var smoothTransition: Animation {
        .spring(response: 0.4, dampingFraction: 0.85) // Faster response for smoother feel
    }
    
    /// Quick spring for interactive elements
    static var quickSpring: Animation {
        .spring(response: 0.3, dampingFraction: 0.7)
    }
    
    /// Celebration animation with bounce
    static var celebration: Animation {
        .spring(response: 0.4, dampingFraction: 0.6)
    }
    
    /// Map reveal animation
    static var mapReveal: Animation {
        .easeOut(duration: 0.6)
    }
}








