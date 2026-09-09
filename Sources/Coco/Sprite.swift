import AppKit

/// Coco is drawn on a 64x64 canvas; perched, she occupies the bottom 48x48 of it,
/// horizontally centred.
///
/// Neither margin is decoration. The perched sprite fills its own 48x48 frame to the
/// top row — her head touches the edge — so the 16 rows above exist to hold the party
/// hat and the speech bubble. The 8 columns either side exist because with her wings
/// spread she is 52 pixels wide and would otherwise lose her wingtips.
///
/// Everything — masks, hit tests, window size — is therefore expressed in canvas
/// coordinates, never sprite ones.
enum Canvas {
    /// One canvas pixel is one point: Coco is drawn at the size she is shown at, with
    /// no magnification. She used to be stored at 48 pixels and doubled, which threw
    /// away seven eighths of what the sheets hold and then made every surviving pixel
    /// twice as coarse — the graininess was that, not the conversion.
    ///
    /// Wider than tall because of the wings: a spread wingbeat is 148 points across
    /// and 120 tall, and this leaves a little margin around the widest of them.
    static let width = 208
    static let height = 168
    static let size = NSSize(width: width, height: height)

    /// Rows above the canvas that only particles use — rising Zzz, hearts, confetti.
    ///
    /// Deliberately NOT part of the canvas: the stage is simply taller than the canvas,
    /// with sprites pinned to its floor. Kept at half her height, as it always was.
    /// Points below her feet that belong to the canvas but not to the ground.
    ///
    /// A wing at the bottom of its beat dips under the line she stands on, which is
    /// what a flying bird's wing does. Without this the flight frames had to be slid up
    /// to fit inside the canvas, and that put her head 21 points above where it sits
    /// when she is perched: every take-off became a hop.
    static let floorMargin = 26

    static let particleHeadroom = 41
    static let stageHeight = height + particleHeadroom
}

/// One drawable layer on the canvas: the bird, or something worn over her.
struct Sprite {
    /// The file it came from. Used to tell frames apart cheaply, so the view is only
    /// marked dirty when the drawing actually changes rather than every tick.
    let name: String
    let image: NSImage
    /// Row-major, `Canvas.width * Canvas.height`, top-down. True where drawn.
    private let opaque: [Bool]
    /// Centre of the drawn pixels in canvas coordinates, origin top-left.
    ///
    /// Not the centre of the canvas. Coco does not fill it — a perched bird sits in the
    /// bottom half and a wingbeat reaches across most of the width — so assuming the
    /// middle put her "body" in empty air above her head once the canvas grew tall
    /// enough to hold spread wings, and she fled the cursor from a point she was not
    /// standing at.
    let drawnCentre: CGPoint

    init?(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Sprites"),
              let source = NSImage(contentsOf: url) else { return nil }
        self.init(name: name, source: source)
    }

    init?(name: String, source: NSImage) {
        guard let built = Sprite.pad(source) else { return nil }
        self.name = name
        (image, opaque) = built
        var minX = Canvas.width, maxX = -1, minY = Canvas.height, maxY = -1
        for y in 0..<Canvas.height {
            for x in 0..<Canvas.width where opaque[y * Canvas.width + x] {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        drawnCentre = maxX < 0
            ? CGPoint(x: Double(Canvas.width) / 2, y: Double(Canvas.height) / 2)
            : CGPoint(x: Double(minX + maxX) / 2, y: Double(minY + maxY) / 2)
    }

    /// True if this layer is drawn at the given canvas pixel, origin top-left.
    ///
    /// `slack` widens the answer by that many pixels in each direction, for hit testing:
    /// she is one point per pixel now, so asking for the exact pixel means asking the
    /// human to hit a tail three points wide.
    func isOpaque(x: Int, y: Int, slack: Int = 0) -> Bool {
        for dy in -slack...slack {
            for dx in -slack...slack {
                let px = x + dx, py = y + dy
                guard px >= 0, py >= 0, px < Canvas.width, py < Canvas.height else { continue }
                if opaque[py * Canvas.width + px] { return true }
            }
        }
        return false
    }

    /// Compose the source onto a full canvas, anchored at the bottom, and read its
    /// alpha back out. A source already the size of the canvas is placed as-is.
    private static func pad(_ source: NSImage) -> (NSImage, [Bool])? {
        let w = Canvas.width, h = Canvas.height
        guard let cg = source.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        var raw = [UInt8](repeating: 0, count: w * h * 4)
        var mask = [Bool](repeating: false, count: w * h)
        var composed: CGImage?

        // The pointer CGContext is given must not outlive this closure, so the drawing
        // and the alpha read both happen inside it.
        raw.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress,
                                      width: w, height: h,
                                      bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }

            ctx.interpolationQuality = .none
            // Bottom-anchored and horizontally centred. CGContext is bottom-up, so
            // y = 0 is the canvas floor. A source already canvas-sized lands exactly.
            let x = (w - cg.width) / 2
            ctx.draw(cg, in: CGRect(x: x, y: 0, width: cg.width, height: cg.height))
            composed = ctx.makeImage()

            let bytes = buffer.bindMemory(to: UInt8.self)
            for y in 0..<h {
                for x in 0..<w {
                    // Flip: buffer row 0 is the canvas floor, mask row 0 is its ceiling.
                    mask[y * w + x] = bytes[((h - 1 - y) * w + x) * 4 + 3] > 127
                }
            }
        }

        guard let composed else { return nil }
        return (NSImage(cgImage: composed, size: Canvas.size), mask)
    }
}
