import AppKit

/// Borderless, always-on-top floating panel, bottom-right of the main screen.
final class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 380),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.contentView = contentView
        isReleasedWhenClosed = false
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    private var slideLoop: FrameLoop?
    private var isSlidingOut = false

    func show(onArrived: (() -> Void)? = nil) {
        // Resting spot: bottom-right with a margin.
        var target = NSPoint(x: 800, y: 60)
        var screenMaxX: CGFloat = 2000
        if let screen = NSScreen.main {
            let v = screen.visibleFrame
            target = NSPoint(x: v.maxX - 500 - 28, y: v.minY + 28)
            screenMaxX = v.maxX
        }
        // Start just off-screen right, then walk in. CADisplayLink ties the
        // motion to the display refresh instead of a coarse Timer.
        let startX = screenMaxX + 20
        setFrameOrigin(NSPoint(x: startX, y: target.y))
        orderFrontRegardless()
        alphaValue = 1
        isSlidingOut = false
        slideLoop?.invalidate()
        let dx = target.x - startX
        let startedAt = Date()
        let duration = 0.6
        slideLoop = FrameLoop(fallbackInterval: 1.0 / 60) { [weak self] _ in
            guard let self else { return }
            let p = min(1.0, Date().timeIntervalSince(startedAt) / duration)
            let eased = 1.0 - pow(1.0 - p, 3.0) // easeOutCubic
            self.setFrameOrigin(NSPoint(x: startX + dx * CGFloat(eased), y: target.y))
            if p >= 1.0 {
                self.slideLoop?.invalidate()
                self.setFrameOrigin(target)
                onArrived?()
            }
        }
    }

    /// Walk back off-screen to the right (buddy keeps stepping), then hide.
    /// Slower than the entrance: she dawdles on the way out (2.4 s vs 0.6 s).
    func hideAnimated() {
        guard !isSlidingOut else { return }
        slideLoop?.invalidate()
        var screenMaxX: CGFloat = 2000
        if let screen = NSScreen.main { screenMaxX = screen.visibleFrame.maxX }
        let startX = frame.origin.x
        let dx = screenMaxX + 20 - startX
        guard dx > 0 else { orderOut(nil); return }
        isSlidingOut = true
        let startedAt = Date()
        let duration = 2.4
        slideLoop = FrameLoop(fallbackInterval: 1.0 / 60) { [weak self] _ in
            guard let self else { return }
            let p = min(1.0, Date().timeIntervalSince(startedAt) / duration)
            let eased = 0.5 - 0.5 * cos(.pi * p) // easeInOutSine
            self.setFrameOrigin(NSPoint(x: startX + dx * CGFloat(eased), y: self.frame.origin.y))
            if p >= 1.0 {
                self.slideLoop?.invalidate()
                self.isSlidingOut = false
                self.orderOut(nil)
            }
        }
    }

    func hide() {
        slideLoop?.invalidate()
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
