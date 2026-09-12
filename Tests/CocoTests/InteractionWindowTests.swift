import AppKit
import Testing
@testable import Coco

@MainActor
struct InteractionWindowTests {
    @Test func foodReceivesTheFirstClickWhileCocoIsInactive() {
        let view = TargetView(frame: CGRect(x: 0, y: 0, width: 48, height: 48))
        #expect(view.acceptsFirstMouse(for: nil))
    }

    /// The two halves of the hoop are drawn in two windows so Coco can pass through its
    /// depth, and the cut between them used to be the geometric middle. The ring is an
    /// odd number of pixels wide, so that middle is inside a column rather than between
    /// two, and it sliced that column lengthwise.
    @Test func theHoopIsCutBetweenArtPixelsAndNotThroughOne() throws {
        let pixels = 21
        let scale = AppDelegate.hoopScale
        // A real representation, not just an NSImage size: the seam is measured against
        // the grain the artwork is stored at, which is what the size alone cannot say.
        let rep = try #require(NSBitmapImageRep(bitmapDataPlanes: nil,
                                                pixelsWide: pixels, pixelsHigh: 60,
                                                bitsPerSample: 8, samplesPerPixel: 4,
                                                hasAlpha: true, isPlanar: false,
                                                colorSpaceName: .deviceRGB,
                                                bytesPerRow: 0, bitsPerPixel: 0))
        let image = NSImage(size: NSSize(width: pixels, height: 60))
        image.addRepresentation(rep)
        let view = TargetView(frame: CGRect(x: 0, y: 0,
                                            width: CGFloat(pixels * scale), height: 180))
        view.image = image

        let pip = CGFloat(scale)
        #expect(view.seam.truncatingRemainder(dividingBy: pip) == 0,
                "la cucitura cade dentro un pixel del disegno: \(view.seam)")
        // And still within half a pixel of the middle, so the near arc stays the near
        // arc: rounding to the grid must not hand a column to the wrong window.
        #expect(abs(view.seam - view.bounds.midX) <= pip / 2)
    }

    /// The count was pinned to the panel's bottom left corner, and the panel is wider
    /// than the count: it sat off to one side of the ring it counts for.
    @Test func theCountSitsUnderTheMiddleOfTheRing() {
        let pad = InteractionWindow.counterPad
        let view = TargetView(frame: CGRect(x: 0, y: 0, width: 63, height: 180 + pad * 2))
        view.kind = .hoop
        view.verticalPad = pad
        view.passes = 2

        let size = view.counterLabel.size(withAttributes: TargetView.counterAttributes)
        let origin = view.counterOrigin
        // Centred: the margin either side of the label is the same, give or take the
        // half point that rounding it onto the grid can cost.
        #expect(abs(origin.x - (view.bounds.width - size.width - origin.x)) <= 1)
        // And inside the band reserved for it, so it never lands on the ring itself.
        #expect(origin.y >= 0)
        #expect(origin.y + size.height <= pad)
    }
}
