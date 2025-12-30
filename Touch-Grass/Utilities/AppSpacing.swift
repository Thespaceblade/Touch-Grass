//
//  AppSpacing.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import SwiftUI

struct AppSpacing {
    // 8pt grid system
    static let xs: CGFloat = 4   // 0.5x
    static let sm: CGFloat = 8   // 1x
    static let md: CGFloat = 16  // 2x
    static let lg: CGFloat = 24  // 3x
    static let xl: CGFloat = 32  // 4x
    static let xxl: CGFloat = 48 // 6x
    static let xxxl: CGFloat = 64 // 8x
    
    // Common spacing combinations
    static let cardPadding: CGFloat = md
    static let screenPadding: CGFloat = md
    static let sectionSpacing: CGFloat = lg
    static let itemSpacing: CGFloat = sm
}

// MARK: - View Extensions for Spacing

extension View {
    func appPadding(_ edges: Edge.Set = .all, _ amount: CGFloat = AppSpacing.md) -> some View {
        padding(edges, amount)
    }
    
    func appPadding(_ amount: CGFloat) -> some View {
        padding(amount)
    }
}