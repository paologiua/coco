import AppKit

/// What Coco is doing right now. Exactly one at a time.
enum Behaviour {
    case resting
    case walking
    case flying
    case sleeping
    case dragged
    /// A short pose that plays out and hands control back: petted, eating, playing.
    case reacting
}

/// Chooses what Coco does and where she goes, and hands the view a sprite and a
/// position each tick. Owns no windows — the caller applies what it is given.
@MainActor
final class BehaviourDriver {
    // Points per second.
    private static let walkSpeed = 34.0
    private static let flySpeed = 150.0
    /// How close the cursor may come before she startles, and — the same distance,
    /// deliberately — how near the offered food may be before she stops chasing it and
    /// waits. A click outside it does not feed her, so holding further out than this
    /// would leave a band where she looks reachable and silently is not.
    static let personalSpace = 110.0
    /// A bird that crosses the text you are typing gets the app closed on day two, so
    /// she keeps to the outer thirds of the screen unless dropped elsewhere.
    private static let edgeBias = 0.72

    private let sim: Simulation
    private let animator: Animator
    private let sprites: SpriteSet
    private let canvasSize: CGSize
    /// Points per stage pixel — needed to find her body's centre, which is not the
    /// window's centre: the window is taller than she is, to leave room for particles.
    private let scale: Double

    private(set) var behaviour: Behaviour = .resting
    /// Accumulated fractionally and rounded only at display: NSWindow snaps origins to
    /// whole points, so a slow walk stored as Int would never move at all.
    private(set) var position: CGPoint
    private(set) var facingRight = true

    /// What she should do with `interactionTarget`. Food is somewhere to go and then
    /// wait beside; the hoop is a moving target she chases for as long as it is up.
    enum InteractionStyle { case waitBeside, chase }

    private var target: CGPoint?
    var interactionStyle: InteractionStyle = .waitBeside
    var interactionTarget: CGPoint? {
        didSet { if interactionTarget == nil { hasArrivedBeside = false } }
    }
    /// Set once she has stopped beside the food, and the reason she then stays put.
    private var hasArrivedBeside = false
    private var sleepLanding: CGPoint?
    private var sleepingPerch: Perch?
    var availablePerches: [Perch] = []
    private var startledUntil = Date.distantPast
    private var cursorIsWelcome = false
    private var restUntil: Date = .distantPast
    private var bobPhase = 0.0
    private var facingBeforeReaction: Bool?
    /// Set while the eating clip runs. The peck is a drawn head-down frame AND a dip of
    /// the whole bird; the dip is the half that reads from across a room, and it is the
    /// "eating dip" the animation player has claimed to have since ticket 09.
    private var isPecking = false
    /// The mood the resting clip was built for. Mood changes while she is already
    /// resting have to be picked up, or she keeps the face she had when she sat down.
    private var restingMood: Mood?

    struct SpriteSet {
        let idle, blink, sad, petted, pettedDeep: Sprite
        let fly: [Sprite]
        /// Head down at the ground. Optional because the peck is half drawing and half
        /// motion: without it the dip below still reads as eating, so a missing frame
        /// costs polish rather than the animation.
        let peck: Sprite?
        /// The same poses with the party hat drawn in, keyed by the plain sprite's
        /// name. Baked rather than laid over the frame at runtime: one `hat_side`
        /// layer fitted the perched poses and floated a pixel or two clear of the
        /// skull in every flight frame, and keeping a hand-written anchor per frame
        /// is what made the hat not worth having. `scripts/make-hatted-sprites.py`
        /// measures the anchor per frame instead, so a new animation costs nothing.
        let hatted: [String: Sprite]
    }

    init(sim: Simulation, sprites: SpriteSet, canvasSize: CGSize, scale: Int, start: CGPoint) {
        self.sim = sim
        self.sprites = sprites
        self.canvasSize = canvasSize
        self.scale = Double(scale)
        self.position = start
        // Built from the mood she loads with, not from a hardcoded happy idle: at
        // launch she never passes through a transition, so nothing else would set it.
        let face = sim.mood == .sad ? sprites.sad : sprites.idle
        self.animator = Animator(clip: .breathing(face, blink: sprites.blink))
        self.restingMood = sim.mood
    }

    // MARK: - Output

    var frame: Sprite {
        let base = animator.frame
        // Asleep she wears nothing: a party hat on a sleeping bird reads as forgotten,
        // not festive. A pose with no hatted twin simply goes bare-headed, which is
        // what lets a new animation ship before its hat has been baked.
        guard sim.isBirthday(on: Date()), behaviour != .sleeping,
              let hatted = sprites.hatted[base.name] else { return base }
        return hatted
    }

