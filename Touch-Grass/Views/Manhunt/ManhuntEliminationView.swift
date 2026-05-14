//
//  ManhuntEliminationView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI

struct ManhuntEliminationView: View {
    let onSpectate: () -> Void
    let eliminationReason: String?
    
    @State private var showContent: Bool = false
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Red background overlay
            Color.red
                .ignoresSafeArea()
                .opacity(0.95)
            
            VStack(spacing: AppSpacing.xl) {
                Spacer()
                
                // Elimination Icon
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 120, weight: .bold))
                    .foregroundColor(.white)
                    .shadow(color: AppColors.cartoonInk, radius: 0, x: 5, y: 5)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
                
                // Main Message
                VStack(spacing: AppSpacing.md) {
                    Text("YOU HAVE BEEN")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: AppColors.cartoonInk, radius: 0, x: 3, y: 3)
                    
                    Text("ELIMINATED")
                        .font(.system(size: 48, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: AppColors.cartoonInk, radius: 0, x: 4, y: 4)
                }
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)
                
                // Elimination Reason (if provided)
                if let reason = eliminationReason {
                    Text(reason)
                        .font(AppTypography.bodyLarge())
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                        .opacity(showContent ? 1.0 : 0.0)
                        .offset(y: showContent ? 0 : 20)
                        .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)
                }
                
                Spacer()
                
                // Spectate Button
                Button(action: {
                    HapticFeedbackManager.shared.selection()
                    onSpectate()
                }) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                        Text("Spectate")
                    }
                }
                .buttonStyle(CartoonButtonStyle(accent: AppColors.cartoonInk))
                .opacity(showContent ? 1.0 : 0.0)
                .offset(y: showContent ? 0 : 20)
                .animation(.easeOut(duration: 0.5).delay(0.4), value: showContent)
                
                Spacer()
                    .frame(height: AppSpacing.xl)
            }
        }
        .onAppear {
            // Start pulse animation
            withAnimation {
                pulseScale = 1.1
            }
            
            // Animate content entrance
            withAnimation(.easeOut(duration: 0.6)) {
                showContent = true
            }
            
            // Haptic feedback
            HapticFeedbackManager.shared.impact(style: .heavy)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                HapticFeedbackManager.shared.impact(style: .heavy)
            }
        }
    }
}
