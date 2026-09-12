import Foundation

/// A pass starts outside one side and finishes outside the other. Moving the hoop
/// during a pass resets the approach, so sweeping it over Coco cannot earn points.
struct HoopGame {
    /// The ring's geometry, in the units `hoop.png` is drawn in.
    ///
    /// Measured from the asset rather than guessed: the drawing is 12 by 35 inside a
    /// 24 by 64 image, so more than half of it is padding. Sizing the game against the
    /// image is what produced a hoop that looked generous and was not, and a scoring
    /// tolerance of 22 — wider than the ring's own half-height of 17.5, so a point was
    /// awarded for passing OUTSIDE the ring she was supposed to go through.
    static let ringHalfHeight = 17.5
    /// How near the middle she has to cross. Comfortably inside the ring, so the point
    /// always comes with the picture of her going through it.
    static let scoringBand = ringHalfHeight * 0.6
    private(set) var passes = 0
    private var anchor: CGPoint?
    private var entrySide = -1.0
    private var crossing = false
    private var crossedCentre = false
    private var previousBird: CGPoint?

    /// `reach` is the band her middle can actually be moved into — narrower than the
    /// screen, because the window is wider than she is. The run-up is 144 points long, so a hoop
    /// held near an edge puts the approach off screen: she cannot get there, the driver
    /// pins her to the edge, and she chases a point that does not exist until the game
    /// times out. Held in the middle of the screen the same code works, which is why
    /// this took a while to see.
    mutating func target(bird: CGPoint, hoop: CGPoint, scale: Double,
                         reach: ClosedRange<Double>? = nil) -> CGPoint {
        // The run-up. 72 was written when the hoop was drawn at 2x, and at 6x it became
        // 432 points — a third of the screen, most of it spent flying in from off in the
        // distance, and far enough out to collide with the edges of her reach.
        let clearance = 36 * scale
        let lo = reach?.lowerBound ?? -Double.infinity
        let hi = reach?.upperBound ?? Double.infinity
        if anchor == nil || hypot(hoop.x - anchor!.x, hoop.y - anchor!.y) > 8 * scale {
            anchor = hoop
            // Approach from the side she is on, unless that side has no room for the
            // run-up, in which case go round.
            var side = bird.x < hoop.x ? -1.0 : 1.0
            if hoop.x + side * clearance < lo || hoop.x + side * clearance > hi {
                side *= -1
            }
            entrySide = side
            crossing = false
            crossedCentre = false
            previousBird = nil
        }
        guard let anchor else { return hoop }
        let entry = CGPoint(x: min(max(anchor.x + entrySide * clearance, lo), hi), y: anchor.y)
        let exit = CGPoint(x: min(max(anchor.x - entrySide * clearance, lo), hi), y: anchor.y)
        defer { previousBird = bird }

        if !crossing {
            if hypot(bird.x - entry.x, bird.y - entry.y) <= 24 {
                crossing = true
            } else {
                return entry
            }
        }

        if let previousBird {
            let before = (previousBird.x - anchor.x) * entrySide
            let after = (bird.x - anchor.x) * entrySide
            if before > 0, after <= 0 {
                let t = before / (before - after)
                let crossingY = previousBird.y + t * (bird.y - previousBird.y)
                crossedCentre = abs(crossingY - anchor.y) <= Self.scoringBand * scale
                // Scored here, as she goes through, rather than when she reaches the
                // far side. The flight carries on for another half second after the
                // ring, and a point that arrives then reads as unrelated to it.
                if crossedCentre { passes += 1 }
            }
        }
        if hypot(bird.x - exit.x, bird.y - exit.y) <= 24 {
            entrySide *= -1
            crossing = false
            crossedCentre = false
        }
        return exit
    }
}
