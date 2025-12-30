//
//  ZombieTagBubbleSettingsView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//


import SwiftUI
import MapKit
import CoreLocation

struct ZombieTagBubbleSettingsView: View {
    @Binding var startRadius: Double
    @Binding var duration: Double
    @Binding var zombieCount: Int
    let onStart: (CLLocationCoordinate2D) -> Void // Now passes selected center
    let userLocation: CLLocationCoordinate2D?
    let maxPlayers: Int // Maximum number of players in session
    @Environment(\.dismiss) var dismiss
    
    // Selected bubble center (defaults to user location)
    @State private var bubbleCenter: CLLocationCoordinate2D?
    
    // Initialize bubbleCenter immediately when view is created (not in onAppear)
    init(startRadius: Binding<Double>, duration: Binding<Double>, zombieCount: Binding<Int>, onStart: @escaping (CLLocationCoordinate2D) -> Void, userLocation: CLLocationCoordinate2D?, maxPlayers: Int) {
        self._startRadius = startRadius
        self._duration = duration
        self._zombieCount = zombieCount
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
    
    // Hardcoded ZombieTag theme colors
    private var primaryColor: Color {
        AppColors.zombiePrimary
    }
    
    private var secondaryColor: Color {
        AppColors.zombieSecondary
    }
    
    // Calculate shrink info
    private var shrinkInterval: Double { 180 } // 3 minutes
    private var numberOfShrinks: Int {
        Int(duration / shrinkInterval)
    }
    
    // Zombie count binding for slider
    private var zombieCountBinding: Binding<Double> {
        Binding(
            get: { 
                // Return current value as Double (clamping happens in setter and onAppear)
                return Double(zombieCount)
            },
            set: { 
                // Clamp the value to valid range
                let currentMax = max(1, maxPlayers - 1)
                let newValue = Int($0)
                zombieCount = min(max(1, newValue), max(2, currentMax)) // Ensure at least 2 for valid slider
            }
        )
    }
    
    // Max zombie count (maxPlayers - 1, minimum 1)
    // Note: If maxPlayers is 1, maxZombieCount will be 1, which creates invalid slider range
    private var maxZombieCount: Int {
        max(1, maxPlayers - 1)
    }
    
    // Check if slider range is valid (needs at least 2 different values)
    private var canShowZombieSlider: Bool {
        maxZombieCount > 1
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
                            
                            Text("Set up the play zone")
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
                            
                            // Duration
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Text("Game Duration")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    Text(timeString(from: duration))
                                        .font(AppTypography.labelMedium())
                                        .foregroundColor(AppColors.zombiePrimary)
                                }
                                
                                // Preset buttons
                                HStack(spacing: AppSpacing.xs) {
                                    presetButton(title: "5 min", duration: 300, currentDuration: $duration)
                                    presetButton(title: "10 min", duration: 600, currentDuration: $duration)
                                    presetButton(title: "15 min", duration: 900, currentDuration: $duration)
                                }
                                
                                Slider(value: $duration, in: 60...600, step: 30)
                                    .tint(primaryColor)
                            }
                            
                            Divider()
                            
                            // Zombie Count (for Zombie Tag)
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Text("Number of Initial Zombies")
                                        .font(AppTypography.labelLarge())
                                        .fontWeight(.semibold)
                                        .foregroundColor(AppColors.textPrimary)
                                    Spacer()
                                    Text("\(zombieCount)")
                                        .font(AppTypography.labelMedium())
                                        .foregroundColor(primaryColor)
                                }
                                
                                // Only show slider if we have a valid range (maxZombieCount > 1)
                                // Slider crashes with "max stride must be positive" if range is 1...1.0
                                if canShowZombieSlider {
                                    // Ensure valid range for slider (at least 1...2)
                                    let sliderMax = max(2, maxZombieCount)
                                    Slider(value: zombieCountBinding, in: 1...Double(sliderMax), step: 1)
                                    .tint(primaryColor)
                                } else {
                                    // If only 1 player, just show the value (can't have more than 1 zombie with 1 player)
                                    Text("1 (Only you in game)")
                                        .font(AppTypography.bodySmall())
                                        .foregroundColor(AppColors.textSecondary)
                                        .padding(.vertical, AppSpacing.xs)
                                }
                                
                                if canShowZombieSlider {
                                Text("Initial zombies will be randomly selected")
                                    .font(AppTypography.caption())
                                    .foregroundColor(AppColors.textTertiary)
                                }
                            }
                            
                            Divider()
                            
                            // Zone Shrink Info
                            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                Text("Zone Shrinks")
                                    .font(AppTypography.labelMedium())
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppColors.textPrimary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Every 3 minutes, shrinks by 15%")
                                        .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                                    Text("Zone moves randomly each shrink")
                                        .font(AppTypography.bodySmall())
                                        .foregroundColor(AppColors.textSecondary)
                                    Text("Shrinks to zero (no minimum)")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textTertiary)
                                    if numberOfShrinks > 0 {
                                        Text("Total shrinks: ~\(numberOfShrinks)")
                            .font(AppTypography.caption())
                                            .foregroundColor(AppColors.textTertiary)
                                    }
                                }
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
                            print("📍 ZombieTagBubbleSettingsView: Configure button pressed with center: \(center.latitude), \(center.longitude)")
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
                // Ensure zombieCount is valid when view appears
                if !canShowZombieSlider {
                    zombieCount = 1 // Force to 1 if only 1 player
                } else {
                    zombieCount = min(max(1, zombieCount), maxZombieCount) // Clamp to valid range
                }
    
                // Initialize bubble center to user location if not already set
                if bubbleCenter == nil, let location = userLocation {
                    bubbleCenter = location
                }
            }
            // Note: Radius changes are handled by DraggableBubbleMapView internally
            // No need to update mapRegion here as it can cause conflicts
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
    
    private func presetButton(title: String, duration: Double, currentDuration: Binding<Double>) -> some View {
        Button(action: {
            HapticFeedbackManager.shared.selection()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentDuration.wrappedValue = duration
            }
        }) {
            Text(title)
                .font(AppTypography.caption())
                .fontWeight(.medium)
                .foregroundColor(abs(currentDuration.wrappedValue - duration) < 30 ? .white : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(
                    Capsule()
                        .fill(abs(currentDuration.wrappedValue - duration) < 30 ? primaryColor : AppColors.backgroundSecondary)
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
    
    private func timeString(from seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let remainingSeconds = Int(seconds) % 60
        if minutes > 0 {
            return remainingSeconds > 0 ? "\(minutes)m \(remainingSeconds)s" : "\(minutes)m"
        } else {
            return "\(Int(seconds))s"
        }
    }
    
}
