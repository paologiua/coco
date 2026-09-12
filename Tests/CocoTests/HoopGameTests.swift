import Foundation
import Testing
@testable import Coco

struct HoopGameTests {
    let hoop = CGPoint(x: 400, y: 300)

    @Test func proximityAloneDoesNotEarnPasses() {
        var game = HoopGame()
        for _ in 0..<100 { _ = game.target(bird: hoop, hoop: hoop, scale: 1) }
        #expect(game.passes == 0)
    }

    @Test func completeCrossingsCountInBothDirections() {
        var game = HoopGame()
        for x in [328.0, 380, 420, 472] {
            _ = game.target(bird: CGPoint(x: x, y: 300), hoop: hoop, scale: 1)
        }
        #expect(game.passes == 1)
        for x in [472.0, 420, 380, 328] {
            _ = game.target(bird: CGPoint(x: x, y: 300), hoop: hoop, scale: 1)
        }
        #expect(game.passes == 2)
    }

    @Test func movingHoopOverBirdDoesNotCount() {
        var game = HoopGame()
        _ = game.target(bird: CGPoint(x: 328, y: 300), hoop: hoop, scale: 1)
        _ = game.target(bird: CGPoint(x: 380, y: 300), hoop: hoop, scale: 1)
        _ = game.target(bird: CGPoint(x: 380, y: 300), hoop: CGPoint(x: 300, y: 300), scale: 1)
        #expect(game.passes == 0)
    }

    /// The bug this guards: the scoring band was a flat 22 against a ring whose own
    /// half-height is 17.5, so a point was awarded for passing OUTSIDE the ring — the
    /// counter went up while she visibly flew past it. The band has to stay inside the
    /// drawing at every scale, or the reward stops matching the picture.
    @MainActor
    @Test func aPointIsNeverAwardedForPassingOutsideTheRing() {
        #expect(HoopGame.scoringBand < HoopGame.ringHalfHeight)

        for scale in [1.0, 2, 4, Double(AppDelegate.hoopScale)] {
            var game = HoopGame()
            // Cross level with the ring's rim rather than its middle: visibly not
            // through it.
            let missBy = HoopGame.ringHalfHeight * scale * 0.95
            let run = 40 * scale
            for point in [CGPoint(x: hoop.x - run, y: hoop.y),
                          CGPoint(x: hoop.x - 8, y: hoop.y + missBy),
                          CGPoint(x: hoop.x + 8, y: hoop.y + missBy),
                          CGPoint(x: hoop.x + run, y: hoop.y)] {
                _ = game.target(bird: point, hoop: hoop, scale: scale)
            }
            #expect(game.passes == 0, "ha segnato passando al bordo dell'anello a scala \(scale)")
        }
    }

    @Test func flyingOutsideOpeningDoesNotCount() {
        var game = HoopGame()
        for point in [CGPoint(x: 328, y: 300), CGPoint(x: 380, y: 400),
                      CGPoint(x: 420, y: 400), CGPoint(x: 472, y: 300)] {
            _ = game.target(bird: point, hoop: hoop, scale: 1)
        }
        #expect(game.passes == 0)
    }
}
