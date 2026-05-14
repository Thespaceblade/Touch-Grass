//
//  DetailedZombieComponents.swift
//  Touch-Grass
//
//  Detailed zombie components for background
//

import SwiftUI

// MARK: - Zombie Variant System

enum ZombieType {
    case walker      // Standard slow shuffler
    case reacher      // One arm reaching forward
    case stagger      // Severe limp, off-balance
    case fresh        // Minimal decay, more human-like
    case advancedDecay // Extensive decay, bone exposure
}

enum ZombiePose {
    case standardShuffle  // Both arms hanging, slight forward lean
    case reaching         // One arm extended forward
    case limping          // One leg bent/shorter, off-balance
    case staggering       // Severe forward lean, arms out
    case hunched          // Severe forward bend, head down
    case twisted          // Body twisted at waist
}

nonisolated extension ZombiePose: Equatable {
    static func == (lhs: ZombiePose, rhs: ZombiePose) -> Bool {
        switch (lhs, rhs) {
        case (.standardShuffle, .standardShuffle),
             (.reaching, .reaching),
             (.limping, .limping),
             (.staggering, .staggering),
             (.hunched, .hunched),
             (.twisted, .twisted):
            return true
        default:
            return false
        }
    }
}

enum DecayLevel {
    case fresh      // Minimal decay
    case moderate   // Some decay visible
    case advanced   // Extensive decay
    case severe     // Mostly bone
}

nonisolated extension DecayLevel: Equatable {
    static func == (lhs: DecayLevel, rhs: DecayLevel) -> Bool {
        switch (lhs, rhs) {
        case (.fresh, .fresh),
             (.moderate, .moderate),
             (.advanced, .advanced),
             (.severe, .severe):
            return true
        default:
            return false
        }
    }
}

enum BodyPart {
    case leftHand
    case rightHand
    case leftFoot
    case rightFoot
    case leftArm
    case rightArm
    case leftLeg
    case rightLeg
    case jaw
    case eye
}

nonisolated extension BodyPart: Hashable {
    func hash(into hasher: inout Hasher) {
        switch self {
        case .leftHand: hasher.combine(0)
        case .rightHand: hasher.combine(1)
        case .leftFoot: hasher.combine(2)
        case .rightFoot: hasher.combine(3)
        case .leftArm: hasher.combine(4)
        case .rightArm: hasher.combine(5)
        case .leftLeg: hasher.combine(6)
        case .rightLeg: hasher.combine(7)
        case .jaw: hasher.combine(8)
        case .eye: hasher.combine(9)
        }
    }
    
    static func == (lhs: BodyPart, rhs: BodyPart) -> Bool {
        switch (lhs, rhs) {
        case (.leftHand, .leftHand),
             (.rightHand, .rightHand),
             (.leftFoot, .leftFoot),
             (.rightFoot, .rightFoot),
             (.leftArm, .leftArm),
             (.rightArm, .rightArm),
             (.leftLeg, .leftLeg),
             (.rightLeg, .rightLeg),
             (.jaw, .jaw),
             (.eye, .eye):
            return true
        default:
            return false
        }
    }
}

struct ZombieVariant {
    let type: ZombieType
    let pose: ZombiePose
    let decayLevel: DecayLevel
    let size: CGFloat
    let hasClothing: Bool
    let missingParts: Set<BodyPart>
    
    // Color based on decay level
    var skinColor: Color {
        switch decayLevel {
        case .fresh:
            return Color(red: 0.75, green: 0.78, blue: 0.7) // Pale green-gray
        case .moderate:
            return Color(red: 0.7, green: 0.75, blue: 0.65) // Slightly decayed
        case .advanced:
            return Color(red: 0.6, green: 0.7, blue: 0.55) // More decayed
        case .severe:
            return Color(red: 0.5, green: 0.65, blue: 0.45) // Very decayed
        }
    }
    
    var decayColor: Color {
        AppColors.zombieDecay
    }
    
    var boneColor: Color {
        Color(red: 0.9, green: 0.85, blue: 0.8) // Off-white
    }
    
    var clothingColor: Color {
        Color(red: 0.3, green: 0.3, blue: 0.35) // Muted gray
    }
}

// MARK: - Zombie Head Shape

struct ZombieHeadShape: Shape {
    let variant: ZombieVariant
    let hasHair: Bool
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let headWidth = rect.width * 0.3
        let headHeight = rect.height * 0.25
        
