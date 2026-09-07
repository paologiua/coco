#!/usr/bin/env bash
# Poses derived from the two base sprites by editing the face only.
#
# The generator gets the face wrong at this size and cannot hold registration between
# frames, so every pose that differs only in expression is edited here instead of
# generated. The body is then guaranteed pixel-identical across poses — Coco cannot
# twitch when her mood changes.
set -euo pipefail
cd "$(dirname "$0")/.."
Y='#E8CF3F'   # face yellow
D='#1B2E14'   # outline

# Sleeping: the front pose with both eyes closed. Front-facing has no direction, which
# is why it is the sleeping pose — a bird asleep should not be pointing anywhere.
magick Assets/Sprites/front.png -alpha on \
  -fill "$Y" -draw "rectangle 17,10 19,12" -draw "rectangle 27,10 29,12" \
  -fill "$D" -draw "line 17,11 19,11" -draw "line 27,11 29,11" \
  PNG32:Assets/Sprites/sleep.png
echo "Assets/Sprites/sleep.png"

# Sad: the side pose with a lid slanting down towards the beak — a drooping eye, not
# merely a shut one, and crucially NOT the flat horizontal line, which is what `blink`
# already is. A curved arc was tried first and read as "eyes closed"; an X was tried
# and read as "fainted", which contradicts a bird who never sickens or dies —
# plus a tear falling from the front corner of the eye. The lid alone read as "eyes
# closed" rather than "sad". The tear runs three pixels down the cheek with a white
# pixel at its head: two pixels of pale blue alone merged with the cere, which sits
# right beside it and is the same colour.
TEAR='#8FB6D9'
magick Assets/Sprites/idle.png -alpha on \
  -fill "$Y" -draw "rectangle 33,6 36,9" \
  -fill "$D" -draw "point 33,7" -draw "point 34,7" -draw "point 35,8" -draw "point 36,8" \
  -fill '#FFFFFF' -draw "point 36,9" \
  -fill "$TEAR" -draw "point 36,10" -draw "point 36,11" \
  PNG32:Assets/Sprites/sad.png
echo "Assets/Sprites/sad.png"

# Petted: eyes squeezed shut in pleasure — the same closed lid curved the other way.
magick Assets/Sprites/idle.png -alpha on \
  -fill "$Y" -draw "rectangle 33,6 36,9" \
  -fill "$D" -draw "point 33,7" -draw "point 34,8" -draw "point 35,8" -draw "point 36,7" \
  PNG32:Assets/Sprites/petted.png
echo "Assets/Sprites/petted.png"
