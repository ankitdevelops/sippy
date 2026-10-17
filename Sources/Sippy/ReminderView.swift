import AppKit

/// Small downward triangle under the hover bubble.
final class BubbleTailView: NSView {
    var fill: NSColor = .controlBackgroundColor
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        fill.setFill()
        let p = NSBezierPath()
        p.move(to: NSPoint(x: 0, y: bounds.height))
        p.line(to: NSPoint(x: bounds.width / 2, y: 0))
        p.line(to: NSPoint(x: bounds.width, y: bounds.height))
        p.close()
        p.fill()
    }
}

/// Just the buddy on screen — no text. Hovering her reveals a small
/// bubble with YES / Remind me later. Pure AppKit so it builds with
/// Command Line Tools.
final class ReminderContentView: NSView {
    private let bubble = NSView()
    private let tail = BubbleTailView()
    private let yesButton = NSButton(title: "Gulp!", target: nil, action: nil)
    private let laterButton = NSButton(title: "Later", target: nil, action: nil)
    private let buddyView = NSImageView()
    private let fallbackLabel = NSTextField(labelWithString: "🧍‍♀️💧")

    let characterID: String
    private let character: BuddyCharacter?
    private var pose: Pose = .walk
    private var currentFrames: [NSImage] = []
    private var frameIndex = 0
    private var loop: FrameLoop?
    private var currentDuration = 0.07
    private var frameAccum = 0.0
    private var hasArrived = false
    private var loopStart = 0

    var onDrank: () -> Void
    var onSnooze: () -> Void

    init(frame: NSRect, character: BuddyCharacter?, onDrank: @escaping () -> Void, onSnooze: @escaping () -> Void) {
        self.character = character
        self.characterID = character?.id ?? ""
        self.onDrank = onDrank
        self.onSnooze = onSnooze
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setup()
        startEnter()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    // MARK: - Pose state machine
    // Enter: greet (hi) while the panel slides in. Arrived: replay hi once,
    // then hold the wait pose until the user answers. Exit: walk cycle while
    // she slides off-screen.

    func startEnter() {
        setPose(.hi)
    }

    func notifyArrived() {
        hasArrived = true
        setPose(.hi) // play the full hi sequence once after landing
    }

    func startExit() {
        hasArrived = false
        setPose(.walk)
    }

    private func setPose(_ pose: Pose) {
        guard let character else { return }
        self.pose = pose
        currentFrames = character.frames(for: pose)
        currentDuration = character.duration(for: pose)
        loopStart = character.loopStart(for: pose)
        frameIndex = 0
        frameAccum = 0
        loop?.invalidate()
        NSLog("[Sippy] pose -> %@ (%d frames, loop from %d)", pose.rawValue, currentFrames.count, loopStart)
        guard !currentFrames.isEmpty else { return }
        loop = FrameLoop(fallbackInterval: currentDuration) { [weak self] delta in
            self?.step(delta)
        }
    }

    private func step(_ delta: Double) {
        frameAccum += delta
        while frameAccum >= currentDuration, currentDuration > 0 {
            frameAccum -= currentDuration
            if frameIndex + 1 >= currentFrames.count {
                // After landing, the hi sequence plays exactly once, then
                // she waits for the user's answer.
                if pose == .hi, hasArrived {
                    setPose(.wait)
                    return
                }
                frameIndex = loopStart
            } else {
                frameIndex += 1
            }
            buddyView.image = currentFrames[frameIndex]
        }
    }

    private func setup() {
        // --- Buddy frames (480x270 in a 500x380 panel, no text) ---
        currentFrames = character?.frames(for: .walk) ?? []
        if currentFrames.isEmpty {
            fallbackLabel.font = .systemFont(ofSize: 120)
            fallbackLabel.alignment = .center
            fallbackLabel.frame = NSRect(x: 100, y: 60, width: 300, height: 300)
            fallbackLabel.isBordered = false; fallbackLabel.isEditable = false; fallbackLabel.backgroundColor = .clear
            addSubview(fallbackLabel)
        } else {
            buddyView.wantsLayer = true // layer-backed swaps avoid re-draw flicker
            buddyView.image = currentFrames[0]
            buddyView.imageScaling = .scaleProportionallyUpOrDown
            buddyView.frame = NSRect(x: 10, y: 10, width: 480, height: 270)
            addSubview(buddyView)
        }

        // Hover zone covers her AND the bubble, so moving the mouse up
        // to click a button doesn't dismiss it mid-travel.
        let tracking = NSTrackingArea(rect: NSRect(x: 10, y: 10, width: 480, height: 360),
                                      options: [.mouseEnteredAndExited, .activeAlways],
                                      owner: self, userInfo: nil)
        addTrackingArea(tracking)

        // --- Hover bubble: buttons only, hidden until hover ---
        bubble.wantsLayer = true
        bubble.layer?.cornerRadius = 16
        bubble.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        bubble.layer?.borderWidth = 1
        bubble.layer?.borderColor = NSColor.separatorColor.cgColor
        bubble.frame = NSRect(x: 134, y: 294, width: 232, height: 76)
        bubble.isHidden = true
        addSubview(bubble)

        yesButton.bezelStyle = .rounded
        yesButton.keyEquivalent = "\r"
        yesButton.frame = NSRect(x: 21, y: 22, width: 92, height: 32)
        yesButton.target = self; yesButton.action = #selector(drankPressed)
        if #available(macOS 14.0, *) { yesButton.bezelColor = .systemBlue }
        bubble.addSubview(yesButton)

        laterButton.bezelStyle = .rounded
        laterButton.font = .systemFont(ofSize: 12)
        laterButton.frame = NSRect(x: 121, y: 22, width: 90, height: 32)
        laterButton.target = self; laterButton.action = #selector(snoozePressed)
        bubble.addSubview(laterButton)

        tail.fill = .controlBackgroundColor
        tail.frame = NSRect(x: 235, y: 280, width: 30, height: 14)
        tail.isHidden = true
        addSubview(tail)
    }

    override func mouseEntered(with event: NSEvent) {
        bubble.isHidden = false
        tail.isHidden = false
    }

    override func mouseExited(with event: NSEvent) {
        bubble.isHidden = true
        tail.isHidden = true
    }

    @objc private func drankPressed() { onDrank() }
    @objc private func snoozePressed() { onSnooze() }

    deinit {
        loop?.invalidate()
    }
}