    var bodyCentre: CGPoint {
        CGPoint(x: position.x + canvasSize.width / 2,
                y: position.y + Double(Canvas.height) * scale / 2)
    }

    /// Where to actually put the window: the accumulated position plus the vertical bob
    /// that stands in for drawn walk and breathing frames.
    var displayPosition: CGPoint {
        CGPoint(x: position.x.rounded(), y: (position.y + bobOffset).rounded())
    }

    private var bobOffset: Double {
        switch behaviour {
        case .walking:  return sin(bobPhase * 8) > 0 ? 3 : 0     // one canvas pixel at 3x
        case .resting:
            // On her birthday the breath becomes a bounce.
            return sim.isBirthday(on: Date())
                ? (sin(bobPhase * 6) > 0 ? 3 : 0)
                : (sin(bobPhase * 1.6) > 0.7 ? 3 : 0)
        case .sleeping: return 0
        // Negative is downwards: she stoops to the ground and comes back up. Twice the
        // walk's amplitude, because a peck that moves as little as a footfall reads as
        // a stumble rather than a bird taking food.
        case .reacting: return isPecking && sin(bobPhase * 14) > 0 ? -6 : 0
        default:        return 0
        }
    }

    // MARK: - Tick

    func tick(dt: Double, now: Date, cursor: CGPoint, screen: NSRect) {
        bobPhase += dt
        animator.advance(by: dt)

        if behaviour == .dragged { return }

        if now < startledUntil {
            advanceTowardsTarget(dt: dt, speed: Self.flySpeed)
            return
        }
        if let perch = sleepingPerch,
           !availablePerches.contains(perch) {
            sleepingPerch = nil
            sleepLanding = nil
            startledUntil = now.addingTimeInterval(1.2)
            flyTo(CGPoint(x: min(max(position.x + 100, screen.minX),
                                max(screen.minX, screen.maxX - canvasSize.width)),
                          y: min(position.y + 100, max(screen.minY, screen.maxY - canvasSize.height))))
            return
        }

        // Travel to a perch before showing the sleeping pose.
        if sim.sleep != .awake {
            if sleepLanding == nil {
                sleepLanding = CGPoint(x: min(max(position.x, screen.minX),
                                             max(screen.minX, screen.maxX - canvasSize.width)),
                                       y: screen.minY)
                let centre = position.x + canvasSize.width / 2
                // The frontmost eligible window beneath her wins. If geometry is
                // unavailable or there is no room above it, use the screen floor.
                if let perch = availablePerches.first(where: {
                    $0.frame.minX <= centre && centre <= $0.frame.maxX &&
                    $0.frame.maxY <= position.y + 5 && $0.frame.maxY >= screen.minY &&
                    $0.frame.maxY + canvasSize.height <= screen.maxY
                }) {
                    sleepingPerch = perch
                    sleepLanding?.y = perch.frame.maxY
                }
            }
            if let landing = sleepLanding {
                let distance = hypot(position.x - landing.x, position.y - landing.y)
                if distance > 1 {
                    target = landing
                    if behaviour != .flying { enter(.flying) }
                    advanceTowardsTarget(dt: dt, speed: Self.flySpeed)
                } else if behaviour != .sleeping {
                    position = landing
                    target = nil
                    enter(.sleeping)
                }
            }
            return
        }
        sleepLanding = nil
        sleepingPerch = nil
        if behaviour == .sleeping { enter(.resting) }

        if let point = interactionTarget {
            let desired = CGPoint(x: min(max(point.x - canvasSize.width / 2, screen.minX),
                                        max(screen.minX, screen.maxX - canvasSize.width)),
                                  y: min(max(point.y - Double(Canvas.height) * scale / 2, screen.minY),
                                         max(screen.minY, screen.maxY - canvasSize.height)))
            // Once she has stopped beside the food she waits, and bringing the hand
            // closer must not move her: a standoff kept against an approaching cursor
            // retreats exactly as fast as you advance, so she can never be fed and
            // reads as fleeing the food she just flew over to get. She goes after it
            // again only if it is carried out of reach.
            if hasArrivedBeside {
                if hypot(bodyCentre.x - cursor.x, bodyCentre.y - cursor.y) <= Self.personalSpace {
                    return
                }
                hasArrivedBeside = false
            }
            if hypot(position.x - desired.x, position.y - desired.y) > 3 {
                target = desired
                if behaviour != .flying { enter(.flying) }
                advanceTowardsTarget(dt: dt, speed: Self.flySpeed)
            } else {
                if interactionStyle == .waitBeside { hasArrivedBeside = true }
                stay(for: 1)
            }
            return
        }

        if behaviour == .reacting {
            if animator.isFinished {
                if let restore = facingBeforeReaction { facingRight = restore }
                facingBeforeReaction = nil
                isPecking = false
                enter(.resting)
            }
            return
        }

        // A hand that has not moved since it fed her has not become a threat.
        if cursorIsWelcome,
           hypot(bodyCentre.x - cursor.x, bodyCentre.y - cursor.y) > Self.personalSpace {
            cursorIsWelcome = false
        }
        if !cursorIsWelcome, startled(by: cursor, in: screen) { return }

        switch behaviour {
        case .walking, .flying:
            let base = behaviour == .flying ? Self.flySpeed : Self.walkSpeed
            advanceTowardsTarget(dt: dt, speed: sim.mood == .sad ? base * 0.65 : base)
        case .resting:
            if restingMood != sim.mood { enter(.resting) }
            if now >= restUntil { decide(in: screen) }
        default:
            break
        }
    }

