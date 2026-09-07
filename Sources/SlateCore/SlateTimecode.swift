import Foundation

public struct SlateTimecode {
    public let framesPerSecond: Int

    public init(framesPerSecond: Int = 24) {
        precondition(SlateSettingsStore.supportedFrameRates.contains(framesPerSecond))
        self.framesPerSecond = framesPerSecond
    }

    /// Time-of-day reference from the device clock; not camera or audio timecode.
    public func string(at date: Date = Date(), calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute, .second], from: date)
        let seconds = date.timeIntervalSince1970
        let fraction = seconds - floor(seconds)
        let frame = min(framesPerSecond - 1, Int(floor(fraction * Double(framesPerSecond))))
        return String(format: "%02d:%02d:%02d:%02d", parts.hour ?? 0, parts.minute ?? 0, parts.second ?? 0, frame)
    }
}
