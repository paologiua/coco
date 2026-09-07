#!/usr/bin/env bash
# Menubar mood icons, derived from the generated colour heads.
#
# Supplied at 44x44 (22 logical points doubled with nearest-neighbour) so a Retina
# menu bar shows crisp square pixels instead of a smoothed upscale. The app sets the
# NSImage size back to 22x22 points and leaves isTemplate false — these are colour
# icons and must not be recoloured by macOS.
#
# Replaces an earlier hand-drawn monochrome set. Those read more clearly at this size
# (the eye was a hole in a solid silhouette rather than two pixels among other dark
# pixels), but colour was chosen for character. See ticket 05.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC=.scratch/coco-v1/art-raw/moods-01.png
PALETTE=.scratch/coco-v1/art-raw/palette-nomagenta.png
Q=627
mkdir -p Assets/Menubar

# Quadrant -> mood, by the eye the generator drew in each.
place() {  # $1 mood, $2 quadrant index 0-3
  local x=$(( ($2 % 2) * Q )) y=$(( ($2 / 2) * Q ))
  magick "$SRC" -crop ${Q}x${Q}+$x+$y +repage \
    -fuzz 8% -transparent white -alpha set -background none -trim +repage \
    -filter Box -resize 22x22 -background none -gravity center -extent 22x22 \
    "PNG32:/tmp/mi.png"
  magick /tmp/mi.png -alpha extract -threshold 50% /tmp/mi_a.png
  magick /tmp/mi.png -alpha off -dither None -remap "$PALETTE" /tmp/mi_r.png
  magick /tmp/mi_r.png /tmp/mi_a.png -alpha off -compose CopyOpacity -composite \
    -filter Point -resize 200% "PNG32:Assets/Menubar/mood_$1.png"
  echo "mood_$1.png  <- quadrant $2"
}

place sad     0   # drooping arc
place content 1   # wide open round eye
place meh     2   # flat line
place happy   3   # upward smiling arc
