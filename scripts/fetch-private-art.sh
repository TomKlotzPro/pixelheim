#!/usr/bin/env bash
# Installs the paid art the Godot build draws (PIX-133) from the private
# TomKlotzPro/pixelheim-assets repo into godot/assets/puny/medieval/, which git
# ignores: the pack may not be redistributed, so it never enters this repo.
# Needs read access to that repo (your GitHub login). Without it the game
# still runs, with the town's old buildings.
set -euo pipefail

cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git clone --quiet --depth 1 https://github.com/TomKlotzPro/pixelheim-assets.git "$tmp"
mkdir -p godot/assets/puny/medieval
cp "$tmp/puny-world-medieval/punyworld-atlas.png" godot/assets/puny/medieval/
echo "Installed godot/assets/puny/medieval/punyworld-atlas.png"
