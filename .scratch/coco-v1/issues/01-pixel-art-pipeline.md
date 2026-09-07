# 01 — Pixel art pipeline and the generation prompt

Type: prototype
Status: resolved
Blocked by: —
Parent: [map](../map.md)

## Question

Can an image generator (ChatGPT) reliably produce **true 32x32, grid-aligned, transparent-background** pixel-art frames of a budgie that stay visually consistent across a 4-frame cycle — and what exact prompt plus cleanup steps produce them?

This is the critical path: 29 frames must exist before the app can look like anything, and generated "pixel art" is usually a large fuzzy image that *resembles* pixel art rather than being it (off-grid pixels, antialiased edges, opaque background, drifting palette between frames).

Resolve by producing, end to end, the **idle cycle only** (4 frames):

- Lock Coco's **design and palette** first: species markings, colours, silhouette at 32x32, a limited palette (12–16 colours) written down as hex values so every later frame matches.
- Write the **generation prompt** and record it verbatim in the answer, so it can be reused per animation.
- Establish the **cleanup procedure**: downscale to a true 32x32 grid, snap to the palette, kill antialiasing, cut the background to alpha. Name the tool used and the exact steps or script.
- Decide the **on-disk asset convention**: file naming, one PNG per frame vs a sprite sheet, where they live in the repo.
- Give a **go / no-go** on the generator, with the fallback named if it is no-go.

Also decide the **hat overlay** anchor: the party hat is a separate sprite drawn on top of any frame, so it needs a defined attachment point on Coco's head that holds across every animation.

## Notes

An open question for the human: does Coco look like a specific real budgie the recipient knows, or is she invented? Green/yellow and blue/white are the two classic budgie palettes.

## Locked palette

Green-and-yellow budgie, 15 colours. Every frame of every animation must quantize to exactly these.

| Role | Hex |
|---|---|
| Outline | `#1B2E14` |
| Green — dark | `#2F6B1B` |
| Green — mid | `#4E9327` |
| Green — light | `#7ABF3A` |
| Green — highlight | `#A8D95C` |
| Yellow — dark | `#C9A62B` |
| Yellow — mid | `#E8CF3F` |
| Yellow — light | `#F7EC8A` |
| Wing barring — dark | `#2A2A22` |
| Wing barring — cream | `#EDE9D0` |
| Cheek patch | `#5B62B8` |
| Beak | `#D9C48C` |
| Cere | `#8FB6D9` |
| Feet | `#C9A98A` |
| Eye highlight | `#FFFFFF` |

Key colour for background removal: magenta `#FF00FF`, never part of the palette.

## Progress — first generation assessed (2026-09-06)

Source: `art-raw/idle-01.jpeg`, 1024x1024, 2x2 grid, magenta key.

**What worked**

- The generator produces **genuine pixel art**: grid-aligned blocks, flat colour fields, hard edges, no antialiasing inside the shape. This was the main risk and it is cleared.
- The **magenta key works**. Background lifts cleanly; no half-transparent halo once the JPEG ringing is dealt with.
- The **character design is right**: yellow head, green body, cream/black nape barring, violet cheek patch, pale beak, long tail, readable silhouette, facing right.

**What failed**

- **Native grid is ~60 units, not 32.** Measured bounding box 474x402 px with a native block pitch of roughly 8 px, so the bird is drawn at about 59x50 "pixels". Forced down to 32x32 the barring turns to noise, the feet fragment and the eye becomes a blob. 48x48 is the smallest size that survives.
- **Registration is broken**, as predicted. Frame bounding boxes: `474x402+19+40`, `464x413+19+29`, `474x392+19+101`, `474x392+19+101`. The bottom row sits 61 px lower and the second frame is 10 px narrower. Frames from one generation cannot be used as an animation cycle without correction.
- **Delivered as JPEG**, giving 56,535 unique colours of ringing. Recoverable with a blur-then-key step, but PNG must be requested from now on.

**Pipeline bug found**

`-remap` after the alpha threshold **drops the alpha channel**. Remap RGB first, then re-apply the alpha mask.

## Answer

**Go on the generator, with a changed plan.**

**Sprite size is 48x48, not 32x32.** The generator draws at roughly a 60-unit grid; forced to 32 the barring turns to noise, the feet fragment and the eye becomes a blob. 48 is the smallest size that survives, and it renders at **3x** on screen (~144 pt tall) — see the size comparison in `art-raw/realsize.png`.

**Frames are not generated as cycles; they are derived from one base sprite.** The second generation (`art-raw/base-01.png`, PNG, single-bird prompt — the model produced a 2x2 grid anyway) came back far better registered: bounding boxes `410x498`, `413x501`, `410x502`, `413x502`, under 1% variation. But a pixel diff of the best-matched pair showed differences scattered across the whole wing, not just the eye, so **frames cannot be extracted by diffing generated variants**. Derive them from the base instead.

**The eye had to be hand-fixed and always will.** As generated it was a 4x4 mush of four colours — dark outline, mid green, and the *feet* colour — that vanished entirely at 2x. Redrawn as a 4x4 dark eye with a single white highlight pixel, plus a closed-eyelid variant. This is the lesson for every future frame: **the generator gets the body right and the face wrong**, because the face is where 48x48 has the fewest pixels to spend. Budget a hand pass on the head for every frame.

**Working prompt**: [`prompts/base-sprite.md`](../prompts/base-sprite.md) — single bird, declared pixel budget ("about 46 wide by 40 tall"), and eye/cheek/cere called out separately because the first attempt smeared them into one blue blob.

**Cleanup pipeline**: [`scripts/clean-sprite.sh`](../../../scripts/clean-sprite.sh). Keys out the magenta, crops to a caller-supplied bounding box, downscales by area average, hard-thresholds the alpha, and snaps to the locked palette. Every frame of an animation must be passed the **same crop size** or they will not register. The script works around the `-remap`-drops-alpha bug by handling RGB and alpha separately and recombining.

**Asset convention**: one PNG per frame, 48x48, transparent background, character facing **right** and mirrored in code, aligned bottom-centre on the canvas. They live in `Assets/Sprites/` and are copied to `Contents/Resources/Sprites/` by the build script.

**Delivered**: `Assets/Sprites/idle.png`, `Assets/Sprites/blink.png`, `Assets/palette.png`.

**Hat anchor**: not yet fixed — deferred to [05](05-asset-production.md), where the hat is drawn against this base sprite's head, now that the head geometry is settled.
