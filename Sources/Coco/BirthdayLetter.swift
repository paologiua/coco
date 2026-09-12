import AppKit

/// The birthday letter: an invitation that appears when Coco is petted, and the
/// animation it opens into.
///
/// Only on the birthday, and every time she is petted — she can read it as often as
/// she likes. It replaced a speech bubble that fired once a year on the first launch
/// of the day, which meant the whole thing could be missed by opening the laptop at
/// the wrong moment.
@MainActor
final class BirthdayLetter {
    /// How long the invitation stays at full strength before it starts to go.
    private static let invitationSeconds = 3.2
    /// And how long it takes to fade out once it does. It stays clickable the whole
    /// way down — a card you can see is a card you can still reach.
    private static let invitationFade = 1.1
    /// Frames per second for the envelope opening.
    ///
    /// Six, not twelve. At twelve the nineteen frames were over in a second and a half
    /// — technically an animation and, watched, a flicker. This is a thing being handed
    /// to someone, and it is allowed to take its time.
    private static let fps = 6.0
    /// The cross-fade from the last drawn frame into the readable letter. Longer than
    /// a cut, so the letter arrives rather than appears.
    private static let revealSeconds = 0.8
    /// Margin kept around the letter, so it does not touch the edges of the screen.
    private static let screenMargin = 24.0

    private var invitation: NSPanel?
    private var letter: NSPanel?
    /// A transparent sheet the size of the screen, sitting just under whichever panel
    /// is up, so that a click anywhere else dismisses it.
    ///
    /// A catcher rather than a global event monitor: monitoring the mouse outside our
    /// own windows is the sort of thing that asks the human for Accessibility, and this
    /// app is built not to ask for anything.
    private var backdrop: NSPanel?
    private var invitationTimer: Timer?
    private var animationTimer: Timer?

    private var frames: [NSImage] = []
    private var letterImage: NSImage?
    private var elapsed = 0.0

    var isLetterOpen: Bool { letter != nil }

    // MARK: - The invitation

    func offer(on screen: NSRect) {
        guard letter == nil else { return }
        // Re-offering restarts the countdown rather than stacking panels: petting her
        // repeatedly should keep the invitation up, not open several of them.
        dismissInvitation()
        guard let image = Self.load("invitation", in: "LetterAnim") else { return }

        let size = Self.fit(image.size, into: CGSize(width: 460, height: 200))
        showBackdrop(on: screen, level: 1) { [weak self] in self?.dismissInvitation() }
        let panel = Self.makePanel(size: size, on: screen, level: 2)
        panel.alphaValue = 1
        let view = ClickableImageView(frame: NSRect(origin: .zero, size: size))
        view.image = image
        view.onClick = { [weak self] in self?.open(on: screen) }
        panel.contentView = view
        panel.orderFrontRegardless()
        invitation = panel

        // Faded rather than switched off. A card that simply stops existing reads as a
        // glitch; one that dims reads as a moment passing.
        var elapsed = 0.0
        let tick = 1.0 / 60
        let timer = Timer(timeInterval: tick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.invitation else { return }
                elapsed += tick
                let over = elapsed - Self.invitationSeconds
                guard over > 0 else { return }
                if over >= Self.invitationFade {
                    self.dismissInvitation()
                } else {
                    panel.alphaValue = 1 - over / Self.invitationFade
                }
            }
        }
        invitationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func dismissInvitation() {
        invitationTimer?.invalidate()
        invitationTimer = nil
        invitation?.orderOut(nil)
        invitation = nil
        if letter == nil { hideBackdrop() }
    }

    // MARK: - The letter

    private func open(on screen: NSRect) {
        dismissInvitation()
        guard letter == nil else { return }

        // Twelve of the nineteen drawn frames, ending on the letter rising out of the
        // open envelope.
        //
        // Frame 12 is where the sheet changes its mind: the open envelope vanishes and
        // is replaced by a small closed one, tilted, and the run never recovers — it
        // grows to 849 points and then falls away to 509 before the real letter arrives
        // at 1293. Cutting at 11 ends on the letter coming out and hands straight over
        // to the letter itself. The rest are kept in Assets/Letter/big, simply unplayed.
        frames = (0..<12).compactMap { Self.load(String(format: "frame%02d", $0), in: "LetterAnim") }
        letterImage = Self.load("letter", in: "LetterAnim")
        guard !frames.isEmpty, let letterImage else { return }

        // Sized by the LETTER, and by its drawing rather than its canvas: the image
        // carries transparent margin, and giving that margin screen height is height
        // the text does not get. The whole point of the size is that it can be read.
        let ink = Self.inkBounds(letterImage)
        let available = CGSize(width: screen.width - Self.screenMargin * 2,
                               height: screen.height - Self.screenMargin * 2)
        let size = Self.fit(ink.size, into: available)

        showBackdrop(on: screen, level: 1) { [weak self] in self?.close() }
        let panel = Self.makePanel(size: size, on: screen, level: 2)
        let view = LetterView(frame: NSRect(origin: .zero, size: size))
        view.frames = frames
        view.letterImage = letterImage
        view.letterInk = ink
        view.onClose = { [weak self] in self?.close() }
        panel.contentView = view
        panel.orderFrontRegardless()
        letter = panel

        elapsed = 0
        let tick = 1.0 / 60
        let timer = Timer(timeInterval: tick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let view = self.letter?.contentView as? LetterView else { return }
                self.elapsed += tick
                let total = Double(self.frames.count) / Self.fps
                if self.elapsed < total {
                    view.frameIndex = min(self.frames.count - 1, Int(self.elapsed * Self.fps))
                    view.reveal = 0
                } else {
                    view.frameIndex = self.frames.count - 1
                    view.reveal = min(1, (self.elapsed - total) / Self.revealSeconds)
                    if view.reveal >= 1 { self.stopAnimation() }
                }
            }
        }
        animationTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    func close() {
        stopAnimation()
        letter?.orderOut(nil)
        letter = nil
        hideBackdrop()
        // Nineteen frames at 1024 square is most of a hundred megabytes. It is worth
        // holding while she reads and not a moment longer.
        frames = []
        letterImage = nil
    }