        // Head outline (slightly lopsided for decay)
        let headOffset = variant.decayLevel == .severe ? rect.width * 0.02 : 0
        path.addEllipse(in: CGRect(
            x: centerX - headWidth * 0.5 + headOffset,
            y: rect.minY,
            width: headWidth,
            height: headHeight
        ))
        
        return path
    }
}

// MARK: - Zombie Facial Features

struct ZombieFacialFeatures: View {
    let variant: ZombieVariant
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let rect = geometry.frame(in: .local)
                let centerX = rect.midX
                let headHeight = rect.height * 0.25
                
                // Eye sockets
                if !variant.missingParts.contains(.eye) {
                    // Left eye socket
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: rect.width * 0.08, height: rect.width * 0.08)
                        .position(
                            x: centerX - rect.width * 0.08,
                            y: headHeight * 0.4
                        )
                    
                    // Right eye socket
                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: rect.width * 0.08, height: rect.width * 0.08)
                        .position(
                            x: centerX + rect.width * 0.08,
                            y: headHeight * 0.4
                        )
                } else {
                    // Missing eye - show exposed bone
                    Circle()
                        .fill(variant.boneColor.opacity(0.8))
                        .frame(width: rect.width * 0.1, height: rect.width * 0.1)
                        .position(
                            x: centerX,
                            y: headHeight * 0.4
                        )
                }
                
                // Mouth (open, showing teeth)
                if !variant.missingParts.contains(.jaw) {
                    // Open mouth
                    Ellipse()
                        .fill(Color.black.opacity(0.7))
                        .frame(width: rect.width * 0.12, height: rect.width * 0.08)
                        .position(
                            x: centerX,
                            y: headHeight * 0.7
                        )
                    
                    // Teeth (top row)
                    ForEach(0..<4, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 1)
                            .fill(variant.boneColor)
                            .frame(width: rect.width * 0.015, height: rect.width * 0.02)
                            .position(
                                x: centerX - rect.width * 0.04 + CGFloat(index) * rect.width * 0.025,
                                y: headHeight * 0.68
                            )
                    }
                } else {
                    // Missing jaw - exposed bone
                    Path { path in
                        path.move(to: CGPoint(x: centerX - rect.width * 0.06, y: headHeight * 0.65))
                        path.addLine(to: CGPoint(x: centerX + rect.width * 0.06, y: headHeight * 0.65))
                        path.addLine(to: CGPoint(x: centerX + rect.width * 0.05, y: headHeight * 0.8))
                        path.addLine(to: CGPoint(x: centerX - rect.width * 0.05, y: headHeight * 0.8))
                        path.closeSubpath()
                    }
                    .fill(variant.boneColor.opacity(0.9))
                }
                
                // Decay patches on face
                if variant.decayLevel != .fresh {
                    ForEach(0..<(variant.decayLevel == .severe ? 3 : 2), id: \.self) { index in
                        DecayPatchShape()
                            .fill(variant.decayColor.opacity(0.4))
                            .frame(
                                width: rect.width * (0.04 + CGFloat(index) * 0.02),
                                height: rect.width * (0.04 + CGFloat(index) * 0.02)
                            )
                            .position(
                                x: centerX + (index % 2 == 0 ? -1 : 1) * rect.width * 0.06,
                                y: headHeight * (0.5 + CGFloat(index) * 0.15)
                            )
                    }
                }
                
                // Exposed bone (cheekbone, forehead)
                if variant.decayLevel == .severe || variant.decayLevel == .advanced {
                    // Cheekbone
                    Ellipse()
                        .fill(variant.boneColor.opacity(0.7))
                        .frame(width: rect.width * 0.05, height: rect.width * 0.03)
                        .position(
                            x: centerX - rect.width * 0.1,
                            y: headHeight * 0.6
                        )
                }
            }
        }
    }
}

// MARK: - Zombie Torso Shape

struct ZombieTorsoShape: Shape {
    let variant: ZombieVariant
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let torsoTop = rect.height * 0.25
        let torsoBottom = rect.height * 0.6
        let torsoWidth = rect.width * 0.24
        
        // Torso (slightly hunched if variant is hunched)
        let hunchOffset: CGFloat = variant.pose == .hunched ? rect.width * 0.02 : 0
        
        path.move(to: CGPoint(x: centerX - torsoWidth * 0.5, y: torsoTop))
        path.addLine(to: CGPoint(x: centerX - torsoWidth * 0.5 + hunchOffset, y: torsoBottom))
        path.addLine(to: CGPoint(x: centerX + torsoWidth * 0.5 + hunchOffset, y: torsoBottom))
        path.addLine(to: CGPoint(x: centerX + torsoWidth * 0.5, y: torsoTop))
        path.closeSubpath()
        
