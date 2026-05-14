//
//  AnimatedTabBar.swift
//  Touch-Grass
//
//  Custom animated tab bar with morphing shapes and color transitions
//

import SwiftUI

struct AnimatedTabBar: View {
    @Binding var selectedTab: TabSelection
    @State private var indicatorOffset: CGFloat = 0
    @State private var indicatorWidth: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var glowIntensity: CGFloat = 0.5
    @State private var morphProgress: CGFloat = 0
    
    enum TabSelection {
        case game
        case profile
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 18)
                    .fill(AppColors.cartoonCream)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AppColors.cartoonInk, lineWidth: 2)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(white: 0.18))
                            .offset(x: 4, y: 4)
                    )
                
                HStack(spacing: 0) {
                    // Game Tab
                    tabButton(
                        tab: .game,
                        icon: "gamecontroller.fill",
                        label: "Game",
                        geometry: geometry
                    )
                    
                    // Profile Tab
                    tabButton(
                        tab: .profile,
                        icon: "person.circle.fill",
                        label: "Profile",
                        geometry: geometry
                    )
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 4)
                
                // Animated indicator background
                animatedIndicator(geometry: geometry)
            }
        }
        .frame(height: 48)
        .onAppear {
            updateIndicator(for: selectedTab, geometry: nil)
            
            // Continuous animations
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowIntensity = 1.0
            }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
            
            // Continuous morphing animation
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                morphProgress = 1.0
            }
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            updateIndicator(for: newValue, geometry: nil)
        }
    }
    
    // MARK: - Tab Button
    
    private func tabButton(
        tab: TabSelection,
        icon: String,
        label: String,
        geometry: GeometryProxy
    ) -> some View {
        Button(action: {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                ZStack {
                    // Glow effect when selected
                    if selectedTab == tab {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        AppColors.grassPrimary.opacity(0.4 * glowIntensity),
                                        AppColors.grassPrimary.opacity(0.1 * glowIntensity),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 4,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 42, height: 42)
                            .blur(radius: 5)
                            .scaleEffect(pulseScale)
                    }
                    
                    // Icon background
                    Circle()
                        .fill(
                            selectedTab == tab ?
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary.opacity(0.2),
                                    AppColors.grassSecondary.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(
                                    selectedTab == tab ?
                                    LinearGradient(
                                        colors: [
                                            AppColors.grassPrimary.opacity(0.6),
                                            AppColors.grassSecondary.opacity(0.4)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ) :
                                    LinearGradient(
                                        colors: [
                                            AppColors.textSecondary.opacity(0.2),
                                            AppColors.textSecondary.opacity(0.1)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: selectedTab == tab ? 2 : 1
                                )
                        )
                    
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: selectedTab == tab ? .bold : .semibold))
                        .foregroundStyle(
                            selectedTab == tab ?
                            LinearGradient(
                                colors: [
                                    AppColors.grassPrimary,
                                    AppColors.grassSecondary,
                                    AppColors.grassLight
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [
                                    AppColors.textSecondary,
                                    AppColors.textSecondary.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                }
                
                // Label
                Text(label)
                    .font(.system(size: 9, weight: selectedTab == tab ? .black : .bold, design: .rounded))
                    .foregroundColor(
                        selectedTab == tab ?
                        AppColors.cartoonInk :
                        AppColors.cartoonInk.opacity(0.58)
                    )
                    .opacity(selectedTab == tab ? 1.0 : 0.6)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Animated Indicator
    
    private func animatedIndicator(geometry: GeometryProxy) -> some View {
        let tabWidth = geometry.size.width / 2
        let indicatorX = selectedTab == .game ? tabWidth / 2 : tabWidth * 1.5
        
        return ZStack {
            // Hard offset sticker shadow
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(white: 0.18))
                .frame(width: 70, height: 32)
                .offset(x: indicatorX - geometry.size.width / 2 + 3, y: 3)
            
            // Main pill indicator - clean rounded capsule
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.grassPrimary,
                            AppColors.grassSecondary,
                            AppColors.grassLight
                        ],
                        startPoint: UnitPoint(
                            x: 0.3 + sin(morphProgress * .pi * 2) * 0.1,
                            y: 0.3
                        ),
                        endPoint: UnitPoint(
                            x: 0.7 + cos(morphProgress * .pi * 2) * 0.1,
                            y: 0.7
                        )
                    )
                )
                .frame(width: 70, height: 32)
                .offset(x: indicatorX - geometry.size.width / 2)
                .overlay(
                    // Top highlight for depth and shine
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.grassLight.opacity(0.5),
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: 70, height: 16)
                        .offset(x: indicatorX - geometry.size.width / 2, y: -8)
                        .blendMode(.overlay)
                        .mask(
                            RoundedRectangle(cornerRadius: 16)
                                .frame(width: 70, height: 32)
                                .offset(y: 0)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(AppColors.cartoonInk, lineWidth: 2)
                        .frame(width: 70, height: 32)
                        .offset(x: indicatorX - geometry.size.width / 2)
                )
                .scaleEffect(pulseScale)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: selectedTab)
    }
    
    private func updateIndicator(for tab: TabSelection, geometry: GeometryProxy?) {
        // Continuous gradient animation is handled by onAppear
    }
}
