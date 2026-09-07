#!/usr/bin/env bash
# Compose the party hat onto a 48x64 canvas, once per pose family.
#
# This IS the per-frame anchor table from ticket 05, baked into assets rather than
# carried as numbers in code: the head sits in a different place in the side and
# front poses, so each gets its own pre-positioned hat layer. Regenerate all of them
# whenever the hat drawing changes.
set -euo pipefail
cd "$(dirname "$0")/.."
HAT=Assets/hat-source.png

place() {  # $1 = output name, $2 = x, $3 = y
  magick -size 64x64 xc:none "$HAT" -geometry "+$2+$3" -compose over -composite \
    "PNG32:Assets/Sprites/hat_$1.png"
  echo "Assets/Sprites/hat_$1.png  at +$2+$3"
}

place side  35 0     # side pose: crown at canvas y=16, head centred near x=42
place front 25 0     # front pose: crown at canvas y=16, head centred near x=32
