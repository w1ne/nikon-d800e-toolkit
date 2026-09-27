# Running the toolkit: macOS, Linux, Windows

| Part | macOS | Linux | Windows |
|---|---|---|---|
| `re/nikonfw.py` (decode/patch/repack/verify) | yes | yes | yes (native Python 3) |
| `re/patchcli/nfpatch` (firmware patcher) | build with clang | build with gcc | build in **MSYS2** (gcc) or WSL |
| `re/make-mod.sh`, `nikon-*.sh` | yes | yes | yes in **Git Bash / MSYS2 / WSL** |
| USB control (`gp` + gphoto2) | yes | yes | **WSL2 + usbipd-win** (native Windows has no gphoto2) |
| `re/tools/emu-probe` (needs Java + ant build) | yes | yes | yes (WSL/MSYS2 with a JDK) |

## macOS

```sh
brew install gphoto2 ffmpeg python3 7zip openjdk ant
export JAVA_HOME=/opt/homebrew/opt/openjdk   # for the disassembler/emulator tools
```

`gp` kills `ptpcamerad`/`mscamerad-xpc` automatically (the `defaults write
com.apple.ImageCapture disableHotPlug -bool YES` tweak from the README is still
recommended).

## Linux

```sh
# Debian/Ubuntu
sudo apt install gphoto2 ffmpeg python3 p7zip-full build-essential patch git openjdk-17-jdk ant

# Fedora
# sudo dnf install gphoto2 ffmpeg python3 p7zip gcc make patch git java-17-openjdk-devel ant
```

- Camera permissions: most distros ship libgphoto2's udev rules; make sure your
  user is in the `plugdev` group (`sudo usermod -aG plugdev $USER`, then re-login).
  Check with `lsusb` and `./gp --auto-detect`.
- Desktop environments: `gp` stops `gvfsd-gphoto2`/`gvfsd-mtp` before talking to
  the camera, so GNOME/KDE auto-mounting won't block PTP.

## Windows

**A. WSL2 (recommended, full feature set including USB control)**

```powershell
wsl --install -d Ubuntu
winget install usbipd
usbipd list                         # find the camera's BUSID
usbipd bind --busid <BUSID>         # once, as admin
usbipd attach --wsl --busid <BUSID> # each time you plug the camera in
```

Inside WSL the setup is the Linux one above; run `./gp --auto-detect`, the
scripts, `make-mod.sh`, `nfpatch`, etc. exactly as documented.

**B. MSYS2 / Git Bash (modding pipeline only, no USB control)**

```sh
# in an MSYS2 UCRT64 shell
pacman -S git patch mingw-w64-ucrt-x86_64-gcc
cd /path/to/nikon-tools && ./re/patchcli/build.sh     # -> nfpatch.exe
```

The Python side (`re/nikonfw.py`) runs with the native Windows Python; the shell
scripts (`re/make-mod.sh`, `nikon-check-bitrate.sh` local-file mode) run in Git
Bash or the MSYS2 shell. `shasum` may be missing in Git Bash; the scripts fall
back to `sha256sum` from coreutils.

## Portability notes

- All shell scripts are plain `bash` (no zsh/bash-4-only constructs); anything
  with `#!/bin/bash` also runs under `sh`-compatible bash on WSL/MSYS2.
- `gp` only touches OS camera helpers on macOS (`killall ptpcamerad ...`) and
  Linux (`pkill gvfsd-*`); elsewhere it just runs `gphoto2`.
- `re/nikonfw.py` is stdlib-only; `nikon-check-bitrate.sh` needs `ffprobe`.
- The disassembler/emulator tools are the cross-platform NikonHacker Java
  suite (built with `ant`); the emulator probe in `re/tools/emu-probe/run.sh`
  finds `java`/`javac` on PATH or via `JAVA_HOME`.
