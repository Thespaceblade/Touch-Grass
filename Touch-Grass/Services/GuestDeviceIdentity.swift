//
//  GuestDeviceIdentity.swift
//  Touch-Grass
//
//  Stable per-physical-device guest identifier, persisted in the Keychain so
//  it survives reinstalls and does NOT sync via iCloud Keychain. This is the
//  primary player identity in guest mode (no real accounts yet); Firebase
//  Anonymous Auth in `AuthService` is only used to satisfy Firestore
//  security rules.
//
//  Two physical devices share an Apple ID and therefore can share one
//  Firebase anonymous user, but they will always have distinct guest
//  device ids (different Keychain stores), so they appear as distinct
//  players in a lobby.
//

import Foundation
import Security
import UIKit

@MainActor
final class GuestDeviceIdentity {
    static let shared = GuestDeviceIdentity()

    private let service = "com.touchgrass.guest"
    private let account = "guestDeviceId.v1"

    /// Legacy UserDefaults key used by previous builds. Read once and
    /// migrated into the Keychain so existing installs keep the same id.
    private let legacyUserDefaultsKey = "guestDeviceId.v1"

    private var cachedId: String?

    private init() {}

    /// Stable per-device guest player id. Created on first read and
    /// stored in the Keychain with a this-device-only accessibility
    /// flag so iCloud Keychain cannot replicate it to a second device.
    var id: String {
        if let cachedId { return cachedId }

        if let existing = readKeychain() {
            cachedId = existing
            return existing
        }

        // Migrate from a legacy UserDefaults-stored id if present so we
        // do not orphan existing testers across this change.
        if let legacy = UserDefaults.standard.string(forKey: legacyUserDefaultsKey) {
            writeKeychain(legacy)
            cachedId = legacy
            return legacy
        }

        // Seed from `identifierForVendor` when available so the same
        // device produces the same id on first install of this build,
        // falling back to a fresh UUID if the system value is missing.
        let seed = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let id = "gd-\(seed)"
        writeKeychain(id)
        UserDefaults.standard.set(id, forKey: legacyUserDefaultsKey)
        cachedId = id
        return id
    }

    // MARK: - Keychain helpers

    private func keychainQuery(includeData: Bool) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
        if includeData {
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
        }
        return query
    }

    private func readKeychain() -> String? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(keychainQuery(includeData: true) as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    private func writeKeychain(_ value: String) {
        let data = Data(value.utf8)
        // Remove any prior entry then add fresh so accessibility flags are
        // applied consistently. `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
        // prevents iCloud Keychain from replicating the value across devices.
        SecItemDelete(keychainQuery(includeData: false) as CFDictionary)

        var attributes = keychainQuery(includeData: false)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let status = SecItemAdd(attributes as CFDictionary, nil)
        if status != errSecSuccess {
            // Last-resort fallback: stash in UserDefaults so we never crash
            // a brand-new device that somehow can't write to Keychain.
            UserDefaults.standard.set(value, forKey: legacyUserDefaultsKey)
        }
    }
}
