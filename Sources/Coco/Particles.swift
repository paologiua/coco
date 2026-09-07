import AppKit

/// Little marks that rise beside Coco and say what just happened, without words.
///
/// Drawn from pixel matrices in code rather than shipped as sprites: at five pixels a
/// side an image file buys nothing, and a mark that has to fade needs its colour chosen
/// at draw time anyway.
@MainActor
final class ParticleField {
    enum Kind { case zzz, heart, note, seed, confetti }

    struct Particle {
        var position: CGPoint       // stage pixels, origin top-left
        var velocity: CGVector      // stage pixels per second
        var age: Double
        let lifetime: Double
        let kind: Kind
        let tint: NSColor

        var fade: Double { max(0, 1 - age / lifetime) }
    }

    private(set) var particles: [Particle] = []
    private var zzzClock = 0.0
    private var queue: [(kind: Kind, origin: CGPoint)] = []
    private var queueClock = 0.0
    private static let queueInterval = 0.26

    var isEmpty: Bool { particles.isEmpty && queue.isEmpty }

    // MARK: - Emitting

    func emit(_ kind: Kind, at point: CGPoint, drift: Double = 0) {
        let colour: NSColor
        switch kind {
        case .zzz:      colour = NSColor(srgbRed: 0.91, green: 0.93, blue: 0.98, alpha: 1)
        case .heart:    colour = NSColor(srgbRed: 0.357, green: 0.384, blue: 0.722, alpha: 1)
        case .note:     colour = NSColor(srgbRed: 0.910, green: 0.812, blue: 0.247, alpha: 1)
        case .seed:     colour = NSColor(srgbRed: 0.851, green: 0.769, blue: 0.549, alpha: 1)
        case .confetti: colour = Self.confettiColours.randomElement()!
        }
        // Confetti falls; everything else rises. The stage's origin is top-left, so
        // rising means a negative dy.
        let dy = kind == .confetti ? Double.random(in: 6...16) : -Double.random(in: 7...11)
        // Scattered rather than identical: marks emitted from one point with one
        // velocity stack into a single thick mark and read as a rendering fault.
        let origin = CGPoint(x: point.x + Double.random(in: -7...7),
                             y: point.y + Double.random(in: -3...3))
        particles.append(Particle(position: origin,
                                  velocity: CGVector(dx: drift + Double.random(in: -5...5), dy: dy),
                                  age: 0,
                                  lifetime: (kind == .confetti ? 1.6 : 2.2) * Double.random(in: 0.8...1.2),
                                  kind: kind,
                                  tint: colour))
    }

    /// Emit over time rather than all at once. A burst of four hearts in one frame is
    /// one heart four times over; spaced out, it reads as a little flurry.
    func stagger(_ kind: Kind, count: Int, at point: CGPoint) {
        queue.append(contentsOf: Array(repeating: (kind, point), count: count))
        queueClock = Self.queueInterval        // so the first one appears at once
    }

    func burst(_ kind: Kind, count: Int, at point: CGPoint) {
        for _ in 0..<count { emit(kind, at: point) }
    }

    /// Sleeping emits on its own clock, so the caller only has to say "still asleep".
    func breatheZzz(dt: Double, at point: CGPoint) {
        zzzClock += dt
        if zzzClock >= 1.4 {
            zzzClock = 0
            emit(.zzz, at: point, drift: 3)
        }
    }

    func stopZzz() { zzzClock = 0 }

    // MARK: - Advancing

    func advance(dt: Double) {
        if !queue.isEmpty {
            queueClock += dt
            while queueClock >= Self.queueInterval, !queue.isEmpty {
                queueClock -= Self.queueInterval
                let next = queue.removeFirst()
                emit(next.kind, at: next.origin)
            }
        }
        for index in particles.indices {
            particles[index].age += dt
            particles[index].position.x += particles[index].velocity.dx * dt
            particles[index].position.y += particles[index].velocity.dy * dt
        }
        particles.removeAll { $0.age >= $0.lifetime }
    }

    func clear() {
        particles.removeAll()
        queue.removeAll()
    }

    // MARK: - Shapes

    private static let confettiColours = [
        NSColor(srgbRed: 0.910, green: 0.812, blue: 0.247, alpha: 1),
        NSColor(srgbRed: 0.357, green: 0.384, blue: 0.722, alpha: 1),
        NSColor(srgbRed: 0.478, green: 0.749, blue: 0.227, alpha: 1),
        NSColor(srgbRed: 0.929, green: 0.914, blue: 0.816, alpha: 1),
    ]

    /// Pixel matrices, drawn as squares at the panel's scale so they stay as chunky as
    /// Coco herself.
    static func matrix(for kind: Kind) -> [String] {
        switch kind {
        case .zzz:
            return ["#####",
                    "...#.",
                    "..#..",
                    ".#...",
                    "#####"]
        case .heart:
            return [".#.#.",
                    "#####",
                    "#####",
                    ".###.",
                    "..#.."]
        case .note:
            return ["..###",
                    "..#.#",
                    "..#..",
                    "###..",
                    "###.."]
        case .seed:
            // The same diamond as the hunger icon in the menu: one mark, one meaning.
            return ["..#..",
                    ".###.",
                    "#####",
                    ".###.",
                    "..#.."]
        case .confetti:
            return ["##",
                    "##"]
        }
    }
}
