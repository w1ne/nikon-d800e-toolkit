#!/usr/bin/env python3
"""Minimal Fujitsu FR assembler - enough for D800E patch stubs and hooks.

Encodings were taken from the NikonHacker disassembler's instruction table
(FrInstructionSet.java) and verified against real firmware bytes via round-trip
disassembly (see selftest.sh).

Supported:
  LDI:8 #imm, rX        LDI:20 #imm, rX       LDI:32 #imm, rX
  MOV rA, rB            CMP #imm, rX          CMP rA, rB
  LD @rA, rB            ST rB, @rA
  JMP @rX  JMP:D @rX    CALL @rX  CALL:D @rX   RET  RET:D
  STM1 (rA,rB,...)      LDM1 (rA,rB,...)      ST RP,@-R15   LD @R15+,RP
  ENTER #n              LEAVE                 NOP           INT #n
  ADD #imm, rX          ADD rA, rB            SUB rA, rB
  AND rA, rB            OR rA, rB             EOR rA, rB
  LSR #d, rX            LSL #d, rX            ASR #d, rX
  BRA label  BEQ label  BNE label  BC label  BNC label   (8-bit disp: /2)
  BRA:D label           (delay slot = the next instruction, written explicitly)

Directives:
  .org 0xADDR           set assembly base (needed for label math)
  label:                label definition
  ; comment             end-of-line comments

Usage:
  frasm.py input.asm output.bin [--listing]
"""
import re, sys

REGS = {f"r{i}": i for i in range(16)}


def parse_reg(tok):
    t = tok.strip().lower()
    if t in REGS:
        return REGS[t]
    raise ValueError(f"bad register: {tok!r}")


def parse_imm(tok):
    t = tok.strip()
    if not t.startswith("#"):
        raise ValueError(f"immediate must start with #: {tok!r}")
    return int(t[1:], 0)


def pack_stm1(regs):
    """STM1 packing: R15 -> bit0, R14 -> bit1 ... R8 -> bit7."""
    mask = 0
    for r in regs:
        if r == 15:
            mask |= 1
        elif 8 <= r <= 14:
            mask |= 1 << (15 - r)
        else:
            raise ValueError(f"STM1 only supports R8..R15, got R{r}")
    return mask


def pack_ldm1(regs):
    """LDM1 packing (empirical from firmware: R8..R11 -> 0x0F)."""
    mask = 0
    for r in regs:
        if 8 <= r <= 15:
            mask |= 1 << (r - 8)
        else:
            raise ValueError(f"LDM1 only supports R8..R15, got R{r}")
    return mask


class Asm:
    def __init__(self):
        self.labels = {}
        self.out = b""
        self.org = 0

    def encode(self, mnem, ops):
        m = mnem.lower().replace(":", "")
        # no-operand
        if m in ("ret", "retd", "leave", "nop"):
            return {"ret": b"\x97\x20", "retd": b"\x9f\x20",
                    "leave": b"\x9f\x90", "nop": b"\x9f\xa0"}[m]
        if m == "enter":
            n = parse_imm(ops[0])
            assert n % 4 == 0 and 0 <= n <= 0x3FC, "ENTER immediate must be a multiple of 4"
            return bytes([0x0F, n >> 2])
        if m == "int":
            return bytes([0x1F, parse_imm(ops[0]) & 0xFF])
        if m == "ldi8":
            v = parse_imm(ops[0]); r = parse_reg(ops[1])
            return bytes([0xC0 | ((v >> 4) & 0xF), ((v & 0xF) << 4) | r])
        if m == "ldi20":
            v = parse_imm(ops[0]); r = parse_reg(ops[1])
            return bytes([0x9B, (((v >> 16) & 0xF) << 4) | r,
                          (v >> 8) & 0xFF, v & 0xFF])
        if m == "ldi32":
            v = parse_imm(ops[0]); r = parse_reg(ops[1])
            return bytes([0x9F, 0x80 | r]) + v.to_bytes(4, "big")
        if m == "mov":
            a = parse_reg(ops[0]); b = parse_reg(ops[1])
            return bytes([0x8B, (a << 4) | b])
        if m == "jmp":
            r = parse_reg(ops[0].lstrip("@"))
            return bytes([0x97, r])
        if m == "jmpd":
            r = parse_reg(ops[0].lstrip("@"))
            return bytes([0x9F, r])
        if m == "call":
            r = parse_reg(ops[0].lstrip("@"))
            return bytes([0x97, 0x10 | r])
        if m == "calld":
            r = parse_reg(ops[0].lstrip("@"))
            return bytes([0x9F, 0x10 | r])
        if m in ("stm1", "ldm1"):
            joined = ",".join(ops)
            regs = [parse_reg(x) for x in joined.strip("() ").split(",")]
            mask = pack_stm1(regs) if m == "stm1" else pack_ldm1(regs)
            return bytes([0x8F if m == "stm1" else 0x8D, mask])
        if m == "st" and ops[1].replace(" ", "").lower() == "@-r15" and ops[0].upper() == "RP":
            return b"\x17\x81"
        if m == "ld" and ops[0].replace(" ", "").lower() == "@r15+" and ops[1].upper() == "RP":
            return b"\x07\x81"
        if m == "st":
            d = parse_reg(ops[0]); a = parse_reg(ops[1].lstrip("@"))
            return bytes([0x14, (a << 4) | d])
        if m == "ld":
            a = parse_reg(ops[0].lstrip("@").rstrip("+")); d = parse_reg(ops[1])
            return bytes([0x04, (a << 4) | d])
        if m == "cmp" and ops[0].startswith("#"):
            v = parse_imm(ops[0]); r = parse_reg(ops[1])
            assert 0 <= v <= 0xF, "CMP #imm,Rx immediate is 4-bit"
            return bytes([0xA8, (v << 4) | r])
        if m == "cmp":
            a = parse_reg(ops[0]); b = parse_reg(ops[1])
            return bytes([0xAA, (a << 4) | b])
        if m == "add" and ops[0].startswith("#"):
            v = parse_imm(ops[0]); r = parse_reg(ops[1])
            assert 0 <= v <= 0xF, "ADD #imm,Rx immediate is 4-bit"
            return bytes([0xA4, (v << 4) | r])
        if m == "add":
            a = parse_reg(ops[0]); b = parse_reg(ops[1])
            return bytes([0xA6, (a << 4) | b])
        if m == "sub":
            a = parse_reg(ops[0]); b = parse_reg(ops[1])
            return bytes([0xAC, (a << 4) | b])
        for mnem2, op in (("and", 0x82), ("or", 0x92), ("eor", 0x9A)):
            if m == mnem2:
                a = parse_reg(ops[0]); b = parse_reg(ops[1])
                return bytes([op, (a << 4) | b])
        for mnem2, op in (("lsr", 0xB0), ("lsl", 0xB4), ("asr", 0xB8)):
            if m == mnem2:
                d = parse_imm(ops[0]); r = parse_reg(ops[1])
                assert 0 <= d <= 0xF, f"{mnem2} #imm,Rx immediate is 4-bit"
                return bytes([op, (d << 4) | r])
        # relative branches (8-bit displacement, in 2-byte units, from pc+2)
        if m in ("bra", "brad", "beq", "bne", "bc", "bnc"):
            return ("BRANCH", m, ops[0])
        raise ValueError(f"unknown instruction: {mnem} {' '.join(ops)}")


