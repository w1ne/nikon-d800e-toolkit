# Nikon D800E firmware reverse-engineering plan

Status date: 2026-09-26
Target: Nikon D800E, stock firmware A/B 1.11
Mode: research only - nothing flashed. Camera untouched.

## 1. Why there is no Magic Lantern on Nikon

- Nikon DSLRs cannot boot code from a card (Canon can, that is why ML works there).
- Firmware is XOR-obfuscated, every block carries a CRC16-CCITT, and the updater
  only accepts Nikon-signed containers. No public exploit exists to run arbitrary code.
- Therefore the realistic maximum is **in-firmware modifications**: change constants,
  tables and code paths inside the stock firmware. That is what NikonHacker does.

## 2. Firmware facts (verified)

| Item | Value |
|---|---|
| D800E 1.11 .bin size | 15,859,842 bytes |
| D800E 1.11 MD5 | 1b033eb7795b13aa137a9170032ba2a7 |
| D800E 1.11 SHA-256 | 8209dd3a57fbc0f5dbc50683aae9daefee60fec016c2afcd43ebc26b9ff0a9c0 |
| Container | header at 0x20: u32be block count, then 32-byte entries; offset @+16, length @+20 |
| Blocks | 2 total: A-fw @0x70 len 0x100002; B-fw @0x100072 len 0xE20000 |
| Obfuscation | XOR with 3 index tables (xor.c), involutive |
| Integrity | CRC16-CCITT (poly 0x1021, init 0) over block minus 2 bytes, stored big-endian at block end |
| CPU (B-fw) | **Fujitsu FR big-endian** - string: "Softune REALOS/FR ... FUJITSU LIMITED 1994-1999" |
| D800 vs D800E 1.11 | ~1.87M differing bytes, all clustered in blocks 4-6 (0x400000-0x6FFFFF); patch region byte-identical |

## 3. Toolchain status on this Mac

Already working:
- `re/nikonfw.py` - decode/xor, block info, extract, search (our tool)
- `re/patchcli/nfpatch` - native macOS rebuild of the official patcher C sources
  (nikon_patch.c + patches.c), plus **new D800E 1.11 patch set added**
- 7-Zip extracts the Nikon .dmg containers without mounting
- OpenJDK 27 installed (needed for the Java emulator and Ghidra)

Still to install when needed:
- Ghidra (not in Homebrew; download release zip from GitHub) + `simeonpilgrim/ghidra_fujitsu_fr`
  processor module for FR disassembly
- `nikon-firmware-tools/Java/Emulator` (FR/TX emulator, already cloned)
- repo `dfr/` C# FR disassembler with `d5100.txt` config template

## 4. Patch inventory for the D800 family

| Model | Version | Status | Features |
|---|---|---|---|
| D800E | 1.02 | Released | 36/54/64 Mbps video |
| D800E | 1.10 | Released + Beta | 36/54/64 Mbps; True Dark Current (BETA) |
| D800 | 1.11 | Alpha | same 4 bitrate patches, never hardware-tested |
| D800E | 1.11 | **none upstream** | - |

Discovered structure: the 1.11 patches are a compact **encoder bitrate table** at
B-fw offset 0x021E2E..0x021EC0, 12 x 4-byte little-endian entries, three groups of 4.
All four bitrate variants only differ in the values written. D800 1.11 and D800E 1.11
are byte-identical across this region, therefore:

**DONE: D800E 1.11 port (alpha parity with D800 1.11)**

- Added `D800E_0111` patch set to patches.c (4 patches, same offsets/values as D800 1.11)
- Registered MD5 1b033eb7795b13aa137a9170032ba2a7 as PatchMap id 57
- Built `patched_D800E_0111.bin` (64 Mbps variant, patch id 3)
- Verified: diffs only at the 12 sites + block CRC; both block CRCs valid; decode round-trip OK

Artifacts:
- `re/patched_D800E_0111.bin` - candidate 64 Mbps firmware, sha256 9de3c24ae5f08eb93b94344a7f53bc3dc1824a52f8bb947dc299d2e1784b75d8
- `re/d800e_0111_patches.diff` - upstreamable diff for Simeon's repo
- `re/patchcli/nfpatch` - `list` / `apply <in> <out> <ids...>`

## 5. Honest risk assessment

- The 1.11 bitrate patches are **Alpha**: per NikonHacker FAQ, alpha means "has never
  run on hardware". The released, hardware-tested route remains: downgrade to 1.10 and
  apply the Released patches.
