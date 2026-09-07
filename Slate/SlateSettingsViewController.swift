import UIKit

/// Grouped settings sheet. Every change applies and saves immediately.
final class SlateSettingsViewController: UITableViewController {
    private enum Row {
        case sound(SlateSound)
        case volume, flash, preview
        case resetTake, advanceTake, advanceDelay
        case frameRate(Int)
        case editDetails, resetCounters
        case promise, version
    }

    private struct Section {
        let title: String?
        let footer: String?
        let rows: [Row]
    }

    private static let sections = [
        Section(title: "Slate sound",
                footer: "Clap gives a natural sync point. Beep is easier to hear in a noisy room. Sound plays with Silent Mode on, and the screen flash marks the same instant.",
                rows: SlateSound.allCases.map(Row.sound) + [.volume, .flash, .preview]),
        Section(title: "Take counter",
                footer: "Reset returns Take to 1 whenever Scene or Shot changes. Next take after clap steps Take up by one after each clap, once the delay has passed, so the slate still shows the take that was just marked. A countdown shows next to the status. A manual change, a new clap or the lock cancels the pending step.",
                rows: [.resetTake, .advanceTake, .advanceDelay]),
        Section(title: "Clock timecode",
                footer: "Sets the frame count of the clock and the FPS shown on the slate. The clock is a local time-of-day reference, not camera-synchronised timecode.",
                rows: SlateSettingsStore.supportedFrameRates.map(Row.frameRate)),
        Section(title: "Slate",
                footer: "Reset returns to Scene 1, Shot A, Take 1 and keeps the written details. Both actions need the slate unlocked.",
                rows: [.editDetails, .resetCounters]),
        Section(title: "Fully Free Apps",
                footer: "Free. No ads, in-app purchases, accounts, analytics or tracking. Everything on the slate stays on this device.",
                rows: [.promise, .version])
    ]

    private let settings: SlateSettingsStore
    private let slate: SlateStore
    private let onChange: () -> Void
    private let onPreview: () -> Void
    private let volumeSlider = UISlider()
    private let flashSwitch = UISwitch()
    private let resetTakeSwitch = UISwitch()
    private let advanceTakeSwitch = UISwitch()
    private let delayStepper = UIStepper()
    private let delayLabel = UILabel()
    /// Cells are built once; shared controls must never be moved between cells.
    private var cells: [[UITableViewCell]] = []

