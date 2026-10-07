#!/usr/bin/env bash
# Renders the web build's boot splash (assets/splash.png) from the title
# screen itself, through the screenshot harness: rerun it whenever the title
# changes so loading still hands over to it without a jump.
set -euo pipefail

cd "$(dirname "$0")/.."
rm -f screenshot.png
perl -e "alarm 60; exec @ARGV" godot --path . -- --screenshot title splash | grep "screenshot saved"
mv screenshot.png assets/splash.png
godot --headless --path . --import >/dev/null 2>&1
echo "assets/splash.png"
