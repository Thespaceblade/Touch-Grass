//
//  LandscapeBackground.swift
//  Touch-Grass
//
//  Realistic landscape background (hills, sun, trees, clouds, mountains)
//

import SwiftUI

// MARK: - Supporting Shapes and Views (defined first for use in LandscapeBackground)

// MARK: - Mountain Shape

struct MountainShape: Shape {
    let peaks: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: rect.height))
        
        // Create mountain peaks
        let peakWidth = rect.width / CGFloat(peaks + 1)
        
        for i in 0..<peaks {
            let peakX = peakWidth * CGFloat(i + 1)
            let peakHeight = rect.height * (0.2 + CGFloat(i % 2) * 0.1) // Vary peak heights
            
            if i == 0 {
                path.addLine(to: CGPoint(x: peakX, y: peakHeight))
            } else {
                let prevPeakX = peakWidth * CGFloat(i)
                let midX = (prevPeakX + peakX) / 2
                path.addLine(to: CGPoint(x: midX, y: rect.height * 0.5))
                path.addLine(to: CGPoint(x: peakX, y: peakHeight))
            }
        }
        
        // Complete to bottom right
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Hill Shape

struct HillShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start from bottom left
        path.move(to: CGPoint(x: 0, y: rect.height))
        
        // Create smooth wavy hill shape
        let controlPoints: [CGPoint] = [
            CGPoint(x: rect.width * 0.2, y: rect.height * 0.6),
            CGPoint(x: rect.width * 0.4, y: rect.height * 0.3),
            CGPoint(x: rect.width * 0.6, y: rect.height * 0.5),
            CGPoint(x: rect.width * 0.8, y: rect.height * 0.4),
            CGPoint(x: rect.width, y: rect.height * 0.7)
        ]
        
        // Create smooth curve through control points
        path.addCurve(
            to: controlPoints[0],
            control1: CGPoint(x: rect.width * 0.1, y: rect.height * 0.8),
            control2: CGPoint(x: rect.width * 0.15, y: rect.height * 0.7)
        )
        
        for i in 0..<controlPoints.count - 1 {
            let current = controlPoints[i]
            let next = controlPoints[i + 1]
            let midX = (current.x + next.x) / 2
            
            path.addQuadCurve(
                to: next,
                control: CGPoint(x: midX, y: min(current.y, next.y) - 10)
            )
        }
        
        // Complete the hill shape
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Realistic Hill

struct RealisticHill: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color
    
    var body: some View {
        HillShape()
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0.9),
                        color.opacity(0.7),
                        color.opacity(0.5)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: height)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
            .overlay(
                // Hill highlight (sunlight)
                HillShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
                    .frame(width: width, height: height)
            )
    }
}

// MARK: - Tree Top Shape

struct TreeTopShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Create cloud-like tree top using a single rounded shape
        // Start from top
        path.move(to: CGPoint(x: center.x, y: center.y - radius * 0.8))
        
        // Create wavy cloud-like top
        path.addCurve(
            to: CGPoint(x: center.x - radius * 0.6, y: center.y - radius * 0.3),
            control1: CGPoint(x: center.x - radius * 0.2, y: center.y - radius * 0.6),
            control2: CGPoint(x: center.x - radius * 0.4, y: center.y - radius * 0.4)
        )
        
        path.addCurve(
            to: CGPoint(x: center.x - radius * 0.3, y: center.y + radius * 0.2),
            control1: CGPoint(x: center.x - radius * 0.5, y: center.y - radius * 0.1),
            control2: CGPoint(x: center.x - radius * 0.4, y: center.y + radius * 0.1)
        )
        
        path.addCurve(
            to: CGPoint(x: center.x + radius * 0.3, y: center.y + radius * 0.2),
            control1: CGPoint(x: center.x - radius * 0.1, y: center.y + radius * 0.3),
            control2: CGPoint(x: center.x + radius * 0.1, y: center.y + radius * 0.3)
        )
        
        path.addCurve(
            to: CGPoint(x: center.x + radius * 0.6, y: center.y - radius * 0.3),
            control1: CGPoint(x: center.x + radius * 0.4, y: center.y + radius * 0.1),
            control2: CGPoint(x: center.x + radius * 0.5, y: center.y - radius * 0.1)
        )
        
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y - radius * 0.8),
            control1: CGPoint(x: center.x + radius * 0.4, y: center.y - radius * 0.4),
            control2: CGPoint(x: center.x + radius * 0.2, y: center.y - radius * 0.6)
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Realistic Tree

struct RealisticTree: View {
    let size: CGFloat
    let greenShade: Int // 0, 1, or 2 for different green shades
    let position: CGPoint
    
    private var treeGreen: Color {
        switch greenShade {
        case 0:
            return Color(red: 0.13, green: 0.55, blue: 0.13) // Forest green (#228B22)
        case 1:
            return Color(red: 0.18, green: 0.55, blue: 0.34) // Sea green (#2E8B57)
        default:
            return Color(red: 0.24, green: 0.70, blue: 0.44) // Medium sea green (#3CB371)
        }
    }
    
    private var trunkBrown: Color {
        return Color(red: 0.55, green: 0.27, blue: 0.07) // Saddle brown (#8B4513)
    }
    
