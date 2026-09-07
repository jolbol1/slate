import Foundation

public enum SlateSound: String, CaseIterable, Codable {
    case clap
    case beep

    public var title: String {
        switch self {
        case .clap: return "Clap"
        case .beep: return "Beep"
        }
    }
}

/// User-facing slate options, kept locally and restored on launch.
public final class SlateSettingsStore {
    private enum Key {
        static let sound = "slate.settings.sound.v1"
        static let volume = "slate.settings.volume.v1"
        static let flash = "slate.settings.flash.v1"
        static let framesPerSecond = "slate.settings.fps.v1"
        static let resetTake = "slate.settings.resetTake.v1"
        static let advanceTake = "slate.settings.advanceTake.v1"
        static let advanceDelay = "slate.settings.advanceDelay.v1"
    }

    public static let supportedFrameRates = [24, 25, 30, 48, 50, 60]
    /// Seconds between a clap and the automatic step to the next take.
    public static let takeAdvanceDelays: ClosedRange<TimeInterval> = 0...120
    public static let defaultTakeAdvanceDelay: TimeInterval = 10

    private let defaults: UserDefaults
    public private(set) var sound: SlateSound
    public private(set) var volume: Float
    public private(set) var flashEnabled: Bool
    public private(set) var framesPerSecond: Int
    /// Take returns to 1 whenever Scene or Shot changes.
    public private(set) var resetsTakeOnNewShot: Bool
    /// Take steps up by one after each clap, so the slate is ready for the next take.
    public private(set) var advancesTakeAfterClap: Bool
    /// Wait before that step, so the slate still shows the take that was just clapped.
    public private(set) var takeAdvanceDelay: TimeInterval

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sound = defaults.string(forKey: Key.sound).flatMap(SlateSound.init(rawValue:)) ?? .clap

        if defaults.object(forKey: Key.volume) == nil {
            volume = 1
        } else {
            volume = min(1, max(0, defaults.float(forKey: Key.volume)))
        }

        flashEnabled = Self.bool(Key.flash, default: true, in: defaults)
        resetsTakeOnNewShot = Self.bool(Key.resetTake, default: true, in: defaults)
        advancesTakeAfterClap = Self.bool(Key.advanceTake, default: false, in: defaults)
        if defaults.object(forKey: Key.advanceDelay) == nil {
            takeAdvanceDelay = Self.defaultTakeAdvanceDelay
        } else {
            takeAdvanceDelay = Self.clampDelay(defaults.double(forKey: Key.advanceDelay))
        }

        let savedFrameRate = defaults.integer(forKey: Key.framesPerSecond)
        framesPerSecond = Self.supportedFrameRates.contains(savedFrameRate) ? savedFrameRate : 24
    }

    private static func clampDelay(_ delay: TimeInterval) -> TimeInterval {
        let range = takeAdvanceDelays
        guard delay.isFinite else { return defaultTakeAdvanceDelay }
        return min(range.upperBound, max(range.lowerBound, delay.rounded()))
    }

    private static func bool(_ key: String, default fallback: Bool, in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
    }

    public func setSound(_ sound: SlateSound) {
        self.sound = sound
        defaults.set(sound.rawValue, forKey: Key.sound)
    }

    public func setVolume(_ volume: Float) {
        self.volume = min(1, max(0, volume))
        defaults.set(self.volume, forKey: Key.volume)
    }

    public func setFlashEnabled(_ enabled: Bool) {
        flashEnabled = enabled
        defaults.set(enabled, forKey: Key.flash)
    }

    public func setFramesPerSecond(_ framesPerSecond: Int) {
        guard Self.supportedFrameRates.contains(framesPerSecond) else { return }
        self.framesPerSecond = framesPerSecond
        defaults.set(framesPerSecond, forKey: Key.framesPerSecond)
    }

    public func setResetsTakeOnNewShot(_ enabled: Bool) {
        resetsTakeOnNewShot = enabled
        defaults.set(enabled, forKey: Key.resetTake)
    }

    public func setAdvancesTakeAfterClap(_ enabled: Bool) {
        advancesTakeAfterClap = enabled
        defaults.set(enabled, forKey: Key.advanceTake)
    }

    /// Whole seconds, 0 to 120. 0 steps the take at the clap itself.
    public func setTakeAdvanceDelay(_ delay: TimeInterval) {
        takeAdvanceDelay = Self.clampDelay(delay)
        defaults.set(takeAdvanceDelay, forKey: Key.advanceDelay)
    }
}
