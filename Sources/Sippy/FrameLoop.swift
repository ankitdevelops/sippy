import AppKit

/// Drives animations at display refresh rate via CADisplayLink (macOS 14+),
/// falling back to a Timer on macOS 13. `handler` receives the seconds since
/// the previous call. Runs in run loop .common mode so animation continues
/// while status menus or tracking areas are active.
final class FrameLoop {
    private var displayLink: Any?
    private var timer: Timer?
    private var lastTimestamp: CFTimeInterval?
    private let fallbackInterval: Double
    private let handler: (Double) -> Void

    init(fallbackInterval: Double, handler: @escaping (Double) -> Void) {
        self.fallbackInterval = fallbackInterval
        self.handler = handler
        if #available(macOS 14.0, *), let screen = NSScreen.main {
            // CADisplayLink retains its target until invalidated.
            let link = screen.displayLink(target: self, selector: #selector(tick(_:)))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else {
            makeTimer()
        }
    }

    private func makeTimer() {
        let interval = fallbackInterval
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.handler(interval)
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func tick(_ link: Any) {
        guard #available(macOS 14.0, *), let link = link as? CADisplayLink else { return }
        let now = link.timestamp
        let delta = lastTimestamp.map { now - $0 } ?? fallbackInterval
        lastTimestamp = now
        handler(min(0.25, max(0, delta)))
    }

    func invalidate() {
        if #available(macOS 14.0, *) { (displayLink as? CADisplayLink)?.invalidate() }
        displayLink = nil
        timer?.invalidate()
        timer = nil
    }

    deinit { invalidate() }
}