    var body: some View {
        ZStack {
            // Tree shadow on ground
            Ellipse()
                .fill(Color.black.opacity(0.15))
                .frame(width: size * 0.8, height: size * 0.2)
                .offset(x: size * 0.1, y: size * 0.55)
            
            // Tree trunk
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            trunkBrown.opacity(0.6),
                            Color(red: 0.82, green: 0.71, blue: 0.55).opacity(0.5) // Tan
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.18, height: size * 0.45)
                .offset(y: size * 0.32)
            
            // Tree top (foliage)
            TreeTopShape()
                .fill(
                    RadialGradient(
                        colors: [
                            treeGreen.opacity(0.4),
                            treeGreen.opacity(0.3),
                            treeGreen.opacity(0.2)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size * 0.85)
                .shadow(color: treeGreen.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .position(position)
    }
}

// MARK: - Grass Tuft Shape

struct GrassTuftShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Create simple grass tuft with 3-4 blades
        let centerX = rect.midX
        let bladeWidth: CGFloat = rect.width / 4
        
        // Blade 1 (left)
        path.move(to: CGPoint(x: centerX - bladeWidth, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: centerX - bladeWidth * 0.5, y: rect.minY),
            control: CGPoint(x: centerX - bladeWidth * 0.7, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX - bladeWidth, y: rect.maxY),
            control: CGPoint(x: centerX - bladeWidth * 0.3, y: rect.midY)
        )
        
        // Blade 2 (center-left)
        path.move(to: CGPoint(x: centerX - bladeWidth * 0.3, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: rect.minY),
            control: CGPoint(x: centerX - bladeWidth * 0.2, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX - bladeWidth * 0.3, y: rect.maxY),
            control: CGPoint(x: centerX - bladeWidth * 0.1, y: rect.midY)
        )
        
        // Blade 3 (center-right)
        path.move(to: CGPoint(x: centerX + bladeWidth * 0.3, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: centerX, y: rect.minY),
            control: CGPoint(x: centerX + bladeWidth * 0.2, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX + bladeWidth * 0.3, y: rect.maxY),
            control: CGPoint(x: centerX + bladeWidth * 0.1, y: rect.midY)
        )
        
        // Blade 4 (right)
        path.move(to: CGPoint(x: centerX + bladeWidth, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: centerX + bladeWidth * 0.5, y: rect.minY),
            control: CGPoint(x: centerX + bladeWidth * 0.7, y: rect.midY)
        )
        path.addQuadCurve(
            to: CGPoint(x: centerX + bladeWidth, y: rect.maxY),
            control: CGPoint(x: centerX + bladeWidth * 0.3, y: rect.midY)
        )
        
        return path
    }
}

// MARK: - Realistic Grass Tuft

struct RealisticGrassTuft: View {
    let size: CGFloat
    let position: CGPoint
    
    var body: some View {
        GrassTuftShape()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.55, blue: 0.13).opacity(0.4), // Forest green
                        Color(red: 0.20, green: 0.55, blue: 0.13).opacity(0.3)  // Vibrant green
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: size, height: size * 0.7)
            .position(position)
    }
}

// MARK: - Wildflower

struct Wildflower: View {
    let type: Int // 0 = yellow, 1 = white, 2 = purple
    let position: CGPoint
    
    private var flowerColor: Color {
        switch type {
        case 0:
            return Color(red: 1.0, green: 0.84, blue: 0.0) // Yellow (#FFD700)
        case 1:
            return Color.white
        default:
            return Color(red: 0.58, green: 0.44, blue: 0.86) // Purple (#9370DB)
        }
    }
    
    var body: some View {
        ZStack {
            // Flower petals (simple circle for small size)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            flowerColor.opacity(0.8),
                            flowerColor.opacity(0.5)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 8
                    )
                )
                .frame(width: 16, height: 16)
            
            // Center
            Circle()
                .fill(
                    type == 0 ? Color(red: 0.80, green: 0.50, blue: 0.20) : // Orange center for yellow
                    type == 1 ? Color(red: 1.0, green: 0.98, blue: 0.80) : // Light yellow for white
                    Color(red: 0.50, green: 0.20, blue: 0.70) // Dark purple for purple
                )
                .frame(width: 6, height: 6)
        }
        .position(position)
    }
}

// MARK: - Small Rock

struct SmallRock: View {
    let size: CGFloat
    let position: CGPoint
    
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.3)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.50, green: 0.50, blue: 0.50).opacity(0.6), // Gray (#808080)
                        Color(red: 0.41, green: 0.41, blue: 0.41).opacity(0.5) // Dim gray (#696969)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size * 0.7)
            .position(position)
            .shadow(color: Color.black.opacity(0.2), radius: 3, x: 1, y: 2)
    }
}

// MARK: - Bush Shape

