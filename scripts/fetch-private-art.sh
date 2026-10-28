#!/usr/bin/env bash
# Installs the paid art the Godot build draws from the private
# TomKlotzPro/pixelheim-assets repo (retro-rpg/shade/): the Medieval Age atlas
# into godot/assets/puny/medieval/ (PIX-133), and every icon
# godot/assets/puny/icons.json names into godot/assets/puny/shade/ (PIX-138),
# and GegX's UI kit as UiStyle's pieces (retro-rpg/gegx/pixel-ui-kit/pixelheim/,
# made by godot/tools/ui_kit_prep.gd) into godot/assets/puny/gegx/ (PIX-385).
# All three folders are git-ignored: the packs may not be redistributed, even
# modified, so they never enter this repo.
#
#   scripts/fetch-private-art.sh            clones the repo (your GitHub login)
#   scripts/fetch-private-art.sh <checkout> uses a checkout already made (CI)
#
# Without it the game still runs on Shade's free art alone: the town's
# houses, props and paid icons are missing (collision is the same).
set -euo pipefail

cd "$(dirname "$0")/.."
if [ $# -ge 1 ]; then
  src="$1"
else
  src="$(mktemp -d)"
  trap 'rm -rf "$src"' EXIT
  git clone --quiet --depth 1 https://github.com/TomKlotzPro/pixelheim-assets.git "$src"
fi
shade="$src/retro-rpg/shade"

mkdir -p godot/assets/puny/medieval
cp "$shade/puny-world-medieval/punyworld-atlas.png" godot/assets/puny/medieval/
echo "Installed godot/assets/puny/medieval/punyworld-atlas.png"

# The paid icons icons.json maps (not "free/..." or "medieval@..."), one file
# per line, sheets once however many cells they give.
count=0
while IFS= read -r file; do
  mkdir -p "godot/assets/puny/shade/$(dirname "$file")"
  cp "$shade/$file" "godot/assets/puny/shade/$file"
  count=$((count + 1))
done < <(python3 - godot/assets/puny/icons.json <<'PY'
import json, sys
doc = json.load(open(sys.argv[1]))
seen = []
for group in ("items", "ailments", "effects", "screens"):
    for src in doc.get(group, {}).values():
        if src.startswith(("free/", "medieval@")):
            continue
        path = src.split("@")[0]
        if path not in seen:
            seen.append(path)
# Skills are "<theme>/<n>" in the Puny Skills pack (ItemIcons.skill_file).
for code in doc["skills"].values():
    theme, n = code.split("/")
    prefix = "Buff" if theme == "Buffs&Debuffs" else theme
    path = "puny-skills/Icons/Transparent Background/%s/%s-Icon-%03d.png" % (theme, prefix, int(n))
    if path not in seen:
        seen.append(path)
print("\n".join(seen))
PY
)
echo "Installed $count icons into godot/assets/puny/shade/"

# GegX's UI kit, prepared (PIX-385): the pieces godot/assets/puny/ui_kit.json names.
kit="$src/retro-rpg/gegx/pixel-ui-kit/pixelheim"
mkdir -p godot/assets/puny/gegx
cp "$kit"/*.png godot/assets/puny/gegx/
echo "Installed $(ls "$kit"/*.png | wc -l | tr -d ' ') UI kit pieces into godot/assets/puny/gegx/"