    private func showBackdrop(on screen: NSRect, level: Int, onClick: @escaping () -> Void) {
        hideBackdrop()
        let panel = Self.makePanel(size: screen.size, on: screen, level: level)
        let view = ClickableImageView(frame: NSRect(origin: .zero, size: screen.size))
        view.onClick = onClick
        panel.contentView = view
        panel.orderFrontRegardless()
        backdrop = panel
    }

    private func hideBackdrop() {
        backdrop?.orderOut(nil)
        backdrop = nil
    }

    // MARK: - Plumbing

    private static func load(_ name: String, in folder: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: folder)
            .flatMap(NSImage.init(contentsOf:))
    }

    /// The largest size with `source`'s proportions that fits inside `box`.
    private static func fit(_ source: CGSize, into box: CGSize) -> CGSize {
        let k = min(box.width / source.width, box.height / source.height)
        return CGSize(width: (source.width * k).rounded(), height: (source.height * k).rounded())
    }

    /// The drawn part of an image, in its own pixel coordinates, origin bottom-left.
    private static func inkBounds(_ image: NSImage) -> CGRect {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return CGRect(origin: .zero, size: image.size)
        }
        let w = cg.width, h = cg.height
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        var minX = w, maxX = -1, minY = h, maxY = -1
        for y in 0..<h {
            for x in 0..<w where pixels[(y * w + x) * 4 + 3] > 8 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return CGRect(origin: .zero, size: image.size) }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private static func makePanel(size: CGSize, on screen: NSRect, level: Int) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + level)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.setFrameOrigin(NSPoint(x: (screen.midX - size.width / 2).rounded(),
                                     y: (screen.midY - size.height / 2).rounded()))
        return panel
    }
}

/// A view that draws one image and reports a click anywhere on it.
private final class ClickableImageView: NSView {
    var image: NSImage?
    var onClick: (() -> Void)?

    /// Coco never activates, so without this AppKit swallows the first click whenever
    /// another application is frontmost — which is always.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

/// Draws the opening animation and then the letter, with a close box.
private final class LetterView: NSView {
    var frames: [NSImage] = []
    var letterImage: NSImage?
    /// The letter's drawn area inside its image, so the transparent margin is not given
    /// screen space the text could have had.
    var letterInk: CGRect = .zero
    var onClose: (() -> Void)?

    var frameIndex = 0 { didSet { if frameIndex != oldValue { needsDisplay = true } } }
    /// 0 while the animation plays, 1 once the letter has fully arrived.
    var reveal = 0.0 { didSet { if reveal != oldValue { needsDisplay = true } } }

    private static let closeSize: CGFloat = 34
    private static let closeInset: CGFloat = 10

    override var isFlipped: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var closeBox: NSRect {
        NSRect(x: Self.closeInset, y: Self.closeInset,
               width: Self.closeSize, height: Self.closeSize)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        // Only the close box takes clicks. A letter that shuts when you click the middle
        // of it is a letter you dismiss by accident halfway through reading.
        if reveal > 0, closeBox.contains(point) { onClose?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none

        if reveal < 1, frames.indices.contains(frameIndex) {
            let image = frames[frameIndex]
            // Fitted rather than stretched, and centred: every frame shares one canvas
            // with the subject drawn in the same place, so fitting them identically is
            // what keeps the envelope still while it opens.
            let k = min(bounds.width / image.size.width, bounds.height / image.size.height)
            let size = CGSize(width: image.size.width * k, height: image.size.height * k)
            let rect = NSRect(x: (bounds.width - size.width) / 2,
                              y: (bounds.height - size.height) / 2,
                              width: size.width, height: size.height)
            image.draw(in: rect, from: .zero, operation: .sourceOver,
                       fraction: 1 - reveal, respectFlipped: true, hints: nil)
        }

        if reveal > 0, let letterImage {
            // Drawn from its ink rather than its whole canvas, so the letter fills the
            // panel and the text gets every point of height available.
            let source = NSRect(x: letterInk.minX,
                                y: letterImage.size.height - letterInk.maxY,
                                width: letterInk.width, height: letterInk.height)
            letterImage.draw(in: bounds, from: source, operation: .sourceOver,
                             fraction: reveal, respectFlipped: true, hints: nil)
            drawCloseBox()
        }
    }

    private func drawCloseBox() {
        let box = closeBox
        NSColor(srgbRed: 0.03, green: 0.04, blue: 0.02, alpha: reveal).setFill()
        box.fill()
        NSColor(srgbRed: 0.97, green: 0.97, blue: 0.94, alpha: reveal).setFill()
        // A pixel X, drawn rather than set in a font: everything else here is pixel art
        // and a smooth glyph beside it looks like a bug.
        let pip = (Self.closeSize / 11).rounded()
        for i in 0..<7 {
            let a = NSRect(x: box.minX + pip * (2 + CGFloat(i)),
                           y: box.minY + pip * (2 + CGFloat(i)), width: pip, height: pip)
            let b = NSRect(x: box.minX + pip * (2 + CGFloat(i)),
                           y: box.minY + pip * (8 - CGFloat(i)), width: pip, height: pip)
            a.fill(); b.fill()
        }
    }
}
