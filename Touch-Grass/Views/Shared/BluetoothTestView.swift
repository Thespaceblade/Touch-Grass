//
//  BluetoothTestView.swift
//  Touch-Grass
//
//  Created for testing Bluetooth functionality
//

import SwiftUI
import CoreBluetooth

struct BluetoothTestView: View {
    @StateObject private var bluetoothService = BluetoothTagService()
    @State private var testPlayerId: String = UUID().uuidString
    @State private var testPlayerName: String = "Test Player"
    @State private var selectedPlayerId: String?
    @State private var showTagRequest: Bool = false
    @State private var tagRequestFrom: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    VStack(spacing: AppSpacing.sm) {
                        Text("Bluetooth Test")
                            .font(AppTypography.displayMedium())
                            .foregroundColor(AppColors.textPrimary)
                        
                        Text("Test BLE advertising and scanning")
                            .font(AppTypography.bodySmall())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.top, AppSpacing.xl)
                    
                    // Player Info Card
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Player Info")
                            .font(AppTypography.labelLarge())
                            .fontWeight(.semibold)
                        
                        TextField("Player Name", text: $testPlayerName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Text("Player ID: \(testPlayerId)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        
                        Button(action: {
                            testPlayerId = UUID().uuidString
                        }) {
                            Text("Generate New ID")
                                .font(AppTypography.caption())
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.backgroundSecondary)
                    )
                    
                    // Status Card
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Bluetooth Status")
                            .font(AppTypography.labelLarge())
                            .fontWeight(.semibold)
                        
                        HStack {
                            Circle()
                                .fill(bluetoothService.isAdvertising ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text("Advertising: \(bluetoothService.isAdvertising ? "ON" : "OFF")")
                                .font(AppTypography.bodyMedium())
                        }
                        
                        HStack {
                            Circle()
                                .fill(bluetoothService.isScanning ? Color.green : Color.red)
                                .frame(width: 12, height: 12)
                            Text("Scanning: \(bluetoothService.isScanning ? "ON" : "OFF")")
                                .font(AppTypography.bodyMedium())
                        }
                        
                        // Control Buttons
                        HStack(spacing: AppSpacing.sm) {
                            Button(action: {
                                bluetoothService.start(playerId: testPlayerId, playerName: testPlayerName)
                            }) {
                                Text("Start BLE")
                                    .font(AppTypography.bodyMedium())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green)
                                    )
                            }
                            
                            Button(action: {
                                bluetoothService.stop()
                            }) {
                                Text("Stop BLE")
                                    .font(AppTypography.bodyMedium())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red)
                                    )
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.backgroundSecondary)
                    )
                    
                    // Nearby Players Card
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Nearby Players (\(bluetoothService.nearbyPlayers.count))")
                            .font(AppTypography.labelLarge())
                            .fontWeight(.semibold)
                        
                        if bluetoothService.nearbyPlayers.isEmpty {
                            Text("No nearby players detected")
                                .font(AppTypography.bodySmall())
                                .foregroundColor(AppColors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(AppSpacing.lg)
                        } else {
                            ForEach(bluetoothService.nearbyPlayers) { player in
                                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                                    HStack {
                                        Text(player.name)
                                            .font(AppTypography.bodyMedium())
                                            .fontWeight(.semibold)
                                        Spacer()
                                        Text("RSSI: \(player.rssi)")
                                            .font(AppTypography.caption())
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                    
                                    Text("ID: \(player.id)")
                                        .font(AppTypography.caption())
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    if bluetoothService.canTagPlayer == player.id {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Can Tag")
                                                .font(AppTypography.caption())
                                                .foregroundColor(.green)
                                        }
                                    }
                                    
                                    Button(action: {
                                        selectedPlayerId = player.id
                                        bluetoothService.requestTag(playerId: player.id)
                                    }) {
                                        Text("Request Tag")
                                            .font(AppTypography.caption())
                                            .foregroundColor(.white)
                                            .padding(.horizontal, AppSpacing.sm)
                                            .padding(.vertical, AppSpacing.xs)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(Color.blue)
                                            )
                                    }
                                }
                                .padding(AppSpacing.sm)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.backgroundPrimary)
                                )
                            }
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.backgroundSecondary)
                    )
                    
                    // Tag Request Card
                    if let tagRequest = bluetoothService.tagRequestReceived {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            Text("Tag Request Received")
                                .font(AppTypography.labelLarge())
                                .fontWeight(.semibold)
                            
                            Text("From: \(tagRequest.fromPlayerName)")
                                .font(AppTypography.bodyMedium())
                            
                            Text("ID: \(tagRequest.fromPlayerId)")
                                .font(AppTypography.caption())
                                .foregroundColor(AppColors.textSecondary)
                            
                            HStack(spacing: AppSpacing.sm) {
                                Button(action: {
                                    bluetoothService.confirmTag(playerId: tagRequest.fromPlayerId)
                                    bluetoothService.rejectTag()
                                }) {
                                    Text("Confirm")
                                        .font(AppTypography.bodyMedium())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, AppSpacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.green)
                                        )
                                }
                                
                                Button(action: {
                                    bluetoothService.rejectTag()
                                }) {
                                    Text("Reject")
                                        .font(AppTypography.bodyMedium())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, AppSpacing.sm)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.red)
                                        )
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.orange.opacity(0.2))
                        )
                    }
                    
                    // Debug Info
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Debug Info")
                            .font(AppTypography.labelLarge())
                            .fontWeight(.semibold)
                        
                        Text("Service UUID: A7CE1234-1234-1234-1234-123456789ABC")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("Characteristic UUID: A7CE5678-5678-5678-5678-123456789ABC")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("Connection Threshold: RSSI > -70")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(AppSpacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.backgroundSecondary)
                    )
                }
                .padding(AppSpacing.md)
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Set up callbacks for testing
                bluetoothService.onTagRequest = { fromPlayerId, fromPlayerName in
                    print("📥 Test: Tag request received from \(fromPlayerName) (\(fromPlayerId))")
                }
                
                bluetoothService.onTagConfirmed = { playerId in
                    print("✅ Test: Tag confirmed by \(playerId)")
                }
            }
        }
    }
}

#Preview {
    BluetoothTestView()
}


