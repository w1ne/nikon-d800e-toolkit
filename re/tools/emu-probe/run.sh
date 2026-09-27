#!/bin/bash
# Headless FR emulator probe for the D800E B firmware.
# usage: run.sh <b63e111b.bin> [fn_address] [g rec q]...
#   (no case args -> stock matrix self-test)
#
# Requires: a Java 8+ JDK (javac on PATH or JAVA_HOME set) and the emulator jar
# built as described in re/d800e/disasm/README.md step 2.
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
EMU="$DIR/../nikon-firmware-tools/Java/Emulator"

if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/javac" ]; then
  JAVAC="$JAVA_HOME/bin/javac"; JAVA="$JAVA_HOME/bin/java"
else
  JAVAC="$(command -v javac || true)"
  JAVA="$(command -v java || true)"
fi
if [ -z "$JAVAC" ] || [ -z "$JAVA" ]; then
  echo "error: javac/java not found - install a JDK and/or set JAVA_HOME" >&2
  exit 1
fi

CP="$EMU/ant_build/dist/jar/NikonEmulator.jar:$(ls "$EMU"/lib/*.jar | tr '\n' ':')"
BUILD="${TMPDIR:-/tmp}/emu-probe-build"
mkdir -p "$BUILD"
if [ ! -f "$EMU/ant_build/dist/jar/NikonEmulator.jar" ]; then
  echo "error: build the emulator jar first (see d800e/disasm/README.md step 2)" >&2
  exit 1
fi
"$JAVAC" -cp "$CP" -d "$BUILD" "$DIR/D800Probe.java"
exec "$JAVA" -cp "$CP:$BUILD" D800Probe "$@"
