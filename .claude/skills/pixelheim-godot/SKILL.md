---
name: pixelheim-godot
description: Pixelheim's Godot 4.7 port (godot/) - how data flows from the web game, the GameState/save contract, the screenshot harness and GUT, and the project's known pitfalls. Use whenever editing anything under godot/, scripts/export-maps.ts or scripts/sync-godot-assets.mjs, porting a feature from src/ to Godot, or verifying Godot work.
---

# Pixelheim in Godot

The React/Pixi web game (`src/`) is being ported to Godot 4.7 (`godot/`), one Linear phase at a time (project "Godot Migration"). Until the web build is sunset, **the web code is the source of truth for data and rules**; Godot ports them and proves the port with tests.

## Data flows one way: web → Godot

- Maps, chests, signs, waypoints, items, roles, skill roots, place names, villagers: exported by `scripts/export-maps.ts` into `godot/assets/maps/*.json` and `godot/assets/data/*.json` by importing the real web modules (so web-side validation runs too).
- Generated sprites: copied from `public/sprites/` by `scripts/sync-godot-assets.mjs` (patterns + `SPRITE_EXTRAS`; widen them when a phase needs new art).
- Run `pnpm godot:sync` after any change; CI runs both scripts with `--check` and fails on drift. **Never hand-edit the exported JSON or synced PNGs.**
- New data a phase needs → add an `emit(...)` to `export-maps.ts` (into `DATA_OUT`), read it from a static GDScript class with a cached `static var _doc`.

## Porting rules

- Port rules as **pure static classes** (`MapData`, `Discovery`, `Interactables`, `Npcs`, `SaveCodec`, `WebImport`...): no nodes, unit-testable. Scene scripts only draw, move and route input.
- Prove the port against the web: write a throwaway `scripts/_ref.ts` that prints reference values from the real web functions (`pnpm exec tsx scripts/_ref.ts`), paste them into a GUT test, delete the script. `test_npcs.gd` (pacing) and `test_save_codec.gd` (a frozen web save code in `test/fixtures/`) are the models.
- Keep web semantics unless real-time play forces a change, and say so in a comment (e.g. villagers pace on a clock, not on hero steps).

## Code conventions

- Typed GDScript, tabs, `##` doc comments that explain *why*. Pure modules get `class_name`; the autoload script (`scripts/state/game_state.gd`, autoload `GameState`) must not.
- Nodes are built in code; `scenes/main.tscn` is the only scene. `world.gd` orchestrates: maps, actors (one y-sorted `actors` layer), HUD, interaction, harness.
- Signals up, calls down: `GameState` emits (`loaded`, `gold_changed`, `inventory_changed`, `dialogue_closed`); world and UI listen.
- Menus/overlays are `CanvasLayer`s with `process_mode = ALWAYS` that pause the tree while open, and use `UiStyle` (`scripts/ui_style.gd`) for palette, boxes, labels, buttons; screen titles use `UiStyle.heading` (Press Start 2P). Body type is Courier Prime via `gui/theme/custom_font` in project.godot (a root `theme` does not reach Controls under a CanvasLayer). Courier is wide: clip long lines (`clip_text` + ellipsis) and check screenshots. Open the hero's screens through `world.open_screen(name)`.
- Input in menus: build the command, `get_viewport().set_input_as_handled()` **first**, then run it; an action that reloads the scene frees the menu (calling it after logs `!is_inside_tree`).
- Sounds are the web synth rendered to WAV (`pnpm audio:render`); play them by the web's names (`Sound.play("coin")`), never hand-make audio. A changed `src/audio` needs a re-render (not CI-checked: noise is random).
- Keys live in `Controls` (defaults, alternates, pad) and `GameSettings.bindings`; never `InputMap.add_action` elsewhere. A new screen's hotkey is a new `Controls.BINDABLE` entry.

## State and saves

- Everything that persists lives in `GameState` (typed sections `hero`, `pack`, `settlement`, `progression`, `world`) and changes only through its methods, which keep the web reducers' invariants and call `mark_dirty()` / `save_now()`.
- Saves are the **web v4 save format**, byte for byte: a Godot slot file loads in the web game and vice versa. `SaveCodec` ports `save.ts` (migrations, normalize, `PXH1.` codes). Every web field round-trips, even ones Godot doesn't play yet. Parse JSON with `SaveCodec.parse_json` (it restores integers; plain JSON makes them floats and Godot would write `123.0`).
- Slots: `user://saves/slot_<n>.json`, atomic temp+rename. The user dir is pinned (`config/custom_user_dir_name="pixelheim"`): never change it, or players lose saves. Slot 0 (harness runs) never touches disk.

