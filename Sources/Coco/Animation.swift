import Foundation

/// A sequence of sprites played at a fixed rate.
///
/// Most of Coco's movement is not in here: breathing, walking bob and the eating dip
/// are motion applied by the driver, because the generator could not hold registration
/// between frames and hand-drawing them would have cost days. A clip is only used where
/// the drawing genuinely differs.
struct Clip {
    let frames: [Sprite]
    let fps: Double
    let loops: Bool

    var duration: Double { Double(frames.count) / fps }

    static func still(_ sprite: Sprite) -> Clip {
        Clip(frames: [sprite], fps: 1, loops: true)
    }

    /// A long hold on one sprite with a short blink at the end. Built as frames rather
    /// than special-cased in the player: an array of repeats costs nothing and keeps
    /// the player with exactly one job.
    static func breathing(_ open: Sprite, blink: [Sprite], seconds: Double = 4,
                          fps: Double = 10) -> Clip {
        let total = max(blink.count + 1, Int(seconds * fps))
        return Clip(frames: Array(repeating: open, count: total - blink.count) + blink,
                    fps: fps, loops: true)
    }
}

/// Plays one clip at a time.
final class Animator {
    private(set) var clip: Clip
    private var elapsed = 0.0

    init(clip: Clip) { self.clip = clip }

    /// Restarts even if the same clip is handed back, so a reaction can be re-triggered.
    func play(_ clip: Clip) {
        self.clip = clip
        elapsed = 0
    }

    func advance(by dt: Double) { elapsed += dt }

    /// True once a non-looping clip has run out.
    var isFinished: Bool { !clip.loops && elapsed >= clip.duration }

    var frame: Sprite {
        let index = Int(elapsed * clip.fps)
        return clip.loops
            ? clip.frames[index % clip.frames.count]
            : clip.frames[min(index, clip.frames.count - 1)]
    }
}
