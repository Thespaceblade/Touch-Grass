//
//  LobbyRosterMergeTests.swift
//  Touch-GrassTests
//
//  Pure unit tests for the read-merge-write roster helper that fixes
//  the lobby flip-button wipe.
//

import XCTest
@testable import Touch_Grass

final class LobbyRosterMergeTests: XCTestCase {

    private func makePlayer(
        id: String,
        name: String,
        role: PlayerRole = .hider,
        isAlive: Bool = true
    ) -> Player {
        Player(
            id: id,
            displayName: name,
            role: role,
            isAlive: isAlive,
            authUserId: "auth-\(id)",
            deviceInstallationId: id
        )
    }

    func testMergePreservesServerPlayersWhenLocalStale() {
        let host = makePlayer(id: "host", name: "Host", role: .hunter)
        let joiner = makePlayer(id: "joiner", name: "Joiner", role: .hider)

        // Server already has both players (the join landed in Firestore).
        let server = [host, joiner]
        // Local copy on the host is stale - only knows about the host.
        // Caller mutated the host's role from .hunter to .hider.
        var mutatedHost = host
        mutatedHost.role = .hider
        let mutated = [mutatedHost]

        let result = LobbyRosterMerge.merge(server: server, mutated: mutated)

        XCTAssertEqual(result.count, 2, "Joiner must not be dropped when local was stale")
        XCTAssertEqual(result.first?.id, "host")
        XCTAssertEqual(result.first?.role, .hider, "Host role change is applied from mutation")
        XCTAssertEqual(result.last?.id, "joiner", "Joiner survives merge")
        XCTAssertEqual(result.last?.role, .hider, "Joiner role from server is preserved")
    }

    func testServerPlayerNotDroppedWhenLocalHadOne() {
        // Regression: the flip wipe scenario.
        // Server has [host, joiner]. Host taps flip with local list = [host].
        // Without merge, setHunter would push [host] back to Firestore
        // and delete the joiner.
        let host = makePlayer(id: "host", name: "Host", role: .hunter)
        let joiner = makePlayer(id: "joiner", name: "Joiner", role: .hider)
        let server = [host, joiner]

        var mutatedHost = host
        mutatedHost.role = .hider
        let mutated = [mutatedHost]

        let result = LobbyRosterMerge.merge(server: server, mutated: mutated)

        XCTAssertEqual(result.map(\.id), ["host", "joiner"])
        XCTAssertEqual(result[0].role, .hider)
        XCTAssertEqual(result[1].role, .hider)
    }

    func testMergeAppliesMutationsToMultiplePlayers() {
        let host = makePlayer(id: "host", name: "Host", role: .hunter)
        let p1 = makePlayer(id: "a", name: "A", role: .hider)
        let p2 = makePlayer(id: "b", name: "B", role: .hider)
        let server = [host, p1, p2]

        var mutatedHost = host
        mutatedHost.role = .hider
        var mutatedP1 = p1
        mutatedP1.role = .hunter
        let mutated = [mutatedHost, mutatedP1, p2]

        let result = LobbyRosterMerge.merge(server: server, mutated: mutated)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result.first(where: { $0.id == "host" })?.role, .hider)
        XCTAssertEqual(result.first(where: { $0.id == "a" })?.role, .hunter)
        XCTAssertEqual(result.first(where: { $0.id == "b" })?.role, .hider)
    }

    func testMergeAppendsBrandNewMutatedPlayers() {
        // Caller is intentionally adding a new player. Lobby mutators
        // do not normally do this, but the merge must not silently
        // drop them either.
        let host = makePlayer(id: "host", name: "Host", role: .hunter)
        let newPlayer = makePlayer(id: "fresh", name: "Fresh")
        let server = [host]
        let mutated = [host, newPlayer]

        let result = LobbyRosterMerge.merge(server: server, mutated: mutated)

        XCTAssertEqual(result.map(\.id), ["host", "fresh"])
    }

    func testMergeKeepsServerPlayerNotInMutated() {
        // If the local copy never had a player that the server knows
        // about, keep the server's copy verbatim.
        let host = makePlayer(id: "host", name: "Host", role: .hunter)
        let ghost = makePlayer(id: "ghost", name: "Ghost", role: .hider)
        let server = [host, ghost]
        let mutated = [host]

        let result = LobbyRosterMerge.merge(server: server, mutated: mutated)

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.last?.id, "ghost")
    }

    func testMergePreservesServerOrder() {
        let a = makePlayer(id: "a", name: "A")
        let b = makePlayer(id: "b", name: "B")
        let c = makePlayer(id: "c", name: "C")
        let server = [a, b, c]
        // Caller has rearranged the local copy.
        let mutated = [c, a]

        let result = LobbyRosterMerge.merge(server: server, mutated: mutated)

        XCTAssertEqual(result.map(\.id), ["a", "b", "c"], "Server roster ordering wins")
    }
}
