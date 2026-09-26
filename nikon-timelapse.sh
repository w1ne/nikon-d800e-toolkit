#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GP="$DIR/gp"

if [ "${1:-}" = "" ] || [ "${2:-}" = "" ]; then
  echo "usage: nikon-timelapse.sh <shots> <interval_seconds> [outdir] [extra gphoto2 args...]" >&2
  exit 1
fi

shots="$1"
interval="$2"
outdir="${3:-tl_$(date +%Y%m%d_%H%M%S)}"
shift $(( $# > 3 ? 3 : $# ))
mkdir -p "$outdir"

echo "timelapse: $shots frames, ${interval}s interval -> $outdir"
for ((i=1; i<=shots; i++)); do
  name=$(printf "frame_%04d.%%C" "$i")
  if "$GP" --capture-image-and-download --filename "$outdir/$name" "$@"; then
    printf "frame %d/%d ok\n" "$i" "$shots"
  else
    printf "frame %d/%d FAILED\n" "$i" "$shots" >&2
  fi
  if [ "$i" -lt "$shots" ]; then sleep "$interval"; fi
done
echo "done: $(ls -1 "$outdir" | wc -l | tr -d ' ') files in $outdir"
