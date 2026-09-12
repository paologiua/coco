import AppKit

/// The first launch: an egg, and Coco coming out of it.
///
/// It replaces a speech bubble that said hello. A bubble is Coco telling you something;
/// this is Coco arriving, which is the thing the first launch is actually for.
@MainActor
final class Hatching {
    /// Frames a second. The sheet is twelve frames and the whole point is watching it,
    /// so it runs slower than the letter opening.
    private static let fps = 5.0
    /// How long the last frame — her idle pose — holds before the real bird takes over.
    private static let settleSeconds = 0.7
    /// Points of clear screen kept under her while she hatches.
    private static let floorMargin = 60.0

    private var notice: NSPanel?
    private var stage: NSPanel?
    private var timer: Timer?
    private var frames: [NSImage] = []
    private var elapsed = 0.0

    /// Called once she is out, with the box her drawn pixels occupy on screen.
    ///
    /// A box, not a corner. The hatch sheet is 147x133 and her canvas is 208x168, and
    /// she sits in a different place inside each — so the only thing the two frames
    /// share is where the BIRD is, and that is what has to be handed over.
    var onHatched: ((CGRect) -> Void)?

    /// Put the egg in front of her. Deliberately has no timeout and cannot be dismissed
    /// by clicking away: everything else in the app can be ignored, but this is the only
    /// route into owning a Coco at all, and a notice you can lose by clicking the wrong
    /// thing would mean a first launch that silently produced nothing.
    func offer(on screen: NSRect) {
        guard notice == nil, stage == nil else { return }
        guard let image = Self.load("notice") else {
            // No card, no ceremony — but she must still arrive.
            finish(on: screen)
            return
        }
        let size = Self.fit(image.size, into: CGSize(width: 520, height: 220))
        let panel = Self.panel(size: size)
        panel.setFrameOrigin(NSPoint(x: (screen.midX - size.width / 2).rounded(),
                                     y: (screen.midY - size.height / 2).rounded()))
        let view = HatchView(frame: NSRect(origin: .zero, size: size))
        view.image = image
        view.onClick = { [weak self] in self?.hatch(on: screen) }
        panel.contentView = view
        panel.orderFrontRegardless()
        notice = panel
    }

    private func hatch(on screen: NSRect) {
        notice?.orderOut(nil)
        notice = nil

        frames = (0..<12).compactMap { Self.load(String(format: "hatch%02d", $0)) }
        guard let first = frames.first else {
            finish(on: screen)
            return
        }

        // Bottom centre, where she will be standing when it is over.
        let size = first.size
        let panel = Self.panel(size: size)
        panel.setFrameOrigin(NSPoint(x: (screen.midX - size.width / 2).rounded(),
                                     y: (screen.minY + Self.floorMargin).rounded()))
        let view = HatchView(frame: NSRect(origin: .zero, size: size))
        view.image = first
        panel.contentView = view
        panel.orderFrontRegardless()
        stage = panel

        elapsed = 0
        let tick = 1.0 / 60
        let timer = Timer(timeInterval: tick, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let view = self.stage?.contentView as? HatchView else { return }
                self.elapsed += tick
                let index = Int(self.elapsed * Self.fps)
                if index < self.frames.count {
                    view.image = self.frames[index]
                } else if self.elapsed >= Double(self.frames.count) / Self.fps + Self.settleSeconds {
                    self.finish(on: screen)
                }
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func finish(on screen: NSRect) {
        timer?.invalidate()
        timer = nil

        // Where the last frame left her, in screen coordinates. With no art there is
        // no bird to measure, so she arrives at the floor of the screen instead.
        let bird = (stage?.frame.origin).flatMap { origin in
            frames.last.map { Self.drawnRect(of: $0, inPanelAt: origin) }
        } ?? CGRect(x: screen.midX, y: screen.minY + Self.floorMargin,
                    width: 0, height: 0)

        // Her first, the egg second. Ordered the other way round there is a beat with
        // neither on screen, and she blinks out of existence on the way in.
        notice?.orderOut(nil)
        notice = nil
        onHatched?(bird)
        stage?.orderOut(nil)
        stage = nil
        frames = []
    }

    /// The box the drawn pixels of `image` occupy on screen, given the panel origin it
    /// is drawn in. The stage draws its frames at one point per pixel, so no scaling
    /// comes into it.
    ///
    /// Read from the art rather than measured once and written down as a constant: the
    /// sheet can be redrawn, and a number in the source would go quietly wrong the
    /// first time it is.
    static func drawnRect(of image: NSImage, inPanelAt origin: CGPoint) -> CGRect {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return CGRect(origin: origin, size: .zero)
        }
        let w = cg.width, h = cg.height
        var raw = [UInt8](repeating: 0, count: w * h * 4)
        var minX = w, maxX = -1, minY = h, maxY = -1

        // The pointer CGContext is given must not outlive this closure.
        raw.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress,
                                      width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            ctx.interpolationQuality = .none
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

            // Row 0 of the buffer is the TOP of the image — measured, not assumed, and
            // the reason this is not simply `origin.y + minY` below.
            let bytes = buffer.bindMemory(to: UInt8.self)
            for y in 0..<h {
                for x in 0..<w where bytes[(y * w + x) * 4 + 3] > 127 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= 0 else { return CGRect(origin: origin, size: .zero) }

        // The scan counted pixels, top-down; the panel is measured in points, bottom-up.
        // The scale is 1 for the sheet as it is drawn today and would silently stop
        // being so the day a frame is redrawn at 2x.
        let sx = image.size.width / Double(w), sy = image.size.height / Double(h)
        return CGRect(x: origin.x + Double(minX) * sx,
                      y: origin.y + Double(h - 1 - maxY) * sy,
                      width: Double(maxX - minX + 1) * sx,
                      height: Double(maxY - minY + 1) * sy)
    }

    private static func load(_ name: String) -> NSImage? {
        Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Hatch")
            .flatMap(NSImage.init(contentsOf:))
    }

    private static func fit(_ source: CGSize, into box: CGSize) -> CGSize {
        let k = min(box.width / source.width, box.height / source.height)
        return CGSize(width: (source.width * k).rounded(), height: (source.height * k).rounded())
    }

    private static func panel(size: CGSize) -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}

/// Draws one frame, and reports a click if anyone is listening for one.
private final class HatchView: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?

    /// Coco never activates, so without this AppKit swallows the first click while
    /// another application is frontmost — which it always is on a first launch.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }
}
