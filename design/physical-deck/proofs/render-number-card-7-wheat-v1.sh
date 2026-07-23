#!/bin/sh
set -eu

proof_dir="design/physical-deck/proofs"
frame="$proof_dir/front-frame-v3.png"
suit="app/assets/art/field_plan/cards/suits/suit-wheat.png"
font="app/assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf"
output="$proof_dir/number-card-7-wheat-v1.png"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# Build the two reusable marks independently so rotation cannot disturb placement.
magick "$suit" -resize 220x220 "$work_dir/pip.png"
magick "$work_dir/pip.png" -rotate 180 "$work_dir/pip-inverted.png"
magick "$suit" -resize 100x100 "$work_dir/index-suit.png"

# The complete corner index rotates as one unit for an exact lower-right partner.
magick -size 180x300 xc:none \
  -font "$font" -pointsize 172 -fill '#263025' -gravity north \
  -annotate +0+12 '7' \
  "$work_dir/index-suit.png" -gravity north -geometry +0+172 -composite \
  "$work_dir/index.png"
magick "$work_dir/index.png" -rotate 180 "$work_dir/index-inverted.png"

# Seven-pip layout: four marks above the midpoint and three below it.
magick "$frame" \
  "$work_dir/index.png" -geometry +190+210 -composite \
  "$work_dir/pip.png" -geometry +420+480 -composite \
  "$work_dir/pip.png" -geometry +1004+480 -composite \
  "$work_dir/pip.png" -geometry +712+742 -composite \
  "$work_dir/pip.png" -geometry +420+1012 -composite \
  "$work_dir/pip.png" -geometry +1004+1012 -composite \
  "$work_dir/pip-inverted.png" -geometry +420+1534 -composite \
  "$work_dir/pip-inverted.png" -geometry +1004+1534 -composite \
  "$work_dir/index-inverted.png" -geometry +1274+1734 -composite \
  "$output"
