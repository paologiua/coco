import Foundation
import Testing
@testable import Coco

struct HoopGameTests {
    let hoop = CGPoint(x: 400, y: 300)

    @Test func proximityAloneDoesNotEarnPasses() {
        var game = HoopGame()
        for _ in 0..<100 { _ = game.target(bird: hoop, hoop: hoop, opening: 40) }
        #expect(game.passes == 0)
    }

    /// Written against the run-up rather than against remembered coordinates: the
    /// numbers here were once literals sized for a 72-point approach, and enlarging the
    /// ring left them short of the entry point, so the test quietly stopped crossing
    /// anything at all.
    @Test func completeCrossingsCountInBothDirections() {
        let run = HoopGame.clearance
        var game = HoopGame()
        for x in [hoop.x - run, hoop.x - 20, hoop.x + 20, hoop.x + run] {
            _ = game.target(bird: CGPoint(x: x, y: 300), hoop: hoop, opening: 40)
        }
        #expect(game.passes == 1)
        for x in [hoop.x + run, hoop.x + 20, hoop.x - 20, hoop.x - run] {
            _ = game.target(bird: CGPoint(x: x, y: 300), hoop: hoop, opening: 40)
        }
        #expect(game.passes == 2)
    }

    @Test func movingHoopOverBirdDoesNotCount() {
        let run = HoopGame.clearance
        var game = HoopGame()
        _ = game.target(bird: CGPoint(x: hoop.x - run, y: 300), hoop: hoop, opening: 40)
        _ = game.target(bird: CGPoint(x: hoop.x - 20, y: 300), hoop: hoop, opening: 40)
        // The hoop is swept over her mid-pass, which restarts the approach.
        _ = game.target(bird: CGPoint(x: hoop.x - 20, y: 300),
                        hoop: CGPoint(x: hoop.x - 100, y: 300), opening: 40)
        #expect(game.passes == 0)
    }

    /// The bug this guards: the scoring band was a flat 22 against a ring whose own
    /// half-height is 17.5, so a point was awarded for passing OUTSIDE the ring — the
    /// counter went up while she visibly flew past it. The band has to stay inside the
    /// drawing at every scale, or the reward stops matching the picture.
    @MainActor
    @Test func aPointIsNeverAwardedForPassingOutsideTheRing() {
        #expect(HoopGame.scoringFraction < 1)

        for opening in [40.0, 80, AppDelegate.hoopOpening] {
            var game = HoopGame()
            // Cross level with the rim of the opening rather than its middle: visibly
            // not through it.
            let missBy = opening * 0.95
            let run = HoopGame.clearance * 0.9
            for point in [CGPoint(x: hoop.x - run, y: hoop.y),
                          CGPoint(x: hoop.x - 8, y: hoop.y + missBy),
                          CGPoint(x: hoop.x + 8, y: hoop.y + missBy),
                          CGPoint(x: hoop.x + run, y: hoop.y)] {
                _ = game.target(bird: point, hoop: hoop, opening: opening)
            }
            #expect(game.passes == 0,
                    "ha segnato passando al bordo dell'apertura (semi-apertura \(opening))")
        }
    }

    @Test func flyingOutsideOpeningDoesNotCount() {
        let run = HoopGame.clearance
        var game = HoopGame()
        for point in [CGPoint(x: hoop.x - run, y: 300), CGPoint(x: hoop.x - 20, y: 400),
                      CGPoint(x: hoop.x + 20, y: 400), CGPoint(x: hoop.x + run, y: 300)] {
            _ = game.target(bird: point, hoop: hoop, opening: 40)
        }
        #expect(game.passes == 0)
    }
}
