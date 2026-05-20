//
//  JoinCodeErrorTests.swift
//  Touch-GrassTests
//
//  Covers the mapping helper that converts raw `GameService.joinGame`
//  error strings into inline `JoinCodeError` cases. The lobby falls back
//  to a toast when the helper returns `nil`, so we exercise both branches.
//

import XCTest
@testable import Touch_Grass

final class JoinCodeErrorTests: XCTestCase {

    func testInvalidFormatMapsInline() {
        let result = JoinCodeError.from(gameServiceMessage: "Invalid join code format. Please enter a 6-digit code.")
        XCTAssertEqual(result, .invalidFormat)
    }

    func testNoSessionFoundMapsInline() {
        let result = JoinCodeError.from(gameServiceMessage: "No session found with that join code.")
        XCTAssertEqual(result, .sessionNotFound)
    }

    func testAlreadyStartedMapsInline() {
        let result = JoinCodeError.from(gameServiceMessage: "This game has already started. Ask the host for a new lobby.")
        XCTAssertEqual(result, .alreadyStarted)
    }

    func testWrongGameTypeMapsToSpecificGameType() {
        let message = "This join code is for Manhunt, but you're trying to join from Zombie Tag. Please select the correct game type."
        let result = JoinCodeError.from(gameServiceMessage: message)
        XCTAssertEqual(result, .wrongGameType(.manhunt))
    }

    func testNotPartOfSessionMapsToNotFound() {
        let result = JoinCodeError.from(gameServiceMessage: "You are not part of this session. Please join with the join code.")
        XCTAssertEqual(result, .sessionNotFound)
    }

    func testGenericCouldNotJoinMapsToNotFound() {
        let result = JoinCodeError.from(gameServiceMessage: "Could not join game. Make sure the join code is correct and the game hasn't started yet.")
        XCTAssertEqual(result, .sessionNotFound)
    }

    func testSituationalFailuresReturnNil() {
        // Sign-in failures and GPS warm-up should fall through to toast.
        XCTAssertNil(JoinCodeError.from(gameServiceMessage: "Sign-in failed. Check your connection and try again."))
        XCTAssertNil(JoinCodeError.from(gameServiceMessage: "GPS has not found you yet. Move somewhere with a clearer signal and try again."))
    }

    func testCaptionsAreNonEmpty() {
        XCTAssertFalse(JoinCodeError.invalidFormat.caption.isEmpty)
        XCTAssertFalse(JoinCodeError.sessionNotFound.caption.isEmpty)
        XCTAssertFalse(JoinCodeError.alreadyStarted.caption.isEmpty)
        XCTAssertFalse(JoinCodeError.wrongGameType(.captureTheFlag).caption.isEmpty)
        XCTAssertFalse(JoinCodeError.other("hi").caption.isEmpty)
    }
}
