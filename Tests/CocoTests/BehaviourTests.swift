import AppKit
import Testing
@testable import Coco

@MainActor
struct BehaviourTests {
    let now = Date()
    let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

    /// Named rather than interchangeable, so a test can tell which clip is playing.
    ///
    /// `inset` shifts where the sprite is drawn inside the canvas. The flight frames
    /// use it so that they do NOT all share a drawn centre: with one shape for every
    /// frame, anything reading the current frame's geometry looks stable in a test and
    /// swings with the wingbeat in the app.
    func fixture(_ name: String, inset: CGFloat = 0, lift: CGFloat = 0) throws -> Sprite {
        let image = NSImage(size: Canvas.size)
        image.lockFocus()
        NSColor.green.setFill()
        // Shaped like the real thing rather than filling the canvas: she occupies about
        // 105 by 82 of a 208 by 168 canvas, sitting on the floor margin with sky above
        // her head. A fixture that fills the canvas hides every bug about the gap
        // between her drawing and her window — which is most of the geometry here.
        //
        // `inset` is anchored left so a bigger one moves the drawn CENTRE right, and
        // `lift` does the same vertically: the real flight frames' centres differ by
        // about ten points across a wingbeat, and a fixture where they do not differ
        // proves nothing about the code that has to cope with it.
        NSRect(x: 51 + inset, y: 27 + lift, width: 105 - inset, height: 81 - lift).fill()
        image.unlockFocus()
        return try #require(Sprite(name: name, source: image))
    }

    func makeDriver(_ sim: Simulation) throws -> BehaviourDriver {
        func many(_ stem: String, _ count: Int) throws -> [Sprite] {
            try (0..<count).map { try fixture("\(stem)_\($0)") }
        }
        let sprite = try fixture("idle")
        let set = BehaviourDriver.SpriteSet(idle: sprite, sad: try fixture("sad"),
                                           blink: try many("blink", 4),
                                           petted: try many("petted", 4),
                                           walk: try many("walk", 4),
                                           fly: try (0..<4).map {
                                               try fixture("fly_\($0)", inset: CGFloat($0) * 12,
                                                           lift: CGFloat($0) * 9)
                                           },
                                           peck: try many("peck", 8),
                                           hatted: [:])
        return BehaviourDriver(sim: sim, sprites: set,
                               canvasSize: CGSize(width: Double(Canvas.width),
                                                  height: Double(Canvas.stageHeight)), scale: 1,
                               start: CGPoint(x: 300, y: 400))
    }

    @Test func sheReachesOfferedFoodInsteadOfHangingInTheAir() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        // The food is aimed at her body. Reading that from the frame being drawn made
        // it move with every wingbeat, so the target slid out from under her on each
        // tick, she never landed inside the tolerance, and she hung there flapping.
        driver.interactionTarget = CGPoint(x: 600, y: 300)

