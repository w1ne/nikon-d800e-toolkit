#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GP="$DIR/gp"

echo "== camera =="
for k in cameramodel deviceversion batterylevel lensname availableshots; do
  v="$("$GP" --get-config "/main/status/$k" 2>/dev/null | sed -n 's/^Current: //p' || true)"
  printf "%-14s %s\n" "$k" "$v"
done

echo "== settings =="
for p in capturesettings/expprogram capturesettings/shutterspeed capturesettings/f-number capturesettings/exposurecompensation capturesettings/rawcompression capturesettings/imagequality imgsettings/iso imgsettings/whitebalance; do
  v="$("$GP" --get-config "/main/$p" 2>/dev/null | sed -n 's/^Current: //p' || true)"
  printf "%-14s %s\n" "$(basename "$p")" "$v"
done
