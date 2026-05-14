//
//  FirestoreService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import CoreLocation
import FirebaseFirestore
import Combine

@MainActor
final class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private func print(_ message: String) {
        if message.hasPrefix("❌") {
            Swift.print(message)
        } else {
            DebugLogger.log(message)
        }
    }
    
    init() {
        // Configure date encoding/decoding for Firestore
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder.dateDecodingStrategy = .secondsSince1970
    }
    
    // MARK: - Helper Methods
    
    private func sessionToDictionary(_ session: GameSession) throws -> [String: Any] {
        let data = try encoder.encode(session)
        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode session"])
        }
        dict["playerIds"] = session.players.map(\.id)
        return dict
    }
    
    private func dictionaryToSession(_ dict: [String: Any], id: String) throws -> GameSession {
        var mutableDict = dict
        // Ensure ID matches document ID (use document ID as source of truth).
        // This injection plus `init(from:)` decoding `.id` directly means we
        // do NOT need to rebuild the session through a manual initializer —
        // doing so silently dropped CTF fields (flag placement flags, safe
        // zones, flag carriers) and would also drop compass fields. Return
        // the fully decoded session instead.
        mutableDict["id"] = id
        
        // Convert Firestore Timestamps to TimeInterval (seconds since 1970)
        func convertTimestamps(_ value: Any) -> Any {
            if let timestamp = value as? Timestamp {
                return timestamp.dateValue().timeIntervalSince1970
            } else if let dict = value as? [String: Any] {
                var converted: [String: Any] = [:]
                for (key, val) in dict {
                    converted[key] = convertTimestamps(val)
                }
                return converted
            } else if let array = value as? [Any] {
                return array.map { convertTimestamps($0) }
            }
            return value
        }
        
        // Convert all timestamps in the dictionary
        let converted = convertTimestamps(mutableDict)
        guard let convertedDict = converted as? [String: Any] else {
            throw NSError(domain: "FirestoreService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to convert timestamps in session dictionary"])
        }
        mutableDict = convertedDict
        
        let data = try JSONSerialization.data(withJSONObject: mutableDict)
        return try decoder.decode(GameSession.self, from: data)
    }
    
    private func encodeToFirestoreValue<T: Encodable>(_ value: T) throws -> Any {
        let data = try encoder.encode(value)
        return try JSONSerialization.jsonObject(with: data)
    }
    
    private func dataPreservingAuthoritativeZoneSchedule(
        _ data: [String: Any],
        incomingSession: GameSession,
        sessionRef: DocumentReference
    ) async throws -> [String: Any] {
        guard incomingSession.gameState == .active,
              let incomingBubble = incomingSession.bubble else {
            return data
        }
        
        let existingDocument = try await sessionRef.getDocument()
        guard existingDocument.exists,
              let existingData = existingDocument.data() else {
            return data
        }
        
        let existingSession = try dictionaryToSession(existingData, id: existingDocument.documentID)
        guard existingSession.gameState == .active,
              let existingBubble = existingSession.bubble,
              existingBubble.zoneScheduleEnabled,
              !existingBubble.zoneSchedule.isEmpty else {
            return data
        }
        
        let incomingGeneratedAt = incomingBubble.zoneScheduleGeneratedAt ?? .distantPast
        let existingGeneratedAt = existingBubble.zoneScheduleGeneratedAt ?? .distantPast
        guard incomingBubble.zoneSchedule.isEmpty || incomingGeneratedAt < existingGeneratedAt else {
            return data
        }
        
        var protectedData = data
        guard var outgoingBubbleData = protectedData["bubble"] as? [String: Any],
              let existingBubbleData = try sessionToDictionary(existingSession)["bubble"] as? [String: Any] else {
            return data
        }
        
        outgoingBubbleData["zoneSchedule"] = existingBubbleData["zoneSchedule"]
        outgoingBubbleData["zoneScheduleGeneratedAt"] = existingBubbleData["zoneScheduleGeneratedAt"]
        outgoingBubbleData["zoneScheduleEnabled"] = existingBubbleData["zoneScheduleEnabled"] ?? true
        protectedData["bubble"] = outgoingBubbleData
        
        print("🛡️ Preserved authoritative zoneSchedule during stale active-session write")
        return protectedData
    }
    
    // MARK: - Create Session
    
    func createSession(_ session: GameSession) async throws {
        let sessionRef = db.collection("sessions").document(session.id)
        let joinCodeRef = db.collection("joinCodes").document(session.joinCode)
        let data = try sessionToDictionary(session)
        let joinCodeData: [String: Any] = [
            "sessionId": session.id,
            "joinCode": session.joinCode,
            "hostId": session.hostId,
            "gameType": session.gameType.rawValue,
            "createdAt": FieldValue.serverTimestamp()
        ]

        let batch = db.batch()
        batch.setData(data, forDocument: sessionRef)
        batch.setData(joinCodeData, forDocument: joinCodeRef)
        try await batch.commit()
        print("✅ Session created in Firestore: \(session.id)")
    }
    
    // MARK: - Join Session by Code
    
    func findSessionByCode(_ joinCode: String) async throws -> GameSession? {
        guard let session = try await findSessionByCodeAnyState(joinCode),
              session.gameState == .lobby else {
            return nil
        }

        return session
    }
    
    // Find session by code (including active games - for reconnection)
    func findSessionByCodeAnyState(_ joinCode: String) async throws -> GameSession? {
        let joinCodeRef = db.collection("joinCodes").document(joinCode)
        let joinCodeDocument = try await joinCodeRef.getDocument()

        guard let joinCodeData = joinCodeDocument.data(),
              let sessionId = joinCodeData["sessionId"] as? String else {
            return nil
        }

        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDocument = try await sessionRef.getDocument()

        guard sessionDocument.exists,
              let data = sessionDocument.data() else {
            return nil
        }

        let session = try dictionaryToSession(data, id: sessionDocument.documentID)
        return session
    }
    
    // MARK: - Update Session
    
    func updateSession(_ session: GameSession) async throws {
        let sessionRef = db.collection("sessions").document(session.id)
        let data = try await dataPreservingAuthoritativeZoneSchedule(
            sessionToDictionary(session),
            incomingSession: session,
            sessionRef: sessionRef
        )
        try await sessionRef.setData(data, merge: true)
    }

    // MARK: - Compass Pulse (predator ability)

    /// Errors that can short-circuit a compass pulse commit. Each maps to
    /// a specific UI failure state (silent vs "Pulse failed" vs
    /// "No target") on the acting device.
    enum CompassPulseError: Error, Equatable {
        /// Caller is not currently a predator (role / alive / game-state).
        /// Surfaced silently — the UI shouldn't even have been tappable.
        case notEligible
        /// No alive prey of the required role exist. Surface as
        /// `"No targets"` and DO NOT advance the cooldown.
        case noEligiblePrey
        /// Caller's cooldown is still active per the latest session
        /// snapshot. Surface silently — UI should reflect this from the
        /// session listener; this guards against client-side drift.
        case cooldownActive(remaining: TimeInterval)
        /// Session document missing. Generic failure.
        case sessionMissing
        /// Session shape unreadable. Generic failure.
        case sessionDecodeFailed

        static func == (lhs: CompassPulseError, rhs: CompassPulseError) -> Bool {
            switch (lhs, rhs) {
            case (.notEligible, .notEligible),
                 (.noEligiblePrey, .noEligiblePrey),
                 (.sessionMissing, .sessionMissing),
                 (.sessionDecodeFailed, .sessionDecodeFailed):
                return true
            case (.cooldownActive(let l), .cooldownActive(let r)):
                return abs(l - r) < 0.001
            default:
                return false
            }
        }
    }

    /// Commit a compass pulse atomically. Reads the latest session inside
    /// a Firestore transaction, validates the caller and cooldown against
    /// THAT snapshot (not a stale local copy), picks a random eligible
    /// prey from the snapshot, computes great-circle distance from
    /// `actorLocation` (live local GPS) to the prey's snapshot
    /// coordinates, and writes only:
    ///
    /// - `compassPulse` — encoded `CompassPulse`
    /// - `compassLastUsedAtByPlayerId.<actorId>` — same `usedAt`
    ///
    /// Returns the committed pulse plus commit-time coordinates. The
    /// transaction closure may retry; the returned value is whichever attempt
    /// actually committed (the only truth for the acting device's result UI).
    func commitCompassPulse(
        sessionId: String,
        actorId: String,
        actorLocation: CLLocation,
        now: Date
    ) async throws -> CompassPulseCommit {
        let sessionRef = db.collection("sessions").document(sessionId)

        // Random source. Hoisted out of the closure so retries don't all
        // share a seed accidentally; `randomElement()` uses the system
        // RNG which is fine across retries.

        let commit = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CompassPulseCommit, Error>) in
            db.runTransaction({ [self] (transaction, errorPointer) -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(sessionRef)
                } catch let fetchError as NSError {
                    errorPointer?.pointee = fetchError
                    return nil
                }

                guard snapshot.exists, let raw = snapshot.data() else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -10,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Session missing",
                            "compassPulseErrorKind": "sessionMissing"
                        ]
                    )
                    return nil
                }

                let session: GameSession
                do {
                    session = try self.dictionaryToSession(raw, id: sessionId)
                } catch {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -11,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Session decode failed",
                            "compassPulseErrorKind": "sessionDecodeFailed"
                        ]
                    )
                    return nil
                }

                // Eligibility from transaction snapshot.
                guard session.gameState == .active,
                      session.supportsCompassAbility,
                      let predatorRole = session.compassPredatorRole,
                      let actor = session.players.first(where: { $0.id == actorId }),
                      actor.role == predatorRole,
                      actor.isAlive else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -12,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Caller not eligible to fire pulse",
                            "compassPulseErrorKind": "notEligible"
                        ]
                    )
                    return nil
                }

                // Cooldown from transaction snapshot.
                if let bubble = session.bubble {
                    let elapsed = now.timeIntervalSince(bubble.startTime)
                    let firstUse = CompassAbilityConfig.firstUseDelay(
                        elapsed: elapsed,
                        totalDuration: bubble.duration
                    )
                    if elapsed < firstUse {
                        let remaining = firstUse - elapsed
                        errorPointer?.pointee = NSError(
                            domain: "FirestoreService",
                            code: -13,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Compass not yet available",
                                "compassPulseErrorKind": "cooldownActive",
                                "remaining": remaining
                            ]
                        )
                        return nil
                    }

                    if let lastUsed = session.compassLastUsedAtByPlayerId[actorId] {
                        let cooldown = CompassAbilityConfig.cooldownDuration(
                            elapsed: elapsed,
                            totalDuration: bubble.duration
                        )
                        let sinceLast = now.timeIntervalSince(lastUsed)
                        if sinceLast < cooldown {
                            let remaining = cooldown - sinceLast
                            errorPointer?.pointee = NSError(
                                domain: "FirestoreService",
                                code: -13,
                                userInfo: [
                                    NSLocalizedDescriptionKey: "Compass on cooldown",
                                    "compassPulseErrorKind": "cooldownActive",
                                    "remaining": remaining
                                ]
                            )
                            return nil
                        }
                    }
                }

                let eligible = session.eligibleCompassPrey(firedBy: actorId)
                guard let target = eligible.randomElement() else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -14,
                        userInfo: [
                            NSLocalizedDescriptionKey: "No eligible prey",
                            "compassPulseErrorKind": "noEligiblePrey"
                        ]
                    )
                    return nil
                }

                let targetLocation = CLLocation(latitude: target.latitude, longitude: target.longitude)
                let distanceMeters = actorLocation.distance(from: targetLocation)

                let pulse = CompassPulse(
                    eventId: UUID().uuidString,
                    usedByPlayerId: actorId,
                    targetPlayerId: target.id,
                    distanceMeters: distanceMeters,
                    usedAt: now
                )

                let commit = CompassPulseCommit(
                    pulse: pulse,
                    actorLatitude: actorLocation.coordinate.latitude,
                    actorLongitude: actorLocation.coordinate.longitude,
                    targetLatitude: target.latitude,
                    targetLongitude: target.longitude
                )

                let pulseData: [String: Any]
                do {
                    pulseData = try self.compassPulseToDictionary(pulse)
                } catch {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -15,
                        userInfo: [
                            NSLocalizedDescriptionKey: "Failed to encode compass pulse"
                        ]
                    )
                    return nil
                }

                // Narrow updateData via FieldPath so the map key cannot be
                // misinterpreted as a dotted path even if `actorId` ever
                // contains '.' or '/'. Rules see top-level
                // `compassLastUsedAtByPlayerId` as the affected key.
                transaction.updateData(
                    [
                        "compassPulse": pulseData
                    ],
                    forDocument: sessionRef
                )
                transaction.updateData(
                    [
                        FieldPath(["compassLastUsedAtByPlayerId", actorId]):
                            Timestamp(date: pulse.usedAt)
                    ],
                    forDocument: sessionRef
                )

                return commit
            }) { value, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let commit = value as? CompassPulseCommit {
                    continuation.resume(returning: commit)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "FirestoreService",
                        code: -16,
                        userInfo: [NSLocalizedDescriptionKey: "Transaction returned unexpected value"]
                    ))
                }
            }
        }

        return commit
    }

    /// Encode `CompassPulse` to a Firestore-safe dictionary. Uses
    /// `Timestamp` for the `usedAt` field so rules can compare it
    /// against the map entry written under
    /// `compassLastUsedAtByPlayerId.<actorId>`.
    private func compassPulseToDictionary(_ pulse: CompassPulse) throws -> [String: Any] {
        return [
            "eventId": pulse.eventId,
            "usedByPlayerId": pulse.usedByPlayerId,
            "targetPlayerId": pulse.targetPlayerId,
            "distanceMeters": pulse.distanceMeters,
            "usedAt": Timestamp(date: pulse.usedAt)
        ]
    }
    
    func updatePlayerLocation(
        sessionId: String,
        player: Player,
        flags: [Flag]? = nil
    ) async throws {
        let sessionRef = db.collection("sessions").document(sessionId)
        let document = try await sessionRef.getDocument()
        guard document.exists,
              let documentData = document.data() else {
            throw NSError(domain: "FirestoreService", code: -3, userInfo: [NSLocalizedDescriptionKey: "Session document not found for location update"])
        }
        
        var latestSession = try dictionaryToSession(documentData, id: document.documentID)
        guard let playerIndex = latestSession.players.firstIndex(where: { $0.id == player.id }) else {
            throw NSError(domain: "FirestoreService", code: -4, userInfo: [NSLocalizedDescriptionKey: "Player not found for location update"])
        }
        
        latestSession.players[playerIndex].latitude = player.latitude
        latestSession.players[playerIndex].longitude = player.longitude
        latestSession.players[playerIndex].lastUpdated = player.lastUpdated
        
        var data: [String: Any] = [
            "players": try encodeToFirestoreValue(latestSession.players)
        ]
        if let flags {
            data["flags"] = try encodeToFirestoreValue(flags)
        }
        
        try await sessionRef.setData(data, merge: true)
    }
    
    // MARK: - Listen to Session Changes
    
    func listenToSession(_ sessionId: String, completion: @escaping (GameSession?) -> Void) {
        // Remove existing listener if any
        stopListening()
        
        let sessionRef = db.collection("sessions").document(sessionId)
        
        listener = sessionRef.addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                self.print("❌ Error fetching session: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }
            
            guard document.exists else {
                self.print("❌ Document does not exist")
                completion(nil)
                return
            }
            
            do {
                let data = document.data() ?? [:]
                let session = try self.dictionaryToSession(data, id: document.documentID)
                completion(session)
            } catch {
                self.print("❌ Error decoding session: \(error)")
                completion(nil)
            }
        }
    }
    
    // MARK: - Remove Listener
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    // MARK: - Delete Session
    
    func deleteSession(_ sessionId: String) async throws {
        let sessionRef = db.collection("sessions").document(sessionId)
        let sessionDocument = try await sessionRef.getDocument()

        let batch = db.batch()
        batch.deleteDocument(sessionRef)
        if let joinCode = sessionDocument.data()?["joinCode"] as? String {
            let joinCodeRef = db.collection("joinCodes").document(joinCode)
            batch.deleteDocument(joinCodeRef)
        }
        try await batch.commit()
        print("✅ Session deleted from Firestore: \(sessionId)")
    }
}
