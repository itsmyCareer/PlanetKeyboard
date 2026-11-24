import UIKit

/// The key area, in UIKit for real multi-touch: fast two-thumb typing ("rollover"), keys that
/// fire on touch-down (backspace, shift), long-press space as a cursor trackpad, and
/// backspace auto-repeat that speeds up to whole words — like the system keyboard.
final class KeysView: UIView {

    enum BackspaceStep { case character, word }

    // MARK: Callbacks (set by KeyboardViewController)

    /// Touch-down on any key (haptic / click).
    var onKeyDown: ((KeyDefinition) -> Void)?
    /// The key action itself.
    var onKey: ((KeyDefinition) -> Void)?
    var onBackspaceRepeat: ((BackspaceStep) -> Void)?
    /// Trackpad started (true) / ended (false).
    var onTrackpad: ((Bool) -> Void)?
    /// Move the cursor by this many characters (negative = left).
    var onCursorMove: ((Int) -> Void)?
    /// Whether the space bar may become a trackpad right now (false while Pinyin composes).
    var canStartTrackpad: () -> Bool = { true }

    // MARK: State

    var rows: [KeyRow] = [] {
        didSet { if rows != oldValue { rebuildCaps() } }
    }
    var metrics: KeyboardMetrics = .portrait {
        didSet { if metrics != oldValue { setNeedsLayout() } }
    }
    var shiftState: EnglishEngine.ShiftState = .off {
        didSet { if shiftState != oldValue { updateShiftCaps() } }
    }

    private var caps: [KeyCapView] = []
    private var keys: [KeyDefinition] = []
    private var frames: [CGRect] = []

    private struct ActiveTouch {
        var index: Int
        var start: CGPoint
        var committed: Bool
    }
    private var active: [ObjectIdentifier: ActiveTouch] = [:]

    // Trackpad
    private var trackpadTouch: ObjectIdentifier?
    private var trackpadAnchorX: CGFloat = 0
    private var spaceHoldTimer: Timer?
    private static let trackpadStep: CGFloat = 10
    private static let trackpadHoldDelay: TimeInterval = 0.35
    private static let trackpadSlideStart: CGFloat = 14

    // Backspace repeat
    private var backspaceTimer: Timer?
    private var backspaceStart: CFTimeInterval = 0
    private static let repeatDelay: TimeInterval = 0.45
    private static let repeatInterval: TimeInterval = 0.085
    private static let wordModeAfter: TimeInterval = 1.9
    private static let wordInterval: TimeInterval = 0.22

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // MARK: - Building

    private func rebuildCaps() {
        cancelAllTouches()
        caps.forEach { $0.removeFromSuperview() }
        caps = []
        keys = rows.flatMap(\.keys)
        for key in keys {
            let cap = KeyCapView(key: key)
            cap.isHidden = key.isSpacer
            addSubview(cap)
            caps.append(cap)
        }
        updateShiftCaps()
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        frames = []
        for (i, row) in rows.enumerated() {
            let y = metrics.topPadding + CGFloat(i) * (metrics.keyHeight + metrics.rowGap)
            frames += RowLayout.frames(for: row, width: bounds.width, y: y, metrics: metrics)
        }
        for (cap, frame) in zip(caps, frames) { cap.frame = frame }
    }

    private func updateShiftCaps() {
        for cap in caps where cap.key.type == .shift {
            switch shiftState {
            case .off: cap.setIcon("shift", highlighted: false)
            case .once: cap.setIcon("shift.fill", highlighted: true)
            case .locked: cap.setIcon("capslock.fill", highlighted: true)
            }
        }
    }

    // MARK: - Hit testing

