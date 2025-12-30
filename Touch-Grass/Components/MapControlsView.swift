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
    
    @State private var isExpanded: Bool = false
    
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(AppColors.manhuntPrimary)
                            .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 2)
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
                            color: AppColors.manhuntPrimary
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
                }
                .padding(.top, AppSpacing.xs) // Small gap from main button
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                    removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8))
                ))
            }
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
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(mapType == type ? .white : AppColors.textSecondary)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(mapType == type ? AppColors.manhuntPrimary : AppColors.cardBackground)
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                )
                .overlay(
                    Circle()
                        .stroke(mapType == type ? AppColors.manhuntPrimary : Color.clear, lineWidth: 1.5)
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
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(color.opacity(0.15))
                        .shadow(color: Color.black.opacity(0.2), radius: 3, x: 0, y: 2)
                )
                .overlay(
                    Circle()
                        .stroke(color.opacity(0.3), lineWidth: 1)
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
        default: return "Map control"
        }
    }
    
}