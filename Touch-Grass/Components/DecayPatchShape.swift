//
//  DecayPatchShape.swift
//  Touch-Grass
//
//  Shared shape for zombie decay patches
//

import SwiftUI

struct DecayPatchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Irregular patch shape
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.minY),
            control2: CGPoint(x: rect.maxX - rect.width * 0.3, y: rect.maxY)
        )
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.midY),
            control1: CGPoint(x: rect.maxX - rect.width * 0.2, y: rect.midY + rect.height * 0.3),
            control2: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.midY - rect.height * 0.3)
        )
        
        return path
    }
}
