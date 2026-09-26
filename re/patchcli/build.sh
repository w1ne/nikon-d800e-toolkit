#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
UPSTREAM="${UPSTREAM:-$DIR/../tools/nikon-firmware-tools}"
DIFF="$DIR/../d800e_0111_patches.diff"
WORK="$DIR/.build"
UPSTREAM_COMMIT="de8019ee30db7fe7bc61e520da289078ae82dcaa"

if [ ! -d "$UPSTREAM/.git" ]; then
  git clone https://github.com/simeonpilgrim/nikon-firmware-tools.git "$UPSTREAM"
fi
if ! git -C "$UPSTREAM" checkout --quiet "$UPSTREAM_COMMIT" 2>/dev/null; then
  echo "warning: upstream commit $UPSTREAM_COMMIT not available, building against current HEAD" >&2
fi

SRC="$UPSTREAM/Nikon-Patch-JS/src/nikon_patch"
rm -rf "$WORK"
mkdir -p "$WORK/fake/emscripten"
cp "$SRC/nikon_patch.c" "$SRC/patches.c" "$SRC/patches.h" "$SRC/md5.c" "$SRC/md5.h" \
   "$SRC/md5driver.c" "$SRC/xor.c" "$SRC/xor.h" "$WORK/"

if ! patch "$WORK/patches.c" "$DIFF" >/dev/null; then
  echo "warning: patch did not apply cleanly - upstream may have changed; D800E 1.11 set may be missing" >&2
fi

printf '#define EMSCRIPTEN_KEEPALIVE\n' > "$WORK/fake/emscripten/emscripten.h"
clang -O2 -c "$WORK/nikon_patch.c" -Dmain=tool_main -I"$WORK/fake" -o "$WORK/nikon_patch.o"
clang -O2 -o "$DIR/nfpatch" "$DIR/main.c" "$WORK/nikon_patch.o" "$WORK/patches.c" \
   "$WORK/md5.c" "$WORK/md5driver.c" "$WORK/xor.c" -I"$WORK" -I"$WORK/fake"
echo "built: $DIR/nfpatch"
echo "usage: nfpatch list <firmware.bin> | nfpatch apply <firmware.bin> <out.bin> <patch_id...>"
