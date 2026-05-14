//
//  ZoneNotificationView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/31/25.
//

import SwiftUI

/// Fortnite-style zone notification with countdown timer
struct ZoneNotificationView: View {
    let title: String
    let countdown: TimeInterval
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            CartoonMedallion(background: color, size: 38) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(AppColors.cartoonInk)
                
                Text(formatCountdown(countdown))
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cartoonCard(cornerRadius: 16, shadowOffset: 4, borderWidth: 2.5)
    }
    
    private func formatCountdown(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, secs)
        } else {
            return String(format: "%d", secs)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        ZoneNotificationView(
            title: "First zone reveals in",
            countdown: 45,
            icon: "exclamationmark.triangle.fill",
            color: .orange
        )
        
        ZoneNotificationView(
            title: "Zone closes in",
            countdown: 30,
            icon: "arrow.triangle.2.circlepath",
            color: .red
        )
        
        ZoneNotificationView(
            title: "Zone closing",
            countdown: 25,
            icon: "arrow.triangle.2.circlepath",
            color: .red
        )
    }
    .padding()
    .background(Color.black)
}









