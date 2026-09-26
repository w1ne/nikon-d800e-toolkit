# Nikon D800E toolkit & firmware reverse-engineering notes

Everything here was developed and verified against a **Nikon D800E on stock firmware
A/B 1.11**, driven from macOS (Apple Silicon).

Three parts:

1. **Full camera control over USB** (gphoto2 scripts: capture, live view, timelapse,
   bracketing, focus stacking, parameter control).
2. **Alternative-firmware research** - what exists for Nikon, and why Magic Lantern
   can never work here.
3. **Firmware reverse engineering** - container format, crypto, the patch system, and a
   **new D800E 1.11 port of the previously D800-only alpha bitrate patches**, built and
   structurally verified with a native macOS patcher.

> **No Nikon firmware binaries are stored in this repo** (copyright Nikon Corporation;
> ~15 MB each). Download links are below. Patch at your own risk: alpha patches have
> bricked test bodies in this community, and the D800E has **no user-accessible recovery
> mode** - see [Recovery options](#recovery-options-if-you-brick).

---

## Part 1 - Full camera control over USB

### Setup

```sh
brew install gphoto2 ffmpeg 7zip openjdk
```

macOS grabs PTP cameras with `ptpcamerad` before gphoto2 can. The `gp` wrapper in this
repo kills it just-in-time and then runs gphoto2:

```sh
cd ~/nikon-tools
./gp --auto-detect          # should show: Nikon DSC D800E
./nikon-status.sh           # model, firmware, battery, lens, settings
```

### Scripts

| Script | What it does |
|---|---|
| `gp` | gphoto2 wrapper that defeats macOS `ptpcamerad` |
| `nikon-status.sh` | camera + settings overview |
| `nikon-set.sh` | set iso / shutter / wb / quality / mode / expcomp, or raw configs |
| `nikon-timelapse.sh <shots> <interval_s> [dir]` | frame-by-frame capture, self-cleaning downloads |
| `nikon-bracket.sh [dir] [-2 -1 0 +1 +2]` | exposure bracketing, restores expcomp |
| `nikon-focus-stack.sh <frames> <step>` | Live View + relative focus drive stepping |
| `nikon-liveview.sh` | live view window (ffplay) or `--record <sec> <out.mp4>` |

Examples:

```sh
./nikon-set.sh iso 800
./nikon-set.sh shutter 1/125          # nearest supported speed is picked
./nikon-set.sh mode M
./nikon-timelapse.sh 100 5 sunset_clip
./nikon-liveview.sh --record 30 take.mp4
```

Live view streams at 640x426 @ 25 fps over plain USB.

### Known limits

- **Aperture is read-only over Nikon PTP.** libgphoto2 refuses writes (verified even at
  the raw property layer). Use the camera dial. qDslrDashboard does support D800/D800E
  aperture over USB if you need it from software.
- **No bulb via PTP** on this body; longest exposure through USB is 30 s.
- Focus drive requires a CPU lens and Live View.

---

## Part 2 - Why can't Nikon have Magic Lantern?

Short version: **Magic Lantern never modifies Canon's firmware.** Canon's bootloader
loads and executes a companion OS (`autoexec.bin`) from the memory card on every boot.
ML hooks Canon's DryOS at runtime; nothing is ever flashed, crashes are recovered by
pulling the card. Nikon's boot process **never executes code from the card**, so every
change requires rebuilding and reflashing the internal firmware image.

| | Canon (ML/CHDK) | Nikon (NikonHacker) |
|---|---|---|
| Code execution | companion OS from card | internal firmware only |
| Firmware files | plain, unpackable | encrypted (XOR tables) + CRC per block + container checks |
| CPU | ARM (DIGIC) | Fujitsu FR / Toshiba TX19A, multiple CPUs per body |
| Iteration | edit card, reboot | flash, pray, no recovery mode |
| Community | 15+ years, dozens of devs | ~6 part-timers, most work on cheap bodies |

The only Nikon route is the **[Nikon Patch](https://simeonpilgrim.com/nikon-patch/nikon-patch.html)**
tool (Simeon Pilgrim / NikonHacker): static patches of the stock firmware.

Known D800-family support (upstream, before this repo):

| Model | Version | Status | Features |
|---|---|---|---|
| D800E | 1.02 | Released | 36/54/64 Mbps video |
| D800E | 1.10 | Released + Beta | 36/54/64 Mbps; True Dark Current (BETA) |
| D800 | 1.11 | Alpha | 4 bitrate patches, never hardware-tested |
| D800E | 1.11 | **none** | **ported here - see Part 3** |

More detail: [`FIRMWARE-PATCH-RESEARCH.md`](FIRMWARE-PATCH-RESEARCH.md) (patching
process, download links for 1.10/1.02, risk rules) and [`re/RE-PLAN.md`](re/RE-PLAN.md)
(the full RE plan, recovery reality, milestones).

---

## Part 3 - Firmware reverse engineering (D800E 1.11)

### Container format

Verified by decoding real firmware and reimplemented in [`re/nikonfw.py`](re/nikonfw.py):

- Header at `0x20`: big-endian u32 block count; then 32-byte entries at `0x30+`, with
  block `offset` at `+16` and `length` at `+20`.
- D800E 1.11 has 2 blocks: **A firmware** at `0x70` (1 MB), **B firmware** at `0x100072`
  (14.75 MB, main UI firmware).
- Whole file is **XOR-obfuscated** with three 256-byte tables indexed by byte 0/1/2
  (see `xor.c` upstream); involution, so decode == encode.
- Every block ends with a **CRC16-CCITT** (poly `0x1021`, init 0) over block-minus-2,
  stored big-endian.
- CPU of B firmware: **Fujitsu FR, big-endian** - confirmed by the in-firmware string
  `Softune REALOS/FR is Realtime OS for FR Family ... FUJITSU LIMITED 1994-1999`.

### The D800E 1.11 port

The 1.11 bitrate patches (upstream: D800 only, Alpha) are 12 FR `LDI` instructions
(prefix `9F 89`) that load **big-endian bitrate constants in bits/sec**:

| Sites (B-fw offsets) | Stock | Patched (64 Mbps variant) |
|---|---|---|
| 0x021E2E, 0x021E5A, 0x021EA6 | 24,000,000 | 64,000,000 |
| 0x021E34, 0x021E60, 0x021EAC | 20,000,000 | 60,000,000 |
| 0x021E42, 0x021E6E, 0x021EBA | 12,000,000 | 24,000,000 |
| 0x021E48, 0x021E74, 0x021EC0 | 10,000,000 | 20,000,000 |

This is precisely the documented "NQ old HQ" semantics. D800 1.11 and D800E 1.11 are
**byte-identical across the whole patch region**, so the port is offset-exact: same
sites, same replacement constants, new MD5 registry entry and model name.

Verified on the resulting image `patched_D800E_0111.bin` (64 Mbps variant, sha256 below,
not committed):

- diffs confined exactly to the 12 sites + block CRC
- both block CRCs recompute valid (`re/nikonfw.py` independent implementation)
- decode/encode round-trip clean

### Native patcher for macOS

Upstream's patcher is C compiled to WebAssembly for the browser (and a C# local UI for
Windows). This repo rebuilds it natively:

```sh
re/patchcli/build.sh          # clones upstream (pinned commit), applies the port diff, builds
re/patchcli/nfpatch list  D800E_0111.bin
re/patchcli/nfpatch apply D800E_0111.bin out.bin 3      # 1=36, 2=54, 3=64, 4=64/36 Mbps
```

The port itself lives in [`re/d800e_0111_patches.diff`](re/d800e_0111_patches.diff),
applied by the build script to upstream at commit `de8019ee` (2026-07-27).

### Firmware downloads (Nikon-hosted, verified live)

- D800E 1.11 (current): via https://downloadcenter.nikonimglib.com/en/download/fw/265.html
- D800E 1.10 (for the released patches): https://download.nikonimglib.com/archive1/aJHz7007pqyh01ze1Kw05tVQ7T34/F-D800E-V110M.dmg
- D800E 1.02: https://download.nikonimglib.com/archive1/g5VaI00ylAhA0057KTB55LrQRu46/F-D800E-V102M.dmg
- D800 1.11 (diff reference): https://download.nikonimglib.com/archive3/HgUC200jB2j403LyzU243RetZF29/F-D800-V111M.dmg

Extract without mounting: `7zz x F-D800E-V111M.dmg` then extract the inner
`*.disk image（Apple_HFS：*)` file.

### Checksums (for verification)

| File | MD5 | SHA-256 |
|---|---|---|
| D800E_0111.bin (stock) | `1b033eb7795b13aa137a9170032ba2a7` | `8209dd3a57fbc0f5dbc50683aae9daefee60fec016c2afcd43ebc26b9ff0a9c0` |
| D800_0111.bin (stock) | `2bc4a74881b08dc0ce67b4f748a0d947` | `fc1273aafd9787a665f662224e4b1aa1e0ff12a5af7befb1e3ec5cd112f6f0ab` |
| patched_D800E_0111.bin (64 Mbps build) | `1ebecf6bdd5ff65346197e7edf522785` | `9de3c24ae5f08eb93b94344a7f53bc3dc1824a52f8bb947dc299d2e1784b75d8` |

### Next steps (M3/M4 in the plan)

- Map the untouched bitrate records at `0x21F38..0x22038` (24M, 12M, 12M, 8M, 9M, 4M,
  3M, 6M) to specific video modes, then extend the same mechanism (e.g. high-bitrate
  720p - something that never existed for the D800 family).
- Code-level features (Live View manual ISO/shutter, HDMI experiments) via Ghidra +
  `ghidra_fujitsu_fr` and/or the NikonHacker FR emulator.

---

## Repo layout

```
.
├── README.md                       # this file
├── FIRMWARE-PATCH-RESEARCH.md      # flash process, risks, firmware links
├── gp                              # gphoto2 wrapper (ptpcamerad workaround)
├── nikon-*.sh                      # USB control scripts
└── re/
    ├── RE-PLAN.md                  # full RE plan + recovery reality + milestones
    ├── nikonfw.py                  # decode/encode, block info, extract, search
    ├── d800e_0111_patches.diff     # the D800E 1.11 port for upstream
    └── patchcli/
        ├── main.c                  # CLI driver (list/apply)
        └── build.sh                # fetches upstream, applies diff, builds nfpatch
```

## Recovery options (if you brick)

There is no DIY recovery mode. Graded options, cheapest first:

1. **Service/mainboard swap** - used D800/E mainboards circulate; third-party shops
   do board swaps. Costs money, near-certain fix.
2. **Chip-off NAND reflash** - the D800 has a dedicated Flash PCB; independent labs
   offer "NAND replacement / firmware reflash". This repo gives you the exact stock
   image and checksums to hand them.
3. **JTAG** - NikonHacker planned it on a dead D5100 years ago (never published a
   working method). Not a realistic DIY path.

Mitigations: test on a cheap sacrificial FR body (D5100/D3200/etc., ~$50-120) first;
prefer Released patches over Alpha; the port here only changes data constants (a tamer
class than the code patch that famously bricked a D5100), but it is still Alpha.

## Credits

- [NikonHacker / Simeon Pilgrim](https://simeonpilgrim.com/nikon-patch/nikon-patch.html) -
  the Nikon Patch tool, firmware decoding, emulator, disassemblers, and the D800 1.11
  alpha patches this port mirrors.
- [libgphoto2/gphoto2](http://gphoto.org/) - all USB control in Part 1.
- [Amazing Goose's patching guide](https://www.amazinggoose.com/nikon-firmware-patch/)
  for preserved firmware archive links.

## License

Our own scripts and documentation: MIT. Upstream tool sources are fetched at build
time and are not redistributed here. Nikon firmware binaries are not included.
