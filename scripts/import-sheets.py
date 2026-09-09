#!/usr/bin/env python3
"""Import Coco's redrawn animation sheets into Assets/Sprites/.

The sheets arrive as large generated PNGs on a magenta field, one folder per state,
each holding a plain and a hatted version. The hat is DRAWN INTO the art now, which is
why nothing is stamped on at runtime any more.

Three things make this more than a resize.

**The sheets are drawn at different scales.** Measured on import, the perched bird is
412 px tall in `idle`, 342 in `blink` and about 237 in `pecked` — nearly 1.9x between
the extremes. Fitting each frame to the canvas would make Coco change size the moment
she started eating, so every sheet is normalised by the bird's STANDING height, taken
as the tallest frame in that sheet, which is always a head-up one.

**A hat is not extra bird.** Normalising the hatted sheets the same way would shrink the
bird under the hat — `idle` measures 412 px tall and `idle_hat` 526, and the difference
is the hat. Width is very nearly hat-invariant (535 against 535), so a hatted sheet is
matched to its plain twin by the width of the SAME frame.

**Frames must register against each other.** The anchor is the TAIL TIP and the GROUND
LINE — the blob's left edge and its bottom. Feet were tried first and are worse than
they sound: with her head down at the ground the lowest pixels ARE the head, so a
"bottom slice" heuristic tracked the beak and reported the anchor swinging 165 px
through the peck cycle. The tail moves 7.

    scripts/import-sheets.py [source-dir]        # default ~/Desktop
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets" / "Sprites"
CANVAS_W = 112
CANVAS_H = 88
# The bird standing, in canvas pixels. The old perched sprites were 48 tall in a 64
# canvas, and matching that keeps her the size she already was on screen.
STAND_H = 48
FUZZ = "25%"
PAD = 40        # source px kept around each bird, so loose seeds travel with the frame

SHEETS = {
    "idle":   dict(rows=1, anchor="perch", names=["idle"]),
    "sad":    dict(rows=1, anchor="perch", names=["sad"]),
    "blink":  dict(rows=2, anchor="perch", names=[f"blink_{i}" for i in range(4)]),
    "petted": dict(rows=2, anchor="perch", names=[f"petted_{i}" for i in range(4)]),
    "fly":    dict(rows=2, anchor="air",   names=[f"fly_{i}" for i in range(4)]),
    "pecked": dict(rows=2, anchor="perch", names=[f"peck_{i}" for i in range(8)]),
}


def run(args):
    return subprocess.run(args, capture_output=True, text=True, check=True).stdout


def keyed(path):
    return ["magick", str(path), "-fuzz", FUZZ, "-transparent", "magenta", "-alpha", "set"]


def birds(path, rows):
    """Every bird on the sheet, in reading order.

    Found by connected components over the whole sheet rather than by slicing a grid:
    the drawn cells are not evenly spaced, and cutting on assumed boundaries sheared
    the tail off frames that sat flush against one.
    """
    out = run(keyed(path) + [
        "-alpha", "extract", "-threshold", "50%",
        "-define", "connected-components:verbose=true",
        "-define", "connected-components:area-threshold=400",
        "-connected-components", "8", "null:"])
    found = []
    for line in out.splitlines()[1:]:
        m = re.match(r"\s*\d+:\s+(\d+)x(\d+)\+(\d+)\+(\d+)\s+([\d.]+),([\d.]+)\s+([\d.e+]+)\s+(\S+)",
                     line)
        if not m:
            continue
        w, h, x, y = (int(m.group(i)) for i in (1, 2, 3, 4))
        cx, cy, area, colour = float(m.group(5)), float(m.group(6)), float(m.group(7)), m.group(8)
        if "255,255,255" not in colour and "gray(255)" not in colour:
            continue                                  # the empty field, not the art
        found.append(dict(w=w, h=h, x=x, y=y, cx=cx, cy=cy, area=area))
    if not found:
        return []
    # Birds are all much of a size; seeds and motion ticks are an order smaller.
    biggest = max(f["area"] for f in found)
    found = [f for f in found if f["area"] > biggest * 0.25]
    height = max(f["y"] + f["h"] for f in found)
    band = height / rows
    found.sort(key=lambda f: (int(f["cy"] // band), f["cx"]))
    return found


def head_metrics(path):
    """(cheek centre, head area) of a rendered frame, or None.

    The periwinkle cheek dot marks the head in any pose, and the bright yellow within
    reach of it is the face — measured with a radius so the yellow-green on her body
    does not join in and make a perched head look three times the size of a flying one.
    """
    out = run(["magick", str(path), "-depth", "8", "txt:-"])
    px = {}
    for line in out.splitlines()[1:]:
        m = re.match(r"(\d+),(\d+): \([^)]*\)\s+#([0-9A-F]{8})", line)
        if m and int(m.group(3)[6:8], 16) > 127:
            px[(int(m.group(1)), int(m.group(2)))] = m.group(3)[:6]
    def rgb(h):
        return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    # The party hat is blue-and-white striped, so a plain "find the periwinkle" search
    # finds the HAT and reports her head up where the pom-pom is. A height threshold was
    # tried and cannot separate them — her cheek sits 32% of the way down and the hat
    # reaches 30% — so the blue is grouped into blobs and the LOWEST one wins. The cheek
    # is always below the hat, whatever the pose.
    blue = {q for q, c in px.items()
            if (lambda C: C[2] > 140 and C[2] - C[1] > 25 and C[0] < 160)(rgb(c))}
    if not blue:
        return None
    blobs, seen = [], set()
    for start in blue:
        if start in seen:
            continue
        group, stack = [], [start]
        while stack:
            q = stack.pop()
            if q in seen or q not in blue:
                continue
            seen.add(q)
            group.append(q)
            x, y = q
            stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1),
                      (x + 1, y + 1), (x - 1, y - 1), (x + 1, y - 1), (x - 1, y + 1)]
        blobs.append(group)
    cheek = max(blobs, key=lambda g: sum(y for _, y in g) / len(g))
    cx = sum(x for x, _ in cheek) / len(cheek)
    cy = sum(y for _, y in cheek) / len(cheek)
    face = [q for q, c in px.items()
            if (lambda C: C[0] > 200 and C[1] > 200 and C[2] < 110)(rgb(c))
            and abs(q[0] - cx) <= 11 and abs(q[1] - cy) <= 11]
    return (cx, cy), len(face)


PERCHED = None
AIR_K = {}


def main():
    global PERCHED
    source = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else Path.home() / "Desktop"
    for sheet, spec in SHEETS.items():
        plain = {}
        for suffix in ("", "_hat"):
            src = source / sheet / f"{sheet}{suffix}.png"
            if not src.exists():
                print(f"  missing: {src}")
                continue
            found = birds(src, spec["rows"])
            if not found:
                print(f"  {src.name}: nothing found")
                continue
            ref = max(range(len(found)), key=lambda i: found[i]["h"])
            if suffix == "":
                scale = STAND_H / found[ref]["h"]
                plain = dict(scale=scale, w=found[ref]["w"], index=ref)
                note = f"stand={found[ref]['h']}px"
            else:
                mate = found[plain["index"]] if plain and plain["index"] < len(found) else found[ref]
                scale = plain["scale"] * plain["w"] / mate["w"]
                note = f"width-matched on frame {plain['index']}"
            widest = max(f["w"] for f in found)
            tallest = max(f["h"] for f in found)
            if widest * scale > CANVAS_W:
                scale = CANVAS_W / widest
                note += f", shrunk to fit {widest}px"
            # One placement for the whole sheet, so frames cannot drift against each
            # other: the tail tip sits at a common left margin, the ground line at the
            # canvas floor.
            x0 = (CANVAS_W - widest * scale) / 2

            def emit(name, f, scale, target_x, target_y, ax, ay):
                cx0, cy0 = max(0, f["x"] - PAD), max(0, f["y"] - PAD)
                crop = f"{f['w'] + 2 * PAD}x{f['h'] + 2 * PAD}+{cx0}+{cy0}"
                # -extent's offset is the viewport origin in the scaled crop, so it is
                # the anchor minus where the anchor should land.
                vx = (ax - cx0) * scale - target_x
                vy = (ay - cy0) * scale - target_y
                run(keyed(src) + [
                    "-crop", crop, "+repage",
                    "-filter", "Box", "-resize", f"{scale * 100:.4f}%",
                    "-background", "none", "-alpha", "set", "-gravity", "none",
                    "-extent", f"{CANVAS_W}x{CANVAS_H}{vx:+.0f}{vy:+.0f}",
                    "-alpha", "on", f"PNG32:{OUT / (name + suffix + '.png')}"])
                return dict(cx0=cx0, cy0=cy0, vx=vx, vy=vy)

            placed = {}
            for name, f in zip(spec["names"], found):
                if spec["anchor"] == "perch":
                    # Tail tip to a common left margin, ground line to the floor.
                    ax, target_x = f["x"], x0
                    ay, target_y = f["y"] + f["h"], CANVAS_H - 1
                else:
                    # Provisional only; the calibration below replaces it.
                    ax, target_x = f["x"] + f["w"] / 2, CANVAS_W / 2
                    ay, target_y = f["y"] + f["h"] / 2, CANVAS_H / 2
                placed[name] = emit(name, f, scale, target_x, target_y, ax, ay)

            if spec["anchor"] == "air" and PERCHED:
                # Flight, calibrated against the perched poses rather than measured on
                # its own. Scaling a wingbeat by its bounding box makes her a smaller
                # bird in the air — the wings inflate the box, so the body shrinks to
                # fit — and centring each frame on its own box makes her bob up and
                # down as the wings change span. Both are fixed by working from the
                # HEAD: match its size, then pin it to where it sits when she is
                # perched, which is also what made take-off seamless in the old set.
                metrics = {}
                for name in spec["names"]:
                    m = head_metrics(OUT / f"{name}{suffix}.png")
                    if m:
                        metrics[name] = m
                if metrics:
                    if suffix == "" or AIR_K.get(sheet) is None:
                        mean_area = sum(a for _, a in metrics.values()) / len(metrics)
                        k = (PERCHED["area"] / mean_area) ** 0.5 if mean_area else 1.0
                        AIR_K[sheet] = k
                    else:
                        # The hat covers part of the yellow head, so the hatted frames
                        # measure smaller and would be scaled up to compensate — she
                        # would fly a size larger on her birthday. Inherit instead.
                        k = AIR_K[sheet]
                    scale *= k
                    for name, f in zip(spec["names"], found):
                        if name not in metrics:
                            continue
                        (rcx, rcy), _ = metrics[name]
                        prev = placed[name]
                        # Recover where the head is in the source, then re-place it.
                        src_cx = (rcx + prev["vx"]) / (scale / k) + prev["cx0"]
                        src_cy = (rcy + prev["vy"]) / (scale / k) + prev["cy0"]
                        emit(name, f, scale, PERCHED["cheek"][0], PERCHED["cheek"][1],
                             src_cx, src_cy)
                    note += f", head-matched to perched ({k:.3f}x)"

            if sheet == "idle" and suffix == "":
                m = head_metrics(OUT / "idle.png")
                if m:
                    PERCHED = dict(cheek=m[0], area=m[1])

            print(f"  {src.name}: {len(found)} frame(s), {note}, "
                  f"scale={scale:.4f}, box={widest}x{tallest}")


if __name__ == "__main__":
    main()
