//
//  CompassView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import CoreLocation

struct CompassView: View {
    let direction: Double? // Bearing in degrees (0-360, 0 = North)
    let distance: Double?
    let threatType: ThreatType
    let isVisible: Bool
    
    enum ThreatType {
        case hunter
        case hider
        
        var color: Color {
            switch self {
            case .hunter: return AppColors.hunterPrimary
            case .hider: return AppColors.hiderPrimary
            }
        }
        
        var icon: String {
            switch self {
            case .hunter: return "target"
            case .hider: return "person.fill"
            }
        }
        
        var label: String {
            switch self {
            case .hunter: return "Hunter"
            case .hider: return "Hider"
            }
        }
    }
    
    var body: some View {
        if isVisible, let direction = direction {
            VStack(spacing: AppSpacing.xs) {
                // Compass circle with arrow
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(threatType.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 80, height: 80)
                    
                    // Direction arrow
                    Image(systemName: "arrow.up")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(threatType.color)
                        .rotationEffect(.degrees(direction))
                        .shadow(color: threatType.color.opacity(0.5), radius: 4)
                    
                    // Center icon
                    Image(systemName: threatType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(threatType.color)
                }
                .frame(width: 80, height: 80)
                
                // Distance label with visual indicator
                if let distance = distance {
                    VStack(spacing: AppSpacing.xs) {
                        // Distance with color coding
                        let distanceColor = distanceColor(for: distance, threatType: threatType)
                        
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(distanceColor)
                            
                            Text("\(Int(distance))m")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(distanceColor)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(distanceColor.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(distanceColor.opacity(0.4), lineWidth: 1.5)
                                )
                        )
                        
                        Text(threatType.label)
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        
                        // Distance progress bar (visual indicator)
                        GeometryReader { geometry in
                            let progress = min(1.0, distance / 100.0) // Normalize to 100m max
                            let reverseProgress = 1.0 - progress // Closer = more filled
                            
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(AppColors.textSecondary.opacity(0.1))
                                    .frame(height: 3)
                                
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                distanceColor,
                                                distanceColor.opacity(0.6)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geometry.size.width * reverseProgress, height: 3)
                            }
                        }
                        .frame(height: 3)
                        .padding(.horizontal, 4)
                    }
                }
            }
            .padding(AppSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                threatType.color.opacity(0.3),
                                lineWidth: 1.5
                            )
                    )
                    .shadow(color: threatType.color.opacity(0.2), radius: 8, x: 0, y: 4)
            )
        }
    }
    
    // MARK: - Helper Functions
    
    private func distanceColor(for distance: Double, threatType: ThreatType) -> Color {
        switch threatType {
        case .hunter:
            // For hiders: red when hunter is close (danger)
            if distance < 10 {
                return AppColors.error
            } else if distance < 20 {
                return AppColors.warning
            } else if distance < 50 {
                return .orange
            } else {
                return AppColors.success
            }
        case .hider:
            // For hunters: green when hider is close (good)
            if distance < 10 {
                return AppColors.success
            } else if distance < 20 {
                return .orange
            } else if distance < 50 {
                return AppColors.warning
            } else {
                return AppColors.textSecondary
            }
        }
    }
}



