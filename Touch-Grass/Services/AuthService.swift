//
//  AuthService.swift
//  Touch-Grass
//
//  Anonymous Firebase Auth identity for multiplayer session ownership.
//

import Foundation
import Combine
import FirebaseCore
import FirebaseAuth
import UIKit

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published private(set) var userId: String?
    @Published private(set) var authenticationError: String?

    private let debugFallbackUserIdKey = "debugFallbackUserId"
    private var signInTask: Task<String, Error>?

    private init() {}

    var isSignedIn: Bool {
        userId != nil
    }

    func start() {
        Task {
            do {
                _ = try await ensureSignedIn()
            } catch {
                authenticationError = error.localizedDescription
                DebugLogger.error("Auth failed: \(error.localizedDescription)")
            }
        }
    }

    func ensureSignedIn() async throws -> String {
        if let userId = userId {
            return userId
        }

        guard FirebaseApp.app() != nil else {
            #if DEBUG
            let fallback = debugFallbackUserId()
            userId = fallback
            authenticationError = nil
            return fallback
            #else
            throw AuthServiceError.firebaseNotConfigured
            #endif
        }

        if let currentUser = Auth.auth().currentUser {
            userId = currentUser.uid
            authenticationError = nil
            return currentUser.uid
        }

        if let signInTask {
            return try await signInTask.value
        }

        let task = Task<String, Error> {
            try await withCheckedThrowingContinuation { continuation in
                Auth.auth().signInAnonymously { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let uid = result?.user.uid {
                        continuation.resume(returning: uid)
                    } else {
                        continuation.resume(throwing: AuthServiceError.missingUserId)
                    }
                }
            }
        }

        signInTask = task
        do {
            let uid = try await task.value
            userId = uid
            authenticationError = nil
            signInTask = nil
            return uid
        } catch {
            authenticationError = error.localizedDescription
            signInTask = nil
            throw error
        }
    }

    func currentUserIdForLocalOperation() -> String {
        if let userId = userId {
            return userId
        }

        if FirebaseApp.app() != nil, let uid = Auth.auth().currentUser?.uid {
            userId = uid
            return uid
        }

        #if DEBUG
        let fallback = debugFallbackUserId()
        userId = fallback
        return fallback
        #else
        return UUID().uuidString
        #endif
    }

    private func debugFallbackUserId() -> String {
        if let existing = UserDefaults.standard.string(forKey: debugFallbackUserIdKey) {
            return existing
        }

        let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let fallback = "debug-\(deviceId)"
        UserDefaults.standard.set(fallback, forKey: debugFallbackUserIdKey)
        return fallback
    }
}

enum AuthServiceError: LocalizedError {
    case firebaseNotConfigured
    case missingUserId

    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not configured. Please check GoogleService-Info.plist."
        case .missingUserId:
            return "Firebase sign-in completed without a user id."
        }
    }
}
