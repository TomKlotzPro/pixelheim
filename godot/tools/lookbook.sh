#!/usr/bin/env bash
# The look book (PIX-220): the same scenes staged the same way every time,
# saved one by one and on a contact sheet, so a change to how the game looks
# is judged before and after. It renders with the browser's renderer
# (Compatibility, what players see) unless --desktop asks for the desktop
# app's (Forward+, wearing the app's look: PIX-227, scripts/desktop_look.gd).
# Quiet: no sound, one window while it runs.
#
#   tools/lookbook.sh                 # lookbook/*.png and lookbook/sheet.png
#   tools/lookbook.sh --perf          # and what each scene's frames cost
#   tools/lookbook.sh --motion        # and each scene filmed: lookbook/motion/
#   tools/lookbook.sh --desktop       # the desktop app's look, into lookbook-desktop/
#   tools/lookbook.sh --desktop --look hdr          # another of its looks
#   tools/lookbook.sh --desktop --looks browser,app  # several, a folder each
#   tools/lookbook.sh --out DIR       # somewhere else (a "before" folder)
#   tools/lookbook.sh --only NAME     # just that shot (e.g. 17_strike)
#   tools/lookbook.sh --compare       # no window: lookbook/ and lookbook-desktop/
#                                     # side by side into lookbook-compare/
set -euo pipefail
cd "$(dirname "$0")/.."
method="gl_compatibility"
out="lookbook"
extra=()
while [ $# -gt 0 ]; do
  case "$1" in
    --desktop) method="forward_plus"; out="lookbook-desktop" ;;
    --perf) extra+=("perf") ;;
    --motion) extra+=("film") ;;
    --look) extra+=("--look" "$2"); shift ;;
    --looks) extra+=("--looks" "$2"); shift ;;
    --out) out="$2"; shift ;;
    --only) extra+=("--only" "$2"); shift ;;
    --compare) exec python3 tools/lookbook_compare.py lookbook lookbook-desktop lookbook-compare ;;
  esac
  shift
done
# -NSAppSleepDisabled: macOS mustn't nap the run while its window is hidden.
godot --rendering-method "$method" --audio-driver Dummy --path . -- --screenshot lookbook --out "res://$out" "${extra[@]+"${extra[@]}"}" -NSAppSleepDisabled YES 2>&1 | grep -E "^LOOK|SCRIPT ERROR|SHADER ERROR|Parse Error"
