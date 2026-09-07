import Foundation

/// Free-text lines written on a physical slate.
public enum SlateTextField: String, CaseIterable, Codable {
    case production, director, cameraOperator, roll, soundRoll, filter, notes

    public var title: String {
        switch self {
        case .production: return "Production"
        case .director: return "Director"
        case .cameraOperator: return "Camera"
        case .roll: return "Roll"
        case .soundRoll: return "Sound roll"
        case .filter: return "Filter"
        case .notes: return "Notes"
        }
    }

    public var placeholder: String {
        switch self {
        case .production: return "Production title"
        case .director: return "Director's name"
        case .cameraOperator: return "DP or operator"
        case .roll: return "A001"
        case .soundRoll: return "S001"
        case .filter: return "ND 0.6"
        case .notes: return "Pick-up, VFX plate…"
        }
    }

    public var maxLength: Int {
        switch self {
        case .production: return 40
        case .director, .cameraOperator: return 32
        case .roll, .soundRoll: return 8
        case .filter: return 16
        case .notes: return 80
        }
    }

    /// Short codes are shown in capitals, like tape labels on a real slate.
    public var isUppercased: Bool {
        self == .roll || self == .soundRoll || self == .filter
    }
}

public enum SlateLocation: String, CaseIterable, Codable {
    case interior, exterior

    public var title: String { self == .interior ? "INT" : "EXT" }
    public var next: SlateLocation { self == .interior ? .exterior : .interior }
}

public enum SlateTimeOfDay: String, CaseIterable, Codable {
    case day, night

    public var title: String { self == .day ? "DAY" : "NIGHT" }
    public var next: SlateTimeOfDay { self == .day ? .night : .day }
}

public enum SlateSoundMode: String, CaseIterable, Codable {
    case sync, mos

    public var title: String { self == .sync ? "SYNC" : "MOS" }
    public var next: SlateSoundMode { self == .sync ? .mos : .sync }
}

/// Everything on the slate except the three counters and the lock.
public struct SlateDetails: Codable, Equatable {
    public static let cameraLetters = Array("ABCD").map(String.init)

    public var production = ""
    public var director = ""
    public var cameraOperator = ""
    public var roll = ""
    public var soundRoll = ""
    public var filter = ""
    public var notes = ""
    /// Index into `cameraLetters`; 0 is camera A.
    public var camera = 0
    public var location = SlateLocation.interior
    public var timeOfDay = SlateTimeOfDay.day
    public var soundMode = SlateSoundMode.sync

    public init() {}

    public var cameraLetter: String { Self.cameraLetters[camera] }
    public var isEmpty: Bool { self == SlateDetails() }

    public subscript(field: SlateTextField) -> String {
        get {
            switch field {
            case .production: return production
            case .director: return director
            case .cameraOperator: return cameraOperator
            case .roll: return roll
            case .soundRoll: return soundRoll
            case .filter: return filter
            case .notes: return notes
            }
        }
        set {
            switch field {
            case .production: production = newValue
            case .director: director = newValue
            case .cameraOperator: cameraOperator = newValue
            case .roll: roll = newValue
            case .soundRoll: soundRoll = newValue
            case .filter: filter = newValue
            case .notes: notes = newValue
            }
        }
    }

    /// Clamps every value into its allowed range; used after decoding and before saving.
    mutating func normalize() {
        for field in SlateTextField.allCases {
            self[field] = String(self[field].prefix(field.maxLength))
        }
        camera = min(Self.cameraLetters.count - 1, max(0, camera))
    }

    private enum CodingKeys: String, CodingKey {
        case production, director, cameraOperator, roll, soundRoll, filter, notes
        case camera, location, timeOfDay, soundMode
    }

    /// Missing or invalid keys fall back to defaults, so old saves and newer saves both open.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        production = container.value(.production, default: "")
        director = container.value(.director, default: "")
        cameraOperator = container.value(.cameraOperator, default: "")
        roll = container.value(.roll, default: "")
        soundRoll = container.value(.soundRoll, default: "")
        filter = container.value(.filter, default: "")
        notes = container.value(.notes, default: "")
        camera = container.value(.camera, default: 0)
        location = container.value(.location, default: .interior)
        timeOfDay = container.value(.timeOfDay, default: .day)
        soundMode = container.value(.soundMode, default: .sync)
        normalize()
    }
}

extension KeyedDecodingContainer {
    func value<T: Decodable>(_ key: Key, default fallback: T) -> T {
        ((try? decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
    }
}
