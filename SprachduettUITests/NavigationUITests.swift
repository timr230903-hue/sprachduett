import XCTest

final class NavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testRoundHasAWayBackToHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let play = app.buttons["play-together"]
        XCTAssertTrue(play.waitForExistence(timeout: 10), "Start zeigt Zusammen spielen")
        play.tap()

        let close = app.buttons["close-screen"]
        XCTAssertTrue(close.waitForExistence(timeout: 10), "Die Runde hat Zurück")
        close.tap()

        let alert = app.alerts["Runde pausieren?"]
        if alert.waitForExistence(timeout: 3) {
            alert.buttons["Pausieren"].tap()
        }

        XCTAssertTrue(app.buttons["play-resume"].waitForExistence(timeout: 8), "Die pausierte Runde lässt sich fortsetzen")
    }

    func testSettingsClosesBackToHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let profile = app.tabBars.buttons["Profil"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.tap()
        app.tabBars.buttons["Lernen"].tap()
        XCTAssertTrue(app.buttons["play-together"].waitForExistence(timeout: 5))
    }
}
