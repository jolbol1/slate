import XCTest

final class SlateUITests: XCTestCase {
    /// Landscape: counters, chips, the details editor, lock, relaunch and the settings sheet.
    /// Ends with the slate locked, so a launch after this test shows the locked state.
    @MainActor
    func testSlateFieldsCountersLockAndRelaunch() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--reset-state"]
        app.launch()
        XCUIDevice.shared.orientation = .landscapeLeft
        waitForButton(app.buttons["take-plus"])

        // Counters: fresh slate is Scene 1, Shot A, Take 1 and Take resets on a new scene or shot.
        let scene = app.staticTexts["number-scene"]
        let shot = app.staticTexts["number-shot"]
        let take = app.staticTexts["number-take"]
        XCTAssertEqual([scene, shot, take].map { $0.value as? String }, ["1", "A", "1"])
        app.buttons["take-plus"].tap()
        app.buttons["take-plus"].tap()
        XCTAssertEqual(take.value as? String, "3")
        app.buttons["scene-plus"].tap()
        XCTAssertEqual(scene.value as? String, "2")
        XCTAssertEqual(take.value as? String, "1")
        app.buttons["take-plus"].tap()
        app.buttons["shot-plus"].tap()
        XCTAssertEqual(shot.value as? String, "B")
        XCTAssertEqual(take.value as? String, "1")
        app.buttons["take-plus"].tap()
        app.buttons["take-plus"].tap()
        app.buttons["take-minus"].tap()
        XCTAssertEqual(take.value as? String, "2")

        // Chips toggle in place.
        app.buttons["chip-location"].tap()
        app.buttons["chip-time"].tap()
        app.buttons["chip-sound"].tap()
        app.buttons["chip-camera"].tap()
        XCTAssertEqual(app.buttons["chip-location"].value as? String, "EXT")
        XCTAssertEqual(app.buttons["chip-time"].value as? String, "NIGHT")
        XCTAssertEqual(app.buttons["chip-sound"].value as? String, "MOS")
        XCTAssertEqual(app.buttons["chip-camera"].value as? String, "B")

        // Written details come from the editor sheet, which opens on the tapped line.
        app.buttons["slate-production"].tap()
        XCTAssertTrue(app.navigationBars["Slate Details"].waitForExistence(timeout: 5))
        // Production is focused on open. The keyboard's Next key walks the lines in slate order,
        // and the form scrolls each focused line clear of the keyboard.
        let lines: [(String, String)] = [
            ("production", "Night Train"), ("director", "Ada Lovelace"), ("cameraOperator", "Sam Fox"),
            ("roll", "A001"), ("filter", "ND 0.6"), ("soundRoll", "S001"), ("notes", "Pick-up of the stairs")
        ]
        for (index, (field, text)) in lines.enumerated() {
            let textField = app.textFields["text-\(field)"]
            XCTAssertTrue(textField.waitForExistence(timeout: 5))
            if index > 0 {
                let nextKeys = app.keyboards.buttons.matching(NSPredicate(format: "label ==[c] 'next'"))
                if nextKeys.count > 0 { nextKeys.element(boundBy: 0).tap() } else { app.typeText("\n") }
            }
            let focused = NSPredicate { _, _ in (textField.value(forKey: "hasKeyboardFocus") as? Bool) == true }
            expectation(for: focused, evaluatedWith: nil)
            waitForExpectations(timeout: 3)
            app.typeText(text)
        }
        let notes = app.textFields["text-notes"]
        XCTAssertEqual(app.textFields["text-roll"].value as? String, "A001")
        XCTAssertEqual(notes.value as? String, "Pick-up of the stairs")
        app.navigationBars["Slate Details"].buttons["Done"].tap()
        XCTAssertEqual(app.buttons["slate-production"].value as? String, "Night Train")
        // The written lines and the lock hint are hidden in the short iPhone landscape layout.
        let fullLayout = app.buttons["field-director"].exists
        if fullLayout {
            XCTAssertEqual(app.buttons["field-director"].value as? String, "Ada Lovelace")
            XCTAssertEqual(app.buttons["field-cameraOperator"].value as? String, "Sam Fox")
            XCTAssertEqual(app.buttons["field-filter"].value as? String, "ND 0.6")
        }
        XCTAssertEqual(app.buttons["chip-roll"].value as? String, "A001")
        XCTAssertEqual(app.buttons["chip-sound-roll"].value as? String, "S001")

