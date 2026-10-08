---
name: pixelheim-godot
description: Pixelheim's Godot 4.7 port (godot/) - how data flows from the web game, the GameState/save contract, the screenshot harness and GUT, and the project's known pitfalls. Use whenever editing anything under godot/, scripts/export-maps.ts or scripts/sync-godot-assets.mjs, porting a feature from src/ to Godot, or verifying Godot work.
---

# Pixelheim in Godot

Pixelheim is a Godot 4.7 game (`godot/`), live at the Pages root since PIX-129. The React/Pixi game it grew from (`src/`) is **the classic edition: frozen, bug fixes only** (Tom's call, 2026-10-07), still playable at `/classic/`.

- **Godot owns the rules now.** New features and rule changes are made in GDScript, not ported from `src/`.
- **`src/` is still the source of the *data*** (maps, items, roles, quests...) through `pnpm godot:sync`, until that data moves into `godot/`. Changing the data there changes both editions.
- **Releases:** add an entry at the top of `src/app/changelog.ts` (newest first, the classic CAPS-lead style). Its version is the game's version in both editions (`meta.json` and the What's new screen come from it via `pnpm godot:sync`); bump `package.json` to match. Mirror each release in the Linear document "Changelog" (project Godot Migration). Keep `README.md` current with what the game does.

## Data flows one way: web → Godot

- Maps, chests, signs, waypoints, items, roles, skill roots, place names, villagers: exported by `scripts/export-maps.ts` into `godot/assets/maps/*.json` and `godot/assets/data/*.json` by importing the real web modules (so web-side validation runs too).
- No generated sprites: the Godot game draws only Shade's art (PIX-137); `scripts/sync-godot-assets.mjs` now syncs just the pixel font.
- Run `pnpm godot:sync` after any change; CI runs both scripts with `--check` and fails on drift. **Never hand-edit the exported JSON or synced PNGs.**
- New data a phase needs → add an `emit(...)` to `export-maps.ts` (into `DATA_OUT`), read it from a static GDScript class with a cached `static var _doc`.

## Porting rules

- Port rules as **pure static classes** (`MapData`, `Discovery`, `Interactables`, `Npcs`, `SaveCodec`, `WebImport`...): no nodes, unit-testable. Scene scripts only draw, move and route input.
- Prove the port against the web: write a throwaway `scripts/_ref.ts` that prints reference values from the real web functions (`pnpm exec tsx scripts/_ref.ts`), paste them into a GUT test, delete the script. `test_npcs.gd` (pacing) and `test_save_codec.gd` (a frozen web save code in `test/fixtures/`) are the models.
- Keep web semantics unless real-time play forces a change, and say so in a comment (e.g. villagers pace on a clock, not on hero steps).

## Code conventions

