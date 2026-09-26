#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GP="$DIR/gp"

if [ "${1:-}" = "" ]; then
  echo "usage: nikon-focus-stack.sh <frames> <step> [outdir]" >&2
  echo "  step is relative focus drive units, use negative to rack the other way" >&2
  echo "  requires a CPU lens and works in Live View mode" >&2
  exit 1
fi

frames="$1"
step="${2:-10}"
outdir="${3:-focus_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$outdir"

echo "focus stack: $frames frames, step $step -> $outdir"
"$GP" --set-config /main/actions/viewfinder=1 >/dev/null 2>&1 || true

for ((i=1; i<=frames; i++)); do
  name=$(printf "focus_%02d.%%C" "$i")
  if "$GP" --capture-image-and-download --filename "$outdir/$name"; then
    printf "frame %d/%d ok\n" "$i" "$frames"
  else
    printf "frame %d/%d FAILED\n" "$i" "$frames" >&2
  fi
  if [ "$i" -lt "$frames" ]; then
    if ! "$GP" --set-config /main/actions/viewfinder=1 \
               --set-config "/main/actions/manualfocusdrive=$step" >/dev/null 2>&1; then
      echo "focus drive failed - CPU lens required and Live View must be possible" >&2
      break
    fi
  fi
done

"$GP" --set-config /main/actions/viewfinder=0 >/dev/null 2>&1 || true
echo "done: $(ls -1 "$outdir" | wc -l | tr -d ' ') frames in $outdir"
