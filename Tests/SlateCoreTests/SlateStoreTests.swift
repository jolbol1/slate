import Foundation
import XCTest
@testable import SlateCore

final class SlateStoreTests: XCTestCase {
    @MainActor
    private func withStore(_ body: (SlateStore, UserDefaults) -> Void) {
        let name = "SlateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(SlateStore(defaults: defaults), defaults)
    }

    func testCountersAreIndependentAndSurviveRelaunch() async {
        await MainActor.run {
            withStore { slate, defaults in
                XCTAssertEqual(SlateCounter.allCases.map(slate.value), [1, 1, 1])
                slate.change(.scene, by: 1)
                slate.change(.shot, by: 1)
                slate.change(.take, by: 1)
                slate.change(.take, by: 1)
                let reopened = SlateStore(defaults: defaults)
                XCTAssertEqual(SlateCounter.allCases.map(reopened.displayValue), ["2", "B", "3"])
            }
        }
    }

    func testDoubleTapRequiredForLockAndUnlock() async {
        await MainActor.run {
            withStore { slate, defaults in
                XCTAssertFalse(slate.tapLock(at: 10))
                XCTAssertFalse(slate.isLocked)
                XCTAssertFalse(slate.tapLock(at: 11))
                XCTAssertTrue(slate.tapLock(at: 11.2))
                XCTAssertTrue(slate.isLocked)
                for counter in SlateCounter.allCases {
                    slate.change(counter, by: 1)
                    slate.change(counter, by: -1)
                    XCTAssertEqual(slate.value(for: counter), 1)
                    XCTAssertFalse(slate.canChange(counter, by: 1))
                }
                XCTAssertTrue(SlateStore(defaults: defaults).isLocked)
                XCTAssertFalse(slate.tapLock(at: 11.3)) // Third tap doesn't unlock.
                XCTAssertTrue(slate.isLocked)
                XCTAssertFalse(slate.tapLock(at: 12))
                XCTAssertTrue(slate.tapLock(at: 12.2))
                slate.change(.take, by: 1)
                XCTAssertEqual(slate.value(for: .take), 2)
                XCTAssertFalse(SlateStore(defaults: defaults).isLocked)
            }
        }
    }

    func testLockTapDoesNotCarryAcrossBackgrounding() async {
        await MainActor.run {
            withStore { slate, _ in
                slate.tapLock(at: 10)
                slate.cancelPendingLockTap()
                XCTAssertFalse(slate.tapLock(at: 10.2))
                XCTAssertFalse(slate.isLocked)
            }
        }
    }

    func testBoundsAndInvalidChanges() async {
        await MainActor.run {
            withStore { slate, defaults in
                slate.change(.take, by: -1)
                slate.change(.take, by: -1)
                XCTAssertEqual(slate.value(for: .take), 0)
                XCTAssertFalse(slate.canChange(.take, by: -1))
                slate.change(.scene, by: Int.max)
                XCTAssertEqual(slate.value(for: .scene), 1)
                defaults.set(Data(#"{"scene":9999,"shot":-10,"take":123456,"isLocked":false}"#.utf8), forKey: "slate.state.v1")
                let reopened = SlateStore(defaults: defaults)
                XCTAssertEqual(SlateCounter.allCases.map(reopened.displayValue), ["9999", "A", "9999"])
                reopened.change(.scene, by: 1)
                XCTAssertEqual(reopened.value(for: .scene), 9999)
            }
        }
    }

    func testMalformedSavedDataRecoversToDefaults() async {
        await MainActor.run {
            withStore { _, defaults in
                defaults.set(Data("invalid".utf8), forKey: "slate.state.v1")
                let reopened = SlateStore(defaults: defaults)
                XCTAssertEqual(SlateCounter.allCases.map(reopened.value), [1, 1, 1])
                XCTAssertFalse(reopened.isLocked)
            }
        }
    }

    func testAccessibleActivationAlsoPersistsLock() async {
        await MainActor.run {
            withStore { slate, defaults in
                slate.activateAccessibleLock()
                XCTAssertTrue(SlateStore(defaults: defaults).isLocked)
                slate.activateAccessibleLock()
                XCTAssertFalse(SlateStore(defaults: defaults).isLocked)
            }
        }
    }

    func testShotStepsThroughAlphabetAndStopsAtEnds() async {
        await MainActor.run {
            withStore { slate, defaults in
                XCTAssertEqual(slate.displayValue(for: .shot), "A")
                XCTAssertFalse(slate.canChange(.shot, by: -1))
                slate.change(.shot, by: -1)
                XCTAssertEqual(slate.displayValue(for: .shot), "A")
                for letter in "BCDEFGHIJKLMNOPQRSTUVWXYZ" {
                    slate.change(.shot, by: 1)
                    XCTAssertEqual(slate.displayValue(for: .shot), String(letter))
                }
                XCTAssertFalse(slate.canChange(.shot, by: 1))
                slate.change(.shot, by: 1)
                XCTAssertEqual(SlateStore(defaults: defaults).displayValue(for: .shot), "Z")
                slate.change(.shot, by: -1)
                XCTAssertEqual(SlateStore(defaults: defaults).displayValue(for: .shot), "Y")
                XCTAssertEqual(slate.displayValue(for: .scene), "1")
                XCTAssertEqual(slate.displayValue(for: .take), "1")
            }
        }
    }

    func testExistingNumericShotMapsToLetterWithoutResettingSlate() async {
        await MainActor.run {
            withStore { _, defaults in
                defaults.set(Data(#"{"scene":7,"shot":3,"take":12,"isLocked":true}"#.utf8), forKey: "slate.state.v1")
                let reopened = SlateStore(defaults: defaults)
                XCTAssertEqual(SlateCounter.allCases.map(reopened.displayValue), ["7", "C", "12"])
                XCTAssertTrue(reopened.isLocked)
                reopened.change(.shot, by: 1)
                XCTAssertEqual(reopened.displayValue(for: .shot), "C")
                defaults.set(Data(#"{"scene":7,"shot":9999,"take":12,"isLocked":false}"#.utf8), forKey: "slate.state.v1")
                XCTAssertEqual(SlateStore(defaults: defaults).displayValue(for: .shot), "Z")
            }
        }
    }
}
