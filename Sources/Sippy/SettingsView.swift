import AppKit

/// Minimal settings panel: pick which buddy reminds you to drink and how
/// often. New characters appear here automatically — drop a folder with a
/// character.json into Resources/Characters and rebuild.
final class SettingsContentView: NSView {
    private var characterRadios: [NSButton] = []
    private var intervalRadios: [NSButton] = []
    private var previewLoop: FrameLoop?
    private var previewFrames: [NSImage] = []
    private var previewIndex = 0
    private var previewAccum = 0.0
    private var previewDuration = 0.07
    private let previewView = NSImageView()
    private let selectedID: String
    private let intervalMinutes: Int
    private let onSelect: (String) -> Void
    private let onInterval: (Int) -> Void
    private let onPreview: () -> Void

    init(frame: NSRect, characters: [BuddyCharacter], selectedID: String, intervalMinutes: Int,
         onSelect: @escaping (String) -> Void, onInterval: @escaping (Int) -> Void,
         onPreview: @escaping () -> Void) {
        self.selectedID = selectedID
        self.intervalMinutes = intervalMinutes
        self.onSelect = onSelect
        self.onInterval = onInterval
        self.onPreview = onPreview
        super.init(frame: frame)
        setup(characters: characters)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    private func setup(characters: [BuddyCharacter]) {
        allCharacters = characters
        let title = NSTextField(labelWithString: "Avatar:")
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = NSRect(x: 20, y: bounds.height - 30, width: 200, height: 20)
        addSubview(title)

        var y = bounds.height - 62
        for c in characters {
            let radio = NSButton(checkboxWithTitle: c.name, target: nil, action: nil)
            radio.setButtonType(.radio)
            radio.font = .systemFont(ofSize: 13)
            radio.frame = NSRect(x: 20, y: y, width: 240, height: 20)
            radio.state = c.id == selectedID ? .on : .off
            radio.target = self
            radio.action = #selector(characterChanged(_:))
            radio.identifier = NSUserInterfaceItemIdentifier(c.id)
            addSubview(radio)
            characterRadios.append(radio)
            y -= 26
        }

        // Little looping preview of the selected buddy, in its own right
        // column clear of the radios.
        previewView.wantsLayer = true
        previewView.imageScaling = .scaleProportionallyUpOrDown
        previewView.frame = NSRect(x: bounds.width - 150, y: bounds.height - 160, width: 120, height: 130)
        addSubview(previewView)
        setPreview(characters.first { $0.id == selectedID })

        // Replaces the old "Every N min" rows in the status menu.
        let intervalTitle = NSTextField(labelWithString: "Remind me every:")
        intervalTitle.font = .boldSystemFont(ofSize: 13)
        intervalTitle.frame = NSRect(x: 20, y: y - 6, width: 200, height: 20)
        addSubview(intervalTitle)
        y -= 38
        for m in [15, 25, 30, 45, 60] {
            let radio = NSButton(checkboxWithTitle: "\(m) min", target: nil, action: nil)
            radio.setButtonType(.radio)
            radio.font = .systemFont(ofSize: 13)
            radio.frame = NSRect(x: 20 + CGFloat(intervalRadios.count) * 74, y: y, width: 74, height: 20)
            radio.state = m == intervalMinutes ? .on : .off
            radio.target = self
            radio.action = #selector(intervalChanged(_:))
            radio.identifier = NSUserInterfaceItemIdentifier(String(m))
            addSubview(radio)
            intervalRadios.append(radio)
        }

        let preview = NSButton(title: "Preview reminder now", target: nil, action: nil)
        preview.bezelStyle = .rounded
        preview.frame = NSRect(x: 20, y: 16, width: 160, height: 30)
        preview.target = self
        preview.action = #selector(previewPressed)
        addSubview(preview)
    }

    @objc private func characterChanged(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue else { return }
        for b in characterRadios where b !== sender { b.state = .off }
        onSelect(id)
        setPreview(allCharacters.first { $0.id == id })
    }

    private var allCharacters: [BuddyCharacter] = []

    /// Loop the buddy's greet frames in the corner.
    private func setPreview(_ character: BuddyCharacter?) {
        previewLoop?.invalidate()
        previewLoop = nil
        guard let character else { previewView.image = nil; return }
        previewFrames = character.frames(for: .hi)
        previewDuration = character.duration(for: .hi)
        previewIndex = 0
        previewAccum = 0
        previewView.image = previewFrames.first
        guard !previewFrames.isEmpty else { return }
        let dur = previewDuration
        previewLoop = FrameLoop(fallbackInterval: dur) { [weak self] delta in
            guard let self else { return }
            self.previewAccum += delta
            while self.previewAccum >= self.previewDuration, !self.previewFrames.isEmpty {
                self.previewAccum -= self.previewDuration
                self.previewIndex = (self.previewIndex + 1) % self.previewFrames.count
                self.previewView.image = self.previewFrames[self.previewIndex]
            }
        }
    }

    @objc private func intervalChanged(_ sender: NSButton) {
        guard let m = sender.identifier?.rawValue, let minutes = Int(m) else { return }
        for b in intervalRadios where b !== sender { b.state = .off }
        onInterval(minutes)
    }

    @objc private func previewPressed() { onPreview() }

    deinit {
        previewLoop?.invalidate()
    }
}
