# 09 — Behaviour driver and animation player

Type: task
Status: resolved
Blocked by: 05, 06
Parent: [map](../map.md)

## Question

Make Coco move and act alive.

- **Animation player**: named clips over the sprites in `Assets/Sprites/`, with per-clip frame rate and looping, plus the code-driven motion that replaces drawn frames — the 1px breathing bob, the walk bob, the eating dip.
- **Behaviour state machine** from [04](04-domain-model.md): the states, the legal transitions, and which states interrupt which.
- **Autonomous movement**: wandering, preferring screen edges, **avoiding the cursor**, taking off and landing. Flight reuses `fly_0`–`fly_3`; take-off needs no transition because the frames are eye-aligned with the perched sprite.
- Facing is **mirrored in code**; the front-facing sprite has no direction and is used for sleeping.
- Position must be accumulated **fractionally** and rounded only at display, or slow movement stalls entirely (`NSWindow` snaps frame origins to whole points).
- Throttle the tick when she is asleep or hidden; a stationary loop should use `CAKeyframeAnimation` in `.discrete` mode, which costs zero app CPU.

## Answer

Coco moves on her own. Verified by sampling the window: she crossed the screen from x=1320 to x=200 in twelve seconds, changing altitude on the way, and all seven acceptance checks passed by eye.

| File | Holds |
|---|---|
| `Sources/Coco/Animation.swift` | `Clip` and `Animator` |
| `Sources/Coco/BehaviourDriver.swift` | states, transitions, movement, the decision timer |
| `Sources/Coco/AppDelegate.swift` | rewritten to apply what the driver reports |

**The player does one job.** Most movement is not in the frames: breathing, the walking bob and the eating dip are offsets computed per tick. A clip exists only where the *drawing* actually differs — flight, sleep, reactions. This is what kept the art budget to two generated poses.

**Position accumulates fractionally and is rounded only at display.** Stored as integers, a 34 pt/s walk at 10 fps gives 3.4 points a tick and the remainder is lost every time; since `NSWindow` snaps origins to whole points, slow movement would stall completely.

**She flees rather than freezes.** Inside 110 points of the cursor she takes off away from it. A pet that stops dead reads as broken; one that flees reads as alive. Fly targets are biased to the outer thirds of the screen, because a bird that crosses the text you are typing is an app uninstalled on day two.

**The timer changes rate rather than checking a flag** — 10 Hz awake, 1 Hz asleep. A sleeping bird should not wake the CPU ten times a second to decide it has nothing to do. Sprites are only reassigned when the drawing changes, so an unchanging pose causes no redraw; `Sprite` gained a `name` purely to make that comparison cheap.

**Bug found before shipping it.** The dragged state was only left when petting *succeeded*. A refused pet — which happens after twenty pets in an hour — froze Coco in mid-air permanently. Every path out of a drag now leaves the state; the fix is a single `if/else` rather than an early return, because the early return was the shape that hid the hole.
