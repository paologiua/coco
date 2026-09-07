#!/usr/bin/env bash
# Clean one generated pixel-art frame into a true NxN sprite on the locked palette.
#
#   clean-sprite.sh <in.png> <out.png> <size> <WxH+X+Y crop> [palette.png]
#
# The crop is the bird's bounding box in the source. Pass the SAME crop size for
# every frame of an animation, or the frames will not register.
#
# Note: -remap drops the alpha channel, so RGB and alpha are handled separately
# and recombined at the end.
set -euo pipefail

IN=$1; OUT=$2; SIZE=$3; CROP=$4
PALETTE=${5:-$(dirname "$0")/../.scratch/coco-v1/art-raw/palette-nomagenta.png}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# 1. key out the magenta, crop to the bird, downscale by area average, pad to canvas
magick "$IN" \
  -fuzz 40% -transparent '#FF00FF' -alpha set \
  -crop "$CROP" +repage \
  -filter Box -resize "${SIZE}x${SIZE}" \
  -background none -gravity south -extent "${SIZE}x${SIZE}" \
  "PNG32:$TMP/rgba.png"

# 2. alpha mask, hard-thresholded: a pixel is either there or it isn't
magick "$TMP/rgba.png" -alpha extract -threshold 55% "$TMP/mask.png"

# 3. snap colours to the locked palette, with alpha off so remap can't eat it
magick "$TMP/rgba.png" -alpha off -dither None -remap "$PALETTE" "$TMP/rgb.png"

# 4. recombine
magick "$TMP/rgb.png" "$TMP/mask.png" -alpha off -compose CopyOpacity -composite "PNG32:$OUT"
