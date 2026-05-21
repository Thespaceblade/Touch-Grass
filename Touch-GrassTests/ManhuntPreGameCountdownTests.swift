//
//  ManhuntPreGameCountdownTests.swift
//  Touch-GrassTests
//

import XCTest
@testable import Touch_Grass

@MainActor
final class ManhuntPreGameCountdownTests: XCTestCase {

    func testEndImmediatelyInvokesOnCompleteAndClearsGoScreen() {
        let model = ManhuntPreGameCountdownModel()
        var completed = false

        model.start {
            completed = true
        }

        model.endImmediatelyForTesting()

        XCTAssertTrue(completed)
        XCTAssertFalse(model.showGoScreen)
    }

    func testStopDoesNotInvokeOnComplete() {
        let model = ManhuntPreGameCountdownModel()
        var completed = false

        model.start {
            completed = true
        }

        model.stop()

        XCTAssertFalse(completed)
        XCTAssertFalse(model.showGoScreen)
    }
}
