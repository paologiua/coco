import AppKit
import Testing
@testable import Coco

@MainActor
struct BehaviourTests {
    let now = Date()
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    func makeDriver(_ sim: Simulation) throws -> BehaviourDriver {
        let image = NSImage(size: Canvas.size)
        image.lockFocus()
        NSColor.green.setFill()
        NSRect(origin: .zero, size: Canvas.size).fill()
        image.unlockFocus()
        let sprite = try #require(Sprite(name: "fixture", source: image))
        let set = BehaviourDriver.SpriteSet(idle: sprite, sad: sprite,
                                           blink: Array(repeating: sprite, count: 4),
                                           petted: Array(repeating: sprite, count: 4),
                                           walk: Array(repeating: sprite, count: 4),
                                           fly: Array(repeating: sprite, count: 4),
                                           peck: Array(repeating: sprite, count: 8),
                                           hatted: [:])
        return BehaviourDriver(sim: sim, sprites: set,
                               canvasSize: CGSize(width: Double(Canvas.width * 2),
                                                  height: Double(Canvas.stageHeight * 2)), scale: 2,
                               start: CGPoint(x: 300, y: 400))
    }

    @Test func corneredAgainstAnEdgeSheFleesPastTheHand() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        // Hard against the right edge, with the hand just inside her personal space to
        // her left. "Away from the hand" is rightwards, where there is no room left:
        // she arrives instantly, rests, is startled again, and flaps against the wall
        // for as long as the hand stays there.
        let wall = screen.maxX - Double(Canvas.width * 2)
        driver.moveTo(CGPoint(x: wall, y: screen.minY))
        driver.stay(for: 30)
        let hand = CGPoint(x: driver.bodyCentre.x - 80, y: driver.bodyCentre.y)

