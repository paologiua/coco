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

    /// Called once she is out, with the point on screen her feet ended on.
    var onHatched: ((CGPoint) -> Void)?

    var isRunning: Bool { notice != nil || stage != nil }

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
        let origin = stage?.frame.origin
            ?? NSPoint(x: screen.midX, y: screen.minY + Self.floorMargin)
        stage?.orderOut(nil)
        stage = nil
        notice?.orderOut(nil)
        notice = nil
        frames = []
        onHatched?(CGPoint(x: origin.x, y: origin.y))
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
