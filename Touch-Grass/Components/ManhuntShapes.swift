//
//  ManhuntShapes.swift
//  Touch-Grass
//
//  Custom shapes for Manhunt background (urban cityscape theme)
//

import SwiftUI

// MARK: - Building Shape (Realistic Urban Building)

struct BuildingShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let windowCount: Int
    let hasFireEscape: Bool
    let hasLedges: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Building outline with slight perspective
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.05)) // Slight base
        path.addLine(to: CGPoint(x: rect.width * 0.02, y: 0)) // Slight perspective
        path.addLine(to: CGPoint(x: rect.width * 0.98, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        
        // Add ledges/floors (horizontal lines)
        if hasLedges {
            let floorCount = Int(height / 30)
            for i in 1..<floorCount {
                let y = CGFloat(i) * (rect.height / CGFloat(floorCount))
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: rect.width, y: y))
            }
        }
        
        return path
    }
    
    // Helper to get window positions (realistic grid pattern)
    func windowPositions(in rect: CGRect) -> [CGRect] {
        var windows: [CGRect] = []
        let columns = 3
        let windowRows = max(2, windowCount / columns)
        let windowWidth = rect.width * 0.18
        let windowHeight = rect.height * 0.08
        let spacingX = (rect.width - (CGFloat(columns) * windowWidth)) / CGFloat(columns + 1)
        let spacingY = rect.height * 0.12
        
        for row in 0..<windowRows {
            for col in 0..<columns {
                let x = spacingX + CGFloat(col) * (windowWidth + spacingX)
                let y = spacingY + CGFloat(row) * (windowHeight + spacingY * 0.8)
                
                if x + windowWidth <= rect.width && y + windowHeight <= rect.height * 0.9 {
                    windows.append(CGRect(x: x, y: y, width: windowWidth, height: windowHeight))
                }
            }
        }
        
        return windows
    }
}

// MARK: - Fire Escape Shape

struct FireEscapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Vertical ladder
        let ladderX = rect.width * 0.85
        
        // Main vertical support
        path.addRect(CGRect(
            x: ladderX,
            y: rect.height * 0.2,
            width: 2,
            height: rect.height * 0.7
        ))
        
        // Horizontal platforms (every floor)
        let platformCount = 4
        for i in 0..<platformCount {
            let y = rect.height * 0.25 + CGFloat(i) * (rect.height * 0.6 / CGFloat(platformCount))
            
            // Platform
            path.addRect(CGRect(
                x: ladderX - rect.width * 0.1,
                y: y,
                width: rect.width * 0.12,
                height: 2
            ))
            
            // Railing
            path.addRect(CGRect(
                x: ladderX - rect.width * 0.1,
                y: y - 3,
                width: rect.width * 0.12,
                height: 1
            ))
        }
        
        return path
    }
}

// MARK: - Skyscraper Shape (Realistic Tall Building)

struct SkyscraperShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let windowCount: Int
    let hasSpire: Bool
    let hasSetbacks: Bool // Architectural setbacks
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Main building base
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.15))
        
        // Setbacks (if applicable) - creates stepped appearance
        if hasSetbacks {
            // First setback
            path.addLine(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.15))
            path.addLine(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.08))
            path.addLine(to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.08))
            path.addLine(to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.15))
        }
        
        // Top section
        if hasSpire {
            // Spire/antenna top
            path.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.15))
            path.addLine(to: CGPoint(x: rect.width * 0.5, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.6, y: rect.height * 0.15))
        } else {
            // Flat or stepped top
            path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.height * 0.15))
            path.addLine(to: CGPoint(x: rect.width * 0.2, y: rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.15))
        }
        
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.15))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        
        return path
    }
    
    // Helper to get window positions (realistic grid for skyscrapers)
    func windowPositions(in rect: CGRect) -> [CGRect] {
        var windows: [CGRect] = []
        let columns = 4
        let windowRows = max(3, windowCount / columns)
        let windowWidth = rect.width * 0.12
        let windowHeight = rect.height * 0.06
        let spacingX = (rect.width - (CGFloat(columns) * windowWidth)) / CGFloat(columns + 1)
        let spacingY = rect.height * 0.1
        
        for row in 0..<windowRows {
            for col in 0..<columns {
                let x = spacingX + CGFloat(col) * (windowWidth + spacingX)
                let y = spacingY + CGFloat(row) * (windowHeight + spacingY * 0.7)
                
                if x + windowWidth <= rect.width && y + windowHeight <= rect.height * 0.85 {
                    windows.append(CGRect(x: x, y: y, width: windowWidth, height: windowHeight))
                }
            }
        }
        
        return windows
    }
}

// MARK: - Streetlight Shape

