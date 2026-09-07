import AppKit

/// The block at the top of the menu: Coco's face, and her three Needs as pixel bars.
///
/// Drawn rather than assembled from controls because a system progress bar in a menu
/// full of pixel art looks like a bug. Colours for the fills come from the locked
/// palette; everything else uses semantic colours so the block reads correctly in
/// both a light and a dark menu.
@MainActor
final class StatusView: NSView {
    private static let rowHeight = 26.0
    private static let segments = 10
    private static let segmentSize = 9.0
    private static let segmentGap = 2.0
    private static let portrait = 48.0

    var moodImage: NSImage?
    var needs: Needs = .full
    var moodLabel: String = ""

    private let icons: [String: NSImage]

    init(icons: [String: NSImage]) {
        self.icons = icons
        super.init(frame: NSRect(x: 0, y: 0, width: 268, height: 3 * Self.rowHeight + 40))
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none

        let inset = 14.0
        let barWidth = Double(Self.segments) * (Self.segmentSize + Self.segmentGap) - Self.segmentGap
        // Bars are pinned to the right edge and the icons sit immediately left of them,
        // so the three rows line up as one block however long the mood sentence is.
        let barX = bounds.width - inset - barWidth
        let iconX = barX - 26

        let label = NSAttributedString(string: moodLabel, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ])
        label.draw(at: NSPoint(x: inset, y: 12))

        let bodyTop = 12 + label.size().height + 8
        moodImage?.draw(in: NSRect(x: inset, y: bodyTop, width: Self.portrait, height: Self.portrait))

        let rows: [(String, Double, NSColor)] = [
            ("hunger", needs.hunger, NSColor(srgbRed: 0.851, green: 0.769, blue: 0.549, alpha: 1)),
            ("affection", needs.affection, NSColor(srgbRed: 0.357, green: 0.384, blue: 0.722, alpha: 1)),
            ("energy", needs.energy, NSColor(srgbRed: 0.910, green: 0.812, blue: 0.247, alpha: 1)),
        ]
        for (index, row) in rows.enumerated() {
            let y = bodyTop + Double(index) * Self.rowHeight
            icons[row.0]?.draw(in: NSRect(x: iconX, y: y, width: 18, height: 18))
            drawBar(value: row.1, colour: row.2, origin: NSPoint(x: barX, y: y + 4), width: barWidth)
        }
    }

    /// Ten discrete blocks rather than a smooth fill — a continuous bar beside a pixel
    /// bird looks borrowed from another app.
    private func drawBar(value: Double, colour: NSColor, origin: NSPoint, width: Double) {
        let lit = Int((value / 100 * Double(Self.segments)).rounded())
        for i in 0..<Self.segments {
            let rect = NSRect(x: origin.x + Double(i) * (Self.segmentSize + Self.segmentGap),
                              y: origin.y, width: Self.segmentSize, height: 10)
            (i < lit ? colour : NSColor.quaternaryLabelColor).setFill()
            rect.fill()
        }
    }
}
