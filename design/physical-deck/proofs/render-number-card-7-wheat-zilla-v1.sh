#!/bin/sh
set -eu

proof_dir="design/physical-deck/proofs"
preview_dir="$proof_dir/ql-zilla-card"
source="$proof_dir/number-card-7-wheat-zilla-v1.svg"
output="$proof_dir/number-card-7-wheat-zilla-v1.png"

mkdir -p "$preview_dir"
qlmanage -t -s 2244 -o "$preview_dir" "$source" >/dev/null 2>&1
magick "$preview_dir/number-card-7-wheat-zilla-v1.svg.png" \
  -crop 1644x2244+300+0 +repage -strip "$output"
