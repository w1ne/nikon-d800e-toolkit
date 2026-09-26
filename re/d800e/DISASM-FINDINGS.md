# D800E 1.11 B-firmware: the bitrate dispatcher, disassembled

Status: code-level analysis of the region that carries the 1.11 bitrate patches, plus
the movie-mode enumeration and the encode-module control block that feed it.
Tool: the NikonHacker Java emulator suite (`com.nikonhacker.disassembly.fr.Dfr`), built
natively on macOS. See `disasm/README.md` for reproduction.

**Update (round 2)**: dispatcher entry point confirmed, the 7 UI movie modes were found
as UI string resources, the frame-size classes were decoded, and the per-record tables
behind the dispatcher were dumped. See "Round 2" below.

## Address mapping (important)

For the decoded B firmware dump (`b63e111b.bin`):

```
memory address = file offset + 0x40000
```

The same relationship as the D5100 config shipped in the upstream repo
(`dfr/d5100.txt`). All addresses below are memory addresses; patch diffs in this repo
use file offsets (`mem - 0x40000`).

## What the code is

A **bitrate-pair selector** function. Prologue `STM1 (R8,R9,R10,R11)`, and it returns
two u32 values by storing them through pointers passed in R11/R10 - the HQ/NQ bitrate
pair for a video record. Dispatch:

```
R4 (0..3)  -> jump table @ mem 0xCD960   (4 entries, group selector)
  per group: R7 (0..6) -> jump table      (7 entries, record selector)
             R7 >= 7   -> common routine @ mem 0x62182
  per record: R5 == 0 ? HQ pair : NQ pair (set R9/R8, then JMP 0x62182)
common routine @ 0x62182: validates then ST R9,@R11 / ST R8,@R10 / LEAVE / RET
```

The `common routine` at `0x62182` is also the fallback: records that have no custom
values just leave R9/R8 at their defaults (0) and go there.

## Group tables (memory addresses)

| Group | Table at | 7 record handlers (R7 = 0..6) |
|---|---|---|
| R4=0 | 0xCD970 | 0x61E28, (common), 0x61E54, 0x61E80, 0x61ECC, (common), 0x61EA0 |
| R4=1 | 0xCD98C | 0x61F06, 0x61F32, 0x61F5E, 0x61F8A, 0x62002, 0x61FAA, 0x61FD6 |
| R4=2 | 0xCD9A8 | 0x6203C, 0x6205C, 0x6207C, 0x6209C, 0x620E0, 0x620AE, 0x620C0 |
| R4=3 | 0xCD9C4 | 0x62104, 0x62116, 0x62128, 0x6213A, 0x62170, 0x6214C, 0x6215E |

R4 dispatch table @ 0xCD960: 0x61E0E (R4=0), 0x61EEC (R4=1), 0x62022 (R4=2),
0x620F2 (R4=3).

## Bitrate matrix (bits/sec, as loaded into R9/R8 by each record handler)

| Group | R7 | values found (code order; R5 selects the applicable pair) |
|---|---|---|
| R4=0 | 0 | **24M/20M, 12M/10M** |
| R4=0 | 1 | (common - defaults) |
| R4=0 | 2 | **24M/20M, 12M/10M**, 12M/8M |
| R4=0 | 3 | 12M/8M, **24M/20M, 12M/10M** |
| R4=0 | 4 | 12M/8M, 10M/8M |
| R4=0 | 5 | (common - defaults) |
| R4=0 | 6 | **24M/20M, 12M/10M**, 12M/8M |
| R4=1 | 0 | 10M/8M, 6M/5M, 24M/20M, 12M/10M |
| R4=1 | 1 | 24M/20M, 12M/10M, 12M/10M, 8M/6M |
| R4=1 | 2 | 12M/10M, 8M/6M, 9M/6M |
| R4=1 | 3 | 9M/6M, 24M/20M, 12M/10M |
| R4=1 | 4 | 9M/6M, 6M/4M |
| R4=1 | 5 | 24M/20M, 12M/10M, 12M/10M, 8M/6M |
| R4=1 | 6 | 12M/10M, 8M/6M, 9M/6M |
| R4=2 | 0..6 | 6M/4M, 5M/4M, 3M/2M combinations |
| R4=3 | 0..6 | 3M/2M only |

Bold = the values rewritten by the 1.11 alpha patch (only group R4=0, records R7=0,2,6).

## The 12 patched sites

