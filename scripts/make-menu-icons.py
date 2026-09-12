#!/usr/bin/env python3
"""The action icons for the menu: feed, play, sleep, and hide/show.

Hand-drawn like the need icons beside them, and for the same reason: at this size
there is nothing to downscale. They are 16x16 rather than 12x12 because a menu item
shows its image at 16 points, and a 16 grid doubled is exactly what a Retina menu
draws — a 12 grid stretched to 16 points is soft in a way pixel art cannot afford.

Two symbols. `#` is the fill, and `o` is drawn in the outline colour: the pupil of the
eye is a hole, not a highlight, and leaving it to the rim rule made it a dark ring
with a pale middle — an eye with two pupils.

The rim rule is the one the need icons use: any lit pixel with an empty orthogonal
neighbour is outline. It is why every stroke here is at least four pixels thick. A
thinner one is all rim and no core, which is what made the first hoop look like wire.

    scripts/make-menu-icons.py
"""
import subprocess

# A seed, the same diamond as the hunger need and the seed particle: one mark, one
# meaning. Feeding her is the thing that fills that bar.
SEED = """
................
................
.......##.......
......####......
.....######.....
....########....
...##########...
..############..
..############..
...##########...
....########....
.....######.....
......####......
.......##.......
................
................"""

# The hoop she flies through. Laid out from a circle rather than by hand — an ellipse
# drawn pixel by pixel at this size comes out lumpy on the diagonals.
HOOP = """
................
.....######.....
...##########...
..############..
.######..######.
.#####....#####.
.####......####.
.####......####.
.####......####.
.####......####.
.#####....#####.
.######..######.
..############..
...##########...
.....######.....
................"""

# A Z. The mark the sleeping Coco already breathes out, so the menu item and the bird
# say the same thing.
ZED = """
................
................
..############..
..############..
..############..
..........#####.
.........#####..
........#####...
.......#####....
......#####.....
.....#####......
..############..
..############..
..############..
................
................"""

# An open eye: she is on screen and can be seen. A filled almond with the pupil
# punched out of it, laid out from two overlapping circles — an eye drawn by hand at
# this size comes out as a lopsided blob, and an eye is a shape everybody knows.
EYE = """
................
................
................
....########....
..############..
.#####oooo#####.
#####oooooo#####
#####oooooo#####
#####oooooo#####
#####oooooo#####
.#####oooo#####.
..############..
....########....
................
................
................"""

# The same eye struck through: she is off screen. The stroke covers the pupil, which
# is how the idiom works — it is read as one mark, not as an eye with a line near it.
EYE_CROSSED = """
................
................
...........***..
....######****..
..#######*****..
.#####oo*****##.
#####oo*****####
#####o*****#####
#####*****o#####
####*****oo#####
.##*****oo#####.
..*****#######..
..****######....
..***...........
................
................"""

# Two rims, one drawing. The near-black rim is what gives these their weight on a
# light menu, and on a dark one it IS the background: the outermost ring of every
# glyph vanishes and what is left reads as a different shape — the hoop lost its caps
# and came out a hexagon, the Z lost the top and bottom of its bars. So the dark menu
# gets the same art with a rim light enough to survive it, still dark enough against
# the fills to read as an outline rather than a halo.
OUTLINE = "1B2E14"
OUTLINE_DARK = "5A6B4E"
N = 16

ART = {
    "feed":  (SEED, "D9C48C"),
    "play":  (HOOP, "E8CF3F"),
    "sleep": (ZED, "8FB6D9"),
    "show":  (EYE, "EDE9D0"),
    "hide":  (EYE_CROSSED, "EDE9D0"),
}
# The stroke through the hidden eye. The red the refused mark uses, so "not now" looks
# the same wherever it appears.
STRIKE = "DB2E21"


def rgb(h):
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def draw(name, art, fill, outline, suffix):
    grid = art.strip("\n").split("\n")
    assert len(grid) == N, f"{name}: {len(grid)} rows"
    assert all(len(row) == N for row in grid), f"{name}: a row is not {N} wide"
    cells = {(x, y): c for y, row in enumerate(grid) for x, c in enumerate(row) if c != "."}
    rows = []
    for y in range(N):
        for x in range(N):
            cell = cells.get((x, y))
            if cell is None:
                rows.append(f"{x},{y}: (0,0,0,0)")
                continue
            # Rim = any lit pixel with an empty orthogonal neighbour. The strike is its
            # own shape and is rimmed against the eye as well as against the ground,
            # which is what keeps it legible where it crosses.
            same = {(x, y) for (x, y), c in cells.items()
                    if (c == "*") == (cell == "*")}
            rim = any((x + dx, y + dy) not in same
                      for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if cell == "o":
                colour = outline
            elif cell == "*":
                colour = outline if rim else STRIKE
            else:
                colour = outline if rim else fill
            r, g, b = rgb(colour)
            rows.append(f"{x},{y}: ({r},{g},{b},255)")
    txt = f"# ImageMagick pixel enumeration: {N},{N},255,srgba\n" + "\n".join(rows) + "\n"
    path = f"Assets/UI/menu_{name}{suffix}.png"
    subprocess.run(["magick", "txt:-", "-filter", "Point", "-resize", "200%",
                    "-strip", f"PNG32:{path}"], input=txt.encode(), check=True)
    print(path)


for name, (art, fill) in ART.items():
    draw(name, art, fill, OUTLINE, "")
    draw(name, art, fill, OUTLINE_DARK, "_dark")
