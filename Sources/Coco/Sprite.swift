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
    static let width = 64
    static let height = 64
    static let size = NSSize(width: width, height: height)

    /// Rows above the canvas that only particles use — rising Zzz, hearts, confetti.
    ///
    /// Deliberately NOT part of the canvas. Growing the canvas a third time would mean
    /// re-cutting every sprite, every hat overlay and every flight frame; the stage is
    /// simply taller than the canvas, with sprites pinned to its floor, so no asset
    /// changes at all.
    static let particleHeadroom = 24
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

    init?(named name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Sprites"),
              let source = NSImage(contentsOf: url) else { return nil }
        self.init(name: name, source: source)
    }

    init?(name: String, source: NSImage) {
        guard let built = Sprite.pad(source) else { return nil }
        self.name = name
        (image, opaque) = built
    }

    /// True if this layer is drawn at the given canvas pixel, origin top-left.
    func isOpaque(x: Int, y: Int) -> Bool {
        guard x >= 0, y >= 0, x < Canvas.width, y < Canvas.height else { return false }
        return opaque[y * Canvas.width + x]
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
