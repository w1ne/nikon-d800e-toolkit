#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GP="$DIR/gp"

outdir="${1:-bracket_$(date +%Y%m%d_%H%M%S)}"
shift || true
levels=("$@")
if [ "${#levels[@]}" -eq 0 ]; then levels=(-2 -1 0 1 2); fi
mkdir -p "$outdir"

"$GP" --set-config /main/capturesettings/exposurecompensation=15 >/dev/null
echo "bracketing ${levels[*]} EV -> $outdir"
for ev in "${levels[@]}"; do
  idx=$(awk "BEGIN{printf \"%d\", 15+($ev)*3}")
  "$GP" --set-config "/main/capturesettings/exposurecompensation=$idx" >/dev/null
  tag=$(echo "$ev" | tr -d '+' | tr '.' 'p')
  if "$GP" --capture-image-and-download --filename "$outdir/ev_${tag}EV.%C"; then
    printf "EV %-5s ok\n" "$ev"
  else
    printf "EV %-5s FAILED\n" "$ev" >&2
  fi
done
"$GP" --set-config /main/capturesettings/exposurecompensation=15 >/dev/null
echo "exposure compensation restored to 0"
