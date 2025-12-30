//
//  LocationObfuscationService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationObfuscationService: ObservableObject {
    // Radar ping timing: every 60 seconds, show for 10 seconds
    static let pingInterval: TimeInterval = 60.0 // 1 minute
    static let pingDuration: TimeInterval = 10.0 // 10 seconds
    
    @Published var isPingActive: Bool = false
    @Published var pingStartTime: Date?
    
    private var pingTimer: Timer?
    private var pingEndTimer: Timer?
    
    init() {
        startPingCycle()
    }
    
    func startPingCycle() {
        // Start first ping immediately
        triggerPing()
        
        // Schedule recurring pings
        pingTimer = Timer.scheduledTimer(withTimeInterval: Self.pingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.triggerPing()
            }
        }
    }
    
    private func triggerPing() {
        isPingActive = true
        pingStartTime = Date()
        
        // Schedule ping end
        pingEndTimer?.invalidate()
        pingEndTimer = Timer.scheduledTimer(withTimeInterval: Self.pingDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isPingActive = false
                self?.pingStartTime = nil
            }
        }
    }
    
    func stop() {
        pingTimer?.invalidate()
        pingTimer = nil
        pingEndTimer?.invalidate()
        pingEndTimer = nil
        isPingActive = false
        pingStartTime = nil
    }
    
    deinit {
        // Cleanup happens automatically when the service is deallocated
        // Can't call MainActor-isolated methods from deinit
    }
}