    init(settings: SlateSettingsStore, slate: SlateStore, onChange: @escaping () -> Void, onPreview: @escaping () -> Void) {
        self.settings = settings
        self.slate = slate
        self.onChange = onChange
        self.onPreview = onPreview
        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init(settings:slate:onChange:onPreview:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Slate Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        tableView.accessibilityIdentifier = "settings-table"

        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = settings.volume
        volumeSlider.accessibilityLabel = "Slate sound volume"
        volumeSlider.accessibilityIdentifier = "volume-slider"
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)
        volumeSlider.addTarget(self, action: #selector(volumeReleased), for: [.touchUpInside, .touchUpOutside])

        for (control, isOn, label, identifier, action) in [
            (flashSwitch, settings.flashEnabled, "Screen flash", "flash-switch", #selector(flashChanged)),
            (resetTakeSwitch, settings.resetsTakeOnNewShot, "Reset take for new scene or shot", "reset-take-switch", #selector(resetTakeChanged)),
            (advanceTakeSwitch, settings.advancesTakeAfterClap, "Next take after clap", "advance-take-switch", #selector(advanceTakeChanged))
        ] {
            control.isOn = isOn
            control.accessibilityLabel = label
            control.accessibilityIdentifier = identifier
            control.addTarget(self, action: action, for: .valueChanged)
        }

        delayStepper.minimumValue = SlateSettingsStore.takeAdvanceDelays.lowerBound
        delayStepper.maximumValue = SlateSettingsStore.takeAdvanceDelays.upperBound
        delayStepper.stepValue = 1
        delayStepper.value = settings.takeAdvanceDelay
        delayStepper.accessibilityLabel = "Delay before next take"
        delayStepper.accessibilityIdentifier = "advance-delay-stepper"
        delayStepper.addTarget(self, action: #selector(delayChanged), for: .valueChanged)
        delayLabel.font = SlateStyle.mono(17, weight: .regular)
        delayLabel.textAlignment = .right
        delayLabel.accessibilityIdentifier = "advance-delay-value"

        cells = Self.sections.map { $0.rows.map(makeCell) }
        update()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }

    // MARK: Cells

    private func makeCell(for row: Row) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.adjustsFontSizeToFitWidth = true

        switch row {
        case .sound(let sound):
            cell.textLabel?.text = sound.title
            cell.accessibilityIdentifier = "sound-\(sound.rawValue)"
        case .volume:
            cell.textLabel?.text = "Volume"
            cell.selectionStyle = .none
            volumeSlider.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(volumeSlider)
            NSLayoutConstraint.activate([
                volumeSlider.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                volumeSlider.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                volumeSlider.widthAnchor.constraint(equalTo: cell.contentView.widthAnchor, multiplier: 0.55),
                cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
            ])
        case .flash:
            cell.textLabel?.text = "Screen flash"
            cell.accessoryView = flashSwitch
            cell.selectionStyle = .none
        case .preview:
            cell.textLabel?.text = "Preview sound and flash"
            cell.textLabel?.textColor = SlateStyle.accent
            cell.accessibilityIdentifier = "preview-slate"
        case .resetTake:
            cell.textLabel?.text = "Reset take for new scene or shot"
            cell.accessoryView = resetTakeSwitch
            cell.selectionStyle = .none
        case .advanceTake:
            cell.textLabel?.text = "Next take after clap"
            cell.accessoryView = advanceTakeSwitch
            cell.selectionStyle = .none
        case .advanceDelay:
            cell.textLabel?.text = "Delay"
            cell.selectionStyle = .none
            let row = UIStackView(arrangedSubviews: [delayLabel, delayStepper])
            row.axis = .horizontal
            row.alignment = .center
            row.spacing = 16
            row.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(row)
            NSLayoutConstraint.activate([
                delayLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
                row.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
                row.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
                cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
            ])
        case .frameRate(let rate):
            cell.textLabel?.text = "\(rate) fps"
            cell.accessibilityIdentifier = "fps-\(rate)"
        case .editDetails:
            cell.textLabel?.text = "Edit slate details"
            cell.accessoryType = .disclosureIndicator
            cell.accessibilityIdentifier = "edit-details"
        case .resetCounters:
            cell.textLabel?.text = "Reset scene, shot and take"
            cell.accessibilityIdentifier = "reset-counters"
        case .promise:
            cell.textLabel?.text = "Our promise"
            cell.detailTextLabel?.text = "No data collected"
            cell.selectionStyle = .none
        case .version:
            let info = Bundle.main.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
            let build = info?["CFBundleVersion"] as? String ?? "1"
            cell.textLabel?.text = "Version"
            cell.detailTextLabel?.text = "\(version) (\(build))"
            cell.selectionStyle = .none
        }
        return cell
    }

    /// Copies current state into the existing cells; nothing is reloaded or recreated.
    private func update() {
        let locked = slate.isLocked
        for (section, rows) in Self.sections.enumerated() {
            for (index, row) in rows.rows.enumerated() {
                let cell = cells[section][index]
                switch row {
                case .sound(let sound):
                    cell.accessoryType = sound == settings.sound ? .checkmark : .none
                case .advanceDelay:
                    let seconds = Int(settings.takeAdvanceDelay)
                    delayLabel.text = seconds == 0 ? "At clap" : "\(seconds) s"
                    delayStepper.accessibilityValue = delayLabel.text
                    let enabled = settings.advancesTakeAfterClap
                    delayStepper.isEnabled = enabled
                    delayLabel.textColor = enabled ? nil : SlateStyle.muted
                    cell.textLabel?.isEnabled = enabled
                case .frameRate(let rate):
                    cell.accessoryType = rate == settings.framesPerSecond ? .checkmark : .none
                case .editDetails:
                    let production = slate.details.production.trimmingCharacters(in: .whitespaces)
                    cell.detailTextLabel?.text = locked ? "Locked" : (production.isEmpty ? "Untitled" : production)
                    cell.textLabel?.isEnabled = !locked
                    cell.selectionStyle = locked ? .none : .default
                case .resetCounters:
                    cell.detailTextLabel?.text = locked ? "Locked" : SlateCounter.allCases.map(slate.displayValue).joined(separator: " · ")
                    cell.textLabel?.textColor = locked ? SlateStyle.muted : SlateStyle.danger
                    cell.selectionStyle = locked ? .none : .default
                default:
                    break
                }
            }
        }
    }

    // MARK: Table

    override func numberOfSections(in tableView: UITableView) -> Int { cells.count }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { cells[section].count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        Self.sections[section].title
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        Self.sections[section].footer
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        cells[indexPath.section][indexPath.row]
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        switch Self.sections[indexPath.section].rows[indexPath.row] {
        case .sound(let sound):
            settings.setSound(sound)
            update()
            onChange()
            onPreview()
        case .preview:
            onPreview()
        case .frameRate(let rate):
            settings.setFramesPerSecond(rate)
            update()
            onChange()
        case .editDetails:
            guard !slate.isLocked else { return }
            let editor = SlateDetailsViewController(slate: slate, focus: nil, onChange: onChange)
            navigationController?.pushViewController(editor, animated: true)
        case .resetCounters:
            guard !slate.isLocked else { return }
            confirmResetCounters(anchor: tableView.cellForRow(at: indexPath))
        default:
            break
        }
    }

    private func confirmResetCounters(anchor: UIView?) {
        let alert = UIAlertController(title: "Reset to Scene 1, Shot A, Take 1?", message: "Written details are kept.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Reset counters", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.slate.resetCounters()
            self.update()
            self.onChange()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = anchor ?? view
        alert.popoverPresentationController?.sourceRect = anchor?.bounds ?? .zero
        present(alert, animated: true)
    }

    // MARK: Controls

    @objc private func close() { dismiss(animated: true) }

    @objc private func volumeChanged() {
        settings.setVolume(volumeSlider.value)
        onChange()
    }

    /// A short preview at the new level, once the finger lifts.
    @objc private func volumeReleased() { onPreview() }

    @objc private func flashChanged() {
        settings.setFlashEnabled(flashSwitch.isOn)
        onChange()
    }

    @objc private func resetTakeChanged() {
        settings.setResetsTakeOnNewShot(resetTakeSwitch.isOn)
        onChange()
    }

    @objc private func advanceTakeChanged() {
        settings.setAdvancesTakeAfterClap(advanceTakeSwitch.isOn)
        update()
        onChange()
    }

    @objc private func delayChanged() {
        settings.setTakeAdvanceDelay(delayStepper.value)
        update()
        onChange()
    }
}
