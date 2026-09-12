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
    /// Startled and on foot. Fast enough to read as alarm, slow enough to follow.
    private static let runSpeed = 105.0
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
    let sprites: SpriteSet
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
    /// Set while she is escaping on foot: a scurry, not a stroll.
    private var running = false
    /// The mood the resting clip was built for. Mood changes while she is already
    /// resting have to be picked up, or she keeps the face she had when she sat down.
    private var restingMood: Mood?

    struct SpriteSet {
        let idle, sad: Sprite
        /// Open, closing, shut, opening. Drawn now rather than derived by editing the
        /// eye, so the whole blink is real animation.
        let blink: [Sprite]
        let petted: [Sprite]
        /// A drawn step cycle. Walking used to be the resting pose slid sideways with
        /// a one-pixel bob standing in for legs.
        let walk: [Sprite]
        /// Flight is anchored on the HEAD, so her body sits a little differently in the
        /// air than at rest — about eight points, against a hoop two hundred tall.
        /// Tracking that was tried and is not worth it: a body centre that changes when
        /// she lands moves the target out from under her at the moment she arrives, so
        /// she takes off again, and the hoop game spends its time landing and
        /// relaunching instead of flying through anything.
        let fly: [Sprite]
        /// Eight frames: head down, beak to the ground, the seed taken, and back up.
        let peck: [Sprite]
        /// Held in the hand: eight frames of twisting to get out of it. Drawn rather
        /// than borrowed from flight, which is what being dragged used to show — a
        /// bird flying along under the cursor reads as going somewhere, not as being
        /// carried. Anchored on the head like flight, so she is the same size in the
        /// hand as out of it.
        let struggle: [Sprite]
        /// The same poses with the party hat drawn in, keyed by the plain sprite's
        /// name. The hat is part of the art now, so nothing is positioned at runtime.
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
        // She keeps the hat on while she sleeps. It used to come off — a party hat on a
        // sleeping bird can read as forgotten rather than festive — but on the one day
        // it exists, taking it off means that dozing off ends the birthday early.
        //
        // A pose with no hatted twin simply goes bare-headed, which is what lets a new
        // animation ship before its hat has been drawn.
        guard sim.isBirthday(on: Date()),
              let hatted = sprites.hatted[base.name] else { return base }
        return hatted
    }

    /// Where she actually is on screen.
    ///
    /// Taken from the RESTING pose, not the frame being drawn. Reading the current
    /// frame sounds more correct and is much worse: in flight it moves with every
    /// wingbeat, and the food and the hoop are aimed at this point, so the target
    /// jittered under her, she never arrived inside the tolerance, and she hung in the
    /// air flapping until the interaction timed out.
    ///
    /// The canvas keeps a margin below her feet for wingtips, so the floor of the
    /// drawing is not the level she stands on; forgetting that aimed everything 26
    /// points low and she flew under the hoop.
    var bodyCentre: CGPoint {
        let centre = sprites.idle.drawnCentre
        let x = facingRight ? centre.x : Double(Canvas.width) - centre.x
        return CGPoint(x: position.x + x * scale,
                       y: position.y - Double(Canvas.floorMargin)
                          + (Double(Canvas.height) - centre.y) * scale)
    }

    /// How far below `bodyCentre` to aim so that her FLYING silhouette is centred.
    ///
    /// She only ever enters the hoop in flight, so the flying shape is the one to
    /// centre, and this is the whole of it: the union of the four frames' drawn
    /// bounds, which is the band of canvas her wingbeat sweeps.
    ///
    /// Averaging the four frames' own centres was the first attempt and is subtly
    /// wrong. Those centres range over 36 points — but that is her WINGS opening and
    /// closing, not her body moving: measured by the cheek, her head holds still to
    /// within half a point across the whole beat. Centring a mean of bounding boxes
    /// therefore aims at the wings. The union's centre lands within two points of that
    /// motionless head, which is the reassurance that it is aiming at the bird.
    var flightAimOffset: Double {
        guard let first = sprites.fly.first else { return 0 }
        var lo = first.drawnBounds.minY, hi = first.drawnBounds.maxY
        for frame in sprites.fly.dropFirst() {
            lo = min(lo, frame.drawnBounds.minY)
            hi = max(hi, frame.drawnBounds.maxY)
        }
        return (sprites.idle.drawnCentre.y - (lo + hi) / 2) * scale
    }

    /// Window positions that keep her DRAWING on screen, rather than her window.
    ///
    /// The window is 209 points tall and she occupies 82 of them: there are 41 points
    /// of sky over her head for particles and 26 below her feet for a dipping wingtip.
    /// Clamping the window to the screen therefore walled her body out of the top 168
    /// points of it and off about fifty at each side — so a hoop held high was
    /// somewhere she could not go, and she stopped short of it and hung there.
    func originBounds(in screen: NSRect) -> (x: ClosedRange<Double>, y: ClosedRange<Double>) {
        let box = sprites.idle.drawnBounds
        let stage = Double(Canvas.stageHeight)
        let sky = Double(Canvas.particleHeadroom)
        // Distance from the window's bottom edge up to her head and to her feet.
        let toHead = (stage - sky - box.minY) * scale
        let toFeet = (stage - sky - box.maxY) * scale
        let loX = screen.minX - box.minX * scale
        let hiX = max(loX, screen.maxX - box.maxX * scale)
        let loY = screen.minY - toFeet
        let hiY = max(loY, screen.maxY - toHead)
        return (loX...hiX, loY...hiY)
    }

    /// Beside her head, in stage pixels, for particles to rise from.
    ///
    /// Derived from the drawing rather than written down: it was a pair of constants
    /// measured against a 64-wide canvas, and when the canvas grew to 208 the marks
    /// went on appearing where her head used to be — a third of the way across the
    /// stage from her, hanging in empty space.
    var emissionPoint: CGPoint {
        let box = sprites.idle.drawnBounds
        // Her head, and mirrored the same way the drawing is. It used to be measured in
        // from whichever edge she faced, which is only the same thing when she faces
        // right: facing left it put the marks a dozen points past her head, out in the
        // air beside her.
        let head = box.maxX - box.width * 0.17
        let x = facingRight ? head : Double(Canvas.width) - head
        // Level with the top of her head, so the first mark half overlaps it and the
        // rest climb away. Started clear of her, the lowest one hung in the air with a
        // visible gap under it and the group read as unattached to the bird.
        return CGPoint(x: x, y: Double(Canvas.particleHeadroom) + box.minY + 3)
    }

    /// The band above her head that birthday confetti falls from, in stage pixels.
    ///
    /// Derived, for the same reason `emissionPoint` is: the burst used a pair of
    /// constants measured against the old 64-wide canvas, and on a 208-wide one the
    /// whole shower arrived in a single stack low and to her left, nowhere near the
    /// bird.
    ///
    /// A band rather than a point because confetti is the one mark that cannot be
    /// staggered — it is meant to arrive all at once — so it is spread in space
    /// instead, across her drawn width. It starts clear of her head so the pieces are
    /// seen falling ONTO her rather than out of her.
    var confettiSource: CGRect {
        let box = sprites.idle.drawnBounds
        let clearance = Double(ParticleField.pip) * 4
        let top = Double(Canvas.particleHeadroom) + box.minY - clearance
        return CGRect(x: box.minX, y: top, width: box.width, height: clearance / 2)
    }

    /// The band her body centre can actually be moved into on this screen.
    ///
    /// Not the screen: the window is wider than she is and is clamped to the screen, so
    /// the leftmost her middle can get is the screen edge plus the gap between it and
    /// her. Anything aiming her — the hoop's run-up especially — has to aim inside this
    /// or it is asking for a place she cannot stand.
    func reachableCentreX(in screen: NSRect) -> ClosedRange<Double> {
        let offset = bodyCentre.x - position.x
        let bounds = originBounds(in: screen).x
        return (bounds.lowerBound + offset)...(bounds.upperBound + offset)
    }

    /// Where to actually put the window: the accumulated position plus the vertical bob
    /// that stands in for drawn walk frames.
    var displayPosition: CGPoint {
        // `position` is where her feet are; the window reaches below that, so the frame
        // sits lower than she does.
        CGPoint(x: position.x.rounded(),
                y: (position.y + bobOffset - Double(Canvas.floorMargin)).rounded())
    }

    /// Nothing at rest but the birthday bounce.
    ///
    /// There was a breath here: two points up and down on a slow cycle. It never read
    /// as breathing, because none of it is drawn — a breath moves a chest, and this
    /// moved her feet with it. AppKit snaps a window origin to whole points and she is
    /// drawn at one point per pixel, so the smallest breath the window can carry is a
    /// whole pixel of the whole bird, which reads as a twitch. Smoothing the curve made
    /// it a smaller twitch, not a breath. She holds still between blinks instead, which
    /// is what the blink clip is for. Anything better than that wants drawn frames.
    private var bobOffset: Double {
        guard behaviour == .resting, sim.isBirthday(on: Date()) else { return 0 }
        return sin(bobPhase * 6) > 0 ? 3 : 0
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
            let limit = originBounds(in: screen)
            flyTo(CGPoint(x: min(max(position.x + 100, limit.x.lowerBound), limit.x.upperBound),
                          y: min(position.y + 100, limit.y.upperBound)))
            return
        }

        // Travel to a perch before showing the sleeping pose.
        if sim.sleep != .awake {
            if sleepLanding == nil {
                let limit = originBounds(in: screen).x
                sleepLanding = CGPoint(x: min(max(position.x, limit.lowerBound), limit.upperBound),
                                       y: screen.minY)
                // Her middle, not the window's: the window is twice her width, so its
                // centre drifts off her and picked the perch beside the one under her.
                let centre = bodyCentre.x
                // The frontmost eligible window beneath her wins. If geometry is
                // unavailable or there is no room above it, use the screen floor.
                if let perch = availablePerches.first(where: {
                    $0.frame.minX <= centre && centre <= $0.frame.maxX &&
                    $0.frame.maxY <= position.y + 5 && $0.frame.maxY >= screen.minY &&
                    $0.frame.maxY + sprites.idle.drawnBounds.height * scale <= screen.maxY
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
            // Where to put the WINDOW so that SHE lands on the point — not the middle
            // of the canvas, which she does not occupy and which drifts from her as
            // the wings change span.
            let offset = CGPoint(x: bodyCentre.x - position.x, y: bodyCentre.y - position.y)
            let limit = originBounds(in: screen)
            let desired = CGPoint(
                x: min(max(point.x - offset.x, limit.x.lowerBound), limit.x.upperBound),
                y: min(max(point.y - offset.y, limit.y.lowerBound), limit.y.upperBound))
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
            let base = behaviour == .flying ? Self.flySpeed
                                            : (running ? Self.runSpeed : Self.walkSpeed)
            advanceTowardsTarget(dt: dt, speed: sim.mood == .sad ? base * 0.65 : base)
        case .resting:
            if restingMood != sim.mood { enter(.resting) }
            if now >= restUntil { decide(in: screen) }
        default:
            break
        }
    }

    /// Off she goes, whatever she happened to be doing. Used when she has had enough
    /// petting: the hand is right there on top of her, so stopping would read as
    /// sulking where leaving reads as a bird deciding it has had enough.
    func flee(from point: CGPoint, in screen: NSRect) {
        interactionTarget = nil
        cursorIsWelcome = false
        escape(from: point, in: screen)
    }

    /// She takes off away from the cursor rather than merely stopping — a pet that
    /// freezes reads as broken, one that flees reads as alive.
    private func startled(by cursor: CGPoint, in screen: NSRect) -> Bool {
        guard behaviour == .resting || behaviour == .walking else { return false }
        let centre = bodyCentre
        guard hypot(centre.x - cursor.x, centre.y - cursor.y) < Self.personalSpace else { return false }
        escape(from: cursor, in: screen)
        return true
    }

    private func escape(from cursor: CGPoint, in screen: NSRect) {
        let centre = bodyCentre
        let limit = originBounds(in: screen).x
        let leftEdge = limit.lowerBound + 20
        let rightEdge = max(leftEdge, limit.upperBound - 20)
        var away = cursor.x > centre.x ? leftEdge : rightEdge
        // Away from the hand — unless she is already against that edge. Then "away" is
        // a move of a few points, she lands still inside your reach, startles again,
        // and beats her wings against the wall until a lucky escape height gets her
        // clear: measured at up to 31 ticks of it. Cornered, she goes PAST you, which
        // is what a real bird does.
        if abs(away - position.x) < Self.personalSpace {
            away = cursor.x > centre.x ? rightEdge : leftEdge
        }
        // Not always flight. A budgie startled on the ground as often scurries as it
        // takes off, and a pet that answers every approach the same way stops reading
        // as a decision. On foot she stays on the floor and covers less ground, which
        // also makes her easier to catch up with if that was the point.
        if Double.random(in: 0...1) < 0.4 {
            running = true
            walkTo(x: min(max(away, limit.lowerBound), limit.upperBound))
        } else {
            flyTo(CGPoint(x: away, y: screen.minY + Double.random(in: 0...(screen.height * 0.30))))
        }
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
            // Height as a share of the screen, not a flat 200 points. She crosses up
            // to 1300 points horizontally, so a fixed couple of hundred made every
            // flight read as a shallow skim along the floor rather than flight.
            // 45% was picked by eye against the real thing, not derived.
            flyTo(CGPoint(x: edgeBiasedX(in: screen),
                          y: screen.minY + Double.random(in: 0...(screen.height * 0.45))))
        } else {
            rest(for: Double.random(in: 2...6))
        }
    }

    private func nearbyX(in screen: NSRect) -> Double {
        let drift = Double.random(in: -220...220)
        let limit = originBounds(in: screen).x
        return min(max(position.x + drift, limit.lowerBound), limit.upperBound)
    }

    private func edgeBiasedX(in screen: NSRect) -> Double {
        // Against her drawing, not her window: measured on the window she stopped fifty
        // points short of each edge, so a bird whose whole point is that she keeps to
        // the edges never reached one.
        let limit = originBounds(in: screen).x
        let t = Double.random(in: 0...1) < Self.edgeBias
            ? (Bool.random() ? Double.random(in: 0...0.28) : Double.random(in: 0.72...1))
            : Double.random(in: 0.28...0.72)
        return limit.lowerBound + (limit.upperBound - limit.lowerBound) * t
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
        if next != .walking { running = false }
        behaviour = next
        switch next {
        case .resting:
            playRestingClip()
            // Sad Coco sits still for longer. The drooping eye is four pixels; the
            // change in how much she moves is what actually reads across a room.
            rest(for: sim.mood == .sad ? Double.random(in: 6...14) : Double.random(in: 2...6))
        case .walking:
            // The drawn cycle carries the walk now, so the bob that used to stand in
            // for legs is gone: run together they made her hop rather than step. The
            // sad face is lost while she is moving, which is where the drooping eye
            // read least anyway — her mood shows in how much she moves, and in the
            // pose she settles back into.
            // Three of the four drawn frames, always restarting from the first: the
            // fourth closes the cycle back towards the pose it started from, so
            // playing it made the step read as a rock back and forth rather than as
            // going somewhere.
            animator.play(Clip(frames: Array(sprites.walk.prefix(3)), fps: 8, loops: true))
        case .flying:
            animator.play(Clip(frames: sprites.fly, fps: 12, loops: true))
        case .dragged:
            // Faster than the wingbeat: this is not flight, it is a bird objecting to
            // being picked up. It loops for as long as the hand holds her.
            animator.play(Clip(frames: sprites.struggle, fps: 14, loops: true))
        case .sleeping:
            animator.play(.still(sprites.blink[2]))    // side-on, eyes shut, feet on the perch
        case .reacting:
            break
        }
    }

    private func playRestingClip() {
        let calm = sim.mood == .sad ? sprites.sad : sprites.idle
        animator.play(.breathing(calm, blink: sprites.blink))
        restingMood = sim.mood
    }

    /// Stop, and stand there.
    ///
    /// The clip has to be swapped here and not only in `enter`, because arriving
    /// somewhere calls this directly. While walking was the resting pose slid sideways
    /// that made no visible difference; against a drawn step cycle it left her working
    /// her legs on the spot after she had stopped.
    private func rest(for seconds: Double) {
        // Stopping ends the scurry. Without this the flag outlived the escape and every
        // ordinary stroll afterwards was taken at a run.
        running = false
        if behaviour != .resting { playRestingClip() }
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
        // Deliberately does NOT wake her. This runs on mouse DOWN, before anyone knows
        // whether the gesture is a drag or a click, and waking here meant a single
        // click on a sleeping bird woke her, landed as petting, and threw hearts — so
        // she could not be left asleep. `dragged(to:)` wakes her, once there is
        // actually a drag.
        target = nil
        sleepLanding = nil
        sleepingPerch = nil
        startledUntil = .distantPast
        interactionTarget = nil
        enter(.dragged)
    }

    /// Moved by the hand. This is the first moment the gesture is known to be a drag
    /// rather than a click, which is where waking her belongs: she can be dragged awake
    /// — drowsily — but being poked once should leave her asleep.
    func dragged(to point: CGPoint) {
        if sim.sleep != .awake { sim.wakeByDragging() }
        position = point
    }

    func moveTo(_ point: CGPoint) { position = point }

    /// Let go, she leaves — she is a bird, not something you put down.
    ///
    /// She used to make straight for the floor directly under the hand, which with the
    /// wings still beating read as falling rather than flying. Now she breaks for the
    /// far side of the screen and climbs a little on the way, which is what a bird that
    /// has just wriggled out of a hand does.
    func endDrag(screen: NSRect) {
        let limit = originBounds(in: screen)
        let leftEdge = limit.x.lowerBound + 20
        let rightEdge = max(leftEdge, limit.x.upperBound - 20)
        // Towards whichever edge is further off: a getaway of thirty points does not
        // read as one, and she is as often dropped near an edge as in the middle.
        let away = abs(position.x - leftEdge) > abs(position.x - rightEdge) ? leftEdge : rightEdge
        // Up a little as she goes, so the first thing the drop shows is a climb.
        // Clamped, or a bird let go near the top of the screen flies into the ceiling
        // and the climb is invisible.
        let climb = min(max(position.y + Double.random(in: 40...120), limit.y.lowerBound),
                        limit.y.upperBound)
        flyTo(CGPoint(x: away, y: climb))
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
    /// Eating: the drawn peck cycle, head down to the ground and back up with the seed.
    ///
    /// The whole movement is in the frames. An earlier version pecked by dipping the
    /// window while holding one pose, which was the best that could be done before the
    /// art existed; running both would now stoop her twice for every peck.
    func eat() {
        react(with: Clip(frames: sprites.peck, fps: 7, loops: false))
    }

    /// Being petted: eyes closing and scrunching, twice, then opening.
    ///
    /// The eye is four pixels, so the animation is built from the states that read
    /// differently at this size rather than from an even interpolation between open
    /// and shut — a drawn half-way frame is indistinguishable from `blink`. Two
    /// scrunches rather than one: a single squeeze reads as a long blink.
    func acceptPetting() {
        react(with: Clip(frames: sprites.petted + sprites.petted.reversed(),
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

    /// Put down whatever she was doing and come back to the floor.
    ///
    /// Every interaction ends here, including the ones that end badly. A hoop held
    /// where she has no room for the run-up asks her to reach a place she cannot stand,
    /// and she will chase it for the full twenty seconds; without this she was then
    /// left hanging wherever the timeout caught her, flapping in mid-air.
    func settle(screen: NSRect) {
        interactionTarget = nil
        if position.y > screen.minY + 40 {
            flyTo(CGPoint(x: position.x, y: screen.minY + Double.random(in: 0...30)))
        } else {
            stay(for: 1)
        }
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
        react(with: Clip(frames: sprites.petted + [sprites.idle], fps: 6, loops: false))
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
