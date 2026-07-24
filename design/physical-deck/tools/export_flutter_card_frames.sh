#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
source_dir="$repo_root/design/physical-deck/proofs/generated-borders"
output_dir="$repo_root/app/assets/art/field_plan/cards/frames"
mkdir -p "$output_dir"

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kolkhoz-card-frames.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

magick -size 1644x2244 xc:black -fill white -stroke none \
  -draw "path 'M970 116 H1440 L1492 168 V752 C1460 615 1370 492 1210 366 C1145 315 1112 282 1107 224 C1102 160 1055 116 970 116 Z'" \
  "$work_dir/upper-mask.png"
magick -size 1644x2244 xc:black -fill white -stroke none \
  -draw "path 'M674 2128 H204 L152 2076 V1492 C184 1629 274 1752 434 1878 C499 1929 532 1962 537 2020 C542 2084 589 2128 674 2128 Z'" \
  "$work_dir/lower-mask.png"
draw_frame() {
  magick "$1" \
    -fill none -stroke '#33434a' -strokewidth 15 -draw "path 'M176 88 H1460 L1520 148 V2096 L1460 2156 H184 L124 2096 V148 Z'" \
    -strokewidth 9 -draw "path 'M204 116 H1440 L1492 168 V2076 L1440 2128 H204 L152 2076 V168 Z'" \
    -draw "path 'M970 116 C1055 116 1102 160 1107 224 C1112 282 1145 315 1210 366 C1370 492 1460 615 1492 752'" \
    -draw "path 'M674 2128 C589 2128 542 2084 537 2020 C532 1962 499 1929 434 1878 C274 1752 184 1629 152 1492'" \
    -resize 822x1122 "$2"
}

draw_dark_frame() {
  magick "$1" \
    -fuzz 2% -fill '#171b1a' \
    -draw 'color 400,500 floodfill' \
    -draw 'color 0,0 floodfill' \
    -draw 'color 100,50 floodfill' \
    -fuzz 0% -fill '#F5D19A' -opaque '#33434a' \
    -strip -depth 8 "$2"
}

for suit in wheat sunflower potato beet; do
  case "$suit" in
    wheat) plate="$source_dir/wheat-artwork-plate-v5-mpc.png" ;;
    sunflower) plate="$source_dir/sunflower-artwork-plate-v4-mpc.png" ;;
    potato) plate="$source_dir/potato-artwork-plate-v4-mpc.png" ;;
    beet) plate="$source_dir/beet-artwork-plate-v4-mpc.png" ;;
  esac
  magick "$plate" -alpha extract "$work_dir/source-alpha.png"
  magick "$work_dir/source-alpha.png" "$work_dir/upper-mask.png" \
    -compose Multiply -composite "$work_dir/upper-opacity.png"
  magick "$plate" "$work_dir/upper-opacity.png" -compose CopyOpacity \
    -composite "$work_dir/upper.png"
  magick -size 1644x2244 xc:none "$plate" -geometry +58+0 -compose over \
    -composite "$work_dir/lower-source.png"
  magick "$work_dir/lower-source.png" -alpha extract "$work_dir/source-alpha.png"
  magick "$work_dir/source-alpha.png" "$work_dir/lower-mask.png" \
    -compose Multiply -composite "$work_dir/lower-opacity.png"
  magick "$work_dir/lower-source.png" "$work_dir/lower-opacity.png" \
    -compose CopyOpacity -composite "$work_dir/lower.png"
  magick -size 1644x2244 xc:'#F5D19A' "$work_dir/upper.png" -compose over \
    -composite "$work_dir/lower.png" -compose over -composite \
    "$work_dir/$suit.png"
  draw_frame "$work_dir/$suit.png" "$output_dir/card-frame-$suit.png"
  draw_dark_frame \
    "$output_dir/card-frame-$suit.png" \
    "$output_dir/card-frame-$suit-dark.png"
done

trump_tile="$source_dir/trump-inset-tile-v2-flat-red.png"
trump_tile_rotated="$source_dir/trump-inset-tile-v2-flat-red-rotated.png"
magick -size 1644x2244 xc:none \( "$trump_tile" -resize 900x900! \) \
  -geometry +699-67 -compose over -composite "$work_dir/trump-upper-source.png"
magick "$work_dir/trump-upper-source.png" -alpha extract \
  "$work_dir/source-alpha.png"
magick "$work_dir/source-alpha.png" "$work_dir/upper-mask.png" \
  -compose Multiply -composite "$work_dir/upper-opacity.png"
magick "$work_dir/trump-upper-source.png" "$work_dir/upper-opacity.png" \
  -compose CopyOpacity -composite "$work_dir/upper.png"
magick -size 1644x2244 xc:none \( "$trump_tile_rotated" -resize 900x900! \) \
  -geometry +45+1411 -compose over -composite "$work_dir/trump-lower-source.png"
magick "$work_dir/trump-lower-source.png" -alpha extract \
  "$work_dir/source-alpha.png"
magick "$work_dir/source-alpha.png" "$work_dir/lower-mask.png" \
  -compose Multiply -composite "$work_dir/lower-opacity.png"
magick "$work_dir/trump-lower-source.png" "$work_dir/lower-opacity.png" \
  -compose CopyOpacity -composite "$work_dir/lower.png"
magick -size 1644x2244 xc:'#F5D19A' "$work_dir/upper.png" -compose over \
  -composite "$work_dir/lower.png" -compose over -composite \
  "$work_dir/trump.png"
draw_frame "$work_dir/trump.png" "$output_dir/card-frame-trump.png"
draw_dark_frame \
  "$output_dir/card-frame-trump.png" \
  "$output_dir/card-frame-trump-dark.png"
