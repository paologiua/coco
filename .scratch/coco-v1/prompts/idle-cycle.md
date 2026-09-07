# Generation prompt — idle cycle (4 frames)

Target: one 1024x1024 image, a 2x2 grid of four 512x512 cells, each cell one frame of a 32x32 sprite rendered at 16x.

---

Pixel art sprite sheet, 1024x1024, arranged as a 2x2 grid of four equal 512x512 cells.

Each cell contains one animation frame of the SAME character: a cute budgerigar (parakeet) named Coco, seen from the side, facing RIGHT, standing on invisible ground, full body visible.

CRITICAL — this must be TRUE pixel art: the artwork is designed on a 32x32 pixel grid and scaled up 16x with nearest-neighbour, so every "pixel" is a perfectly sharp 16x16 square aligned to the grid. Hard edges only. NO antialiasing, NO gradients, NO soft shading, NO blur, NO outline glow, NO drop shadow.

Background: solid flat magenta #FF00FF, filling every cell completely. No ground line, no scenery, no grid lines between cells, no borders, no text, no numbers, no watermark.

REGISTRATION — the most important rule: the bird occupies EXACTLY the same position and the same scale in all four cells, centred in its cell. Between frames, ONLY the parts described below change. Everything else is pixel-identical across the four frames.

Character design, identical in every frame:
- A green-and-yellow budgie. Bright yellow head and face, green body, wings and back.
- Black-and-cream horizontal barring across the back of the head, nape and the top of the wings.
- One large round black eye with a single white highlight pixel, on the head facing right.
- A small round violet-blue cheek patch below and behind the eye.
- A short curved pale beak, and a small light-blue cere just above the beak.
- Two small pale feet.
- A long green tail sweeping down and to the left.
- Chunky, rounded, cute proportions: large head, compact body. Readable at tiny size.

Strictly limited palette, use ONLY these colours:
#1B2E14 outline, #2F6B1B #4E9327 #7ABF3A #A8D95C greens, #C9A62B #E8CF3F #F7EC8A yellows, #2A2A22 and #EDE9D0 wing barring, #5B62B8 cheek, #D9C48C beak, #8FB6D9 cere, #C9A98A feet, #FFFFFF eye highlight, #FF00FF background only.
Dark outline #1B2E14 around the whole silhouette.

The four frames, reading top-left, top-right, bottom-left, bottom-right:
1. Resting. Body settled down, wings folded flat against the body, eye wide open, tail hanging straight.
2. Breathing in. The whole body is lifted very slightly, the chest puffed a little rounder and wider. Wings still folded. Eye wide open. Head and feet unmoved.
3. Identical to frame 1. Resting, eye wide open.
4. Blinking. Identical to frame 1 in every way EXCEPT the eye, which is closed: a single dark horizontal line where the eye was.

---

## Notes for the human

- Ask for the image at 1024x1024. If the generator offers a "transparent background" option, ignore it: flat magenta keys out far more reliably than the half-transparent edges these models produce.
- Frames 2 and 4 are where generators break registration. If the bird drifts or resizes between cells, do not fight the prompt — take the best single frame as the base sprite and derive the other three by hand in a pixel editor. Three tiny edits beat twenty regenerations.
- Regenerate rather than "edit" if the style drifts: follow-up edits tend to soften the pixels.
