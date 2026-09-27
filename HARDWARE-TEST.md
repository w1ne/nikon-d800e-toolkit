# Hardware test checklist (do this on a sacrificial D800/D800E)

Everything in this repo is emulator/CRC-verified only. Flashing is one-way:
no user recovery, chip-off NAND or mainboard swap is the fallback.

## Before you start

- [ ] Sacrificial body + recovery budget (NAND reflash service / used mainboard)
- [ ] Genuine, fully charged battery; camera-formatted card (fast CF or SD)
- [ ] Pristine `D800E_0111.bin` (stock) on the card for instant revert
- [ ] Baseline drill: flash stock once, confirm the update flow and that you can
      revert, before any modified image

## Stage 1 - bitrate ladder (data patches)

Build each image with: `./re/make-mod.sh <stock.bin> <outdir> <ids...>`

- [ ] id 1 (1080p 36 Mbps): record 10 s of 1080/30p HQ; check with
      `./nikon-check-bitrate.sh --from-camera <index>` (expect ~30-36 Mbps)
- [ ] 30 min continuous recording; watch for stops, heat, card errors
- [ ] id 2 (54 Mbps): same checks
- [ ] id 3 (64 Mbps): same checks; also 1080/24p and 1080/25p
- [ ] ids 3 5 6 (adds 720p60/50 64 Mbps, 720p30/25 24 Mbps): 720p checks
- [ ] Live view in/out cycles, power cycle, menu responsiveness

Note: at 64 Mbps the 4 GB file-size limit arrives ~2.5x sooner - expect short
clips; that is normal.

## Stop conditions (revert immediately)

- Boot loop, black screen, unresponsive menus, repeated recording aborts,
  overheating beyond normal, card "ERR" on new cards.

## Revert

Flash the pristine stock `D800E_0111.bin` exactly like any update, or flash it
from the camera with `./re/make-mod.sh <stock.bin> out 0` is NOT valid - simply
copy the stock file. Keep it on the card at all times while testing.

## Stage 2 - hook PoC (only after Stage 1 passes and caves are validated)

- `re/tools/fr-hook/` injects code into a 0xFF cave; before flashing:
  - [ ] confirm the cave region is really mapped/executable (try the small
        cave variant first; see `re/d800e/CODE-MOD-GROUNDWORK.md` section 1)
  - [ ] pick a marker RAM address verified to be unused
  - [ ] the identity hook should be invisible (matrix unchanged); the
        `--force-quality` build visibly turns HQ modes into NQ bitrates - use it
        to confirm execution on hardware, then revert to stock.

## Record results here (append after testing)

```
date, body, image sha256, patch ids, observations
```
