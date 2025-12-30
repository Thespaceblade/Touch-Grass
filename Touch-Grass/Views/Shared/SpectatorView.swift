//
//  SpectatorView.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import MapKit

struct SpectatorView: View {
    @ObservedObject var gameService: GameService
    @ObservedObject var locationService: LocationService
    
    @State private var mapType: MKMapType = .standard
    @State private var currentTime: Date = Date()
    @State private var timer: Timer?
    @State private var showPlayerLabels: Bool = true
    
    var body: some View {
        let bubbleCenter = gameService.session?.bubble?.center
        let bubbleRadius = currentBubbleRadius
        
        return ZStack {
            // Full-screen map with bubble and players (no obfuscation for spectators)
            MapViewRepresentable(
                userCoordinate: locationService.coordinate,
                bubbleCenter: bubbleCenter,
                bubbleRadius: bubbleRadius,
                warningLevel: gameService.warningLevel,
                players: gameService.session?.players ?? [],
                currentPlayerId: gameService.currentPlayer?.id,
                currentPlayerRole: .hunter, // Spectators see all exact locations
                gameType: gameService.session?.gameType,
                flags: gameService.session?.flags ?? [],
                teamABase: gameService.session?.teamABase,
                teamBBase: gameService.session?.teamBBase,
                teamASafeZone: nil,
                teamBSafeZone: nil,
                isPingActive: false, // No obfuscation for spectators
                zoneRadius: bubbleRadius,
                mapType: $mapType,
                showPlayerLabels: $showPlayerLabels,
                zoomToBubbleTrigger: .constant(false),
                centerOnPlayerTrigger: .constant(false)
            )
            .ignoresSafeArea()
            
            // Spectator overlay
            VStack {
                // Top banner
                VStack(spacing: AppSpacing.xs) {
                    HStack {
                        Image(systemName: "eye.fill")
                            .foregroundColor(.white)
                        Text("SPECTATOR MODE")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.red.opacity(0.8), Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    
                    Text("You were eliminated. Watching the game...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Game stats panel
                gameStatsPanel
                    .padding()
            }
        }
    }
    
    private var currentBubbleRadius: Double {
        guard let bubble = gameService.session?.bubble else { return 0 }
        return bubble.currentRadius(at: currentTime)
    }
    
    private var gameStatsPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Game Status")
                .font(AppTypography.labelLarge())
                .fontWeight(.semibold)
            
            Divider()
            
            // Remaining players
            if let session = gameService.session {
                let alivePlayers = session.players.filter { $0.isAlive }
                let hunters = alivePlayers.filter { $0.role == .hunter }
                let hiders = alivePlayers.filter { $0.role == .hider }
                
                HStack {
                    Text("Remaining:")
                        .font(AppTypography.bodyMedium())
                    Spacer()
                    Text("\(alivePlayers.count) player\(alivePlayers.count == 1 ? "" : "s")")
                        .font(AppTypography.labelMedium())
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Hunters:")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.hunterPrimary)
                    Spacer()
                    Text("\(hunters.count)")
                        .font(AppTypography.labelSmall())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.hunterPrimary)
                }
                
                HStack {
                    Text("Hiders:")
                        .font(AppTypography.bodySmall())
                        .foregroundColor(AppColors.hiderPrimary)
                    Spacer()
                    Text("\(hiders.count)")
                        .font(AppTypography.labelSmall())
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.hiderPrimary)
                }
                
                // Time remaining
                if let bubble = session.bubble {
                    let elapsed = currentTime.timeIntervalSince(bubble.startTime)
                    let remaining = max(0, bubble.duration - elapsed)
                    
                    Divider()
                    
                    HStack {
                        Text("Time Remaining:")
                            .font(AppTypography.bodySmall())
                        Spacer()
                        Text(timeString(from: remaining))
                            .font(AppTypography.labelMedium())
                            .fontWeight(.semibold)
                            .foregroundColor(remaining < 60 ? .red : .primary)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
