# Generation prompt — flight cycle (4 frames)

The only animation that cannot be derived from the base sprite: flying needs a body posture and
wing shapes that simply do not exist in the perched pose.

Ask for **PNG**, 1024x1024. Start a **fresh chat** — continuing the base-sprite conversation makes
the model reproduce the perched bird.

---

Pixel art sprite sheet, 1024x1024, arranged as a 2x2 grid of four equal cells.

Each cell contains one frame of a flight cycle for the SAME character: a cute budgerigar
(parakeet) named Coco, seen from the side, facing RIGHT, in mid-air with both wings spread. Her
body is angled slightly nose-down as a flying bird's is, legs tucked up under the body, tail
extended straight back.

CRITICAL — this must be TRUE pixel art at LOW resolution. Including the spread wings, the whole
bird is drawn on a grid only about 46 pixels wide and 40 pixels tall, then scaled up so each
"pixel" is a large, perfectly sharp square aligned to the grid. Chunky and blocky. Hard edges
only. NO antialiasing, NO gradients, NO soft shading, NO blur, NO glow, NO drop shadow.

Background: solid flat magenta #FF00FF filling every cell. No ground, no sky, no motion lines, no
grid lines between cells, no border, no text.

REGISTRATION: the bird's BODY stays in exactly the same position and at the same scale in all four
cells, centred. Only the WINGS change between frames. Head, body, tail and legs are pixel-identical
across all four.

The four frames, reading top-left, top-right, bottom-left, bottom-right — a full wingbeat:
1. Wings raised fully UP above the body, tips nearly touching, in a shallow V.
2. Wings halfway down, spread wide and roughly horizontal, fully extended sideways.
3. Wings fully DOWN below the body, tips angled down and slightly forward.
4. Wings halfway up again, spread wide and roughly horizontal — same as frame 2 but with the
   feathers angled upward.

Design, identical in every frame:
- Bright yellow head and face. Green body, wings, back and tail.
- Black-and-cream horizontal barring across the nape and along the top edge of each wing.
- ONE large round black eye with a single white highlight pixel.
- A small round violet-blue cheek patch BELOW the eye, not touching it.
- A short curved pale beak, with a small light-blue cere directly ABOVE the beak.
- Chunky, rounded, cute proportions: big round head, compact plump body.
- A clean unbroken dark outline in #1B2E14 around the entire silhouette, wings included.

Strictly limited palette, use ONLY these colours:
#1B2E14 outline, #2F6B1B #4E9327 #7ABF3A #A8D95C greens, #C9A62B #E8CF3F #F7EC8A yellows,
#2A2A22 and #EDE9D0 wing barring, #5B62B8 cheek, #D9C48C beak, #8FB6D9 cere, #C9A98A feet,
#FFFFFF eye highlight, #FF00FF background only.

---

## What to expect back

Same two lessons as the base sprite: **the face will need a hand pass**, and the four cells will
not register perfectly. Here that matters less — the body is what must hold still, and if it
drifts, the best frame becomes the reference and the other three get their wings transplanted onto
it. Wings are the easy part to move; a face is not.
