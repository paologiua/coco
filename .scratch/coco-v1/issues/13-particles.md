# 13 — Animated particles

Type: task
Status: resolved
Blocked by: 09
Parent: [map](../map.md)

## Question

Small animated marks that appear beside Coco and say what just happened, without words.

- **Zzz** rising while she sleeps.
- **Hearts** rising when she is fed, and when she is petted.
- Something at the **end of a play session** — a musical note, or a star.
- **Confetti** on the birthday when she is clicked (belongs to [11](11-birthday-and-welcome.md) but shares this machinery).

These live in the canvas headroom and above it, so the canvas or the particle layer may need to grow again — the same discovery that took the canvas from 48x48 to 64x64.

Drawn in code rather than as sprites where the shape is simple enough (a heart already exists at 12x12 in `Assets/UI/`).

## Answer

Zzz, hearts, seeds and notes rise beside Coco. `Sources/Coco/Particles.swift`, drawn by `SpriteView`.

**Particles live on the stage, not on the canvas.** They rise above her head, and there were only 16 rows up there. Growing the canvas a third time would have meant re-cutting every sprite, every hat overlay and every flight frame — so instead the *stage* is taller than the canvas (64x88), with sprites pinned to its floor and 24 rows reserved above. **No asset changed.**

**Shapes are pixel matrices in code**, not files: at five pixels a side an image buys nothing, and a mark that fades needs its colour chosen at draw time anyway.

**Particles are never mirrored.** Coco is — she is one drawing flipped — but a flipped heart is still a heart and a flipped Z is a mistake. They are drawn outside the mirror transform; only their origin changes side.

**They are emitted over time, not in a burst.** Four hearts emitted in one frame from one point at one velocity *are* one thick heart, which is what the human saw and reported. A queue now releases one every 0.26 s, each from a slightly different point with its own velocity and lifetime.

**Feeding uses the seed diamond, not hearts** — the same mark as the hunger icon in the menu, so you can see *which* need is filling without reading anything.

**Asleep the loop runs at 4 Hz, not 1.** Stopping nearly dead was right while there was nothing to draw; with Zzz rising, 1 fps looks broken. The real saving now happens when Coco is hidden, which drops to 1 Hz.

### The sad face, settled over three attempts

The mood sprite was chosen only on *entering* rest, and the initial clip was hardcoded to the happy idle — so at launch, and whenever her mood fell while she was already sitting, she kept the wrong face. Fixed both ways: the first clip is built from the mood she loads with, and rest re-enters when the mood changes.

The drawing then went: a **curved arc** (read as "eyes closed"), a **tear** two pixels long (merged with the cere, which sits right beside it and is the same blue), a **longer tear with a white head** (worked), and finally the lid itself changed from a curve to a **line slanting down towards the beak**. An **X** was considered and rejected: it is the "fainted" convention, and it contradicts a bird who by design never sickens or dies. A flat horizontal line was rejected because that is exactly what `blink` is.

And the part that carries furthest: **sad Coco moves less.** Six to fourteen seconds of stillness instead of two to six, 65% speed, and half her decisions are to stay put. The drooping eye is four pixels; how much she moves is what reads across a room.
