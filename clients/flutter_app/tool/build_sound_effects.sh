#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
output="$root/assets/audio"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

download() {
  curl -L --fail --silent --show-error "$2" -o "$work/$1.mp3"
}

download card https://cdn.freesound.org/previews/108/108395_1817800-hq.mp3
download scythe https://cdn.freesound.org/previews/251/251660_4451798-hq.mp3
download shovel https://cdn.freesound.org/previews/415/415303_7919598-hq.mp3
download potatoes https://cdn.freesound.org/previews/288/288927_34567-hq.mp3
download crate https://cdn.freesound.org/previews/667/667655_3271378-hq.mp3
download stamp https://cdn.freesound.org/previews/362/362624_3165091-hq.mp3
download metal_clang https://cdn.freesound.org/previews/362/362625_3165091-hq.mp3
download metal_door https://cdn.freesound.org/previews/48/48980_120830-hq.mp3
download factory_whistle https://cdn.freesound.org/previews/477/477827_5583936-hq.mp3
download book_close https://cdn.freesound.org/previews/319/319809_3262745-hq.mp3

mkdir -p "$output"

ffmpeg -y -loglevel error -ss 3.54 -t 0.22 -i "$work/card.mp3" \
  -af 'afade=t=out:st=0.16:d=0.06' "$work/card_play.wav"

ffmpeg -y -loglevel error -ss 9.24 -t 0.42 -i "$work/card.mp3" \
  -t 0.65 -i "$work/metal_clang.mp3" -filter_complex \
  '[0:a]volume=1.1[card];[1:a]atrim=0:0.55,volume=0.42,adelay=180[medal];[card][medal]amix=inputs=2:duration=longest' \
  "$work/trick_win.wav"

ffmpeg -y -loglevel error -ss 8.82 -t 1.14 -i "$work/scythe.mp3" \
  -af 'atempo=1.65,afade=t=out:st=0.58:d=0.11' "$work/assignment_wheat.wav"

ffmpeg -y -loglevel error -ss 7.48 -t 0.90 -i "$work/scythe.mp3" \
  -i "$work/crate.mp3" -filter_complex \
  '[0:a]atempo=1.35,afade=t=out:st=0.55:d=0.11[cut];[1:a]volume=0.28,adelay=360[chop];[cut][chop]amix=inputs=2:duration=longest' \
  "$work/assignment_sunflower.wav"

ffmpeg -y -loglevel error -ss 0.52 -t 0.58 -i "$work/shovel.mp3" \
  -ss 5.10 -t 0.43 -i "$work/potatoes.mp3" -i "$work/crate.mp3" \
  -filter_complex \
  '[0:a]volume=0.9[dig];[1:a]volume=0.9,adelay=260[drop];[2:a]volume=0.32,adelay=470[crate];[dig][drop][crate]amix=inputs=3:duration=longest' \
  "$work/assignment_potato.wav"

ffmpeg -y -loglevel error -ss 1.92 -t 0.62 -i "$work/shovel.mp3" \
  -i "$work/crate.mp3" -filter_complex \
  '[0:a]volume=1.0[earth];[1:a]asetrate=35280,aresample=48000,volume=0.55,adelay=430[thump];[earth][thump]amix=inputs=2:duration=longest' \
  "$work/assignment_beet.wav"

ffmpeg -y -loglevel error -t 0.55 -i "$work/metal_clang.mp3" \
  -af 'highpass=f=500,volume=0.55,afade=t=out:st=0.40:d=0.15' \
  "$work/assignment_saboteur.wav"

ffmpeg -y -loglevel error -i "$work/stamp.mp3" -t 0.58 \
  "$work/assignment.wav"

ffmpeg -y -loglevel error -ss 0.02 -t 1.02 -i "$work/metal_door.mp3" \
  -af 'afade=t=out:st=0.88:d=0.14' "$work/requisition.wav"

ffmpeg -y -loglevel error -ss 0.73 -t 1.25 -i "$work/factory_whistle.mp3" \
  -af 'volume=0.72,afade=t=out:st=0.90:d=0.35' "$work/year_start.wav"

ffmpeg -y -loglevel error -i "$work/book_close.mp3" \
  -t 0.70 -i "$work/metal_clang.mp3" -filter_complex \
  '[0:a]volume=1.0[ledger];[1:a]asetrate=38400,aresample=48000,volume=0.38,adelay=230,afade=t=out:st=0.65:d=0.18[bell];[ledger][bell]amix=inputs=2:duration=longest' \
  "$work/game_over.wav"

for file in \
  card_play trick_win assignment assignment_wheat assignment_sunflower \
  assignment_potato assignment_beet assignment_saboteur requisition \
  year_start game_over; do
  ffmpeg -y -loglevel error -i "$work/$file.wav" -ac 1 -ar 48000 \
    -af 'loudnorm=I=-19:TP=-2:LRA=7' "$output/$file.wav"
done
