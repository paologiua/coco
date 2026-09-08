#!/usr/bin/env python3
"""Draw the ORIGINAL birthday party hat — the symmetric cone.

No longer the hat Coco wears. `Assets/hat-source.png` now holds a hat that was
drawn onto her head by an image generator and lifted back out: it is shorter,
tilted back, and its brim follows the curve of her skull, which the symmetric cone
below never could. This script is kept because it is the only record of how the
cone was built, and the fallback if the extracted hat is ever rejected.

Drawn on the FULL 48x64 canvas rather than as a small patch with an anchor point:
compositing then needs no coordinate maths and cannot drift between animations.

Violet and cream deliberately — a yellow hat vanishes against Coco's yellow head.
"""
import subprocess

W, H = 48, 64
OUTLINE, BODY, STRIPE, POM = "1B2E14", "5B62B8", "EDE9D0", "FFFFFF"

CENTRE = 35.0
TIP_Y, BASE_Y = 6, 18          # the head's crown sits at canvas y=16

px = {}
for y in range(TIP_Y, BASE_Y + 1):
    half = (y - TIP_Y) * 0.46 + 0.5
    lo, hi = round(CENTRE - half), round(CENTRE + half)
    for x in range(lo, hi + 1):
        edge = x in (lo, hi) or y == BASE_Y
        band = ((y - TIP_Y) // 3) % 2 == 1
        px[(x, y)] = OUTLINE if edge else (STRIPE if band else BODY)
for (dx, dy) in [(0, 0), (1, 0), (0, 1), (1, 1)]:      # pom-pom on the tip
    px[(35 + dx, 3 + dy)] = POM
for (dx, dy) in [(0, -1), (1, -1), (-1, 0), (2, 1), (0, 2), (1, 2), (-1, 1)]:
    px.setdefault((35 + dx, 4 + dy), OUTLINE)

def rgb(h):
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)

# ImageMagick's txt reader takes the RGBA tuple; the trailing hex is only a comment.
rows = []
for y in range(H):
    for x in range(W):
        c = px.get((x, y))
        if c:
            r, g, b = rgb(c)
            rows.append(f"{x},{y}: ({r},{g},{b},255)")
        else:
            rows.append(f"{x},{y}: (0,0,0,0)")
txt = f"# ImageMagick pixel enumeration: {W},{H},255,srgba\n" + "\n".join(rows) + "\n"
subprocess.run(["magick", "txt:-", "PNG32:Assets/hat-source-cone.png"], input=txt.encode(), check=True)
print("Assets/hat-source-cone.png")
