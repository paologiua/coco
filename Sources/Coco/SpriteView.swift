import AppKit

/// Draws the stage: Coco on its floor, and the particles rising through the rows above
/// her. There is no second layer for the party hat — it is baked into her frames, so
/// the view has exactly one sprite to draw and one alpha mask to hit-test.
final class SpriteView: NSView {
    var sprite: Sprite? { didSet { needsDisplay = true } }
    /// Coco is drawn facing right and mirrored to face left, so no frame is drawn twice.
    var facingRight = true {
        didSet { if facingRight != oldValue { needsDisplay = true } }
    }
    /// Rising marks, in stage pixels. Never mirrored: a flipped heart is still a heart,
    /// but a flipped Z is a mistake.
    var particles: [ParticleField.Particle] = []
    /// Points per stage pixel.
    var scale: CGFloat = 3

    /// The mouse went down on Coco's drawn pixels.
    var onPress: (() -> Void)?
    /// The mouse moved while held down, reported as an absolute screen location.
    /// Absolute, not a delta: a dropped event must not become permanent drift.
    var onDragTo: ((NSPoint) -> Void)?
    /// The gesture ended. `wasClick` is true if the pointer never really moved.
    var onRelease: ((_ wasClick: Bool) -> Void)?

    private var pressedAt: NSPoint?
    private var hasMoved = false
    /// Below this, a wobble during a click is not a drag.
    private static let dragThreshold: CGFloat = 3

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        // .default blurs exactly as much as .high — nearest is never the default
        // anywhere in the stack and has to be asked for explicitly.
        NSGraphicsContext.current?.imageInterpolation = .none
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Sprites sit on the stage floor; the rows above them belong to particles.
        let spriteRect = NSRect(x: 0,
                                y: CGFloat(Canvas.particleHeadroom) * scale,
                                width: CGFloat(Canvas.width) * scale,
                                height: CGFloat(Canvas.height) * scale)

        ctx.saveGState()
        if !facingRight {
            ctx.translateBy(x: bounds.width, y: 0)
            ctx.scaleBy(x: -1, y: 1)
        }
        sprite?.image.draw(in: spriteRect,
                           from: .zero,
                           operation: .sourceOver,
                           fraction: 1.0,
                           respectFlipped: true,
                           hints: [.interpolation: NSImageInterpolation.none.rawValue])
        ctx.restoreGState()

        drawParticles(in: ctx)
    }

    private func drawParticles(in ctx: CGContext) {
        for particle in particles {
            let rows = ParticleField.matrix(for: particle.kind)
            particle.tint.withAlphaComponent(particle.fade).setFill()
            // One cell of the matrix is `pip` points across, so the next one starts
            // `pip` points along. Stepping by anything else stacks them: the cells were
            // laid out a point apart while being drawn five points wide, so a Z came out
            // as a solid square and the sleeping marks stopped reading as letters.
            // A particle's position is the CENTRE of its mark, not the top-left corner
            // of its matrix. As a corner it was off by half a mark in both directions,
            // which at fifteen points across is most of the distance between sitting on
            // her head and floating beside it.
            let pip = CGFloat(ParticleField.pip)
            let originX = particle.position.x * scale - CGFloat(rows[0].count) * pip / 2
            let originY = particle.position.y * scale - CGFloat(rows.count) * pip / 2
            for (row, line) in rows.enumerated() {
                for (column, character) in line.enumerated() where character == "#" {
                    let rect = NSRect(x: originX + CGFloat(column) * pip,
                                      y: originY + CGFloat(row) * pip,
                                      width: pip, height: pip)
                    ctx.fill(rect)
                }
            }
        }
    }

    // MARK: - Gestures

    override func mouseDown(with event: NSEvent) {
        pressedAt = NSEvent.mouseLocation
        hasMoved = false
        onPress?()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressedAt else { return }
        let now = NSEvent.mouseLocation
        if !hasMoved, hypot(now.x - start.x, now.y - start.y) > Self.dragThreshold {
            hasMoved = true
        }
        if hasMoved { onDragTo?(now) }
    }

    override func mouseUp(with event: NSEvent) {
        // A press that never really moved is a pet, not a drag.
        onRelease?(!hasMoved)
        pressedAt = nil
        hasMoved = false
    }
}
