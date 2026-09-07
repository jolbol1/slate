import UIKit

final class SlateSettingsViewController: UITableViewController {
    private let settings: SlateSettingsStore
    private let onChange: () -> Void
    private let onPreview: () -> Void
    private let volumeSlider = UISlider()
    private let flashSwitch = UISwitch()

    init(settings: SlateSettingsStore, onChange: @escaping () -> Void, onPreview: @escaping () -> Void) {
        self.settings = settings
        self.onChange = onChange
        self.onPreview = onPreview
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) { fatalError("Use init(settings:onChange:onPreview:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Slate Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(close)
        )
        tableView.accessibilityIdentifier = "settings-table"

        volumeSlider.minimumValue = 0
        volumeSlider.maximumValue = 1
        volumeSlider.value = settings.volume
        volumeSlider.accessibilityLabel = "Slate sound volume"
        volumeSlider.accessibilityIdentifier = "volume-slider"
        volumeSlider.addTarget(self, action: #selector(volumeChanged), for: .valueChanged)

        flashSwitch.isOn = settings.flashEnabled
        flashSwitch.accessibilityLabel = "Screen flash"
        flashSwitch.accessibilityIdentifier = "flash-switch"
        flashSwitch.addTarget(self, action: #selector(flashChanged), for: .valueChanged)
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 4 }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return SlateSound.allCases.count
        case 1: return 3
        case 2: return SlateSettingsStore.supportedFrameRates.count
        default: return 1
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Slate sound"
        case 1: return "Output"
        case 2: return "Clock timecode"
        default: return "Fully Free Apps"
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "Clap gives a natural sync point. Beep is easier to hear in noisy rooms."
        case 1: return "Sound uses the iPad's media volume and plays with Silent Mode on. The screen flash marks the same instant."
        case 2: return "This is a visual time-of-day reference, not camera-synchronised timecode."
        default: return "Free. No ads, in-app purchases, accounts, analytics or tracking. Settings stay on this iPad."
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.textLabel?.adjustsFontSizeToFitWidth = true

        switch indexPath.section {
        case 0:
            let sound = SlateSound.allCases[indexPath.row]
            cell.textLabel?.text = sound.title
            cell.accessoryType = sound == settings.sound ? .checkmark : .none
            cell.accessibilityIdentifier = "sound-\(sound.rawValue)"
        case 1 where indexPath.row == 0:
            cell.textLabel?.text = "Volume"
            volumeSlider.frame = CGRect(x: 0, y: 0, width: 190, height: 34)
            cell.accessoryView = volumeSlider
            cell.selectionStyle = .none
        case 1 where indexPath.row == 1:
            cell.textLabel?.text = "Screen flash"
            cell.accessoryView = flashSwitch
            cell.selectionStyle = .none
        case 1:
            cell.textLabel?.text = "Preview sound + flash"
            cell.textLabel?.textAlignment = .center
            cell.accessibilityIdentifier = "preview-slate"
        case 2:
            let frameRate = SlateSettingsStore.supportedFrameRates[indexPath.row]
            cell.textLabel?.text = "\(frameRate) fps"
            cell.accessoryType = frameRate == settings.framesPerSecond ? .checkmark : .none
            cell.accessibilityIdentifier = "fps-\(frameRate)"
        default:
            cell.textLabel?.text = "Our promise"
            cell.detailTextLabel?.text = "No data collected"
            cell.selectionStyle = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        defer { tableView.deselectRow(at: indexPath, animated: true) }
        switch indexPath.section {
        case 0:
            settings.setSound(SlateSound.allCases[indexPath.row])
            tableView.reloadSections(IndexSet(integer: 0), with: .none)
            onChange()
            onPreview()
        case 1 where indexPath.row == 2:
            onPreview()
        case 2:
            settings.setFramesPerSecond(SlateSettingsStore.supportedFrameRates[indexPath.row])
            tableView.reloadSections(IndexSet(integer: 2), with: .none)
            onChange()
        default:
            break
        }
    }

    @objc private func close() { dismiss(animated: true) }

    @objc private func volumeChanged() {
        settings.setVolume(volumeSlider.value)
        onChange()
    }

    @objc private func flashChanged() {
        settings.setFlashEnabled(flashSwitch.isOn)
        onChange()
    }
}