        // Exposed ribs (if advanced decay)
        if variant.decayLevel == .severe || variant.decayLevel == .advanced {
            // Left side ribs
            for i in 0..<3 {
                path.move(to: CGPoint(
                    x: centerX - torsoWidth * 0.5 + hunchOffset,
                    y: torsoTop + CGFloat(i + 1) * (torsoBottom - torsoTop) / 4
                ))
                path.addLine(to: CGPoint(
                    x: centerX - torsoWidth * 0.3 + hunchOffset,
                    y: torsoTop + CGFloat(i + 1) * (torsoBottom - torsoTop) / 4
                ))
            }
        }
        
        return path
    }
}

// MARK: - Zombie Clothing Overlay

struct ZombieClothingOverlay: View {
    let variant: ZombieVariant
    
    var body: some View {
        GeometryReader { geometry in
            if variant.hasClothing {
                ZStack {
                    let rect = geometry.frame(in: .local)
                    let centerX = rect.midX
                    let torsoTop = rect.height * 0.25
                    let torsoBottom = rect.height * 0.6
                    let torsoWidth = rect.width * 0.24
                    
                    // Tattered shirt
                    Path { path in
                        path.move(to: CGPoint(x: centerX - torsoWidth * 0.5, y: torsoTop))
                        path.addLine(to: CGPoint(x: centerX - torsoWidth * 0.5, y: torsoBottom))
                        path.addLine(to: CGPoint(x: centerX + torsoWidth * 0.5, y: torsoBottom))
                        path.addLine(to: CGPoint(x: centerX + torsoWidth * 0.5, y: torsoTop))
                        path.closeSubpath()
                    }
                    .fill(variant.clothingColor.opacity(0.6))
                    
                    // Rips and tears
                    ForEach(0..<3, id: \.self) { index in
                        Path { path in
                            let x = centerX - torsoWidth * 0.3 + CGFloat(index) * torsoWidth * 0.3
                            path.move(to: CGPoint(x: x, y: torsoTop + 10))
                            path.addLine(to: CGPoint(x: x + 2, y: torsoTop + 15))
                            path.addLine(to: CGPoint(x: x - 2, y: torsoTop + 20))
                            path.addLine(to: CGPoint(x: x, y: torsoTop + 25))
                        }
                        .stroke(variant.clothingColor.opacity(0.8), lineWidth: 1)
                    }
                }
            }
        }
    }
}

// MARK: - Zombie Arms Shape

struct ZombieArmsShape: View {
    let variant: ZombieVariant
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let rect = geometry.frame(in: .local)
                let centerX = rect.midX
                let shoulderY = rect.height * 0.35
                
                // Left arm
                if !variant.missingParts.contains(.leftArm) {
                    ZombieArmShape(
                        isLeft: true,
                        pose: variant.pose,
                        variant: variant
                    )
                    .position(
                        x: centerX - rect.width * 0.12,
                        y: shoulderY
                    )
                }
                
                // Right arm
                if !variant.missingParts.contains(.rightArm) {
                    ZombieArmShape(
                        isLeft: false,
                        pose: variant.pose,
                        variant: variant
                    )
                    .position(
                        x: centerX + rect.width * 0.12,
                        y: shoulderY
                    )
                }
            }
        }
    }
}

struct ZombieArmShape: Shape {
    let isLeft: Bool
    let pose: ZombiePose
    let variant: ZombieVariant
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let shoulderY = rect.height * 0.35
        
        // Determine arm position based on pose
        let (endX, endY): (CGFloat, CGFloat)
        let armWidth: CGFloat = rect.width * 0.08
        
        switch pose {
        case .reaching:
            if isLeft {
                // Left arm reaching forward
                endX = centerX - rect.width * 0.25
                endY = rect.height * 0.2
            } else {
                // Right arm hanging
                endX = centerX + rect.width * 0.2
                endY = rect.height * 0.55
            }
        case .staggering:
            // Both arms out for balance
            if isLeft {
                endX = centerX - rect.width * 0.22
                endY = rect.height * 0.25
            } else {
                endX = centerX + rect.width * 0.22
                endY = rect.height * 0.25
            }
        default:
            // Standard hanging
            if isLeft {
                endX = centerX - rect.width * 0.2
                endY = rect.height * 0.5
            } else {
                endX = centerX + rect.width * 0.2
                endY = rect.height * 0.55
            }
        }
        
