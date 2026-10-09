# Pixelheim — Godot

Pixelheim in Godot 4.7 ([Godot Migration](https://linear.app/pixelheim/project/godot-migration-4ba6c77b3226) project). It began as a React/Pixi web game, retired in v0.75; its maps and data tables now live here (`assets/maps/`, `assets/data/`) and are edited directly.

## Run

```sh
../scripts/fetch-private-art.sh  # once: the paid art (below)
godot --path godot            # play (or open godot/ in the Godot editor)
```

### Paid art

The town's houses, the rooms behind their doors and the props outdoors
(wells, the fountain, torches, fences, stalls, chests) come from Shade's paid
**Puny World Medieval Age** pack (`scripts/puny_town.gd`, `puny_interior.gd`,
`puny_props.gd`; PIX-133, PIX-137). Item, skill and ailment icons come from
his paid Survival, Armor, Jewelry and Puny Skills packs and his free CC0 icon
sheets, mapped in `assets/puny/icons.json` (`scripts/item_icons.gd`,
PIX-138). Their licences forbid redistributing the packs, so they are not in
this repository: they live in the private `TomKlotzPro/pixelheim-assets` repo
under `retro-rpg/shade/`. `scripts/fetch-private-art.sh`
installs the atlas into `godot/assets/puny/medieval/` and every icon
`icons.json` names into `godot/assets/puny/shade/` (both git-ignored) with your
GitHub login; the deploy and the Godot CI run the same script on a checkout
made with a read-only deploy key (secret `PIXELHEIM_ASSETS_KEY`). Without it
the game runs with the town's old buildings and props and the web's item
icons.

Combat runs on the web game's numbers, kept: the hero's real HP and stats, each
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
the old web game's save format, schema v4 — envelope, migrations and `PXH1.`
save codes are ported in `save_codec.gd` — so its heroes load here. Device
settings live apart in `user://settings.cfg`.

The saves screen (Esc) plays, starts or clears slots and brings heroes across
from the retired web game (`scripts/saves_screen.gd`, `state/web_import.gd`):

- **Same browser**: the game is served from the web game's old origin, so it
  still reads that hero from `localStorage` (`pixelheim-save-v1`). A first
  visit with no saves offers to bring them over right away.
- **Anywhere else**: paste a save code (raw save JSON works too). `C` copies a
  hero's code.

## Tests

Unit tests use [GUT](https://github.com/bitwes/Gut) (vendored in `addons/gut`):

```sh
godot --headless --path godot --import                       # first run only
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd
```

Config in `.gutconfig.json`; tests live in `test/unit/`.

## Agent verification harness

Headless Godot cannot render, so visual verification drives a real window
briefly, saves `screenshot.png` into `godot/`, and quits. It lives in
`scripts/harness.gd`, which `world.gd` adds only when `--screenshot` is
passed. Harness runs play a fresh throwaway hero and never touch save slots
unless `--slot N` is passed:

```sh
godot --path godot -- --screenshot                    # new hero in the village
godot --path godot -- --screenshot --slot 1           # resume (and write) slot 1
godot --path godot -- --screenshot --map town         # boot into another map
godot --path godot -- --screenshot --walk l,d,d,d     # scripted steps first
godot --path godot -- --screenshot --at 40,27 --walk u,u,u  # stand on a cell, then walk: what stops you
godot --path godot -- --screenshot fight              # orc fight, mid-swing
godot --path godot -- --screenshot fight kill         # swing until it dies (rewards in the battle log)
godot --path godot -- --screenshot fight kill hurt --foe wyvern   # another foe, and let it bite back
godot --path godot -- --screenshot talk --map town_shop   # talk to the map's first villager
godot --path godot -- --screenshot near --map town_hall   # stand beside them (the "!" prompt)
godot --path godot -- --screenshot shop --map town_smith --tab 2   # a keeper's counter (500g), tab by index
godot --path godot -- --screenshot station --map town_alchemist   # E at the room's first cauldron or forge (report: tab=Craft)
godot --path godot -- --screenshot hall --map town_hall   # the town ledger (20000g); `bank` for Mirelle's
godot --path godot -- --screenshot --map town --town-tier 4  # preview the village at another age
godot --path godot -- --screenshot home --map town_house --house-tier 3 --mode nook  # a house fixture (storage|workbench|trophies|nook|furniture)
godot --path godot -- --screenshot lineup             # every hero role, villager and monster sheet, walking down and right
godot --path godot -- --screenshot saves              # the saves screen
godot --path godot -- --screenshot saves --web-save res://test/fixtures/web_save_v4.txt
                                                      # first-visit web import offer
godot --path godot -- --screenshot --map town portal  # walk into the nearest doorway
godot --path godot -- --screenshot die                # fall, then wake at the inn
godot --path godot -- --screenshot title splash       # the title as the boot splash
godot --path godot -- --screenshot title options     # options over the title, before any hero
godot --path godot -- --screenshot title --wait 8      # hold the shot (the dragon crosses the moon about 8 s in)
godot --path godot -- --screenshot title still        # with Reduce motion on (no sway, drift, dragon or shine)
godot --path godot -- --screenshot title --keys enter --wait 6.5   # the opening, mid-way (Fafnyr wakes); `--keys enter,esc` skips it
godot --path godot -- --screenshot --floor 10 --wait 2.5   # a boss floor: its intro plays the first time (Fafnyr; 15 for Morvax)
godot --path godot -- --screenshot --story ending --wait 20  # any story scene over the world (descent, ending: the credits roll)
godot --path godot -- --screenshot title --keys s,s,s # walk the title's menu with real keys (w, s, e, enter, esc, space)
godot --path godot -- --screenshot dockmenu           # the dock's menu of screens, open
godot --path godot -- --screenshot inventory --keys i # press keys at whatever screen the run opened (here: I closes the pack)
godot --path godot -- --screenshot --map town --look browser   # the desktop renderer in another of the app's looks (below)
```

The final `print` line reports the map id, hero cell, HP, gold, the save's place, draw calls, whether the world is held still (`paused=`) and which screens are open (`open=`), for assertions.

### Release flows

`godot/tools/flows.sh` runs the flows a release must not break (spawn,
portal, chest, shop, craft, quest, rank-up, fight, death and the inn, saves,
reading a conversation to its end, leaving one with Esc, and walking without
the camera shake)
through the harness. Each one checks the harness's report line and leaves its
picture in `godot/flows/<name>.png` (gitignored). `godot/tools/flows.sh fight die`
runs just those. It needs a window, so it runs locally, not in CI.

### Boot splash

The web build loads behind `assets/splash.png`, which is the title screen
without its menu or parade, and the loading bar sits where the menu will
appear (`html/head_include` in `export_presets.cfg`). Rerun
`godot/tools/splash.sh` whenever the title changes.

### Icon

`assets/icon.png` is the game's icon: the web build's favicon and home-screen
icon, and the desktop window's (`config/icon`). It is the title's gold P on the
title's night, drawn pixel by pixel on a 32x32 grid by `godot/tools/favicon.py`
(Pillow) and saved at 16x so every size Godot makes from it stays crisp.

## Web export

```sh
mkdir -p godot/export/web
godot --headless --path godot --export-release Web export/web/index.html
python3 -m http.server -d godot/export/web            # play in a browser
```

Single-threaded preset (`export_presets.cfg`): no cross-origin-isolation
headers needed, so any static host works — GitHub Pages included (~9.6 MB
gzipped over the wire). The deploy puts it at the root of the Pages site; old
`/classic/` and `/godot/` links lead there.

## Desktop app

The browser build stays the main one; the same project also exports as an
app for macOS (universal, ad-hoc signed, not notarized) and Windows (x86_64,
one `.exe` with the game inside). `.github/workflows/desktop.yml` builds both
on every pull request and push to `main` and uploads them as the
`pixelheim-macos` and `pixelheim-windows` artifacts (the Mac app stays in
Godot's own zip, which keeps its binary executable: unzip twice). Locally,
with the macOS and Windows export templates installed:

```sh
godot --headless --path godot --export-release macOS export/macos/Pixelheim.zip
godot --headless --path godot --export-release Windows export/windows/Pixelheim.exe
```

The app runs the desktop renderer (Forward+), and where it runs in a window
it wears the app's look (`scripts/desktop_look.gd`, PIX-227); the browser, a
headless run or a desktop that fell back to the Compatibility renderer keep
the browser's:

- **An HDR canvas**: the 2D world drawn in linear light, sixteen bits a
  channel, debanded, so lamps and the glow fall off into the night without
  bands. Every pass over the world reads and writes through
  `shaders/linear.gdshaderinc`, which compiles away in the browser, so its
  thresholds and tints hold on both canvases; light colours are made linear
  to keep their hue (`DesktopLook.canvas_color`).
- **A wider glow at night**, on top of the browser's own: what's brighter
  than a threshold is marked in the screen's alpha (`glow_mask.gdshader`,
  last on the LightRig's layer) before the blur, and `glow_wide.gdshader`,
  alone on a canvas layer of its own under the HUD, spreads it soft and far,
  so a small flame glows as far as it is bright. The renderer's own glow (a
  WorldEnvironment) was tried and dropped: everything drawn after its pass,
  the HUD included, came out lifted, and lamplit rooms washed out.

Saves are the browser's format: the app keeps its slots in
`user://saves/slot_<n>.json` under the pinned user dir
(`~/Library/Application Support/pixelheim/`, `%APPDATA%\pixelheim\`), the
same files every desktop run uses; save codes carry a hero between the app
and the browser. Screenshots of a linear canvas go through
`DesktopLook.snapshot`, which turns its light into the screen's colours.

`--look NAME` wears another of the app's looks for a run (`browser`, `hdr`,
`app`, `app_bright`; `DesktopLook.LOOKS`). The look book shows the difference:

```sh
godot/tools/lookbook.sh                              # the browser's renderer: lookbook/
godot/tools/lookbook.sh --desktop                    # the app's look: lookbook-desktop/
godot/tools/lookbook.sh --desktop --looks browser,app  # both on the desktop renderer, a folder each
godot/tools/lookbook.sh --compare                    # no window: lookbook/ | lookbook-desktop/ side by side in lookbook-compare/
python3 godot/tools/lookbook_compare.py godot/lookbook-desktop/browser godot/lookbook-desktop/app godot/lookbook-compare
```

## Layout

- `scenes/main.tscn` — entry scene; all other nodes are built in code
- `scripts/world_tiles.gd` — what each tile lets the hero do (walkability) and its colour on the map
- `scripts/map_data.gd` — loads the JSON maps in `assets/maps/` (pure data, unit-tested)
- `scripts/world.gd` — the play: entering maps, the hero, villagers and monsters, the HUD, interaction, combat, music
- `scripts/map_view.gd` — one visit to a map as drawn (PIX-136): Shade's ground, houses, rooms and dungeons, props, field scatter, chests, door signs, the house's furniture and the invisible blockers; `plan` marks what all that covers on the map before anything is drawn, `build` draws it behind the world's y-sorted actors
- `scripts/harness.gd` — the screenshot harness below, added only for `--screenshot` runs
- `scripts/state/` — the `GameState` autoload and its typed sections (hero, pack, settlement, progression, world), the save codec, slots and settings
- `scripts/player.gd` / `scripts/enemy.gd` — live combat actors
- `scripts/npcs.gd` / `scripts/npc.gd` / `scripts/dialogue_box.gd` — villagers: who lives where (ported from `src/world/npcs.ts`), their pacing, and conversations
- `scripts/state/economy.gd` + `scripts/shop_screen.gd` — shops, forge and crafting rules (ported from `src/game/economy`) and the keeper's counter
- `scripts/state/town.gd` + `scripts/{town_hall,bank}_screen.gd` (on `ledger_screen.gd`) — town tiers, deeds, the bank, recruits, the inn
- `scripts/state/quests.gd` + `scripts/journal_screen.gd` — the villagers' quests (ported from `src/game/quests.ts`): a giver's first word accepts, kills tick bounties, deliveries leave the pack on turn-in (`GameState.questing.resolve_quests`); Q opens the journal
- `scripts/state/ranks.gd` + `scripts/rankup_screen.gd` — rank titles, auras and presence every five levels (ported from `src/game/hero/ranks.ts`), the Path Graph's choices (`hero/paths.ts`, `GameState.training.choose_path`), and the ascension scene that plays when a rank is crossed, holding at a fork for the path cards
- `scripts/state/skills.gd` + `scripts/stats_screen.gd` + `scripts/skills_screen.gd` — the stat sheet (ported from `hero/statInfo.ts`, `applyStatPoint`) on C and the skill tree with the Path Graph (`hero/skillTree.ts`, `SkillTree.tsx`) on K; points are spent through `GameState.training.spend_stat_point` / `buy_skill_node`
- `scripts/title_screen.gd` + `scripts/title_scene.gd` + `scripts/create_screen.gd` — the title (PIX-139: Pixelheim's street at night under the smoking Ashen Mountain, built from Shade's art at 2x, with lit windows, torches, the watchman's round, the hero in the street and the dragon crossing the moon; the gold logo; Continue / New Game / Saves / Options / What's new) and hero creation (`CharacterCreation.tsx`: role, look among Shade's colourways, name). A plain launch with no hero keeps an unsaved stand-in behind the title (`GameState.standing_in`) until one is made
- `scripts/cutscene.gd` + `assets/data/story.json` — story moments (PIX-31): a scene is data, ordered steps (stage, fade, caption, tint, ash, shake, actor, eyes, logo, wait) the Cutscene screen plays over a letterboxed stage; E moves on, Esc skips to what comes next, Reduce motion keeps the words and drops the movement. The opening plays on New Game, before hero creation; `moments` in story.json map play to scenes (a boss's floor, the first clear of floor 10, victory), each played once per hero (`storySeen` in the save, written only once there is one)
- `scripts/screen.gd` — what every menu, page and conversation shares (PIX-136): built in `_open`, `dim()` behind, keys through `_command` (handled before they run), Esc / the menu key / its own key close it, and it holds the world still, counted, so the world runs again only when the last screen closes
- `scripts/pause_screen.gd` + `scripts/options_screen.gd` + `scripts/controls.gd` — Esc's pause menu (Resume, Saves, Options, Quit to title) and the options (volumes, CRT scanlines, fullscreen, reduced motion, key rebinding); `Controls` rebuilds the InputMap from `GameSettings.bindings` (one rebindable primary per action plus fixed alternates and the pad)
- `scripts/inventory_screen.gd` — the pack and paperdoll on I (ported from `Inventory.tsx`): nine slots around the hero and the numbers gear makes, everything carried by category; equip, take off, drink, place furniture, drop (`GameState.upkeep.equip` / `unequip` / `use_item` / `drop_item` / `drop_gear`). item icons are Shade's (`scripts/item_icons.gd`, `assets/puny/icons.json`), and a Craft tab guides crafting
- `scripts/codex_screen.gd` — the codex on B (ported from `Codex.tsx`): family masteries with their Slayer tiers, and the bestiary of every monster whose family the hero has met
- `scripts/state/dungeons.gd` + `scripts/dungeon_screen.gd` + `scripts/dungeon_floor.gd` — the two dungeons and their fifteen floors (ported from `src/game/hero/levels.ts`), the gate's floor select, and the floors the hero walks: generated from the floor number, one room per web encounter with the guardian last; the save keeps the hero at the gate while below (`GameState.spoils.clear_floor` pays a first clear)
- `scripts/puny_sheet.gd` / `scripts/puny_dungeon.gd` — one Shade tileset with its `.tsx` (animations, wang corners, a lazily built TileSet), and Puny Dungeon's wall grammar, stone, torches, barrels and stairs
- `scripts/home_screen.gd` — the house's barrel, workbench, trophy shelf, nook and furniture placement (house rules live in `state/town.gd`)
- `scripts/ui_style.gd` — the one look (PIX-138): parchment pages in carved wooden frames, ink on the page and cream on the dark, pixel fonts at whole scales, Press Start 2P headings
- `scripts/hud_dock.gd` — the hero's dock centred along the bottom: experience along its top, portrait, rank, health and energy, the six skill slots by their number keys (a click casts too), gold and a menu of every screen with its key and waiting points
- `scripts/sound.gd` (autoload `Sound`) + `assets/audio/` — 17 stingers, a seamless loop per theme and ambient one-shots with variants (`assets/data/audio.json`), rendered once from the old web game's synth, plus the pages' UI sounds synthesized at start. Music crossfades per place, battle/boss while something hunts the hero; Music/SFX/Ambience buses follow the options
- `assets/fonts/` — Pixeloid (OFL) for all text, Press Start 2P (OFL) for the logo (`FONTS.txt`)
- `assets/puny/` — art by Shade, CC0 (`LICENSE.txt`): characters (hero, villagers, bestiary) from [Puny Characters + PunyMonsters](https://merchant-shade.itch.io/16x16-puny-characters) and [Mini World Sprites](https://merchant-shade.itch.io/16x16-mini-world-sprites), the overworld from [Puny World](https://merchant-shade.itch.io/16x16-puny-world) and stone from [Puny Dungeon](https://merchant-shade.itch.io/16x16-puny-dungeon). `scripts/puny_art.gd` assigns who wears which sheet; `scripts/puny_terrain.gd` lays Puny World over the maps (wang corners on the dual grid, read from Shade's Tiled `.tsx`), raises ramparts, bridges and skylines, and `shaders/region_tint.gdshader` tones ash and mire
- `assets/maps/*.json` — all world maps (grid one row per line, spawn, portals), and `interactables.json` (chests, signs, waypoints); edit them directly
- `assets/data/catalog.json` — items, roles and skill data
- `assets/data/npcs.json` — villagers and recruits with their lines
- `assets/data/changelog.json` — every release, newest first: What's new, and the game's version
- `assets/data/economy.json` — shops and their stock per unlocked floor, recipes, stations, rarities
- `assets/data/town.json` — town tiers, deeds, rest and bank tuning; `assets/maps/town@N.json` / `town_house@N.json` are the tier redraws
