import UIKit

/// Palette, type and small reusable controls. Everything here runs on iOS 12.
enum SlateStyle {
    static let background = UIColor(red: 0.035, green: 0.043, blue: 0.047, alpha: 1)
    static let card = UIColor.white.withAlphaComponent(0.045)
    static let surface = UIColor.white.withAlphaComponent(0.08)
    static let surfaceStrong = UIColor.white.withAlphaComponent(0.14)
    static let ink = UIColor(red: 0.96, green: 0.95, blue: 0.91, alpha: 1)
    static let muted = UIColor(red: 0.55, green: 0.58, blue: 0.58, alpha: 1)
    static let accent = UIColor(red: 1, green: 0.65, blue: 0.25, alpha: 1)
    static let rule = UIColor.white.withAlphaComponent(0.14)
    static let danger = UIColor(red: 1, green: 0.42, blue: 0.36, alpha: 1)

    static func rounded(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if #available(iOS 13.0, *), let descriptor = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: descriptor, size: size)
        }
        return base
    }

    static func mono(_ size: CGFloat, weight: UIFont.Weight) -> UIFont {
        .monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    static func caption(_ text: String, size: CGFloat = 11, weight: UIFont.Weight = .semibold,
                        color: UIColor = muted, kern: CGFloat = 1.6) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .kern: kern,
            .foregroundColor: color
        ])
    }

    static func roundCorners(_ view: UIView, radius: CGFloat) {
        view.layer.cornerRadius = radius
        if #available(iOS 13.0, *) { view.layer.cornerCurve = .continuous }
    }

    /// A 1pt hairline used between slate regions.
    static func rule(vertical: Bool = false) -> UIView {
        let line = UIView()
        line.backgroundColor = rule
        line.translatesAutoresizingMaskIntoConstraints = false
        (vertical ? line.widthAnchor : line.heightAnchor).constraint(equalToConstant: 1).isActive = true
        return line
    }
}

/// Rounded pill button used for lock, settings and +/− steps.
final class SlatePillButton: UIButton {
    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    convenience init(title: String, font: UIFont) {
        self.init(type: .custom)
        setTitle(title, for: .normal)
        titleLabel?.font = font
        setTitleColor(SlateStyle.ink, for: .normal)
        setTitleColor(SlateStyle.ink.withAlphaComponent(0.22), for: .disabled)
        backgroundColor = SlateStyle.surface
        layer.borderWidth = 1
        layer.borderColor = SlateStyle.rule.cgColor
        translatesAutoresizingMaskIntoConstraints = false
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        SlateStyle.roundCorners(self, radius: min(bounds.height / 2, 22))
    }
}

/// Small tag such as "ROLL A001", or a two-way toggle such as "INT / EXT" with the active option lit.
final class SlateChip: UIButton {
    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = SlateStyle.surface
        // Extra trailing room: the kerned title measures narrower than it draws.
        contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 16)
        titleLabel?.lineBreakMode = .byClipping
        heightAnchor.constraint(equalToConstant: 32).isActive = true
        SlateStyle.roundCorners(self, radius: 16)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    /// UIButton measures kerned attributed titles a few points short of how they draw,
    /// so give the title the whole content area and a little extra width.
    override var intrinsicContentSize: CGSize {
        var size = super.intrinsicContentSize
        size.width += 8
        return size
    }

    override func titleRect(forContentRect contentRect: CGRect) -> CGRect { contentRect }

    func show(key: String, value: String, isPlaceholder: Bool = false) {
        let text = NSMutableAttributedString(attributedString: SlateStyle.caption(key, size: 10, kern: 1.4))
        text.append(NSAttributedString(string: "  "))
        text.append(NSAttributedString(string: value, attributes: [
            .font: SlateStyle.mono(14, weight: .bold),
            .foregroundColor: isPlaceholder ? SlateStyle.muted : SlateStyle.ink
        ]))
        setAttributedTitle(text, for: .normal)
        accessibilityValue = value
    }

    func show(options: [String], selected: Int) {
        let text = NSMutableAttributedString()
        for (index, option) in options.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(string: "  /  ", attributes: [
                    .font: UIFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: SlateStyle.muted.withAlphaComponent(0.5)
                ]))
            }
            let active = index == selected
            text.append(NSAttributedString(string: option, attributes: [
                .font: UIFont.systemFont(ofSize: 12, weight: active ? .heavy : .semibold),
                .kern: 1.2,
                .foregroundColor: active ? SlateStyle.ink : SlateStyle.muted.withAlphaComponent(0.55)
            ]))
        }
        setAttributedTitle(text, for: .normal)
        accessibilityValue = options[selected]
    }
}

