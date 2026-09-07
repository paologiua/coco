# Generation prompt — menubar mood icons (experiment)

Run as a comparison against the hand-drawn icons in `Assets/Menubar/`. Expected to fail: at 18
pixels there is nothing to downscale, and the output must be pure black plus alpha so macOS can
recolour it for light and dark menu bars. Worth five minutes to find out.

New chat. PNG, 1024x1024.

---

Pixel art, 1024x1024, arranged as a 2x2 grid of four equal cells.

Each cell contains a SOLID BLACK SILHOUETTE of a budgerigar's head, seen from the side, facing
RIGHT, with a short pointed beak clearly protruding from the profile. Pure black shape, no
interior detail, no colour, no shading — a stencil.

CRITICAL — this must be TRUE pixel art at VERY LOW resolution. Each head is drawn on a grid only
about 18 pixels wide and 18 pixels tall, then scaled up so each "pixel" is a huge, perfectly sharp
square. Extremely chunky — the whole head is only about eighteen pixels across. Hard edges only.
NO antialiasing, NO grey, NO gradients, NO blur. Every pixel is either pure black #000000 or pure
white #FFFFFF.

Background: solid flat white #FFFFFF. No border, no text, no grid lines between cells.

The head silhouette is IDENTICAL in all four cells. The only difference is the eye, which is cut
out of the black shape as a white hole:
1. An upward curved arc, like a happy closed eye.
2. A wide open round eye.
3. A flat horizontal slit.
4. A downward curved arc, like a sad eye.

The eye sits in the upper front third of the head, near the beak.
