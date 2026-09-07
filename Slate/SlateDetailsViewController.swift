import UIKit

/// Form for every written line on the slate. Each keystroke saves immediately.
final class SlateDetailsViewController: UITableViewController, UITextFieldDelegate {
    private enum Row {
        case text(SlateTextField)
        case camera, location, timeOfDay, soundMode, clear
    }

    private struct Section {
        let title: String?
        let footer: String?
        let rows: [Row]
    }

    private static let sections = [
        Section(title: "Production", footer: nil,
                rows: [.text(.production), .text(.director), .text(.cameraOperator)]),
        Section(title: "Camera", footer: "Roll is the camera card or magazine in use, for example A001.",
                rows: [.camera, .text(.roll), .text(.filter)]),
        Section(title: "Sound", footer: "MOS marks a take recorded without sound.",
                rows: [.text(.soundRoll), .soundMode]),
        Section(title: "Scene", footer: nil,
                rows: [.location, .timeOfDay, .text(.notes)]),
        Section(title: nil, footer: "Scene, shot and take are set on the slate itself.",
                rows: [.clear])
    ]

    private let slate: SlateStore
    private let focus: SlateTextField?
    private let onChange: () -> Void
    private var textFields: [SlateTextField: UITextField] = [:]
    private let cameraStepper = UIStepper()
    private let cameraLabel = UILabel()
    private let locationControl = UISegmentedControl(items: SlateLocation.allCases.map { $0.title })
    private let timeControl = UISegmentedControl(items: SlateTimeOfDay.allCases.map { $0.title })
    private let soundControl = UISegmentedControl(items: SlateSoundMode.allCases.map { $0.title })
    private var cells: [[UITableViewCell]] = []
    private var didFocus = false

