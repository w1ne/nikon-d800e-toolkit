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

This table was hand-read from the first listing and contained small errors; the
definitive, mechanically extracted matrix is in
[`ENCODE-MODULE.md`](ENCODE-MODULE.md) and in round 3 below. Corrected summary:
each handler holds **two pairs**; quality (`R5`) 0 takes the first pair ("High"),
quality != 0 the second ("Normal").

| Group | R7 | pair A (quality 0) | pair B (quality != 0) |
|---|---|---|---|
| R4=0 | 0 | **24M/20M** | **12M/10M** |
| R4=0 | 1 | (common - defaults) | (common - defaults) |
| R4=0 | 2 | **24M/20M** | **12M/10M** |
| R4=0 | 3 | 12M/8M | 12M/8M |
| R4=0 | 4 | 12M/8M | 12M/8M |
| R4=0 | 5 | (common - defaults) | (common - defaults) |
| R4=0 | 6 | **24M/20M** | **12M/10M** |
| R4=1 | 0 | 10M/8M | 6M/5M |
| R4=1 | 1 | 24M/20M | 12M/10M |
| R4=1 | 2 | 12M/10M | 8M/6M |
| R4=1 | 3 | 9M/6M | 9M/6M |
| R4=1 | 4 | 9M/6M | 9M/6M |
| R4=1 | 5 | 24M/20M | 12M/10M |
| R4=1 | 6 | 12M/10M | 8M/6M |
| R4=2 | all | 6M/4M or 5M/4M | 6M/4M or 3M/2M |
| R4=3 | all | 3M/2M | 3M/2M |

Bold = the values rewritten by the 1.11 alpha patch (only group R4=0, records R7=0,2,6).

## The 12 patched sites

