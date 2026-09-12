#!/usr/bin/env python3
"""The three need icons for the menu, 12x12, doubled to 24x24 for Retina.

Hand-drawn rather than generated: at this size there is nothing to downscale, and
they must read instantly beside a bar.

Two sizing lessons, both learnt the hard way. At 8x8 the rim rule below ate the whole
glyph and the heart and bolt became blobs. And a diagonal stroke narrower than four
pixels is all rim and no core, which left the first bolt looking dashed.
"""
import subprocess

SEED = """
............
.....##.....
....####....
...######...
..########..
..########..
..########..
...######...
....####....
.....##.....
............
............"""

HEART = """
............
..###..###..
.##########.
.##########.
.##########.
.##########.
..########..
...######...
....####....
.....##.....
............
............"""

BOLT = """
............
......#####.
.....#####..
....#####...
...#####....
..#########.
......#####.
.....#####..
....#####...
...#####....
..####......
............"""

ART = {
    "hunger": (SEED, "D9C48C"),
    "affection": (HEART, "5B62B8"),
    "energy": (BOLT, "E8CF3F"),
}
# One drawing, two rims. On a dark menu the near-black rim IS the background: it
# disappears and the glyph left behind is a different shape — the seed rounds off into
# an octagon, the heart loses the notch between its lobes. The dark menu gets a rim
# light enough to survive it and still dark enough against the fills to read as an
# outline. Same reasoning, same pair of colours as the menu glyphs beside these.
OUTLINE = "1B2E14"
OUTLINE_DARK = "5A6B4E"
N = 12


def rgb(h):
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def draw(name, art, fill, outline, suffix):
    grid = art.strip("\n").split("\n")
    on = {(x, y) for y, row in enumerate(grid) for x, c in enumerate(row) if c == "#"}
    rows = []
    for y in range(N):
        for x in range(N):
            if (x, y) not in on:
                rows.append(f"{x},{y}: (0,0,0,0)")
                continue
            # Rim = any lit pixel with an empty orthogonal neighbour.
            rim = any((x + dx, y + dy) not in on
                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            r, g, b = rgb(outline if rim else fill)
            rows.append(f"{x},{y}: ({r},{g},{b},255)")
    txt = f"# ImageMagick pixel enumeration: {N},{N},255,srgba\n" + "\n".join(rows) + "\n"
    path = f"Assets/UI/need_{name}{suffix}.png"
    subprocess.run(["magick", "txt:-", "-filter", "Point", "-resize", "200%",
                    f"PNG32:{path}"], input=txt.encode(), check=True)
    print(path)


for name, (art, fill) in ART.items():
    draw(name, art, fill, OUTLINE, "")
    draw(name, art, fill, OUTLINE_DARK, "_dark")
