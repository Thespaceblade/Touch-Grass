//
//  ManhuntBubbleSettingsView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import SwiftUI
import MapKit
import CoreLocation

struct ManhuntBubbleSettingsView: View {
    @Binding var startRadius: Double
    @Binding var duration: Double
    @Binding var hunterCount: Int
    @Binding var showTimer: Bool
    @Binding var enableShrinking: Bool
    let onStart: (CLLocationCoordinate2D) -> Void // Now passes selected center
    let userLocation: CLLocationCoordinate2D?
    let maxPlayers: Int // Maximum number of players in session
    @Environment(\.dismiss) var dismiss
    
    // Selected bubble center (defaults to user location)
    // Initialize immediately to userLocation if available
    @State private var bubbleCenter: CLLocationCoordinate2D?
    
    // Initialize bubbleCenter immediately when view is created (not in onAppear)
    init(startRadius: Binding<Double>, duration: Binding<Double>, hunterCount: Binding<Int>, showTimer: Binding<Bool>, enableShrinking: Binding<Bool>, onStart: @escaping (CLLocationCoordinate2D) -> Void, userLocation: CLLocationCoordinate2D?, maxPlayers: Int) {
        self._startRadius = startRadius
        self._duration = duration
        self._hunterCount = hunterCount
        self._showTimer = showTimer
        self._enableShrinking = enableShrinking
        self.onStart = onStart
        self.userLocation = userLocation
        self.maxPlayers = maxPlayers
        // Initialize bubbleCenter immediately if userLocation is available
        self._bubbleCenter = State(initialValue: userLocation)
    }
    
    // Computed property to ensure we always have a valid center
    private var effectiveBubbleCenter: CLLocationCoordinate2D {
        bubbleCenter ?? userLocation ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    // Hardcoded Manhunt theme colors
    private var primaryColor: Color {
        AppColors.hunterPrimary
    }
    
    private var secondaryColor: Color {
        AppColors.hunterSecondary
    }
    
    // Hunter count binding for slider
    private var hunterCountBinding: Binding<Double> {
        Binding(
            get: { 
                // Return current value as Double (clamping happens in setter and onAppear)
                return Double(hunterCount)
            },
            set: { 
                // Clamp the value to valid range
                let currentMax = max(1, maxPlayers - 1)
                let newValue = Int($0)
                hunterCount = min(max(1, newValue), max(2, currentMax)) // Ensure at least 2 for valid slider
            }
        )
    }
    
    // Max hunter count (maxPlayers - 1, minimum 1)
    // Note: If maxPlayers is 1, maxHunterCount will be 1, which creates invalid slider range
    private var maxHunterCount: Int {
        max(1, maxPlayers - 1)
    }
    
    // Check if slider range is valid (needs at least 2 different values)
    private var canShowHunterSlider: Bool {
        maxHunterCount > 1
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeBackgroundView(
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    lightColor: AppColors.manhuntLight
                )
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                            .frame(height: AppSpacing.md)
                        
                        CartoonConfigurationHero(
                            iconName: "figure.run",
                            title: "Configure Game",
                            subtitle: "Set the play zone, timer, and starting Hunters.",
                            badge: "Manhunt Setup",
                            accent: primaryColor
                        )
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Interactive Map Card
                        if let location = userLocation {
                            interactiveMapCard(userLocation: location)
                                .padding(.horizontal, AppSpacing.md)
                        }
                        
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                CartoonSettingHeader(
                                    iconName: "scope",
                                    title: "Start Radius",
                                    value: "\(Int(startRadius))m",
                                    accent: primaryColor
                                )
                                
                                HStack(spacing: AppSpacing.xs) {
                                    presetButton(title: "Small", radius: 200, currentRadius: $startRadius)
                                    presetButton(title: "Medium", radius: 500, currentRadius: $startRadius)
                                    presetButton(title: "Large", radius: 1000, currentRadius: $startRadius)
                                }
                                
                                Slider(value: $startRadius, in: 50...1000, step: 10)
                                    .tint(primaryColor)
                            }
                            
                            CartoonSettingDivider()
                            
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                CartoonSettingHeader(
                                    iconName: "timer",
                                    title: "Game Duration",
                                    value: timeString(from: duration),
                                    accent: primaryColor
                                )
                                
                                HStack(spacing: AppSpacing.xs) {
                                    presetButton(title: "15", duration: 900, currentDuration: $duration)
                                    presetButton(title: "30", duration: 1800, currentDuration: $duration)
                                    presetButton(title: "60", duration: 3600, currentDuration: $duration)
                                }
                                
                                Slider(value: $duration, in: 900...7200, step: 900)
                                    .tint(primaryColor)
                            }
                            
