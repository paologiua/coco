#!/usr/bin/env python3
"""Bake the party hat into every sprite, once per frame, at a computed anchor.

Replaces the old overlay approach, where ONE `hat_side` and ONE `hat_front` layer were
composited over every pose in code. That worked for the perched side poses and nothing
else: the flight frames carry the head 1-3 canvas pixels higher or wider than the
perched pose, which at 3x is a visible gap between hat and skull, and the front pose's
hat sat two pixels right of the crown. Keeping a hand-written anchor per frame was the
thing that made the hat not worth having.

The anchor is therefore MEASURED, not tabulated. Coco's violet cheek patch (#5B62B8) is
a small blob that appears on the face and nowhere else, so it identifies the head in any
pose; the head is then the run of face-yellow connected to it, and the hat is placed
against the crown of that run.

The placement rule is calibrated from `idle`, the one pose whose hat was always right:
the hat's centre sits one pixel right of the crown's midpoint, and its base two pixels
below the crown's top row, so the brim bites into the skull instead of floating on it.
Run against idle it reproduces the old hand-placed +38+0 exactly.

Every sprite gets a `<name>_hat.png` twin. New animations cost nothing extra: draw the
frame, re-run this, and its hatted twin exists.

    scripts/make-hatted-sprites.py [name ...]      # default: every sprite
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "Assets" / "Sprites"
HAT = ROOT / "Assets" / "hat-source.png"

CANVAS = 64
CHEEK = "5B62B8"                          # the violet cheek patch: face, and only face
FACE_YELLOW = {"C9A62B", "E8CF3F", "F7EC8A"}
# Calibrated from `idle`, whose hat placement was correct before this script existed.
HAT_DX = 1                                # hat centre, relative to the crown midpoint
HAT_DY = 2                                # hat base, below the crown's top row


def canvas_pixels(path):
    """The sprite as {(x, y): 'RRGGBB'} in the 64x64 canvas the app actually draws.

    Mirrors `Sprite.pad` in Sources/Coco/Sprite.swift: bottom-anchored, centred. A
    48x48 pose measured in its own frame would be 8 pixels out horizontally.
    """
    out = subprocess.run(
        ["magick", str(path), "-background", "none", "-gravity", "south",
         "-extent", f"{CANVAS}x{CANVAS}", "-depth", "8", "txt:-"],
        capture_output=True, text=True, check=True).stdout
    px = {}
    for line in out.splitlines()[1:]:
        m = re.match(r"(\d+),(\d+): \([^)]*\)\s+#([0-9A-F]{8})", line)
        if m and int(m.group(3)[6:8], 16) > 127:
            px[(int(m.group(1)), int(m.group(2)))] = m.group(3)[:6]
    return px


def head_crown(px):
    """(crown_mid_x, crown_top_y) of the head, found from the cheek outwards."""
    cheek = [p for p, c in px.items() if c == CHEEK]
    if not cheek:
        return None
    cx = sum(x for x, _ in cheek) // len(cheek)
    cy = sum(y for _, y in cheek) // len(cheek)

    # Flood the face-yellow connected to the cheek. Connectivity is what keeps wing
    # highlights — the same pale yellow, but not touching the face — out of the head.
    seeds = [(cx + dx, cy + dy) for dx in range(-3, 4) for dy in range(-4, 2)
             if px.get((cx + dx, cy + dy)) in FACE_YELLOW]
    if not seeds:
        return None
    head, stack = set(), list(seeds)
    while stack:
        p = stack.pop()
        if p in head or px.get(p) not in FACE_YELLOW:
            continue
        head.add(p)
        x, y = p
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]

    top = min(y for _, y in head)
    xs = [x for x, y in head if y == top]
    return (min(xs) + max(xs)) // 2, top


def bake(name):
    src = SPRITES / f"{name}.png"
    px = canvas_pixels(src)
    crown = head_crown(px)
    if crown is None:
        print(f"  {name}: no cheek found — skipped (not a pose of Coco?)")
        return False
    mid, top = crown

    # The hat drawing sits inside a 20x20 source; place by its own ink, not its canvas.
    trim = subprocess.run(["magick", str(HAT), "-trim", "-format", "%w %h %X %Y", "info:"],
                          capture_output=True, text=True, check=True).stdout.split()
    hw, hh = int(trim[0]), int(trim[1])
    hx, hy = int(trim[2].lstrip("+")), int(trim[3].lstrip("+"))

    # Inclusive pixel spans: a 14-wide stamp has its centre at index 6, and its
    # base row at index 13 — hence (n - 1) // 2 and (n - 1), not n // 2 and n.
    # Off by one here puts the hat a pixel off the skull in every single frame.
    left = mid + HAT_DX - (hw - 1) // 2 - hx
    topy = top + HAT_DY - (hh - 1) - hy

    out = SPRITES / f"{name}_hat.png"
    subprocess.run(
        ["magick", str(src), "-background", "none", "-gravity", "south",
         "-extent", f"{CANVAS}x{CANVAS}",
         str(HAT), "-gravity", "none", "-geometry", f"{left:+d}{topy:+d}",
         "-compose", "over", "-composite", f"PNG32:{out}"], check=True)
    print(f"  {name}_hat.png  crown=({mid},{top})  hat at {left:+d}{topy:+d}")
    return True


def main():
    names = sys.argv[1:]
    if not names:
        names = sorted(p.stem for p in SPRITES.glob("*.png")
                       if not p.stem.startswith("hat") and not p.stem.endswith("_hat"))
    print(f"Baking the hat into {len(names)} sprite(s):")
    made = sum(bake(n) for n in names)
    print(f"{made} hatted sprite(s) written to Assets/Sprites/")


if __name__ == "__main__":
    main()
