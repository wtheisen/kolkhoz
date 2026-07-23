#!/bin/sh
set -eu

proof_dir="design/physical-deck/proofs"
frame="$proof_dir/front-frame-v3.png"
suit="app/assets/art/field_plan/cards/suits/suit-wheat.png"
font="app/assets/art/field_plan/shared/fonts/PTSansNarrow-Bold.ttf"
output="$proof_dir/number-card-7-wheat-v3.png"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

magick "$suit" -resize 280x280 "$work_dir/pip.png"
magick "$work_dir/pip.png" -rotate 180 "$work_dir/pip-inverted.png"
magick "$suit" -resize 150x150 "$work_dir/index-suit.png"

magick -size 240x410 xc:none \
  -font "$font" -pointsize 248 -fill '#263025' -gravity north \
  -annotate +0-2 '7' \
  "$work_dir/index-suit.png" -gravity north -geometry +0+244 -composite \
  "$work_dir/index.png"
magick "$work_dir/index.png" -rotate 180 "$work_dir/index-inverted.png"

# Indices move 50 px inward on both axes. Pip columns move 70 px toward center.
magick "$frame" \
  "$work_dir/index.png" -geometry +240+260 -composite \
  "$work_dir/pip.png" -geometry +500+430 -composite \
  "$work_dir/pip.png" -geometry +864+430 -composite \
  "$work_dir/pip.png" -geometry +682+710 -composite \
  "$work_dir/pip.png" -geometry +500+990 -composite \
  "$work_dir/pip.png" -geometry +864+990 -composite \
  "$work_dir/pip-inverted.png" -geometry +500+1450 -composite \
  "$work_dir/pip-inverted.png" -geometry +864+1450 -composite \
  "$work_dir/index-inverted.png" -geometry +1164+1574 -composite \
  "$output"
