#!/usr/bin/env python3
"""Flatten the hoop prop onto three tones of the locked palette.

`hoop.png` arrived as a render that was area-averaged down to 21x60, and an average
gives every pixel a shade of its own: 637 drawn pixels carried 586 distinct colours,
none of them on the palette. Blown up to the three points per pixel the game shows it
at, that is not pixel art — it is a photograph of pixel art, and it reads as soft and
restless however cleanly it is drawn and however carefully it is blitted.

The drawing underneath was never the problem. Cluster those 586 shades and exactly
three fall out, laid in a band that is the same all the way round the ellipse: outline,
shadow, highlight, mirrored. This snaps each pixel to the nearest of the three and
leaves the shape alone. The ring keeps its silhouette, its thickness and its opening —
`AppDelegate.hoopOpening` measures 50 of these 60 rows and must go on being true.

The three are the render's own, and they are the one place in the app that is not on
the locked palette — `food.png` is five palette entries and nothing else, and the
particle colours in `Particles.swift` are palette values by name. It is a deliberate
exception, made after looking at both: the palette has greens and yellows for a bird
and no amber at all, so snapping the ring to it costs the shadow its warmth, the two
remaining golds sit too close to read as a tube, and a prop drawn round comes out flat.
Widening the gap to the palest yellow buys the volume back and spends it worse — the
render's highlight wanders by a pixel here and there, which is invisible at low
contrast and reads as scattered glints at high. Keeping the ring's own three tones
keeps the object that was drawn.

Idempotent: run on its own output, every pixel is already its own nearest tone.

    scripts/clean-hoop.py
"""
import re
import subprocess

ART = "Assets/UI/hoop.png"

# Outline, shadow, highlight: the cluster centres of the render's own 586 shades,
# rounded. Change these and the ring changes colour — they are the drawing, not a
# convention.
TONES = [(0x18, 0x1A, 0x0A), (0xCB, 0x7A, 0x05), (0xF8, 0xD2, 0x1B)]
# A pixel is either there or it is not, exactly as `clean-sprite.sh` decides it.
ALPHA_FLOOR = 128

PIXEL = re.compile(r"^(\d+),(\d+): \((\d+),(\d+),(\d+),(\d+)\)")


def read(path):
    out = subprocess.run(["magick", path, "-depth", "8", "txt:-"],
                         capture_output=True, check=True).stdout.decode()
    pixels, width, height = {}, 0, 0
    for line in out.splitlines():
        found = PIXEL.match(line)
        if not found:
            continue
        x, y, r, g, b, a = (int(v) for v in found.groups())
        pixels[(x, y)] = (r, g, b, a)
        width, height = max(width, x + 1), max(height, y + 1)
    return pixels, width, height


def nearest(colour):
    return min(range(len(TONES)),
               key=lambda i: sum((colour[c] - TONES[i][c]) ** 2 for c in range(3)))


pixels, width, height = read(ART)
tone = {xy: (None if p[3] < ALPHA_FLOOR else nearest(p)) for xy, p in pixels.items()}

# Nothing else. Evening out the odd pixel that sits the far side of a boundary was
# tried twice and dropped twice, because at this size the noise and the drawing are
# the same shape:
#
#   - across the band, where the ellipse turns it narrows to outline-shadow-HIGHLIGHT-
#     shadow-outline, so a one-pixel highlight is flanked by two shadows that agree
#     against it BY CONSTRUCTION. The rule deleted the highlight from every narrow part
#     of the ring — it read the drawing's finest detail as its worst noise.
#   - along it, the band runs vertically down the sides and horizontally over the crown,
#     so "along" rotates through ninety degrees on the way round and the same test dims
#     the top of the ring instead.
#
# What is left is a handful of single pixels on the straight sides, which are the
# render's and not worth a rule that cannot tell them from art. Redraw the ring if they
# ever start to show.

rows = []
for y in range(height):
    for x in range(width):
        index = tone.get((x, y))
        if index is None:
            rows.append(f"{x},{y}: (0,0,0,0)")
        else:
            r, g, b = TONES[index]
            rows.append(f"{x},{y}: ({r},{g},{b},255)")
txt = f"# ImageMagick pixel enumeration: {width},{height},255,srgba\n" + "\n".join(rows) + "\n"
subprocess.run(["magick", "txt:-", "-strip", f"PNG32:{ART}"], input=txt.encode(), check=True)

drawn = sum(1 for index in tone.values() if index is not None)
print(f"{ART}: {width}x{height}, {drawn} drawn pixels on three tones")
