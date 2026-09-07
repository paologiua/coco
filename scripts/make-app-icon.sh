#!/usr/bin/env bash
# App icon: Coco on a rounded square, nearest-neighbour at every size.
set -euo pipefail
cd "$(dirname "$0")/.."
BG='#8FB6D9'          # the cere blue from the locked palette; green reads well on it
SPRITE=Assets/Sprites/idle.png
mkdir -p Assets/Icon
for N in 16 32 64 128 256 512 1024; do
  R=$((N/5))
  BIRD=$((N*72/100))
  magick -size ${N}x${N} xc:none \
    -fill "$BG" -draw "roundrectangle 0,0 $((N-1)),$((N-1)) $R,$R" \
    \( "$SPRITE" -filter Point -resize ${BIRD}x${BIRD} \) \
    -gravity center -compose over -composite \
    "PNG32:Assets/Icon/icon_${N}.png"
done
echo "icone generate: $(ls Assets/Icon | tr '\n' ' ')"
