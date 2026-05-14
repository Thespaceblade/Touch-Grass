//
//  BackgroundShapes.swift
//  Touch-Grass
//
//  Decorative background shapes
//

import SwiftUI

struct BackgroundShapes: View {
    // Depth layers for background shapes
    
    var body: some View {
        ZStack {
            // Layer 1: Far layer (small shapes)
            farLayer
            
            // Layer 2: Mid layer (medium shapes)
            midLayer
            
            // Layer 3: Near layer (large shapes)
            nearLayer
        }
        .allowsHitTesting(false) // Don't block touches
        .ignoresSafeArea(.all) // Extend to all edges including notch
        .drawingGroup() // OPTIMIZATION: Render as single image for maximum performance
    }
    
    // MARK: - Far Layer (Background)
    
    private var farLayer: some View {
        ZStack {
            // Themed icons scattered across background (Manhunt, Zombie Tag, CTF)
            ForEach(0..<8, id: \.self) { index in
                let theme = getThemeForIndex(index)
                ThemedIcon(
                    iconName: theme.icon,
                    colors: theme.colors,
                    size: 40
                )
                .position(farLayerPositions[index])
            }
        }
    }
    
    // MARK: - Mid Layer (Middle ground)
    
    private var midLayer: some View {
        ZStack {
            // Medium themed icons
            ForEach(0..<6, id: \.self) { index in
                let theme = getThemeForIndex(index)
                ThemedIcon(
                    iconName: theme.icon,
                    colors: theme.colors,
                    size: 60
                )
                .position(midLayerPositions[index])
            }
        }
    }
    
    // MARK: - Near Layer (Foreground)
    
    private var nearLayer: some View {
        ZStack {
            // Large themed icons for foreground depth
            ForEach(0..<4, id: \.self) { index in
                let theme = getThemeForIndex(index)
                ThemedIcon(
                    iconName: theme.icon,
                    colors: theme.colors,
                    size: 80
                )
                .blur(radius: 1) // Subtle blur for depth
                .position(nearLayerPositions[index])
            }
        }
    }
    
    // MARK: - Theme Helper
    
    private struct GameTheme {
        let icon: String
        let colors: [Color]
    }
    
    private func getThemeForIndex(_ index: Int) -> GameTheme {
        // Cycle through game themes: Manhunt, Zombie Tag, CTF
        let themeIndex = index % 3
        
        switch themeIndex {
        case 0: // Manhunt (hunter/seeker theme)
            let manhuntIcons = ["eye.fill", "target", "location.fill", "scope"]
            let iconIndex = (index / 3) % manhuntIcons.count
            return GameTheme(
                icon: manhuntIcons[iconIndex],
                colors: [
                    AppColors.manhuntPrimary.opacity(0.25),
                    AppColors.manhuntSecondary.opacity(0.15),
                    AppColors.manhuntLight.opacity(0.1)
                ]
            )
        case 1: // Zombie Tag (infection/zombie theme)
            let zombieIcons = ["exclamationmark.triangle.fill", "bolt.fill", "cross.case.fill", "allergens"]
            let iconIndex = (index / 3) % zombieIcons.count
            return GameTheme(
                icon: zombieIcons[iconIndex],
                colors: [
                    AppColors.zombiePrimary.opacity(0.25),
                    AppColors.zombieSecondary.opacity(0.15),
                    AppColors.zombieLight.opacity(0.1)
                ]
            )
        default: // Capture The Flag (military/flag theme)
            let ctfIcons = ["flag.fill", "shield.fill", "star.fill", "location.fill"]
            let iconIndex = (index / 3) % ctfIcons.count
            return GameTheme(
                icon: ctfIcons[iconIndex],
                colors: [
                    AppColors.ctfPrimary.opacity(0.25),
                    AppColors.ctfSecondary.opacity(0.15),
                    AppColors.ctfLight.opacity(0.1)
                ]
            )
        }
    }
    
    // MARK: - Shape Positions (scattered across screen, avoiding content area)
    
    // Far layer positions (background)
    private let farLayerPositions: [CGPoint] = [
        CGPoint(x: 80, y: 150),
        CGPoint(x: 300, y: 200),
        CGPoint(x: 150, y: 400),
        CGPoint(x: 350, y: 500),
        CGPoint(x: 50, y: 600),
        CGPoint(x: 280, y: 700),
        CGPoint(x: 120, y: 800),
        CGPoint(x: 320, y: 900)
    ]
    
    // Mid layer positions
    private let midLayerPositions: [CGPoint] = [
        CGPoint(x: 200, y: 180),
        CGPoint(x: 100, y: 350),
        CGPoint(x: 300, y: 450),
        CGPoint(x: 150, y: 650),
        CGPoint(x: 250, y: 750),
        CGPoint(x: 80, y: 850)
    ]
    
    // Near layer positions (foreground)
    private let nearLayerPositions: [CGPoint] = [
        CGPoint(x: 120, y: 250),
        CGPoint(x: 280, y: 400),
        CGPoint(x: 90, y: 600),
        CGPoint(x: 310, y: 800)
    ]
}

// MARK: - Themed Icon Component

struct ThemedIcon: View {
    let iconName: String
    let colors: [Color]
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Outer glow
            Image(systemName: iconName)
                .font(.system(size: size * 1.2, weight: .light))
                .foregroundStyle(
                    LinearGradient(
                        colors: colors.map { $0.opacity(0.3) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blur(radius: 4)
            
            // Main icon
            Image(systemName: iconName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: colors.first?.opacity(0.4) ?? Color.clear, radius: 8, x: 0, y: 0)
        }
    }
}

