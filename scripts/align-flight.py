#!/usr/bin/env python3
"""Turn the generated flight sheet into four registered canvas frames.

The generator does not hold registration: the four birds differ in position and in
bounding box by over 100 source pixels. Aligning on the bounding box would make the
head lurch around while the wings flap — the opposite of what the eye forgives.

So each frame is aligned on the EYE HIGHLIGHT, the one pure-white cluster in the
palette, and placed so the eye lands exactly where the perched sprite's eye sits.
Coco's head then stays nailed in place through the whole wingbeat, and through
take-off from the perched pose.
"""
import re, subprocess

SRC = ".scratch/coco-v1/art-raw/fly-01.png"
QUAD = 627
SCALE = 48 / 502          # the scale the perched sprite was cleaned at
EYE = (44, 23)            # where the perched sprite's eye lands on the 64x64 canvas
PALETTE = ".scratch/coco-v1/art-raw/palette-nomagenta.png"

def eye_of(path, step=4):
    out = subprocess.run(["magick", path, "-filter", "Point", "-resize", f"{100//step}%",
                          "txt:-"], capture_output=True, text=True).stdout
    xs, ys = [], []
    for line in out.splitlines()[1:]:
        m = re.match(r"(\d+),(\d+): \((\d+),(\d+),(\d+)", line)
        if not m: continue
        x, y, r, g, b = map(int, m.groups())
        if r > 240 and g > 240 and b > 240:
            xs.append(x); ys.append(y)
    return (sum(xs) / len(xs) * step, sum(ys) / len(ys) * step)

for n in range(4):
    qx, qy = (n % 2) * QUAD, (n // 2) * QUAD
    quad = f"/tmp/fly_q{n}.png"
    subprocess.run(["magick", SRC, "-crop", f"{QUAD}x{QUAD}+{qx}+{qy}", "+repage", quad], check=True)

    ex, ey = eye_of(quad)
    dx, dy = round(EYE[0] - ex * SCALE), round(EYE[1] - ey * SCALE)

    out = f"Assets/Sprites/fly_{n}.png"
    subprocess.run([
        "magick", quad,
        "-fuzz", "30%", "-transparent", "#FF00FF", "-alpha", "set",
        "-filter", "Box", "-resize", f"{SCALE * 100:.4f}%",
        "PNG32:/tmp/fly_s.png"], check=True)
    # Composite onto the canvas rather than -extent: -extent moves the crop window,
    # so its offsets run backwards, which is how the first attempt scattered the heads.
    subprocess.run([
        "magick", "-size", "64x64", "xc:none",
        "/tmp/fly_s.png", "-geometry", f"{dx:+d}{dy:+d}", "-compose", "over", "-composite",
        "-channel", "A", "-threshold", "55%", "+channel",
        "PNG32:/tmp/fly_a.png"], check=True)
    # -remap drops alpha, so RGB and alpha are handled apart and recombined.
    subprocess.run(["magick", "/tmp/fly_a.png", "-alpha", "extract", "-threshold", "50%", "/tmp/fly_m.png"], check=True)
    subprocess.run(["magick", "/tmp/fly_a.png", "-alpha", "off", "-dither", "None",
                    "-remap", PALETTE, "/tmp/fly_r.png"], check=True)
    subprocess.run(["magick", "/tmp/fly_r.png", "/tmp/fly_m.png", "-alpha", "off",
                    "-compose", "CopyOpacity", "-composite", f"PNG32:{out}"], check=True)
    print(f"{out}  eye source ({ex:.0f},{ey:.0f}) -> canvas offset {dx:+d}{dy:+d}")