struct StreetlightShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Pole
        let poleWidth = rect.width * 0.1
        path.addRect(CGRect(
            x: rect.midX - poleWidth / 2,
            y: rect.height * 0.3,
            width: poleWidth,
            height: rect.height * 0.7
        ))
        
        // Top arm
        path.move(to: CGPoint(x: rect.midX, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.2, y: rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.2, y: rect.height * 0.1))
        path.closeSubpath()
        
        // Light bulb (circle)
        let bulbSize = rect.width * 0.15
        path.addEllipse(in: CGRect(
            x: rect.midX - bulbSize / 2,
            y: rect.height * 0.05,
            width: bulbSize,
            height: bulbSize
        ))
        
        return path
    }
}

// MARK: - Car Shape

struct CarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Car body (rounded rectangle)
        let bodyHeight = rect.height * 0.5
        let bodyY = rect.height * 0.25
        
        // Main body
        path.addRoundedRect(
            in: CGRect(x: 0, y: bodyY, width: rect.width, height: bodyHeight),
            cornerSize: CGSize(width: rect.width * 0.1, height: rect.height * 0.1)
        )
        
        // Windshield
        path.addRect(CGRect(
            x: rect.width * 0.15,
            y: bodyY + bodyHeight * 0.1,
            width: rect.width * 0.3,
            height: bodyHeight * 0.4
        ))
        
        // Wheels
        let wheelSize = rect.width * 0.15
        path.addEllipse(in: CGRect(
            x: rect.width * 0.15,
            y: bodyY + bodyHeight * 0.7,
            width: wheelSize,
            height: wheelSize
        ))
        path.addEllipse(in: CGRect(
            x: rect.width * 0.7,
            y: bodyY + bodyHeight * 0.7,
            width: wheelSize,
            height: wheelSize
        ))
        
        return path
    }
}

// MARK: - Smoke Shape

struct ManhuntSmokeShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Wispy smoke cloud using curves
        let startY = rect.height * 0.8
        let endY = rect.height * 0.2
        
        // Base of smoke
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.1, y: startY))
        
        // Wavy smoke path
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.15, y: startY * 0.7),
            control1: CGPoint(x: rect.midX, y: startY * 0.9),
            control2: CGPoint(x: rect.midX + rect.width * 0.05, y: startY * 0.8)
        )
        
        path.addCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.1, y: startY * 0.5),
            control1: CGPoint(x: rect.midX + rect.width * 0.2, y: startY * 0.6),
            control2: CGPoint(x: rect.midX + rect.width * 0.05, y: startY * 0.55)
        )
        
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.2, y: endY),
            control1: CGPoint(x: rect.midX - rect.width * 0.2, y: startY * 0.4),
            control2: CGPoint(x: rect.midX, y: startY * 0.3)
        )
        
        // Close the shape
        path.addCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.1, y: startY),
            control1: CGPoint(x: rect.midX + rect.width * 0.1, y: startY * 0.9),
            control2: CGPoint(x: rect.midX - rect.width * 0.05, y: startY * 0.95)
        )
        
        return path
    }
}

// MARK: - Billboard Shape

struct BillboardShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Billboard frame
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height * 0.7),
            cornerSize: CGSize(width: 3, height: 3)
        )
        
        // Support posts
        path.addRect(CGRect(x: rect.width * 0.1, y: rect.height * 0.7, width: 3, height: rect.height * 0.3))
        path.addRect(CGRect(x: rect.width * 0.9, y: rect.height * 0.7, width: 3, height: rect.height * 0.3))
        
        return path
    }
}

// MARK: - AC Unit Shape

struct ACUnitShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // AC unit box
        path.addRoundedRect(
            in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height),
            cornerSize: CGSize(width: 2, height: 2)
        )
        
        // Vent slats
        for i in 0..<3 {
            path.addRect(CGRect(
                x: 0,
                y: CGFloat(i) * (rect.height / 4) + rect.height * 0.2,
                width: rect.width,
                height: 1
            ))
        }
        
        return path
    }
}

// MARK: - Cloud Shape (Wispy Dark Clouds) - Manhunt specific

struct ManhuntCloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Create wispy, irregular cloud using multiple overlapping circles
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) * 0.4
        
        // Main cloud body (multiple overlapping circles)
        let cloudParts: [(center: CGPoint, radius: CGFloat)] = [
            (CGPoint(x: center.x - baseRadius * 0.3, y: center.y), baseRadius * 0.6),
            (CGPoint(x: center.x, y: center.y - baseRadius * 0.2), baseRadius * 0.7),
            (CGPoint(x: center.x + baseRadius * 0.3, y: center.y), baseRadius * 0.5),
            (CGPoint(x: center.x - baseRadius * 0.1, y: center.y + baseRadius * 0.2), baseRadius * 0.4),
            (CGPoint(x: center.x + baseRadius * 0.2, y: center.y + baseRadius * 0.1), baseRadius * 0.35)
        ]
        
        // Draw first circle
        if let first = cloudParts.first {
            path.addEllipse(in: CGRect(
                x: first.center.x - first.radius,
                y: first.center.y - first.radius,
                width: first.radius * 2,
                height: first.radius * 2
            ))
        }
        
        // Add remaining circles
        for part in cloudParts.dropFirst() {
            let ellipse = Path(ellipseIn: CGRect(
                x: part.center.x - part.radius,
                y: part.center.y - part.radius,
                width: part.radius * 2,
                height: part.radius * 2
            ))
            path.addPath(ellipse)
        }
        
        return path
    }
}

