import AppKit

/// A temporary mouse target. Owns its timeout so it disappears even when Coco's
/// simulation loop is paused by a menu or another UI interaction.
@MainActor
final class InteractionWindow {
    enum Kind { case food, hoop }
    private var panel: TargetPanel?
    private var backPanel: TargetPanel?
    private var timer: Timer?
    private var deadline = Date.distantPast
    var passes: Int = 0 {
        didSet {
            (panel?.contentView as? TargetView)?.passes = passes
            panel?.contentView?.needsDisplay = true
            (backPanel?.contentView as? TargetView)?.passes = passes
            backPanel?.contentView?.needsDisplay = true
        }
    }
    var onClick: (() -> Void)?
    var onEnd: ((Bool) -> Void)?

    func show(_ kind: Kind, seconds: Double, scale: Int) {
        finish(completed: false)
        let size = kind == .food ? CGSize(width: 24 * scale, height: 24 * scale)
                                 : CGSize(width: 24 * scale, height: 64 * scale)
        let name = kind == .food ? "food" : "hoop"
        let image = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "UI")
            .flatMap(NSImage.init(contentsOf:))

        if kind == .food {
            panel = makePanel(size: size,
                              level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1),
                              kind: kind, image: image, layer: .whole,
                              receivesClicks: true, showsCounter: false)
        } else {
            // The right arc is behind Coco; the left arc is in front. Drawing the same
            // asset in two clipped windows is what makes her travel through its depth.
            backPanel = makePanel(size: size,
                                  level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue - 1),
                                  kind: kind, image: image, layer: .right,
                                  receivesClicks: false, showsCounter: false)
            panel = makePanel(size: size,
                              level: NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1),
                              kind: kind, image: image, layer: .left,
                              receivesClicks: false, showsCounter: true)
        }
        deadline = Date().addingTimeInterval(seconds)
        update()
        guard let panel else { return }
        backPanel?.orderFrontRegardless()
        panel.orderFrontRegardless()
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func makePanel(size: CGSize, level: NSWindow.Level, kind: Kind,
                           image: NSImage?, layer: TargetView.Layer,
                           receivesClicks: Bool, showsCounter: Bool) -> TargetPanel {
        let panel = TargetPanel(contentRect: NSRect(origin: .zero, size: size),
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        panel.level = level
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let view = TargetView(frame: panel.contentLayoutRect)
        view.kind = kind
        view.passes = 0
        view.image = image
        view.layerToDraw = layer
        view.showsCounter = showsCounter
        panel.ignoresMouseEvents = !receivesClicks
        view.clicked = { [weak self] in self?.onClick?() }
        panel.contentView = view
        return panel
    }

    private func update() {
        // Poll only Escape's current state: no global keyboard monitor or permission.
        if CGEventSource.keyState(.combinedSessionState, key: 53) {
            finish(completed: false)
        } else if Date() >= deadline {
            finish(completed: true)
        } else {
            let mouse = NSEvent.mouseLocation
            if let panel {
                let origin = CGPoint(x: mouse.x - panel.frame.width / 2,
                                     y: mouse.y - panel.frame.height / 2)
                panel.setFrameOrigin(origin)
                backPanel?.setFrameOrigin(origin)
            }
        }
    }

    func finish(completed: Bool = false) {
        let wasActive = panel != nil || backPanel != nil
        timer?.invalidate()
        timer = nil
        panel?.orderOut(nil)
        backPanel?.orderOut(nil)
        panel = nil
        backPanel = nil
        if wasActive { onEnd?(completed) }
    }
}

private final class TargetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class TargetView: NSView {
    enum Layer { case whole, left, right }

    var kind = InteractionWindow.Kind.food
    var layerToDraw = Layer.whole
    var showsCounter = false
    var clicked: (() -> Void)?
    /// Coco deliberately never activates, so AppKit otherwise discards the first click
    /// delivered while another application is frontmost.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { clicked?() }
    override func rightMouseDown(with event: NSEvent) { /* consume only this target */ }

    var image: NSImage?
    var passes = 0

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        NSGraphicsContext.current?.saveGraphicsState()
        switch layerToDraw {
        case .whole:
            break
        case .left:
            NSRect(x: bounds.minX, y: bounds.minY,
                   width: bounds.width / 2, height: bounds.height).clip()
        case .right:
            NSRect(x: bounds.midX, y: bounds.minY,
                   width: bounds.width / 2, height: bounds.height).clip()
        }
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
        NSGraphicsContext.current?.restoreGraphicsState()
        if showsCounter {
            let label = "\(passes) / 3"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.white,
                .backgroundColor: NSColor.black.withAlphaComponent(0.8)
            ]
            (label as NSString).draw(at: CGPoint(x: 6, y: 4), withAttributes: attributes)
        }
    }
}
