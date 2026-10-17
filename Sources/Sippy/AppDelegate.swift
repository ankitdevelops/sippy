import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    var secondsRemaining: Int = 25 * 60
    var intervalMinutes: Int = 25 {
        didSet { UserDefaults.standard.set(intervalMinutes, forKey: "intervalMinutes"); resetTimer() }
    }
    var glassesToday: Int {
        didSet { UserDefaults.standard.set(glassesToday, forKey: "glassesToday"); UserDefaults.standard.set(todayKey, forKey: "glassesDate") }
    }

    private var timer: Timer?
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel?
    private var settingsWindow: NSWindow?
    private var loginMenuItem: NSMenuItem!
    private lazy var characters: [BuddyCharacter] = BuddyCharacter.loadAll()

    var selectedCharacterID: String {
        get {
            let saved = UserDefaults.standard.string(forKey: "characterID")
            if let saved, characters.contains(where: { $0.id == saved }) { return saved }
            return characters.first { $0.id == "maya" }?.id ?? characters.first?.id ?? ""
        }
        set { UserDefaults.standard.set(newValue, forKey: "characterID") }
    }

    private var selectedCharacter: BuddyCharacter? {
        let id = selectedCharacterID
        return characters.first { $0.id == id }
    }

    private var todayKey: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }

    override init() {
        let savedInterval = UserDefaults.standard.integer(forKey: "intervalMinutes")
        self.intervalMinutes = savedInterval > 0 ? savedInterval : 25
        let savedDate = UserDefaults.standard.string(forKey: "glassesDate") ?? ""
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        let savedCount = UserDefaults.standard.integer(forKey: "glassesToday")
        self.glassesToday = (savedDate == today) ? savedCount : 0
        self.secondsRemaining = self.intervalMinutes * 60
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Sippy] characters: %@", "\(characters.map { "\($0.id) (\($0.name))" })")
        NSLog("[Sippy] selected: %@", selectedCharacterID)
        setupMenuBar()
        resetTimer()
        // Test hook: WB_TEST=1 auto-runs a reminder 2 s after launch.
        if ProcessInfo.processInfo.environment["WB_TEST"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.showReminder() }
        }
    }

    // MARK: - Menu bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateMenuBarTitle()
        let menu = NSMenu()
        loginMenuItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginMenuItem.target = self
        menu.addItem(loginMenuItem)
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Preview reminder now", action: #selector(previewNow), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "I drank water 💧", action: #selector(drankFromMenu), keyEquivalent: "d"))
        menu.addItem(NSMenuItem(title: "Snooze 5 min", action: #selector(snoozeFromMenu), keyEquivalent: "s"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Reset timer", action: #selector(resetFromMenu), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Quit Sippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        refreshLoginItem()
    }

    private func updateMenuBarTitle() {
        DispatchQueue.main.async {
            guard let button = self.statusItem?.button else { return }
            let m = self.secondsRemaining / 60
            let s = self.secondsRemaining % 60
            button.title = String(format: "💧 %02d:%02d  (%d🥛)", m, s, self.glassesToday)
        }
    }

    // MARK: - Timer

    func resetTimer() {
        timer?.invalidate()
        secondsRemaining = intervalMinutes * 60
        updateMenuBarTitle()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsRemaining -= 1
            self.updateMenuBarTitle()
            if self.secondsRemaining <= 0 {
                self.showReminder()
            }
        }
    }

    func snooze(minutes: Int = 5) {
        timer?.invalidate()
        secondsRemaining = minutes * 60
        updateMenuBarTitle()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.secondsRemaining -= 1
            self.updateMenuBarTitle()
            if self.secondsRemaining <= 0 { self.showReminder() }
        }
    }

    // MARK: - Reminder window

    func showReminder() {
        timer?.invalidate() // pause countdown while popup is up
        playChime()
        if let p = panel, let content = p.contentView as? ReminderContentView,
           content.characterID == selectedCharacter?.id {
            content.startEnter()
        } else {
            panel?.orderOut(nil) // stale panel — recycling with a different buddy
            let content = ReminderContentView(
                frame: NSRect(x: 0, y: 0, width: 500, height: 380),
                character: selectedCharacter,
                onDrank: { [weak self] in self?.didDrink() },
                onSnooze: { [weak self] in self?.didSnooze() }
            )
            let newPanel = FloatingPanel(contentView: content)
            if let old = panel { old.orderOut(nil) }
            panel = newPanel
        }
        panel?.show(onArrived: { [weak self] in
            (self?.panel?.contentView as? ReminderContentView)?.notifyArrived()
        })
        NSApp.activate(ignoringOtherApps: true)
    }

    private func didDrink() {
        glassesToday += 1
        updateMenuBarTitle()
        endReminder()
        resetTimer()
    }

    private func didSnooze() {
        endReminder()
        snooze(minutes: 5)
    }

    // Only buddies with their own walk-off-screen animation leave walking;
    // the rest just vanish the moment you answer.
    private func endReminder() {
        guard let panel = self.panel else { return }
        if selectedCharacter?.animatedExit ?? true {
            (panel.contentView as? ReminderContentView)?.startExit()
            panel.hideAnimated()
        } else {
            panel.hide()
        }
    }

    // MARK: - Sound (no UserNotifications: raw SwiftPM binary has no app bundle)

    private func playChime() {
        for name in ["Glass", "Ping", "Pop", "Hero"] {
            if let s = NSSound(named: name) { s.play(); return }
        }
        NSSound.beep()
    }

    // MARK: - Menu actions

    private func refreshLoginItem() {
        let on = SMAppService.mainApp.status == .enabled
        loginMenuItem.title = on ? "✓ Start at Login" : "Start at Login"
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login setting"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refreshLoginItem()
    }

    @objc private func previewNow() { showReminder() }

    // MARK: - Settings

    @objc private func openSettings() {
        let characters = self.characters
        guard !characters.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "No characters found"
            alert.informativeText = "Resources/Characters is empty in this build."
            alert.runModal()
            return
        }
        let height = CGFloat(166 + characters.count * 26)
        let content = SettingsContentView(
            frame: NSRect(x: 0, y: 0, width: 540, height: height),
            characters: characters,
            selectedID: selectedCharacterID,
            intervalMinutes: intervalMinutes,
            onSelect: { [weak self] id in self?.selectedCharacterID = id },
            onInterval: { [weak self] m in self?.intervalMinutes = m },
            onPreview: { [weak self] in self?.showReminder() }
        )
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        win.title = "Sippy Settings"
        win.contentView = content
        settingsWindow = win
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func drankFromMenu() { didDrink() }
    @objc private func snoozeFromMenu() { didSnooze() }
    @objc private func resetFromMenu() { resetTimer() }
}