    /// She takes off away from the cursor rather than merely stopping — a pet that
    /// freezes reads as broken, one that flees reads as alive.
    private func startled(by cursor: CGPoint, in screen: NSRect) -> Bool {
        guard behaviour == .resting || behaviour == .walking else { return false }
        let centre = bodyCentre
        guard hypot(centre.x - cursor.x, centre.y - cursor.y) < Self.personalSpace else { return false }
        let away = cursor.x > centre.x ? screen.minX + 20 : screen.maxX - canvasSize.width - 20
        flyTo(CGPoint(x: away, y: screen.minY + Double.random(in: 0...120)))
        return true
    }

    private func decide(in screen: NSRect) {
        let roll = Double.random(in: 0...1)
        // Sad, she mostly stays put rather than flying about.
        if sim.mood == .sad, roll < 0.55 {
            rest(for: Double.random(in: 6...14))
            return
        }
        if roll < 0.55 {
            walkTo(x: nearbyX(in: screen))
        } else if roll < 0.8 {
            flyTo(CGPoint(x: edgeBiasedX(in: screen),
                          y: screen.minY + Double.random(in: 0...200)))
        } else {
            rest(for: Double.random(in: 2...6))
        }
    }

    private func nearbyX(in screen: NSRect) -> Double {
        let drift = Double.random(in: -220...220)
        return min(max(position.x + drift, screen.minX), screen.maxX - canvasSize.width)
    }

    private func edgeBiasedX(in screen: NSRect) -> Double {
        let usable = screen.width - canvasSize.width
        let t = Double.random(in: 0...1) < Self.edgeBias
            ? (Bool.random() ? Double.random(in: 0...0.28) : Double.random(in: 0.72...1))
            : Double.random(in: 0.28...0.72)
        return screen.minX + usable * t
    }

    private func advanceTowardsTarget(dt: Double, speed: Double) {
        guard let target else { enter(.resting); return }
        let dx = target.x - position.x, dy = target.y - position.y
        let distance = hypot(dx, dy)
        if distance < speed * dt {
            position = target
            self.target = nil
            rest(for: Double.random(in: 2...7))
            return
        }
        facingRight = dx >= 0
        position.x += dx / distance * speed * dt
        position.y += dy / distance * speed * dt
    }

    // MARK: - Transitions

    private func enter(_ next: Behaviour) {
        // Any transition out of the reaction ends the peck. Leaving it set would carry
        // the dip into walking or flight, where it reads as a limp.
        if next != .reacting { isPecking = false }
        behaviour = next
        switch next {
        case .resting:
            let calm = sim.mood == .sad ? sprites.sad : sprites.idle
            animator.play(.breathing(calm, blink: sprites.blink))
            restingMood = sim.mood
            // Sad Coco sits still for longer. The drooping eye is four pixels; the
            // change in how much she moves is what actually reads across a room.
            rest(for: sim.mood == .sad ? Double.random(in: 6...14) : Double.random(in: 2...6))
        case .walking:
            animator.play(.still(sim.mood == .sad ? sprites.sad : sprites.idle))
        case .flying, .dragged:
            animator.play(Clip(frames: sprites.fly, fps: 12, loops: true))
        case .sleeping:
            animator.play(.still(sprites.blink))       // side-on, eyes closed, feet on the perch
        case .reacting:
            break
        }
    }

    private func rest(for seconds: Double) {
        behaviour = .resting
        restUntil = Date().addingTimeInterval(seconds)
    }