## Verify

```sh
godot --headless --path godot --import                        # after new assets/scripts
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd # GUT; ALSO grep the output for "Parse Error"
godot --path godot -- --screenshot [--map <id>] [--walk l,d,r,u] [fight [kill] [hurt] [--foe <species>]] [chest] [talk] [near] [shop [--tab N]] [hall] [bank] [home --mode M] [--town-tier N] [--house-tier N] [lineup] [saves] [night] [worldmap] [overview] [--at x,y] [--zoom Z] [--floor N] [clear] [gate [--dungeon id] [descend]] [leave] [quest] [journal] [--level N] [rankup [walk-path]] [stats] [skills] [codex [bestiary]] [inventory] [title] [create] [pause [scanlines]] [options] [--slot N]
```

- GUT **exits 0 when a test file fails to parse** (the whole suite is silently skipped); CI greps for it, do the same locally.
- The harness writes `godot/screenshot.png` (gitignored) and prints `map=… cell=… hp=… gold=…`. Read the PNG; the owner judges looks from screenshots.
- Dungeons: `--floor N` walks down floor N, `clear` fells every foe on the map (the floor's clear and hoard), `gate` opens a floor select (`descend` takes the selected floor), `leave` climbs back to the gate. The printed `save=` shows where the save stands (it stays at the gate while below).
- Terrain review: `overview` frames the whole map, `--at x,y` stands the hero on a cell, `--zoom Z` sets the camera (play zoom is 4).
- `--slot N` writes real saves to `~/Library/Application Support/pixelheim/`; delete what you created afterwards.
- Web-only behavior (localStorage import, IndexedDB saves): `godot --headless --path godot --export-release Web export/web/index.html`, serve `godot/export/web` with `python3 -m http.server`, drive it with Playwright, and inspect IndexedDB `/userfs`.
- macOS has no `timeout`; don't wrap commands in it.

## Pitfalls already paid for

- Characters are Shade's Puny family at 1x (PIX-130): `PunyArt` maps roles, villagers and species to sheets. Row orders differ per family: Puny Characters turn clockwise (down 0, right 2, up 4, left 6), PunyMonsters the other way (left 2, right 6), Mini World rows are down/up/left/right. Check any new sheet with `--screenshot lineup` before trusting a direction.
- A new villager sprite id or monster species needs a `PunyArt` entry; `test_puny_art` fails otherwise.
- The world is Shade's Puny World (`PunyTerrain`): corner wang tiles from his `.tsx` on the **dual grid** (layer shifted half a tile up-left, one tile per cell corner), so terrain edges sit on collision edges. Shade pairs terrains only with grass; `STRENGTH` settles other meetings. Ground tiles have no sprite in `TILE_INFO` (`""`); the tile layer only puts an invisible blocker under unwalkable ones. A new ground tile id goes in `GROUND_TILES` and `PunyTerrain.GROUND`.
- `TileSetAtlasSource` animation separation counts **tiles**, not pixels; Puny water frames sit 2-4 rows apart and may overlap other tiles' strips, so `PunyTerrain._slot` opens a new source on the same sheet when one is full.
- In a `canvas_item` shader, `COLOR` in `fragment()` already holds texel × modulate; sampling `TEXTURE` again squares it (everything goes dark).
- Non-resource files (`.tsx`, `.txt`) only reach the web build through `include_filter` in `export_presets.cfg`.
- A plain launch shows the title (harness runs skip it unless `title`); with no hero in the slot, a stand-in plays behind it and `GameState.save_now` writes nothing until `new_hero_in` / `import_into` / `play_slot` (`standing_in`).
- Dungeon floors (`MapData.floor_level > 0`) are not web maps: never `GameState.move_to` them, or a save would point at a map the web game can't load.
- A static func named like a GDScript builtin (`floor`, `round`...) is shadowed by the builtin inside its own class: `floor(level)` there calls math `floor`. Name them apart (`floor_def`).
- Shade's animations that pause or loop back can't be TileSet atlas animations; `PunySheet` holds them on their first frame.
- `--map <id>` boots at that map's spawn, not the save's position; `GameState.boot` runs once per session (slot switches reload the scene).
- Interiors chart under their town's place name (`Catalog.place_name`).
- The village and the house redraw per tier: load runtime maps through `world._load_map` (→ `MapData.load_tiered`), never `MapData.load_by_id`, or a funded town shows its old self.
