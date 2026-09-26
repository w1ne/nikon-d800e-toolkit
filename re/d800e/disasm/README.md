# Reproducing the FR disassembly of the D800E B firmware

Nothing in this directory is committed except this README - the firmware dump and the
generated listings stay local.

## 1. Extract the decoded B firmware

```sh
cd ~/nikon-tools/re
python3 nikonfw.py extract firmware/d800e/F-D800E-V111M/D800EUpdate/D800E_0111.bin 1 \
        d800e/disasm/b63e111b.bin
```

(Result: `b63e111b.bin`, 14,811,136 bytes - block 1 of the container.)

## 2. Build the NikonHacker Java tools on macOS

```sh
brew install ant openjdk
export JAVA_HOME=/opt/homebrew/opt/openjdk
export PATH="$JAVA_HOME/bin:$PATH"
cd re/tools/nikon-firmware-tools/Java/Emulator     # cloned by patchcli/build.sh
ant -Djava-level=8 make-jar                        # builds ant_build/dist/jar/NikonEmulator.jar
```

## 3. Disassemble the bitrate dispatcher region

Address mapping for this firmware: `memory = file offset + 0x40000`.

```sh
"$JAVA_HOME/bin/java" \
  -cp "ant_build/dist/jar/NikonEmulator.jar:lib/commons-io-2.1.jar:lib/commons-lang3-3.1.jar:lib/xstream-1.4.2.jar:lib/jacksum.jar" \
  com.nikonhacker.disassembly.fr.Dfr \
  -i 0x40000-0x4E2000=0 \
  -m 0x61A00-0x62200=CODE \
  -o ~/nikon-tools/re/d800e/disasm/region_mem.asm \
  ~/nikon-tools/re/d800e/disasm/b63e111b.bin
```

`-i` maps firmware memory to file offsets; `-m` marks the range to force-disassemble.
Add more `-m` ranges as needed. The dispatcher's tables live at memory 0xCD960-0xCDA20
(file 0x8D960).

Passing many `-m` options on the command line trips Dfr's option parser; write them to
an options file and use `-x` instead. The `opts_*.txt` files in this directory are the
exact option files for the round-2 listings (`callers.asm`, `settings_writers.asm`,
`helpers.asm`, `mode_cases.asm`, `api2964*.asm`, `consts2.asm`), e.g.:

```sh
"$JAVA_HOME/bin/java" -cp "ant_build/dist/jar/NikonEmulator.jar:lib/commons-io-2.1.jar:lib/commons-lang3-3.1.jar:lib/xstream-1.4.2.jar:lib/jacksum.jar" \
  com.nikonhacker.disassembly.fr.Dfr -x opts_ma.txt b63e111b.bin
```

To resolve the small 7-entry jump tables and the UI strings, byte-level inspection of
the `.bin` with a short Python script is faster than more disassembly; see the round-2
section of `../DISASM-FINDINGS.md` for the exact tables/addresses.

## Notes

- `Dfr` usage: run it with no arguments.
- The numbering in the listing only shows addresses at branch targets; the record
  handlers listed in `../DISASM-FINDINGS.md` are memory addresses of branch targets.
- Other tools useful here: `startEmulator.sh` (full FR emulator), `startDtx.sh`
  (Toshiba TX19A disassembler for the other CPUs in the body).
