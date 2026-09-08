#!/usr/bin/env bash
# Poses derived from the two base sprites by editing the face only.
#
# The generator gets the face wrong at this size and cannot hold registration between
# frames, so every pose that differs only in expression is edited here instead of
# generated. The body is then guaranteed pixel-identical across poses — Coco cannot
# twitch when her mood changes.
#
# Every pose here is the SIDE view. The front view was dropped: it was the one drawing
# that could not be mirrored, so it needed keeping in step with her design by hand, and
# on screen it read as a second bird rather than the same bird turning round. The
# sleeping pose used to be derived from it; she now sleeps side-on with her eyes shut,
# which is what the behaviour driver was already drawing anyway.
set -euo pipefail
cd "$(dirname "$0")/.."
Y='#E8CF3F'   # face yellow
D='#1B2E14'   # outline

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

# --- Petting: a squeeze that ramps, rather than one frozen pose -------------------
#
# Petting used to be `petted.png` held still for 1.2 seconds. At 48x48 the states the
# eye can actually hold are few — open, flat shut, squeezed, drooping — and they are
# only four pixels each, so a "half closed" frame drawn between open and squeezed is
# indistinguishable from `blink`. The animation is therefore built from a RAMP of the
# states that do read differently, ending one row higher than `petted`: open, flat,
# squeezed, squeezed harder. Played back it is a bird scrunching her eyes shut in
# pleasure rather than a bird wearing an expression.
#
# Deep squeeze: the same V as `petted`, lifted a row. The cheek patch is deliberately
# left where it is. Raising it to follow the eye was tried first — a real squeeze does
# push the cheek up — but at this size the three violet pixels stop reading as a round
# patch and become a vertical bar down the face, which is worse than the anatomy is
# right.
magick Assets/Sprites/idle.png -alpha on \
  -fill "$Y" -draw "rectangle 33,6 36,9" \
  -fill "$D" -draw "point 33,6" -draw "point 36,6" -draw "point 34,7" -draw "point 35,7" \
  PNG32:Assets/Sprites/petted_deep.png
echo "Assets/Sprites/petted_deep.png"
