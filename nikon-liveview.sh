#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GP="$DIR/gp"

if ! command -v ffmpeg >/dev/null || ! command -v ffplay >/dev/null; then
  echo "ffmpeg/ffplay not found - install with: brew install ffmpeg" >&2
  exit 1
fi

if [ "${1:-}" = "--record" ]; then
  secs="${2:?usage: nikon-liveview.sh --record <seconds> <outfile.mp4>}"
  out="${3:?usage: nikon-liveview.sh --record <seconds> <outfile.mp4>}"
  echo "recording ${secs}s of live view -> $out"
  "$GP" --capture-movie --stdout 2>/dev/null | ffmpeg -y -loglevel error -i - -t "$secs" -c:v libx264 -preset veryfast -pix_fmt yuv420p "$out" || true
  if [ -s "$out" ]; then
    echo "saved: $(ls -la "$out" | awk '{print $5" bytes"}')"
  else
    echo "recording failed" >&2
    exit 1
  fi
else
  echo "streaming live view, press q to quit (use --record <secs> <out.mp4> to save)"
  "$GP" --capture-movie --stdout 2>/dev/null | ffplay -loglevel error -i - -window_title "Nikon D800E LiveView" -x 960 -y 638
fi