                            CartoonSettingDivider()
                            
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                CartoonSettingHeader(
                                    iconName: "person.2.fill",
                                    title: "Initial Hunters",
                                    value: "\(hunterCount)",
                                    accent: primaryColor
                                )
                                
                                if canShowHunterSlider {
                                    let sliderMax = max(2, maxHunterCount)
                                    Slider(value: hunterCountBinding, in: 1...Double(sliderMax), step: 1)
                                        .tint(primaryColor)
                                    
                                    CartoonInfoLine(
                                        iconName: "shuffle",
                                        text: "Initial hunters will be randomly selected.",
                                        accent: primaryColor,
                                        isSubtle: true
                                    )
                                } else {
                                    if maxPlayers <= 1 {
                                        CartoonInfoLine(
                                            iconName: "person.fill",
                                            text: "Only you are in the game right now.",
                                            accent: primaryColor,
                                            isSubtle: true
                                        )
                                    } else {
                                        CartoonInfoLine(
                                            iconName: "person.2.fill",
                                            text: "With \(maxPlayers) players, 1 initial hunter will be randomly selected.",
                                            accent: primaryColor,
                                            isSubtle: true
                                        )
                                    }
                                }
                            }
                            
                            CartoonSettingDivider()
                            
                            VStack(alignment: .leading, spacing: AppSpacing.md) {
                                HStack(spacing: AppSpacing.md) {
                                    CartoonSettingHeader(
                                        iconName: "arrow.down.right.and.arrow.up.left",
                                        title: "Shrinking Zone",
                                        value: enableShrinking ? "On" : "Off",
                                        accent: primaryColor
                                    )
                                    
                                    Toggle("", isOn: $enableShrinking)
                                        .tint(primaryColor)
                                        .labelsHidden()
                                }
                                
                                if enableShrinking {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                        if startRadius < ZoneService.minimumShrinkingStartRadius {
                                            CartoonInfoLine(iconName: "lock.circle.fill", text: "Small zone: shrinking is disabled under 100m.", accent: primaryColor)
                                        } else {
                                            CartoonInfoLine(iconName: "clock.arrow.circlepath", text: "First safe zone reveals after opening grace.", accent: primaryColor)
                                            CartoonInfoLine(iconName: "move.3d", text: "Zones close on a duration-scaled schedule.", accent: primaryColor, isSubtle: true)
                                            CartoonInfoLine(iconName: "circle.dashed", text: "Controlled pulls keep each new safe zone inside the current bubble.", accent: primaryColor, isSubtle: true)
                                        }
                                    }
                                } else {
                                    CartoonInfoLine(
                                        iconName: "lock.circle.fill",
                                        text: "Zone stays fixed at \(Int(startRadius))m for the whole game.",
                                        accent: primaryColor
                                    )
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .cartoonCard(cornerRadius: 18, shadowOffset: 5, borderWidth: 2.5)
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Configure Button
                        Button(action: {
                            HapticFeedbackManager.shared.selection()
                            // Use selected center or fall back to user location
                            let center = effectiveBubbleCenter
                            print("📍 ManhuntBubbleSettingsView: Configure button pressed with center: \(center.latitude), \(center.longitude)")
                            onStart(center)
                        }) {
                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                Text("Configure")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(CartoonButtonStyle(accent: primaryColor, textColor: .white))
                        .padding(.horizontal, AppSpacing.md)
                        .accessibilityLabel("Configure game")
                        .accessibilityHint("Saves the game configuration and starts the game")
                        
                        Spacer()
                            .frame(height: AppSpacing.lg)
                    }
                }
                .safeAreaPadding(.bottom, AppSpacing.lg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    CartoonSheetToolbarButton(
                        title: "Cancel",
                        systemImage: "xmark",
                        style: .secondary,
                        action: { dismiss() }
                    )
                }
            }
            .onAppear {
                // Ensure hunterCount is valid when view appears
                if !canShowHunterSlider {
                    hunterCount = 1 // Force to 1 if only 1 player
                } else {
                    hunterCount = min(max(1, hunterCount), maxHunterCount) // Clamp to valid range
                }
    
                // Initialize bubble center to user location if not already set
                // This ensures it's set before the map view tries to use it
                if bubbleCenter == nil, let location = userLocation {
                    bubbleCenter = location
                    print("📍 ManhuntBubbleSettingsView: Initialized bubble center to user location: \(location.latitude), \(location.longitude)")
                } else if bubbleCenter == nil {
                    print("⚠️ ManhuntBubbleSettingsView: No user location available, bubble center is nil")
                }
            }
            // Note: Radius changes are handled by DraggableBubbleMapView internally
            // No need to update mapRegion here as it can cause conflicts
        }
    }
    
    // MARK: - Interactive Map
    
    private func interactiveMapCard(userLocation: CLLocationCoordinate2D) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                CartoonMedallion(background: primaryColor, size: 34) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zone Configuration")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk)
                    
                    Text("Pan the map or drag the red marker.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.cartoonInk.opacity(0.62))
                }
                
                Spacer()
                
                Button(action: {
                    // Reset to user location
                    bubbleCenter = userLocation
                    // Map region will be updated automatically by DraggableBubbleMapView
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                        Text("Reset")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(0.4)
                            .textCase(.uppercase)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(primaryColor)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(AppColors.cartoonInk, lineWidth: 2))
                    .background(
                        Capsule()
                            .fill(AppColors.cartoonInk)
                            .offset(x: 2, y: 2)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }

            // Draggable map with MKMapView for smooth native dragging
            // userLocation is guaranteed non-nil in this function (it's a non-optional parameter)
            DraggableBubbleMapView(
                userLocation: userLocation,
                bubbleCenter: Binding(
                    get: { 
                        effectiveBubbleCenter
                    },
                    set: { newCenter in
                        print("📍 BubbleSettingsView: Setting bubble center to \(newCenter.latitude), \(newCenter.longitude)")
                        bubbleCenter = newCenter
                    }
                ),
                bubbleRadius: $startRadius,
                onCenterChanged: { newCenter in
                    bubbleCenter = newCenter
                }
            )
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.cartoonInk, lineWidth: 2.5)
            )
            
            // Legend
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack(spacing: AppSpacing.md) {
                    HStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(AppColors.bubbleSafe)
                            .frame(width: 9, height: 9)
                        Text("Zone: \(Int(startRadius))m")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                    }
                    
                    HStack(spacing: AppSpacing.xs) {
                        Circle()
                            .fill(primaryColor)
                            .frame(width: 9, height: 9)
                        Text("Center")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.cartoonInk.opacity(0.68))
                    }
                }
                
                Text("The bubble center is saved when you tap Configure.")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk.opacity(0.52))
            }
        }
        .padding(AppSpacing.md)
        .cartoonCard(cornerRadius: 18, shadowOffset: 5, borderWidth: 2.5)
    }
    
    private func regionForBubble(center: CLLocationCoordinate2D, radius: Double) -> MKCoordinateRegion {
        // Convert radius in meters to degrees (approximate)
        let radiusInDegrees = radius / 111000.0 // Rough conversion: 1 degree ≈ 111km
        let span = MKCoordinateSpan(latitudeDelta: radiusInDegrees * 2.5, longitudeDelta: radiusInDegrees * 2.5)
        return MKCoordinateRegion(center: center, span: span)
    }
    
    // MARK: - Preset Helpers
    
    private func presetButton(title: String, radius: Double, currentRadius: Binding<Double>) -> some View {
        CartoonPresetChip(
            title: title,
            isSelected: abs(currentRadius.wrappedValue - radius) < 10,
            accent: primaryColor
        ) {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentRadius.wrappedValue = radius
            }
        }
    }
    
    private func presetButton(title: String, duration: Double, currentDuration: Binding<Double>) -> some View {
        CartoonPresetChip(
            title: title,
            isSelected: abs(currentDuration.wrappedValue - duration) < 30,
            accent: primaryColor
        ) {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentDuration.wrappedValue = duration
            }
        }
    }
    
    private func presetButton(title: String, value: Double, currentValue: Binding<Double>) -> some View {
        CartoonPresetChip(
            title: title,
            isSelected: abs(currentValue.wrappedValue - value) < 0.5,
            accent: primaryColor
        ) {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentValue.wrappedValue = value
            }
        }
    }
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        } else if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }
    
}