struct BushShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Create rounded bush shape (multiple overlapping circles)
        let circles: [(center: CGPoint, radius: CGFloat)] = [
            (CGPoint(x: center.x, y: center.y - radius * 0.2), radius * 0.5),
            (CGPoint(x: center.x - radius * 0.3, y: center.y), radius * 0.45),
            (CGPoint(x: center.x + radius * 0.3, y: center.y), radius * 0.45),
            (CGPoint(x: center.x, y: center.y + radius * 0.2), radius * 0.4)
        ]
        
        // Draw first circle
        if let first = circles.first {
            path.addEllipse(in: CGRect(
                x: first.center.x - first.radius,
                y: first.center.y - first.radius,
                width: first.radius * 2,
                height: first.radius * 2
            ))
        }
        
        // Add remaining circles
        for circle in circles.dropFirst() {
            let ellipse = Path(ellipseIn: CGRect(
                x: circle.center.x - circle.radius,
                y: circle.center.y - circle.radius,
                width: circle.radius * 2,
                height: circle.radius * 2
            ))
            path.addPath(ellipse)
        }
        
        return path
    }
}

// MARK: - Small Bush

struct SmallBush: View {
    let size: CGFloat
    let position: CGPoint
    
    var body: some View {
        BushShape()
            .fill(
                RadialGradient(
                    colors: [
                        Color(red: 0.13, green: 0.55, blue: 0.13).opacity(0.5), // Forest green
                        Color(red: 0.18, green: 0.55, blue: 0.34).opacity(0.4), // Sea green
                        Color(red: 0.13, green: 0.55, blue: 0.13).opacity(0.3)
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size * 0.5
                )
            )
            .frame(width: size, height: size * 0.8)
            .position(position)
            .shadow(color: Color(red: 0.13, green: 0.55, blue: 0.13).opacity(0.2), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Leaf Shape

struct LeafShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Simple leaf shape (oval with point)
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control: CGPoint(x: rect.maxX * 0.8, y: rect.minY + rect.height * 0.2)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.maxY),
            control: CGPoint(x: rect.maxX * 0.9, y: rect.maxY * 0.8)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control: CGPoint(x: rect.minX * 0.9, y: rect.maxY * 0.8)
        )
        path.addQuadCurve(
            to: CGPoint(x: rect.midX, y: rect.minY),
            control: CGPoint(x: rect.minX * 0.8, y: rect.minY + rect.height * 0.2)
        )
        path.closeSubpath()
        
        return path
    }
}

// MARK: - Leaf Cluster

struct LeafCluster: View {
    let position: CGPoint
    
    var body: some View {
        ZStack {
            // Multiple small leaves
            ForEach(0..<5, id: \.self) { index in
                LeafShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.13, green: 0.55, blue: 0.13).opacity(0.4),
                                Color(red: 0.20, green: 0.55, blue: 0.13).opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 12, height: 8)
                    .rotationEffect(.degrees(Double(index) * 15))
            }
        }
        .position(position)
    }
}


// MARK: - Main Landscape Background View

