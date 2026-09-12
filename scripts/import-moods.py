#!/usr/bin/env python3
"""Import the four mood heads into Assets/Menubar/.

One generated PNG on a magenta field, four quadrants, in reading order: happy,
content, meh, sad — the order `Mood` declares them in. Each is Coco's head with the
mark that names the mood beside it: sparkles, a heart, nothing, a rain cloud.

Two things make this more than a crop.

**The mark is not part of her head.** Fitting each quadrant's whole drawing to the
icon would make her head a different size in every mood — the sad one carries a cloud
and four raindrops, the meh one carries nothing — so she would swell as she cheered
up. Every quadrant is placed by the HEAD instead: the largest blob on it, which the
marks are an order of magnitude too small to be mistaken for.

**One scale for all four.** It is the largest that leaves every quadrant's marks
inside the icon, so the heads match each other and nothing is clipped. The head ends
up about 18 of the 22 points, a little smaller than the old head-only icons, which is
the price of the marks — and they are what makes happy and content tell apart at this
size, where the difference in her eye is two pixels.

Deliberately NOT remapped to the locked palette, which the hand-built icons this
replaces were. That palette is Coco's own fifteen colours: it has no red and no
storm blue, so remapping turned the heart brown and the rain cloud into foliage.

    scripts/import-moods.py [source.png]      # default Assets/Moods/moods.png
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Assets" / "Moods" / "moods.png"
OUT = ROOT / "Assets" / "Menubar"
# Logical points. The app declares the image 22x22 and ships it at twice that, so a
# Retina bar draws each pixel as a crisp 2x2 block instead of smoothing an upscale.
ICON = 22
RETINA = 2
FUZZ = "25%"
# Reading order. The same order `Mood` declares, which is also brightest to darkest.
MOODS = ["happy", "content", "meh", "sad"]


def run(args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def keyed(path, crop=None):
    return ["magick", str(path)] + (["-crop", crop, "+repage"] if crop else []) + [
        "-fuzz", FUZZ, "-transparent", "magenta", "-alpha", "set"]


def blobs(path, crop):
    """Everything drawn in one quadrant, largest first: the head, then its marks."""
    out = run(keyed(path, crop) + [
        "-alpha", "extract", "-threshold", "50%",
        "-define", "connected-components:verbose=true",
        "-define", "connected-components:area-threshold=20",
        "-connected-components", "8", "null:"])
    found = []
    for line in out.splitlines()[1:]:
        m = re.match(r"\s*\d+:\s+(\d+)x(\d+)\+(\d+)\+(\d+)\s+[\d.]+,[\d.]+\s+([\d.e+]+)\s+(\S+)",
                     line)
        if not m:
            continue
        w, h, x, y, area, colour = (int(m.group(1)), int(m.group(2)), int(m.group(3)),
                                    int(m.group(4)), float(m.group(5)), m.group(6))
        if "255,255,255" not in colour and "gray(255)" not in colour:
            continue                                  # the empty field, not the art
        found.append(dict(w=w, h=h, x=x, y=y, area=area))
    found.sort(key=lambda f: -f["area"])
    return found


def main():
    src = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else SOURCE
    width, height = (int(v) for v in run(["magick", str(src), "-format", "%w %h", "info:"]).split())
    q_w, q_h = width // 2, height // 2

    quadrants = []
    for index, mood in enumerate(MOODS):
        crop = f"{q_w}x{q_h}+{(index % 2) * q_w}+{(index // 2) * q_h}"
        found = blobs(src, crop)
        if not found:
            print(f"  {mood}: nothing found")
            return
        head = found[0]
        # Her head's middle, not the drawing's: the marks hang off one side, so a
        # drawing centre would slide her left by however much this mood carries.
        centre = (head["x"] + head["w"] / 2, head["y"] + head["h"] / 2)
        span = (min(f["x"] for f in found) - centre[0],
                max(f["x"] + f["w"] for f in found) - centre[0],
                min(f["y"] for f in found) - centre[1],
                max(f["y"] + f["h"] for f in found) - centre[1])
        quadrants.append(dict(mood=mood, crop=crop, head=head, centre=centre, span=span))

    # One scale, set by whichever mood reaches furthest from her head — the rain cloud,
    # as it turns out. Anything larger clips somebody's mark.
    reach = (min(q["span"][0] for q in quadrants), max(q["span"][1] for q in quadrants),
             min(q["span"][2] for q in quadrants), max(q["span"][3] for q in quadrants))
    scale = min(ICON / (reach[1] - reach[0]), ICON / (reach[3] - reach[2]))
    # Where her head's middle goes, so that the furthest mark of any mood lands just
    # inside the icon. Not the middle of the icon: the marks are all up and to one
    # side, so centring her head would hang them over the edge.
    anchor = (-reach[0] * scale + (ICON - (reach[1] - reach[0]) * scale) / 2,
              -reach[2] * scale + (ICON - (reach[3] - reach[2]) * scale) / 2)

    OUT.mkdir(parents=True, exist_ok=True)
    for q in quadrants:
        # -extent's offset is the viewport origin in the scaled quadrant, so it is the
        # anchor point minus where that point should land.
        vx = q["centre"][0] * scale - anchor[0]
        vy = q["centre"][1] * scale - anchor[1]
        name = "mood_" + q["mood"] + ".png"
        # Built at the icon's own size and then pixel-doubled, rather than rendered
        # straight to 44: doubling keeps every pixel a square block, where rendering at
        # twice the size lands the art's pixels on half-boundaries and softens them.
        run(keyed(src, q["crop"]) + [
            "-filter", "Box", "-resize", f"{scale * 100:.4f}%",
            "-background", "none", "-alpha", "set", "-gravity", "none",
            "-extent", f"{ICON}x{ICON}{vx:+.0f}{vy:+.0f}",
            # Hard edges. Averaging a 627px quadrant down to 22 leaves every outline
            # pixel part transparent, and at this size that grey halo is a third of
            # what you see: she looked smudged rather than drawn.
            "-channel", "A", "-threshold", "50%", "+channel",
            "-filter", "Point", "-resize", f"{RETINA * 100}%",
            # Stripped so a re-import is byte-identical when the art has not changed.
            "-alpha", "on", "-strip",
            f"PNG32:{OUT / name}"])
        head = q["head"]
        print(f"  {name}: head {head['w']}x{head['h']}px -> "
              f"{head['w'] * scale:.1f}x{head['h'] * scale:.1f} points, "
              f"{len(blobs(src, q['crop'])) - 1} mark(s)")
    print(f"  scale={scale:.5f}, anchor={anchor[0]:.1f},{anchor[1]:.1f}")


if __name__ == "__main__":
    main()
