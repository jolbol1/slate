import Foundation

public enum SlateCounter: String, CaseIterable {
    case scene, shot, take

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

/// One local snapshot, saved after every change. No account or network needed.
public final class SlateStore {
    public static let allowedNumbers = 0...9999
    private static let shotLetters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ").map(String.init)
    private static let storageKey = "slate.state.v1"

    private static func allowedValues(for counter: SlateCounter) -> ClosedRange<Int> {
        counter == .shot ? 1...shotLetters.count : allowedNumbers
    }

    private struct Snapshot: Codable, Equatable {
        var scene = 1
        var shot = 1
        var take = 1
        var isLocked = false
        var details = SlateDetails()

        init() {}

        private enum CodingKeys: String, CodingKey {
            case scene, shot, take, isLocked, details
        }

        /// Saves from before `details` existed decode with empty details.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            scene = container.value(.scene, default: 1)
            shot = container.value(.shot, default: 1)
            take = container.value(.take, default: 1)
            isLocked = container.value(.isLocked, default: false)
            details = container.value(.details, default: SlateDetails())
        }

        subscript(counter: SlateCounter) -> Int {
            get {
                switch counter {
                case .scene: return scene
                case .shot: return shot
                case .take: return take
                }
            }
            set {
                switch counter {
                case .scene: scene = newValue
                case .shot: shot = newValue
                case .take: take = newValue
                }
            }
        }
    }

    private var snapshot: Snapshot
    private let defaults: UserDefaults
    private var previousLockTap: TimeInterval?

    public var isLocked: Bool { snapshot.isLocked }
    public var details: SlateDetails { snapshot.details }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           var saved = try? JSONDecoder().decode(Snapshot.self, from: data) {
            for counter in SlateCounter.allCases {
                let range = Self.allowedValues(for: counter)
                saved[counter] = min(range.upperBound, max(range.lowerBound, saved[counter]))
            }
            snapshot = saved
        } else {
            snapshot = Snapshot()
        }
    }

    // MARK: Counters

    public func value(for counter: SlateCounter) -> Int {
        snapshot[counter]
    }

    public func displayValue(for counter: SlateCounter) -> String {
        counter == .shot ? Self.shotLetters[snapshot.shot - 1] : String(snapshot[counter])
    }

    public func canChange(_ counter: SlateCounter, by step: Int) -> Bool {
        guard !isLocked, step == -1 || step == 1 else { return false }
        return Self.allowedValues(for: counter).contains(snapshot[counter] + step)
    }

    public func change(_ counter: SlateCounter, by step: Int) {
        guard canChange(counter, by: step) else { return }
        snapshot[counter] += step
        save()
    }

    /// Take goes back to 1, as when a new scene or shot starts. Does nothing while locked.
    public func resetTake() {
        guard !isLocked, snapshot.take != 1 else { return }
        snapshot.take = 1
        save()
    }

    /// Scene 1, Shot A, Take 1. Does nothing while locked.
    public func resetCounters() {
        guard !isLocked else { return }
        snapshot.scene = 1
        snapshot.shot = 1
        snapshot.take = 1
        save()
    }

    // MARK: Details

    /// All detail edits go through here; edits are ignored while locked.
    public func updateDetails(_ change: (inout SlateDetails) -> Void) {
        guard !isLocked else { return }
        var details = snapshot.details
        change(&details)
        details.normalize()
        guard details != snapshot.details else { return }
        snapshot.details = details
        save()
    }

    public func setText(_ text: String, for field: SlateTextField) {
        updateDetails { $0[field] = text }
    }

    public func setCamera(_ index: Int) {
        updateDetails { $0.camera = index }
    }

    public func cycleCamera() {
        updateDetails { $0.camera = ($0.camera + 1) % SlateDetails.cameraLetters.count }
    }

    public func setLocation(_ location: SlateLocation) {
        updateDetails { $0.location = location }
    }

    public func setTimeOfDay(_ timeOfDay: SlateTimeOfDay) {
        updateDetails { $0.timeOfDay = timeOfDay }
    }

    public func setSoundMode(_ soundMode: SlateSoundMode) {
        updateDetails { $0.soundMode = soundMode }
    }

    public func clearDetails() {
        updateDetails { $0 = SlateDetails() }
    }

    // MARK: Lock

    /// Uses monotonic time; a lone tap or two taps more than 0.6s apart do nothing.
    @discardableResult
    public func tapLock(at time: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        if let previousLockTap, time >= previousLockTap, time - previousLockTap <= 0.6 {
            self.previousLockTap = nil
            toggleLock()
            return true
        }
        previousLockTap = time
        return false
    }

    public func cancelPendingLockTap() {
        previousLockTap = nil
    }

    /// An accessibility activation already requires an intentional system gesture.
    public func activateAccessibleLock() {
        previousLockTap = nil
        toggleLock()
    }

    private func toggleLock() {
        snapshot.isLocked.toggle()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
