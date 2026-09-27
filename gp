#!/bin/bash
# gphoto2 wrapper: frees the PTP device from OS helpers that like to grab it.
#   macOS  -> ptpcamerad / mscamerad-xpc
#   Linux  -> gvfsd-gphoto2 / gvfsd-mtp (respawn on demand, harmless to kill)
# Other systems (BSD, WSL...) just run gphoto2.
case "$(uname -s)" in
  Darwin)
    killall -9 ptpcamerad mscamerad-xpc 2>/dev/null
    ;;
  Linux)
    pkill -f gvfsd-gphoto2 2>/dev/null
    pkill -f gvfsd-mtp 2>/dev/null
    ;;
esac
exec gphoto2 "$@"