    /// Index of the key for a point. Gaps between keys belong to the nearest key, so a touch
    /// is never lost (the system keyboard behaves the same).
    func keyIndex(at point: CGPoint) -> Int? {
        var best: (index: Int, distance: CGFloat)?
        for (i, frame) in frames.enumerated() where !keys[i].isSpacer {
            let rowBand = frame.insetBy(dx: 0, dy: -metrics.rowGap / 2 - 1)
            let dy = point.y < rowBand.minY ? rowBand.minY - point.y : (point.y > rowBand.maxY ? point.y - rowBand.maxY : 0)
            let dx = point.x < frame.minX ? frame.minX - point.x : (point.x > frame.maxX ? point.x - frame.maxX : 0)
            let d = dy * 1000 + dx    // stay in the touched row first
            if best == nil || d < best!.distance { best = (i, d) }
        }
        return best?.index
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            guard trackpadTouch == nil, let index = keyIndex(at: point) else { continue }
            let key = keys[index]
            guard key.isEnabled else { continue }

            // Rollover: a new finger commits keys still held by other fingers.
            for (id, var other) in active where !other.committed && keys[other.index].type == .character {
                fire(other.index)
                other.committed = true
                active[id] = other
            }

            onKeyDown?(key)
            caps[index].isPressed = true
            var state = ActiveTouch(index: index, start: point, committed: false)

            switch key.type {
            case .backspace:
                fire(index)
                state.committed = true
                startBackspaceRepeat()
            case .shift:
                // Shift reacts on touch-down like iOS (fast double-tap = caps lock).
                fire(index)
                state.committed = true
            case .space:
                startSpaceHold(for: touch)
            default:
                break
            }
            active[ObjectIdentifier(touch)] = state
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            let point = touch.location(in: self)
            if trackpadTouch == id {
                moveTrackpad(to: point.x)
                continue
            }
            guard var state = active[id], !state.committed else { continue }
            let key = keys[state.index]
            if key.type == .space {
                if abs(point.x - state.start.x) > Self.trackpadSlideStart, canStartTrackpad() {
                    beginTrackpad(touch: touch, x: point.x)
                }
                continue
            }
            // Sliding to a neighbour character key types the key under the finger on release.
            if key.type == .character, let index = keyIndex(at: point), index != state.index,
               keys[index].type == .character {
                caps[state.index].isPressed = false
                caps[index].isPressed = true
                state.index = index
                active[id] = state
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if trackpadTouch == id {
                endTrackpad()
                active[id] = nil
                continue
            }
            guard let state = active.removeValue(forKey: id) else { continue }
            caps[state.index].isPressed = false
            if keys[state.index].type == .backspace { stopBackspaceRepeat() }
            if keys[state.index].type == .space { cancelSpaceHold() }
            if !state.committed { fire(state.index) }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let id = ObjectIdentifier(touch)
            if trackpadTouch == id { endTrackpad() }
            if let state = active.removeValue(forKey: id) {
                caps[state.index].isPressed = false
                if keys[state.index].type == .backspace { stopBackspaceRepeat() }
                if keys[state.index].type == .space { cancelSpaceHold() }
            }
        }
    }

    private func fire(_ index: Int) {
        onKey?(keys[index])
    }

    private func cancelAllTouches() {
        if trackpadTouch != nil { endTrackpad() }
        stopBackspaceRepeat()
        cancelSpaceHold()
        active.removeAll()
    }

    // MARK: - Space → trackpad

    private func startSpaceHold(for touch: UITouch) {
        cancelSpaceHold()
        spaceHoldTimer = Timer.scheduledTimer(withTimeInterval: Self.trackpadHoldDelay, repeats: false) { [weak self, weak touch] _ in
            guard let self, let touch, self.active[ObjectIdentifier(touch)] != nil, self.canStartTrackpad() else { return }
            self.beginTrackpad(touch: touch, x: touch.location(in: self).x)
        }
    }

    private func cancelSpaceHold() {
        spaceHoldTimer?.invalidate()
        spaceHoldTimer = nil
    }

    private func beginTrackpad(touch: UITouch, x: CGFloat) {
        cancelSpaceHold()
        let id = ObjectIdentifier(touch)
        guard trackpadTouch == nil, var state = active[id] else { return }
        state.committed = true          // no space is typed
        active[id] = state
        trackpadTouch = id
        trackpadAnchorX = x
        caps[state.index].isPressed = false
        UIView.animate(withDuration: 0.15) { self.caps.forEach { $0.contentAlpha = 0 } }
        onTrackpad?(true)
    }

    private func moveTrackpad(to x: CGFloat) {
        let delta = x - trackpadAnchorX
        let steps = Int(delta / Self.trackpadStep)
        guard steps != 0 else { return }
        trackpadAnchorX += CGFloat(steps) * Self.trackpadStep
        onCursorMove?(steps)
    }

