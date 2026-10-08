#!/usr/bin/env bash
# Installs the paid art the Godot build draws from the private
# TomKlotzPro/pixelheim-assets repo (retro-rpg/shade/): the Medieval Age atlas
# into godot/assets/puny/medieval/ (PIX-133), and every icon
# godot/assets/puny/icons.json names into godot/assets/puny/shade/ (PIX-138).
# Both folders are git-ignored: the packs may not be redistributed, so they
# never enter this repo.
#
#   scripts/fetch-private-art.sh            clones the repo (your GitHub login)
#   scripts/fetch-private-art.sh <checkout> uses a checkout already made (CI)
#
# Without it the game still runs, with the town's old buildings and props and
# the web's item icons.
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
for group in ("items", "ailments"):
    for src in doc[group].values():
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