The upstream D800 1.11 alpha patch (and this repo's D800E port) rewrites exactly these
`LDI:32` operands (file offsets used by the patch database / memory addresses):

| File offset | Memory | Stock | 64 Mbps variant | Role |
|---|---|---|---|---|
| 0x021E2E | 0x61E2E | 24,000,000 | 64,000,000 | record R7=0 HQ |
| 0x021E34 | 0x61E34 | 20,000,000 | 60,000,000 | record R7=0 HQ2 |
| 0x021E42 | 0x61E42 | 12,000,000 | 24,000,000 | record R7=0 NQ |
| 0x021E48 | 0x61E48 | 10,000,000 | 20,000,000 | record R7=0 NQ2 |
| 0x021E5A | 0x61E5A | 24,000,000 | 64,000,000 | record R7=2 HQ |
| 0x021E60 | 0x61E60 | 20,000,000 | 60,000,000 | record R7=2 HQ2 |
| 0x021E6E | 0x61E6E | 12,000,000 | 24,000,000 | record R7=2 NQ |
| 0x021E74 | 0x61E74 | 10,000,000 | 20,000,000 | record R7=2 NQ2 |
| 0x021EA6 | 0x61EA6 | 24,000,000 | 64,000,000 | record R7=6 HQ |
| 0x021EAC | 0x61EAC | 20,000,000 | 60,000,000 | record R7=6 HQ2 |
| 0x021EBA | 0x61EBA | 12,000,000 | 24,000,000 | record R7=6 NQ |
| 0x021EC0 | 0x61EC0 | 10,000,000 | 20,000,000 | record R7=6 NQ2 |

This confirms the "NQ becomes old HQ" semantics: the former HQ pair (24/20) is bumped
to the new HQ pair (64/60), and the former NQ pair (12/10) is bumped to the old HQ
values. The other records (R4=0 R7=3/4, all of R4=1..3) are untouched.

## Evidence excerpt (record R7=0, memory view)

```
 CMP     #0x0,R5
 BNE     0x00061E40
 LDI:32  #0x016E3600,R9        ; 24,000,000
 LDI:32  #0x01312D00,R8        ; 20,000,000
 LDI:32  #0x00062182,R12
 JMP     @R12                  ; common store
 LDI:32  #0x00B71B00,R9        ; 12,000,000
 LDI:32  #0x00989680,R8        ; 10,000,000
 LDI:32  #0x00062182,R12
 JMP     @R12
```

## Round 2: the movie modes, the encode control block, and the per-record tables

### Dispatcher entry confirmed

The function starts exactly at memory `0x61DE2` (bytes `8f f0 17 81 0f 01 8b 7b 20 6a
c0 09 c0 08`); the prologue seen in round 1 is this same function, and the `0x61DC2`
constant used from `0x61170` is the unrelated "set force stop" helper. Only four code
sites call the dispatcher, all in the encode module and all reading the same struct:

| Call site (mem) | Module context |
|---|---|
| 0x6272E | encode_cc event handler |
| 0x63264 | encode_cc start path |
| 0x64672 | encode_cc bitrate calc |
| 0x6ACA4 | vraw path (reads u16 fields +0xB8/+0xBA/+0xBC from its own struct) |

All four load `R4=[struct+0x10]`, `R5=[struct+0x14]`, `R6=[struct+0x18]` and pass two
output pointers (R7 = fp-8, stack arg fp+0x18). `0x6ACA4` additionally maps a selector
field `+0xB4` (1 -> 0, 2 -> 1) into the quality slot.

### The 7 UI movie modes (from firmware UI resources)

The B firmware contains, at at least ten locations, this identical ordered block of
7 German-UI menu strings ("Bildgröße/Bildrate" = frame size/frame rate), e.g. at mem
`0xB00333`, `0xB4150E`, `0xBC035D`, `0xC7504E`, `0xCE65FA`, `0xCFAE1F`, `0xD116C5`,
`0xD81CDD`, `0xDA1337`, `0xDF6DDB` (a spread-out variant of the same set also exists
around `0xAFCB51`/`0xAFD9B2`/`0xAFF1BE`):

1. `1920x1080; 30 fps`
2. `1920x1080; 25 fps`
3. `1920x1080; 24 fps`
4. `1280x  720; 60 fps`
5. `1280x  720; 50 fps`
6. `1280x  720; 30 fps`
7. `1280x  720; 25 fps`

This is exactly the D800/D800E movie menu, and it matches the upstream patch's
observation that only 3 of the 7 record slots are patched in group 0.

### Encode settings block `0x84E65E50` (size 0x2C) and state block `0x84E65D40` (0x110)

`0x84E65E50` = "current movie encode settings":

| Offset | Meaning |
|---|---|
| +0x10 | frame-size class 0..3 (see next table) |
| +0x14 | record index 0..6 (indexes the 7-entry tables, see below) |
| +0x18 | quality / HQ-NQ selector 0/1 (dispatcher's R6) |
| +0x1C | flag checked at encode start |
| +0x28 | copied from a mode descriptor by `0x62F4C` |

`0x84E65D40` = "encode session state": +0x00 derived time value (result of `0x67E86`,
clamped to <= 0xFFF7FFFF), +0x04 per-record value from helper `0x621A4`, +0x08
0/clamp, +0x10/+0x14 compared by the recordable-time check ("WARNING## encode_cc:
media max over", mem 0xCD368), +0x1C/+0x20/+0x24/+0x28 force-stop/watchdog state flags,
+0x3C a sequence counter.

The mode-apply function is `0x62F4C` (copies `[descriptor+0x28]` into `[E50+0x28]`,
then derives the `0x84E65D40` fields). It has **no direct callers** (no `LDI:32`
references) - it is entered through a pointer table. The reset function is `0x62F04`
(memsets E50 with 0x2C and D40 with 0x110).

### Frame-size classes (from `0x630A0`, switch on `[E50+0x10]`)

Each class yields three `LDI:20` constants (encoder plane/stride sizes, first value is
a luma plane: 1920x1072, 1280x704, 640x416, 640x208):

| Class | Values |
|---|---|
| 0 | 0x1F6800 (2,058,240 = 1920x1072), 0xF7800, 0x7800 |
| 1 | 0x0DC000 (901,120 = 1280x704), 0x6B800, 0x5000 |
| 2 | 0x041000 (266,240 = 640x416), 0x20800, 0x2800 |
| 3 | 0x020800 (133,120), 0xF000, 0x2800 |

So the dispatcher's `R4` really is a *frame-size* class: 0 = 1080p modes (1920 wide),
1 = 720p modes (1280 wide), 2/3 = small (640-wide and below) pipelines.

### Per-record tables

Three 7-entry tables are indexed by `[E50+0x14]` (record index):

- **Dispatcher group tables** (round 1): per-group records select the HQ/NQ bitrate
  pairs; group 0 records 0/2/6 carry the 24M/20M + 12M/10M pairs - i.e. the three
  1080p modes, which is why the alpha patch's 12 sites are exactly those records.
- **Helper `0x621A4(record)`** (table 0xCD9E0, bodies 0x621B6..0x621D2, each body a
  `BRA:D` + delay `LDI:8 #imm,R4`; FR `LDI:8` encoding verified against known bytes):
  returns `[12, 30, 15, 15, 12, 24, 12]` for records 0..6. Meaning still open
  (GOP-length-shaped, but not consistently fps/2).
- **Helper `0x621D6(record)`** (table 0xCD9FC): returns 1 for records 1 and 5, 0
  otherwise.
- **Function `0x63728`** (record jump table mem `0xCDA6C`): per-record case calls the
  Softune runtime 64-bit add (`0x29649A`, entry `ADD R7,R5 / ADDC R6,R4`, 427 callers)
  to accumulate a 64-bit counter at `[ctx+0x10..0x17]`. Increments per record are
  `15015, 6006, 12012, 24024, 7200, 14400, 15000` = nominal rates
  {15.015, 6.006, 12.012, 24.024, 7.2, 14.4, 15.0} Mbps (NTSC x1001/1000 and
  PAL x1.2 scalings visible). A second 7-entry jump table of the same shape exists at
  `0xCDAA4` (used by the `0x646xx` caller) with `MULU R5,R4` + `0x296D08` per case.

### Other confirmed helpers

- `0x62182(R9,R8,R11,R10)` - the shared dispatcher tail: prints
  "ERROR## encode: bitrate get error" (mem 0xCD91C) if either value is 0, then
  `ST R9,@R11 / ST R8,@R10`.
- `0x621F4(group,record,quality)` - returns a ROM table base: default `0x001B7358`;
  `0x00124F80` when quality==0 and (group==0 or (group==1 and record in {1,5})).
- `0x67E86`, `0x621A4`, `0x621D6` results feed `[D40]`/`[D40+4]` in the apply path.

## M3 extension candidates (same mechanism, Alpha risk class)

1. **R4=1, R7=1 and R7=5** - these already carry the same 24M/20M premium pair as the
   patched records but were left untouched by the upstream patch. Prime candidates if
   they turn out to drive high-bitrate modes.
2. **R4=0, R7=3** - 12M/8M, 24M/20M, 12M/10M mix.
3. **R4=1, R7=0/3** - contain 24M/20M+12M/10M among lower pairs.

Since round 2 the mode space is known: 7 UI modes (see above), frame-size class 0 =
1080p and 1 = 720p. Group 0 records 0/2/6 are the three 1080p modes; group 1 records
carry the 720p modes. Still open is the *order*: which of records 0/2/6 is 30p vs 25p
vs 24p, and how the UI mode index maps to (size class, record, quality) exactly
(the UI resource order above is a strong candidate for the record order).

## Open questions

- Which of records 0/2/6 (group 0, patched) is 1080p30 vs 1080p25 vs 1080p24, and the
  corresponding record order for group 1 (720p modes).
- Meaning of helper `0x621A4` values {12, 30, 15, 15, 12, 24, 12} and the
  `0x621D6` flags (1 for records 1 and 5) - plausibly GOP/field/rate-control traits.
- Purpose of frame-size classes 2 and 3 (640x416 and below) - likely the live-view /
  small pipeline rather than user-visible movie modes.
- Callers of the mode-apply function `0x62F4C` and of the mode descriptor table that
  supplies `[descriptor+0x28]` (entered via pointer table) - the last link between UI
  menu events and `E50`.