    private func endTrackpad() {
        trackpadTouch = nil
        UIView.animate(withDuration: 0.15) { self.caps.forEach { $0.contentAlpha = 1 } }
        onTrackpad?(false)
    }

    // MARK: - Backspace repeat

    private func startBackspaceRepeat() {
        stopBackspaceRepeat()
        backspaceStart = CACurrentMediaTime()
        backspaceTimer = Timer.scheduledTimer(withTimeInterval: Self.repeatDelay, repeats: false) { [weak self] _ in
            self?.scheduleRepeat(interval: Self.repeatInterval)
        }
    }

    private func scheduleRepeat(interval: TimeInterval) {
        backspaceTimer?.invalidate()
        backspaceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let held = CACurrentMediaTime() - self.backspaceStart
            if held >= Self.wordModeAfter {
                if interval != Self.wordInterval {
                    self.scheduleRepeat(interval: Self.wordInterval)
                    return
                }
                self.onBackspaceRepeat?(.word)
            } else {
                self.onBackspaceRepeat?(.character)
            }
        }
        backspaceTimer?.fire()
    }

    private func stopBackspaceRepeat() {
        backspaceTimer?.invalidate()
        backspaceTimer = nil
    }
}

// MARK: - Key cap

final class KeyCapView: UIView {
    let key: KeyDefinition
    private let label = UILabel()
    private let imageView = UIImageView()
    private var iconHighlighted = false

    var isPressed = false { didSet { if isPressed != oldValue { updateColors() } } }
    var contentAlpha: CGFloat = 1 {
        didSet { label.alpha = contentAlpha; imageView.alpha = contentAlpha }
    }

    init(key: KeyDefinition) {
        self.key = key
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        layer.cornerRadius = 8
        layer.cornerCurve = .continuous
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.28
        layer.shadowRadius = 0
        layer.shadowOffset = CGSize(width: 0, height: 1)

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        label.text = key.label
        label.font = Self.font(for: key)
        addSubview(label)

        imageView.contentMode = .center
        addSubview(imageView)
        if let icon = key.icon { setIcon(icon, highlighted: false) }
        isAccessibilityElement = true
        accessibilityLabel = key.label
        accessibilityTraits = .keyboardKey
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func setIcon(_ name: String, highlighted: Bool) {
        let weight: UIImage.SymbolWeight = key.type == .language ? .regular : .regular
        let config = UIImage.SymbolConfiguration(pointSize: key.type == .returnKey ? 19 : 20, weight: weight)
        imageView.image = UIImage(systemName: name, withConfiguration: config)
        label.isHidden = imageView.image != nil
        iconHighlighted = highlighted
        updateColors()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        imageView.frame = bounds
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    private static func font(for key: KeyDefinition) -> UIFont {
        switch key.type {
        case .character:
            return key.label.count > 2 ? .systemFont(ofSize: 17) : .systemFont(ofSize: 23)
        case .space:
            return .systemFont(ofSize: 15)
        default:
            return .systemFont(ofSize: key.label.count > 3 ? 15 : 16)
        }
    }

    private var isLightKey: Bool {
        // Character keys and the space bar are "light" keys; everything else is a function key.
        key.type == .character || key.type == .space || iconHighlighted
    }

    private func updateColors() {
        let dark = traitCollection.userInterfaceStyle == .dark
        let light = dark ? UIColor(white: 0.42, alpha: 1) : .white
        let function = dark ? UIColor(white: 0.27, alpha: 1)
                            : UIColor(red: 0.68, green: 0.70, blue: 0.74, alpha: 1)
        let text: UIColor = dark ? .white : .black

        if key.isAccent {
            backgroundColor = isPressed ? function : .systemBlue
            label.textColor = .white
            imageView.tintColor = .white
        } else if isLightKey {
            backgroundColor = isPressed ? function : light
            label.textColor = key.type == .space ? .secondaryLabel : text
            imageView.tintColor = text
        } else {
            backgroundColor = isPressed ? light : function
            label.textColor = key.isEnabled ? text : text.withAlphaComponent(0.35)
            imageView.tintColor = key.isEnabled ? text : text.withAlphaComponent(0.35)
        }
    }
}
