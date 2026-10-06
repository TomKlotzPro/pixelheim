# Pixelheim — Godot

The Godot 4.7 rewrite of Pixelheim ([Godot Migration](https://linear.app/pixelheim/project/godot-migration-4ba6c77b3226) project). The React/Pixi web game in the repo root stays the source of truth for game data (maps, tiles, balance) until it is sunset.

## Run

```sh
godot --path godot            # play (or open godot/ in the Godot editor)
```

Controls: WASD/arrows or left stick to move, Space/J or gamepad A to attack.

## Saves

The game resumes the last slot played (`--slot 1..3` picks one); an empty
slot starts a new hero in the village square. State lives in the `GameState`
autoload (`scripts/state/`) and autosaves within 3 s of any change, at once on
map changes and loot, and when the window closes or loses focus.

Slot files (`user://saves/slot_<n>.json`; IndexedDB on the web export) use
the web game's save format, schema v4 — envelope, migrations and `PXH1.` save
codes are ported in `save_codec.gd` — so a web save loads in Godot and a
Godot save loads in the web game. Device settings live apart in
`user://settings.cfg`.

## Tests

Unit tests use [GUT](https://github.com/bitwes/Gut) (vendored in `addons/gut`):

```sh
godot --headless --path godot --import                       # first run only
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd
```

Config in `.gutconfig.json`; tests live in `test/unit/`.

## Agent verification harness

Headless Godot cannot render, so visual verification drives a real window
briefly, saves `screenshot.png` into `godot/`, and quits. Harness runs play a
fresh throwaway hero and never touch save slots unless `--slot N` is passed:

```sh
godot --path godot -- --screenshot                    # new hero in the village
godot --path godot -- --screenshot --slot 1           # resume (and write) slot 1
godot --path godot -- --screenshot --map town         # boot into another map
godot --path godot -- --screenshot --walk l,d,d,d     # scripted steps first
godot --path godot -- --screenshot fight              # orc fight, mid-swing
godot --path godot -- --screenshot fight kill         # swing until it dies
```

The final `print` line reports current map id, hero cell, HP and gold for assertions.

## Web export

```sh
mkdir -p godot/export/web
godot --headless --path godot --export-release Web export/web/index.html
python3 -m http.server -d godot/export/web            # play in a browser
```

Single-threaded preset (`export_presets.cfg`): no cross-origin-isolation
headers needed, so any static host works — GitHub Pages included (~9.6 MB
gzipped over the wire). CI deploys it to `/godot/` on the Pages site.

## Layout

- `scenes/main.tscn` — entry scene; all other nodes are built in code
- `scripts/world_tiles.gd` — tile tables ported from `src/world/tiles.ts`
- `scripts/map_data.gd` — loads the JSON maps exported by `pnpm godot:sync` (pure data, unit-tested)
- `scripts/world.gd` — scene orchestration: tilemap, spawns, HUD, harness
- `scripts/state/` — the `GameState` autoload and its typed sections (hero, pack, settlement, progression, world), the save codec, slots and settings
- `scripts/player.gd` / `scripts/enemy.gd` — live combat actors
- `assets/sprites/` — Pixelheim generated art (synced from `public/sprites/`)
- `assets/crawler/` — [Pixel Crawler](https://anokolisa.itch.io/free-pixel-art-asset-pack-topdown-tileset-rpg-16x16-sprites) pack by Anokolisa; license in `TERMS.txt` (commercial use OK, no attribution required, do not resell the assets)
- `assets/crawler/terrain/` — 16px fill tiles cut from the pack's sheets by `tools/extract_terrain.gd` (committed; re-run the tool if crop coordinates change)
- `assets/maps/*.json` — all world maps (grid, spawn, portals) exported from `src/world/maps` by `scripts/export-maps.ts`; regenerate with `pnpm godot:sync`
- `assets/data/catalog.json` — item, role and skill data the save layer needs, exported by the same script
