//
//  GuestSessionStoreTests.swift
//  Touch-GrassTests
//
//  Unit tests for `GuestSessionStore` save / read / expiry / clear.
//

import XCTest
@testable import Touch_Grass

@MainActor
final class GuestSessionStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GuestSessionStore.shared.clear(reason: "test-setup")
    }

    override func tearDown() {
        GuestSessionStore.shared.clear(reason: "test-tearDown")
        super.tearDown()
    }

    private func makeSnapshot(
        sessionId: String = "sess-1",
        joinCode: String = "123456",
        gameType: GameType = .manhunt,
        localPlayerId: String = "gd-local",
        hostPlayerId: String = "gd-host",
        savedAt: Date = Date()
    ) -> GuestSessionSnapshot {
        GuestSessionSnapshot(
            sessionId: sessionId,
            joinCode: joinCode,
            gameType: gameType,
            localPlayerId: localPlayerId,
            hostPlayerId: hostPlayerId,
            savedAt: savedAt
        )
    }

    func testSaveAndRead() {
        let snapshot = makeSnapshot()
        GuestSessionStore.shared.save(snapshot, force: true)

        let restored = GuestSessionStore.shared.currentSnapshot()
        XCTAssertEqual(restored, snapshot)
    }

    func testClearRemovesSnapshot() {
        GuestSessionStore.shared.save(makeSnapshot(), force: true)
        GuestSessionStore.shared.clear(reason: "test")
        XCTAssertNil(GuestSessionStore.shared.currentSnapshot())
    }

    func testExpirySnapshotIsDropped() {
        let stale = makeSnapshot(savedAt: Date().addingTimeInterval(-25 * 60 * 60))
        GuestSessionStore.shared.save(stale, force: true)

        XCTAssertNil(
            GuestSessionStore.shared.currentSnapshot(),
            "Snapshots older than 24h should not be returned"
        )
    }

    func testSaveThrottleSkipsRapidRewrites() {
        let first = makeSnapshot(sessionId: "sess-1", localPlayerId: "gd-a")
        GuestSessionStore.shared.save(first, force: true)

        let second = makeSnapshot(sessionId: "sess-1", localPlayerId: "gd-b")
        // Throttled write to the same session id should not overwrite
        // within the throttle window, but a forced write must.
        GuestSessionStore.shared.save(second, force: false)
        XCTAssertEqual(GuestSessionStore.shared.currentSnapshot()?.localPlayerId, "gd-a")

        GuestSessionStore.shared.save(second, force: true)
        XCTAssertEqual(GuestSessionStore.shared.currentSnapshot()?.localPlayerId, "gd-b")
    }

    func testSaveDifferentSessionByPassesThrottle() {
        GuestSessionStore.shared.save(makeSnapshot(sessionId: "sess-1"), force: true)
        let next = makeSnapshot(sessionId: "sess-2")
        GuestSessionStore.shared.save(next, force: false)
        XCTAssertEqual(GuestSessionStore.shared.currentSnapshot()?.sessionId, "sess-2")
    }
}
