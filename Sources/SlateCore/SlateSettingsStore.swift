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
    }

    public static let supportedFrameRates = [24, 25, 30]

    private let defaults: UserDefaults
    public private(set) var sound: SlateSound
    public private(set) var volume: Float
    public private(set) var flashEnabled: Bool
    public private(set) var framesPerSecond: Int

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sound = defaults.string(forKey: Key.sound).flatMap(SlateSound.init(rawValue:)) ?? .clap

        if defaults.object(forKey: Key.volume) == nil {
            volume = 1
        } else {
            volume = min(1, max(0, defaults.float(forKey: Key.volume)))
        }

        flashEnabled = defaults.object(forKey: Key.flash) == nil
            ? true
            : defaults.bool(forKey: Key.flash)

        let savedFrameRate = defaults.integer(forKey: Key.framesPerSecond)
        framesPerSecond = Self.supportedFrameRates.contains(savedFrameRate) ? savedFrameRate : 24
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
}
