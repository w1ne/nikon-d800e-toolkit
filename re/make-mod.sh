#!/bin/bash
# One-command firmware mod: stock .bin -> patched, CRC-fixed, verified, flashable.
# See MODDING.md for the manual workflow and for the site map behind each patch id.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
NFPATCH="$DIR/patchcli/nfpatch"
FWTOOL="$DIR/nikonfw.py"
STOCK_MD5="1b033eb7795b13aa137a9170032ba2a7"

if [ $# -lt 3 ]; then
  echo "usage: make-mod.sh <stock D800E_0111.bin> <outdir> <patch_id> [patch_id...]" >&2
  echo "  patch ids (D800E 1.11):" >&2
  echo "    1-4  1080p: 36 / 54 / 64 Mbps, 64 Mbps + NQ 36" >&2
  echo "    5    720p60/50: HQ 64/60, NQ 24/20 Mbps" >&2
  echo "    6    720p30/25: HQ 24/20, NQ 12/10 Mbps" >&2
  exit 1
fi

stock="$1"; outdir="$2"; shift 2
[ -f "$stock" ] || { echo "error: no such file: $stock" >&2; exit 1; }
[ -x "$NFPATCH" ] || { echo "error: $NFPATCH missing - run re/patchcli/build.sh" >&2; exit 1; }
[ -f "$FWTOOL" ] || { echo "error: $FWTOOL missing" >&2; exit 1; }

md5="$(md5 -q "$stock" 2>/dev/null || md5sum "$stock" | cut -d' ' -f1)"
if [ "$md5" != "$STOCK_MD5" ]; then
  echo "warning: md5 $md5 != stock D800E 1.11 ($STOCK_MD5)" >&2
  printf "continue anyway? [y/N] " >&2
  read -r ans
  [ "${ans:-n}" = "y" ] || exit 1
fi

mkdir -p "$outdir"
out="$outdir/D800E_0111.bin"

echo "applying patch ids: $*"
"$NFPATCH" apply "$stock" "$out" "$@" >/dev/null

echo "verifying container CRCs..."
python3 "$FWTOOL" verify "$out"

sha="$( { shasum -a 256 "$out" 2>/dev/null || sha256sum "$out"; } | cut -d' ' -f1)"
echo
echo "flashable image : $out"
echo "sha256          : $sha"
echo "size            : $(wc -c < "$out" | tr -d ' ') bytes"
echo
echo "flash : copy to a camera-formatted card root, insert in slot 1,"
echo "        Setup menu -> Firmware version -> Update. Never power off mid-flash."
echo "revert: flash the untouched stock .bin the same way."
echo
echo "after flashing, verify with: ./nikon-check-bitrate.sh --from-camera <index>"
