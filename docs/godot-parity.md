# Godot parity

Since PIX-129 the Godot build is the game at **https://tomklotzpro.github.io/pixelheim/**.
The React/Pixi game lives on at **/pixelheim/classic/** on the same origin, so the
two editions share one `localStorage`: a classic hero can be brought into Godot
from the saves screen, and Godot heroes export save codes the classic edition
can import. The web code stays the source of truth for data and rules.

This is where each web feature stands in Godot.

## Ported

| Web feature                                                    | Godot                                                           | Notes                                                                      |
| -------------------------------------------------------------- | --------------------------------------------------------------- | -------------------------------------------------------------------------- |
| Title, character creation (7 classes, looks, names)            | `title_screen.gd`, `create_screen.gd`                           | Title has a link to the classic edition                                    |
| Open world, maps, portals, signs, chests, waypoints            | `world.gd`, `map_data.gd`, `interactables.gd`                   | Maps exported from `src/world/maps`                                        |
| Terrain art                                                    | `puny_terrain.gd`, `puny_sheet.gd`                              | Shade's Puny World, dual-grid corners, region tints                        |
| Day and night                                                  | `day_night.gd`                                                  | Sky colour on the web's clock                                              |
| Villagers, dialogue, pacing                                    | `npcs.gd`, `npc.gd`, `dialogue_box.gd`                          | Villagers pace on a clock, not on hero steps                               |
| Visible monsters, packs, elites, ailments, drops, xp           | `enemy.gd`, `state/bestiary.gd`, `state/ailments.gd`            | Real time; a web turn is one second                                        |
| Foraging and monster mastery                                   | `state/game_state.gd`, `state/bestiary.gd`                      | Same chances as the web                                                    |
| Dungeons: Ashen Mountain and Undermountain floors, both bosses | `dungeon_floor.gd`, `dungeon_screen.gd`, `state/dungeons.gd`    | Floors are generated rooms in Puny Dungeon art; the save stays at the gate |
| Victory                                                        | `world.gd` (`_floor_cleared`)                                   | A dialogue and the victory theme instead of a separate screen              |
| Rank evolution, auras, specialization fork                     | `rankup_screen.gd`, `state/ranks.gd`                            |                                                                            |
| Stats and stat points                                          | `stats_screen.gd`, `state/skills.gd`                            |                                                                            |
| Skill trees and skill casting                                  | `skills_screen.gd`, `skill_bar.gd`, `player.gd`                 | Number keys 1-6 cast; the web's damage and heal formulas                   |
| Inventory, nine equip slots, rarities                          | `inventory_screen.gd`                                           | Item lines match `itemStatLine`                                            |
| Shops, crafting at the stations                                | `shop_screen.gd`, `state/economy.gd`                            |                                                                            |
| House: storage, workbench, trophies, alchemy nook, furniture   | `home_screen.gd`, `state/settlement_state.gd`                   |                                                                            |
| Town tiers, owned businesses and rent, bank                    | `town_hall_screen.gd`, `bank_screen.gd`, `state/town.gd`        |                                                                            |
| Quests and journal                                             | `journal_screen.gd`, `state/quests.gd`                          |                                                                            |
| Codex and bestiary                                             | `codex_screen.gd`                                               |                                                                            |
| World map, fog of war, fast travel                             | `map_screen.gd`, `discovery.gd`                                 |                                                                            |
| Music, stingers, ambience                                      | `sound.gd`                                                      | Web synth rendered to WAV by `pnpm audio:render`                           |
| Saves: autosave, three slots, save codes, migrations           | `state/save_codec.gd`, `saves_screen.gd`, `state/web_import.gd` | Web v4 format; a late-game web save re-encodes byte for byte               |
| Pause, options, rebindable keys, gamepad                       | `pause_screen.gd`, `options_screen.gd`, `controls.gd`           | Adds scanlines and fullscreen                                              |
| Reduced motion                                                 | `options_screen.gd`, `title_screen.gd`, `rankup_screen.gd`      | An option, not the browser's setting; stills the title and the rank-up     |

## Not yet in Godot

| Web feature                                | Status                                                                                                                  |
| ------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------- |
| Mini-map in the corner of the world screen | Not ported; the world map (M) covers it                                                                                 |
| Changelog page                             | Not ported; the classic edition still has it                                                                            |
| Touch controls                             | No virtual stick; the web export needs a keyboard or a gamepad                                                          |
| Town buildings and interiors in Puny art   | Still Pixel Crawler (the inn's hearth is a furnace frame); the matching Puny pack is paid, pending a decision (PIX-130) |

## Release checks

- `godot/tools/flows.sh` drives the ten flows a release must not break through the screenshot harness: spawn, portal, chest, shop, craft, quest, rank-up, fight, death and the inn, saves. Each one checks the harness report and leaves a picture in `godot/flows/`.
- `test_save_codec.gd` loads a late-game save made by the web's own reducer (level 18, all fifteen floors, house, village, a business, savings) and checks Godot writes back exactly what the web writes.
- The web build loads behind the title's own night scene (`godot/tools/splash.sh`), with the loading bar where the menu appears.
- Draw calls, as the harness reports them: 76 in any map (tiles batch by texture, even zoomed out over the whole overworld), about 160 with a full screen like the inventory open, 158 on the title.

## Known issues shared with the web

- Alchemist Vex's quest _Greens for the Cauldron_ can't be accepted in either edition: talking to him opens his counter, so his dialogue never closes and the quest never starts (PIX-125).