- A bad flash bricks the body. There is **no user-accessible recovery mode** (no button
  combo, no card rescue, no DFU-style USB mode documented for D800/D800E). But "no recovery"
  is too absolute - there are real, graded paths:
  1. **Service center mainboard swap**: historically ~50% of camera price at Nikon
     (Simeon's D5100 brick quote). Third-party shops do board swaps for far less, and used
     D800/D800E mainboards circulate on eBay. Fastest, most certain, costs money.
  2. **Board-level NAND reflash (chip-off)**: the D800 has a dedicated **Flash PCB** (visible
     in teardowns), and independent repair labs explicitly offer "NAND replacement / firmware
     reflash" for the D800. Since we now hold the exact stock firmware image (byte-identical
     container with valid CRCs), such a lab has everything needed to restore stock.
     Requires desoldering/reballing NAND or SPI flash and an external programmer.
  3. **JTAG**: the NikonHacker team planned JTAG recovery on Simeon's dead D5100 ("send it
     to coderat to try JTAG recovery"), but never published a working method; more than a
     decade later there is still no public JTAG procedure for these bodies.
  So: recovery exists as **paid specialist work**, not as a DIY safety net. Price it before
  flashing anything.
- Risk class matters: the infamous 2013 D5100 brick was caused by a *code* patch (invalid FR
  instruction sequence). Our 1.11 port only changes data-table constants + CRCs - a much
  tamer class - but it is still Alpha (never hardware-tested), so the risk is reduced,
  not eliminated.
- Flashing rules: genuine Nikon battery, fully charged; no third-party battery; no AC/PSU;
  never interrupt; correct card; verify file checksum on card before starting.

## 6. Sacrificial-body strategy (strongly recommended)

1. Buy a used D5100/D3200/D3100 (~$50-120). They are FR-based, community-supported,
   cheap and have the richest patch sets (Liveview manual ISO/shutter, clean HDMI,
   star eater removal, NEF compression).
2. Learn the whole loop there: decode -> patch -> flash -> measure -> revert.
3. Only then consider flashing the D800E, and prefer the Released 1.10 route first.

## 7. Hardware verification protocol (once flashed)

- Bitrate: record 10-20 s of static, detailed scene at each preset; read back with
  `ffprobe` and compare bitrates/file sizes vs stock.
- Stability: 30 min continuous recording, battery warm check, live view in/out cycles.
- Dark current patch (1.10 only): 60 s dark frame, check hot-pixel suppression in RAW.
- Always keep the pristine stock `.bin` on the card for instant revert.

## 8. Research milestones beyond the port

- M1 (done): decode, diff, port, native patcher, candidate image.
- M2 (days): independent review of the port diff. Upstream PR to Simeon is on hold
  (decision 2026-09-26) - the port stays in this repo's own diff for now.
- M3 (days-weeks): extend the same table approach. Findings so far:
  - The 12 patched sites are FR `LDI` instructions (prefix `9F 89`) loading **big-endian
    bitrate constants in bits/sec**: 24,000,000 / 20,000,000 / 12,000,000 / 10,000,000.
  - The patches rewrite them to 64M/60M (HQ pair) and 24M/20M (NQ pair) - exactly the
    documented "NQ old HQ" semantics, which independently validates the port.
  - Untouched records at 0x21F38..0x22038 hold 24M, 12M, 12M, 8M, 9M, 4M, 3M, 6M - they
    likely belong to other video records (other frame-rate banks / 720p / low quality).
  - Next: correlate each record with a UI mode (test recordings or disassembly of the FR
    code around 0x21E00-0x22040 via dfr / Ghidra + ghidra_fujitsu_fr), then it becomes
    possible to offer high-bitrate 720p or other-frame-rate variants that never existed.
    Same mechanism, same risk class (Alpha).
- M4 (weeks-months): code-level work in Ghidra + FR plugin / emulator: port features
  that never existed for D800 family (Liveview manual ISO/shutter like D5100, HDMI
  clean/uncropped experiments, long-exposure automation). This is where the real
  "ML-vision" additions live, and where the emulator saves your camera.

## 9. Commands cheat sheet

```sh
# inspect any Nikon firmware
python3 ~/nikon-tools/re/nikonfw.py info  <file.bin>
python3 ~/nikon-tools/re/nikonfw.py search <file.bin> "D800E"

# list patchable features / apply patches natively
~/nikon-tools/re/patchcli/nfpatch list  D800E_0111.bin
~/nikon-tools/re/patchcli/nfpatch apply D800E_0111.bin out.bin 3

# extract original firmware from Nikon dmg (no mounting)
7zz x -y -odir F-D800E-V111M.dmg
7zz x -y -odir "dir/4.disk image（Apple_HFS：4）"
```

## 10. Open questions

- Confirm B-fw load base / memory maps for FR disassembly (use dfr with D5100 pattern,
  or the emulator's expectations). Needed only for M4.
- Whether Alpha 1.11 table values are electrically correct for the D800E encoder -
  only hardware testing can answer; start on sacrificial body.
- Which presets the untouched table rows at 0x21Fxx belong to.
