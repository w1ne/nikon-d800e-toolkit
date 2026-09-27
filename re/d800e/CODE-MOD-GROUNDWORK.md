# Code-mod groundwork: free space, container validation, recovery

Research notes (2026-09-27) for anything beyond constant-level patches. All
offsets are file offsets; B-firmware memory = file + 0x40000.

## 1. Free space (0xFF runs)

| image | file offset | length | memory | notes |
|---|---|---|---|---|
| B | 0x6009E8 | 0x3DF618 (4.06 MiB) | 0x6409E8 | biggest cave; sits between code and the resource/string area |
| B | 0x092758 | 0xD498 (54 KiB) | 0x4D2758 | amid early code |
| B | 0x0A0000 | 0x20000 (128 KiB) | 0x4E0000 | aligned, amid code |
| B | 0x27E1FB | 0x101 | 0x2BE1FB | small |
| B | 0x3BADF0 | 0x47C (1.1 KiB) | 0x3FADF0 | small |
| B | 0x576648 | 0x54A8 (21 KiB) | 0x5B6648 | amid resources |
| B | 0x57C100 | 0x9DC0 (40 KiB) | 0x5BC100 | amid resources |
| B | 0xDCE534 | 0x51ACA (334 KiB) | 0xE0E534 | tail padding |
| A | 0x0BD12C | 0x42ECC (274 KiB) | (A: +0xBFC00000) | tail padding |

Caveats: FR memory is flat, but we cannot verify from software which regions
are mapped/executable at runtime; the 4 MiB cave is the most attractive but the
least verified. First code-hook experiment should use a small cave inside the
same region as the target code (e.g. 0x092758 or 0x0A0000) so a bad guess is
easy to reason about.

## 2. Container validation

Container layout (decoded):

```
0x00..0x1F   two 16-byte values (build fingerprints)
0x20         u32 BE block count (2)
0x30+        32-byte entries: name[16], offset u32, length u32, 8 bytes zero
0x70         block 0 (A), CRC16-CCITT in last 2 bytes
0x100072     block 1 (B), CRC16-CCITT in last 2 bytes
```

Findings:

- The 32 header bytes are **not** MD5 of either block (decoded, encoded, or
  without CRC) - tested. They stay untouched by `nfpatch`/`repack` and patched
  cameras boot fine, so the update path does not enforce them against block
  contents.
- The only block-level check observed anywhere is the **CRC16-CCITT** (poly
  0x1021, init 0, big-endian, over block-minus-2). Empirical proof this is the
  acceptance check: NikonHacker released CRC-fixed patched images for many
  bodies for 10+ years, including this repo's 1.11 port.
- No signature/RSA/SHA *message* strings exist in either image (the "verif"
  hits in B are UI/network resource text, not firmware validation).
- No anti-rollback was observed: Nikon's own docs and the community workflow
  downgrade 1.11 -> 1.10 freely.
- Caveat: the boot ROM is not part of these images; if it did any extra check,
  it evidently accepts CRC-fixed containers.

## 3. Recovery research (web, 2026-09)

- **No user-accessible recovery mode** on D800/D800E (as before).
- **Chip-off NAND reflash / NAND replacement** is a real service: the D800 has a
  dedicated Flash PCB (teardown galleries), and independent shops list
  "built-in memory (NAND) replacement" plus firmware reflash for modest prices
  (e.g. ~2000 RUB NAND swap, ~1000 RUB firmware flash in one St. Petersburg
  shop). This is the most practical recovery for a bricked body and this repo
  supplies the exact stock image + checksums to hand to such a shop.
- **Mainboard swap**: used D800/E mainboards circulate; Nikon service quoted
  ~50% of body price historically (Simeon's D5100 brick post).
- **JTAG**: attempted on a bricked D5100 by the NikonHacker team; no public
  working method was ever published. No D800 JTAG documentation found.
- **Nikon Self Service Repair** exists but does not list the D800 (products not
  listed are unsupported); D800 teardown/repair guides exist on iFixit and
  third-party teardown sites; D800 service manuals circulate unofficially.
- Conclusion: recovery = chip-off NAND or mainboard swap. Any code-level
  experimentation should budget for one of these, or be done on a second body.

## 4. Related infra notes

- `INT #0x40` = Softune REALOS/FR system-call instruction (`1F 40`, 4042 sites
  in B). Most-used service numbers: `0xD0` (781), `0xD1` (643), `0xD2` (360),
  `0xAB` (309), `0xDB` (249), `0xC9` (236), `0xCB` (176). Naming them requires
  the Softune REALOS syscall table; the counts alone already show where task
  synchronisation happens.
- The 720p bitrate extension is ported to all three supported images:
  D800E 1.11 (md5 `1b033eb7...`), D800 1.11 (md5 `2bc4a748...`),
  D800E 1.10 (md5 `a6a6c6a7748d5acc97e859ad5031ace5`) - `nfpatch` ids 5/6.