        // Lock needs a double-tap; the clap still works while locked.
        let lock = app.buttons["slate-lock"]
        lock.tap()
        XCTAssertTrue(app.buttons["take-plus"].isEnabled)
        if fullLayout { XCTAssertTrue(app.staticTexts["Double-tap to lock"].exists) }
        lock.doubleTap()
        XCTAssertFalse(app.buttons["take-plus"].isEnabled)
        XCTAssertFalse(app.buttons["scene-minus"].isEnabled)
        XCTAssertFalse(app.buttons["shot-plus"].isEnabled)
        XCTAssertFalse(app.buttons["chip-location"].isEnabled)
        XCTAssertFalse(app.buttons["slate-production"].isEnabled)
        let slateSound = app.buttons["slate-clap"]
        XCTAssertTrue(slateSound.isEnabled)
        slateSound.tap()

        let clock = app.staticTexts["timecode"]
        let firstTime = clock.value as? String
        XCTAssertNotNil(firstTime)
        expectation(for: NSPredicate { _, _ in (clock.value as? String) != firstTime }, evaluatedWith: nil)
        waitForExpectations(timeout: 3)

        // Everything survives a relaunch.
        app.launchArguments = []
        app.terminate()
        app.launch()
        XCTAssertTrue(lock.waitForExistence(timeout: 10))
        XCTAssertEqual([scene, shot, take].map { $0.value as? String }, ["2", "B", "2"])
        XCTAssertEqual(app.buttons["slate-production"].value as? String, "Night Train")
        XCTAssertEqual(app.buttons["chip-roll"].value as? String, "A001")
        XCTAssertEqual(app.buttons["chip-sound"].value as? String, "MOS")
        XCTAssertFalse(app.buttons["take-plus"].isEnabled)
        lock.doubleTap()
        XCTAssertTrue(app.buttons["take-plus"].isEnabled)

        // Settings: sound and frame rate show on the slate at once.
        app.buttons["slate-settings"].tap()
        XCTAssertTrue(app.navigationBars["Slate Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Clap"].exists)
        XCTAssertTrue(app.staticTexts["Beep"].exists)
        app.staticTexts["Beep"].tap()
        app.staticTexts["25 fps"].tap()
        app.navigationBars["Slate Settings"].buttons["Done"].tap()
        XCTAssertEqual(slateSound.label, "Play beep slate sound")
        XCTAssertEqual(app.buttons["chip-fps"].value as? String, "25")

        // Frame rate is also one tap away on the slate.
        app.buttons["chip-fps"].tap()
        app.buttons["24 fps"].tap()
        XCTAssertEqual(app.buttons["chip-fps"].value as? String, "24")

        lock.doubleTap()
        XCTAssertFalse(app.buttons["take-plus"].isEnabled)
    }

    /// Portrait: the stacked layout, the sheets, and the settings that change the take counter.
    /// Leaves the simulator in portrait and the slate unlocked.
    @MainActor
    func testPortraitLayoutSheetsAndTakeSettings() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCUIDevice.shared.orientation = .portrait
        waitForButton(app.buttons["scene-plus"])
        let lock = app.buttons["slate-lock"]
        if lock.label == "Unlock slate" { lock.doubleTap() }
        XCTAssertTrue(app.buttons["shot-minus"].isHittable)
        XCTAssertTrue(app.buttons["slate-clap"].isHittable)
        XCTAssertTrue(app.staticTexts["timecode"].exists)

        app.buttons["slate-production"].tap()
        XCTAssertTrue(app.navigationBars["Slate Details"].waitForExistence(timeout: 5))
        snapshot(app, "details-sheet")
        app.navigationBars["Slate Details"].buttons["Done"].tap()

        // Turn off the automatic take reset, then Shot changes keep Take.
        app.buttons["slate-settings"].tap()
        XCTAssertTrue(app.navigationBars["Slate Settings"].waitForExistence(timeout: 5))
        snapshot(app, "settings-sheet")
        app.staticTexts["Clap"].tap()
        let resetSwitch = app.switches["reset-take-switch"]
        if (resetSwitch.value as? String) == "1" { resetSwitch.tap() }
        app.navigationBars["Slate Settings"].buttons["Done"].tap()

        let shot = app.staticTexts["number-shot"]
        let take = app.staticTexts["number-take"]
        let takeBefore = take.value as? String
        let shotBefore = shot.value as? String
        app.buttons[shotBefore == "Z" ? "shot-minus" : "shot-plus"].tap()
        XCTAssertNotEqual(shot.value as? String, shotBefore)
        XCTAssertEqual(take.value as? String, takeBefore)

        app.buttons["slate-settings"].tap()
        XCTAssertTrue(app.navigationBars["Slate Settings"].waitForExistence(timeout: 5))
        app.switches["reset-take-switch"].tap()
        app.navigationBars["Slate Settings"].buttons["Done"].tap()
        snapshot(app, "portrait")
    }

    @MainActor
    private func waitForButton(_ button: XCUIElement) {
        let ready = NSPredicate(format: "hittable == true")
        let wait = XCTNSPredicateExpectation(predicate: ready, object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [wait], timeout: 5), .completed)
    }

    /// Attaches a named screenshot to the result bundle.
    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
