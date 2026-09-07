# Generation prompt — base sprite

The one that worked. Produced `art-raw/base-01.png`, from which `Assets/Sprites/idle.png` was cleaned.

Ask for **PNG**, not JPEG. The model produced a 2x2 grid despite being asked for a single bird (it carried context from the earlier request in the same chat) — harmless, just pick the best quadrant.

---

Pixel art sprite, 1024x1024, a single character centred in the frame, filling most of the canvas.

A cute budgerigar (parakeet) named Coco, seen from the side, facing RIGHT, perched on invisible ground, whole body visible, standing in a calm neutral resting pose: wings folded flat against the body, tail hanging down and to the left, eye open and alert.

CRITICAL — this must be TRUE pixel art at LOW resolution. The whole bird is drawn on a grid only about 46 pixels wide and 40 pixels tall, then scaled up so each "pixel" is a large, perfectly sharp square aligned to the grid. Chunky and blocky. Hard edges only. NO antialiasing, NO gradients, NO soft shading, NO blur, NO glow, NO drop shadow, NO texture. Large flat areas of a single colour.

Background: solid flat magenta #FF00FF filling the whole canvas. No ground line, no scenery, no border, no text, no watermark.

Design:
- Bright yellow head and face. Green body, wings, back and tail.
- Black-and-cream horizontal barring across the nape and the top of the folded wings.
- ONE large round black eye with a single white highlight pixel. Nothing else on the face beside the eye except the beak.
- A small round violet-blue cheek patch placed BELOW the eye, on the yellow cheek. It must not touch the eye.
- A short curved pale beak at the front of the face, with a small light-blue cere directly ABOVE the beak. The cere must not be near or behind the eye.
- Two small pale feet gripping the invisible perch.
- Chunky, rounded, cute proportions: big round head, compact plump body, short neck.
- A clean unbroken dark outline in #1B2E14 around the entire silhouette.

Strictly limited palette, use ONLY these colours:
#1B2E14 outline, #2F6B1B #4E9327 #7ABF3A #A8D95C greens, #C9A62B #E8CF3F #F7EC8A yellows, #2A2A22 and #EDE9D0 wing barring, #5B62B8 cheek, #D9C48C beak, #8FB6D9 cere, #C9A98A feet, #FFFFFF eye highlight, #FF00FF background only.

---

## What to expect back

- **The body is good, the face is wrong.** Every time. At 48x48 the face has the fewest pixels to spend and the model muddles the eye — the first one came back as a 4x4 blob mixing the outline colour, mid green and the *feet* colour. Budget a hand pass on the head for every frame.
- **Declaring the pixel budget ("about 46 wide by 40 tall") is what produces chunky blocks.** Asking for "chunky pixels" in words does not work; asking for a count does.
- **Naming eye, cheek patch and cere separately, with their positions relative to each other**, is what stopped the model smearing them into one blue blob behind the eye.
