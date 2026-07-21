#!/bin/sh
set -eu

proof_dir="design/physical-deck/proofs"
frame="$proof_dir/front-frame-v3.png"
suit="app/assets/art/field_plan/cards/suits/suit-wheat.png"
font="app/assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf"
output="$proof_dir/number-card-7-wheat-v2.png"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

# These sizes are chosen for legibility on a 2.5 x 3.5 inch printed card.
magick "$suit" -resize 280x280 "$work_dir/pip.png"
magick "$work_dir/pip.png" -rotate 180 "$work_dir/pip-inverted.png"
magick "$suit" -resize 150x150 "$work_dir/index-suit.png"

# A large, tightly stacked index stays readable when held in a hand or on a table.
magick -size 240x410 xc:none \
  -font "$font" -pointsize 248 -fill '#263025' -gravity north \
  -annotate +0-2 '7' \
  "$work_dir/index-suit.png" -gravity north -geometry +0+244 -composite \
  "$work_dir/index.png"
magick "$work_dir/index.png" -rotate 180 "$work_dir/index-inverted.png"

# The seven symbols fill the field without entering either information corner.
magick "$frame" \
  "$work_dir/index.png" -geometry +190+210 -composite \
  "$work_dir/pip.png" -geometry +430+430 -composite \
  "$work_dir/pip.png" -geometry +934+430 -composite \
  "$work_dir/pip.png" -geometry +682+710 -composite \
  "$work_dir/pip.png" -geometry +430+990 -composite \
  "$work_dir/pip.png" -geometry +934+990 -composite \
  "$work_dir/pip-inverted.png" -geometry +430+1450 -composite \
  "$work_dir/pip-inverted.png" -geometry +934+1450 -composite \
  "$work_dir/index-inverted.png" -geometry +1214+1624 -composite \
  "$output"
