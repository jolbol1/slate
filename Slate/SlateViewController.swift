import UIKit

private enum SlateStyle {
    static let background = UIColor(red: 0.035, green: 0.043, blue: 0.047, alpha: 1)
    static let ink = UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1)
    static let muted = UIColor(red: 0.51, green: 0.54, blue: 0.54, alpha: 1)
    static let accent = UIColor(red: 1, green: 0.65, blue: 0.25, alpha: 1)
    static let rule = UIColor.white.withAlphaComponent(0.16)
}

/// Uses only APIs available on the original iPad Air's iOS 12.
final class SlateViewController: UIViewController {
    private let slate: SlateStore
    private let settings: SlateSettingsStore
    private let audioPlayer = SlateAudioPlayer()
    private let titleLabel = UILabel()
    private let statusLabel = UILabel()
    private let statusDot = UIView()
    private let clapButton = UIButton(type: .custom)
    private let settingsButton = UIButton(type: .custom)
    private let topRule = UIView()
    private let bottomRule = UIView()
    private let separators = [UIView(), UIView()]
    private let lockButton = UIButton(type: .custom)
    private let hintLabel = UILabel()
    private let timecodeLabel = UILabel()
    private let timecodeCaption = UILabel()
    private let flashView = UIView()
    private var clockTimer: Timer?
    private var counters: [CounterView] = []

