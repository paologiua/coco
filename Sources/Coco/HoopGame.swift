import Foundation

/// A pass starts outside one side and finishes outside the other. Moving the hoop
/// during a pass resets the approach, so sweeping it over Coco cannot earn points.
struct HoopGame {
    private(set) var passes = 0
    private var anchor: CGPoint?
    private var entrySide = -1.0
    private var crossing = false
    private var crossedCentre = false
    private var previousBird: CGPoint?

    mutating func target(bird: CGPoint, hoop: CGPoint, scale: Double) -> CGPoint {
        let clearance = 72 * scale
        if anchor == nil || hypot(hoop.x - anchor!.x, hoop.y - anchor!.y) > 8 * scale {
            anchor = hoop
            entrySide = bird.x < hoop.x ? -1 : 1
            crossing = false
            crossedCentre = false
            previousBird = nil
        }
        guard let anchor else { return hoop }
        let entry = CGPoint(x: anchor.x + entrySide * clearance, y: anchor.y)
        let exit = CGPoint(x: anchor.x - entrySide * clearance, y: anchor.y)
        defer { previousBird = bird }

        if !crossing {
            if hypot(bird.x - entry.x, bird.y - entry.y) <= 12 {
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
                crossedCentre = abs(crossingY - anchor.y) <= 22 * scale
            }
        }
        if hypot(bird.x - exit.x, bird.y - exit.y) <= 12 {
            if crossedCentre { passes += 1 }
            entrySide *= -1
            crossing = false
            crossedCentre = false
        }
        return exit
    }
}
