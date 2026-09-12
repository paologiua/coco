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
    private static let needIcon = 18.0
    /// Her face. Sized so that the HEAD stands as tall as the three rows beside it,
    /// which is what makes the block read as one thing rather than as a small picture
    /// parked beside a table.
    ///
    /// Four times the 22 points the icon is declared at, and the multiple is the whole
    /// reason for the number: the file is pixel art, so only a whole multiple draws it
    /// as whole square pixels. She is drawn 16 of those 22 points tall — the rest is
    /// the sky her sparkles and her rain cloud live in — so 88 puts her head at 64
    /// against rows that measure 70.
    private static let portrait = 88.0
    private static let inset = 14.0
    /// Between her face and the needs. It used to be whatever was left over once both
    /// were pinned to opposite edges of a fixed width, which was fifty-eight points of
    /// nothing.
    private static let portraitGap = 14.0
    private static let iconGap = 8.0

    private static var barWidth: Double {
        Double(segments) * (segmentSize + segmentGap) - segmentGap
    }

    /// Wide enough for the block and no wider: the widest item sets the menu's width,
    /// and this view is it.
    static var width: Double {
        inset * 2 + portrait + portraitGap + needIcon + iconGap + barWidth
    }

    /// The three rows, first icon's top to last icon's bottom.
    private static var rowsHeight: Double { 2 * rowHeight + needIcon }
    /// Whichever of the two is taller. The block is as tall as that.
    private static var blockHeight: Double { max(portrait, rowsHeight) }

    var moodImage: NSImage?
    var needs: Needs = .full
    var moodLabel: String = ""

    private let icons: [String: NSImage]
    /// The same three drawn with a lighter rim. The near-black one these ship with is
    /// the dark menu's own background: it drops out, and the glyph left behind is a
    /// different shape — the seed rounds off into an octagon, the heart loses the notch
    /// between its lobes. Picked between at draw time, in `needIcon(_:)`.
    private let darkIcons: [String: NSImage]

    init(icons: [String: NSImage], darkIcons: [String: NSImage]) {
        self.icons = icons
        self.darkIcons = darkIcons
        // The 48 is the sentence above the block and the margins around it, which are
        // the same whatever is in the block.
        super.init(frame: NSRect(x: 0, y: 0, width: Self.width,
                                 height: Self.blockHeight + 48))
    }

    required init?(coder: NSCoder) { nil }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none

        let inset = Self.inset
        let barWidth = Self.barWidth
        // Bars are pinned to the right edge and the icons sit immediately left of them,
        // so the three rows line up as one block however long the mood sentence is.
        let barX = bounds.width - inset - barWidth
        let iconX = barX - Self.needIcon - Self.iconGap

        let label = NSAttributedString(string: moodLabel, attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.labelColor,
        ])
        label.draw(at: NSPoint(x: inset, y: 12))

        let bodyTop = 12 + label.size().height + 8
        // Face and rows are centred against each other, so neither hangs off the other
        // whichever of the two is taller.
        let portraitY = bodyTop + (Self.blockHeight - Self.portrait) / 2
        let rowsY = bodyTop + (Self.blockHeight - Self.rowsHeight) / 2
        moodImage?.draw(in: NSRect(x: inset, y: portraitY,
                                   width: Self.portrait, height: Self.portrait))

        let rows: [(String, Double, NSColor)] = [
            ("hunger", needs.hunger, NSColor(srgbRed: 0.851, green: 0.769, blue: 0.549, alpha: 1)),
            ("affection", needs.affection, NSColor(srgbRed: 0.357, green: 0.384, blue: 0.722, alpha: 1)),
            ("energy", needs.energy, NSColor(srgbRed: 0.910, green: 0.812, blue: 0.247, alpha: 1)),
        ]
        for (index, row) in rows.enumerated() {
            let y = rowsY + Double(index) * Self.rowHeight
            needIcon(row.0)?.draw(in: NSRect(x: iconX, y: y,
                                             width: Self.needIcon, height: Self.needIcon))
            drawBar(value: row.1, colour: row.2, origin: NSPoint(x: barX, y: y + 4), width: barWidth)
        }
    }

    /// Whichever rim reads against the menu being drawn into. Asked here rather than
    /// held, because the appearance can change under a running app and this view is
    /// redrawn every time the menu opens.
    private func needIcon(_ name: String) -> NSImage? {
        let dark = NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return (dark ? darkIcons[name] : icons[name]) ?? icons[name]
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
