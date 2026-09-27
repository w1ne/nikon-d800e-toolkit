# The D800E "A" firmware - identified: MIPS32 big-endian

Status: solved (2026-09-27). This closes the last structural unknown of the
firmware chain: the "A" image is the camera's **main CPU firmware**, a
**MIPS32 big-endian** program, and it is the producer of the movie
settings/messages that the FR "B" image (the encoder side) consumes.

## Evidence

First 16 bytes of `a63em011100.bin` (block 0, 1 MiB):

```
3c 1a bf c0   lui   k0, 0xBFC0
27 5a 05 00   addiu k0, k0, 0x0500
03 40 00 08   jr    k0
00 00 00 00   nop
```

This is the canonical MIPS boot-vector stub: the ROM/base is `0xBFC00000`
(KSEG1) and execution jumps to `0xBFC00500`. Instruction-pattern counts over the
image: 125x `addiu sp,sp,-N`, 106x `jr ra`, 47x `sw ra`, 2363x `nop` - clean
MIPS code, and Capstone disassembles the entry into sane MIPS32 code with
zero errors:

```asm
0xBFC00500  mfc0  $k1, $t4, 0        ; CP0 Config register check
0xBFC00504  lui   $k0, 8
0xBFC00508  and   $k1, $k1, $k0
0xBFC0050C  beqz  $k1, 0xBFC00524
0xBFC00510  nop
0xBFC00514  lui   $t0, 0xBFC1
0xBFC00518  addiu $t0, $t0, 0x6978
0xBFC0051C  jalr  $t0               ; -> stage 2 @ 0xBFC16978
0xBFC00520  nop
0xBFC00524  ori   $k1, $zero, 2      ; baseboard/device setup
0xBFC00528  lui   $k0, 0xFF00
0xBFC0052C  sb    $k1, 0x1913($k0)   ; MMIO writes at 0xFF00xxxx
...
```

Other facts:

- `"D800E  Firmware A Copyright Nikon Corp."` at file `0x7FB0`.
- `"PTP"` at file `0xAFFD8` - the A side carries the USB/PTP (and likely
  network/UT-1) stack, which matches the 1.10 release notes (UT-1/http/ftp
  features). The B image holds the image/encode side plus the UI resources.
- A-side free space: `0x0BD12C..0x100000` is 0xFF (274 KiB).

## How to disassemble / emulate

```sh
python3 -m venv /tmp/mips && /tmp/mips/bin/pip install capstone
/tmp/mips/bin/python - <<'EOF'
import capstone as cs
a = open("a63em011100.bin","rb").read()   # extracted block 0
md = cs.Cs(cs.CS_ARCH_MIPS, cs.CS_MODE_MIPS32 + cs.CS_MODE_BIG_ENDIAN)
for ins in md.disasm(a[0x500:0x900], 0xBFC00500):
    print(f"0x{ins.address:08x}: {ins.mnemonic:8s} {ins.op_str}")
EOF
```

Address mapping: `virtual = 0xBFC00000 + file offset`.

## Why this matters

- The menu/message logic that feeds `E50`/the shared control blocks lives here;
  UI-level features (Movie menu additions, HDMI experiments, PTP extensions)
  must be researched on this side.
- The two populated firmware blocks are now both understood at least
  architecturally: A = MIPS main/UI/comms, B = Fujitsu FR image/encode side
  (the side all bitrate patches touch).

## Next steps on A

- Map stage 2 (`0xBFC16978`) and the PTP handler tables (Simeon's 2021 note:
  "PTP handlers are driven by tables").
- Search for the movie-settings message constructor that writes the shared RAM
  (the counterpart of B's parser at `0x692A0`).
- Only then could A-side code patches be considered; the A block's 274 KiB of
  free space is a natural cave if that road is taken.
