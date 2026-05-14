//
//  MarketingScreenshotUITests.swift
//  Touch-GrassUITests
//
//  Captures live iOS Simulator screenshots of every marketing scenario by
//  launching the app with the matching `-ScreenshotScenario` argument and
//  waiting on the accessibility identifier that `ScreenshotScenarioRootView`
//  publishes. Each captured screenshot is attached to the test result so
//  the `Scripts/capture_marketing_screenshots.sh` exporter can pull it into
//  `DesignSystem/project/marketing/assets/screenshots/`.
//

import XCTest

final class MarketingScreenshotUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Tests

    @MainActor
    func testCaptureGameSelection() throws {
        try capture(scenarioRawValue: "gameSelection", attachmentName: "gameSelection")
    }

    @MainActor
    func testCaptureCTFLobby() throws {
        // Lobby sits under the status bar; Simulator may show a system tip
        // (e.g. Apple Intelligence). We try taps + upward flicks, then wait
        // before capture so marketing PNGs stay clean.
        try capture(
            scenarioRawValue: "ctfLobby",
            attachmentName: "ctfLobby",
            settleDelay: 1.5,
            dismissSystemTipBanner: true,
            extraSettleAfterDismiss: 4.0
        )
    }

    @MainActor
    func testCaptureCTFActive() throws {
        try capture(scenarioRawValue: "ctfActive",
                    attachmentName: "ctfActive",
                    settleDelay: 2.5)
    }

    @MainActor
    func testCaptureZombieActive() throws {
        try capture(scenarioRawValue: "zombieActive",
                    attachmentName: "zombieActive",
                    settleDelay: 2.5)
    }

    @MainActor
    func testCaptureManhuntActive() throws {
        try capture(scenarioRawValue: "manhuntActive",
                    attachmentName: "manhuntActive",
                    settleDelay: 2.5)
    }

    @MainActor
    func testCaptureResultsShare() throws {
        try capture(scenarioRawValue: "resultsShare",
                    attachmentName: "resultsShare",
                    settleDelay: 1.0)
    }

    // MARK: - Helper

    /// Launches the app with the screenshot scenario argument, waits for the
    /// scenario root view to publish its accessibility identifier, and then
    /// captures a screenshot attached with `keepAlways` so the exporter
    /// script can pull it out of the `.xcresult` bundle.
    @MainActor
    private func capture(scenarioRawValue: String,
                         attachmentName: String,
                         settleDelay: TimeInterval = 0.75,
                         dismissSystemTipBanner: Bool = false,
                         extraSettleAfterDismiss: TimeInterval = 0,
                         file: StaticString = #filePath,
                         line: UInt = #line) throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ScreenshotScenario", scenarioRawValue]
        app.launch()

        let readyIdentifier = "screenshot-ready-\(scenarioRawValue)"
        let ready = app.descendants(matching: .any)
            .matching(identifier: readyIdentifier)
            .firstMatch

        XCTAssertTrue(
            ready.waitForExistence(timeout: 30),
            "Screenshot scenario \(scenarioRawValue) never reported ready",
            file: file,
            line: line
        )

        // Give the SwiftUI hierarchy a moment to finish initial animations,
        // load any map tiles, and settle before we capture.
        if settleDelay > 0 {
            Thread.sleep(forTimeInterval: settleDelay)
        }

        if dismissSystemTipBanner {
            swipeUpOnPossibleSimulatorTipBanner(in: app)
        }
        if extraSettleAfterDismiss > 0 {
            Thread.sleep(forTimeInterval: extraSettleAfterDismiss)
        }

        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Best-effort: dismiss Simulator / system banners that overlap the top of
    /// the app (e.g. “Ready for Apple Intelligence”). Tries common dismiss
    /// labels first, then several short upward drags across the banner strip.
    @MainActor
    private func swipeUpOnPossibleSimulatorTipBanner(in app: XCUIApplication) {
        guard app.wait(for: .runningForeground, timeout: 2) else { return }

        let dismissLabels = [
            "Not Now", "Close", "Dismiss", "Maybe Later", "Skip", "Remind Me Later",
            "Not Interested", "Ignore", "No Thanks"
        ]
        for label in dismissLabels {
            let btn = app.buttons[label]
            if btn.waitForExistence(timeout: 0.35), btn.isHittable {
                btn.tap()
                Thread.sleep(forTimeInterval: 0.5)
                return
            }
        }

        // Upward flicks from the status-bar / banner band (normalized y is top = 0).
        let swipes: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.5, 0.10, 0.5, 0.02),
            (0.35, 0.09, 0.35, 0.02),
            (0.65, 0.09, 0.65, 0.02),
            (0.5, 0.12, 0.5, 0.03)
        ]
        for (sx, sy, ex, ey) in swipes {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: sx, dy: sy))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: ex, dy: ey))
            start.press(forDuration: 0.05, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.25)
        }
    }
}
