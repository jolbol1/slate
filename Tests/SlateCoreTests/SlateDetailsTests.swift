import Foundation
import XCTest
@testable import SlateCore

final class SlateDetailsTests: XCTestCase {
    private func withStore(_ body: (SlateStore, UserDefaults) -> Void) {
        let name = "SlateDetailsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(SlateStore(defaults: defaults), defaults)
    }

    func testDefaultsAreEmptyCameraAInteriorDaySync() {
        withStore { slate, _ in
            let details = slate.details
            XCTAssertTrue(details.isEmpty)
            for field in SlateTextField.allCases { XCTAssertEqual(details[field], "") }
            XCTAssertEqual(details.cameraLetter, "A")
            XCTAssertEqual(details.location, .interior)
            XCTAssertEqual(details.timeOfDay, .day)
            XCTAssertEqual(details.soundMode, .sync)
        }
    }

    func testDetailsPersistAcrossRelaunch() {
        withStore { slate, defaults in
            slate.setText("Night Train", for: .production)
            slate.setText("Ada Lovelace", for: .director)
            slate.setText("Sam Fox", for: .cameraOperator)
            slate.setText("A007", for: .roll)
            slate.setText("S003", for: .soundRoll)
            slate.setText("ND 0.9", for: .filter)
            slate.setText("Pick-up", for: .notes)
            slate.cycleCamera()
            slate.setLocation(.exterior)
            slate.setTimeOfDay(.night)
            slate.setSoundMode(.mos)

            let reopened = SlateStore(defaults: defaults).details
            XCTAssertEqual(reopened.production, "Night Train")
            XCTAssertEqual(reopened.director, "Ada Lovelace")
            XCTAssertEqual(reopened.cameraOperator, "Sam Fox")
            XCTAssertEqual(reopened.roll, "A007")
            XCTAssertEqual(reopened.soundRoll, "S003")
            XCTAssertEqual(reopened.filter, "ND 0.9")
            XCTAssertEqual(reopened.notes, "Pick-up")
            XCTAssertEqual(reopened.cameraLetter, "B")
            XCTAssertEqual(reopened.location, .exterior)
            XCTAssertEqual(reopened.timeOfDay, .night)
            XCTAssertEqual(reopened.soundMode, .mos)
        }
    }

    func testOldSaveWithoutDetailsKeepsCountersAndOpensEmptyDetails() {
        withStore { _, defaults in
            defaults.set(Data(#"{"scene":7,"shot":3,"take":12,"isLocked":true}"#.utf8), forKey: "slate.state.v1")
            let reopened = SlateStore(defaults: defaults)
            XCTAssertEqual(SlateCounter.allCases.map(reopened.displayValue), ["7", "C", "12"])
            XCTAssertTrue(reopened.isLocked)
            XCTAssertTrue(reopened.details.isEmpty)
        }
    }

    func testInvalidSavedDetailsFallBackPerField() {
        withStore { _, defaults in
            let json = #"{"scene":2,"shot":1,"take":1,"isLocked":false,"details":{"production":"Keep me","camera":99,"location":"space","soundMode":"mos","roll":"ABCDEFGHIJKLMNOP"}}"#
            defaults.set(Data(json.utf8), forKey: "slate.state.v1")
            let details = SlateStore(defaults: defaults).details
            XCTAssertEqual(details.production, "Keep me")
            XCTAssertEqual(details.cameraLetter, "Z")
            XCTAssertEqual(details.location, .interior)
            XCTAssertEqual(details.soundMode, .mos)
            XCTAssertEqual(details.roll, "ABCDEFGH")
        }
    }

    func testTextIsLimitedToFieldLength() {
        withStore { slate, _ in
            slate.setText(String(repeating: "x", count: 100), for: .notes)
            XCTAssertEqual(slate.details.notes.count, SlateTextField.notes.maxLength)
            slate.setText("A0011234", for: .roll)
            XCTAssertEqual(slate.details.roll, "A0011234")
        }
    }

    func testCameraCyclesAThroughZAndSetterClamps() {
        withStore { slate, _ in
            var seen = ""
            for _ in 0..<27 {
                seen += slate.details.cameraLetter
                slate.cycleCamera()
            }
            XCTAssertEqual(seen, "ABCDEFGHIJKLMNOPQRSTUVWXYZA")
            slate.setCamera(-4)
            XCTAssertEqual(slate.details.cameraLetter, "A")
            slate.setCamera(40)
            XCTAssertEqual(slate.details.cameraLetter, "Z")
            slate.setCamera(7)
            XCTAssertEqual(slate.details.cameraLetter, "H")
        }
    }

    func testLockBlocksDetailEditsResetsAndClear() {
        withStore { slate, defaults in
            slate.setText("Before", for: .production)
            slate.change(.take, by: 1)
            slate.activateAccessibleLock()
            slate.setText("After", for: .production)
            slate.cycleCamera()
            slate.setSoundMode(.mos)
            slate.resetTake()
            slate.resetCounters()
            slate.clearDetails()
            let reopened = SlateStore(defaults: defaults)
            XCTAssertEqual(reopened.details.production, "Before")
            XCTAssertEqual(reopened.details.cameraLetter, "A")
            XCTAssertEqual(reopened.details.soundMode, .sync)
            XCTAssertEqual(reopened.value(for: .take), 2)
        }
    }

    func testResetTakeResetCountersAndClearDetails() {
        withStore { slate, defaults in
            slate.change(.scene, by: 1)
            slate.change(.shot, by: 1)
            slate.change(.take, by: 1)
            slate.change(.take, by: 1)
            slate.resetTake()
            XCTAssertEqual(SlateCounter.allCases.map(slate.displayValue), ["2", "B", "1"])
            slate.resetCounters()
            XCTAssertEqual(SlateCounter.allCases.map(slate.displayValue), ["1", "A", "1"])

            slate.setText("Gone", for: .director)
            slate.setTimeOfDay(.night)
            slate.clearDetails()
            XCTAssertTrue(slate.details.isEmpty)
            XCTAssertTrue(SlateStore(defaults: defaults).details.isEmpty)
        }
    }
}