- Typed GDScript, tabs, `##` doc comments that explain *why*. Pure modules get `class_name`; the autoload script (`scripts/state/game_state.gd`, autoload `GameState`) must not.
- Nodes are built in code; `scenes/main.tscn` is the only scene. `world.gd` orchestrates: maps, actors (one y-sorted `actors` layer), HUD, interaction; `harness.gd` (added only for `--screenshot` runs) drives the screenshot harness.
- Signals up, calls down: `GameState` emits (`loaded`, `gold_changed`, `inventory_changed`, `dialogue_closed`); world and UI listen.
- Menus/overlays are `CanvasLayer`s with `process_mode = ALWAYS` that pause the tree while open. Open the hero's screens through `world.open_screen(name)`.
- **The look lives in `UiStyle` (`scripts/ui_style.gd`, PIX-138)**: pages of a village ledger. Parchment (`WINDOW`) in a carved wooden frame with brass corner studs, rows and slots (`CARD`) inked on the page with a `RIM` line, wooden planks for buttons (`UiStyle.plank`, `UiStyle.focus(button, on)` for the chosen one). Frames are pixel art generated from the palette at 1x and shown at `UI_SCALE` 2, as 9-slice `StyleBoxTexture`s (the page tiles its grain, never stretches it). **Two text palettes, by surface**: on the page `INK`, `FADED`, and `LAMP` (rubric red) for focus; on the dark around windows (headings, subtitles, gold counts, footers, the title, anything over the world) `CREAM`, `DUSK`, `GOLD`. Rarity inks are `FINE` and `EPIC`. Content that isn't in a window sits on `UiStyle.page(rect)`, never on the backdrop. `UiStyle.window()` is a main window; `UiStyle.box(fill, rim, padding)` infers the rest (a `LAMP` rim means focus, `CARD` with padding ≥ 12 means a window, anything else is a card). Footers are `UiStyle.footer("Esc  close      W/S  choose", at)` (keycaps, on the dark). Screens ease in on their own: the world hooks every `*_screen.gd` CanvasLayer it adds into `UiStyle.enter` (fade + 10 px rise, skipped with reduce motion; the title and rank-up make their own entrances), which also plays `Sound.play_ui("open")` and `"close"`; move keys tick while a screen pauses the tree. Those three sounds are synthesized in `sound.gd` (`UI_SOUNDS`), not in the frozen web synth. Don't hand-roll `StyleBoxFlat`s or colours.
- **The HUD is the dock** (`scripts/hud_dock.gd`, `world.dock`): a wooden plate centred on the bottom edge (XP line along its top, portrait/name/rank and HP + energy bars, six skill slots by number key, gold and a Menu that lists every screen with its key and lights when points wait). Nothing else sits at the bottom; the battle log and flash messages float above it in `CREAM` with a `NIGHT` outline. `world.dock.refresh()` after anything the hero shows changes. `--screenshot dockmenu` opens its menu.
- **Type is all pixel fonts at whole-number scales**: `UiStyle.label(text, size, color)` below 16 gives dense Pixel Operator at 1x (rows, descriptions, hints); 16 and up gives the chunky Pixel Operator 8 at 2x (dialogue, names, menus, values), and 3x from 24. `UiStyle.strong` is bold; `UiStyle.sized(control, size)` applies the same rule to buttons and fields; `UiStyle.heading` is Press Start 2P. `UiStyle.setup()` (first line of `world._ready`) makes the default font render fixed-size. Never set fractional or arbitrary font sizes on other fonts.
- Input in menus: build the command, `get_viewport().set_input_as_handled()` **first**, then run it; an action that reloads the scene frees the menu (calling it after logs `!is_inside_tree`).
- **Never poll `Input.is_action_just_pressed` for a key a menu or conversation can take** (world, attack, skills): a modal that closes on a key event unpauses the tree in that same frame, and the poll still sees the key, so E reopened every conversation and Esc opened the pause menu behind it (PIX-131). Take keys in `_unhandled_input` and mark them handled. Polling is only for held input (`Input.get_vector`).
- InputMap bindings are for all devices (`Controls.ALL_DEVICES`); the harness presses keys with `--keys e,esc,...` (`harness._press`: `Input.action_press` plus `viewport.push_input`, stamped `harness.DEVICE`), because an unfocused window's keys are dropped by the display server.
- Sounds are the web synth rendered to WAV (`pnpm audio:render`); play them by the web's names (`Sound.play("coin")`), never hand-make audio. A changed `src/audio` needs a re-render (not CI-checked: noise is random).
- Keys live in `Controls` (defaults, alternates, pad) and `GameSettings.bindings`; never `InputMap.add_action` elsewhere. A new screen's hotkey is a new `Controls.BINDABLE` entry.

## State and saves

- Everything that persists lives in `GameState` (typed sections `hero`, `pack`, `settlement`, `progression`, `world`) and changes only through its methods, which keep the web reducers' invariants and call `mark_dirty()` / `save_now()`.
- Saves are the **web v4 save format**, byte for byte: a Godot slot file loads in the web game and vice versa. `SaveCodec` ports `save.ts` (migrations, normalize, `PXH1.` codes). Every web field round-trips, even ones Godot doesn't play yet. Parse JSON with `SaveCodec.parse_json` (it restores integers; plain JSON makes them floats and Godot would write `123.0`), and write it with `SaveCodec.serialize` (it keeps key order; `JSON.stringify` sorts keys by default). `test_save_codec.gd` pins a late-game web save and the web's own re-encode of it (`fixtures/web_save_late*`).
- Slots: `user://saves/slot_<n>.json`, atomic temp+rename. The user dir is pinned (`config/custom_user_dir_name="pixelheim"`): never change it, or players lose saves. Slot 0 (harness runs) never touches disk.

## Paid art (PIX-133)

