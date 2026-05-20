//
//  ComingSoonCautionTapeOverlay.swift
//  Touch-Grass
//

import SwiftUI

/// Diagonal construction-tape overlay for game modes not yet on the App Store.
struct ComingSoonCautionTapeOverlay: View {
    var cornerRadius: CGFloat = 18

    private let tapeYellow = Color(red: 1.0, green: 0.82, blue: 0.0)
    private let tapeBlack = Color.black

    var body: some View {
        ZStack {
            DiagonalHazardStripes(yellow: tapeYellow, black: tapeBlack)
                .opacity(0.88)

            Color.black.opacity(0.12)

            Text("COMING SOON")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .tracking(0.6)
                .foregroundColor(tapeBlack)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(tapeYellow)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(tapeBlack, lineWidth: 2.5)
                )
                .shadow(color: tapeBlack.opacity(0.25), radius: 0, x: 2, y: 2)
                .rotationEffect(.degrees(-14))
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct DiagonalHazardStripes: View {
    let yellow: Color
    let black: Color

    var body: some View {
        GeometryReader { geometry in
            let stripeWidth: CGFloat = 14
            let diagonal = hypot(geometry.size.width, geometry.size.height)
            let stripeCount = Int(diagonal / stripeWidth) + 6

            HStack(spacing: 0) {
                ForEach(0..<stripeCount, id: \.self) { index in
                    Rectangle()
                        .fill(index.isMultiple(of: 2) ? yellow : black)
                        .frame(width: stripeWidth)
                }
            }
            .frame(width: diagonal * 1.6, height: diagonal * 1.6)
            .rotationEffect(.degrees(-32))
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
