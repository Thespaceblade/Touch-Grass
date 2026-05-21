//
//  CTFBubbleSettingsView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import SwiftUI
import MapKit
import CoreLocation

struct CTFBubbleSettingsView: View {
    @Binding var startRadius: Double
    @Binding var teamABase: CLLocationCoordinate2D?
    @Binding var teamBBase: CLLocationCoordinate2D?
    let onStart: (CLLocationCoordinate2D) -> Void // Now passes selected center
    let userLocation: CLLocationCoordinate2D?
    let maxPlayers: Int // Maximum number of players in session
    @Environment(\.dismiss) var dismiss
    
    // Selected bubble center (defaults to user location)
    // Initialize to userLocation if available to avoid nil issues
    @State private var bubbleCenter: CLLocationCoordinate2D?
    
    // Initialize bubbleCenter immediately when view is created (not in onAppear)
    init(startRadius: Binding<Double>, teamABase: Binding<CLLocationCoordinate2D?>, teamBBase: Binding<CLLocationCoordinate2D?>, onStart: @escaping (CLLocationCoordinate2D) -> Void, userLocation: CLLocationCoordinate2D?, maxPlayers: Int) {
        self._startRadius = startRadius
        self._teamABase = teamABase
        self._teamBBase = teamBBase
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
    
    // Hardcoded CTF theme colors
    private var primaryColor: Color {
        AppColors.ctfPrimary
    }
    
    private var secondaryColor: Color {
        AppColors.ctfSecondary
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ThemeBackgroundView(
                    primaryColor: primaryColor,
                    secondaryColor: secondaryColor,
                    lightColor: AppColors.ctfLight
                )
                
                ScrollView {
                    VStack(spacing: AppSpacing.lg) {
                        Spacer()
                            .frame(height: AppSpacing.md)
                        
                        CartoonConfigurationHero(
                            iconName: "flag.2.crossed.fill",
                            title: "Configure Game",
                            subtitle: "Set the play zone and automatic team bases.",
                            badge: "CTF Setup",
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
                                    iconName: "flag.2.crossed.fill",
                                    title: "Team Bases",
                                    value: "Auto",
                                    accent: primaryColor
                                )
                                
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    CartoonInfoLine(
                                        iconName: "arrow.left.and.right.circle.fill",
                                        text: "Team bases are positioned on opposite sides of the zone.",
                                        accent: primaryColor
                                    )
                                    
                                    CartoonInfoLine(
                                        iconName: "person.2.fill",
                                        text: "Team A and Team B are assigned when the game starts.",
                                        accent: primaryColor,
                                        isSubtle: true
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
                            print("📍 CTFBubbleSettingsView: Configure button pressed with center: \(center.latitude), \(center.longitude)")
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
                // Initialize bubble center to user location if not already set
                // This ensures the center is set before the map view is created
                if bubbleCenter == nil, let location = userLocation {
                    bubbleCenter = location
                    print("📍 CTFBubbleSettingsView: Initialized bubble center to user location: \(location.latitude), \(location.longitude)")
                } else if bubbleCenter == nil {
                    print("⚠️ CTFBubbleSettingsView: No user location available, bubble center is nil")
                }
            }
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
    
}