struct LandscapeBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    // Background layers (static)
    
    // Night mode detection
    private var isNightMode: Bool {
        colorScheme == .dark
    }
    
    var body: some View {
        ZStack {
            if isNightMode {
                // NIGHT MODE
                nightSkyGradient
                stars
                moon
                nightClouds
                nightDistantMountains
                nightMidGroundHills
                nightTrees
                nightNearHills
                nightForegroundDetails
            } else {
                // DAY MODE
                skyGradient
                farClouds
                midClouds
                birds
                sun
                distantMountains
                midGroundHills
                trees
                nearHills
                foregroundDetails
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea(.all) // Extend to full screen including notch and bottom
        // OPTIMIZATION: Remove animation - colorScheme changes are instant for better performance
    }
    
    // MARK: - Sky Gradient (Realistic Blue)
    
    private var skyGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.53, green: 0.81, blue: 0.92), // Light sky blue (#87CEEB)
                Color(red: 0.69, green: 0.88, blue: 0.90), // Sky blue (#B0E0E6)
                Color(red: 0.88, green: 0.95, blue: 0.97), // Light blue-white (#E0F2F7)
                AppColors.backgroundPrimary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Far Clouds
    
    private var farClouds: some View {
        ZStack {
            CloudShape(size: 120, position: CGPoint(x: 80, y: 180))
            CloudShape(size: 100, position: CGPoint(x: 280, y: 200))
            CloudShape(size: 115, position: CGPoint(x: 50, y: 210)) // Additional cloud
            CloudShape(size: 105, position: CGPoint(x: 320, y: 175)) // Additional cloud
        }
    }
    
    // MARK: - Mid Clouds
    
    private var midClouds: some View {
        ZStack {
            CloudShape(size: 140, position: CGPoint(x: 200, y: 160))
            CloudShape(size: 110, position: CGPoint(x: 350, y: 190))
            CloudShape(size: 130, position: CGPoint(x: 120, y: 170)) // Additional cloud
            CloudShape(size: 125, position: CGPoint(x: 300, y: 150)) // Additional cloud
        }
    }
    
    // MARK: - Birds
    
    private var birds: some View {
        ZStack {
            BirdSilhouette(position: CGPoint(x: 150, y: 220))
            BirdSilhouette(position: CGPoint(x: 300, y: 240))
            BirdSilhouette(position: CGPoint(x: 250, y: 200))
            BirdSilhouette(position: CGPoint(x: 100, y: 230)) // Additional bird
            BirdSilhouette(position: CGPoint(x: 330, y: 210)) // Additional bird
        }
    }
    
    // MARK: - Sun (Yellow/Orange - NOT GREEN!)
    
    private var sun: some View {
        ZStack {
            // Outer warm glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.80).opacity(0.4), // Warm yellow-white
                            Color(red: 1.0, green: 0.65, blue: 0.0).opacity(0.3), // Orange
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 30,
                        endRadius: 100
                    )
                )
                .frame(width: 200, height: 200)
                .blur(radius: 15)
            
            // Sun rays (subtle)
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.85, blue: 0.0).opacity(0.2),
                                Color.clear
                            ],
                            startPoint: .center,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 4, height: 40)
                    .offset(x: 50)
                    .rotationEffect(.degrees(Double(index) * 45))
            }
            
            // Main sun circle (bright yellow to orange)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.84, blue: 0.0), // Bright yellow (#FFD700)
                            Color(red: 1.0, green: 0.65, blue: 0.0), // Orange (#FFA500)
                            Color(red: 1.0, green: 0.55, blue: 0.0)  // Warm orange (#FF8C00)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: Color(red: 1.0, green: 0.65, blue: 0.0).opacity(0.5), radius: 20, x: 0, y: 0)
        }
        .position(x: 300, y: 120)
    }
    
    // MARK: - Distant Mountains (Atmospheric Perspective)
    
    private var distantMountains: some View {
        ZStack {
            // Mountain 1 (left, tallest)
            MountainShape(peaks: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.44, green: 0.50, blue: 0.56).opacity(0.4), // Blue-gray
                            Color(red: 0.44, green: 0.50, blue: 0.56).opacity(0.25),
                            Color(red: 0.44, green: 0.50, blue: 0.56).opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 180, height: 200)
                .position(x: 100, y: 480)
                .blur(radius: 2) // Atmospheric blur
            
            // Mountain 2 (center)
            MountainShape(peaks: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.41, green: 0.47, blue: 0.53).opacity(0.35),
                            Color(red: 0.41, green: 0.47, blue: 0.53).opacity(0.2),
                            Color(red: 0.41, green: 0.47, blue: 0.53).opacity(0.12)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 200, height: 180)
                .position(x: 200, y: 490)
                .blur(radius: 1.5)
            
            // Mountain 3 (right)
            MountainShape(peaks: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.44, green: 0.50, blue: 0.56).opacity(0.3),
                            Color(red: 0.44, green: 0.50, blue: 0.56).opacity(0.18),
                            Color(red: 0.44, green: 0.50, blue: 0.56).opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 160, height: 170)
                .position(x: 320, y: 485)
                .blur(radius: 2)
        }
    }
    
    // MARK: - Mid-Ground Hills
    
    private var midGroundHills: some View {
        ZStack {
            // Hill 1 (left) - medium green
            RealisticHill(
                width: 220,
                height: 160,
                color: Color(red: 0.42, green: 0.56, blue: 0.14) // Medium green (#6B8E23)
            )
            .position(x: 100, y: 500)
            
            // Hill 2 (center) - slightly darker green
            RealisticHill(
                width: 260,
                height: 190,
                color: Color(red: 0.40, green: 0.54, blue: 0.12)
            )
            .position(x: 200, y: 520)
            
            // Hill 3 (right) - medium green
            RealisticHill(
                width: 200,
                height: 150,
                color: Color(red: 0.42, green: 0.56, blue: 0.14)
            )
            .position(x: 320, y: 510)
        }
    }
    
    // MARK: - Trees (Variety)
    
    private var trees: some View {
        ZStack {
            // Tree variety with different sizes and green shades (increased from 6 to 12)
            RealisticTree(size: 75, greenShade: 0, position: CGPoint(x: 70, y: 450))
            RealisticTree(size: 95, greenShade: 1, position: CGPoint(x: 160, y: 440))
            RealisticTree(size: 85, greenShade: 2, position: CGPoint(x: 260, y: 445))
            RealisticTree(size: 90, greenShade: 0, position: CGPoint(x: 340, y: 455))
            RealisticTree(size: 80, greenShade: 1, position: CGPoint(x: 120, y: 460))
            RealisticTree(size: 100, greenShade: 2, position: CGPoint(x: 290, y: 438))
            // Additional trees for more detail
            RealisticTree(size: 88, greenShade: 0, position: CGPoint(x: 50, y: 465))
            RealisticTree(size: 82, greenShade: 1, position: CGPoint(x: 200, y: 435))
            RealisticTree(size: 92, greenShade: 2, position: CGPoint(x: 310, y: 450))
            RealisticTree(size: 78, greenShade: 0, position: CGPoint(x: 140, y: 470))
            RealisticTree(size: 96, greenShade: 1, position: CGPoint(x: 270, y: 432))
            RealisticTree(size: 84, greenShade: 2, position: CGPoint(x: 360, y: 460))
        }
    }
    
    // MARK: - Near Hills (Foreground)
    
    private var nearHills: some View {
        ZStack {
            // Near hill 1 (left) - vibrant green
            RealisticHill(
                width: 200,
                height: 130,
                color: Color(red: 0.20, green: 0.55, blue: 0.13) // Vibrant green (#32CD32)
            )
            .position(x: 120, y: 600)
            
            // Near hill 2 (right) - rich green
            RealisticHill(
                width: 240,
                height: 150,
                color: Color(red: 0.13, green: 0.55, blue: 0.13) // Rich green (#228B22)
            )
            .position(x: 300, y: 610)
        }
    }
    
    // MARK: - Foreground Details
    
    private var foregroundDetails: some View {
        ZStack {
            // Enhanced grass tufts (increased from 8 to 15)
            ForEach(0..<15, id: \.self) { index in
                RealisticGrassTuft(
                    size: 20 + CGFloat(index % 5) * 6,
                    position: foregroundGrassPositions[index]
                )
            }
            
            // Wildflowers (increased from 6 to 12)
            ForEach(0..<12, id: \.self) { index in
                Wildflower(
                    type: index % 3,
                    position: foregroundFlowerPositions[index]
                )
            }
            
            // Small rocks (increased from 5 to 10)
            ForEach(0..<10, id: \.self) { index in
                SmallRock(
                    size: 10 + CGFloat(index % 4) * 3,
                    position: foregroundRockPositions[index]
                )
            }
            
            // Additional details: small bushes on hills
            ForEach(0..<6, id: \.self) { index in
                SmallBush(
                    size: 35 + CGFloat(index % 3) * 5,
                    position: bushPositions[index]
                )
            }
            
            // Leaf clusters
            ForEach(0..<4, id: \.self) { index in
                LeafCluster(position: leafPositions[index])
            }
        }
    }
    
    // MARK: - Position Arrays
    
    private let foregroundGrassPositions: [CGPoint] = [
        CGPoint(x: 50, y: 650),
        CGPoint(x: 140, y: 680),
        CGPoint(x: 240, y: 670),
        CGPoint(x: 310, y: 690),
        CGPoint(x: 90, y: 720),
        CGPoint(x: 270, y: 710),
        CGPoint(x: 180, y: 700),
        CGPoint(x: 330, y: 730),
        CGPoint(x: 60, y: 700),
        CGPoint(x: 200, y: 690),
        CGPoint(x: 290, y: 700),
        CGPoint(x: 120, y: 740),
        CGPoint(x: 250, y: 750),
        CGPoint(x: 160, y: 680),
        CGPoint(x: 340, y: 720)
    ]
    
    private let foregroundFlowerPositions: [CGPoint] = [
        CGPoint(x: 80, y: 660),
        CGPoint(x: 200, y: 675),
        CGPoint(x: 280, y: 680),
        CGPoint(x: 130, y: 710),
        CGPoint(x: 250, y: 720),
        CGPoint(x: 160, y: 690),
        CGPoint(x: 70, y: 680),
        CGPoint(x: 220, y: 700),
        CGPoint(x: 300, y: 710),
        CGPoint(x: 110, y: 730),
        CGPoint(x: 240, y: 740),
        CGPoint(x: 170, y: 695)
    ]
    
    private let foregroundRockPositions: [CGPoint] = [
        CGPoint(x: 110, y: 690),
        CGPoint(x: 220, y: 700),
        CGPoint(x: 300, y: 715),
        CGPoint(x: 150, y: 730),
        CGPoint(x: 260, y: 740),
        CGPoint(x: 85, y: 710),
        CGPoint(x: 230, y: 725),
        CGPoint(x: 310, y: 735),
        CGPoint(x: 140, y: 750),
        CGPoint(x: 280, y: 745)
    ]
    
    private let bushPositions: [CGPoint] = [
        CGPoint(x: 100, y: 550),
        CGPoint(x: 220, y: 560),
        CGPoint(x: 290, y: 555),
        CGPoint(x: 130, y: 580),
        CGPoint(x: 250, y: 570),
        CGPoint(x: 180, y: 575)
    ]
    
    private let leafPositions: [CGPoint] = [
        CGPoint(x: 95, y: 680),
        CGPoint(x: 210, y: 690),
        CGPoint(x: 285, y: 685),
        CGPoint(x: 155, y: 710)
    ]
    
    // MARK: - Night Mode Views
    
    // MARK: - Night Sky Gradient
    
    private var nightSkyGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.10, blue: 0.16), // Dark navy (#0A1929)
                Color(red: 0.10, green: 0.12, blue: 0.23), // Deep purple-blue (#1A1F3A)
                Color(red: 0.05, green: 0.07, blue: 0.09), // Darker (#0D1117)
                AppColors.backgroundPrimary
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // MARK: - Stars
    
    private var stars: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { index in
                Star(
                    size: starSizes[index % starSizes.count],
                    position: starPositions[index % starPositions.count],
                    brightness: starBrightness[index % starBrightness.count]
                )
            }
        }
    }
    
    private let starPositions: [CGPoint] = [
        // Original 25 stars
        CGPoint(x: 60, y: 100), CGPoint(x: 120, y: 80), CGPoint(x: 180, y: 120),
        CGPoint(x: 240, y: 90), CGPoint(x: 300, y: 110), CGPoint(x: 360, y: 95),
        CGPoint(x: 80, y: 140), CGPoint(x: 150, y: 160), CGPoint(x: 220, y: 130),
        CGPoint(x: 280, y: 150), CGPoint(x: 340, y: 125), CGPoint(x: 100, y: 180),
        CGPoint(x: 170, y: 200), CGPoint(x: 250, y: 170), CGPoint(x: 320, y: 190),
        CGPoint(x: 50, y: 220), CGPoint(x: 130, y: 240), CGPoint(x: 210, y: 210),
        CGPoint(x: 290, y: 230), CGPoint(x: 360, y: 200), CGPoint(x: 70, y: 260),
        CGPoint(x: 160, y: 280), CGPoint(x: 270, y: 250), CGPoint(x: 350, y: 270),
        // Additional 25 stars for more density
        CGPoint(x: 40, y: 120), CGPoint(x: 90, y: 100), CGPoint(x: 140, y: 110),
        CGPoint(x: 200, y: 100), CGPoint(x: 260, y: 105), CGPoint(x: 330, y: 100),
        CGPoint(x: 55, y: 150), CGPoint(x: 110, y: 170), CGPoint(x: 190, y: 145),
        CGPoint(x: 270, y: 160), CGPoint(x: 350, y: 140), CGPoint(x: 75, y: 200),
        CGPoint(x: 145, y: 220), CGPoint(x: 230, y: 190), CGPoint(x: 310, y: 210),
        CGPoint(x: 35, y: 250), CGPoint(x: 105, y: 270), CGPoint(x: 195, y: 240),
        CGPoint(x: 275, y: 260), CGPoint(x: 365, y: 230), CGPoint(x: 65, y: 300),
        CGPoint(x: 155, y: 310), CGPoint(x: 255, y: 290), CGPoint(x: 345, y: 300)
    ]
    
    private let starSizes: [CGFloat] = [
        3, 2, 4, 2, 3, 2, 3, 2, 4, 2, 3, 2, 3, 4, 2, 3, 2, 3, 2, 4, 2, 3, 2, 3, 2,
        2, 3, 2, 3, 2, 4, 2, 3, 2, 3, 2, 4, 2, 3, 2, 3, 4, 2, 3, 2, 3, 2, 4, 2, 3
    ]
    private let starBrightness: [CGFloat] = [
        0.9, 0.7, 1.0, 0.6, 0.8, 0.7, 0.9, 0.6, 1.0, 0.7, 0.8, 0.6, 0.9, 1.0, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0, 0.6, 0.8, 0.7, 0.9, 0.6,
        0.7, 0.8, 0.6, 0.9, 0.7, 1.0, 0.6, 0.8, 0.7, 0.9, 0.6, 1.0, 0.7, 0.8, 0.6, 0.9, 1.0, 0.7, 0.8, 0.6, 0.9, 0.7, 1.0, 0.6, 0.8
    ]
    
    // MARK: - Moon
    
    private var moon: some View {
        ZStack {
            // Moon glow halo
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.90).opacity(0.3),
                            Color(red: 1.0, green: 0.95, blue: 0.80).opacity(0.2),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 40,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .blur(radius: 20)
            
            // Moon rays (subtle)
            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.98, blue: 0.90).opacity(0.15),
                                Color.clear
                            ],
                            startPoint: .center,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 3, height: 35)
                    .offset(x: 55)
                    .rotationEffect(.degrees(Double(index) * 60))
            }
            
            // Main moon (crescent moon)
            ZStack {
                // Full moon circle (for crescent effect)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.98, blue: 0.90), // Warm white
                                Color(red: 0.95, green: 0.95, blue: 0.85), // Slightly off-white
                                Color(red: 0.90, green: 0.90, blue: 0.80) // Warmer gray-white
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 110, height: 110)
                
                // Dark overlay to create crescent shape (offset to the right)
                Circle()
                    .fill(Color(red: 0.04, green: 0.10, blue: 0.16)) // Solid dark navy (matches night sky)
                    .frame(width: 120, height: 120) // Slightly larger to ensure full coverage
                    .offset(x: 30) // Increased offset to create proper crescent
                
                // Moon craters (subtle dark spots on visible crescent)
                Circle()
                    .fill(Color(red: 0.7, green: 0.7, blue: 0.65).opacity(0.3))
                    .frame(width: 12, height: 12)
                    .offset(x: -15, y: -10)
                Circle()
                    .fill(Color(red: 0.7, green: 0.7, blue: 0.65).opacity(0.25))
                    .frame(width: 10, height: 10)
                    .offset(x: -20, y: 15)
                Circle()
                    .fill(Color(red: 0.7, green: 0.7, blue: 0.65).opacity(0.2))
                    .frame(width: 8, height: 8)
                    .offset(x: -10, y: -5)
            }
            .shadow(color: Color(red: 1.0, green: 0.98, blue: 0.90).opacity(0.4), radius: 25, x: 0, y: 0)
        }
        .position(x: 300, y: 120)
    }
    
    // MARK: - Night Clouds
    
    private var nightClouds: some View {
        ZStack {
            NightCloudShape(size: 120, position: CGPoint(x: 80, y: 180))
            NightCloudShape(size: 100, position: CGPoint(x: 280, y: 200))
            NightCloudShape(size: 115, position: CGPoint(x: 50, y: 210))
            NightCloudShape(size: 140, position: CGPoint(x: 200, y: 160))
            NightCloudShape(size: 110, position: CGPoint(x: 350, y: 190))
        }
    }
    
    // MARK: - Night Distant Mountains
    
    private var nightDistantMountains: some View {
        ZStack {
            MountainShape(peaks: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.5),
                            Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.3),
                            Color(red: 0.02, green: 0.02, blue: 0.05).opacity(0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 180, height: 200)
                .position(x: 100, y: 480)
                .blur(radius: 3)
            
            MountainShape(peaks: 2)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.08, blue: 0.12).opacity(0.45),
                            Color(red: 0.04, green: 0.04, blue: 0.08).opacity(0.25),
                            Color(red: 0.02, green: 0.02, blue: 0.05).opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 200, height: 180)
                .position(x: 200, y: 490)
                .blur(radius: 2.5)
            
            MountainShape(peaks: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.4),
                            Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.25),
                            Color(red: 0.02, green: 0.02, blue: 0.05).opacity(0.15)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 160, height: 170)
                .position(x: 320, y: 485)
                .blur(radius: 3)
        }
    }
    
    // MARK: - Night Mid-Ground Hills
    
    private var nightMidGroundHills: some View {
        ZStack {
            RealisticHill(
                width: 220,
                height: 160,
                color: Color(red: 0.05, green: 0.15, blue: 0.05) // Very dark green
            )
            .position(x: 100, y: 500)
            
            RealisticHill(
                width: 260,
                height: 190,
                color: Color(red: 0.04, green: 0.12, blue: 0.04)
            )
            .position(x: 200, y: 520)
            
            RealisticHill(
                width: 200,
                height: 150,
                color: Color(red: 0.05, green: 0.15, blue: 0.05)
            )
            .position(x: 320, y: 510)
        }
    }
    
    // MARK: - Night Trees
    
    private var nightTrees: some View {
        ZStack {
            // Same tree positions, but darker/silhouetted
            ForEach(0..<12, id: \.self) { index in
                NightTree(
                    size: treeSizes[index],
                    position: treePositions[index]
                )
            }
        }
    }
    
    private let treeSizes: [CGFloat] = [75, 95, 85, 90, 80, 100, 88, 82, 92, 78, 96, 84]
    private let treePositions: [CGPoint] = [
        CGPoint(x: 70, y: 450), CGPoint(x: 160, y: 440), CGPoint(x: 260, y: 445),
        CGPoint(x: 340, y: 455), CGPoint(x: 120, y: 460), CGPoint(x: 290, y: 438),
        CGPoint(x: 50, y: 465), CGPoint(x: 200, y: 435), CGPoint(x: 310, y: 450),
        CGPoint(x: 140, y: 470), CGPoint(x: 270, y: 432), CGPoint(x: 360, y: 460)
    ]
    
    // MARK: - Night Near Hills
    
    private var nightNearHills: some View {
        ZStack {
            RealisticHill(
                width: 200,
                height: 130,
                color: Color(red: 0.06, green: 0.18, blue: 0.06) // Dark green
            )
            .position(x: 120, y: 600)
            
            RealisticHill(
                width: 240,
                height: 150,
                color: Color(red: 0.05, green: 0.16, blue: 0.05)
            )
            .position(x: 300, y: 610)
        }
    }
    
    // MARK: - Night Foreground Details
    
    private var nightForegroundDetails: some View {
        ZStack {
            // Dark grass tufts (silhouetted)
            ForEach(0..<15, id: \.self) { index in
                RealisticGrassTuft(
                    size: 20 + CGFloat(index % 5) * 6,
                    position: foregroundGrassPositions[index]
                )
                .opacity(0.3) // Much darker
            }
            
            // Dark rocks
            ForEach(0..<10, id: \.self) { index in
                SmallRock(
                    size: 10 + CGFloat(index % 4) * 3,
                    position: foregroundRockPositions[index]
                )
                .opacity(0.4)
            }
            
            // Fireflies (optional magical touch)
            ForEach(0..<4, id: \.self) { index in
                Firefly(position: fireflyPositions[index])
            }
        }
    }
    
    private let fireflyPositions: [CGPoint] = [
        CGPoint(x: 120, y: 650),
        CGPoint(x: 250, y: 680),
        CGPoint(x: 180, y: 720),
        CGPoint(x: 320, y: 700)
    ]
}

