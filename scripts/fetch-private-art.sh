#!/usr/bin/env bash
# Installs the paid art the Godot build draws from the private
# TomKlotzPro/pixelheim-assets repo (retro-rpg/shade/): the Medieval Age atlas
# and its sample characters (PIX-405) into godot/assets/puny/medieval/
# (PIX-133), and every icon
# godot/assets/puny/icons.json names into godot/assets/puny/shade/ (PIX-138),
# and GegX's UI kit as UiStyle's pieces (retro-rpg/gegx/pixel-ui-kit/pixelheim/,
# made by godot/tools/ui_kit_prep.gd) into godot/assets/puny/gegx/ (PIX-385),
# and ninth-jedi's Farm Animals (retro-rpg/ninth-jedi/farm-animals/) into
# godot/assets/puny/animals/ (PIX-387), and Leohpaz's sounds as the game
# plays them (retro-rpg/leohpaz/pixelheim/, made by godot/tools/sound_prep.py)
# and his RPG music (retro-rpg/leohpaz/music/, made by
# godot/tools/music_prep.py, PIX-416) into godot/assets/audio/paid/ (PIX-411).
# All five folders are git-ignored: the packs may not be redistributed, even
# modified, so they never enter this repo.
#
#   scripts/fetch-private-art.sh            clones the repo (your GitHub login)
#   scripts/fetch-private-art.sh <checkout> uses a checkout already made (CI)
#
# Without it the game still runs on Shade's free art alone: the town's
# houses, props and paid icons are missing (collision is the same), and
# every sound and track is the game's own.
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

# The pack's sample folk PunyArt.VILLAGERS' "paid" sheets name (PIX-405),
# faces for the folk who talk: only those, as the export takes every file
# in the folder.
rm -rf godot/assets/puny/medieval/characters
mkdir -p godot/assets/puny/medieval/characters
for sheet in $(grep -o 'medieval/characters/[A-Za-z-]*\.png' godot/scripts/puny_art.gd | sort -u); do
  cp "$shade/puny-world-medieval/Sample 32 by 32 Characters/$(basename "$sheet")" godot/assets/puny/medieval/characters/
done
echo "Installed $(ls godot/assets/puny/medieval/characters/*.png | wc -l | tr -d ' ') sample characters into godot/assets/puny/medieval/characters/"

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
for group in ("items", "ailments", "effects", "screens", "stats"):
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

# ninth-jedi's Farm Animals (PIX-387): each animal's walk and sleep frames,
# named simply: "Chicken 1 (16x16)/Walk/walk1.png" is chicken1_walk1.png.
farm="$src/retro-rpg/ninth-jedi/farm-animals"
mkdir -p godot/assets/puny/animals
count=0
for dir in "$farm"/*/; do
  name="$(basename "$dir" | sed 's/ (.*//; s/ //g' | tr '[:upper:]' '[:lower:]')"
  for frame in "$dir"Walk/walk*.png "$dir"Sleep/sleep*.png; do
    cp "$frame" "godot/assets/puny/animals/${name}_$(basename "$frame")"
    count=$((count + 1))
  done
done
echo "Installed $count farm animal frames into godot/assets/puny/animals/"

# Leohpaz's sounds, prepared (PIX-411): each event's takes and the list the
# game reads them by (godot/assets/audio/paid.json names where each is from).
sounds="$src/retro-rpg/leohpaz/pixelheim"
rm -rf godot/assets/audio/paid
mkdir -p godot/assets/audio/paid
cp "$sounds"/*.wav "$sounds"/takes.json godot/assets/audio/paid/
echo "Installed $(ls "$sounds"/*.wav | wc -l | tr -d ' ') sound takes into godot/assets/audio/paid/"

# Leohpaz's RPG music, prepared (PIX-416): each track's and story theme's
# music and the list the game reads them by (godot/assets/audio/paid_music.json
# names where each is from), beside the sounds. A checkout from before it has none.
music="$src/retro-rpg/leohpaz/music"
if [ -d "$music" ]; then
  cp "$music"/*.ogg "$music"/music.json godot/assets/audio/paid/
  echo "Installed $(ls "$music"/*.ogg | wc -l | tr -d ' ') music tracks into godot/assets/audio/paid/"
fi
