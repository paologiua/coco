import AppKit

/// A speech bubble beside Coco.
///
/// Its own window, not part of her stage. The stage is 64 pixels wide — 128 points at
/// Medium — and neither "Hi, I'm Coco!" nor a birthday message written by a human fits
/// in that. A separate window can be as wide as the sentence needs without touching a
/// single sprite, mask or hat anchor.
@MainActor
final class BubbleWindow {
    private var panel: NSPanel?
    private var hideTimer: Timer?

    private static let padding = 12.0
    private static let border = 3.0
    private static let tail = 10.0
    private static let maxWidth = 320.0

    func show(_ text: String, above coco: NSRect, on screen: NSRect, seconds: Double = 6) {
        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let bounded = NSSize(width: Self.maxWidth, height: .greatestFiniteMagnitude)
        let measured = (text as NSString).boundingRect(
            with: bounded,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font])

        let size = NSSize(width: ceil(measured.width) + Self.padding * 2 + Self.border * 2,
                          height: ceil(measured.height) + Self.padding * 2 + Self.border * 2 + Self.tail)

        let panel = self.panel ?? makePanel()
        self.panel = panel

        let view = panel.contentView as! BubbleView
        view.text = text
        view.font = font
        view.needsDisplay = true

        // Centred over her, then pushed back inside the screen if that would overhang.
        var origin = NSPoint(x: coco.midX - size.width / 2, y: coco.maxY - Self.tail)
        origin.x = min(max(origin.x, screen.minX + 8), screen.maxX - size.width - 8)
        origin.y = min(origin.y, screen.maxY - size.height - 8)

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.alphaValue = 1
        panel.orderFrontRegardless()

        hideTimer?.invalidate()
        hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    func hide() {
        hideTimer?.invalidate()
        hideTimer = nil
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        // Nothing here is clickable, and a bubble that eats clicks while it fades would
        // be far worse than one that cannot be dismissed.
        panel.ignoresMouseEvents = true
        panel.contentView = BubbleView(frame: .zero)
        return panel
    }
}

/// The bubble itself: a chunky bordered box with a tail, drawn to match Coco rather
/// than to match macOS.
private final class BubbleView: NSView {
    var text = ""
    var font = NSFont.systemFont(ofSize: 13)

    private let ink = NSColor(srgbRed: 0.106, green: 0.180, blue: 0.078, alpha: 1)     // #1B2E14
    private let paper = NSColor(srgbRed: 0.929, green: 0.914, blue: 0.816, alpha: 1)   // #EDE9D0

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let tail = 10.0
        let border = 3.0
        let box = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - tail)

        ink.setFill()
        box.fill()
        paper.setFill()
        box.insetBy(dx: border, dy: border).fill()

        // A stepped tail rather than a smooth triangle: three squares, so it belongs to
        // the same drawing as the bird.
        let step = tail / 3
        for index in 0..<3 {
            let width = (3.0 - Double(index)) * step * 2
            let rect = NSRect(x: box.midX - width / 2, y: box.maxY + Double(index) * step,
                              width: width, height: step)
            ink.setFill()
            rect.fill()
            if index < 2 {
                paper.setFill()
                rect.insetBy(dx: border, dy: 0).fill()
            }
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        (text as NSString).draw(
            in: box.insetBy(dx: border + 12, dy: border + 12),
            withAttributes: [.font: font, .foregroundColor: ink, .paragraphStyle: paragraph])
    }
}
