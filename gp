#!/bin/bash
# gphoto2 wrapper: defeats macOS ptpcamerad claiming the camera
killall -9 ptpcamerad mscamerad-xpc 2>/dev/null
exec gphoto2 "$@"
