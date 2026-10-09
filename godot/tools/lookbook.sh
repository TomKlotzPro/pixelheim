#!/usr/bin/env bash
# The look book (PIX-220): the same scenes staged the same way every time,
# saved one by one and on a contact sheet, so a change to how the game looks
# is judged before and after. It renders with the browser's renderer
# (Compatibility, what players see) unless --desktop asks for the desktop
# app's (Forward+). Quiet: no sound, one window while it runs.
#
#   tools/lookbook.sh                 # lookbook/*.png and lookbook/sheet.png
#   tools/lookbook.sh --perf          # and what each scene's frames cost
#   tools/lookbook.sh --motion        # and each scene filmed: lookbook/motion/
#   tools/lookbook.sh --desktop       # the desktop renderer, into lookbook-desktop/
#   tools/lookbook.sh --out DIR       # somewhere else (a "before" folder)
set -euo pipefail
cd "$(dirname "$0")/.."
method="gl_compatibility"
out="lookbook"
extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --desktop) method="forward_plus"; out="lookbook-desktop" ;;
    --perf) extra+=("perf") ;;
    --motion) extra+=("motion") ;;
    --out) out="$2"; shift ;;
  esac
  shift
done
godot --rendering-method "$method" --audio-driver Dummy --path . -- --screenshot lookbook --out "res://$out" "${extra[@]+"${extra[@]}"}" 2>&1 | grep -E "^LOOK|SCRIPT ERROR|Parse Error"