        // Upper arm
        path.move(to: CGPoint(x: centerX - (isLeft ? rect.width * 0.12 : -rect.width * 0.12), y: shoulderY))
        path.addLine(to: CGPoint(x: endX - armWidth * 0.5, y: endY))
        path.addLine(to: CGPoint(x: endX + armWidth * 0.5, y: endY))
        path.addLine(to: CGPoint(x: centerX - (isLeft ? rect.width * 0.1 : -rect.width * 0.1), y: shoulderY + 5))
        path.closeSubpath()
        
        // Forearm (if hand not missing)
        let handMissing = (isLeft && variant.missingParts.contains(.leftHand)) ||
                         (!isLeft && variant.missingParts.contains(.rightHand))
        
        if !handMissing {
            path.move(to: CGPoint(x: endX - armWidth * 0.3, y: endY))
            path.addLine(to: CGPoint(x: endX - armWidth * 0.4, y: endY + rect.height * 0.1))
            path.addLine(to: CGPoint(x: endX + armWidth * 0.4, y: endY + rect.height * 0.1))
            path.addLine(to: CGPoint(x: endX + armWidth * 0.3, y: endY))
            path.closeSubpath()
        } else {
            // Exposed bone at wrist
            path.addEllipse(in: CGRect(
                x: endX - armWidth * 0.3,
                y: endY - armWidth * 0.2,
                width: armWidth * 0.6,
                height: armWidth * 0.4
            ))
        }
        
        // Exposed bone at elbow (if advanced decay)
        if variant.decayLevel == .severe || variant.decayLevel == .advanced {
            let elbowX = (centerX + endX) / 2
            let elbowY = (shoulderY + endY) / 2
            path.addEllipse(in: CGRect(
                x: elbowX - armWidth * 0.3,
                y: elbowY - armWidth * 0.2,
                width: armWidth * 0.6,
                height: armWidth * 0.4
            ))
        }
        
        return path
    }
}

// MARK: - Zombie Legs Shape

struct ZombieLegsShape: View {
    let variant: ZombieVariant
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                let rect = geometry.frame(in: .local)
                let centerX = rect.midX
                let hipY = rect.height * 0.6
                
                // Left leg
                if !variant.missingParts.contains(.leftLeg) {
                    ZombieLegShape(
                        isLeft: true,
                        pose: variant.pose,
                        variant: variant
                    )
                    .position(
                        x: centerX - rect.width * 0.08,
                        y: hipY
                    )
                }
                
                // Right leg
                if !variant.missingParts.contains(.rightLeg) {
                    ZombieLegShape(
                        isLeft: false,
                        pose: variant.pose,
                        variant: variant
                    )
                    .position(
                        x: centerX + rect.width * 0.08,
                        y: hipY
                    )
                }
            }
        }
    }
}

struct ZombieLegShape: Shape {
    let isLeft: Bool
    let pose: ZombiePose
    let variant: ZombieVariant
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centerX = rect.midX
        let hipY = rect.height * 0.6
        let bottomY = rect.maxY
        let legWidth = rect.width * 0.06
        
        // Determine leg position based on pose
        let (footX, footY): (CGFloat, CGFloat)
        
        switch pose {
        case .limping, .staggering:
            if isLeft {
                // Left leg shorter/bent
                footX = centerX - rect.width * 0.1
                footY = bottomY - rect.height * 0.1 // Shorter
            } else {
                // Right leg normal
                footX = centerX + rect.width * 0.12
                footY = bottomY
            }
        default:
            // Standard stance
            if isLeft {
                footX = centerX - rect.width * 0.1
                footY = bottomY
            } else {
                footX = centerX + rect.width * 0.12
                footY = bottomY
            }
        }
        
        // Thigh
        path.move(to: CGPoint(x: centerX - (isLeft ? rect.width * 0.08 : -rect.width * 0.08), y: hipY))
        path.addLine(to: CGPoint(x: footX - legWidth * 0.5, y: footY))
        path.addLine(to: CGPoint(x: footX + legWidth * 0.5, y: footY))
        path.addLine(to: CGPoint(x: centerX - (isLeft ? rect.width * 0.06 : -rect.width * 0.06), y: hipY + 5))
        path.closeSubpath()
        
        // Lower leg (if foot not missing)
        let footMissing = (isLeft && variant.missingParts.contains(.leftFoot)) ||
                         (!isLeft && variant.missingParts.contains(.rightFoot))
        
