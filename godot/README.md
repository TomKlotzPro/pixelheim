# Pixelheim — Godot

The Godot 4.7 rewrite of Pixelheim ([Godot Migration](https://linear.app/pixelheim/project/godot-migration-4ba6c77b3226) project). The React/Pixi web game in the repo root stays the source of truth for game data (maps, tiles, balance) until it is sunset.

## Run

```sh
godot --path godot            # play (or open godot/ in the Godot editor)
```

Combat runs on the web game's numbers: the hero's real HP and stats, each
species' stats per region, elites, ailments (a web turn = 1 s), drops, xp and
level-ups; defeat wakes you at the inn. Monsters stand in packs at the web's
visible spawn points and stay cleared until you leave the map.

Controls: WASD/arrows or left stick to move, Space/J or gamepad A to attack,
E to talk or open chests, M/Tab for the map, Esc (gamepad Start) for saves.

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

The saves screen (Esc) plays, starts or clears slots and brings heroes across
from the web game (`scripts/saves_screen.gd`, `state/web_import.gd`):

- **Same browser**: the Godot build is served from the web game's origin, so
  it reads the web save from `localStorage` (`pixelheim-save-v1`). A first
  visit with no Godot saves offers to bring that hero over right away.
- **Anywhere else**: paste the code from the web game's Options → Copy save
  code (raw save JSON works too). `C` copies a Godot hero's code back for the
  web game's Import save code.

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
godot --path godot -- --screenshot fight kill         # swing until it dies (rewards in the battle log)
godot --path godot -- --screenshot fight kill hurt --foe wyvern   # another foe, and let it bite back
godot --path godot -- --screenshot talk --map town_shop   # talk to the map's first villager
godot --path godot -- --screenshot near --map town_hall   # stand beside them (the "!" prompt)
godot --path godot -- --screenshot shop --map town_smith --tab 2   # a keeper's counter (500g), tab by index
godot --path godot -- --screenshot hall --map town_hall   # the town ledger (20000g); `bank` for Mirelle's
godot --path godot -- --screenshot --map town --town-tier 4  # preview the village at another age
godot --path godot -- --screenshot home --map town_house --house-tier 3 --mode nook  # a house fixture (storage|workbench|trophies|nook|furniture)
godot --path godot -- --screenshot lineup             # every hero role, villager and monster sheet, walking down and right
godot --path godot -- --screenshot saves              # the saves screen
godot --path godot -- --screenshot saves --web-save res://test/fixtures/web_save_v4.txt
                                                      # first-visit web import offer
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
- `scripts/npcs.gd` / `scripts/npc.gd` / `scripts/dialogue_box.gd` — villagers: who lives where (ported from `src/world/npcs.ts`), their pacing, and conversations
- `scripts/state/economy.gd` + `scripts/shop_screen.gd` — shops, forge and crafting rules (ported from `src/game/economy`) and the keeper's counter
- `scripts/state/town.gd` + `scripts/{town_hall,bank}_screen.gd` (on `ledger_screen.gd`) — town tiers, deeds, the bank, recruits, the inn
- `scripts/state/quests.gd` + `scripts/journal_screen.gd` — the villagers' quests (ported from `src/game/quests.ts`): a giver's first word accepts, kills tick bounties, deliveries leave the pack on turn-in (`GameState.resolve_quests`); Q opens the journal
- `scripts/state/ranks.gd` + `scripts/rankup_screen.gd` — rank titles, auras and presence every five levels (ported from `src/game/hero/ranks.ts`), the Path Graph's choices (`hero/paths.ts`, `GameState.choose_path`), and the ascension scene that plays when a rank is crossed, holding at a fork for the path cards
- `scripts/state/skills.gd` + `scripts/stats_screen.gd` + `scripts/skills_screen.gd` — the stat sheet (ported from `hero/statInfo.ts`, `applyStatPoint`) on C and the skill tree with the Path Graph (`hero/skillTree.ts`, `SkillTree.tsx`) on K; points are spent through `GameState.spend_stat_point` / `buy_skill_node`
- `scripts/codex_screen.gd` — the codex on B (ported from `Codex.tsx`): family masteries with their Slayer tiers, and the bestiary of every monster whose family the hero has met
- `scripts/state/dungeons.gd` + `scripts/dungeon_screen.gd` + `scripts/dungeon_floor.gd` — the two dungeons and their fifteen floors (ported from `src/game/hero/levels.ts`), the gate's floor select, and the floors the hero walks: generated from the floor number, one room per web encounter with the guardian last; the save keeps the hero at the gate while below (`GameState.clear_floor` pays a first clear)
- `scripts/puny_sheet.gd` / `scripts/puny_dungeon.gd` — one Shade tileset with its `.tsx` (animations, wang corners, a lazily built TileSet), and Puny Dungeon's wall grammar, stone, torches, barrels and stairs
- `scripts/home_screen.gd` — the house's barrel, workbench, trophy shelf, nook and furniture placement (house rules live in `state/town.gd`)
- `scripts/ui_style.gd` — the menus' shared palette and widgets until the UI suite (PIX-127)
- `assets/sprites/` — Pixelheim generated art (synced from `public/sprites/`)
- `assets/puny/` — art by Shade, CC0 (`LICENSE.txt`): characters (hero, villagers, bestiary) from [Puny Characters + PunyMonsters](https://merchant-shade.itch.io/16x16-puny-characters) and [Mini World Sprites](https://merchant-shade.itch.io/16x16-mini-world-sprites), the overworld from [Puny World](https://merchant-shade.itch.io/16x16-puny-world) and stone from [Puny Dungeon](https://merchant-shade.itch.io/16x16-puny-dungeon). `scripts/puny_art.gd` assigns who wears which sheet; `scripts/puny_terrain.gd` lays Puny World over the maps (wang corners on the dual grid, read from Shade's Tiled `.tsx`), raises ramparts, bridges and skylines, and `shaders/region_tint.gdshader` tones ash and mire
- `assets/crawler/` — building roofs, doors, fences, interiors and furniture from the [Pixel Crawler](https://anokolisa.itch.io/free-pixel-art-asset-pack-topdown-tileset-rpg-16x16-sprites) pack by Anokolisa until the buildings move to Puny; license in `TERMS.txt` (commercial use OK, no attribution required, do not resell the assets)
- `assets/crawler/terrain/` — 16px tiles cut from the pack's sheets by `tools/extract_terrain.gd` (committed; re-run the tool if crop coordinates change)
- `assets/maps/*.json` — all world maps (grid, spawn, portals) exported from `src/world/maps` by `scripts/export-maps.ts`; regenerate with `pnpm godot:sync`
- `assets/data/catalog.json` — item, role and skill data the save layer needs, exported by the same script
- `assets/data/npcs.json` — villagers and recruits with their lines, exported by the same script
- `assets/data/economy.json` — shops and their stock per unlocked floor, recipes, stations, rarities
- `assets/data/town.json` — town tiers, deeds, rest and bank tuning; `assets/maps/town@N.json` / `town_house@N.json` are the tier redraws
