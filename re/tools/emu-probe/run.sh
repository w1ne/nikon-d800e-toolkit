#!/bin/bash
# Headless FR emulator probe for the D800E B firmware.
# usage: run.sh <b63e111b.bin> [fn_address] [g rec q]...
#   (no case args -> stock matrix self-test)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
EMU="$DIR/../nikon-firmware-tools/Java/Emulator"
JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk}"
CP="$EMU/ant_build/dist/jar/NikonEmulator.jar:$(ls "$EMU"/lib/*.jar | tr '\n' ':')"
BUILD="${TMPDIR:-/tmp}/emu-probe-build"
mkdir -p "$BUILD"
if [ ! -f "$EMU/ant_build/dist/jar/NikonEmulator.jar" ]; then
  echo "error: build the emulator jar first (see d800e/disasm/README.md step 2)" >&2
  exit 1
fi
"$JAVA_HOME/bin/javac" -cp "$CP" -d "$BUILD" "$DIR/D800Probe.java"
exec "$JAVA_HOME/bin/java" -cp "$CP:$BUILD" D800Probe "$@"
