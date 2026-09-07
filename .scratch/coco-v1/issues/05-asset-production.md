# 05 — Produce the full asset set

Type: task
Status: resolved
Blocked by: —
Parent: [map](../map.md)

## Question

Generate and clean every sprite v1 needs, using the pipeline and prompt established in `01`.

- **Animations** (32x32, facing right only, mirrored in code): idle 4, sad idle 2, walk 4, fly 4, eat 4, play 4, sleep 2, petted 3, dragged 2 — 29 frames.
- **Party hat overlay**, one sprite, anchored per `01`.
- **Menubar silhouettes**: one monochrome template icon per Mood level (level count comes from `04`).
- **Menu status sprites**: the pixel-art need bars shown inside the open menu.
- **App icon** for the `.app` bundle.

If time runs short, the agreed drop order is: `play` first, then `sad idle`. Everything else is load-bearing.

Resolved when every asset exists in the repo under the naming convention from `01`, at true 32x32 with transparent backgrounds and a consistent palette.

## Scope changes agreed while working

- **The hat is anchored per frame**, not composited at a fixed position. A single overlay works
  only while the head stays put — true for every frame derived from the base sprite, false for
  flight (body horizontal, head elsewhere) and for eating (head down). So: one hat asset plus a
  small per-animation offset table, and **a second, tilted hat for the flight pose**.

  Rejected: generating every animation a second time with the hat on. The generator does not hold
  registration, so a hatted variant would be a subtly *different* bird, and Coco would visibly jump
  between hatted and bare frames. The overlay is not only cheaper, it is the only way to guarantee
  the hat never dances.

- **A front-facing base sprite is added.** Unlike the side view it has no direction and is never
  mirrored, which makes it the natural pose for sleeping and for any moment Coco faces the viewer.
  Prompt: [`prompts/front-view.md`](../prompts/front-view.md).

- **Generated rather than hand-drawn, at the human's request**: the party hat
  ([`prompts/party-hat.md`](../prompts/party-hat.md)) and, as an experiment, the menubar mood icons
  ([`prompts/mood-icons.md`](../prompts/mood-icons.md)). The hand-drawn versions already exist and
  stand as the fallback if the generated ones come back worse.

## Answer

Every asset v1 needs now exists. The 29-frame plan from charting was never executed and should not be: most poses were **derived**, several were **replaced by motion in code**, and only two things were genuinely generated.

**Generated** (three prompts, in `prompts/`): the perched side base, the front-facing base, the flight cycle, the party hat, and the mood heads.

**Derived by editing the face only** — `scripts/make-derived-sprites.sh`: `blink`, `sad` (drooping lid), `petted` (squeezed shut), `sleep` (front pose, both eyes closed). Editing rather than generating guarantees the body is pixel-identical across poses, so Coco cannot twitch when her mood changes.

**Replaced by code, no asset at all**: breathing (a 1px bob), walking (a bob plus horizontal motion), being dragged and playing (both reuse flight frames), eating (a downward bob plus a seed).

**Delivered**

| Where | What |
|---|---|
| `Assets/Sprites/` | `idle`, `blink`, `sad`, `petted`, `front`, `sleep`, `fly_0`–`fly_3`, `hat_side`, `hat_front` |
| `Assets/Menubar/` | `mood_happy`, `mood_content`, `mood_meh`, `mood_sad` — colour, 44x44 shown at 22 pt |
| `Assets/UI/` | `need_hunger`, `need_affection`, `need_energy` — 12x12 doubled |
| `Assets/Icon/` | seven sizes, 16 to 1024, assembled into `.icns` by `iconutil` |

### Decisions and reversals worth keeping

- **The canvas grew twice.** 48x48 → 48x64 when the party hat had nowhere to go (the perched sprite fills its frame to the top row), then → **64x64** when the flight frames turned out to be 52 pixels wide with the wings spread. Both were discovered by making the asset, not by planning.

- **Flight frames are aligned on the eye highlight.** The four generated birds were offset from each other by over 100 source pixels. Aligning on the bounding box would make the head lurch while the wings flap; the eye is the one pure-white cluster in the palette, so it can be found automatically. Each frame is placed so the eye lands exactly where the perched sprite's eye sits — which means **take-off costs no transition**, the head simply does not move. `scripts/align-flight.py`.

- **The menubar icons are colour, chosen against the evidence.** A hand-drawn monochrome template set was built first and measured as more legible at 22 points: the eye there is a *hole* in a solid silhouette, whereas in the colour head it is two pixels among beak, cere, cheek and barring, all dark marks of the same size — `sad` and `meh` become hard to tell apart. The human chose colour for character, which is a legitimate trade and is recorded here so it is not rediscovered as a bug. The monochrome generator was **deleted** rather than left in the tree: a script that silently overwrites the real assets with the rejected ones is a trap.

- **The generator always gets the face wrong.** Every generated sprite arrived with a muddled eye — in the first one, mixing the outline colour, mid green and the *feet* colour. Budget a hand pass on the head for anything generated in future.
