//
//  FirestoreService.swift
//  Touch-Grass
//
//  Created by Jason Charwin on 12/26/25.
//

import Foundation
import FirebaseFirestore
import Combine

@MainActor
final class FirestoreService: ObservableObject {
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    init() {
        // Configure date encoding/decoding for Firestore
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder.dateDecodingStrategy = .secondsSince1970
    }
    
    // MARK: - Helper Methods
    
    private func sessionToDictionary(_ session: GameSession) throws -> [String: Any] {
        let data = try encoder.encode(session)
        guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "FirestoreService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode session"])
        }
        return dict
    }
    
    private func dictionaryToSession(_ dict: [String: Any], id: String) throws -> GameSession {
        var mutableDict = dict
        // Ensure ID matches document ID (use document ID as source of truth)
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
        let decodedSession = try decoder.decode(GameSession.self, from: data)
        
        // Create new session with correct ID (since id is let constant)
        return GameSession(
            id: id,
            hostId: decodedSession.hostId,
            gameState: decodedSession.gameState,
            gameType: decodedSession.gameType,
            bubble: decodedSession.bubble,
            players: decodedSession.players,
            catchDistance: decodedSession.catchDistance,
            joinCode: decodedSession.joinCode,
            hunterCount: decodedSession.hunterCount,
            firstTaggedPlayerId: decodedSession.firstTaggedPlayerId,
            gameNumber: decodedSession.gameNumber,
            flags: decodedSession.flags,
            teamAScore: decodedSession.teamAScore,
            teamBScore: decodedSession.teamBScore,
            teamABase: decodedSession.teamABase,
            teamBBase: decodedSession.teamBBase,
            scoreLimit: decodedSession.scoreLimit
        )
    }
    
    // MARK: - Create Session
    
    func createSession(_ session: GameSession) async throws {
        let sessionRef = db.collection("sessions").document(session.id)
        let data = try sessionToDictionary(session)
        try await sessionRef.setData(data)
        print("✅ Session created in Firestore: \(session.id)")
    }
    
    // MARK: - Join Session by Code
    
    func findSessionByCode(_ joinCode: String) async throws -> GameSession? {
        let query = db.collection("sessions")
            .whereField("joinCode", isEqualTo: joinCode)
            .whereField("gameState", isEqualTo: "lobby")
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        let data = document.data()
        let session = try dictionaryToSession(data, id: document.documentID)
        return session
    }
    
    // Find session by code (including active games - for reconnection)
    func findSessionByCodeAnyState(_ joinCode: String) async throws -> GameSession? {
        let query = db.collection("sessions")
            .whereField("joinCode", isEqualTo: joinCode)
            .limit(to: 1)
        
        let snapshot = try await query.getDocuments()
        
        guard let document = snapshot.documents.first else {
            return nil
        }
        
        let data = document.data()
        let session = try dictionaryToSession(data, id: document.documentID)
        return session
    }
    
    // MARK: - Update Session
    
    func updateSession(_ session: GameSession) async throws {
        let sessionRef = db.collection("sessions").document(session.id)
        let data = try sessionToDictionary(session)
        try await sessionRef.setData(data, merge: true)
    }
    
    // MARK: - Listen to Session Changes
    
    func listenToSession(_ sessionId: String, completion: @escaping (GameSession?) -> Void) {
        // Remove existing listener if any
        stopListening()
        
        let sessionRef = db.collection("sessions").document(sessionId)
        
        listener = sessionRef.addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("❌ Error fetching session: \(error?.localizedDescription ?? "unknown")")
                completion(nil)
                return
            }
            
            guard document.exists else {
                print("❌ Document does not exist")
                completion(nil)
                return
            }
            
            do {
                let data = document.data() ?? [:]
                let session = try self.dictionaryToSession(data, id: document.documentID)
                completion(session)
            } catch {
                print("❌ Error decoding session: \(error)")
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
        try await sessionRef.delete()
        print("✅ Session deleted from Firestore: \(sessionId)")
    }
}
