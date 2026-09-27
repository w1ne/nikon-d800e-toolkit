# FR hook proof-of-concept (Phase 2)

Executes new FR code inside the D800E B firmware. This is the mechanism that any
future firmware feature (not just bitrate data patches) would use.

## Mechanism

- **Trampoline** at the bitrate dispatcher entry `0x61DE2`: the first 8 bytes
  (`STM1` / `ST RP,@-R15` / `ENTER #4` / `MOV R7,R11`) are replaced with
  `LDI:32 #stub,R12 ; JMP @R12`.
- **Stub** (assembled by `re/tools/fr-asm/frasm.py`) is placed in the 128 KiB
  0xFF cave at memory `0x0E0000` (file `0x0A0000`). It writes a magic marker to
  RAM, replays the stolen prologue and jumps back to `0x61DEA`.
- The B-block CRC16 is recomputed; `--container` mode additionally re-encodes
  the full flashable image via `nikonfw.py` primitives.

```
                       (8 bytes replaced)                         (cave)
 0x61DE2 -> LDI:32 #0x0E0000,R12 ; JMP @R12 ---> stub: write marker 0xCAFE0001
                                                  STM1 / ST RP / ENTER#4
                                                  MOV R7,R11
                                                  0x61DEA <- JMP back (LDI:32)
```

## Usage

```sh
# patched decoded B block (for the emulator probe)
python3 re/tools/fr-hook/hook_poc.py b63e111b.bin out_b.bin

# same, but also forces R6=1 (Normal quality) to show behavioural influence
python3 re/tools/fr-hook/hook_poc.py b63e111b.bin out_b.bin --force-quality

# flashable container built from the stock Nikon file
python3 re/tools/fr-hook/hook_poc.py D800E_0111.bin out.bin --container
```

## Verification (emulator)

```sh
# stock and hooked images must reproduce the documented matrix...
./re/tools/emu-probe/run.sh out_b.bin 0x61DE2 0 2 0 0 2 1 1 1 0
#   -> g=0 rec=2 q=0 -> 24,000,000 / 20,000,000   (identity preserved)
#   -> marker=0xCAFE0001                          (stub executed)

# ...and with --force-quality the same HQ requests return the NQ pair
./re/tools/emu-probe/run.sh out_b.bin 0x61DE2 0 2 0 0 6 0 1 1 0
#   -> 12,000,000 / 10,000,000   + marker=0xCAFE0001
```

Observed results (2026-09-27):
- identity hook: matrix unchanged, marker set -> code execution proven;
- `--force-quality`: 1080/30p, 1080/25p, 720/60p HQ requests return 12/10 ->
  injected code changes firmware behaviour;
- container mode: both block CRCs verify, trampoline/stub bytes confirmed.

## Caveats before hardware

- The cave `0x0E0000` is 0xFF in the image, but its **runtime mapping and
  executability are unverified** on hardware. A hardware-first attempt should
  use a small cave inside an already-executing region (see
  `re/d800e/CODE-MOD-GROUNDWORK.md` section 1) and be proven on a sacrificial
  body.
- The marker address `0x84E6C020` is a plausible scratch slot, not a verified
  free RAM address.
- Flashing any hooked image carries the usual no-recovery risk; keep the PoC in
  the emulator until the above are resolved.