    init(slate: SlateStore, focus: SlateTextField?, onChange: @escaping () -> Void) {
        self.slate = slate
        self.focus = focus
        self.onChange = onChange
        if #available(iOS 13.0, *) {
            super.init(style: .insetGrouped)
        } else {
            super.init(style: .grouped)
        }
    }

    required init?(coder: NSCoder) { fatalError("Use init(slate:focus:onChange:)") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Slate Details"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(close))
        tableView.accessibilityIdentifier = "details-table"
        tableView.keyboardDismissMode = .interactive

        cameraStepper.minimumValue = 0
        cameraStepper.maximumValue = Double(SlateDetails.cameraLetters.count - 1)
        cameraStepper.stepValue = 1
        cameraStepper.wraps = true
        cameraStepper.addTarget(self, action: #selector(cameraChanged), for: .valueChanged)
        locationControl.addTarget(self, action: #selector(locationChanged), for: .valueChanged)
        timeControl.addTarget(self, action: #selector(timeChanged), for: .valueChanged)
        soundControl.addTarget(self, action: #selector(soundChanged), for: .valueChanged)
        cameraStepper.accessibilityIdentifier = "camera-stepper"
        cameraStepper.accessibilityLabel = "Camera letter"
        locationControl.accessibilityIdentifier = "location-control"
        timeControl.accessibilityIdentifier = "time-control"
        soundControl.accessibilityIdentifier = "sound-mode-control"

        cells = Self.sections.map { $0.rows.map(makeCell) }
        load()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didFocus, let focus = focus else { return }
        didFocus = true
        self.focus(focus)
    }

    /// Rows that are scrolled away are not in the view hierarchy, so bring the row on screen first.
    private func focus(_ field: SlateTextField) {
        if let indexPath = indexPath(of: field) {
            tableView.scrollToRow(at: indexPath, at: .none, animated: false)
            tableView.layoutIfNeeded()
        }
        textFields[field]?.becomeFirstResponder()
    }

    private func indexPath(of field: SlateTextField) -> IndexPath? {
        for (section, entry) in Self.sections.enumerated() {
            for (row, item) in entry.rows.enumerated() {
                if case .text(let candidate) = item, candidate == field { return IndexPath(row: row, section: section) }
            }
        }
        return nil
    }

    /// Copies the store into every control; used on open and after a clear.
    private func load() {
        let details = slate.details
        for (field, textField) in textFields { textField.text = details[field] }
        cameraStepper.value = Double(details.camera)
        showCameraLetter()
        locationControl.selectedSegmentIndex = SlateLocation.allCases.firstIndex(of: details.location) ?? 0
        timeControl.selectedSegmentIndex = SlateTimeOfDay.allCases.firstIndex(of: details.timeOfDay) ?? 0
        soundControl.selectedSegmentIndex = SlateSoundMode.allCases.firstIndex(of: details.soundMode) ?? 0
    }

    private func makeCell(for row: Row) -> UITableViewCell {
        switch row {
        case .text(let field):
            let cell = TextFieldCell(field: field)
            cell.textField.delegate = self
            cell.textField.addTarget(self, action: #selector(textChanged(_:)), for: .editingChanged)
            textFields[field] = cell.textField
            return cell
        case .camera: return cameraCell()
        case .location: return segmentCell("Location", control: locationControl)
        case .timeOfDay: return segmentCell("Time", control: timeControl)
        case .soundMode: return segmentCell("Sound", control: soundControl)
        case .clear:
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Clear all details"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = SlateStyle.danger
            cell.accessibilityIdentifier = "clear-details"
            return cell
        }
    }

    /// "Camera  A  [− +]": any of the 26 letters is a few taps away, and the stepper wraps.
    private func cameraCell() -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = "Camera"
        cell.selectionStyle = .none
        cameraLabel.font = SlateStyle.mono(22, weight: .semibold)
        cameraLabel.textAlignment = .center
        cameraLabel.accessibilityIdentifier = "camera-letter"
        let row = UIStackView(arrangedSubviews: [cameraLabel, cameraStepper])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 16
        row.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            cameraLabel.widthAnchor.constraint(equalToConstant: 32),
            row.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            row.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
        return cell
    }

    private func showCameraLetter() {
        cameraLabel.text = slate.details.cameraLetter
        cameraStepper.accessibilityValue = "Camera \(slate.details.cameraLetter)"
    }

    private func segmentCell(_ title: String, control: UISegmentedControl) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = title
        cell.selectionStyle = .none
        control.apportionsSegmentWidthsByContent = false
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(control)
        NSLayoutConstraint.activate([
            control.trailingAnchor.constraint(equalTo: cell.contentView.layoutMarginsGuide.trailingAnchor),
            control.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            control.widthAnchor.constraint(equalTo: cell.contentView.widthAnchor, multiplier: 0.5),
            cell.contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
        return cell
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
        tableView.deselectRow(at: indexPath, animated: true)
        switch Self.sections[indexPath.section].rows[indexPath.row] {
        case .text(let field):
            focus(field)
        case .clear:
            confirmClear(anchor: tableView.cellForRow(at: indexPath))
        default:
            break
        }
    }

    private func confirmClear(anchor: UIView?) {
        let alert = UIAlertController(title: "Clear all slate details?", message: "Production, names, rolls, filter and notes are emptied. Scene, shot and take are kept.", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Clear details", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.view.endEditing(true)
            self.slate.clearDetails()
            self.load()
            self.onChange()
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.popoverPresentationController?.sourceView = anchor ?? view
        alert.popoverPresentationController?.sourceRect = anchor?.bounds ?? .zero
        present(alert, animated: true)
    }

    // MARK: Text entry

    @objc private func textChanged(_ textField: UITextField) {
        guard let cell = textField.superview?.superview as? TextFieldCell ?? textField.superview?.superview?.superview as? TextFieldCell else { return }
        slate.setText(textField.text ?? "", for: cell.field)
        onChange()
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let field = textFields.first(where: { $0.value === textField })?.key else { return true }
        let current = textField.text ?? ""
        guard let swiftRange = Range(range, in: current) else { return true }
        let updated = current.replacingCharacters(in: swiftRange, with: string)
        return updated.count <= field.maxLength
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        let ordered = Self.sections.flatMap { $0.rows }.compactMap { row -> SlateTextField? in
            if case .text(let field) = row { return field }
            return nil
        }
        if let index = ordered.firstIndex(where: { textFields[$0] === textField }), index + 1 < ordered.count {
            focus(ordered[index + 1])
        } else {
            textField.resignFirstResponder()
        }
        return true
    }

    // MARK: Segments

    @objc private func cameraChanged() {
        slate.setCamera(Int(cameraStepper.value))
        showCameraLetter()
        onChange()
    }

    @objc private func locationChanged() {
        slate.setLocation(SlateLocation.allCases[locationControl.selectedSegmentIndex])
        onChange()
    }

    @objc private func timeChanged() {
        slate.setTimeOfDay(SlateTimeOfDay.allCases[timeControl.selectedSegmentIndex])
        onChange()
    }

    @objc private func soundChanged() {
        slate.setSoundMode(SlateSoundMode.allCases[soundControl.selectedSegmentIndex])
        onChange()
    }

    @objc private func close() {
        view.endEditing(true)
        dismiss(animated: true)
    }
}

/// A caption on the left and a text field that fills the rest of the row.
private final class TextFieldCell: UITableViewCell {
    let field: SlateTextField
    let textField = UITextField()

    init(field: SlateTextField) {
        self.field = field
        super.init(style: .default, reuseIdentifier: nil)
        selectionStyle = .none
        let caption = UILabel()
        caption.text = field.title
        caption.font = .systemFont(ofSize: 17)
        caption.setContentHuggingPriority(.required, for: .horizontal)
        caption.setContentCompressionResistancePriority(.required, for: .horizontal)
        caption.translatesAutoresizingMaskIntoConstraints = false
        caption.widthAnchor.constraint(equalToConstant: 104).isActive = true

        textField.placeholder = field.placeholder
        textField.font = .systemFont(ofSize: 17)
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = field == .notes ? .done : .next
        textField.autocorrectionType = field == .notes ? .default : .no
        textField.spellCheckingType = .no
        textField.accessibilityLabel = field.title
        textField.accessibilityIdentifier = "text-\(field.rawValue)"
        switch field {
        case .roll, .soundRoll, .filter:
            textField.autocapitalizationType = .allCharacters
        case .notes:
            textField.autocapitalizationType = .sentences
        default:
            textField.autocapitalizationType = .words
        }
        if field == .director || field == .cameraOperator { textField.textContentType = .name }
        textField.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [caption, textField])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            row.topAnchor.constraint(equalTo: contentView.topAnchor),
            row.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Use init(field:)") }
}
