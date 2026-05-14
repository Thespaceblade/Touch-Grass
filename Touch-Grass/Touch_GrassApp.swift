//
//  Touch_GrassApp.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import SwiftUI
import FirebaseCore
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        #if DEBUG
        // In screenshot mode we deliberately bypass Firebase / Auth so that
        // the app never tries to hit the network and so XCTest sees a clean,
        // deterministic SwiftUI hierarchy.
        if ScreenshotScenario.isActive {
            return true
        }
        #endif
        FirebaseApp.configure()
        AuthService.shared.start()
        return true
    }
}

@main
struct Touch_GrassApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let scenario = ScreenshotScenario.current() {
                ScreenshotScenarioRootView(scenario: scenario)
            } else {
                ContentView()
            }
            #else
            ContentView()
            #endif
        }
    }
}
