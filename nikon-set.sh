#!/bin/bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
GP="$DIR/gp"

usage() {
  cat <<'EOF'
usage: nikon-set.sh <what> <value>
  iso <50..25600>          e.g. nikon-set.sh iso 800
  shutter <1/125|2s|0.05>  nearest supported speed is chosen
  wb <name|index>          Automatic Daylight Fluorescent Tungsten Flash Cloudy Shade "Color Temperature"
  quality <name|index>     "JPEG Fine" "NEF (Raw)" "NEF+Fine" ...
  mode <M|P|A|S>
  expcomp <stops>          e.g. -1.3, 0, +2 (1/3 stops, -5..+5)
  raw </main/...>=<value>  pass a raw gphoto2 config
note: aperture (f-number) is read-only over Nikon PTP - use the camera dial / lens ring.
EOF
}

resolve_choice() {
  local cfg="$1" want="$2"
  "$GP" --get-config "$cfg" 2>/dev/null | awk -v want="$want" '
    /^Choice:/ {
      idx=$2; $1=""; $2="";
      sub(/^ +/, "");
      val=$0;
      lval=tolower(val); lwant=tolower(want);
      if (lval==lwant) { print idx; found=1; exit }
      if (lval ~ "^" lwant) { if (!found) { print idx; found=1 } }
    }'
}

cmd="${1:-}"; val="${2:-}"
case "$cmd" in
  iso)
    [ -n "$val" ] || { usage; exit 1; }
    "$GP" --set-config "/main/imgsettings/iso=$val" ;;
  shutter)
    [ -n "$val" ] || { usage; exit 1; }
    case "$val" in
      */*) secs=$(awk "BEGIN{printf \"%.6f\", $val}") ;;
      *s)  secs="${val%s}" ;;
      *)   secs="$val" ;;
    esac
    best=$("$GP" --get-config /main/capturesettings/shutterspeed 2>/dev/null | awk -v t="$secs" '
      BEGIN { best = 1e9; bi = "" }
      /^Choice:/ {
        idx=$2; $1=""; $2=""; sub(/^ +/, ""); v=$0; sub(/s$/, "", v);
        d = v - t; if (d < 0) d = -d;
        if (d < best) { best = d; bi = idx; bv = v }
      }
      END { if (bi != "") print bi }')
    [ -n "${best:-}" ] || { echo "could not resolve shutter speed" >&2; exit 1; }
    "$GP" --set-config "/main/capturesettings/shutterspeed=$best" ;;
  wb)
    [ -n "$val" ] || { usage; exit 1; }
    idx=$(resolve_choice /main/imgsettings/whitebalance "$val")
    [ -n "$idx" ] || { echo "unknown white balance: $val" >&2; exit 1; }
    "$GP" --set-config "/main/imgsettings/whitebalance=$idx" ;;
  quality)
    [ -n "$val" ] || { usage; exit 1; }
    idx=$(resolve_choice /main/capturesettings/imagequality "$val")
    [ -n "$idx" ] || { echo "unknown quality: $val" >&2; exit 1; }
    "$GP" --set-config "/main/capturesettings/imagequality=$idx" ;;
  mode)
    case "$val" in
      M|m) i=0 ;; P|p) i=1 ;; A|a) i=2 ;; S|s) i=3 ;;
      *) echo "mode must be M, P, A or S" >&2; exit 1 ;;
    esac
    "$GP" --set-config "/main/capturesettings/expprogram=$i" ;;
  expcomp)
    [ -n "$val" ] || { usage; exit 1; }
    idx=$(awk "BEGIN{printf \"%d\", 15+($val)*3}")
    "$GP" --set-config "/main/capturesettings/exposurecompensation=$idx" ;;
  raw)
    [ -n "$val" ] || { usage; exit 1; }
    "$GP" --set-config "$val" ;;
  *) usage; exit 1 ;;
esac
