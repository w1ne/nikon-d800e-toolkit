#!/usr/bin/env python3
"""Phase-2 proof of concept: execute new FR code inside the D800E B firmware.

Mechanism:
  - 8 bytes at the bitrate-dispatcher entry (0x61DE2) are replaced with
    "LDI:32 #stub, R12 ; JMP @R12"  (the stolen bytes are STM1 / ST RP,@-R15 /
    ENTER #4 / MOV R7,R11)
  - the stub is assembled with frasm into the 128 KiB 0xFF cave at memory
    0x4E0000 (file 0x0A0000). It writes a magic marker to RAM, replays the
    stolen prologue and jumps back to 0x61DEA (the interrupted instruction)
  - the B-block CRC16 is recomputed

Modes:
  hook_poc.py <b63e111b.bin> <out_b.bin> [--force-quality]
      -> patched decoded B block
  hook_poc.py <stock_raw.bin> <out_flashable.bin> --container [--force-quality]
      -> patched, CRC-fixed, XOR-encoded flashable container

--force-quality additionally sets R6=1 (Normal quality) in the stub, which
flips the dispatcher results (24/20 -> 12/10 for 1080p), demonstrating
behavioral influence, not just execution.

Verify with the emulator probe:
  re/tools/emu-probe/run.sh <out_b.bin> 0x61DE2 0 2 0 0 2 1
  -> stock values + "marker=0xCAFE0001" (and 12/10 when --force-quality)
"""
import sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "fr-asm"))
sys.path.insert(0, os.path.join(HERE, "..", ".."))

from frasm import assemble  # noqa: E402
import nikonfw  # noqa: E402

DISP_ENTRY = 0x61DE2          # memory
RESUME = 0x61DEA              # dispatcher+8: after the stolen bytes
CAVE_MEM = 0x0E0000           # file 0x0A0000, 128 KiB of 0xFF
MARKER = 0x84E6C020           # RAM scratch (emulator: opened by the probe)

STUB_TPL = """
.org 0x{cave:08X}
stub:
    ldi32 #0x{marker:08X}, r0
    ldi32 #0xCAFE0001, r1
    st    r1, @r0
{force}    stm1  (r8,r9,r10,r11)
    st    rp, @-r15
    enter #4
    mov   r7, r11
    ldi32 #0x{resume:08X}, r12
    jmp   @r12
"""


def build_stub(force_quality=False):
    force = "    ldi8  #0x1, r6      ; PoC: force NQ\n" if force_quality else ""
    src = STUB_TPL.format(cave=CAVE_MEM, marker=MARKER, resume=RESUME, force=force)
    return assemble(src)


def build_trampoline():
    src = f".org 0x{DISP_ENTRY:08X}\n" \
          f"    ldi32 #0x{CAVE_MEM:08X}, r12\n" \
          f"    jmp   @r12\n"
    return assemble(src)


def patch_b_block(blob, force_quality=False):
    b = bytearray(blob)
    cave_off = CAVE_MEM - 0x40000
    stub = build_stub(force_quality)
    tramp = build_trampoline()
    assert len(tramp) == 8, tramp.hex()
    assert all(x == 0xFF for x in b[cave_off:cave_off + len(stub)]), "cave not empty"
    b[cave_off:cave_off + len(stub)] = stub
    off = DISP_ENTRY - 0x40000
    b[off:off + len(tramp)] = tramp
    crc = nikonfw.crc16_ccitt(bytes(b[:-2]))
    b[-2:] = crc.to_bytes(2, "big")
    return bytes(b), len(stub)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    if len(args) != 2:
        print(__doc__)
        sys.exit(2)
    inp, outp = args
    force = "--force-quality" in flags
    raw = open(inp, "rb").read()

    if "--container" in flags:
        dec = bytearray(nikonfw.detect(raw)[0])
        count, blocks = nikonfw.parse_blocks(dec)
        o, l = blocks[1]
        patched, stub_len = patch_b_block(dec[o:o + l], force)
        dec[o:o + l] = patched
        for oo, ll in blocks:
            nikonfw.fix_block_crc(dec, oo, ll)
        enc = nikonfw.xor(bytes(dec))
        open(outp, "wb").write(enc)
        import hashlib
        print(f"wrote {outp} ({len(enc)} bytes, stub {stub_len} bytes, force_quality={force})")
        print("sha256:", hashlib.sha256(enc).hexdigest())
    else:
        patched, stub_len = patch_b_block(raw, force)
        open(outp, "wb").write(patched)
        print(f"wrote {outp} ({len(patched)} bytes, stub {stub_len} bytes, force_quality={force})")
        print("B-block CRC: OK (recomputed)")


if __name__ == "__main__":
    main()
