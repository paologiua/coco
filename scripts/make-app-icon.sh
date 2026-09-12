#!/usr/bin/env bash
# App icon: Coco on a rounded square, nearest-neighbour at every size.
set -euo pipefail
cd "$(dirname "$0")/.."
BG='#FFFFFF'          # white: she is a bright bird and carries the icon on her own
SPRITE=Assets/Sprites/idle.png
mkdir -p Assets/Icon
for N in 16 32 64 128 256 512 1024; do
  R=$((N/5))
  BIRD=$((N*72/100))
  # Trimmed first. The sprite sits on a 208x168 canvas with room over her head for a
  # party hat and under her feet for a wingtip, and fitting THAT to the icon made her
  # a third of the size the same script used to draw her.
  magick -size ${N}x${N} xc:none \
    -fill "$BG" -draw "roundrectangle 0,0 $((N-1)),$((N-1)) $R,$R" \
    \( "$SPRITE" -trim +repage -filter Point -resize ${BIRD}x${BIRD} \) \
    -gravity center -compose over -composite \
    "PNG32:Assets/Icon/icon_${N}.png"
done
echo "icone generate: $(ls Assets/Icon | tr '\n' ' ')"
