//
//  LobbyRosterMerge.swift
//  Touch-Grass
//
//  Pure helpers that ground every lobby write on the authoritative
//  server roster instead of a possibly-stale local copy. The flip
//  button bug (host writes a 1-player session after a join landed in
//  Firestore but before the listener applied it) is fixed by always
//  starting from the server snapshot and only adopting per-player
//  field changes from the caller's mutation.
//

import Foundation

enum LobbyRosterMerge {
    /// Merge two roster arrays.
    ///
    /// - Parameters:
    ///   - server: roster as currently stored in Firestore.
    ///   - mutated: roster after applying the caller's intended changes
    ///     (role flip, team change, flag toggle, etc.) on top of whatever
    ///     local state the caller had.
    /// - Returns: a new roster that starts from `server` (so no one is
    ///   accidentally dropped because the local copy was stale) and
    ///   adopts the per-player field changes from `mutated` for every
    ///   matching `id`.
    ///
    /// Players present in `server` but missing from `mutated` are kept
    /// untouched. Players present in `mutated` but missing from
    /// `server` are appended (covers the rare case where the caller is
    /// the one adding a new player; lobby mutators do not normally do
    /// this, but tests cover it explicitly).
    static func merge(server: [Player], mutated: [Player]) -> [Player] {
        let mutatedById = Dictionary(uniqueKeysWithValues: mutated.map { ($0.id, $0) })
        var result: [Player] = []
        result.reserveCapacity(server.count)
        var consumedMutatedIds = Set<String>()

        for serverPlayer in server {
            if let updated = mutatedById[serverPlayer.id] {
                result.append(updated)
                consumedMutatedIds.insert(updated.id)
            } else {
                result.append(serverPlayer)
            }
        }

        for mutatedPlayer in mutated where !consumedMutatedIds.contains(mutatedPlayer.id) {
            result.append(mutatedPlayer)
        }

        return result
    }
}
