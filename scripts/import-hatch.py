#!/usr/bin/env python3
"""Import the hatching animation from its drawn sheet into Assets/Hatch/.

Twelve frames, six to a row, from a still egg to Coco standing in her idle pose.

Two things make this more than a crop.

**The frames must not jump.** Each is placed by the main subject's horizontal centre
and by the bottom of everything drawn — the ground she and the egg share. Centring on
the whole picture instead would swing the frame sideways every time a piece of shell
flies off, since those are separate blobs sitting well away from her.

**It has to end at Coco's size.** The last frame is her idle pose, so the whole sheet
is scaled by whatever makes that frame as tall as `idle.png` is on screen. Anything
else and she would change size at the moment the animation handed over to the real bird.

    scripts/import-hatch.py
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SHEET = ROOT / "Assets" / "Hatch" / "source" / "sheet.png"
OUT = ROOT / "Assets" / "Hatch"
COLS, ROWS = 6, 2
FUZZ = "25%"
# Room around her, in the animation's own pixels, once everything is scaled.
MARGIN_X, MARGIN_TOP, MARGIN_BOTTOM = 12, 12, 4


def run(args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def keyed(crop):
    return ["magick", str(SHEET), "-crop", crop, "+repage",
            "-fuzz", FUZZ, "-transparent", "magenta", "-alpha", "set"]


def blobs(crop):
    """Every drawn island in one cell: the subject, and any shell flying off it."""
    out = run(keyed(crop) + [
        "-alpha", "extract", "-threshold", "50%",
        "-define", "connected-components:verbose=true",
        "-define", "connected-components:area-threshold=120",
        "-connected-components", "8", "null:"])
    found = []
    for line in out.splitlines()[1:]:
        m = re.match(r"\s*\d+:\s+(\d+)x(\d+)\+(\d+)\+(\d+)\s+([\d.]+),([\d.]+)\s+([\d.e+]+)\s+(\S+)",
                     line)
        if not m:
            continue
        colour = m.group(8)
        if "255,255,255" not in colour and "gray(255)" not in colour:
            continue
        found.append(dict(w=int(m.group(1)), h=int(m.group(2)),
                          x=int(m.group(3)), y=int(m.group(4)),
                          cx=float(m.group(5)), area=float(m.group(7))))
    return found


def main():
    sheet_w, sheet_h = (int(v) for v in run(["magick", str(SHEET), "-format", "%w %h", "info:"]).split())
    cw, ch = sheet_w // COLS, sheet_h // ROWS

    frames = []
    for row in range(ROWS):
        for col in range(COLS):
            crop = f"{cw}x{ch}+{col * cw}+{row * ch}"
            islands = blobs(crop)
            if not islands:
                continue
            main_blob = max(islands, key=lambda b: b["area"])
            frames.append(dict(
                crop=crop,
                anchor_x=main_blob["cx"],
                ground=max(b["y"] + b["h"] for b in islands),
                left=min(b["x"] for b in islands),
                right=max(b["x"] + b["w"] for b in islands),
                top=min(b["y"] for b in islands),
                bird_h=main_blob["h"]))

    # Her idle sprite, as the app draws it, is the size the last frame has to reach.
    idle = run(["magick", str(ROOT / "Assets" / "Sprites" / "idle.png"),
                "-trim", "-format", "%w %h", "info:"]).split()
    target_h = int(idle[1])
    scale = target_h / frames[-1]["bird_h"]

    # One canvas for all twelve, big enough for the widest and tallest of them.
    left = min((f["left"] - f["anchor_x"]) * scale for f in frames)
    right = max((f["right"] - f["anchor_x"]) * scale for f in frames)
    top = min((f["top"] - f["ground"]) * scale for f in frames)
    width = int(right - left) + MARGIN_X * 2
    height = int(-top) + MARGIN_TOP + MARGIN_BOTTOM
    anchor = (MARGIN_X - left, height - MARGIN_BOTTOM)

    print(f"scala {scale:.4f} (ultimo frame {frames[-1]['bird_h']}px -> {target_h})")
    print(f"tela {width}x{height}, ancora a ({anchor[0]:.0f},{anchor[1]:.0f})")

    for i, f in enumerate(frames):
        # -extent's offset is the viewport origin in the scaled crop, so it is the
        # anchor minus where the anchor has to land.
        vx = f["anchor_x"] * scale - anchor[0]
        vy = f["ground"] * scale - anchor[1]
        run(keyed(f["crop"]) + [
            "-filter", "Box", "-resize", f"{scale * 100:.4f}%",
            "-background", "none", "-alpha", "set", "-gravity", "none",
            "-extent", f"{width}x{height}{vx:+.0f}{vy:+.0f}",
            "-alpha", "on", "-strip", f"PNG32:{OUT / f'hatch{i:02d}.png'}"])
    print(f"{len(frames)} frame scritti in Assets/Hatch/")


if __name__ == "__main__":
    main()