    private func walkTo(x: Double) {
        target = CGPoint(x: x, y: position.y)
        enter(.walking)
    }

    private func flyTo(_ point: CGPoint) {
        target = point
        enter(.flying)
    }

    // MARK: - Driven from outside

    func beginDrag() {
        if sim.sleep != .awake { sim.wakeByDragging() }
        target = nil
        sleepLanding = nil
        sleepingPerch = nil
        startledUntil = .distantPast
        interactionTarget = nil
        enter(.dragged)
    }

    func moveTo(_ point: CGPoint) { position = point }

    func endDrag(screen: NSRect) {
        // Dropped in mid-air, she flies down rather than hanging there.
        if position.y > screen.minY + 40 {
            flyTo(CGPoint(x: position.x, y: screen.minY + Double.random(in: 0...30)))
        } else {
            enter(.resting)
        }
    }

    /// A short clip that plays once and hands control back.
    func react(with clip: Clip) {
        behaviour = .reacting
        animator.play(clip)
    }

    /// A single pose held for a moment. Still the right shape for the reactions that
    /// are a held expression rather than a movement — refusing, and looking up at the
    /// human — so those do not have to pretend to be animations.
    func react(with sprite: Sprite, seconds: Double = 1.2) {
        react(with: Clip(frames: [sprite], fps: 1 / seconds, loops: false))
    }

    /// Eating: three pecks at the ground.
    ///
    /// Head-down and head-up alternating rather than a drawn arc between them. A bird's
    /// peck snaps — it does not sweep — so the two states are the whole movement, and
    /// two states are also all the generator can be trusted to register (ticket 01).
    func eat() {
        isPecking = true
        let down = sprites.peck ?? sprites.idle
        react(with: Clip(frames: [sprites.idle, down, down,
                                  sprites.idle, down, down,
                                  sprites.idle, down, down, sprites.idle],
                         fps: 7, loops: false))
    }

    /// Being petted: eyes closing and scrunching, twice, then opening.
    ///
    /// The eye is four pixels, so the animation is built from the states that read
    /// differently at this size rather than from an even interpolation between open
    /// and shut — a drawn half-way frame is indistinguishable from `blink`. Two
    /// scrunches rather than one: a single squeeze reads as a long blink.
    func acceptPetting() {
        react(with: Clip(frames: [sprites.blink, sprites.petted,
                                  sprites.pettedDeep, sprites.pettedDeep, sprites.petted,
                                  sprites.pettedDeep, sprites.pettedDeep, sprites.petted,
                                  sprites.blink],
                         fps: 7, loops: false))
    }

    /// Refusing is something Coco DOES: she turns her back for a moment. Greying out a
    /// menu item would say the same thing and say nothing about her.
    func refuse() {
        facingBeforeReaction = facingRight
        facingRight.toggle()
        react(with: sim.mood == .sad ? sprites.sad : sprites.idle, seconds: 1.1)
    }

    /// Stand still. Used while she is saying something: a bird that starts a sentence
    /// and then wanders out from under its own speech bubble looks broken.
    func stay(for seconds: Double) {
        target = nil
        enter(.resting)
        rest(for: seconds)
    }

    /// Arrive from off screen. Used once, on the very first launch.
    func flyIn(from origin: CGPoint, to destination: CGPoint) {
        position = origin
        flyTo(destination)
    }

    /// True once she has arrived and settled — the welcome message waits for this so it
    /// does not appear beside an empty patch of screen while she is still on her way.
    var hasLanded: Bool { behaviour == .resting && target == nil }

    /// Pleased with herself — after a game she has just finished.
    ///
    /// This used to be a front-facing pose, turning to look at the human. The front
    /// view is gone: it was the one drawing that could not be mirrored, it cost a
    /// second silhouette to keep in step with every change to her design, and it read
    /// as a different bird rather than the same bird turning round.
    func celebrate() {
        react(with: Clip(frames: [sprites.petted, sprites.pettedDeep, sprites.petted,
                                  sprites.pettedDeep, sprites.blink, sprites.idle],
                         fps: 6, loops: false))
    }

    /// The hand that has just fed her is welcome. Without this the ordinary
    /// cursor-avoidance rule fires the moment the eating pose ends, so the reward for
    /// feeding her is watching her leave.
    ///
    /// It lasts until the hand withdraws past her personal space rather than for a
    /// fixed few seconds: the hand is still right there when the pose ends, so any
    /// timer just postpones the same startle. Coming back afterwards is a fresh
    /// approach and she startles at it like any other.
    func welcomeCursor() { cursorIsWelcome = true }
}
