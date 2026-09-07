import Foundation
import XCTest
@testable import SlateCore

final class SlateSettingsStoreTests: XCTestCase {
    private func withDefaults(_ body: (UserDefaults) -> Void) {
        let name = "SlateSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        body(defaults)
    }

    func testDefaultsAreClapFullVolumeFlashAnd24FPS() {
        withDefaults { defaults in
            let settings = SlateSettingsStore(defaults: defaults)
            XCTAssertEqual(settings.sound, .clap)
            XCTAssertEqual(settings.volume, 1)
            XCTAssertTrue(settings.flashEnabled)
            XCTAssertEqual(settings.framesPerSecond, 24)
            XCTAssertTrue(settings.resetsTakeOnNewShot)
            XCTAssertFalse(settings.advancesTakeAfterClap)
        }
    }

    func testSettingsPersistAcrossRelaunch() {
        withDefaults { defaults in
            let settings = SlateSettingsStore(defaults: defaults)
            settings.setSound(.beep)
            settings.setVolume(0.42)
            settings.setFlashEnabled(false)
            settings.setFramesPerSecond(25)
            settings.setResetsTakeOnNewShot(false)
            settings.setAdvancesTakeAfterClap(true)

            let reopened = SlateSettingsStore(defaults: defaults)
            XCTAssertEqual(reopened.sound, .beep)
            XCTAssertEqual(reopened.volume, 0.42, accuracy: 0.001)
            XCTAssertFalse(reopened.flashEnabled)
            XCTAssertEqual(reopened.framesPerSecond, 25)
            XCTAssertFalse(reopened.resetsTakeOnNewShot)
            XCTAssertTrue(reopened.advancesTakeAfterClap)
        }
    }

    func testInvalidValuesAreClampedOrIgnored() {
        withDefaults { defaults in
            defaults.set("airhorn", forKey: "slate.settings.sound.v1")
            defaults.set(4.2, forKey: "slate.settings.volume.v1")
            defaults.set(47, forKey: "slate.settings.fps.v1")
            let settings = SlateSettingsStore(defaults: defaults)
            XCTAssertEqual(settings.sound, .clap)
            XCTAssertEqual(settings.volume, 1)
            XCTAssertEqual(settings.framesPerSecond, 24)

            settings.setVolume(-2)
            settings.setFramesPerSecond(23)
            XCTAssertEqual(settings.volume, 0)
            XCTAssertEqual(settings.framesPerSecond, 24)
            settings.setFramesPerSecond(30)
            XCTAssertEqual(settings.framesPerSecond, 30)
            settings.setFramesPerSecond(60)
            XCTAssertEqual(settings.framesPerSecond, 60)
        }
    }
}
