#!/bin/bash
# Round-trip check: assemble test.asm, disassemble the result with the
# NikonHacker Dfr and print both listings side by side for comparison.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
EMU="$DIR/../nikon-firmware-tools/Java/Emulator"
TMP="${TMPDIR:-/tmp}/fr-asm-test"
mkdir -p "$TMP"

python3 "$DIR/frasm.py" "$DIR/test.asm" "$TMP/test.bin" --listing | tee "$TMP/asm.txt"

SIZE=$(wc -c < "$TMP/test.bin" | tr -d ' ')
END=$(printf '0x%x' $((0x40000 + SIZE)))
printf -- "-i 0x40000-0x4E2000=0\n-m 0x40000-%s=CODE\n-waddress\n-whexcode\n-o %s/dfr.asm\n" "$END" "$TMP" > "$TMP/opts.txt"

if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then J="$JAVA_HOME/bin/java"; else J=java; fi
"$J" -cp "$EMU/ant_build/dist/jar/NikonEmulator.jar:$EMU/lib/commons-io-2.1.jar:$EMU/lib/commons-lang3-3.1.jar:$EMU/lib/xstream-1.4.2.jar:$EMU/lib/jacksum.jar" \
  com.nikonhacker.disassembly.fr.Dfr -x "$TMP/opts.txt" "$TMP/test.bin" >/dev/null

echo
echo "=== Dfr re-disassembly ==="
grep -E "^[0-9A-F]{8} " "$TMP/dfr.asm" || cat "$TMP/dfr.txt"