        var ticksToEscape = 0
        for i in 0..<400 {
            driver.tick(dt: 0.1, now: now.addingTimeInterval(Double(i) * 0.1),
                        cursor: hand, screen: screen)
            if hypot(driver.bodyCentre.x - hand.x, driver.bodyCentre.y - hand.y)
                > BehaviourDriver.personalSpace {
                ticksToEscape = i
                break
            }
        }
        #expect(ticksToEscape > 0, "never escaped at all")
        #expect(ticksToEscape <= 15, "took \(ticksToEscape) ticks to get clear of the hand")
    }

    @Test func sleepFliesDownBeforeClosingEyes() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        sim.putToSleep(at: now)
        driver.tick(dt: 0.1, now: now, cursor: .zero, screen: screen)
        #expect(driver.behaviour == .flying)
        #expect(driver.position.y < 400)
        for _ in 0..<40 { driver.tick(dt: 0.1, now: now, cursor: .zero, screen: screen) }
        #expect(driver.behaviour == .sleeping)
        #expect(driver.position.y == 0)
    }

    @Test func movingPerchStartlesInsteadOfFollowingWindow() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        let perch = Perch(id: 7, frame: CGRect(x: 100, y: 0, width: 500, height: 300))
        driver.availablePerches = [perch]
        sim.putToSleep(at: now)
        for _ in 0..<15 { driver.tick(dt: 0.1, now: now, cursor: .zero, screen: screen) }
        #expect(driver.behaviour == .sleeping)
        #expect(driver.position.y == 300)
        driver.availablePerches = []
        driver.tick(dt: 0.1, now: now, cursor: .zero, screen: screen)
        #expect(driver.behaviour == .flying)
        driver.tick(dt: 0.1, now: now, cursor: .zero, screen: screen)
        #expect(driver.position.y > 300)
    }

    @Test func interactionApproachesInsteadOfFleeingCursor() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        driver.interactionTarget = CGPoint(x: 500, y: 464)
        driver.tick(dt: 0.1, now: now, cursor: driver.bodyCentre, screen: screen)
        #expect(driver.position.x > 300)
        #expect(driver.behaviour == .flying)
        driver.beginDrag()
        #expect(driver.interactionTarget == nil)
    }

    @Test func feedingDoesNotTurnTheWaitingHandIntoAThreat() throws {
        let sim = Simulation(state: {
            var state = SavedState.fresh(now: now)
            state.needs.hunger = 50
            return state
        }())
        let driver = try makeDriver(sim)
        let hand = driver.bodyCentre

        #expect(sim.feed() == .done)
        driver.interactionTarget = nil
        driver.eat()
        driver.welcomeCursor()
        driver.tick(dt: 1.3, now: now.addingTimeInterval(1.3), cursor: hand, screen: screen)
        driver.tick(dt: 0.1, now: now.addingTimeInterval(1.4), cursor: hand, screen: screen)

        #expect(sim.needs.hunger == 60)
        #expect(driver.behaviour != .flying)

        // The hand has not moved since it fed her, so it is still not a threat: this
        // used to expire on a three-second timer and she flew off from the person who
        // had just fed her.
        //
        // Park her first. `rest` schedules against the wall clock while `tick` takes an
        // injected date, so left alone she may decide to wander mid-test and the flight
        // she chooses is indistinguishable from a startle. Resting still startles.
        driver.stay(for: 60)
        driver.tick(dt: 0.1, now: now.addingTimeInterval(3.1), cursor: hand, screen: screen)
        driver.tick(dt: 0.1, now: now.addingTimeInterval(9.0), cursor: hand, screen: screen)
        #expect(driver.behaviour != .flying)

        // Withdrawing ends the welcome, and coming back is an ordinary approach.
        let away = CGPoint(x: hand.x + 400, y: hand.y)
        driver.tick(dt: 0.1, now: now.addingTimeInterval(9.1), cursor: away, screen: screen)
        driver.tick(dt: 0.1, now: now.addingTimeInterval(9.2), cursor: hand, screen: screen)
        #expect(driver.behaviour == .flying)
    }

    @Test func offeredFoodBroughtCloserDoesNotPushHerAway() throws {
        let sim = Simulation(state: {
            var state = SavedState.fresh(now: now)
            state.needs.hunger = 50
            return state
        }())
        let driver = try makeDriver(sim)
        driver.interactionStyle = .waitBeside

        // Fly her over to the food, which sits 65 points to her right.
        var hand = CGPoint(x: driver.bodyCentre.x + 300, y: driver.bodyCentre.y)
        for step in 0..<200 {
            driver.interactionTarget = CGPoint(x: hand.x - 65, y: hand.y)
            driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(step) * 0.05),
                        cursor: hand, screen: screen)
        }
        let waiting = driver.bodyCentre
        #expect(driver.behaviour != .flying)
        #expect(abs(waiting.x - (hand.x - 65)) < 4)

        // Now bring the food to her, which is what a person actually does. She must
        // hold still: a standoff maintained against an approaching cursor retreats as
        // fast as the hand advances, so she could never be fed and read as fleeing.
        for step in 0..<15 {
            hand.x -= 4
            driver.interactionTarget = CGPoint(x: hand.x - 65, y: hand.y)
            driver.tick(dt: 0.05, now: now.addingTimeInterval(10 + Double(step) * 0.05),
                        cursor: hand, screen: screen)
        }
        #expect(driver.behaviour != .flying)
        #expect(abs(driver.bodyCentre.x - waiting.x) < 1)
        // And she is still inside the radius a click needs to feed her.
        #expect(hypot(driver.bodyCentre.x - hand.x,
                      driver.bodyCentre.y - hand.y) < BehaviourDriver.personalSpace)
    }

    @Test func foodCarriedOutOfReachIsWorthFollowing() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        driver.interactionStyle = .waitBeside

        var hand = CGPoint(x: driver.bodyCentre.x + 65, y: driver.bodyCentre.y)
        for step in 0..<40 {
            driver.interactionTarget = CGPoint(x: hand.x - 65, y: hand.y)
            driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(step) * 0.05),
                        cursor: hand, screen: screen)
        }
        #expect(driver.behaviour != .flying)

        hand.x += 400
        driver.interactionTarget = CGPoint(x: hand.x - 65, y: hand.y)
        driver.tick(dt: 0.05, now: now.addingTimeInterval(5), cursor: hand, screen: screen)
        #expect(driver.behaviour == .flying)
    }

    @Test func birdCanCompleteThreeHoopPassesBeforeTimeout() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        var game = HoopGame()
        let hoop = CGPoint(x: 500, y: 300)
        for tick in 0..<200 {
            driver.interactionTarget = game.target(bird: driver.bodyCentre, hoop: hoop, scale: 2)
            driver.tick(dt: 0.1, now: now.addingTimeInterval(Double(tick) / 10),
                        cursor: hoop, screen: screen)
            if game.passes == 3 { break }
        }
        #expect(game.passes == 3)
    }
}