// MARK: - Cloud Shape

struct CloudShape: View {
    let size: CGFloat
    let position: CGPoint
    
    var body: some View {
        CloudPath()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.9),
                        Color.white.opacity(0.7),
                        Color(red: 0.9, green: 0.9, blue: 0.9).opacity(0.6)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size * 0.6)
            .position(position)
            .shadow(color: Color.gray.opacity(0.2), radius: 8, x: 0, y: 4)
    }
}

struct CloudPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        // Create fluffy cloud using multiple overlapping circles
        let circles: [(center: CGPoint, radius: CGFloat)] = [
            (CGPoint(x: center.x - rect.width * 0.2, y: center.y), rect.width * 0.25),
            (CGPoint(x: center.x, y: center.y - rect.height * 0.1), rect.width * 0.3),
            (CGPoint(x: center.x + rect.width * 0.2, y: center.y), rect.width * 0.25),
            (CGPoint(x: center.x - rect.width * 0.1, y: center.y + rect.height * 0.15), rect.width * 0.2),
            (CGPoint(x: center.x + rect.width * 0.1, y: center.y + rect.height * 0.15), rect.width * 0.2)
        ]
        
        // Draw first circle
        if let first = circles.first {
            path.addEllipse(in: CGRect(
                x: first.center.x - first.radius,
                y: first.center.y - first.radius,
                width: first.radius * 2,
                height: first.radius * 2
            ))
        }
        
        // Add remaining circles
        for circle in circles.dropFirst() {
            let ellipse = Path(ellipseIn: CGRect(
                x: circle.center.x - circle.radius,
                y: circle.center.y - circle.radius,
                width: circle.radius * 2,
                height: circle.radius * 2
            ))
            // Use union-like approach by drawing overlapping
            path.addPath(ellipse)
        }
        
        return path
    }
}

