import XCTest

final class SlateUITests: XCTestCase {
    @MainActor
    func testCountersLockAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForButton(app.buttons["take-plus"])

        let lock = app.buttons["slate-lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        if lock.label == "Unlock slate" { lock.doubleTap() }
        let take = app.staticTexts["number-take"]
        let before = Int(take.value as? String ?? "")!
        app.buttons["take-plus"].tap()
        XCTAssertEqual(take.value as? String, String(before + 1))
        app.buttons["take-minus"].tap()
        XCTAssertEqual(take.value as? String, String(before))

        let shot = app.staticTexts["number-shot"]
        let shotBefore = shot.value as! String
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
        let shotIndex = alphabet.firstIndex(of: shotBefore)!
        let shotStep = shotIndex == 25 ? -1 : 1
        app.buttons[shotStep == 1 ? "shot-plus" : "shot-minus"].tap()
        let changedShot = alphabet[shotIndex + shotStep]
        XCTAssertEqual(shot.value as? String, changedShot)

        lock.tap()
        XCTAssertTrue(app.buttons["take-plus"].isEnabled)
        let hint = app.staticTexts["Double-tap to lock"]
        XCTAssertTrue(hint.exists)
        lock.doubleTap()
        XCTAssertFalse(app.buttons["take-plus"].isEnabled)
        XCTAssertFalse(app.buttons["scene-minus"].isEnabled)
        XCTAssertFalse(app.buttons["shot-plus"].isEnabled)
        XCTAssertFalse(app.buttons["shot-minus"].isEnabled)
        let slateSound = app.buttons["slate-clap"]
        XCTAssertTrue(slateSound.isEnabled)

        let clock = app.staticTexts["timecode"]
        let firstTime = clock.value as? String
        XCTAssertNotNil(firstTime)
        let clockChanges = NSPredicate { _, _ in
            (clock.value as? String) != firstTime
        }
        expectation(for: clockChanges, evaluatedWith: nil)
        waitForExpectations(timeout: 3)

        let locked = XCTAttachment(screenshot: app.screenshot())
        locked.name = "Slate — landscape locked"
        locked.lifetime = .keepAlways
        add(locked)

        app.terminate()
        app.launch()
        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        XCTAssertEqual(take.value as? String, String(before))
        XCTAssertEqual(shot.value as? String, changedShot)
        XCTAssertFalse(app.buttons["take-plus"].isEnabled)
        lock.doubleTap()
        XCTAssertTrue(app.buttons["take-plus"].isEnabled)

        app.buttons["slate-settings"].tap()
        XCTAssertTrue(app.navigationBars["Slate Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Clap"].exists)
        XCTAssertTrue(app.staticTexts["Beep"].exists)
        app.staticTexts["Beep"].tap()
        app.buttons["Done"].tap()
        XCTAssertEqual(slateSound.label, "Play beep slate sound")

        XCUIDevice.shared.orientation = .portrait
        waitForButton(app.buttons["scene-plus"])
        XCTAssertTrue(app.buttons[shotStep == 1 ? "shot-minus" : "shot-plus"].isHittable)
        let portrait = XCTAttachment(screenshot: app.screenshot())
        portrait.name = "Slate — portrait"
        portrait.lifetime = .keepAlways
        add(portrait)
        app.buttons[shotStep == 1 ? "shot-minus" : "shot-plus"].tap()
        XCTAssertEqual(shot.value as? String, shotBefore)
        app.buttons["slate-settings"].tap()
        XCTAssertTrue(app.navigationBars["Slate Settings"].waitForExistence(timeout: 5))
        app.staticTexts["Clap"].tap()
        app.staticTexts["24 fps"].tap()
        app.buttons["Done"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
    }

    @MainActor
    private func waitForButton(_ button: XCUIElement) {
        let ready = NSPredicate(format: "hittable == true")
        let wait = XCTNSPredicateExpectation(predicate: ready, object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed)
    }
}