// MARK: - Street View Building Shape (Perspective-Aware)

struct StreetViewBuildingShape: Shape {
    let width: CGFloat
    let height: CGFloat
    let windowCount: Int
    let hasFireEscape: Bool
    let roofType: RoofType
    
    enum RoofType {
        case flat
        case stepped
        case sloped
        case rooftopStructures
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Building base (slightly tapered for perspective)
        let topWidth = rect.width * 0.98 // Slight taper
        
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height * 0.05))
        path.addLine(to: CGPoint(x: (rect.width - topWidth) / 2, y: 0))
        path.addLine(to: CGPoint(x: (rect.width - topWidth) / 2 + topWidth, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height))
        path.closeSubpath()
        
        // Roof details
        switch roofType {
        case .stepped:
            // Stepped roof
            path.move(to: CGPoint(x: rect.width * 0.2, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.2, y: -rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: -rect.height * 0.05))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: 0))
        case .sloped:
            // Sloped roof
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width * 0.5, y: -rect.height * 0.08))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
        case .rooftopStructures:
            // Rooftop structures (AC units, etc.)
            path.addRect(CGRect(x: rect.width * 0.1, y: -rect.height * 0.03, width: rect.width * 0.15, height: rect.height * 0.03))
            path.addRect(CGRect(x: rect.width * 0.75, y: -rect.height * 0.03, width: rect.width * 0.15, height: rect.height * 0.03))
        case .flat:
            break
        }
        
        return path
    }
    
    // Helper to get window positions (realistic grid)
    func windowPositions(in rect: CGRect) -> [CGRect] {
        var windows: [CGRect] = []
        let columns = 3
        let windowRows = max(2, windowCount / columns)
        let windowWidth = rect.width * 0.2
        let windowHeight = rect.height * 0.08
        let spacingX = (rect.width - (CGFloat(columns) * windowWidth)) / CGFloat(columns + 1)
        let spacingY = rect.height * 0.12
        
        for row in 0..<windowRows {
            for col in 0..<columns {
                let x = spacingX + CGFloat(col) * (windowWidth + spacingX)
                let y = spacingY + CGFloat(row) * (windowHeight + spacingY * 0.8)
                
                if x + windowWidth <= rect.width && y + windowHeight <= rect.height * 0.9 {
                    windows.append(CGRect(x: x, y: y, width: windowWidth, height: windowHeight))
                }
            }
        }
        
        return windows
    }
}

// MARK: - Fog Shape

struct FogShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Wispy fog using curves
        let startY = rect.height * 0.9
        let endY = rect.height * 0.3
        
        // Base of fog
        path.move(to: CGPoint(x: rect.midX - rect.width * 0.2, y: startY))
        
        // Wavy fog path
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.15, y: startY * 0.7),
            control1: CGPoint(x: rect.midX - rect.width * 0.05, y: startY * 0.9),
            control2: CGPoint(x: rect.midX + rect.width * 0.05, y: startY * 0.8)
        )
        
        path.addCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.1, y: startY * 0.5),
            control1: CGPoint(x: rect.midX + rect.width * 0.2, y: startY * 0.6),
            control2: CGPoint(x: rect.midX + rect.width * 0.05, y: startY * 0.55)
        )
        
        path.addCurve(
            to: CGPoint(x: rect.midX + rect.width * 0.25, y: endY),
            control1: CGPoint(x: rect.midX - rect.width * 0.25, y: startY * 0.4),
            control2: CGPoint(x: rect.midX, y: startY * 0.3)
        )
        
        // Close the shape
        path.addCurve(
            to: CGPoint(x: rect.midX - rect.width * 0.2, y: startY),
            control1: CGPoint(x: rect.midX + rect.width * 0.15, y: startY * 0.9),
            control2: CGPoint(x: rect.midX - rect.width * 0.1, y: startY * 0.95)
        )
        
        return path
    }
}

// MARK: - Graffiti Shape

struct GraffitiShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Abstract graffiti pattern (stylized letters/shapes)
        // Letter "M" style
        path.move(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.2))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.8))
        
        // Decorative swirl
        path.move(to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.5))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.3),
            control1: CGPoint(x: rect.width * 0.8, y: rect.height * 0.4),
            control2: CGPoint(x: rect.width * 0.85, y: rect.height * 0.35)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.7, y: rect.height * 0.5),
            control1: CGPoint(x: rect.width * 0.95, y: rect.height * 0.25),
            control2: CGPoint(x: rect.width * 0.8, y: rect.height * 0.4)
        )
        
        return path
    }
}

