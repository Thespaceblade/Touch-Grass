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

    private static func isCoordinateOutsideActiveZone(
        _ coordinate: CLLocationCoordinate2D,
        bubble: Bubble,
        now: Date
    ) -> Bool {
        let distanceToEdge: Double

        if bubble.usesNewZoneSystem {
            let runtimeState = ZoneService.deriveRuntimeZoneState(for: bubble, now: now)
            let radius = runtimeState.currentActiveZone.radiusMeters
            guard radius.isFinite && radius > 0 else { return false }
            distanceToEdge = runtimeState.distanceToEdge(from: coordinate)
            guard distanceToEdge.isFinite else { return false }
            return distanceToEdge - ZoneService.enforcementToleranceMeters > 0
        }

        let radius = bubble.currentRadius(at: now)
        guard radius.isFinite && radius > 0 else { return false }
        distanceToEdge = bubble.distanceToEdge(from: coordinate, at: now)
        guard distanceToEdge.isFinite else { return false }
        return distanceToEdge > 0
    }
    
    // MARK: - Helper Methods
    
    private func sessionToDictionary(_ session: GameSession) throws -> [String: Any] {
        let data = try encoder.encode(session)
        guard var dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode session"])
        }
        // Top-level mirror fields keep Firestore security rules and join-code
        // lookups simple (they would otherwise have to walk into the `players`
        // array). `playerIds` is the per-device roster, `memberAuthUids`
        // collapses to one entry per Firebase account.
        dict["playerIds"] = session.players.map(\.id)
        dict["memberAuthUids"] = session.memberAuthUserIds
        dict["playerAuthByPlayerId"] = FirestoreService.playerAuthMap(for: session.players)
        dict["hostPlayerId"] = session.hostPlayerId
        dict["hostAuthUid"] = session.hostAuthUid
        dict["endReason"] = session.endReason?.rawValue ?? NSNull()
        return dict
    }

    /// Top-level `playerId -> authUserId` map mirrored from the roster.
    /// Used by Firestore security rules to verify that a member update is
    /// actually being performed by the owner of the affected player row
    /// (rules can't iterate the `players` array, but they can index this
    /// map by the caller's `request.auth.uid` after a lookup-by-id check).
    static func playerAuthMap(for players: [Player]) -> [String: String] {
        var map: [String: String] = [:]
        map.reserveCapacity(players.count)
        for player in players {
            map[player.id] = player.authUserId
        }
        return map
    }
    
    private func dictionaryToSession(_ dict: [String: Any], id: String) throws -> GameSession {
        var mutableDict = dict
        // Ensure ID matches document ID (use document ID as source of truth).
        // This injection plus `init(from:)` decoding `.id` directly means we
        // do NOT need to rebuild the session through a manual initializer -
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
    
    // MARK: - Fetch Session

    /// One-shot read of a session document. Used by `GameService` lobby
    /// commits to ground every write on the authoritative server roster
    /// instead of a possibly-stale local copy.
    func fetchSession(sessionId: String) async throws -> GameSession? {
        let sessionRef = db.collection("sessions").document(sessionId)
        let snapshot = try await sessionRef.getDocument()
        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }
        return try dictionaryToSession(data, id: snapshot.documentID)
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

    // MARK: - Join Session

    enum JoinSessionError: LocalizedError {
        case sessionMissing
        case notLobby
        case full
        case decodeFailed
        case encodeFailed
        case unexpectedTransactionResult

        var errorDescription: String? {
            switch self {
            case .sessionMissing:
                return "Session not found."
            case .notLobby:
                return "This game has already started."
            case .full:
                return "Session is full."
            case .decodeFailed:
                return "Session data could not be read."
            case .encodeFailed:
                return "Session data could not be saved."
            case .unexpectedTransactionResult:
                return "Join transaction returned an unexpected result."
            }
        }
    }

    /// Atomically appends or refreshes a player in the latest lobby roster.
    /// This avoids the stale read/whole-session write race where a join can
    /// be overwritten by a host lobby update, and it writes only the fields
    /// that Firestore rules allow non-host members to change.
    func joinSession(sessionId: String, player: Player, maxPlayers: Int) async throws -> GameSession {
        let sessionRef = db.collection("sessions").document(sessionId)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GameSession, Error>) in
            db.runTransaction({ [self] transaction, errorPointer -> Any? in
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
                        code: -20,
                        userInfo: [
                            NSLocalizedDescriptionKey: JoinSessionError.sessionMissing.localizedDescription,
                            "joinSessionErrorKind": "sessionMissing"
                        ]
                    )
                    return nil
                }

                var session: GameSession
                do {
                    session = try self.dictionaryToSession(raw, id: sessionId)
                } catch {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -21,
                        userInfo: [
                            NSLocalizedDescriptionKey: JoinSessionError.decodeFailed.localizedDescription,
                            "joinSessionErrorKind": "decodeFailed"
                        ]
                    )
                    return nil
                }

                guard session.gameState == .lobby else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -22,
                        userInfo: [
                            NSLocalizedDescriptionKey: JoinSessionError.notLobby.localizedDescription,
                            "joinSessionErrorKind": "notLobby"
                        ]
                    )
                    return nil
                }

                if let existingIndex = session.players.firstIndex(where: { $0.id == player.id }) {
                    var refreshedPlayer = session.players[existingIndex]
                    refreshedPlayer.displayName = player.displayName
                    refreshedPlayer.latitude = player.latitude
                    refreshedPlayer.longitude = player.longitude
                    refreshedPlayer.lastUpdated = player.lastUpdated
                    refreshedPlayer.profilePictureBase64 = player.profilePictureBase64
                    refreshedPlayer.authUserId = player.authUserId
                    refreshedPlayer.deviceInstallationId = player.deviceInstallationId
                    session.players[existingIndex] = refreshedPlayer
                } else {
                    guard session.players.count < maxPlayers else {
                        errorPointer?.pointee = NSError(
                            domain: "FirestoreService",
                            code: -23,
                            userInfo: [
                                NSLocalizedDescriptionKey: JoinSessionError.full.localizedDescription,
                                "joinSessionErrorKind": "full"
                            ]
                        )
                        return nil
                    }

                    session.players.append(player)
                }

                do {
                    transaction.updateData(
                        [
                            "players": try self.encodeToFirestoreValue(session.players),
                            "playerIds": session.players.map(\.id),
                            "memberAuthUids": session.memberAuthUserIds,
                            "playerAuthByPlayerId": FirestoreService.playerAuthMap(for: session.players)
                        ],
                        forDocument: sessionRef
                    )
                } catch {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -24,
                        userInfo: [
                            NSLocalizedDescriptionKey: JoinSessionError.encodeFailed.localizedDescription,
                            "joinSessionErrorKind": "encodeFailed"
                        ]
                    )
                    return nil
                }

                return session
            }) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let session = value as? GameSession {
                    continuation.resume(returning: session)
                } else {
                    continuation.resume(throwing: JoinSessionError.unexpectedTransactionResult)
                }
            }
        }
    }

    // MARK: - Leave Session

    enum LeaveSessionError: LocalizedError {
        case sessionMissing
        case decodeFailed
        case encodeFailed
        case unexpectedTransactionResult

        var errorDescription: String? {
            switch self {
            case .sessionMissing:
                return "Session not found."
            case .decodeFailed:
                return "Session data could not be read."
            case .encodeFailed:
                return "Session data could not be saved."
            case .unexpectedTransactionResult:
                return "Leave transaction returned an unexpected result."
            }
        }
    }

    /// Atomically handles explicit user leave:
    /// - host device: marks the session ended with `hostLeft` so every
    ///   listener can show a clear "game closed" notice before local cleanup.
    /// - non-host device: removes only that device-scoped player from the roster.
    func leaveSession(sessionId: String, playerId: String) async throws -> GameSession {
        let sessionRef = db.collection("sessions").document(sessionId)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<GameSession, Error>) in
            db.runTransaction({ [self] transaction, errorPointer -> Any? in
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
                        code: -30,
                        userInfo: [
                            NSLocalizedDescriptionKey: LeaveSessionError.sessionMissing.localizedDescription,
                            "leaveSessionErrorKind": "sessionMissing"
                        ]
                    )
                    return nil
                }

                var session: GameSession
                do {
                    session = try self.dictionaryToSession(raw, id: sessionId)
                } catch {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -31,
                        userInfo: [
                            NSLocalizedDescriptionKey: LeaveSessionError.decodeFailed.localizedDescription,
                            "leaveSessionErrorKind": "decodeFailed"
                        ]
                    )
                    return nil
                }

                guard session.players.contains(where: { $0.id == playerId }) else {
                    return session
                }

                if session.isDeviceHost(playerId: playerId) {
                    session.gameState = .ended
                    session.endReason = .hostLeft
                    transaction.updateData(
                        [
                            "gameState": session.gameState.rawValue,
                            "endReason": GameEndReason.hostLeft.rawValue
                        ],
                        forDocument: sessionRef
                    )
                } else {
                    session.players.removeAll { $0.id == playerId }

                    do {
                        transaction.updateData(
                            [
                                "players": try self.encodeToFirestoreValue(session.players),
                                "playerIds": session.players.map(\.id),
                                "memberAuthUids": session.memberAuthUserIds,
                                "playerAuthByPlayerId": FirestoreService.playerAuthMap(for: session.players)
                            ],
                            forDocument: sessionRef
                        )
                    } catch {
                        errorPointer?.pointee = NSError(
                            domain: "FirestoreService",
                            code: -32,
                            userInfo: [
                                NSLocalizedDescriptionKey: LeaveSessionError.encodeFailed.localizedDescription,
                                "leaveSessionErrorKind": "encodeFailed"
                            ]
                        )
                        return nil
                    }
                }

                return session
            }) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let session = value as? GameSession {
                    continuation.resume(returning: session)
                } else {
                    continuation.resume(throwing: LeaveSessionError.unexpectedTransactionResult)
                }
            }
        }
    }

    // MARK: - Compass Pulse (predator ability)

    /// Errors that can short-circuit a compass pulse commit. Each maps to
    /// a specific UI failure state (silent vs "Pulse failed" vs
    /// "No target") on the acting device.
    enum CompassPulseError: Error, Equatable {
        /// Caller is not currently a predator (role / alive / game-state).
        /// Surfaced silently, the UI shouldn't even have been tappable.
        case notEligible
        /// No alive prey of the required role exist. Surface as
        /// `"No targets"` and DO NOT advance the cooldown.
        case noEligiblePrey
        /// Caller's cooldown is still active per the latest session
        /// snapshot. Surface silently, UI should reflect this from the
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
    /// - `compassPulse`, encoded `CompassPulse`
    /// - `compassLastUsedAtByPlayerId.<actorId>`, same `usedAt`
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

                    if Self.isCoordinateOutsideActiveZone(actorLocation.coordinate, bubble: bubble, now: now) {
                        errorPointer?.pointee = NSError(
                            domain: "FirestoreService",
                            code: -15,
                            userInfo: [
                                NSLocalizedDescriptionKey: "Predator is outside the active zone",
                                "compassPulseErrorKind": "outsideZone"
                            ]
                        )
                        return nil
                    }
                }

                let eligible = session.eligibleCompassPrey(firedBy: actorId, now: now)
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

    // MARK: - Manhunt Catch

    /// How a Manhunt catch was initiated. The transaction validates caller
    /// eligibility against the snapshot per source kind, so the field is
    /// authoritative even if the optimistic local state was wrong.
    enum ManhuntCatchKind {
        /// BLE-confirmed proximity tag. Caller must be an alive hunter in
        /// the snapshot and the target must be an alive hider.
        case bluetooth
        /// Hider self-reports they were tagged when BLE missed. Caller must
        /// be the target (same `playerId`) and an alive hider.
        case honor
        /// Zone / out-of-bounds elimination of a hider. Caller is any
        /// member; the transaction still requires the target to be an
        /// alive hider.
        case zone
    }

    enum ManhuntCatchError: LocalizedError {
        case sessionMissing
        case decodeFailed
        case notManhunt
        case targetMissing
        case targetAlreadyDead
        case targetNotHider
        case callerNotMember
        case callerNotHunter
        case callerNotTarget
        case gameNotActive

        var errorDescription: String? {
            switch self {
            case .sessionMissing: return "Session not found."
            case .decodeFailed: return "Session data could not be read."
            case .notManhunt: return "This game type does not support manhunt catches."
            case .targetMissing: return "Target player not in roster."
            case .targetAlreadyDead: return "Target player is already eliminated."
            case .targetNotHider: return "Target player is not a hider."
            case .callerNotMember: return "Caller is not a session member."
            case .callerNotHunter: return "Only an alive hunter can confirm a tag."
            case .callerNotTarget: return "Only the target player can self-report a tag."
            case .gameNotActive: return "Game is not active."
            }
        }
    }

    /// Result returned to the calling device after a successful commit.
    /// Reflects the authoritative server-side state so the caller can
    /// reconcile local UI without re-reading the session.
    struct ManhuntCatchCommit {
        let firstTaggedPlayerId: String?
        let players: [Player]
    }

    /// Atomically marks the target hider dead and (if previously unset)
    /// records them as `firstTaggedPlayerId`. Used by every Manhunt catch
    /// path so non-host hunters and self-reporting hiders no longer rely
    /// on broad host-only `updateSession` writes that Firestore rules
    /// reject. The transaction is the authoritative source of truth for
    /// catch state, and the security rule is a belt-and-suspenders gate
    /// on the diff shape.
    func commitManhuntCatch(
        sessionId: String,
        callerPlayerId: String,
        targetPlayerId: String,
        kind: ManhuntCatchKind
    ) async throws -> ManhuntCatchCommit {
        let sessionRef = db.collection("sessions").document(sessionId)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ManhuntCatchCommit, Error>) in
            db.runTransaction({ [self] transaction, errorPointer -> Any? in
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
                        code: -50,
                        userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.sessionMissing.localizedDescription]
                    )
                    return nil
                }

                var session: GameSession
                do {
                    session = try self.dictionaryToSession(raw, id: sessionId)
                } catch {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -51,
                        userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.decodeFailed.localizedDescription]
                    )
                    return nil
                }

                guard session.gameType == .manhunt else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -52,
                        userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.notManhunt.localizedDescription]
                    )
                    return nil
                }

                guard session.gameState == .active else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -53,
                        userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.gameNotActive.localizedDescription]
                    )
                    return nil
                }

                guard let targetIndex = session.players.firstIndex(where: { $0.id == targetPlayerId }) else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -54,
                        userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.targetMissing.localizedDescription]
                    )
                    return nil
                }

                let target = session.players[targetIndex]
                guard target.role == .hider else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -55,
                        userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.targetNotHider.localizedDescription]
                    )
                    return nil
                }

                guard target.isAlive else {
                    // Race-safe no-op: target was already caught by another
                    // client. Treat as success and return the snapshot so
                    // the caller's UI converges without an error.
                    let commit = ManhuntCatchCommit(
                        firstTaggedPlayerId: session.firstTaggedPlayerId,
                        players: session.players
                    )
                    return commit
                }

                guard let caller = session.players.first(where: { $0.id == callerPlayerId }) else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -56,
                        userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.callerNotMember.localizedDescription]
                    )
                    return nil
                }

                // Per-kind eligibility. Belt-and-suspenders: the local UI
                // should already have gated these, but the transaction
                // re-validates against the authoritative snapshot.
                switch kind {
                case .bluetooth:
                    guard caller.role == .hunter, caller.isAlive else {
                        errorPointer?.pointee = NSError(
                            domain: "FirestoreService",
                            code: -57,
                            userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.callerNotHunter.localizedDescription]
                        )
                        return nil
                    }
                case .honor:
                    guard caller.id == target.id else {
                        errorPointer?.pointee = NSError(
                            domain: "FirestoreService",
                            code: -58,
                            userInfo: [NSLocalizedDescriptionKey: ManhuntCatchError.callerNotTarget.localizedDescription]
                        )
                        return nil
                    }
                case .zone:
                    // Any member can flag a hider as out-of-bounds; the
                    // role/alive checks above already guarded against
                    // eliminating non-hiders.
                    break
                }

                session.players[targetIndex].isAlive = false

                var updates: [String: Any] = [:]
                do {
                    updates["players"] = try self.encodeToFirestoreValue(session.players)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                if session.firstTaggedPlayerId == nil {
                    session.firstTaggedPlayerId = target.id
                    updates["firstTaggedPlayerId"] = target.id
                }

                transaction.updateData(updates, forDocument: sessionRef)

                return ManhuntCatchCommit(
                    firstTaggedPlayerId: session.firstTaggedPlayerId,
                    players: session.players
                )
            }) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let commit = value as? ManhuntCatchCommit {
                    continuation.resume(returning: commit)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "FirestoreService",
                        code: -59,
                        userInfo: [NSLocalizedDescriptionKey: "Manhunt catch returned unexpected value"]
                    ))
                }
            }
        }
    }

    // MARK: - Presence Heartbeat

    enum PlayerPresenceError: LocalizedError {
        case sessionMissing
        case playerMissing
        case decodeFailed

        var errorDescription: String? {
            switch self {
            case .sessionMissing: return "Session not found."
            case .playerMissing: return "Player not in session."
            case .decodeFailed: return "Session data could not be read."
            }
        }
    }

    /// Bumps the caller's own `lastUpdated` so other clients see them as
    /// connected even when their GPS coordinates haven't changed.
    ///
    /// Uses a transaction to avoid clobbering other players' rows on a
    /// stale local copy. Writes only the `players` array (no mirror or
    /// `gameState` mutation), keeping the diff inside what the member
    /// presence rule permits.
    /// Updates the caller's roster row inside a transaction.
    /// - `includeCoordinates: false` — heartbeat-only `lastUpdated` bump.
    /// - `includeCoordinates: true` — also writes `latitude` / `longitude`.
    func commitPlayerPresence(
        sessionId: String,
        player: Player,
        includeCoordinates: Bool = false
    ) async throws {
        let sessionRef = db.collection("sessions").document(sessionId)

        _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            db.runTransaction({ [self] transaction, errorPointer -> Any? in
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
                        code: -40,
                        userInfo: [NSLocalizedDescriptionKey: PlayerPresenceError.sessionMissing.localizedDescription]
                    )
                    return nil
                }

                var session: GameSession
                do {
                    session = try self.dictionaryToSession(raw, id: sessionId)
                } catch {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -41,
                        userInfo: [NSLocalizedDescriptionKey: PlayerPresenceError.decodeFailed.localizedDescription]
                    )
                    return nil
                }

                guard let index = session.players.firstIndex(where: { $0.id == player.id }) else {
                    errorPointer?.pointee = NSError(
                        domain: "FirestoreService",
                        code: -42,
                        userInfo: [NSLocalizedDescriptionKey: PlayerPresenceError.playerMissing.localizedDescription]
                    )
                    return nil
                }

                session.players[index].lastUpdated = player.lastUpdated
                if includeCoordinates {
                    session.players[index].latitude = player.latitude
                    session.players[index].longitude = player.longitude
                }

                do {
                    transaction.updateData(
                        [
                            "players": try self.encodeToFirestoreValue(session.players)
                        ],
                        forDocument: sessionRef
                    )
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }

                return true
            }) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }
    
    // MARK: - Listen to Session Changes
    
    func listenToSession(
        _ sessionId: String,
        completion: @escaping (GameSession?) -> Void,
        onDecodeError: ((Error) -> Void)? = nil,
        onListenError: ((Error) -> Void)? = nil
    ) {
        // Remove existing listener if any
        stopListening()

        let sessionRef = db.collection("sessions").document(sessionId)

        listener = sessionRef.addSnapshotListener { documentSnapshot, error in
            if let error {
                self.print("❌ Error fetching session: \(error.localizedDescription)")
                onListenError?(error)
                return
            }

            guard let document = documentSnapshot else {
                self.print("❌ Error fetching session: unknown")
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
                // Surface decode errors separately so callers can treat a
                // schema mismatch differently from a deletion. Falling
                // back to completion(nil) would make the host clear its
                // resume snapshot on a transient decode error.
                self.print("❌ Error decoding session: \(error)")
                onDecodeError?(error)
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