        var arrived = false
        for i in 0..<400 {
            driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(i) * 0.05),
                        cursor: CGPoint(x: -9000, y: -9000), screen: screen)
            if driver.behaviour != .flying { arrived = true; break }
        }
        #expect(arrived, "still flying after 20 seconds of chasing a fixed point")
    }

    @Test func offeredFoodSheSettlesBesideItRatherThanCirclingIt() throws {
        let sim = Simulation(state: {
            var state = SavedState.fresh(now: now)
            state.needs.hunger = 40
            return state
        }())
        let driver = try makeDriver(sim)
        driver.interactionStyle = .waitBeside
        let mouse = CGPoint(x: 700, y: 300)

        // Exactly what the app does every tick while food is out: re-aim at a point
        // beside the hand, on whichever side of it she currently is.
        var settled = 0
        for i in 0..<600 {
            let side = driver.bodyCentre.x < mouse.x ? -1.0 : 1.0
            driver.interactionTarget = CGPoint(x: mouse.x + side * 65, y: mouse.y)
            driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(i) * 0.05),
                        cursor: mouse, screen: screen)
            settled = driver.behaviour == .flying ? 0 : settled + 1
            if settled > 20 { break }
        }
        #expect(settled > 20,
                "never settled: still \(driver.behaviour) at \(Int(driver.position.x))")
    }

    @Test func theHoopIsPlayableInTheMiddleOfTheScreen() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        var game = HoopGame()
        driver.interactionStyle = .chase
        var scored = false
        for i in 0..<1200 {
            driver.interactionTarget = game.target(bird: driver.bodyCentre, hoop: CGPoint(x: 500, y: 400),
                                                   opening: AppDelegate.hoopOpening,
                                                   reach: driver.reachableCentreX(in: screen))
            driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(i) * 0.05),
                        cursor: CGPoint(x: -9000, y: -9000), screen: screen)
            if game.passes >= 1 { scored = true; break }
        }
        #expect(scored, "non ha mai attraversato l'anello in 60 secondi")
    }

    @Test func theAimCentresHerFlyingSilhouetteRatherThanHerWings() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)

        // She only ever enters the hoop in flight, so what has to sit in the middle of
        // it is the band of canvas her wingbeat sweeps — the union of the flight
        // frames, top of the highest to bottom of the lowest.
        func screenY(canvas: Double) -> Double {
            driver.position.y - Double(Canvas.floorMargin) + (Double(Canvas.height) - canvas)
        }
        let lo = driver.sprites.fly.map(\.drawnBounds.minY).min()!
        let hi = driver.sprites.fly.map(\.drawnBounds.maxY).max()!
        let silhouetteCentre = (screenY(canvas: lo) + screenY(canvas: hi)) / 2

        // Where the ring ends up, given the driver is asked to put bodyCentre one
        // offset below it.
        let ringCentre = driver.bodyCentre.y + driver.flightAimOffset

        #expect(abs(ringCentre - silhouetteCentre) < 1,
                "la sagoma di volo non e' centrata nell'anello: scarto \(silhouetteCentre - ringCentre)")

        // And it is NOT the average of the frames' own centres, which is the mistake
        // this replaced: those centres swing with the wings while the bird holds still.
        let meanOfCentres = driver.sprites.fly.map(\.drawnCentre.y)
            .reduce(0, +) / Double(driver.sprites.fly.count)
        let wingAim = (driver.sprites.idle.drawnCentre.y - meanOfCentres) * 1
        if abs(wingAim - driver.flightAimOffset) < 0.001 {
            Issue.record("l'obiettivo coincide con la media dei centri: il fixture non distingue i due casi")
        }
    }

    @Test func theHoopIsPlayableHighOnTheScreen() throws {
        // Her window is 209 points tall and she fills 82 of them, so clamping the
        // WINDOW to the screen walled her body out of the top 168 points of it. Held up
        // there the hoop was somewhere she could not go: she stopped a hundred points
        // short, gave up, and hung in the air well below the ring — reported as
        // stopping as soon as she reached it and never centring on it.
        // Not right against the top: she is 82 points tall, so a ring centred within
        // about 66 of the edge would need her head off the screen, and that is a real
        // limit rather than a bug. These two sit inside it, and both were out of reach
        // when the window rather than the bird was being kept on screen.
        for y in [screen.maxY - 200, screen.maxY - 130] {
            let sim = Simulation(state: .fresh(now: now))
            let driver = try makeDriver(sim)
            var game = HoopGame()
            let hoop = CGPoint(x: 500, y: y)
            driver.interactionStyle = .chase
            var closest = Double.infinity
            for i in 0..<1200 {
                driver.interactionTarget = game.target(bird: driver.bodyCentre, hoop: hoop,
                                                       opening: AppDelegate.hoopOpening,
                                                       reach: driver.reachableCentreX(in: screen))
                driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(i) * 0.05),
                            cursor: CGPoint(x: -9000, y: -9000), screen: screen)
                closest = min(closest, abs(driver.bodyCentre.y - hoop.y))
                if game.passes >= 1 { break }
            }
            #expect(game.passes >= 1,
                    "anello a y=\(Int(y)): mai attraversato, si e' fermata a \(Int(closest)) punti")
        }
    }

    @Test func anImpossibleHoopLeavesHerOnTheFloorNotInTheAir() throws {
        // Held against an edge, the run-up is somewhere she cannot stand and the pass
        // cannot be made at all. What must not happen is her being abandoned mid-air
        // when the game gives up.
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        var game = HoopGame()
        driver.interactionStyle = .chase
        for i in 0..<400 {
            driver.interactionTarget = game.target(bird: driver.bodyCentre, hoop: CGPoint(x: 60, y: 400),
                                                   opening: AppDelegate.hoopOpening,
                                                   reach: driver.reachableCentreX(in: screen))
            driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(i) * 0.05),
                        cursor: CGPoint(x: -9000, y: -9000), screen: screen)
        }
        let strandedAt = driver.position.y
        driver.settle(screen: screen)
        // Does she come DOWN — not where she happens to be twenty seconds later, by
        // which time she may perfectly well have chosen to fly again.
        var lowest = driver.position.y
        for i in 0..<200 {
            driver.tick(dt: 0.05, now: now.addingTimeInterval(20 + Double(i) * 0.05),
                        cursor: CGPoint(x: -9000, y: -9000), screen: screen)
            lowest = min(lowest, driver.position.y)
        }
        #expect(strandedAt > screen.minY + 60, "il caso non riproduce l'abbandono a mezz'aria")
        #expect(lowest < screen.minY + 60,
                "non e' mai tornata a terra: piu' in basso y=\(Int(lowest))")
    }

    @Test func arrivingSomewhereSheStopsWorkingHerLegs() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)

        // Walk somewhere and get there. Arriving calls `rest` directly rather than
        // going through `enter`, so the walk cycle used to keep playing while she
        // stood still — invisible while walking was the resting pose slid sideways.
        var walked = false
        for i in 0..<600 {
            driver.tick(dt: 0.1, now: now.addingTimeInterval(Double(i) * 0.1),
                        cursor: CGPoint(x: -5000, y: -5000), screen: screen)
            if driver.behaviour == .walking { walked = true }
            if walked && driver.behaviour == .resting { break }
        }

        #expect(walked, "she never walked, so the test proved nothing")
        #expect(driver.behaviour == .resting)
        #expect(!driver.frame.name.hasPrefix("walk"),
                "still on \(driver.frame.name) after stopping")
    }

    @Test func walkUsesThreeFramesAndAlwaysRestarts() throws {
        let sim = Simulation(state: .fresh(now: now))
        let driver = try makeDriver(sim)
        driver.moveTo(CGPoint(x: 400, y: screen.minY))
        var seen: Set<String> = []
        for i in 0..<600 {
            driver.tick(dt: 0.05, now: now.addingTimeInterval(Double(i) * 0.05),
                        cursor: CGPoint(x: -5000, y: -5000), screen: screen)
            if driver.behaviour == .walking { seen.insert(driver.frame.name) }
        }
        #expect(seen.contains("walk_0"))
        #expect(!seen.contains("walk_3"), "the closing frame is deliberately unused")
    }

    @Test func corneredAgainstAnEdgeSheFleesPastTheHand() throws {
        // Cornered, "away from the hand" is a move of a few points into the wall: she
        // arrives at once, lands still inside your reach, is startled again, and beats
        // her wings against the edge. The fix is that she goes PAST you instead, so
        // that — her ending up on the far side of the hand — is what this asserts.
        //
        // It used to count ticks, which was the wrong measure twice over: it described
        // the symptom rather than the fix, and once she began sometimes escaping on
        // foot, which is slower than flying, the threshold started failing on the runs
        // where she ran.
        for trial in 0..<12 {
            let sim = Simulation(state: .fresh(now: now))
            let driver = try makeDriver(sim)
            let wall = screen.maxX - Double(Canvas.width)
            driver.moveTo(CGPoint(x: wall, y: screen.minY))
            driver.stay(for: 30)
            let hand = CGPoint(x: driver.bodyCentre.x - 80, y: driver.bodyCentre.y)

            var escaped = false
            for i in 0..<400 {
                driver.tick(dt: 0.1, now: now.addingTimeInterval(Double(i) * 0.1),
                            cursor: hand, screen: screen)
                if hypot(driver.bodyCentre.x - hand.x, driver.bodyCentre.y - hand.y)
                    > BehaviourDriver.personalSpace {
                    escaped = true
                    break
                }
            }
            #expect(escaped, "prova \(trial): non si e' mai liberata dalla mano")
            #expect(driver.bodyCentre.x < hand.x,
                    "prova \(trial): e' rimasta dal lato del muro invece di passare oltre la mano")
        }
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
        // She leaves — on the wing or on foot, which she now chooses between. The point
        // is that a fresh approach startles her again, not how she answers it.
        #expect(driver.behaviour == .flying || driver.behaviour == .walking)
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
            // The scale the app actually ships, not a convenient one: the run-up, the
            // scoring band and the ring's size all derive from it.
            driver.interactionTarget = game.target(bird: driver.bodyCentre, hoop: hoop,
                                                   opening: AppDelegate.hoopOpening,
                                                   reach: driver.reachableCentreX(in: screen))
            driver.tick(dt: 0.1, now: now.addingTimeInterval(Double(tick) / 10),
                        cursor: hoop, screen: screen)
            if game.passes == 3 { break }
        }
        #expect(game.passes == 3)
    }
}