    init(slate: SlateStore, settings: SlateSettingsStore) {
        self.slate = slate
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(slate:settings:)") }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SlateStyle.background

        titleLabel.attributedText = NSAttributedString(string: "SLATE", attributes: [
            .font: UIFont.systemFont(ofSize: 16, weight: .bold),
            .kern: 4, .foregroundColor: SlateStyle.ink
        ])
        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statusLabel.textAlignment = .right
        statusDot.layer.cornerRadius = 3.5

        clapButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        clapButton.layer.cornerRadius = 12
        clapButton.backgroundColor = SlateStyle.accent
        clapButton.setTitleColor(SlateStyle.background, for: .normal)
        clapButton.accessibilityIdentifier = "slate-clap"
        clapButton.accessibilityHint = "Plays even while the scene, shot and take controls are locked"
        clapButton.addTarget(self, action: #selector(playSlate), for: .touchUpInside)

        settingsButton.setTitle("SETTINGS", for: .normal)
        settingsButton.titleLabel?.font = .systemFont(ofSize: 11, weight: .bold)
        settingsButton.setTitleColor(SlateStyle.ink, for: .normal)
        settingsButton.layer.cornerRadius = 10
        settingsButton.layer.borderWidth = 1
        settingsButton.layer.borderColor = SlateStyle.rule.cgColor
        settingsButton.accessibilityLabel = "Slate settings"
        settingsButton.accessibilityIdentifier = "slate-settings"
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)

        for child in [titleLabel, statusLabel, statusDot, clapButton, settingsButton, topRule, bottomRule, lockButton, hintLabel, timecodeLabel, timecodeCaption] + separators {
            view.addSubview(child)
        }
        for rule in [topRule, bottomRule] + separators { rule.backgroundColor = SlateStyle.rule }

        for counter in SlateCounter.allCases {
            let column = CounterView(counter: counter)
            column.onStep = { [weak self] step in
                guard let self = self else { return }
                self.slate.change(counter, by: step)
                self.refresh()
            }
            counters.append(column)
            view.addSubview(column)
        }

        lockButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        lockButton.layer.cornerRadius = 30
        lockButton.layer.borderWidth = 1
        lockButton.accessibilityIdentifier = "slate-lock"
        lockButton.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textAlignment = .center
        hintLabel.textColor = SlateStyle.muted
        hintLabel.isAccessibilityElement = false
        timecodeLabel.font = .monospacedDigitSystemFont(ofSize: 38, weight: .medium)
        timecodeLabel.textColor = SlateStyle.ink
        timecodeLabel.textAlignment = .right
        timecodeLabel.adjustsFontSizeToFitWidth = true
        timecodeLabel.minimumScaleFactor = 0.5
        timecodeLabel.accessibilityLabel = "Local clock timecode"
        timecodeLabel.accessibilityIdentifier = "timecode"
        timecodeCaption.font = .systemFont(ofSize: 11, weight: .medium)
        timecodeCaption.textColor = SlateStyle.muted
        timecodeCaption.textAlignment = .right
        timecodeCaption.accessibilityIdentifier = "timecode-caption"
        flashView.backgroundColor = SlateStyle.ink
        flashView.alpha = 0
        flashView.isUserInteractionEnabled = false
        flashView.accessibilityElementsHidden = true
        view.addSubview(flashView)
        NotificationCenter.default.addObserver(self, selector: #selector(startClock), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(stopClock), name: UIApplication.willResignActiveNotification, object: nil)
        startClock()
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = view.bounds.inset(by: view.safeAreaInsets)
        let compact = bounds.width < 600
        let margin: CGFloat = compact ? 24 : 44
        let left = bounds.minX + margin
        let width = bounds.width - margin * 2
        let top = bounds.minY + (compact ? 24 : 36)
        titleLabel.frame = CGRect(x: left, y: top, width: 100, height: 24)
        let settingsWidth: CGFloat = compact ? 76 : 92
        settingsButton.frame = CGRect(x: left + width - settingsWidth, y: top - 7, width: settingsWidth, height: 38)
        statusLabel.frame = CGRect(x: settingsButton.frame.minX - 82, y: top, width: 72, height: 24)
        statusDot.frame = CGRect(x: statusLabel.frame.minX - 11, y: top + 8.5, width: 7, height: 7)
        let clapWidth: CGFloat = compact ? 176 : 220
        clapButton.frame = CGRect(x: bounds.midX - clapWidth / 2, y: top - 9, width: clapWidth, height: 42)

        let counterTop = top + 56
        let counterBottom = bounds.maxY - 156
        topRule.frame = CGRect(x: left, y: counterTop, width: width, height: 1)
        bottomRule.frame = CGRect(x: left, y: counterBottom, width: width, height: 1)
        let regionHeight = max(0, counterBottom - counterTop)

        for (index, column) in counters.enumerated() {
            column.compact = compact
            if compact {
                let height = regionHeight / 3
                column.frame = CGRect(x: left, y: counterTop + CGFloat(index) * height, width: width, height: height)
                if index < 2 {
                    separators[index].frame = CGRect(x: left, y: column.frame.maxY, width: width, height: 1)
                }
            } else {
                let columnWidth = width / 3
                column.frame = CGRect(x: left + CGFloat(index) * columnWidth, y: counterTop, width: columnWidth, height: regionHeight)
                if index < 2 {
                    separators[index].frame = CGRect(x: column.frame.maxX, y: counterTop + 32, width: 1, height: regionHeight - 64)
                }
            }
            column.setNeedsLayout()
        }
        let lockWidth: CGFloat = compact ? 160 : 224
        lockButton.frame = CGRect(x: left, y: counterBottom + 32, width: lockWidth, height: 60)
        hintLabel.frame = CGRect(x: left, y: lockButton.frame.maxY + 12, width: lockWidth, height: 20)
        let clockLeft = lockButton.frame.maxX + (compact ? 16 : 32)
        let clockWidth = max(0, bounds.maxX - margin - clockLeft)
        timecodeLabel.frame = CGRect(x: clockLeft, y: counterBottom + 36, width: clockWidth, height: 48)
        timecodeCaption.frame = CGRect(x: clockLeft, y: counterBottom + 98, width: clockWidth, height: 20)
        flashView.frame = view.bounds
    }

    private func refresh() {
        for column in counters { column.refresh(slate: slate) }
        let locked = slate.isLocked
        statusLabel.text = locked ? "LOCKED" : "READY"
        statusLabel.textColor = locked ? SlateStyle.accent : SlateStyle.muted
        statusDot.backgroundColor = statusLabel.textColor
        lockButton.setTitle(locked ? "Unlock slate" : "Lock slate", for: .normal)
        lockButton.setTitleColor(locked ? SlateStyle.background : SlateStyle.ink, for: .normal)
        lockButton.backgroundColor = locked ? SlateStyle.accent : UIColor.white.withAlphaComponent(0.08)
        lockButton.layer.borderColor = locked ? UIColor.clear.cgColor : SlateStyle.rule.cgColor
        lockButton.accessibilityHint = locked ? "Double tap to enable the slate controls" : "Double tap to disable all slate controls"
        hintLabel.text = locked ? "Double-tap to unlock" : "Double-tap to lock"
        clapButton.setTitle("TAP TO \(settings.sound.title.uppercased())", for: .normal)
        clapButton.accessibilityLabel = "Play \(settings.sound.title.lowercased()) slate sound"
        timecodeCaption.text = "LOCAL TIME  ·  \(settings.framesPerSecond) FPS"
    }

    @objc private func playSlate() {
        audioPlayer.play(settings.sound, volume: settings.volume)
        guard settings.flashEnabled else { return }
        if let window = view.window, flashView.superview !== window {
            flashView.removeFromSuperview()
            flashView.frame = window.bounds
            window.addSubview(flashView)
        }
        flashView.superview?.bringSubviewToFront(flashView)
        flashView.layer.removeAllAnimations()
        flashView.alpha = 0.92
        UIView.animate(
            withDuration: 0.18,
            delay: 0.035,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: { [weak self] in self?.flashView.alpha = 0 },
            completion: nil
        )
    }

    @objc private func showSettings() {
        let controller = SlateSettingsViewController(
            settings: settings,
            onChange: { [weak self] in self?.refresh() },
            onPreview: { [weak self] in self?.playSlate() }
        )
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .formSheet
        present(navigation, animated: true)
    }

    @objc private func lockTapped() {
        if UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning {
            slate.activateAccessibleLock()
        } else {
            slate.tapLock()
        }
        refresh()
    }

    @objc private func startClock() {
        guard clockTimer == nil else { return }
        updateClock()
        // Read wall time on each tick so delays never accumulate as clock drift.
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.updateClock()
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    @objc private func stopClock() {
        clockTimer?.invalidate()
        clockTimer = nil
    }

    private func updateClock() {
        let text = SlateTimecode(framesPerSecond: settings.framesPerSecond).string()
        if timecodeLabel.text != text {
            timecodeLabel.text = text
            timecodeLabel.accessibilityValue = text
        }
    }

    deinit {
        clockTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

private final class CounterView: UIView {
    let counter: SlateCounter
    var compact = false
    var onStep: ((Int) -> Void)?
    private let titleLabel = UILabel()
    private let numberLabel = UILabel()
    private let minusButton = UIButton(type: .custom)
    private let plusButton = UIButton(type: .custom)

    init(counter: SlateCounter) {
        self.counter = counter
        super.init(frame: .zero)
        titleLabel.attributedText = NSAttributedString(string: counter.title.uppercased(), attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .medium),
            .kern: 5, .foregroundColor: SlateStyle.muted
        ])
        titleLabel.isAccessibilityElement = false
        numberLabel.textColor = SlateStyle.ink
        numberLabel.adjustsFontSizeToFitWidth = true
        numberLabel.minimumScaleFactor = 0.18
        numberLabel.numberOfLines = 1
        numberLabel.accessibilityLabel = counter.title
        numberLabel.accessibilityIdentifier = "number-\(counter.rawValue)"

        for (button, symbol, name) in [(minusButton, "−", "minus"), (plusButton, "+", "plus")] {
            button.setTitle(symbol, for: .normal)
            button.titleLabel?.font = .systemFont(ofSize: 30, weight: .regular)
            button.setTitleColor(SlateStyle.ink, for: .normal)
            button.setTitleColor(SlateStyle.ink.withAlphaComponent(0.18), for: .disabled)
            button.layer.cornerRadius = 14
            button.layer.borderWidth = 1
            button.accessibilityLabel = counter == .shot
                ? "\(name == "plus" ? "Next" : "Previous") shot letter"
                : "\(name == "plus" ? "Increase" : "Decrease") \(counter.rawValue)"
            button.accessibilityIdentifier = "\(counter.rawValue)-\(name)"
        }
        minusButton.addTarget(self, action: #selector(decrease), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(increase), for: .touchUpInside)
        for child in [titleLabel, numberLabel, minusButton, plusButton] { addSubview(child) }
    }

    required init?(coder: NSCoder) { fatalError("Use init(counter:)") }

    override func layoutSubviews() {
        super.layoutSubviews()
        if compact {
            titleLabel.textAlignment = .left
            numberLabel.textAlignment = .left
            titleLabel.frame = CGRect(x: 0, y: 12, width: bounds.width - 90, height: 28)
            numberLabel.frame = CGRect(x: 0, y: 42, width: bounds.width - 90, height: bounds.height - 48)
            numberLabel.font = .monospacedDigitSystemFont(ofSize: min(112, bounds.height * 0.65), weight: .semibold)
            plusButton.frame = CGRect(x: bounds.width - 70, y: bounds.midY - 65, width: 70, height: 60)
            minusButton.frame = CGRect(x: bounds.width - 70, y: bounds.midY + 5, width: 70, height: 60)
        } else {
            titleLabel.textAlignment = .center
            numberLabel.textAlignment = .center
            titleLabel.frame = CGRect(x: 12, y: 36, width: bounds.width - 24, height: 30)
            numberLabel.frame = CGRect(x: 16, y: 78, width: bounds.width - 32, height: max(0, bounds.height - 190))
            numberLabel.font = .monospacedDigitSystemFont(ofSize: min(280, bounds.height * 0.55), weight: .semibold)
            let buttonWidth = min(90, (bounds.width - 54) / 2)
            minusButton.frame = CGRect(x: bounds.midX - buttonWidth - 7, y: bounds.height - 96, width: buttonWidth, height: 60)
            plusButton.frame = CGRect(x: bounds.midX + 7, y: bounds.height - 96, width: buttonWidth, height: 60)
        }
    }

    func refresh(slate: SlateStore) {
        numberLabel.text = slate.displayValue(for: counter)
        numberLabel.accessibilityValue = numberLabel.text
        for (button, step) in [(minusButton, -1), (plusButton, 1)] {
            let enabled = slate.canChange(counter, by: step)
            button.isEnabled = enabled
            button.backgroundColor = UIColor.white.withAlphaComponent(enabled ? 0.07 : 0.02)
            button.layer.borderColor = UIColor.white.withAlphaComponent(enabled ? 0.15 : 0.04).cgColor
        }
    }

    @objc private func decrease() { onStep?(-1) }
    @objc private func increase() { onStep?(1) }
}