// MARK: - Star (Night Mode)

struct Star: View {
    let size: CGFloat
    let position: CGPoint
    let brightness: CGFloat
    
    @State private var twinkle: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Star glow (for bright stars)
            if brightness > 0.8 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.3 * brightness),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 2
                        )
                    )
                    .frame(width: size * 4, height: size * 4)
            }
            
            // Main star
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(brightness * twinkle),
                            Color(red: 0.9, green: 0.95, blue: 1.0).opacity(brightness * twinkle * 0.8)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size
                    )
                )
                .frame(width: size * 2, height: size * 2)
        }
        .position(position)
        .onAppear {
            // Subtle twinkling animation
            withAnimation(
                Animation.easeInOut(duration: 3.0 + Double.random(in: 0...2))
                    .repeatForever(autoreverses: true)
            ) {
                twinkle = 0.7
            }
        }
    }
}

// MARK: - Night Cloud Shape

struct NightCloudShape: View {
    let size: CGFloat
    let position: CGPoint
    
    var body: some View {
        CloudPath()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.2, green: 0.2, blue: 0.3).opacity(0.4),
                        Color(red: 0.15, green: 0.15, blue: 0.25).opacity(0.3),
                        Color(red: 0.1, green: 0.1, blue: 0.2).opacity(0.2)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size * 0.6)
            .position(position)
            .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Night Tree

