import Foundation
import XCTest
@testable import SlateCore

final class SlateTimecodeTests: XCTestCase {
    func testClockAndFrameRollover() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let clock = SlateTimecode()
        XCTAssertEqual(clock.string(at: Date(timeIntervalSince1970: 0.125), calendar: utc), "00:00:00:03")
        XCTAssertEqual(clock.string(at: Date(timeIntervalSince1970: 86399.999), calendar: utc), "23:59:59:23")
        XCTAssertEqual(clock.string(at: Date(timeIntervalSince1970: 86400), calendar: utc), "00:00:00:00")
    }

    func testLocalTimezoneAndSupportedFrameRates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3600)!
        XCTAssertEqual(SlateTimecode(framesPerSecond: 24).string(at: Date(timeIntervalSince1970: 0.5), calendar: calendar), "01:00:00:12")
        XCTAssertEqual(SlateTimecode(framesPerSecond: 30).string(at: Date(timeIntervalSince1970: 0.5), calendar: calendar), "01:00:00:15")
    }
}
