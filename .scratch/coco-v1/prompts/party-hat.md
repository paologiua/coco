# Generation prompt — party hat

Worn as an overlay over any frame, so it must be the hat ALONE, with nothing under it.

New chat. PNG, 1024x1024.

**Known risk:** an isolated tiny object is the case these models get most wrong — with no body
beside it there is nothing to calibrate scale against, so it tends to come back huge and detailed.
If it does, the hand-drawn hat in `Assets/Sprites/hat.png` stands.

---

Pixel art sprite, 1024x1024, a single object centred in the frame.

A small party hat: a cone, seen from the side, standing upright with its wide opening at the
bottom and its point at the top, topped by a round fluffy pom-pom. Nothing else in the image — no
head, no character, no hand, no confetti, no table.

CRITICAL — this must be TRUE pixel art at LOW resolution. The whole hat is drawn on a grid only
about 16 pixels wide and 20 pixels tall, then scaled up so each "pixel" is a large, perfectly
sharp square aligned to the grid. Very chunky and blocky, only a handful of pixels across. Hard
edges only. NO antialiasing, NO gradients, NO soft shading, NO blur, NO glow, NO drop shadow.

Background: solid flat magenta #FF00FF filling the whole canvas.

Design:
- A simple cone with a flat, straight bottom edge — it will sit on a bird's head, so the bottom
  must be a clean horizontal line, not curved or ragged.
- Two or three bold horizontal stripes banding the cone: violet-blue #5B62B8 alternating with
  cream #EDE9D0.
- A round white #FFFFFF pom-pom at the very tip.
- A clean unbroken dark outline in #1B2E14 around the whole hat.

Strictly limited palette, use ONLY these colours:
#1B2E14 outline, #5B62B8 violet, #EDE9D0 cream, #FFFFFF pom-pom, #FF00FF background only.
