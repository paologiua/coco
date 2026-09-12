import AppKit

/// A temporary mouse target. Owns its timeout so it disappears even when Coco's
/// simulation loop is paused by a menu or another UI interaction.
@MainActor
final class InteractionWindow {
    enum Kind { case food, hoop }
    /// Points reserved above and below the hoop for its counter.
    static let counterPad: CGFloat = 22
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
        let name = kind == .food ? "food" : "hoop"
        let image = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "UI")
            .flatMap(NSImage.init(contentsOf:))
        // Measured from the artwork rather than written down. These were the literals
        // 24x24 and 24x64, so redrawing a prop at a different shape silently stretched
        // it into the old one's proportions.
        let pixels = image?.representations.first.map {
            CGSize(width: $0.pixelsWide, height: $0.pixelsHigh)
        } ?? CGSize(width: 24, height: 24)
        let drawn = CGSize(width: pixels.width * CGFloat(scale),
                           height: pixels.height * CGFloat(scale))
        // Room under the ring for the counter, added top AND bottom so the ring stays
        // centred on the pointer. The old asset carried enough transparent padding to
        // hold the counter by accident; this one is trimmed to the drawing, so the
        // count landed on the ring itself.
        let pad = kind == .hoop ? Self.counterPad : 0
        let size = CGSize(width: drawn.width, height: drawn.height + pad * 2)

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
        view.verticalPad = kind == .hoop ? InteractionWindow.counterPad : 0
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
                let snapped = Self.onDevicePixels(origin, of: panel)
                panel.setFrameOrigin(snapped)
                backPanel?.setFrameOrigin(snapped)
            }
        }
    }

    /// The nearest origin that puts the artwork on whole device pixels.
    ///
    /// The prop follows a pointer reported in points and freely fractional, and it is
    /// centred on it — and the hoop's panel is an odd number of points wide, so half of
    /// it is a half. Between the two, the window landed part of a device pixel off the
    /// grid, and nearest-neighbour sampling then had to split art pixels across device
    /// pixels: the ring came out soft, and softened differently every time the mouse
    /// moved, which is the shimmer. Drawing it with no interpolation is not enough on
    /// its own — a pixel can only stay hard if it lands on whole ones.
    private static func onDevicePixels(_ origin: CGPoint, of panel: NSWindow) -> CGPoint {
        let backing = (panel.screen ?? NSScreen.main)?.backingScaleFactor ?? 2
        return CGPoint(x: (origin.x * backing).rounded() / backing,
                       y: (origin.y * backing).rounded() / backing)
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

    /// Points of empty panel above and below the drawing, so the counter has somewhere
    /// to sit that is not on top of the ring.
    var verticalPad: CGFloat = 0

    /// Where the arc in front of Coco is cut from the arc behind her, rounded to a
    /// whole art pixel.
    ///
    /// Halfway across an odd number of pixels falls INSIDE the middle one, and the ring
    /// is 21 wide: clipping there sliced that column down its length, half of it drawn
    /// in the near window and half in the far one. Over the crown of the ring, where
    /// the band crosses the middle, that is a hairline seam through the drawing.
    var seam: CGFloat {
        guard let pixels = image?.representations.first?.pixelsWide, pixels > 0 else {
            return bounds.midX
        }
        let pip = bounds.width / CGFloat(pixels)
        return (bounds.midX / pip).rounded() * pip
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        NSGraphicsContext.current?.saveGraphicsState()
        let art = NSRect(x: bounds.minX, y: bounds.minY + verticalPad,
                         width: bounds.width, height: bounds.height - verticalPad * 2)
        switch layerToDraw {
        case .whole:
            break
        case .left:
            NSRect(x: bounds.minX, y: bounds.minY,
                   width: seam, height: bounds.height).clip()
        case .right:
            NSRect(x: seam, y: bounds.minY,
                   width: bounds.maxX - seam, height: bounds.height).clip()
        }
        // The hint as well as the context's setting, exactly as `SpriteView` draws her:
        // nearest is never the default anywhere in the stack and has to be asked for.
        image?.draw(in: art, from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: true,
                    hints: [.interpolation: NSImageInterpolation.none.rawValue])
        NSGraphicsContext.current?.restoreGraphicsState()
        if showsCounter {
            counterLabel.draw(at: counterOrigin, withAttributes: Self.counterAttributes)
        }
    }

    var counterLabel: NSString { "\(passes) / 3" as NSString }

    static let counterAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
        .foregroundColor: NSColor.white,
        .backgroundColor: NSColor.black.withAlphaComponent(0.8)
    ]

    /// Where the count is drawn: centred under the ring, in the band of empty panel
    /// that `counterPad` reserves for it.
    ///
    /// It used to be pinned four points in from the bottom left, which is the corner of
    /// the PANEL rather than of the drawing — and the panel is wider than the count is,
    /// so the number sat off to one side of the ring it is counting for.
    ///
    /// Rounded to whole points: the panel is snapped to the device grid so the ring
    /// stays hard, and half a point of drift here would be spent softening the digits.
    var counterOrigin: CGPoint {
        let size = counterLabel.size(withAttributes: Self.counterAttributes)
        return CGPoint(x: ((bounds.width - size.width) / 2).rounded(),
                       y: ((verticalPad - size.height) / 2).rounded())
    }
}
