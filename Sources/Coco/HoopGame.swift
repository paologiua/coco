import Foundation

/// A pass starts outside one side and finishes outside the other. Moving the hoop
/// during a pass resets the approach, so sweeping it over Coco cannot earn points.
struct HoopGame {
    /// How far to the side of the ring her run-up starts, in points.
    ///
    /// A plain distance rather than a multiple of the art's scale: it was 72 units when
    /// the hoop was drawn at 2x, and enlarging the ring silently turned that into 432
    /// points — a third of the screen, most of it spent arriving from the distance.
    static let clearance = 210.0
    /// How near the middle of the opening she has to cross, as a fraction of its half
    /// height. Strictly less than one, and that is the whole point: the band used to be
    /// a flat 22 against a ring whose own half-height was 17.5, so the counter went up
    /// for passing OUTSIDE the ring she was supposed to fly through.
    static let scoringFraction = 0.6

    private(set) var passes = 0
    private var anchor: CGPoint?
    private var entrySide = -1.0
    private var crossing = false
    private var crossedCentre = false
    private var previousBird: CGPoint?

    /// `reach` is the band her middle can actually be moved into — narrower than the
    /// screen, because the window is wider than she is. The run-up is long, so a hoop
    /// held near an edge puts the approach off screen: she cannot get there, the driver
    /// pins her to the edge, and she chases a point that does not exist until the game
    /// times out. Held in the middle of the screen the same code works, which is why
    /// this took a while to see.
    /// `opening` is half the height of the hole through the ring, in points — the gap
    /// she actually has to fly through, not the size of the image it is drawn in.
    mutating func target(bird: CGPoint, hoop: CGPoint, opening: Double,
                         reach: ClosedRange<Double>? = nil) -> CGPoint {
        let clearance = Self.clearance
        let lo = reach?.lowerBound ?? -Double.infinity
        let hi = reach?.upperBound ?? Double.infinity
        if anchor == nil || hypot(hoop.x - anchor!.x, hoop.y - anchor!.y) > 16 {
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
                crossedCentre = abs(crossingY - anchor.y) <= opening * Self.scoringFraction
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
