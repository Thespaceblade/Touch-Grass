//
//  DebugLogger.swift
//  Touch-Grass
//
//  Optimized logging - only logs in debug builds
//

import Foundation

struct DebugLogger {
    #if DEBUG
    static let enabled = true
    #else
    static let enabled = false
    #endif
    
    static func log(_ message: String) {
        if enabled {
            print(message)
        }
    }
    
    static func error(_ message: String) {
        // Always log errors, even in release
        print("❌ ERROR: \(message)")
    }
}




