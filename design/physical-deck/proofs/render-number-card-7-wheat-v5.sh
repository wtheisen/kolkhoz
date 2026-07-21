#!/bin/sh
set -eu

proof_dir="design/physical-deck/proofs"
frame="$proof_dir/front-frame-v3.png"
suit="app/assets/art/field_plan/cards/suits/suit-wheat.png"
output="$proof_dir/number-card-7-wheat-v5.png"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

magick "$suit" -resize 340x340 "$work_dir/pip.png"
magick "$work_dir/pip.png" -rotate 180 "$work_dir/pip-inverted.png"
magick "$suit" -resize 150x150 "$work_dir/index-suit.png"

# Custom woodblock seven: broad square cap and a blunt diagonal stroke.
# Drawing it directly avoids importing a modern typeface into the Field Plan style.
magick -size 240x410 xc:none \
  -fill '#263025' \
  -draw 'polygon 20,18 220,18 210,70 10,70' \
  -draw 'polygon 148,62 210,62 94,240 34,240' \
  "$work_dir/index-suit.png" -gravity north -geometry +0+244 -composite \
  "$work_dir/index.png"
magick "$work_dir/index.png" -rotate 180 "$work_dir/index-inverted.png"

magick "$frame" \
  "$work_dir/index.png" -geometry +240+260 -composite \
  "$work_dir/pip.png" -geometry +470+400 -composite \
  "$work_dir/pip.png" -geometry +834+400 -composite \
  "$work_dir/pip.png" -geometry +652+680 -composite \
  "$work_dir/pip.png" -geometry +470+960 -composite \
  "$work_dir/pip.png" -geometry +834+960 -composite \
  "$work_dir/pip-inverted.png" -geometry +470+1420 -composite \
  "$work_dir/pip-inverted.png" -geometry +834+1420 -composite \
  "$work_dir/index-inverted.png" -geometry +1164+1574 -composite \
  "$output"