The upstream D800 1.11 alpha patch (and this repo's D800E port) rewrites exactly these
`LDI:32` operands (file offsets used by the patch database / memory addresses).
Record numbers map to UI modes as `R7=0` = 1080/24p, `R7=2` = 1080/30p,
`R7=6` = 1080/25p (round 3):

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
  returns `[12, 30, 15, 15, 12, 24, 12]` for records 0..6 = **GOP length in frames**
  (about fps/2; used by the batch as bytes-per-GOP divisor, 0x64640).
- **Helper `0x621D6(record)`** (table 0xCD9FC): returns 1 for records 1 and 5, 0
  otherwise (50p/60p flag).
- **Function `0x63728`** (record jump table mem `0xCDA6C`): per-record case calls the
  Softune runtime 64-bit add (`0x29649A`, entry `ADD R7,R5 / ADDC R6,R4`, 427 callers)
  to accumulate a 64-bit counter at `[ctx+0x10..0x17]`. Increments in **table order**
  (corrected from the earlier address-order list) are rec0..6 =
  `15015, 6006, 12012, 24024, 15000, 7200, 14400`, and
  `increment x real fps = 360,000` exactly for every record - the counter is a
  **360 kHz timebase** (units of 1/360000 s). A second 7-entry jump table exists at
  `0xCDAA4` (used by the `0x646xx` batch) dividing by floor(fps) per record
  (`23, 59, 29, 14, 24, 50, 25`) to get **bytes per GOP** = `(bitrate>>3) x GOP / fps`.

### Other confirmed helpers

- `0x62182(R9,R8,R11,R10)` - the shared dispatcher tail: prints
  "ERROR## encode: bitrate get error" (mem 0xCD91C) if either value is 0, then
  `ST R9,@R11 / ST R8,@R10`.
- `0x621F4(group,record,quality)` - returns a ROM table base: default `0x001B7358`;
  `0x00124F80` when quality==0 and (group==0 or (group==1 and record in {1,5})).
- `0x67E86`, `0x621A4`, `0x621D6` results feed `[D40]`/`[D40+4]` in the apply path.

## M3 extension candidates (now with known mode labels)

Each site below is a B-block file offset (container = +0x100072), u32 BE bits/s;
first value of each pair = HQ, second = NQ.

| mode | status | sites |
|---|---|---|
| 1080/24p | **patched** | 0x21E2E, 0x21E34 / 0x21E42, 0x21E48 |
| 1080/30p | **patched** | 0x21E5A, 0x21E60 / 0x21E6E, 0x21E74 |
| 1080/25p | **patched** | 0x21EA6, 0x21EAC / 0x21EBA, 0x21EC0 |
| 720/60p | candidate | 0x21F38, 0x21F3E / 0x21F4C, 0x21F52 |
| 720/50p | candidate | 0x21FB0, 0x21FB6 / 0x21FC4, 0x21FCA |
| 720/30p | candidate | 0x21F64, 0x21F6A / 0x21F78, 0x21F7E |
| 720/25p | candidate | 0x21FDC, 0x21FE2 / 0x21FF0, 0x21FF6 |

720p60/50 already run at the same 24/20 Mbps premium pair as stock 1080p, so the
natural extension is the same bump the alpha patch applies to 1080p. The non-movie
rate classes (15p/2.4p) exist in both groups but are not user-selectable movie modes.
See `../MODDING.md` for the edit + repack + verify loop.

## Round 3: the mapping is solved (and supersedes the open items above)

The vraw mode mapper `0x6AB76` reads the current movie settings from context
`0x84E6B538` and produces the dispatcher arguments:

- **width `[ctx+0xB0]`** 1920/1280/640/320 -> **group** 0/1/2/3
- **rate `[ctx+0x9C]`** (fps x 1000) -> **record**:
  24000->0, 60000->1, 30000->2, 15000->3, 2400->4, 50000->5, 25000->6
- **quality `[ctx+0xB4]`** 1/2 -> 0 (High) / 1 (Normal)

So the record index is a **frame-rate class**, and the seven UI modes map to:

| UI mode | (group, record) | patched by alpha? |
|---|---|---|
| 1920x1080; 24p | (0, 0) | yes |
| 1920x1080; 30p | (0, 2) | yes |
| 1920x1080; 25p | (0, 6) | yes |
| 1280x720; 60p | (1, 1) | no |
| 1280x720; 50p | (1, 5) | no |
| 1280x720; 30p | (1, 2) | no |
| 1280x720; 25p | (1, 6) | no |

This makes the alpha patch's 12 sites exactly the three 1080p modes. Group 0's
records for 60p/50p are empty (no 1080p60/50 exists), which is why records 1 and 5
fall through to the common zero-store. `0x621A4` returns GOP-ish lengths
(12/30/15/15/12/24/12 = about fps/2 for the movie rates) and `0x621D6` returns 1
exactly for the 50p/60p classes.

The definitive bitrate matrix, per-mode extension offsets and the full call graph
are in [`ENCODE-MODULE.md`](ENCODE-MODULE.md); the mod/flash workflow is in
[`../MODDING.md`](../MODDING.md).

## Round 5: closing the remaining questions

1. **Accounting unit solved.** With the record table order corrected, the `0x63728`
   increments are rec0..6 = `15015, 6006, 12012, 24024, 15000, 7200, 14400` and
   `increment x real fps = 360,000` exactly for all seven - the accumulator is a
   **360 kHz timebase** (1/360000 s per unit). The `0x64640` batch uses GOP length
   (`0x621A4`) and floor(fps) (`23, 59, 29, 14, 24, 50, 25`) to compute **bytes per
   GOP** = `(bitrate>>3) x GOP / fps`.
2. **"2.4p" was a misnomer.** Record 4 is `(timebase 2400, scale 100)` = **24.000 fps
   exactly**, a non-menu integer-rate variant; record 3 is `(15000, 1001)` = 14.985 fps.
   Both are accepted by the settings parser and dispatched with 12M/8M (group 0) or
   9M/6M (group 1) rates, serving pipelines that are not the user movie modes.
3. **Settings message path found.** Parser entry `0x692A0` (clears 0x154 bytes of
   `0x84E6B538`, copies a name from `0xCFBC0`, fills fields from the source struct and
   dispatches on the rate enum table `0xCFDC4`). Called from `0x70C7A` (entry via the
   call at `0x6DA2C`), the "prepare movie pipeline" function that switches on the size
   enum, computes encoder buffer geometry (1920x1080/1088, 1280x720, 640x424/480,
   320x216/480) and builds the message; its caller runs after REALOS `INT #0x40`
   services and feeds it `R4 = [0x84E6BFD4]` from the shared RAM control block. A
   getter at `0x69290` returns the ctx pointer; `0x6922A` converts time values (÷1000).
   The A firmware is not FR code (0 `RET` opcodes; header `3c 1a bf c0`; copyright
   string at `0x7FB8`), so this shared block's producer cannot be disassembled with
   the FR toolchain - B-side accesses to these blocks are all reads.
4. **E50 write side clarified.** All ten `0x84E65E50` references were audited: B writes
   only `+0x0C` (`0x62D8E`), `+0x38` (`0x64C1A`), `+0x28` (apply `0x62F4A`) and the
   reset `0x62F14`; everything else is read-only. The mode triple
   `+0x10/+0x14/+0x18` and `+0x08` therefore arrive from the **other processor**
   (the A image has no FR code or UI strings) via shared RAM/IPC. That external
   producer is the only structural unknown left.

## Open questions

- Producer of the E50 mode triple and the shared control blocks: the A-side CPU
  (non-FR image; header `3c 1a bf c0`, Nikon copyright at `0x7FB8`). Out of reach of
  the FR disassembler; all B-side accesses are reads.
- The 360 kHz accumulator's consumer is the **spool/scheduler** subsystem
  (`0x6Dxxx-0x71xxx`): `0x6D340` ÷1000 + counters at `0x84E6C014`, min/max at
  `0x84E6BA70/+4`; `0x6D29A` classifies intervals (≤1000 ms) into rate categories.
  Which UI element consumes the result (remaining-time estimate vs. throttling) is
  not proven.
- Which pipeline drives the 15p and 24.000 fps classes.
- Callers of `0x62F4A` (mode apply) and `0x62F14` (reset): no direct LDI references
  (indirect entry; corrected addresses - the round-1/2 note said 0x62F4C). The
  module's entry points are generally reached indirectly (pipeline builder, parser,
  apply all lack direct refs), consistent with REALOS task/dispatch registration.
