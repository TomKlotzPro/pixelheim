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
- Menus/overlays are `CanvasLayer`s with `process_mode = ALWAYS` that pause the tree while open, and use `UiStyle` (`scripts/ui_style.gd`) for palette, boxes, labels, buttons until the UI suite themes everything.
- Input in menus: build the command, `get_viewport().set_input_as_handled()` **first**, then run it; an action that reloads the scene frees the menu (calling it after logs `!is_inside_tree`).

## State and saves

- Everything that persists lives in `GameState` (typed sections `hero`, `pack`, `settlement`, `progression`, `world`) and changes only through its methods, which keep the web reducers' invariants and call `mark_dirty()` / `save_now()`.
- Saves are the **web v4 save format**, byte for byte: a Godot slot file loads in the web game and vice versa. `SaveCodec` ports `save.ts` (migrations, normalize, `PXH1.` codes). Every web field round-trips, even ones Godot doesn't play yet. Parse JSON with `SaveCodec.parse_json` (it restores integers; plain JSON makes them floats and Godot would write `123.0`).
- Slots: `user://saves/slot_<n>.json`, atomic temp+rename. The user dir is pinned (`config/custom_user_dir_name="pixelheim"`): never change it, or players lose saves. Slot 0 (harness runs) never touches disk.

## Verify

```sh
godot --headless --path godot --import                        # after new assets/scripts
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd # GUT; ALSO grep the output for "Parse Error"
godot --path godot -- --screenshot [--map <id>] [--walk l,d,r,u] [fight [kill] [hurt] [--foe <species>]] [chest] [talk] [near] [shop [--tab N]] [hall] [bank] [home --mode M] [--town-tier N] [--house-tier N] [lineup] [saves] [night] [worldmap] [--slot N]
```

- GUT **exits 0 when a test file fails to parse** (the whole suite is silently skipped); CI greps for it, do the same locally.
- The harness writes `godot/screenshot.png` (gitignored) and prints `map=… cell=… hp=… gold=…`. Read the PNG; the owner judges looks from screenshots.
- `--slot N` writes real saves to `~/Library/Application Support/pixelheim/`; delete what you created afterwards.
- Web-only behavior (localStorage import, IndexedDB saves): `godot --headless --path godot --export-release Web export/web/index.html`, serve `godot/export/web` with `python3 -m http.server`, drive it with Playwright, and inspect IndexedDB `/userfs`.
- macOS has no `timeout`; don't wrap commands in it.

## Pitfalls already paid for

- Characters are Shade's Puny family at 1x (PIX-130): `PunyArt` maps roles, villagers and species to sheets. Row orders differ per family: Puny Characters turn clockwise (down 0, right 2, up 4, left 6), PunyMonsters the other way (left 2, right 6), Mini World rows are down/up/left/right. Check any new sheet with `--screenshot lineup` before trusting a direction.
- A new villager sprite id or monster species needs a `PunyArt` entry; `test_puny_art` fails otherwise.
- `--map <id>` boots at that map's spawn, not the save's position; `GameState.boot` runs once per session (slot switches reload the scene).
- Interiors chart under their town's place name (`Catalog.place_name`).
- The village and the house redraw per tier: load runtime maps through `world._load_map` (→ `MapData.load_tiered`), never `MapData.load_by_id`, or a funded town shows its old self.