/// A caption above a value line, like one handwritten line on a slate. Tap to edit.
final class SlateFieldView: UIControl {
    let field: SlateTextField
    private let captionLabel = UILabel()
    private let valueLabel = UILabel()

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    init(field: SlateTextField) {
        self.field = field
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = field.title
        accessibilityIdentifier = "field-\(field.rawValue)"
        captionLabel.attributedText = SlateStyle.caption(field.title.uppercased())
        valueLabel.font = SlateStyle.rounded(19, weight: .semibold)
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7
        valueLabel.lineBreakMode = .byTruncatingTail
        for label in [captionLabel, valueLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.isUserInteractionEnabled = false
            addSubview(label)
        }
        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            captionLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            captionLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor),
            valueLabel.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 4),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Use init(field:)") }

    func show(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            valueLabel.text = field.placeholder
            valueLabel.textColor = SlateStyle.muted.withAlphaComponent(0.7)
            accessibilityValue = "Empty"
        } else {
            valueLabel.text = field.isUppercased ? trimmed.uppercased() : trimmed
            valueLabel.textColor = SlateStyle.ink
            accessibilityValue = trimmed
        }
    }
}

/// Diagonal clapper-stick stripes.
final class SlateStripesView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.09, green: 0.10, blue: 0.11, alpha: 1)
        contentMode = .redraw
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }

    required init?(coder: NSCoder) { fatalError("Use init(frame:)") }

    override func draw(_ rect: CGRect) {
        let band = max(18, bounds.height * 0.42)
        let skew = bounds.height
        SlateStyle.ink.withAlphaComponent(0.92).setFill()
        var x = -skew
        while x < bounds.width {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: x, y: bounds.maxY))
            path.addLine(to: CGPoint(x: x + band, y: bounds.maxY))
            path.addLine(to: CGPoint(x: x + band + skew, y: 0))
            path.addLine(to: CGPoint(x: x + skew, y: 0))
            path.close()
            path.fill()
            x += band * 2
        }
    }
}

/// The clapper sticks. Tapping anywhere on the bar plays the slate sound.
final class SlateClapButton: UIControl {
    private let stripes = SlateStripesView()
    private let pill = UIView()
    private let pillLabel = UILabel()

    var title: String = "" {
        didSet {
            pillLabel.attributedText = SlateStyle.caption(title, size: 13, weight: .heavy, color: SlateStyle.background, kern: 2.2)
        }
    }

    override var isHighlighted: Bool {
        didSet { stripes.alpha = isHighlighted ? 0.7 : 1 }
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        clipsToBounds = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        SlateStyle.roundCorners(self, radius: 18)
        stripes.translatesAutoresizingMaskIntoConstraints = false
        pill.translatesAutoresizingMaskIntoConstraints = false
        pill.backgroundColor = SlateStyle.accent
        pill.isUserInteractionEnabled = false
        SlateStyle.roundCorners(pill, radius: 17)
        pillLabel.translatesAutoresizingMaskIntoConstraints = false
        pillLabel.textAlignment = .center
        addSubview(stripes)
        addSubview(pill)
        pill.addSubview(pillLabel)
        NSLayoutConstraint.activate([
            stripes.topAnchor.constraint(equalTo: topAnchor),
            stripes.bottomAnchor.constraint(equalTo: bottomAnchor),
            stripes.leadingAnchor.constraint(equalTo: leadingAnchor),
            stripes.trailingAnchor.constraint(equalTo: trailingAnchor),
            pill.centerXAnchor.constraint(equalTo: centerXAnchor),
            pill.centerYAnchor.constraint(equalTo: centerYAnchor),
            pill.heightAnchor.constraint(equalToConstant: 34),
            pillLabel.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 22),
            pillLabel.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -22),
            pillLabel.centerYAnchor.constraint(equalTo: pill.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("Use init()") }

    /// The sticks drop and settle, like a real clap.
    func animateClap() {
        layer.removeAllAnimations()
        transform = .identity
        UIView.animate(withDuration: 0.05, delay: 0, options: [.curveEaseIn, .allowUserInteraction], animations: {
            self.transform = CGAffineTransform(translationX: 0, y: 6).scaledBy(x: 1, y: 0.9)
        }, completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.45, initialSpringVelocity: 0.8,
                           options: [.allowUserInteraction], animations: { self.transform = .identity }, completion: nil)
        })
    }
}