struct NightTree: View {
    let size: CGFloat
    let position: CGPoint
    
    var body: some View {
        ZStack {
            // Tree shadow on ground (more pronounced at night)
            Ellipse()
                .fill(Color.black.opacity(0.3))
                .frame(width: size * 0.8, height: size * 0.2)
                .offset(x: size * 0.1, y: size * 0.55)
            
            // Tree trunk (darker)
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.2, green: 0.15, blue: 0.1).opacity(0.7),
                            Color(red: 0.15, green: 0.1, blue: 0.05).opacity(0.6)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: size * 0.18, height: size * 0.45)
                .offset(y: size * 0.32)
            
            // Tree top (silhouetted, with moonlit edge)
            TreeTopShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.05, green: 0.15, blue: 0.05).opacity(0.6), // Dark green
                            Color(red: 0.02, green: 0.08, blue: 0.02).opacity(0.5), // Very dark green
                            Color.black.opacity(0.4) // Black silhouette
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size * 0.85)
                .overlay(
                    // Moonlit edge highlight
                    TreeTopShape()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.3, green: 0.3, blue: 0.25).opacity(0.3),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            ),
                            lineWidth: 2
                        )
                        .frame(width: size, height: size * 0.85)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
        }
        .position(position)
    }
}

// MARK: - Firefly (Night Mode)

