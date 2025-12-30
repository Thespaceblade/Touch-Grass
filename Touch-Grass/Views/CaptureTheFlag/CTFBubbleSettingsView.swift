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
                // Dynamic-themed background
                LinearGradient(
                    colors: [
                        primaryColor.opacity(0.1),
                        AppColors.backgroundPrimary
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: AppSpacing.xl) {
                        Spacer()
                            .frame(height: AppSpacing.lg)
                        
                        // Title
                        VStack(spacing: AppSpacing.sm) {
                            Text("Configure Game")
                                .font(AppTypography.displayMedium())
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            primaryColor,
                                            secondaryColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Text("Set up the play zone and team bases")
                                .font(AppTypography.bodyMedium())
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        
                        // Interactive Map Card
                        if let location = userLocation {
                            interactiveMapCard(userLocation: location)
                                .padding(.horizontal, AppSpacing.md)
                        }
                        
                        // Settings Card
                        VStack(alignment: .leading, spacing: AppSpacing.lg) {
                            // Start Radius
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Text("Start Radius")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    Text("\(Int(startRadius))m")
                                        .font(AppTypography.labelMedium())
                                        .foregroundColor(primaryColor)
                                }
                                
                                // Preset buttons
                                HStack(spacing: AppSpacing.xs) {
                                    presetButton(title: "Small", radius: 200, currentRadius: $startRadius)
                                    presetButton(title: "Medium", radius: 500, currentRadius: $startRadius)
                                    presetButton(title: "Large", radius: 1000, currentRadius: $startRadius)
                                }
                                
                                Slider(value: $startRadius, in: 50...1000, step: 10)
                                    .tint(AppColors.bubbleSafe)
                            }
                            
                            Divider()
                            
                            // Team Base Positioning Info
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Team Bases")
                                    .font(AppTypography.labelMedium())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                Text("Team bases will be automatically positioned on opposite sides of the zone")
                                    .font(AppTypography.bodySmall())
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Text("Team A (Blue) and Team B (Red) will be assigned when the game starts")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.ultraThinMaterial)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
                        )
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
                                    .font(.title3)
                                Text("Configure")
                                    .font(AppTypography.labelLarge())
                                    .fontWeight(.semibold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.horizontal, AppSpacing.md)
                        .accessibilityLabel("Configure game")
                        .accessibilityHint("Saves the game configuration and starts the game")
                        
                        Spacer()
                            .frame(height: AppSpacing.lg)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(primaryColor)
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
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Zone Configuration")
                .font(AppTypography.labelLarge())
                .fontWeight(.semibold)
                .foregroundColor(AppColors.textPrimary)
            
                Spacer()
                
                Button(action: {
                    // Reset to user location
                    bubbleCenter = userLocation
                    // Map region will be updated automatically by DraggableBubbleMapView
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                        Text("Reset")
                            .font(AppTypography.caption())
                    }
                    .foregroundColor(primaryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(primaryColor.opacity(0.1))
                    )
                }
            }
            
            Text("Pan the map to set zone center, or drag the red marker")
                .font(AppTypography.caption())
                .foregroundColor(AppColors.textSecondary)
            
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
            .cornerRadius(12)
            
            // Legend
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                        .fill(AppColors.bubbleSafe)
                        .frame(width: 8, height: 8)
                        Text("Zone: \(Int(startRadius))m")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                }
                
                HStack(spacing: AppSpacing.xs) {
                    Circle()
                            .fill(primaryColor)
                        .frame(width: 8, height: 8)
                        Text("Center")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                Text("Pan the map to set zone center, or drag the red marker")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 4)
        )
    }
    
    private func regionForBubble(center: CLLocationCoordinate2D, radius: Double) -> MKCoordinateRegion {
        // Convert radius in meters to degrees (approximate)
        let radiusInDegrees = radius / 111000.0 // Rough conversion: 1 degree ≈ 111km
        let span = MKCoordinateSpan(latitudeDelta: radiusInDegrees * 2.5, longitudeDelta: radiusInDegrees * 2.5)
        return MKCoordinateRegion(center: center, span: span)
    }
    
    // MARK: - Preset Helpers
    
    private func presetButton(title: String, radius: Double, currentRadius: Binding<Double>) -> some View {
        Button(action: {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentRadius.wrappedValue = radius
            }
        }) {
            Text(title)
                .font(AppTypography.caption())
                .fontWeight(.medium)
                .foregroundColor(abs(currentRadius.wrappedValue - radius) < 10 ? .white : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(abs(currentRadius.wrappedValue - radius) < 10 ? primaryColor : AppColors.backgroundSecondary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func presetButton(title: String, value: Double, currentValue: Binding<Double>) -> some View {
        Button(action: {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentValue.wrappedValue = value
            }
        }) {
            Text(title)
                .font(AppTypography.caption())
                .fontWeight(.medium)
                .foregroundColor(abs(currentValue.wrappedValue - value) < 0.5 ? .white : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(abs(currentValue.wrappedValue - value) < 0.5 ? primaryColor : AppColors.backgroundSecondary)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
}