        if !footMissing {
            // Lower leg
            let kneeY = (hipY + footY) / 2
            path.move(to: CGPoint(x: footX - legWidth * 0.4, y: kneeY))
            path.addLine(to: CGPoint(x: footX - legWidth * 0.3, y: footY))
            path.addLine(to: CGPoint(x: footX + legWidth * 0.3, y: footY))
            path.addLine(to: CGPoint(x: footX + legWidth * 0.4, y: kneeY))
            path.closeSubpath()
        } else {
            // Exposed bone at ankle
            path.addEllipse(in: CGRect(
                x: footX - legWidth * 0.4,
                y: footY - rect.height * 0.05 - legWidth * 0.25,
                width: legWidth * 0.8,
                height: legWidth * 0.5
            ))
        }
        
        // Exposed bone at knee (if advanced decay)
        if variant.decayLevel == .severe || variant.decayLevel == .advanced {
            let kneeX = footX
            let kneeY = (hipY + footY) / 2
            path.addEllipse(in: CGRect(
                x: kneeX - legWidth * 0.4,
                y: kneeY - legWidth * 0.3,
                width: legWidth * 0.8,
                height: legWidth * 0.6
            ))
        }
        
        return path
    }
}

// MARK: - Main Detailed Zombie Component

struct DetailedZombie: View {
    let variant: ZombieVariant
    let position: CGPoint
    @State private var swayOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Head
            ZStack {
                ZombieHeadShape(variant: variant, hasHair: variant.decayLevel == .fresh)
                    .fill(variant.skinColor)
                
                // Facial features overlay
                ZombieFacialFeatures(variant: variant)
            }
            .frame(width: variant.size * 0.3, height: variant.size * 0.25)
            .position(x: position.x, y: position.y - variant.size * 0.6)
            
            // Torso
            ZStack {
                ZombieTorsoShape(variant: variant)
                    .fill(variant.skinColor)
                
                // Clothing overlay
                ZombieClothingOverlay(variant: variant)
                
                // Decay patches on torso
                if variant.decayLevel != .fresh {
                    ForEach(0..<(variant.decayLevel == .severe ? 4 : 2), id: \.self) { index in
                        DecayPatchShape()
                            .fill(variant.decayColor.opacity(0.4))
                            .frame(
                                width: variant.size * (0.05 + CGFloat(index) * 0.02),
                                height: variant.size * (0.05 + CGFloat(index) * 0.02)
                            )
                            .position(
                                x: position.x + (index % 2 == 0 ? -1 : 1) * variant.size * 0.04,
                                y: position.y - variant.size * 0.1 + CGFloat(index) * variant.size * 0.08
                            )
                    }
                }
            }
            .frame(width: variant.size * 0.24, height: variant.size * 0.35)
            .position(x: position.x, y: position.y - variant.size * 0.2)
            
            // Arms
            ZStack {
                if !variant.missingParts.contains(.leftArm) {
                    ZombieArmShape(
                        isLeft: true,
                        pose: variant.pose,
                        variant: variant
                    )
                    .fill(variant.skinColor)
                    .frame(width: variant.size, height: variant.size)
                }
                
                if !variant.missingParts.contains(.rightArm) {
                    ZombieArmShape(
                        isLeft: false,
                        pose: variant.pose,
                        variant: variant
                    )
                    .fill(variant.skinColor)
                    .frame(width: variant.size, height: variant.size)
                }
            }
            .position(x: position.x, y: position.y - variant.size * 0.2)
            
            // Legs
            ZStack {
                if !variant.missingParts.contains(.leftLeg) {
                    ZombieLegShape(
                        isLeft: true,
                        pose: variant.pose,
                        variant: variant
                    )
                    .fill(variant.skinColor)
                    .frame(width: variant.size, height: variant.size)
                }
                
                if !variant.missingParts.contains(.rightLeg) {
                    ZombieLegShape(
                        isLeft: false,
                        pose: variant.pose,
                        variant: variant
                    )
                    .fill(variant.skinColor)
                    .frame(width: variant.size, height: variant.size)
                }
            }
            .position(x: position.x, y: position.y + variant.size * 0.3)
        }
        .frame(width: variant.size, height: variant.size * 1.8)
        .offset(x: swayOffset)
        .onAppear {
            // Subtle sway animation
            withAnimation(
                Animation.easeInOut(duration: Double.random(in: 2.5...4.0))
                    .repeatForever(autoreverses: true)
            ) {
                swayOffset = variant.type == .stagger ? 3 : 1.5
            }
        }
    }
}

