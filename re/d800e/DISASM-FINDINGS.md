# D800E 1.11 B-firmware: the bitrate dispatcher, disassembled

Status: first code-level analysis of the region that carries the 1.11 bitrate patches.
Tool: the NikonHacker Java emulator suite (`com.nikonhacker.disassembly.fr.Dfr`), built
natively on macOS. See `disasm/README.md` for reproduction.

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

## M3 extension candidates (same mechanism, Alpha risk class)

1. **R4=1, R7=1 and R7=5** - these already carry the same 24M/20M premium pair as the
   patched records but were left untouched by the upstream patch. Prime candidates if
   they turn out to drive high-bitrate modes.
2. **R4=0, R7=3** - 12M/8M, 24M/20M, 12M/10M mix.
3. **R4=1, R7=0/3** - contain 24M/20M+12M/10M among lower pairs.

To label each record with its UI mode, correlate against test recordings per mode, or
find the callers of the dispatcher (memory ~0x61DDx-0x61E00) in the full disassembly
or in the emulator. Only then is it safe to propose value changes per mode.

## Open questions

- Exact function entry point (prologue immediately precedes the R4 dispatch at 0x61E00).
- Which R4/R7 combination maps to which UI video mode (1080p30/25/24, 720p60/50, ...).
- Whether R5 is "quality" (HQ/NQ) or something else (bit depth, rate control mode).
