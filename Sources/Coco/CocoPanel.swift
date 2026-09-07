import AppKit

/// The window Coco lives in: borderless, transparent, above everything, and
/// incapable of taking focus from whatever the human is actually doing.
final class CocoPanel: NSPanel {
    let scale: Int

    init(scale: Int) {
        self.scale = scale
        let width = CGFloat(Canvas.width * scale)
        let height = CGFloat(Canvas.stageHeight * scale)
        super.init(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)

        // Order matters. Setting isFloatingPanel forces the level back to 3, which is
        // BELOW the Dock (level 20) — so it is set first and left false deliberately.
        // See .scratch/coco-v1/issues/03-floating-panel-behaviour.md.
        isFloatingPanel = false
        level = .statusBar

        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        isReleasedWhenClosed = false
    }

    // A panel that can never become key cannot hold a text insertion point. That is the
    // point: clicking Coco must not steal the caret from the app in front. It also means
    // settings must live in a separate ordinary window.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
