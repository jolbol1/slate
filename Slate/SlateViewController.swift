import UIKit

/// Uses only APIs available on the original iPad Air's iOS 12.
final class SlateViewController: UIViewController {
    private enum LayoutMode { case regular, compact, short }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return formatter
    }()

    private let slate: SlateStore
    private let settings: SlateSettingsStore
    private let audioPlayer = SlateAudioPlayer()

    private let column = UIStackView()
    private let clapButton = SlateClapButton()
    private let headerRow = UIStackView()
    private let productionButton = UIButton(type: .custom)
    private let dateLabel = UILabel()
    private let statusDot = UIView()
    private let statusLabel = UILabel()
    private let settingsButton = SlatePillButton(title: "SETTINGS", font: .systemFont(ofSize: 11, weight: .bold))
    private let chipScroll = UIScrollView()
    private let chipStack = UIStackView()
    private let rollChip = SlateChip()
    private let cameraChip = SlateChip()
    private let soundRollChip = SlateChip()
    private let fpsChip = SlateChip()
    private let locationChip = SlateChip()
    private let timeChip = SlateChip()
    private let soundChip = SlateChip()
    private let countersStack = UIStackView()
    private var counters: [CounterView] = []
    private let detailsStack = UIStackView()
    private var fields: [SlateFieldView] = []
    private let footerRow = UIStackView()
    private let lockButton = SlatePillButton(title: "Lock slate", font: SlateStyle.rounded(17, weight: .semibold))
    private let hintLabel = UILabel()
    private let timecodeLabel = UILabel()
    private let timecodeCaption = UILabel()
    private let flashView = UIView()
    private var clockTimer: Timer?
    private var layoutMode: LayoutMode?

    private var columnEdges: [NSLayoutConstraint] = []
    private var clapHeight: NSLayoutConstraint!
    private var headerHeight: NSLayoutConstraint!
    private var detailsHeight: NSLayoutConstraint!
    private var lockHeight: NSLayoutConstraint!
    private var lockWidth: NSLayoutConstraint!

    init(slate: SlateStore, settings: SlateSettingsStore) {
        self.slate = slate
        self.settings = settings
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(slate:settings:)") }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .all }

    // MARK: Build

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SlateStyle.background
        buildClap()
        buildHeader()
        buildChips()
        buildCounters()
        buildDetails()
        buildFooter()
        buildColumn()

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

    private func buildClap() {
        clapButton.accessibilityIdentifier = "slate-clap"
        clapButton.accessibilityHint = "Plays even while the slate is locked"
        clapButton.addTarget(self, action: #selector(playSlate), for: .touchUpInside)
        clapHeight = clapButton.heightAnchor.constraint(equalToConstant: 64)
        clapHeight.isActive = true
    }

    private func buildHeader() {
        headerRow.axis = .horizontal
        headerRow.alignment = .center
        headerRow.spacing = 14

        productionButton.contentHorizontalAlignment = .left
        productionButton.titleLabel?.font = SlateStyle.rounded(24, weight: .bold)
        productionButton.titleLabel?.lineBreakMode = .byTruncatingTail
        productionButton.titleLabel?.adjustsFontSizeToFitWidth = true
        productionButton.titleLabel?.minimumScaleFactor = 0.7
        productionButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        productionButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        productionButton.accessibilityLabel = "Production"
        productionButton.accessibilityHint = "Opens the slate details editor"
        productionButton.accessibilityIdentifier = "slate-production"
        productionButton.addTarget(self, action: #selector(editProduction), for: .touchUpInside)

        dateLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        dateLabel.accessibilityLabel = "Date"
        dateLabel.accessibilityIdentifier = "slate-date"

        let status = UIStackView(arrangedSubviews: [statusDot, statusLabel])
        status.axis = .horizontal
        status.alignment = .center
        status.spacing = 7
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.widthAnchor.constraint(equalToConstant: 7).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 7).isActive = true
        statusDot.layer.cornerRadius = 3.5
        statusLabel.font = .systemFont(ofSize: 12, weight: .bold)
        statusLabel.accessibilityIdentifier = "slate-status"
        status.setContentCompressionResistancePriority(.required, for: .horizontal)

        settingsButton.accessibilityLabel = "Slate settings"
        settingsButton.accessibilityIdentifier = "slate-settings"
        settingsButton.addTarget(self, action: #selector(showSettings), for: .touchUpInside)
        settingsButton.widthAnchor.constraint(equalToConstant: 92).isActive = true
        settingsButton.heightAnchor.constraint(equalToConstant: 38).isActive = true

        for child in [productionButton, dateLabel, status, settingsButton] { headerRow.addArrangedSubview(child) }
        headerHeight = headerRow.heightAnchor.constraint(equalToConstant: 40)
        headerHeight.isActive = true
    }

    private func buildChips() {
        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.alwaysBounceHorizontal = false
        chipScroll.clipsToBounds = false
        chipScroll.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.heightAnchor.constraint(equalToConstant: 32).isActive = true
        chipStack.axis = .horizontal
        chipStack.spacing = 8
        chipStack.translatesAutoresizingMaskIntoConstraints = false
        chipScroll.addSubview(chipStack)
        NSLayoutConstraint.activate([
            chipStack.topAnchor.constraint(equalTo: chipScroll.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScroll.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScroll.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScroll.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScroll.heightAnchor)
        ])

        let chips: [(SlateChip, String, String, Selector)] = [
            (rollChip, "chip-roll", "Camera roll", #selector(editRoll)),
            (cameraChip, "chip-camera", "Camera", #selector(cycleCamera)),
            (soundRollChip, "chip-sound-roll", "Sound roll", #selector(editSoundRoll)),
            (fpsChip, "chip-fps", "Frame rate", #selector(chooseFrameRate)),
            (locationChip, "chip-location", "Interior or exterior", #selector(toggleLocation)),
            (timeChip, "chip-time", "Day or night", #selector(toggleTimeOfDay)),
            (soundChip, "chip-sound", "Sync or MOS", #selector(toggleSoundMode))
        ]
        for (chip, identifier, label, action) in chips {
            chip.accessibilityIdentifier = identifier
            chip.accessibilityLabel = label
            chip.addTarget(self, action: action, for: .touchUpInside)
            chipStack.addArrangedSubview(chip)
        }
    }

    private func buildCounters() {
        countersStack.axis = .horizontal
        countersStack.distribution = .fillEqually
        countersStack.spacing = 12
        countersStack.setContentHuggingPriority(.defaultLow - 1, for: .vertical)
        countersStack.setContentCompressionResistancePriority(.defaultLow - 1, for: .vertical)
        for counter in SlateCounter.allCases {
            let card = CounterView(counter: counter)
            card.onStep = { [weak self] step in
                guard let self = self else { return }
                self.slate.change(counter, by: step)
                if counter != .take, self.settings.resetsTakeOnNewShot { self.slate.resetTake() }
                self.refresh()
            }
            counters.append(card)
            countersStack.addArrangedSubview(card)
        }
    }

    private func buildDetails() {
        detailsStack.axis = .horizontal
        detailsStack.distribution = .fillEqually
        detailsStack.alignment = .top
        detailsStack.spacing = 16
        for field in [SlateTextField.director, .cameraOperator, .filter, .notes] {
            let view = SlateFieldView(field: field)
            view.addTarget(self, action: #selector(editField(_:)), for: .touchUpInside)
            fields.append(view)
            detailsStack.addArrangedSubview(view)
        }
        detailsHeight = detailsStack.heightAnchor.constraint(equalToConstant: 50)
        detailsHeight.isActive = true
    }

    private func buildFooter() {
        footerRow.axis = .horizontal
        footerRow.alignment = .center
        footerRow.spacing = 16

        lockButton.accessibilityIdentifier = "slate-lock"
        lockButton.addTarget(self, action: #selector(lockTapped), for: .touchUpInside)
        lockHeight = lockButton.heightAnchor.constraint(equalToConstant: 56)
        lockWidth = lockButton.widthAnchor.constraint(equalToConstant: 200)
        NSLayoutConstraint.activate([lockHeight, lockWidth])
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = SlateStyle.muted
        hintLabel.textAlignment = .center
        hintLabel.isAccessibilityElement = false
        let lockColumn = UIStackView(arrangedSubviews: [lockButton, hintLabel])
        lockColumn.axis = .vertical
        lockColumn.alignment = .center
        lockColumn.spacing = 6

        timecodeLabel.font = SlateStyle.mono(40, weight: .medium)
        timecodeLabel.textColor = SlateStyle.ink
        timecodeLabel.textAlignment = .right
        timecodeLabel.adjustsFontSizeToFitWidth = true
        timecodeLabel.minimumScaleFactor = 0.5
        timecodeLabel.accessibilityLabel = "Local clock timecode"
        timecodeLabel.accessibilityIdentifier = "timecode"
        timecodeCaption.textAlignment = .right
        timecodeCaption.accessibilityIdentifier = "timecode-caption"
        let timeColumn = UIStackView(arrangedSubviews: [timecodeLabel, timecodeCaption])
        timeColumn.axis = .vertical
        timeColumn.alignment = .trailing
        timeColumn.spacing = 2

        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow - 10, for: .horizontal)
        for child in [lockColumn, spacer, timeColumn] { footerRow.addArrangedSubview(child) }
    }

    private func buildColumn() {
        column.axis = .vertical
        column.alignment = .fill
        column.spacing = 14
        column.translatesAutoresizingMaskIntoConstraints = false
        let topRule = SlateStyle.rule()
        let bottomRule = SlateStyle.rule()
        for child in [clapButton, headerRow, chipScroll, topRule, countersStack, bottomRule, detailsStack, footerRow] {
            column.addArrangedSubview(child)
        }
        column.setCustomSpacing(18, after: clapButton)
        column.setCustomSpacing(10, after: headerRow)
        view.addSubview(column)
        let guide = view.safeAreaLayoutGuide
        columnEdges = [
            column.topAnchor.constraint(equalTo: guide.topAnchor, constant: 20),
            column.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -20),
            column.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 32),
            column.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -32)
        ]
        NSLayoutConstraint.activate(columnEdges)
    }

    // MARK: Layout

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let bounds = view.bounds.inset(by: view.safeAreaInsets)
        let mode: LayoutMode
        if bounds.height < 500 {
            mode = .short
        } else if bounds.width < 600 && bounds.height > bounds.width {
            mode = .compact
        } else {
            mode = .regular
        }
        guard mode != layoutMode else { return }
        layoutMode = mode
        apply(mode)
    }

    private func apply(_ mode: LayoutMode) {
        let regular = mode == .regular
        let compact = mode == .compact
        let margin: CGFloat = regular ? 32 : 16
        columnEdges[0].constant = regular ? 20 : 10
        columnEdges[1].constant = regular ? -20 : -10
        columnEdges[2].constant = margin
        columnEdges[3].constant = -margin
        column.spacing = regular ? 14 : 10
        column.setCustomSpacing(regular ? 18 : 12, after: clapButton)
        column.setCustomSpacing(regular ? 10 : 8, after: headerRow)

        clapHeight.constant = regular ? 64 : (compact ? 54 : 46)
        headerHeight.constant = regular ? 40 : 36
        productionButton.titleLabel?.font = SlateStyle.rounded(regular ? 24 : 19, weight: .bold)
        dateLabel.isHidden = compact

        countersStack.axis = compact ? .vertical : .horizontal
        countersStack.spacing = regular ? 12 : 8
        for card in counters { card.compact = compact }

        detailsStack.isHidden = mode == .short
        detailsHeight.constant = regular ? 50 : 46
        for field in fields {
            field.isHidden = compact && (field.field == .filter || field.field == .notes)
        }

        lockHeight.constant = regular ? 56 : 44
        lockWidth.constant = regular ? 200 : 150
        lockButton.titleLabel?.font = SlateStyle.rounded(regular ? 17 : 15, weight: .semibold)
        timecodeLabel.font = SlateStyle.mono(regular ? 40 : 28, weight: .medium)
        hintLabel.isHidden = mode == .short
    }

    // MARK: Refresh

    private func refresh() {
        let details = slate.details
        let locked = slate.isLocked
        for card in counters { card.refresh(slate: slate) }

        let production = details.production.trimmingCharacters(in: .whitespaces)
        productionButton.setTitle(production.isEmpty ? "Untitled production" : production, for: .normal)
        productionButton.setTitleColor(production.isEmpty ? SlateStyle.muted : SlateStyle.ink, for: .normal)
        productionButton.accessibilityValue = production.isEmpty ? "Empty" : production
        productionButton.isEnabled = !locked
        refreshDate()

        statusLabel.text = locked ? "LOCKED" : "READY"
        statusLabel.textColor = locked ? SlateStyle.accent : SlateStyle.muted
        statusDot.backgroundColor = statusLabel.textColor

        rollChip.show(key: "ROLL", value: details.roll.isEmpty ? "—" : details.roll.uppercased(), isPlaceholder: details.roll.isEmpty)
        cameraChip.show(key: "CAM", value: details.cameraLetter)
        soundRollChip.show(key: "SND", value: details.soundRoll.isEmpty ? "—" : details.soundRoll.uppercased(), isPlaceholder: details.soundRoll.isEmpty)
        fpsChip.show(key: "FPS", value: String(settings.framesPerSecond))
        locationChip.show(options: SlateLocation.allCases.map { $0.title }, selected: SlateLocation.allCases.firstIndex(of: details.location) ?? 0)
        timeChip.show(options: SlateTimeOfDay.allCases.map { $0.title }, selected: SlateTimeOfDay.allCases.firstIndex(of: details.timeOfDay) ?? 0)
        soundChip.show(options: SlateSoundMode.allCases.map { $0.title }, selected: SlateSoundMode.allCases.firstIndex(of: details.soundMode) ?? 0)
        for chip in [rollChip, cameraChip, soundRollChip, locationChip, timeChip, soundChip] { chip.isEnabled = !locked }

        for field in fields {
            field.show(details[field.field])
            field.isEnabled = !locked
        }

        lockButton.setTitle(locked ? "Unlock slate" : "Lock slate", for: .normal)
        lockButton.setTitleColor(locked ? SlateStyle.background : SlateStyle.ink, for: .normal)
        lockButton.backgroundColor = locked ? SlateStyle.accent : SlateStyle.surface
        lockButton.layer.borderColor = locked ? UIColor.clear.cgColor : SlateStyle.rule.cgColor
        lockButton.accessibilityHint = locked ? "Double tap to enable the slate controls" : "Double tap to disable all slate controls"
        hintLabel.text = locked ? "Double-tap to unlock" : "Double-tap to lock"

        clapButton.title = "TAP TO \(settings.sound.title.uppercased())"
        clapButton.accessibilityLabel = "Play \(settings.sound.title.lowercased()) slate sound"
        timecodeCaption.attributedText = SlateStyle.caption("LOCAL TIME  ·  \(settings.framesPerSecond) FPS", size: 11, kern: 1.2)
    }

    private func refreshDate() {
        let text = Self.dateFormatter.string(from: Date()).uppercased()
        if dateLabel.text != text {
            dateLabel.attributedText = SlateStyle.caption(text, size: 12, weight: .bold, color: SlateStyle.ink, kern: 1.4)
            dateLabel.accessibilityValue = text
        }
    }

    // MARK: Actions

    @objc private func playSlate() {
        audioPlayer.play(settings.sound, volume: settings.volume)
        clapButton.animateClap()
        if settings.advancesTakeAfterClap {
            slate.change(.take, by: 1)
            refresh()
        }
        guard settings.flashEnabled else { return }
        if let window = view.window, flashView.superview !== window {
            flashView.removeFromSuperview()
            flashView.frame = window.bounds
            flashView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
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

    @objc private func editProduction() { openDetails(focus: .production) }
    @objc private func editRoll() { openDetails(focus: .roll) }
    @objc private func editSoundRoll() { openDetails(focus: .soundRoll) }
    @objc private func editField(_ sender: SlateFieldView) { openDetails(focus: sender.field) }

    @objc private func cycleCamera() {
        slate.cycleCamera()
        refresh()
    }

    @objc private func toggleLocation() {
        slate.setLocation(slate.details.location.next)
        refresh()
    }

    @objc private func toggleTimeOfDay() {
        slate.setTimeOfDay(slate.details.timeOfDay.next)
        refresh()
    }

    @objc private func toggleSoundMode() {
        slate.setSoundMode(slate.details.soundMode.next)
        refresh()
    }

    @objc private func chooseFrameRate() {
        let sheet = UIAlertController(title: "Frame rate", message: "Sets the frame count of the clock and the FPS shown on the slate.", preferredStyle: .actionSheet)
        for rate in SlateSettingsStore.supportedFrameRates {
            let current = rate == settings.framesPerSecond
            sheet.addAction(UIAlertAction(title: current ? "\(rate) fps  ✓" : "\(rate) fps", style: .default) { [weak self] _ in
                self?.settings.setFramesPerSecond(rate)
                self?.refresh()
            })
        }
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        sheet.popoverPresentationController?.sourceView = fpsChip
        sheet.popoverPresentationController?.sourceRect = fpsChip.bounds
        present(sheet, animated: true)
    }

    private func openDetails(focus: SlateTextField?) {
        guard !slate.isLocked else { return }
        let controller = SlateDetailsViewController(slate: slate, focus: focus, onChange: { [weak self] in self?.refresh() })
        presentSheet(controller)
    }

    @objc private func showSettings() {
        let controller = SlateSettingsViewController(
            settings: settings,
            slate: slate,
            onChange: { [weak self] in self?.refresh() },
            onPreview: { [weak self] in self?.playSlate() }
        )
        presentSheet(controller)
    }

    private func presentSheet(_ controller: UIViewController) {
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .formSheet
        if #available(iOS 13.0, *) { navigation.overrideUserInterfaceStyle = .dark }
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

    // MARK: Clock

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
        guard timecodeLabel.text != text else { return }
        let secondChanged = timecodeLabel.text?.prefix(8) != text.prefix(8)
        timecodeLabel.text = text
        timecodeLabel.accessibilityValue = text
        if secondChanged { refreshDate() }
    }

    deinit {
        clockTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}