- Shade's paid **Puny World Medieval Age** atlas (town houses, `scripts/puny_town.gd`) is NOT in this public repo: it lives in the private `TomKlotzPro/pixelheim-assets` repo, is installed by `pnpm godot:art` into git-ignored `godot/assets/puny/medieval/`, and CI fetches it with the deploy key secret `PIXELHEIM_ASSETS_KEY`. Never commit its PNGs, its sample maps, or anything cut from them.
- Code must keep working without it (`PunyTown.available()` false: old buildings); test pure logic through `PunyTown.plan()`, which needs no art.
- Icons (PIX-138): `godot/assets/puny/icons.json` maps every item (by id), skill (by name, `<theme>/<n>` in the Puny Skills pack) and ailment to Shade's art: `free/<sheet>@c,r` (CC0 sheets in `assets/puny/icons/`, committed), `medieval@<tile>`, or a path under the private repo's `retro-rpg/shade/` (copied by `scripts/fetch-private-art.sh` into git-ignored `assets/puny/shade/`). `ItemIcons` resolves them and falls back to the web sprites. A new item or skill without an entry fails `test_item_icons`. New paid packs go in the private repo under `retro-rpg/<artist>/<pack>/` with a line in its `retro-rpg/README.md`.
- Houses: each web roof cluster becomes a 9-wide gable centred on the door (Shade's cottage grammar, height by repeating body rows) plus hip-roofed wings for the remaining columns; roof colours are fixed row shifts into the pack's colour blocks (`ROOF_ROWS`). Cells a house covers become `roof` in the grid, roof cells it leaves become `grass` (`freed`). Rooms (`scripts/puny_interior.gd`, `PunyInterior.plan`) get plank floors (stone in the smithy) and a rug, cream walls autotiled around the room (the web's thicker walls beyond are dark), windows on the back wall, Shade's door, and furniture per web tile (`FURNITURE`, `RUNS`); furniture spreading onto floor blocks it, except a bed's foot (the inn wakes guests there). Outdoor props (`scripts/puny_props.gd`, PIX-137, `PunyProps.plan`): the web's lamps, wells, shrine, barrels, crates, counters, fences and flowers become Shade's torches, roofed well (a well in paving all round is the square's 2x2 fountain), the dungeon sheet's stone knight, market crates, autotiled log fences and flat flowers, y-sorted in `actors` on the bottom of their foot with a StaticBody2D exactly there; cells they stand on beyond the web's tile go in `MapData.covered` (walkability checks it). Every foot must cover x 4..12, y 7..15 of each cell it blocks, so the hero's position (feet box 3 px below it) never enters a blocked cell (`test_puny_props` checks every tier). Door signs (`scripts/shop_sign.gd`, PIX-134) are hanging boards with a pack icon per label (`ShopSign.ICONS`); the place's name and keeper show in a HUD nameplate when the hero is within ~2.5 tiles (`world._update_nameplate`).

## Verify

```sh
godot --headless --path godot --import                        # after new assets/scripts
godot --headless --path godot -s res://addons/gut/gut_cmdln.gd # GUT; ALSO grep the output for "Parse Error"
godot --path godot -- --screenshot [--map <id>] [--walk l,d,r,u] [fight [kill] [hurt] [--foe <species>]] [chest] [talk] [near] [shop [--tab N]] [hall] [bank] [home --mode M] [--town-tier N] [--house-tier N] [lineup] [saves] [night] [worldmap] [overview] [--at x,y] [--zoom Z] [--floor N] [clear] [gate [--dungeon id] [descend]] [leave] [quest] [journal] [--level N] [rankup [walk-path]] [stats] [skills] [codex [bestiary]] [cast] [inventory] [title [splash]] [create] [pause [scanlines]] [options] [portal] [die] [talk --keys e,esc] [motion] [--slot N]
godot/tools/flows.sh [name...]   # the ten release flows; pictures in godot/flows/
godot/tools/splash.sh            # re-render the web boot splash after title changes
```

- GUT **exits 0 when a test file fails to parse** (the whole suite is silently skipped); CI greps for it, do the same locally.
- The harness writes `godot/screenshot.png` (gitignored) and prints `map=… cell=… hp=… gold=…`. Read the PNG; the owner judges looks from screenshots.
- Dungeons: `--floor N` walks down floor N, `clear` fells every foe on the map (the floor's clear and hoard), `gate` opens a floor select (`descend` takes the selected floor), `leave` climbs back to the gate. The printed `save=` shows where the save stands (it stays at the gate while below).
- Terrain review: `overview` frames the whole map, `--at x,y` stands the hero on a cell, `--zoom Z` sets the camera (play zoom is 4).
- **Collision (PIX-137)**: the hero and enemies are `MOTION_MODE_FLOATING`; the hero's box is their feet (10x8, 3 px below the position). Anything that blocks must cover x 4..12, y 7..15 of each cell it blocks, so the hero's position (and `player_cell`) never enters a blocked cell. Villagers' bodies run 14 px below their centre (a full step between hero and villager, a pixel's clearance along the row below). Every blocker the grid doesn't spell out goes in `MapData.covered` (props' extra cells, chests, placed furniture, solid field decor), which `is_walkable` reads, so spawns, pacing and arrivals agree with physics. Field decor (`scripts/scatter.gd`, `Scatter.solid`) blocks only where every neighbour stays open (`test_scatter` proves no map loses reachable ground). In rooms, `PunyInterior.plan()["over"]` names furniture drawn over a cell (a bed's foot is the bed: E rests, nothing is placed there; `world._tile_in_hand`).
- **Motion (PIX-135)**: physics interpolation is on for the `actors` layer only (world root OFF). Anything that moves an actor outside physics must run on physics ticks (tweens: `set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)`), and every teleport of the hero goes through `world._teleported()` (resets interpolation and cuts the camera). The camera is top-level and eases toward where the hero is *drawn* (`_follow_hero`, from ticks the world records after the actors move) onto whole screen pixels; the zoom is fitted so an art pixel is whole screen pixels (`_fit_zoom`). Do not turn on `snap_2d_transforms_to_pixel` (it snaps sprites to the world's 4px grid under the gliding camera) and do not re-attach smoothing to the hero. `--screenshot --map town motion` measures it (`backsteps=` on the report line; the `motion` release flow).
- Harness windows are always-on-top and never take focus (macOS stops drawing a covered window, so a run behind another app never reached its screenshot, and keys you type elsewhere used to land in the game); `harness.gd`'s `_input` (it runs paused too) drops every event but its own and lets go of the actions they pressed, since movement reads held actions.
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