/// One counter card: caption, big value, and −/+ steps.
final class CounterView: UIView {
    let counter: SlateCounter
    var compact = false {
        didSet { setNeedsLayout() }
    }
    var onStep: ((Int) -> Void)?
    private let captionLabel = UILabel()
    private let numberLabel = UILabel()
    private let minusButton = SlatePillButton(title: "−", font: SlateStyle.rounded(30, weight: .medium))
    private let plusButton = SlatePillButton(title: "+", font: SlateStyle.rounded(30, weight: .medium))

    init(counter: SlateCounter) {
        self.counter = counter
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = SlateStyle.card
        layer.borderWidth = 1
        layer.borderColor = SlateStyle.rule.cgColor
        SlateStyle.roundCorners(self, radius: 22)

        captionLabel.attributedText = SlateStyle.caption(counter.title.uppercased(), size: 13, kern: 3)
        captionLabel.isAccessibilityElement = false
        numberLabel.textColor = SlateStyle.ink
        numberLabel.adjustsFontSizeToFitWidth = true
        numberLabel.minimumScaleFactor = 0.18
        numberLabel.numberOfLines = 1
        numberLabel.baselineAdjustment = .alignCenters
        numberLabel.accessibilityLabel = counter.title
        numberLabel.accessibilityIdentifier = "number-\(counter.rawValue)"

        for (button, name) in [(minusButton, "minus"), (plusButton, "plus")] {
            button.translatesAutoresizingMaskIntoConstraints = true
            button.accessibilityLabel = counter == .shot
                ? "\(name == "plus" ? "Next" : "Previous") shot letter"
                : "\(name == "plus" ? "Increase" : "Decrease") \(counter.rawValue)"
            button.accessibilityIdentifier = "\(counter.rawValue)-\(name)"
        }
        minusButton.addTarget(self, action: #selector(decrease), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(increase), for: .touchUpInside)
        for child in [captionLabel, numberLabel, minusButton, plusButton] { addSubview(child) }
    }

    required init?(coder: NSCoder) { fatalError("Use init(counter:)") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 16
        if compact {
            captionLabel.textAlignment = .left
            numberLabel.textAlignment = .left
            let buttonWidth: CGFloat = 60
            let buttonHeight: CGFloat = min(52, bounds.height - 24)
            plusButton.frame = CGRect(x: bounds.width - inset - buttonWidth, y: bounds.midY - buttonHeight / 2, width: buttonWidth, height: buttonHeight)
            minusButton.frame = CGRect(x: plusButton.frame.minX - 8 - buttonWidth, y: plusButton.frame.minY, width: buttonWidth, height: buttonHeight)
            let textWidth = minusButton.frame.minX - inset - 12
            captionLabel.frame = CGRect(x: inset, y: 12, width: textWidth, height: 18)
            numberLabel.frame = CGRect(x: inset, y: 28, width: textWidth, height: max(0, bounds.height - 34))
            numberLabel.font = SlateStyle.mono(min(170, bounds.height * 0.66), weight: .semibold)
        } else {
            let short = bounds.height < 260
            captionLabel.textAlignment = .center
            numberLabel.textAlignment = .center
            captionLabel.frame = CGRect(x: inset, y: short ? 10 : 20, width: bounds.width - inset * 2, height: 18)
            let buttonHeight: CGFloat = short ? 44 : 58
            let buttonBottom: CGFloat = short ? 10 : 16
            let buttonY = bounds.height - buttonBottom - buttonHeight
            let buttonWidth = min(104, (bounds.width - inset * 2 - 8) / 2)
            minusButton.frame = CGRect(x: bounds.midX - buttonWidth - 4, y: buttonY, width: buttonWidth, height: buttonHeight)
            plusButton.frame = CGRect(x: bounds.midX + 4, y: buttonY, width: buttonWidth, height: buttonHeight)
            let numberTop = captionLabel.frame.maxY + (short ? 2 : 6)
            numberLabel.frame = CGRect(x: inset, y: numberTop, width: bounds.width - inset * 2, height: max(0, buttonY - numberTop - 6))
            numberLabel.font = SlateStyle.mono(min(300, numberLabel.frame.height * 0.92), weight: .semibold)
        }
    }

    func refresh(slate: SlateStore) {
        numberLabel.text = slate.displayValue(for: counter)
        numberLabel.accessibilityValue = numberLabel.text
        for (button, step) in [(minusButton, -1), (plusButton, 1)] {
            let enabled = slate.canChange(counter, by: step)
            button.isEnabled = enabled
            button.backgroundColor = enabled ? SlateStyle.surface : UIColor.white.withAlphaComponent(0.02)
            button.layer.borderColor = UIColor.white.withAlphaComponent(enabled ? 0.14 : 0.04).cgColor
        }
    }

    @objc private func decrease() { onStep?(-1) }
    @objc private func increase() { onStep?(1) }
}