def assemble(text, listing=False):
    asm = Asm()
    lines = []
    for raw in text.splitlines():
        line = raw.split(";")[0].strip()
        if not line:
            continue
        if line.lower().startswith(".org"):
            asm.org = int(line.split()[1], 0)
            continue
        MNEMS = {"ldi8","ldi20","ldi32","mov","jmp","jmp:d","jmpd","call","call:d","calld",
                 "ret","retd","leave","nop","enter","int","stm1","ldm1","st","ld","cmp",
                 "add","sub","and","or","eor","lsr","lsl","asr","bra","bra:d","brad",
                 "beq","bne","bc","bnc"}
        m = re.match(r"^([A-Za-z_][\w.]*):\s*(.*)$", line)
        if m and m.group(1).lower() not in MNEMS:
            asm.labels[m.group(1)] = asm.org + len(asm.out)
            line = m.group(2).strip()
            if not line:
                continue
        parts = re.split(r"\s+", line, maxsplit=1)
        mnem = parts[0]
        ops = [o.strip() for o in parts[1].split(",")] if len(parts) > 1 else []
        lines.append((mnem, ops))
    # pass 1: sizes
    sizes = []
    for mnem, ops in lines:
        try:
            enc = asm.encode(mnem, ops)
        except Exception as e:
            raise ValueError(f"{mnem} {' '.join(ops)}: {e}")
        sizes.append(6 if (isinstance(enc, tuple)) else len(enc))
    # pass 2: emit
    pc = asm.org
    for (mnem, ops), size in zip(lines, sizes):
        enc = asm.encode(mnem, ops)
        if isinstance(enc, tuple):
            _, m, label = enc
            target = asm.labels.get(label)
            if target is None:
                raise ValueError(f"undefined label: {label}")
            disp = (target - (pc + 2)) // 2
            if not (-128 <= disp <= 127) or (target - (pc + 2)) % 2:
                raise ValueError(f"branch out of range: {label}")
            opc = {"bra": 0xE0, "brad": 0xF0, "beq": 0xE2, "bne": 0xE3,
                   "bc": 0xE4, "bnc": 0xE5}[m]
            enc = bytes([opc, disp & 0xFF])
        asm.out += enc
        if listing:
            print(f"{pc:08X}  {enc.hex(' ').upper():<18} {mnem} {', '.join(ops)}")
        pc += len(enc)
    return asm.out


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(2)
    src = open(sys.argv[1]).read()
    out = assemble(src, listing="--listing" in sys.argv)
    open(sys.argv[2], "wb").write(out)
    print(f"wrote {sys.argv[2]} ({len(out)} bytes)")


if __name__ == "__main__":
    main()