struct Firefly: View {
    let position: CGPoint
    
    @State private var glowIntensity: CGFloat = 0.5
    @State private var offset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.5).opacity(0.4 * glowIntensity),
                            Color(red: 1.0, green: 0.85, blue: 0.3).opacity(0.2 * glowIntensity),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 15
                    )
                )
                .frame(width: 30, height: 30)
                .blur(radius: 3)
            
            // Firefly body
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.5), // Warm yellow
                            Color(red: 1.0, green: 0.85, blue: 0.3)  // Orange-yellow
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 4
                    )
                )
                .frame(width: 8, height: 8)
        }
        .position(
            x: position.x + offset.width,
            y: position.y + offset.height
        )
        .onAppear {
            // Gentle floating animation
            withAnimation(
                Animation.easeInOut(duration: 2.0 + Double.random(in: 0...1))
                    .repeatForever(autoreverses: true)
            ) {
                offset = CGSize(width: CGFloat.random(in: -10...10), height: CGFloat.random(in: -15...15))
            }
            
            // Glow pulsing
            withAnimation(
                Animation.easeInOut(duration: 1.5 + Double.random(in: 0...0.5))
                    .repeatForever(autoreverses: true)
            ) {
                glowIntensity = 1.0
            }
        }
    }
}

// MARK: - Bird Silhouette

struct BirdSilhouette: View {
    let position: CGPoint
    
    var body: some View {
        BirdShape()
            .fill(Color(red: 0.18, green: 0.31, blue: 0.31).opacity(0.6)) // Dark slate gray
            .frame(width: 30, height: 20)
            .position(position)
    }
}

struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Simple bird silhouette (flying V shape)
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

