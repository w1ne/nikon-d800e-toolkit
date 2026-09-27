#!/bin/bash
# Measure the real bitrate of a recorded clip - local file or pulled from the
# camera over USB - to confirm that a firmware bitrate patch actually took.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GP="$DIR/gp"

usage() {
  echo "usage: nikon-check-bitrate.sh <file.MOV|file.MP4>" >&2
  echo "       nikon-check-bitrate.sh --from-camera <file_index>" >&2
  echo "  list camera files: ./gp --list-files | head -40" >&2
  exit 1
}
[ $# -ge 1 ] || usage

cleanup=""
if [ "$1" = "--from-camera" ]; then
  idx="${2:-}"
  [ -n "$idx" ] || usage
  tmpdir="$(mktemp -d)"
  cleanup="$tmpdir"
  echo "downloading file #$idx from camera..."
  ( cd "$tmpdir" && "$GP" --get-file "$idx" )
  name="$(ls -t "$tmpdir" | head -1)"
  [ -n "$name" ] || { echo "error: nothing downloaded" >&2; exit 1; }
  file="$tmpdir/$name"
else
  file="$1"
fi
[ -f "$file" ] || { echo "error: no such file: $file" >&2; exit 1; }

command -v ffprobe >/dev/null 2>&1 || { echo "error: ffprobe not found (brew install ffmpeg)" >&2; exit 1; }

dur="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$file" || true)"
[ -n "$dur" ] || { echo "error: cannot read duration - is it a movie?" >&2; exit 1; }
size="$(wc -c < "$file" | tr -d ' ')"

mbps="$(python3 -c "print(f'{($size*8)/($dur*1e6):.1f}')")"

echo
echo "file     : $file"
echo "size     : $size bytes"
echo "duration : ${dur}s"
echo "bitrate  : ${mbps} Mbps  (size x 8 / duration)"
echo
cat <<'REF'
nameplate reference (measured is usually 5-15% below):
                    1080p             720p60/50        720p30/25
  stock  HQ        24 Mbps           24 Mbps          12 Mbps
         NQ        12 Mbps           12 Mbps           6 Mbps
  mod    HQ        64 Mbps           64 Mbps          24 Mbps
         NQ        24 Mbps           24 Mbps          12 Mbps
REF

if [ -n "$cleanup" ]; then
  rm -rf "$cleanup"
fi
