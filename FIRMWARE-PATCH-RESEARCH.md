# Nikon D800E alternative firmware research

Date: 2026-09-26
Camera on hand: D800E, A/B firmware **1.11** (read over USB via gphoto2)

## TL;DR

- Magic Lantern is Canon-only and always will be. CHDK is Canon compacts only.
- The only Nikon alternative-firmware project is **NikonHacker "Nikon Patch"** (Simeon Pilgrim).
  It is a **static binary patch of the stock firmware**, not a runtime OS - it cannot add
  arbitrary live control like ML overlays. It ships fixed features only.
- For the D800E, patches exist for firmware **1.02 and 1.10 only**. There is **no 1.11 patch**
  (even the D800, non-E, only has untested alpha ports for 1.11).
- So patching this body means **downgrading 1.11 -> 1.10 first**, then flashing a patched 1.10.
- What you gain (1.10 patch list): 36 / 54 / 64 Mbps 1080p video, and BETA
  "True Dark Current - Menu based". Nothing else.
- Full runtime control (ISO, shutter, WB, focus, live view, movie, bracketing, HDR,
  RAW compression...) is already available over USB without touching firmware. See the
  gphoto2 scripts in this folder.

## Features per firmware version (D800E)

| Firmware | Patches |
|---|---|
| 1.02 | Video 1080 HQ 36/54/64 Mbps Bit-rate NQ old HQ |
| 1.10 | Video 1080 HQ 36/54/64 Mbps Bit-rate NQ old HQ, BETA - True Dark Current (menu based) |
| 1.11 | none for D800E (D800 has alpha-only 1.11 ports) |

## Official firmware downloads (verified live 2026-09-26, HTTP 200)

Nikon only lists 1.11 on its public download page now, but old firmware is still hosted on
Nikon's download servers:

- 1.10 macOS: http://download.nikonimglib.com/archive1/aJHz7007pqyh01ze1Kw05tVQ7T34/F-D800E-V110M.dmg
- 1.10 Windows: http://download.nikonimglib.com/archive1/pN4Ti00S9UAm01j6W2605Kr7yq33/F-D800E-V110W.exe
- 1.02 macOS: https://download.nikonimglib.com/archive1/g5VaI00ylAhA0057KTB55LrQRu46/F-D800E-V102M.dmg
- 1.02 Windows: https://download.nikonimglib.com/archive1/SBrxd00gymvS00myBV955BcXnw45/F-D800E-V102W.exe

Extract -> you get `D800E_0110.bin` (or `D800E_0102.bin`).

## Patch tool

- https://simeonpilgrim.com/nikon-patch/nikon-patch.html (WebAssembly, works in Safari/Chrome)
- Mirrors: https://www.amazinggoose.com/nikon-patch/nikon-patch.html
  and https://dyk3v11u6y5ii.cloudfront.net/nikon-patch/nikon-patch.html

## Exact procedure

1. Fully charge a **genuine Nikon battery**. No third-party battery, no AC/PSU during flash.
2. Download the 1.10 firmware, mount the .dmg, copy `D800E_0110.bin` out.
3. Open the patch tool, Browse -> `D800E_0110.bin`, tick the features, "Save Patched Firmware File".
4. Rename the downloaded `patched_D800E_0110.bin` back to **`D800E_0110.bin`**.
5. Format an approved card **in the camera**, then copy the .bin to the card root (no folders).
6. Insert card in the primary slot, camera on, Setup menu -> **Firmware version** -> update.
   Never power off or remove the card during the flash.
7. Reverting: flash the untouched original `.bin` exactly the same way. Nikon does not block
   installing older/newer official firmware.

## Risks and caveats (from the NikonHacker FAQ and release notes)

- Release-status patches have been tested by the community; BETA is riskier; ALPHA means
  "has never run on hardware" - the team has bricked D5100/D3100 units during alpha testing.
  On the D800E, the bitrate patches are release status; **True Dark Current is BETA**.
- A brick means mainboard replacement. This body is a D800E, so weigh that.
- Nikon notice for D800/D800E: check Lexar 400x/1000x CF card compatibility before flashing.
- High-bitrate clips hit the 4 GB card file-size limit faster, so recordings get shorter.
- In-camera playback of patched high-bitrate videos may not work.
- Downgrading 1.11 -> 1.10 loses the 1.11 fixes (mostly UT-1 network/FTP features and
  small bug fixes), not image-quality changes.
- Keep `Save/load settings` backups off; do not restore old settings files across firmware
  versions (Nikon explicitly warns about 1.10+ settings compatibility).

## Verdict

Patching this D800E buys higher video bitrate and (BETA) dark-current removal, at the risk of
flashing a modified binary and losing 1.11. It adds **no new real-time parameter control**.
For "full control" the gphoto2 route already wins: everything is controllable over USB today,
with zero brick risk. Decision on file: research only, camera left untouched.
