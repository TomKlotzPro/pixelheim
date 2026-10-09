# Solid Ground: what the code graph says

> **A planning record for P-PIX-16 (Pixelheim: Solid Ground).** Built 2026-10-09 from `00ead68` (v0.168). No game code was changed to write it.

## How the graph is made

graphify reads a dozen languages but not GDScript, so `godot/tools/codegraph.py` reads the scripts itself (regexes, Python's standard library only) and writes `graphify-out/graph.json` in graphify's own format. graphify then does the rest without an LLM:

```sh
python3 godot/tools/codegraph.py              # graphify-out/graph.json; --tests adds godot/test/, --private lists reach-ins
graphify cluster-only . --no-label            # communities, graphify-out/GRAPH_REPORT.md and graph.html
graphify god-nodes --top 15                   # the hubs
graphify affected godot_scripts_world         # what leans on world.gd
graphify query "camera"
```

A node id is the file's path without `.gd`, with `/` turned into `_` (`godot_scripts_state_game_state`), and a func's id adds its name (`godot_scripts_world_cell_center`). `graphify-out/` is git-ignored. After the code changes, rerun the first two commands. `graphify update .` and `graphify watch` can't refresh this graph, because they only re-read the languages graphify knows.

**What's in it.** The graph has 1,557 nodes: 99 scripts, 1,442 top-level funcs and 16 signals. It has 6,413 edges: 3,731 calls, 1,458 contains, 1,144 references, 54 imports (`preload`/`load`) and 26 extends. 97% of the edges are read straight from the code. The other 3% (170) are inferred: 168 go through an untyped `world` variable, which the tool takes to mean the main scene (`world.gd`), and 2 through `get_tree().current_scene`. The `##` doc comments go into each node's `rationale` field, which graphify's query searches. That's how `graphify query "camera"` finds `world._frame_lift()` and `world._teleported()`, though no func is named after the camera.

## God nodes

These are graphify's 15 most connected nodes. Degree counts distinct neighbours, and a script's degree includes the funcs and signals it contains.

| # | Node | Degree | Note |
| -- | ---------------------------- | ---: | ---------------------------------------------------------------------- |
| 1 | `GameState` (state/game_state.gd) | 355 | 143 funcs and 16 signals of its own; 45 other scripts use it |
| 2 | `Text.t()` | 162 | every translated string |
| 3 | `res://scripts/world.gd` | 160 | 116 funcs of its own; it uses 67 of the other 98 scripts |
| 4 | `UiStyle` | 132 | |
| 5 | `InventoryState` | 118 | |
| 6 | `HeroState` | 116 | |
| 7 | `ProgressionState` | 88 | |
| 8 | `harness._run_test_harness()` | 81 | a single 555-line function |
| 9 | `MapData` | 80 | |
| 10 | `SettlementState` | 68 | |
| 11 | `Bestiary._data()` | 66 | a "private" accessor that 47 funcs in 22 other scripts call |
| 12 | `UiStyle.label()` | 64 | |
| 13 | `Town` | 63 | |
| 14 | `GameSettings` | 56 | |
| 15 | `shop_screen._build_rows()` | 55 | 145 lines |

The two hubs are coupled in opposite directions:

- **GameState** is the most depended-upon script: 45 scripts use it.
- **world.gd** depends on the most: it uses 67 scripts, and only 23 use it.

GameState's typed sections are already small files of their own, and they rank as hubs too (5, 6, 7 and 10). Callers also reach straight into those sections:

- `GameState.progression`: 98 times from 12 scripts
- `GameState.hero`: 97 times from 18 scripts
- `GameState.pack`: 71 times from 19 scripts
- `GameState.settings`: 57 times from 21 scripts
- `GameState.settlement`: 55 times from 12 scripts
- `GameState.world`: 41 times from 10 scripts

Fan-in and fan-out of the busiest scripts:

| Script | Lines | Used by (scripts) | Uses (scripts) |
| ---------------- | ----: | ----: | ----: |
| Text | 115 | 48 | 10 |
| GameState | 2,178 | 45 | 32 |
| UiStyle | 649 | 28 | 5 |
| Bestiary | 366 | 27 | 9 |
| Catalog, MapData | 74, 87 | 26 each | 2 each |
| Sound | 396 | 23 | 3 |
| world.gd | 2,216 | 23 | 67 |
| GameSettings, Screen | 96, 214 | 22 each | 2, 4 |

## Communities

graphify's Leiden clustering found 65 communities, and they come out the same on every run for the same graph. With `--no-label` graphify leaves them as "Community N". These names are mine, chosen from each community's members:

| # | Name | Nodes | Members |
| -- | ----------------------------------- | --: | ------------------------------------------------------------------------- |
| 0 | Hero growth | 105 | Skills, HeroRules, HeroState, Ranks, skills and stats screens, GameState's skill and stat funcs |
| 1 | Town money | 82 | Town, ShopSign, bank and town hall screens, GameState's projects, bank, ventures and tills |
| 2 | Quests and story | 78 | Prologue, Quests, Story, MainQuest, Relics, ProgressionState, journal screen |
| 3 | Saves and slots | 65 | SaveCodec, SaveSlots, Catalog, saves screen, `GameState.new_game/apply` |
| 4 | Trade and crafting | 57 | Economy, GameState's shop, forge and craft funcs |
| 5 | Characters and villagers | 55 | PunyArt, Npcs, npc.gd |
| 6 | GameState core and settlement | 50 | the GameState node, SettlementState, `save_now`, `_pack_changed`, the inn, house buying |
| 7 | World loop, camera and hits | 48 | world.gd's node, `_process`, camera, shake, floating words, reveal screen, the brains' strikes |
| 8 | Map travel and staging | 42 | `_enter_map`, `enter_floor`, `_play_ending`, `_cell_center`, `_keep_hours`, map screen, Discovery, the harness |
| 9 | Dungeons | 42 | Dungeons, DungeonFloor, dungeon screen |
| 10 | Music and the boss bar | 40 | Sound, boss_bar.gd, `world._update_music/_soundscape` |
| 11 | UI kit | 38 | UiStyle's windows, headings and plates, `world.hint`, dialogue and cutscene builders |
| 12 | The hero in play | 34 | player.gd, Ailments |
| 13 | Item words | 33 | `Text.t`, `Catalog.item_name`, item descriptions in the shop and pack |
| 14 | Interaction and messages | 30 | `_try_interact`, `_talk`, `_house_interact`, `_flash_message`, `_show_message` |
| 15 | Inventory and loot | 29 | InventoryState, `GameState.defeat_monster/clear_floor/resolve_quests` |
| 16 | Title backdrop | 28 | TitleScene |
| 17 | Bestiary | 27 | Bestiary's rules |
| 18 | Map data and tiles | 27 | MapData, WorldTiles, `world._ready/_floor_cleared/on_enemy_died` |
| 19 | Title screen | 26 | title_screen.gd, WebImport |
| 20 | HUD dock | 25 | hud_dock.gd |
| 21 | World state and the house | 25 | WorldState, GameState's furniture, house, fishing and items |
| 22 | Terrain | 24 | PunyTerrain, `MapView._build_ground`, water reflections |
| 23 | Elite and boss fights | 22 | elite_brain.gd, BossBrain, Telegraph |
| 24 | Screen chrome | 22 | `UiStyle.label/heading/title/screen_footer`, `Screen.dim`, codex screen |
| 25 | Bounties | 21 | Hunts, bounty screen |
| 26 | Monsters | 20 | enemy.gd |
| 27 | Cutscenes | 19 | Cutscene |
| 28 | Map decor | 19 | MapView, Scatter |
| 29 | Inventory screen | 18 | inventory_screen.gd |
| 30 | Weather and light | 17 | Weather, light_rig.gd, atmosphere's shading |
| 31 | Dawn after the Night of Ash | 16 | dawn_screen.gd |
| 32 | Ledger screens | 16 | ledger_screen.gd, `UiStyle.purse` |
| 33 | Controls | 15 | Controls |
| 34 | Deeds and mastery | 15 | Deeds, Bestiary's damage and mastery formulas |
| 35 | Town buildings | 15 | PunyTown |
| 36 | Screen base | 15 | Screen |
| 37 | Phones | 15 | Touch, touch_controls.gd |
| 38 | Character creation | 14 | create_screen.gd |
| 39 | Item icons | 14 | ItemIcons, firebolt.gd |
| 40 | Translation and interactables | 14 | Text, Interactables |
| 41 | Lights | 14 | Lights |
| 42 | GameState's signals | 14 | twelve signals and `world._build_hud`, where they are wired |
| 43 | Keycaps | 13 | Keycap, `UiStyle.keycap` |
| 44 | Settings | 13 | GameSettings, `GameState.boot`, volumes, `apply_video` |
| 45 | Home and trophies | 12 | home screen, GameState's trophies |
| 46 | Outdoor props | 12 | PunyProps |
| 47 | Packs | 12 | Packs, `world.can_notice` |
| 48 | Dungeon tiles | 11 | PunyDungeon, `MapView._build_dungeon` |
| 49 | Dialogue box | 11 | dialogue_box.gd |
| 50 | Interiors | 11 | PunyInterior, furniture placement |
| 51 | Options screen | 11 | |
| 52 | Shop screen | 11 | |
| 53 | Atmosphere | 10 | atmosphere.gd's particles |
| 54 | Escort | 10 | escort.gd, `world._tend_escort`, `GameState.escort_due` |
| 55 | Look book | 10 | lookbook.gd, PerfProbe |
| 56 | Throne screen | 9 | |
| 57 | Day, night and showers | 8 | DayNight, Weather's timing |
| 58 | Pause screen | 8 | |
| 59 | Sprite sheets | 8 | PunySheet |
| 60 | Rank-up screen | 8 | |
| 61 | Ring toss | 8 | |
| 62 | Gathering | 8 | Gathering |
| 63 | Harness input | 5 | the harness's key presses |
| 64 | Changelog screen | 3 | |

**What the communities say about the two big files.**

- **world.gd** is spread over 18 communities. Most of it falls in five:
  - 7, world loop, camera and hits: 34 funcs
  - 14, interaction and messages: 26
  - 8, map travel and staging: 22
  - 18, map data and tiles: 9
  - 2, quests and story: 5
- **game_state.gd** is spread over 19 communities. Each slice sits beside the rule class it drives:
  - its shop funcs beside `Economy` (4)
  - its money funcs beside `Town` (1)
  - its quest funcs beside `Quests` and `Prologue` (2)
  - its skill funcs beside `Skills` and `HeroRules` (0)
  - its loot funcs beside `InventoryState` (15)

The splits below follow those lines.

## Who calls world.gd's private functions

`python3 godot/tools/codegraph.py --private` lists every call that reaches through a receiver into another script's `_func`. Calls to a base class's own `_func` don't count. Into world.gd there are **46 calls to 16 private functions, from 10 scripts**. 28 of them come from the tools (harness.gd 25, lookbook.gd 3). The other 18 come from 8 gameplay scripts.

| world.gd function | Calls | Callers |
| ------------------ | ---: | ------------------------------------------------------------------------- |
| `_cell_center` | 13 | dawn_screen 7 (`_fires` 3, `_place_everyone` 2, `_fire_at`, `_stand`), harness 5, escort 1 |
| `_teleported` | 7 | harness 5, `dawn_screen.close`, `reveal_screen.close` |
| `_flash_message` | 5 | `player.cast` 3, `escort._reached`, `inventory_screen._primary` |
| `_try_interact` | 3 | harness 3 |
| `_enter_map` | 2 | harness, `lookbook._stage` |
| `_keep_hours` | 2 | harness, `lookbook._stage` |
| `_load_map` | 2 | harness, `lookbook._stage` |
| `_open_saves` | 2 | harness, `pause_screen._saves` |
| `_play_ending` | 2 | harness 2 (one passes it as a Callable) |
| `_use_portal` | 2 | harness 2 |
| `_on_hp_changed` | 1 | harness |
| `_open_inventory` | 1 | harness (`open_screen("inventory")` already does this) |
| `_open_title` | 1 | `saves_screen._decline`, through `get_tree().current_scene` |
| `_play_reveals` | 1 | harness |
| `_talk` | 1 | harness |
| `_update_music` | 1 | `title_screen._leave` |

lookbook.gd also reads two private variables, `world._messages` and `world._message_now`.

The rest of the project has **117 more** cross-script private calls:

- 108 are data accessors that are private in name only: `Bestiary._data()` 53, `Economy._data()` 17, `Town._data()` 15, `Npcs._data()` 10, `Catalog._data()` 5, `Interactables._data()` 4 and `Quests._data()` 4. Renaming them `data()` would clear most of the list in one go (`Prologue.data()` already does it that way).
- 9 are scattered: the harness calling `GameState._grant_levels`, `GameState._start_festival`, `hud_dock._toggle_menu`, `shop_screen._switch`, `pause_screen._options` and `create_screen._refresh`; `journal_screen` calling `bounty_screen._when` twice; and `GameState.reforge_gear` calling `Bestiary._roll_rarity`.

## Screens laid out on a fixed 1280×720 canvas

`grep -nE "1280|720" scripts/*screen*.gd` hits 9 files:

| File | What it does with the canvas |
| --------------------- | ------------------------------------------------------------------------------- |
| `title_screen.gd:7` | `const VIEW := Vector2(1280, 720)`, used 8 times |
| `rankup_screen.gd:27` | `var view := Vector2(1280, 720)` for its layout math |
| `pause_screen.gd:19` | centres its card by hand on `resized`: `((Vector2(1280, 720) - card.size) / 2.0).round()` |
| `dawn_screen.gd:217`, `:250` | centres the plate across 1280 with its bottom at y 560; a full-width (1280) day card at y 250 |
| `saves_screen.gd:38` | centres its stack across 1280 |
| `changelog_screen.gd:21` | a title 1280 wide, to centre it |
| `create_screen.gd:72` | a status line pinned at (720, 626) |
| `skills_screen.gd:42` | a status line 720 wide |
| `screen.gd:34`, `:111` | comments only (the phone note) |

So eight screens depend on the canvas, plus the base's comments. The literals are the visible part. Across 19 screen scripts, about 165 lines place something at hard-coded coordinates. Some are halves of the canvas (`ledger_screen` puts its list at x 640). Others are rows above the footer (`journal` and `options` at (80, 640); `UiStyle.FOOTER_Y` is 672). The same arithmetic shows up outside the screens too:

- `hud_dock.gd:77`: the dock plate, `(1280 - w) / 2` and `720 - MARGIN - h`
- `world.gd`: message and objective plates centred across 1280, the run clock at `1280 - 24 - w`, `_dock_top()` defaulting to 720
- `ui_style.gd:616-632`: footer rows 1280 wide

`Touch.DESIGN` (`Vector2(1280, 720)`) is already the one true constant, but only `Touch` itself and the phone's tap bar read it.

The seven ledger screens (bank, bounty, dungeon, home, stats, throne and town hall) have no placements of their own, because `ledger_screen.gd` lays them out. **A shared layout base does the same one level up.** The helpers would go on `Screen` itself, since every screen extends it:

- **`CANVAS` (= `Touch.DESIGN`).** Replaces title's `VIEW`, rankup's `view`, pause's `Vector2(1280, 720)` and every bare `1280`, `720` and `640`.
- **`centre_x(control, y)` and `keep_centred(control)`.** Centre now, and again on every `resized`. They replace the hand-written centring in pause, dawn (×2) and saves. Outside the screens, they can replace the plates in hud_dock and world.gd.
- **`full_width(control, y, height)`.** Replaces changelog's 1280-wide title, dawn's day card and title's six `VIEW.x` widths.
- **`status_line()`.** One row above `UiStyle.FOOTER_Y`. Replaces create's (720, 626), skills' 720-wide line, and the `(80, 640)` lines in journal and options.
- **One place for the phone.** `Touch.center_offset` already shifts each screen as a whole (`Screen._ready`). Layout written against `CANVAS` keeps that working. Code that reads the viewport size itself (as `dim()` does) would go through `Touch.view_size(self)` in the same helper.

## Splitting world.gd

world.gd has 2,216 lines and 116 top-level funcs. The brief counted 114, which is the count without the two `static func`s, `split_messages` and `tag_of`. Today it holds:

- the frame loop
- map travel and dungeon floors
- the camera
- the HUD, messages and the battle log
- floating words and effects
- interaction with villagers, chests and the house
- spawning and fighting foes
- villagers' hours
- music
- every story moment

**Proposal.** Split it into ten children of the world. Each is a `Node` built in code and added in `_ready`, holding `var world` the way `light_rig.gd` and `atmosphere.gd` already do. world.gd stays the conductor:

- `_process` keeps calling each piece in today's order, so behaviour doesn't change.
- Being nodes, the pieces own their tweens (`node.create_tween()`, the paid-for pitfall in the skill notes).
- Each piece keeps the state it uses, so `_shake_*` moves to the camera and `_messages` to the messages.

Line counts are function bodies, before member declarations and doc comments.

| Piece (file, class) | Funcs → lines | Moves there | Public API (the old name, when it changes) |
| --- | --- | --- | --- |
| **world.gd** (conductor) | 22 → 372 | `_ready`, `_unhandled_input`, `_process`, `_notification`, `_setup_input`, `apply_video`, `_spawn_player`, `_load_map`, `is_walkable`, `_enter_map`, `_fade_in`, `_use_portal`, `_step_back`, `travel_to`, `_enter_house`, `_after_board`, `on_player_died`, `_cell_center`, `open_screen`, `_open_inventory`, `_open_saves`, `_open_title` | `map`, `view`, `actors`, `player`, `player_cell`, `TILE`, `harness`; `load_map(id)` (`_load_map`), `enter_map(next, arrival)` (`_enter_map`), `use_portal(target)` (`_use_portal`), `travel_to(waypoint)`, `cell_center(cell)` (`_cell_center`), `is_walkable(cell)`, `open_screen(name)`, `open_saves(web_save, welcome)` (`_open_saves`), `open_title()` (`_open_title`), `apply_video()`, `on_player_died()`; the pieces below as `world.camera_rig`, `world.messages` and so on |
| **world_delve.gd** `Delve` | 4 → 80 | `enter_floor`, `_leave_floor`, `_floor_cleared`, `skill_ward` | `enter_floor(level)`, `leave_floor()`, `skill_ward()` |
| **world_camera.gd** `CameraRig` | 12 → 77 | `_physics_process` (the hero's ticks), `_follow_hero`, `_teleported`, `_frame_lift`, `_dock_top`, `view_rect`, `in_view`, `_stretch`, `_fit_zoom`, `shake`, `_apply_shake`, `hit_stop`; `camera`, `camera_follows`, `ZOOM`, `CAMERA_EASE` | `camera`, `follows` (`camera_follows`), `cut()` (`_teleported`), `view_rect(margin)`, `in_view(at, margin)`, `fit_zoom()`, `shake(strength, seconds)`, `hit_stop(seconds, scale)`, `update(delta)` |
| **world_messages.gd** `Messages` | 9 → 92 | `_flash_message`, `_show_message`, `_advance_messages`, `_fit_message`, `_tags`, `split_messages`, `tag_of`, `_log`, `log_line`; the plate, the log box and the message queue | `flash(text)` (`_flash_message`), `log(lines)` (`_log`), `log_line(line)`, `is_idle()` (for the look book's `_messages` read), `update()`, static `split_messages`, `tag_of` |
| **world_fx.gd** `WorldFx` | 9 → 100 | `float_text`, `_floating`, `_pop`, `float_number`, `skill_flash`, `_level_up_burst`, `_show_loot`, `dust`, `appear` | `float_text(text, at, color, big)`, `float_number(value, at, color, crit)`, `skill_flash(at, color)`, `level_up_burst()`, `show_loot(pieces, at)`, `dust(at)`, `appear(enemy)` |
| **world_hud.gd** `Hud` | 7 → 216 | `_build_hud` (cut into its widgets: dock, boss bar, sky overlay, nameplate, objective), `_place_hud`, `hint`, `_hint_boards`, `_on_hp_changed`, `_update_objective`, `_update_nameplate`; the GameState signal wiring that is about the HUD | `dock`, `boss_bar`, `sky_overlay`, `hint(id, values, key)`, `place()` (`_place_hud`), `on_hp_changed(hp, max_hp)` (`_on_hp_changed`), `update()` |
| **world_interaction.gd** `Interaction` | 19 → 262 | `_try_interact`, `_facing_cell`, `_npc_beside`, `_chest_at`, `_tile_in_hand`, `_fishing_here`, `_asked_twice`, `_house_interact`, `_open_shop`, `_open_stall`, `_talk`, `_open_chest`, `_carry_water`, `_gather_at`, `_collect_ground_treasure`, `place_from_pack`, `_update_prompt`, `_show_prompt`, `_interact_key`; `prompt_label`, `_asked`, `prologue_bucket` | `interact()` (`_try_interact`), `talk(npc)` (`_talk`), `facing_cell()`, `place_from_pack(item_id)`, `step_on(cell)` (`_gather_at` and `_collect_ground_treasure`), `update_prompt()` |
| **world_foes.gd** `Foes` | 13 → 171 | `spawn_enemy`, `_spawn_enemies`, `_spawn_pack`, `_revive_packs`, `spawn_lairs`, `spawn_named`, `_mimic_wakes`, `can_notice`, `on_enemy_noticed`, `fights_like_boss`, `in_fight`, `on_enemy_died`, `boss_fell`; `pack_alive`, `kills`, `floor_foes`, `hunted_at`, `noticed_at`, `arrived_at` | `spawn_enemy(...)`, `spawn_for(map)`, `revive()`, `spawn_lairs()`, `spawn_named(id, cell)`, `mimic_wakes(sprite, chest)`, `can_notice(enemy)`, `on_enemy_noticed(enemy)`, `on_enemy_died(enemy)`, `fights_like_boss(enemy)`, `in_fight()`, `boss_fell()`, `kills` |
| **world_folk.gd** `Folk` | 3 → 55 | `_spawn_npcs`, `_respawn_npcs`, `_keep_hours` | `spawn_for(map)`, `respawn()`, `keep_hours(arriving)` (`_keep_hours`) |
| **world_soundscape.gd** `Soundscape` | 6 → 60 | `_update_music`, `_soundscape`, `_raining`, `_near_camp_fire`, `_hear_gold`, `_hear_hp`; `heard_gold`, `heard_hp`, `hushed_until`, `soundscape_left` | `refresh()` (`_update_music`), `hush(seconds)`, `update(delta)` |
| **world_stage.gd** `Stage` | 12 → 225 | `play_story`, `_ascend`, `_prologue_arrive`, `_prologue_wave`, `_play_dawn`, `_dream`, `_play_ending`, `_lanterns`, `_festival`, `_play_reveals`, `_tend_escort`, `_run_clocks`; `escort`, `escort_lost_at`, `run_clock` | `play_story(id)`, `play_ending(choice)` (`_play_ending`), `play_reveals()` (`_play_reveals`), `play_dawn()`, `dream()`, `ascend(title)`, `arrive(map)`, `update(delta)` (escort and run clock) |

The tool checked this table: all 116 functions are placed, each exactly once.

**What it changes for the callers.** The 46 private calls above become public calls on world or on a piece. For example, `world._cell_center` becomes `world.cell_center`, `world._teleported` becomes `world.camera_rig.cut()`, and `world._flash_message` becomes `world.messages.flash()`. The public calls move as well: `world.shake` becomes `world.camera_rig.shake`, `world.float_number` becomes `world.fx.float_number`, and `world.spawn_enemy` becomes `world.foes.spawn_enemy`.

harness.gd moves the most: 25 private calls, and it reads `world.player` 31 times. Each piece's PR has to update the harness too, and `godot/tools/flows.sh --quiet` is the check.

`_ready`'s harness arguments (`--town-tier`, `--prologue`, `--house-tier`, `--map`, about 40 lines) could move to harness.gd as well. That would leave the conductor near 330 lines.

**Constraints to keep.**

- **Motion contract.** The camera piece keeps it unchanged: hero ticks recorded in `_physics_process` with the world's `process_physics_priority = 10`, and every teleport going through `cut()`.
- **`--screenshot motion`** measures that contract, so it is the check for the camera PR.
- **HUD signals.** The 15 signal connections `_build_hud` makes today split by who listens: the dock and hints go to the HUD, the message and log lines to `Messages`, and gold and HP sounds to `Soundscape`.

**A good order.**

1. `CameraRig`, `Messages` and `WorldFx`: self-contained, and they take out 12 of the 46 private calls.
2. `Soundscape` and `Folk`.
3. `Interaction`.
4. `Foes` and `Delve`.
5. `Stage`.
6. `Hud`, last, because `_build_hud` is the wiring hub.

After each step, rerun the graph: `--private` should shrink and nothing should break.

## Splitting game_state.gd

game_state.gd has 2,178 lines, 143 funcs and 16 signals. Its data is already split out:

- the five persisted sections: `HeroState`, `InventoryState`, `SettlementState`, `ProgressionState` and `WorldState`
- the pure rules: `Economy`, `Town`, `Quests`, `Skills`, `Bestiary` and the rest

What's left in game_state.gd is two things: the methods that change the sections, which the game calls as `GameState.x()` 196 times, and the save and slot machinery.

**Proposal.** GameState stays the autoload and the only owner of the sections and signals. Its methods move into seven `RefCounted` classes that GameState creates in `_init` and holds as `GameState.trade`, `GameState.holdings` and so on. Each class gets a back-reference to its GameState.

They must hang off the instance, never call the `GameState` autoload from inside. 43 test files build their own GameState (`GameStateScript.new()`). A module that called the autoload would quietly change the real game's state from inside a test.

| Module (file, class) | Funcs → lines | Moves there | Public API (callers today) |
| --- | --- | --- | --- |
| **game_state.gd** (core) | 27 → 212 | the 16 signals; `hero`, `pack`, `settlement`, `progression`, `world`, `slots`, `settings`, `slot`, `dirty`, `roll`, `first_run`, `title_seen`, `standing_in`, `reveals`, `last_deed`; `_init`, `_ready`, `_input`, `_watch_the_page`, `_process`, `_notification`, `saves_kept`, `boot`, `play_slot`, `new_hero_in`, `free_slot`, `import_into`, `clear_slot`, `save_code`, `_use_slot`, `new_game`, `apply`, `to_dict`, `mark_dirty`, `save_now`, `move_to`, `walk`, `has_seen`, `mark_seen`, `town_tier`, `_pack_changed`, `_make_whole` | the slot and save API as today; `pack_changed()` (`_pack_changed`, which modules call about 50 times), `make_whole()` (`_make_whole`), `town_tier()`, `move_to`, `walk`, `has_seen`, `mark_seen`; the module handles |
| **state/trade.gd** `Trade` | 17 → 189 | `active_shop`, `at_station`, `stock_stage`, `price_of`, `shop_wares`, `owned_shop_map`, `sale_multiplier`, `trophy_sell_multiplier`, `forge_price`, `buy_item`, `sell_item`, `sell_gear`, `salvage_gear`, `reforge_gear`, `quench_gear`, `upgrade_gear`, `craft`; `stall_shop` | all public (shop_screen above all; inventory_screen, home_screen, world) |
| **state/holdings.gd** `Holdings` | 24 → 193 | `fund_commission`, `commission_buff`, `fund_project`, `project_built`, `buy_property`, `till`, `collect_till`, `expand_property`, `steps_now`, `investments`, `bank_deposit`, `bank_withdraw`, `fund_venture`, `collect_venture`, `_savings_now`, `perk_grown`, `song_crit`, `walk_bonus`, `is_settled`, `_resolve_settler`, `_top_up_potions`, `_start_festival`, `festival_on`, `win_ring_toss` | the money and town API; `start_festival(age)` (`_start_festival`, the harness), `resolve_settler(id)` for Questing (bank_screen, town_hall_screen, shop_screen, ring_toss_screen, player, world, map_view) |
| **state/household.gd** `Household` | 15 → 169 | `owns_house`, `buy_house`, `buy_house_upgrade`, `store_item`, `take_item`, `trophies`, `display_trophy`, `take_trophy`, `_shift_stats`, `combine_potions`, `furniture`, `home_buff`, `furniture_at`, `place_furniture`, `house_interact` | all public but `_shift_stats` (home_screen, map_view, shop_screen, world, player) |
| **state/questing.gd** `Questing` | 23 → 288 | `quest_on_offer`, `first_skill_heals`, `quest_open`, `givers_waiting`, `board_floors`, `finish_dialogue`, `resolve_quests`, `choose`, `escort_due`, `escort_arrived`, `timed_run`, `tick_runs`, `_note_deliveries`, `delivery_dip`, `ask_before_dip`, `_note_deeds`, `_prologue_talk`, `prologue_pouch`, `prologue_reached_town`, `_prologue_on`, `prologue_wave_cleared`, `prologue_douse`, `finish_prologue`; `_delivered`, `_dip_asked`, `_dip_asked_at` | the quest, dialogue and prologue API; `note_deliveries(announce)` and `note_deeds()` for the core's `pack_changed` and `apply` (world, dialogue_box, map, bounty and journal screens, the four screens that ask before a dip) |
| **state/spoils.gd** `Spoils` | 15 → 299 | `defeat_monster`, `_record_kill`, `_hunted`, `earn_xp`, `_grant_levels`, `clear_pack`, `revive_pack`, `wake_the_wilds`, `clear_floor`, `clear_deep`, `open_chest`, `is_opened`, `gather`, `fish`, `death_toll` | kills, xp, chests, floors and gathering; `grant_levels()` (`_grant_levels`, the harness) (world, map_view) |
| **state/upkeep.gd** `Upkeep` | 15 → 139 | `hurt`, `heal_hero`, `regen_resting`, `rest_mend`, `regen_stamina`, `hp_restore`, `carry_capacity`, `hero_art`, `equip`, `unequip`, `drop_item`, `drop_gear`, `use_item`, `rest_at_inn`, `wake_at_inn` | the hero's body and kit, all public (player, inventory_screen, shop_screen, dungeon_screen, hud_dock, rankup_screen, title_scene, world) |
| **state/training.gd** `Training` | 7 → 96 | `pay_for_skill`, `spend_stat_point`, `buy_beyond`, `forget_skills`, `buy_skill_node`, `choose_path`, `dock_skill` | all public (stats_screen, skills_screen, rankup_screen, player) |

The tool checked this table too: all 143 functions are placed, each exactly once. The names avoid the existing pure classes (`Prologue`, `Economy`, `Town`). Each module is the stateful partner of the rules it calls, as the communities show.

**Keeping saves byte-compatible with the web v4 format.**

- **Saving and loading stay put.** What reaches disk is `to_dict()`: `SaveCodec.initial_state()` merged with `RESUME_INTO`, then `hero.to_dict()` and each section's `write_into`. Loading is `apply()` through the sections' `from_dict`. Both stay in the core untouched, with `new_game`, `SaveCodec`, `SaveSlots` and the five section classes.
- **Modules persist nothing.** The fields that move with them (`stall_shop`, `_delivered`, `_dip_asked*`) were never saved, and `reveals` and `last_deed` stay in the core, also unsaved. No key is added, dropped or reordered.
- **The gate.** `test_save_codec.gd`, with its late-game web save and the web's own re-encode (`fixtures/web_save_late*`), is the check for every PR in this series.
- **Construction order matters.** `_init` must build the modules before it calls `new_game()`, because `apply()` already calls `_note_deliveries` (Questing).
- **Signals stay on GameState.** Nineteen `connect`s listen to `GameState.<signal>`: 18 in world.gd and one in player.gd. Modules emit through their owner, as in `owner.hp_changed.emit(...)`.

**Migrating without breaking 43 test files.**

1. Move each module's bodies, and leave a one-line delegate on GameState (`func buy_item(id: String) -> bool: return trade.buy_item(id)`). Callers and tests don't change, and the save tests prove nothing moved on disk.
2. Move callers to `GameState.trade.buy_item()` one script at a time, tests included. `graphify affected godot_scripts_state_game_state_buy_item` lists who is left.
3. Delete each delegate once nothing calls it.

The module order matters less than in world.gd. `Training`, `Household` and `Trade` are the most self-contained. `Spoils` and `Questing` touch the most state, so they go last.

## What graphify couldn't do

- **It can't read GDScript.** `.gd` isn't in its `CODE_EXTENSIONS`, so its own extractor, `graphify update` / `watch` and the git hook all see nothing here. Refreshing the graph means rerunning `codegraph.py` and then `cluster-only`. The "run `graphify update .`" advice in GRAPH_REPORT.md doesn't apply to this repo.
- **It can't name communities without an LLM.** `--no-label` leaves "Community N", so the names above are mine. graphify will reuse names from a hand-written `graphify-out/.graphify_labels.json`, but those ids only hold for one clustering, so I didn't keep one.
- **Degree counts neighbours, not uses.** It merges a `calls` and a `references` edge between the same two nodes, and ignores the tool's `count` field. graph.json keeps every edge and its `count`, and the fan-in tables above are worked out from those.
- **The graph can only be as good as its regexes.** It can't see:
  - calls through an untyped variable other than `world` (`var dock: Control` is understood only because world.gd assigns `preload("res://scripts/hud_dock.gd").new()` to it)
  - calls by name, like the harness's `node.has_method("_walk")` and then `._walk()`
  - inner classes' own funcs
  - signals connected by string

  It treats any untyped `world` as world.gd, which holds everywhere in this codebase today.
- **`graphify query` searches labels and doc text.** It doesn't search code, so a question about something no func is named after or documented as (a variable, say) finds nothing. For "who reads `world.player`", the per-member counts above came from the same scripts with the tool's own reader.
