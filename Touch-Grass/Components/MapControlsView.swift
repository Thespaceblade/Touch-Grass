//
//  MapControlsView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import SwiftUI
import MapKit

struct MapControlsView: View {
    @Binding var mapType: MKMapType
    @Binding var showPlayerLabels: Bool
    let onZoomToBubble: () -> Void
    let onCenterOnPlayer: () -> Void
    let bubbleExists: Bool
    let playerLocationExists: Bool
    let gameType: GameType?
    var onEndGame: (() -> Void)? = nil
    
    @State private var isExpanded: Bool = false
    @State private var showEndGameConfirm: Bool = false
    
    // Helper to get primary color based on game type
    private var primaryColor: Color {
        guard let gameType = gameType else {
            return AppColors.manhuntPrimary // Default fallback
        }
        switch gameType {
        case .manhunt:
            return AppColors.manhuntPrimary
        case .zombieTag:
            return AppColors.zombiePrimary
        case .captureTheFlag:
            return AppColors.ctfPrimary
        }
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            // Main Toggle Button (map icon - FIXED position, always visible)
            Button(action: {
                HapticFeedbackManager.shared.selection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            }) {
                Image(systemName: "map.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        Circle()
                            .fill(primaryColor)
                    )
                    .overlay(Circle().stroke(AppColors.cartoonInk, lineWidth: 2.5))
                    .background(
                        Circle()
                            .fill(Color(white: 0.18))
                            .offset(x: 3, y: 3)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(10) // Keep main button on top
            .accessibilityLabel("Map controls")
            .accessibilityHint(isExpanded ? "Tap to collapse map controls" : "Tap to expand map controls")
            
            // Expanded Icons Column (spring from underneath, downward)
            if isExpanded {
                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                    // Icon 1: Standard Map
                    mapTypeIconButton(.standard, icon: "map")
                    
                    // Icon 2: Satellite Map
                    mapTypeIconButton(.satellite, icon: "globe")
                    
                    // Icon 3: Hybrid Map
                    mapTypeIconButton(.hybrid, icon: "map.fill")
                    
                    // Icon 4: Zoom to Bubble (if exists)
                    if bubbleExists {
                        controlIconButton(
                            icon: "circle.grid.cross",
                            color: AppColors.bubbleSafe
                        ) {
                            onZoomToBubble()
                        }
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                    
                    // Icon 5: Center on Player (if exists)
                    if playerLocationExists {
                        controlIconButton(
                            icon: "location.fill",
                            color: primaryColor
                        ) {
                            onCenterOnPlayer()
                        }
                    } else {
                        Color.clear.frame(width: 40, height: 40)
                    }
                    
                    // Icon 6: Toggle Labels (always shown)
                    controlIconButton(
                        icon: showPlayerLabels ? "person.fill.checkmark" : "person.fill.xmark",
                        color: AppColors.textPrimary
                    ) {
                        showPlayerLabels.toggle()
                    }

                    if onEndGame != nil {
                        controlIconButton(
                            icon: "stop.circle.fill",
                            color: AppColors.error
                        ) {
                            showEndGameConfirm = true
                        }
                    }
                }
                .padding(.top, AppSpacing.xs) // Small gap from main button
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                    removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8))
                ))
            }
        }
        .alert("End game?", isPresented: $showEndGameConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("End Game", role: .destructive) {
                onEndGame?()
            }
        } message: {
            Text("This ends the current game for everyone.")
        }
    }
    
    private func mapTypeIconButton(_ type: MKMapType, icon: String) -> some View {
        Button {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                mapType = type
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(mapType == type ? .white : AppColors.cartoonInk.opacity(0.72))
                .frame(width: 40, height: 40)
            .background(
                Circle()
                    .fill(mapType == type ? primaryColor : AppColors.cartoonCream)
            )
            .overlay(
                Circle()
                    .stroke(AppColors.cartoonInk, lineWidth: 2)
            )
            .background(
                Circle()
                    .fill(Color(white: 0.18))
                    .offset(x: 2.5, y: 2.5)
            )
            }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(mapTypeLabel(for: type))
        .accessibilityHint("Changes map display type")
    }
    
    private func mapTypeLabel(for type: MKMapType) -> String {
        switch type {
        case .standard: return "Standard map"
        case .satellite: return "Satellite map"
        case .hybrid: return "Hybrid map"
        case .satelliteFlyover: return "Satellite flyover map"
        case .hybridFlyover: return "Hybrid flyover map"
        case .mutedStandard: return "Muted standard map"
        @unknown default: return "Map type"
        }
    }
    
    private func controlIconButton(
        icon: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticFeedbackManager.shared.selection()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(color == AppColors.textPrimary ? AppColors.cartoonInk : color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(AppColors.cartoonCream)
                )
                .overlay(
                    Circle()
                        .stroke(AppColors.cartoonInk, lineWidth: 2)
                )
                .background(
                    Circle()
                        .fill(Color(white: 0.18))
                        .offset(x: 2.5, y: 2.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(controlLabel(for: icon))
    }
    
    private func controlLabel(for icon: String) -> String {
        switch icon {
        case "circle.grid.cross": return "Zoom to zone"
        case "location.fill": return "Center on player"
        case "person.fill.checkmark": return "Hide player labels"
        case "person.fill.xmark": return "Show player labels"
        case "stop.circle.fill": return "End game"
        default: return "Map control"
        }
    }
    
}
