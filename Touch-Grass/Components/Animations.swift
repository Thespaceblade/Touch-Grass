//
//  Animations.swift
//  Touch-Grass
//
//  Reusable animation components and utilities
//

import SwiftUI

// MARK: - Number Counting Animation

struct CountingNumberView: View {
    let value: Int
    let duration: Double
    @State private var displayedValue: Int = 0
    
    init(value: Int, duration: Double = 1.0) {
        self.value = value
        self.duration = duration
    }
    
    var body: some View {
        Text("\(displayedValue)")
            .onAppear {
                animateToValue()
            }
            .onChange(of: value) { _, newValue in
                animateToValue(target: newValue)
            }
    }
    
    private func animateToValue(target: Int? = nil) {
        let targetValue = target ?? value
        let steps = abs(targetValue - displayedValue)
        guard steps > 0 else { return }
        
        let stepDuration = duration / Double(steps)
        let increment = targetValue > displayedValue ? 1 : -1
        
        for step in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                withAnimation(.linear(duration: stepDuration)) {
                    displayedValue += increment
                    if (increment > 0 && displayedValue >= targetValue) || 
                       (increment < 0 && displayedValue <= targetValue) {
                        displayedValue = targetValue
                    }
                }
            }
        }
    }
}

// MARK: - Shimmer Effect

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    let duration: Double
    
    init(duration: Double = 2.0) {
        self.duration = duration
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 2)
                    .offset(x: -geometry.size.width + (geometry.size.width * 2 * phase))
                    .blur(radius: 10)
                }
            )
            .onAppear {
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1.0
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 2.0) -> some View {
        modifier(ShimmerEffect(duration: duration))
    }
}

// MARK: - Pulse Animation

struct PulseEffect: ViewModifier {
    @State private var isPulsing: Bool = false
    let duration: Double
    let minScale: CGFloat
    let maxScale: CGFloat
    
    init(duration: Double = 1.0, minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05) {
        self.duration = duration
        self.minScale = minScale
        self.maxScale = maxScale
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? maxScale : minScale)
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}

extension View {
    func pulse(duration: Double = 1.0, minScale: CGFloat = 0.95, maxScale: CGFloat = 1.05) -> some View {
        modifier(PulseEffect(duration: duration, minScale: minScale, maxScale: maxScale))
    }
}

// MARK: - Bounce Animation

struct BounceEffect: ViewModifier {
    @State private var isBouncing: Bool = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isBouncing ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isBouncing)
    }
    
    func trigger() {
        isBouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isBouncing = false
        }
    }
}

extension View {
    func bounce() -> some View {
        modifier(BounceEffect())
    }
}













