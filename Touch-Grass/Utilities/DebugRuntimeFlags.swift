//
//  DebugRuntimeFlags.swift
//  Touch-Grass
//

import Foundation

/// Runtime toggles for debug / UI iteration. In release builds every flag is effectively off.
enum DebugRuntimeFlags {
    #if DEBUG
    /// Skip the full-screen pre-game countdown (Manhunt / Zombie Tag lobby → active, CTF flag placement → active).
    static var skipPreGameCountdown: Bool = false
    #else
    static var skipPreGameCountdown: Bool { false }
    #endif
}
