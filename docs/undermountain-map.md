# The Undermountain: what it touches, before it goes

> **A planning record for PIX-263**, which prepares PIX-257 (Tom: « On dégage le Sous-Mont »). Project: Pixelheim: Solid Ground. Built 2026-10-09 from `6a1578c` (v0.171.0). No game code was changed to write it.

## What "the Undermountain" is in the code

The brief describes one thing; the game has three, stacked:

| Layer | Floors | Gate | Opens when | Boss | Stays? |
| --- | --- | --- | --- | --- | --- |
| **The Ashen Mountain** (dungeon `mountain`) | 1-10 | the door at overworld (48,6) | the four relics are home with Maren, or any floor was ever cleared (`Relics.gate_open`, PIX-170) | Fafnyr the Ashen (`dragon`), floor 10 "The Ashen Throne" | yes, unless Tom says otherwise (question 1) |
| **The Undermountain** (dungeon `undermountain`, « Le Sous-Mont ») | 11-15 | its own cave at overworld (24,10) | Fafnyr is down (`unlocked_level` ≥ 11); until then the gate shows a seal | Morvax the Deathless (`lich`), floor 15 "Throne of the Deathless", then the throne choice | **goes** |
| **The Deep Hunt** | 16+ ("depth 1" is floor 16) | a hole that opens beside the stairs once floor 15 is cleared, and extra rows under the Undermountain's gate | Morvax is down | a warden every tenth depth ("The Deep Warden", a dragon; "The Hollow King", a lich) | **goes** (it lies below Morvax; question 2) |

So the gate "barred until the relics come home" is the **Ashen Mountain's** door, not the Undermountain's. The Undermountain has its own cave, sealed until the dragon falls. This map treats "the Undermountain" as floors 11-15, Morvax, the throne and the Deep Hunt under them. The Ashen Mountain is mapped only where it leans on them.

The game's current pace (`test_pacing.gd:2-9`, `:159-161`): about level 12 at the mountain's gate, 16 at the Ashen Throne, 18 at the Throne of the Deathless. The Deep Hunt starts at foe level 19 (`combat.json` `deepHunt.startLevel`) and climbs 1.5 levels a depth. (The "around 14 at the bottom" of the 0.83.0 changelog, PIX-141, predates PIX-170, which moved the mountain to the end of the game and lifted its floors.)

### How this map was made

- `python3 godot/tools/codegraph.py`, then `graphify cluster-only . --no-label` (1,597 nodes, 6,435 edges), then `graphify affected` on `Dungeons`, every `Dungeons.deep_*`/`is_final`/`floor_count`/`milestone`/`modifier`, `throne_screen`, `Story.ending_of`/`ending_scene`/`can_lay_to_rest`, `GameState.clear_deep`, `InventoryState.deepen`/`deep_name`, `Hunts.deep_guardian`, `world.skill_ward`, `Deeds.count`, `Relics.gate_open`, `Town.homecoming`, `Economy.stock_stage`; and `graphify query` on the Deep Hunt, Morvax and the seal.
- The graph misses data-driven links (moments by string, quests by monster id, posting by floor number, town ages by floor), so every data file, map, test, flow, harness flag and French string was also read and grepped.

---

## 1. What exists

Paths under `scripts/`, `assets/`, `test/`, `tools/` and `locale/` are in `godot/`; the others are from the repo root. **U** = floors 11-15 / Morvax, **D** = the Deep Hunt.

### 1.1 Entry points

| How a player gets in | Where |
| --- | --- |
| The Undermountain's cave, a `dungeon` portal at overworld (24,10) | `assets/maps/overworld.json:18-25` (portal), `:108` (the `cave` tile in row 10) |
| The fast-travel waypoint "The Undermountain" (at 24,10, arrival 26,10) | `assets/maps/interactables.json:418-430` |
| The floor select: rows 11-15, its seal text until a floor opens | `scripts/dungeon_screen.gd:15-19`, `:26-32`; seal in `assets/data/combat.json:5323-5333` |
| Down from floor 15: a "deeper" hole beside the stairs | `scripts/world.gd:870-878` (made), `:509-510` (`"deeper"` → `enter_floor(level + 1)`) |
| The Deep Hunt rows under the Undermountain's gate (depth 1, the first of every tier reached, the next past the deepest) | `scripts/dungeon_screen.gd:35-43`; `Dungeons.deep_entries` `scripts/state/dungeons.gd:154-165` |
| A deep named monster takes its depth's stair | `scripts/world.gd:832-841` |
| Harness: `--floor N` (N ≥ 11), `gate --dungeon undermountain [descend]`, `--cleared 15`, `throne`, `ending [rest]`, `--story morvax/ending/ending_rest/descent` | `scripts/harness.gd:127-132`, `:138-151`, `:251-260`, `:527-531`, `:537-543`, `:133-137` |

Nothing else reaches it: no NPC, quest or sign sends the player to (24,10), and the Ashen Mountain's door only ever opens the `mountain` dungeon (`world.gd:500`).

### 1.2 Scripts and functions

**Wholly the Undermountain or the Deep Hunt**

| File:line | What | |
| --- | --- | --- |
| `scripts/throne_screen.gd:1-74` | "The Throne Below": destroy Morvax, or lay him to rest if `Story.can_lay_to_rest` (Maren's confession seen and Liane's last page found). Esc does nothing. | U |
| `scripts/state/dungeons.gd:18-25` | `is_deep`, `depth_of`: anything past `floor_count()` is the Deep Hunt | D |
| `scripts/state/dungeons.gd:28-94` | `deep_def`: a depth generated from its number (foes, elites every 3rd, a warden every 10th, the twist, hoard, milestone crystal), cached in `_deep` | D |
| `scripts/state/dungeons.gd:97-165` | `deep_level`, `is_warden_depth`, `modifier_at`, `modifier`, `loot_luck`, `milestone`, `next_milestone`, `milestone_reached`, `deep_entries` | D |
| `scripts/state/dungeons.gd:186-191` | `deep_tier`: how deep a piece is forged | D |
| `scripts/state/dungeons.gd:214-219` | `any_open`: "a sealed dungeon (the Undermountain) shows its seal" | U |
| `scripts/state/game_state.gd:1970-2001` | `clear_deep`: new deepest, hoard, XP, milestone line, `deep:N` reveal, "a hole into the dark" | D |
| `scripts/state/hunts.gd:33-58` | `_deep_numbers`, `deep_guardian`: deep named monsters, posted as depths are cleared | D |
| `scripts/world.gd:591-596` | `skill_ward`: skills hit at 70% on a warded depth (read by `player.gd:370-371`) | D |
| `scripts/state/deeds.gd:22-23` | the `deepest` deed kind (Ten Below, Thirty Below) | D |
| `scripts/state/story.gd:74-94` | `ending_of`, `ending_scene`, `can_lay_to_rest` | U |
| `scripts/world.gd:1540-1583` | `_play_ending(choice)`: home to the square, festival (destroy) or lanterns (rest), the `victory` track, a tour of each age's landmark, then the ending cutscene and credits | U |
| `scripts/world.gd:1585-1615` | `_lanterns`: five lanterns on the square, the rest ending only | U |

**Shared code with Undermountain branches**

| File:line | What the branch does | |
| --- | --- | --- |
| `scripts/state/dungeons.gd:1-15` | the class doc ("their fifteen floors"); `floor_def` hands anything past `floor_count()` to `deep_def` | U, D |
| `scripts/state/dungeons.gd:168-183` | `lift`, `drop_floor` (capped at `floor_count()`), `epithet` ("Deep" past it) | D |
| `scripts/state/dungeons.gd:199-228` | `floor_count()` = `combat.json levels.size()` (15); `is_final(level)` = `level == floor_count()` ("clearing the last floor wins the game"); `unlocked_after` caps at it | U |
| `scripts/state/game_state.gd:1958-1960`, `:1967` | `clear_floor`: on the final floor, "Behind the throne, a stair goes on … the Deep Hunt", and `victory` on its first clear | U, D |
| `scripts/state/game_state.gd:1950-1951` | `clear_floor`: a homecoming reveal for floors with one (10 and 15) | U |
| `scripts/state/game_state.gd:1378-1379`, `:1441-1442` | `defeat_monster(..., mountain)`: the twist's extra loot luck | D |
| `scripts/state/game_state.gd:1621-1627` | `_hunted`: a deep named monster's prize is epic and deep-forged | D |
| `scripts/state/game_state.gd:484-485`, `:491-512` | `reforge_gear` re-rolls a deep piece's affixes; `quench_gear`, Hilda's deep-only gold sink (PIX-218) | D |
| `scripts/state/game_state.gd:877-879` | `board_floors` passes `progression.deepest` | D |
| `scripts/world.gd:803-848` | `enter_floor`: replay gold on a beaten depth (`:808-809`), reads `deepHunt` **on every floor** (`:813`), swift and venom twists (`:815-822`), warden names (`:823-825`), the deep named guardian (`:832-841`), deep floor names (`:844`), the twist line (`:845-846`), `boss:<id>` moment (`:848`, plays `morvax` on floor 15) | U, D |
| `scripts/world.gd:859-885` | `_floor_cleared`: `clear_deep` or `clear_floor`; the "deeper" hole on a deep or final floor; the throne screen on the first final clear when no ending was seen | U, D |
| `scripts/world.gd:671` | the `deepwind` bed when `floor_level > 10` (hard-coded) | U, D |
| `scripts/world.gd:1002-1004` | `_spawn_npcs` passes `deepest` so Maren speaks of milestones | D |
| `scripts/world.gd:1172-1188` | `_talk`: Maren's story lines, filtered by the ending played | U |
| `scripts/world.gd:1423-1427` | `_dream`: "a night under Sela's roof brings Morvax's voice" | U (story) |
| `scripts/world.gd:1675-1677` | `_play_reveals`: a Deep Hunt milestone's homecoming | D |
| `scripts/dungeon_screen.gd:1-5`, `:35-106` | the doc ("a seal on the Undermountain until the dragon does"); deep rows, twist, deepest, next milestone, hoard; `DEEPEST n` note | U, D |
| `scripts/dungeon_floor.gd:74-77` | per-encounter lift and warden name | D |
| `scripts/state/bestiary.gd:82-85` | gold grows linearly past `goldLinearFrom` (19), which only the Deep Hunt reaches | D |
| `scripts/state/bestiary.gd:307-328` | `roll_drop`: past `floor_count()` gear comes from `deepHunt.gearIds` and is deepened | D |
| `scripts/state/hunts.gd:28-29`, `:67-79` | `named` merges deep numbers; `board_floors` counts depths as floors past 15 | D |
| `scripts/state/inventory_state.gd:60-92`, `:107-111`, `:150-155` | `deepen`, `deep_affixes`, `deep_name` ("Deep-forged", "Abyssal"…), the gear name, the pre-PIX-218 mend of old deep pieces | D |
| `scripts/state/hero_rules.gd:33-47` | `deepBonus` added to a piece's armour and damage | D |
| `scripts/state/economy.gd:71-75`, `:85-92` | a deep tier's worth; the quench's price | D |
| `scripts/state/economy.gd:266-272` | `_floor_span`: "the mountain from floor %d" when a list reaches `floor_count()` | U |
| `scripts/state/town.gd:96-110` | `age_blockers`: the `cleared` kind (the City asks for floor 15) | U |
| `scripts/state/town.gd:152-154`, `:164-166`, `:509-518` | `homecoming(15)`; `lanterns()`; `trophy_stat_delta` hard-codes `lich_crown` (+2 to every stat) | U |
| `scripts/npcs.gd:27`, `:48-53` | Maren opens with the deepest milestone's word | D |
| `scripts/journal_screen.gd:179-182` | "The Deep Hunt: deepest depth N" | D |
| `scripts/bounty_screen.gd:13-14`, `:49-50`, `:65-66` | "Deepest Hunt: depth N"; deep named notices | D |
| `scripts/shop_screen.gd:39-40`, `:240`, `:449-450`; `scripts/inventory_screen.gd:247-248` | the quench row; the deep bonus shown | D |
| `scripts/enemy.gd:76-77`, `:109-116`; `scripts/boss_brain.gd:3` | `pace` (the swift twist); Morvax's boss brain (`bossPatterns.lich`) | U, D |
| `scripts/state/progression_state.gd:24-26`, `:47`, `:71-72` | `deepest`, saved as `deepHunt` only once > 0 | D |
| `scripts/state/save_codec.gd:158-162` | opens floor `max cleared + 1`, capped at `Catalog.level_count()` (15, `assets/data/catalog.json:2145`) | U |
| `scripts/state/text.gd:113` | `Text.forget` clears `Dungeons._deep` (deep names are translated) | D |
| `scripts/puny_art.gd:170-171` | sprites for `boneknight` and `lich` (Mini World Skeleton-Soldier, Necromancer) | U |
| `scripts/title_screen.gd:95` | the title's tagline: "Fifteen floors. One dragon. Worse things below." | U |

`Dungeons.floor_count()` is called 20 times in 7 scripts, and `graphify affected` reaches 36 functions in 10 scripts from it (through `is_deep`, `is_final`, `floor_def`, `drop_floor`). It means four different things today: "Fafnyr's floor is not the last" (`is_final`), "where the Deep Hunt begins" (`is_deep`, `depth_of`, `deep_def`, `Hunts`), "the deepest loot pool" (`drop_floor`, `roll_drop`, `material_sources`, `_floor_span`) and "how many floors to list" (`dungeon_screen`, `harness`). **Removing floors 11-15 from `levels` without touching the code silently makes floor 10 the final floor, starts the Deep Hunt at floor 11, and plays Morvax's throne and ending after Fafnyr.** See 3.5, step 1.

### 1.3 Data

**`assets/data/combat.json`**

| Lines | What | |
| --- | --- | --- |
| 5189-5305 | `levels` 11-15: The Sunless Stair, Hall of Echoes, The Vaulted Hoard, Ember Warrens, Throne of the Deathless (hoards: `obsidian_blade` on 12, `runic_armor` on 13, `lich_crown` on 15; gold 570-1740; lift 6 down to 3) | U |
| 5323-5333 | `dungeons.undermountain` (name, floors, `sealed` text) | U |
| 163-173, 225-241 | monsters `boneknight` (lv 11) and `lich` (Morvax, lv 15) | U |
| 1392-1395, 1422-1447, 1466-1478 | `bossIds` "lich", `bossPatterns.lich` (ring and summon), `bossAttacks.ring`/`summon` (only the lich uses them) | U |
| 1701-1720 | `floorPools` floor 12 (floors 12-15 and every deep stack drop); its gear is floor 8's plus `obsidian_blade` | U, D |
| 1134-1141 | `gathering.floorMaterials` 11 (`deep_root`) and 14 (`grave_moss`) | U |
| 1774-1779 | `families` entries for shade, boneknight, lich, mimic, imp | U |
| 5531-5569 | named `gulp` (Grandmother Gulp, Mirefen): **`postedAfter: 12`**, no `postedRelics` | U-gated |
| 5734-5878 | named `grimshade`, `bone_abbot`, `hollowmother`, `ironheart` (`deepDepth` 6/11/16/21, `mapId: "deep"`) | D |
| 5959-5990 | `floorLift` "about" text; `goldLinearFrom` 19 / `goldLinearStep` (deep only) | D |
| 5991-6165 | `deepHunt`: start level, foes, wardens, modifiers (swift, warded, venom, proud), milestones (depths 5-50, `deep_crystal_*`, Maren's and the town's words), hoard potions, `gearIds` | D |
| 6299-6306 | `namedDeep` multipliers | D |
| 5353-5360 | `skillTierLevels [1,3,6,10,13,17]`: tiers at 13 and 17 assume levels past Fafnyr | balance |

**`assets/data/story.json`**

| Lines | What | |
| --- | --- | --- |
| 693, 695, 698 | moments `boss:lich` → `morvax`, `victory` → `ending`, `victory:rest` → `ending_rest` | U |
| 277-347 | scene `morvax` ("You're late, courier. Fifty years late.") | U |
| 348-414 | scene `ending` (destroy), with the credits (392-408) | U |
| 618-689 | scene `ending_rest` | U |
| 731-750 | Liane's pages VII-X on floors 11-14; page X is "Liane's last page", which the rest ending asks for | U |
| 816-834 | Maren's `maren_peace` (rest) and `maren_after` (destroy), after floor 15 | U |
| 233-276, 694 | scene `descent` after floor 10, ending "The Undermountain is open." (268) | points forward |
| 3-184, 415-617, 701-730, 763-815 | the rest of the story points at Morvax: the opening's "whispers come from below" (158), the crypt's "MORVAX OF PIXELHEIM" shield (437), the forge's seal "broken from below" (474), the dreams (`dream_courier` 514 is Morvax's voice, `dream_five` 559, `dream_door` 604), pages I, II, V and VI (VI, floor 9: "Morvax found a stair behind the hoard"), `maren_ingot` (767), `maren_liane` ("if you find her pages up there", 786) and **`maren_confession`** (806-815, after floor 10: "He isn't dead, courier. He's waiting. Go down and end it.") | points forward |

**`assets/data/progression.json`**

| Lines | What | |
| --- | --- | --- |
| 1357-1409 | main quest chapter 4 "The Deathless": optional `fountain` and `confession` (mountain content), then `stair` (cleared 11), `hoard` (13), `morvax` (15) | U |
| 1411 | `mainQuest.done`: "Pixelheim is safe. The mountain is quiet, and the tavern isn't." | U |
| 478-495 | quest `bram_imps`: kill 2 imps ("imps from the mountain's deep floors"); imps live only on floors 14-15, the Deep Hunt and the prologue | U-gated |
| 345-363 | quest `loras_horn`: deliver an `imp_horn` (still dropped by floor pool 8, Mirefen loot and the prologue's embers) | fine |
| 1514-1534 | `prologue.embers` are `imp`s: the imp monster must stay | shared |
| 1573-1589 | deeds `deep_10` (Ten Below), `deep_30` (Thirty Below) | D |
| 1590-1596, 1611-1617 | deeds `all_hunts` (counts the four deep named and Gulp) and `bestiary` (counts every monster key, so `boneknight` and `lich`) | U, D |

**`assets/data/town.json`**

| Lines | What | |
| --- | --- | --- |
| 823-830 | **age 4 (the City) requires `cleared 15`: "Nothing stirs below: cast down Morvax"** | U-gated |
| 833-927, 1166-1197 | the City's projects (`grand_avenue`, `flower_beds`) and the commissions offered once every age is built | U-gated |
| 1074-1076 | homecoming "15" | U |
| 1116-1137 | `lanterns`, the rest ending's five | U |
| 976-978, 982-1027 | trophy buffs: `lich_crown`, `deep_crystal_*`, `medal_ten_below`, `medal_thirty_below` | U, D |

**`assets/data/economy.json`**: tier-4 `ageStock` (odo 26-33: `city_banquet`, `kings_signet`; smith 76-84: `tower_shield`, `city_plate`, `aegis_of_the_ash`; alchemist 105-113: `greater_potion`, `phoenix_draught`, `everflask`), all behind the City; alchemist `greater_potion` at stage 11 (103); `stockByRelics` ends at 11 (848-854); `deepTiers` (873-884); `quench` (926-932). U-gated, D.

**`assets/data/catalog.json`**: `lich_crown` (495-502), `deep_crystal_5…50` (1735-1782), `medal_ten_below`/`medal_thirty_below` (1783-1798), `levelCount: 15` (2145). Flavour that points down: `starfall_staff` "the mountain's deep floors keep a few" (186).

**`assets/data/npcs.json`**: Maren's "There are older things below" (14); Loras's City line "I need the ending - Morvax's, ideally" (596); `settler_serra` and `settler_fenn` arrive only in the City (`minTownTier: 4`, 227, 241), and every villager's tier-4 lines (Mira 193, Tomas 213, Iva 550, Loras 595, Wren 638, Mirelle 679) wait on it too.

**`assets/data/audio.json`** and **`assets/audio/`**: themes `morvax` (158-180), `ending` (202-222), `ending_rest` (223-244) and their WAVs (`music/theme_morvax.wav`, `theme_ending.wav`, `theme_ending_rest.wav`); the `victory` track (61-64), played only by the endings; the `deepwind` bed (133, `ambience/bed_deepwind.wav`, synthesized by `tools/synth.py:199-220`).

**`assets/data/hints.json`**: nothing. **`assets/data/interiors.json`**: nothing (its "thrones" are hall furniture).

### 1.4 Maps

- `assets/maps/overworld.json:18-25`, `:108`: the Undermountain portal and its `cave` tile at (24,10), at the west end of the Ash below the mountains. The Ashen Mountain's door is at (48,6) (`:10-17`).
- `assets/maps/interactables.json:418-430`: the `undermountain_cave` waypoint (index 4 of the waypoints; `test_discovery.gd:42` counts on the order).
- No floor is a map on disk: floors 11-15 and every depth are generated by `DungeonFloor.plan` (`scripts/dungeon_floor.gd`). Deep named monsters use the pseudo-map `"deep"`.

### 1.5 Screens

- `throne_screen.gd` (Morvax's choice), wholly U.
- `dungeon_screen.gd` (the floor select, shared with the Ashen Mountain): seal, deep rows, twist, milestones.
- `reveal_screen.gd` (shared): the ending's tour and the milestone homecomings.
- `journal_screen.gd` (Story tab: pages VII-X; "The Deep Hunt: deepest depth N"; deeds), `bounty_screen.gd` (deep notices, "Deepest Hunt"), `shop_screen.gd` (Hilda's quench), `inventory_screen.gd` (deep names and bonus), `codex_screen.gd` (boneknight, lich: it lists every monster in the data).
- `dawn_screen.gd` is **not** the ending: it is the dawn after the Night of Ash (the prologue, PIX-197), and the `dawn` flow tests that. It does not touch the Undermountain.

### 1.6 Story beats, in the order a player meets them

1. The title's tagline ("Fifteen floors. One dragon. Worse things below.") and the opening ("And now the whispers come from below.").
2. Dreams at the inn (after the Night of Ash, floor 3, floor 7): Morvax's voice.
3. Floors 1-9: Liane's pages I-VI; Morvax is one of the five who climbed. The crypt (floor 3): his name on a shield. The forge (floor 7): the seal was broken from below.
4. Floor 10, Fafnyr: the `descent` scene ("The voice below…", "The Undermountain is open."). Maren's `maren_confession`: Morvax led the five, went down the stair, the others died holding it; "Go down and end it."
5. Floors 11-14: pages VII-X (the fall of the five).
6. Floor 15: the `morvax` scene, the fight, the throne choice, `ending` or `ending_rest` with credits, Maren's last words, the homecoming.
7. Below: the Deep Hunt, without story beyond milestone words.

Morvax is the main story's antagonist from the first minute, not only the Undermountain's boss.

### 1.7 Translations

`locale/fr.po` (3,360 entries) is written from scratch by `python3 godot/tools/i18n.py` out of the data and scripts; each entry's `#:` line names the first source it was found in, and translations are kept by msgid. So removing the English strings and rerunning the tool drops the dead French by itself, and a string that survives elsewhere keeps its French. CI runs `i18n.py --check`, which fails while `messages.pot` is stale. `test_i18n.gd:149` checks the Deep Hunt's French name.

About **187 game strings** go with the Undermountain, Morvax, the throne and the Deep Hunt (line = the `msgid` line):

- The names: "The Undermountain" « Le Sous-Mont » (6716; also the waypoint's name), the seal (6856), "Morvax the Deathless" « Morvax le Sans-Mort » (6120), "The Deep Hunt" « La Traque des Profondeurs » (6664), "%s, depth %d" (12536).
- Floors 11-15: names, descriptions and epithets (14 strings, e.g. "The Sunless Stair" 6700, "Throne of the Deathless" 6968).
- Monsters: Bone Knight (5372), Fire Imp (5684, also the prologue's id), Morvax and his two boss lines (6112, 6116).
- Items: the Crown of the Deathless (332, 768), the Obsidian Blade (928, 1436), the six crystals, the two depth medals; the trophy labels (10228-10248).
- The Deep Hunt's data: descriptions, "Deep", the wardens, the four twists, the milestone lines (28 strings); the four deep named (20); the deep tier names (7332-7388); the two deeds (8396, 8400, 9312, 9612).
- Main quest chapter 4 "The Deathless" (9372 and 9 step and hint strings), Bram's "Imp-ossible" (5 strings), the story's `descent`, `morvax`, both endings, pages VII-X, `maren_confession`, `maren_peace`, `maren_after` (31), Maren's "older things below" (7588), Loras's City line (7532), the City's "Nothing stirs below: cast down Morvax" (10404), homecoming 15 (10492).
- Scripts (34): `throne_screen.gd` (12, 13176-13220), the rest ending's lantern line (`world.gd`, 13336), **the title's tagline "Fifteen floors. One dragon. Worse things below."** (`title_screen.gd:95`, 13248), the deep lines of `dungeon_screen.gd` (11012-11072), `bounty_screen.gd` (10692, 10740), `journal_screen.gd` (11608), `game_state.gd` (12808-12832, 12892) and the quench in `shop_screen.gd` (12172, 12208).

About **88 shared strings** stay but some need rewording: Shade (6460), Mimic (6092), "Ember" (8508, also the Night of Ash); the Runic Armor, Greater Health Potion ("for those who go below", 1100), Starfall Staff ("the mountain's deep floors keep a few", 112) and Imp Horn; Every Bounty Paid ("the Reach's and the deep's", 9200); the fountain step and `mainQuest.done` (9072); the floors 1-10 story lines that name Morvax, the stair or "below" (36 strings, from the opening's 9896 to page VI's 9920); the ending's town lines and credits (8, reusable if the ending moves); "A deeper way opens" (12812) and "No map reaches this deep" (13368), which serve every floor.

The changelog's French (about 65 strings about the topic, 17 more in passing) stays as it is: the changelog is history.

### 1.8 Tests, flows and the harness

**Test files that go whole:** `test/unit/test_deep_hunt.gd` (13 tests, all D or floor 15), `test/unit/test_deep_gear.gd` (6 tests; keep `:48 test_a_deep_piece_from_before_is_mended_once` in some form while old deep pieces load).

**Tests that go** (in files that stay): `test_endings.gd:19`, `:28`, `:35` (move its three settler-arc tests, `:44`, `:54`, `:73`, elsewhere); `test_endgame.gd:43`, `:101` (and the `_hits_at` helper, `:21`); `test_bosses.gd:76` (the lich raising the dead); `test_economy.gd:262` (deep gold); `test_loot.gd:114` (deep tiers); `test_deeds.gd:19` (uses `deep_10`; rewrite on another deed); `test_dungeons.gd:60` (the final floor's first clear is victory: rewrite for the new final floor).

**Tests to rewrite** (they test what stays, with numbers from 11-15 or the deep):

- `test_dungeons.gd:16` (`floor_count()==15`, the `undermountain` floors, `boss_of(15)`), `:26` (`any_open("undermountain")`, `unlocked_after(15,15)`).
- `test_main_quest.gd:20` (fails if steps still name floors past `floor_count()`), `:64` (uses floor 11, "hoard", "The Deathless"), `:87` (the quiet end after floor 15).
- `test_cutscene.gd:62` (`boss:lich`, `victory`, `boss_of(15)`), `test_story.gd:23` (ten pages, four on floors 11-14), `test_sound.gd:26` (`morvax`, `ending`, `ending_rest` themes).
- `test_pacing.gd:113` (gate 11-13, floor 10 15-17, **floor 15 17-19**), `:166` (`lift(15) < lift(1)`), `:233`; its `FLOOR_QUESTS` (`loras_horn` at 12, `bram_imps` at 14) and `FLOOR_SWEEPS` (the Mirefen at 12).
- `test_armour.gd:38`, `:76` and `KITS[19]` (the level-19 kit at the bottom).
- `test_bosses.gd:51` (Fafnyr and Morvax through three phases), `test_past_ten.gd:174` (`lich_crown`), `test_house.gd:61` (trophies with `lich_crown`).
- `test_loot.gd:85` (floor 13 rolls `obsidian_blade`), `test_hunts.gd:68` (`next_notice(range(1,16))` is `grimshade`), `test_combat.gd:188` (the "Deep" epithet), `test_i18n.gd:149` (the Deep Hunt's French name), `test_traders.gd:17` (floors lead the stock at 13), `test_gathering.gd:55` (`grave_moss` on 15), `test_leads.gd:18` (hoards of floors 13-15), `test_town.gd:171` (the City's budget "by Morvax").
- `test_discovery.gd:34` (waypoint index 5), `test_map_data.gd:37` (9 overworld portals).
- `test_save_codec.gd:57` (cleared floors reopen new content, through `levelCount`), `:141` and `:160` (the late web save: level 18, 15 floors cleared, `unlockedLevel` 15; **must keep passing unchanged**), `test_frostgate.gd:27`, `test_greyhold.gd:26`, `test_saltmere.gd:20` (`range(1,16)` meaning "everything cleared").

**Fixtures:** `test/fixtures/web_save_late.txt` and `web_save_late_reencoded.json` are a web hero at level 18 who beat Morvax: `clearedLevels` 1-15, `unlockedLevel` 15, `lich_crown` in the pack, `obsidian_blade` equipped, `runic_armor`; no `deepHunt`. It is the gate for every save-touching PR (it must load and re-encode byte for byte). `web_save_v4.txt` is a level-1 hero (unaffected).

**Flows** (`tools/flows.sh`): `throne` (`:57`, `--cleared 15 --seen maren_confession throne`, expects the tour) and `deep` (`:68`, `--floor 16 clear`) go; the header comment (`:6-11`) names both. `gate` (`:67`) is the Ashen Mountain's barred door and stays.

**Harness** (`scripts/harness.gd`): `throne` (`:537-543`) and `ending [rest]` (`:527-531`) go; `--floor N` (`:127-132`) and `gate --dungeon` (`:138-151`) stay for the mountain; `--cleared N` (`:251-260`) must clamp to `floor_count()` (today `--cleared 15` writes floors 11-15 into the save). No flag sets `deepest`. `lookbook.gd:27` shoots floor 5 only, but `enter_floor` reads `deepHunt` on every floor (`world.gd:813`), so deleting that data block breaks the floor shot until the code changes.

### 1.9 Documents

- `README.md:22` (the pitch: "five more floors of the Undermountain, down to Morvax the Deathless"), `:33` (the ending's credits), `:100` (roadmap: "The Undermountain: floors 11-15 and a second boss").
- `godot/README.md:104-105` (`--floor 10`, "15 for Morvax"; `--story ending`).
- `docs/godot-parity.md:24`, `:67`, `:112`.
- `.claude/skills/pixelheim-godot/SKILL.md:51`, `:59` (the dungeon harness flags; they stay for the mountain).

### 1.10 How it was built (changelog, read only)

Oldest first; the line is the release's `"version"` in `assets/data/changelog.json`, the ticket comes from the release commit.

| Version (line) | Ticket | What it added or changed |
| --- | --- | --- |
| 0.4.0 (1865) | PIX-17 | The Undermountain: floors 11-15, Bone Knight, Shade, Mimic, Fire Imp, Morvax; the Obsidian Blade; victory moved to floor 15 |
| 0.6.0 (1842) | PIX-7 | The dragon and the lich always drop |
| 0.10.0 (1798) | PIX-24 | The cave at the mountain's base, sealed until the dragon falls |
| 0.14.0 (1753) | PIX-11 | Balance: Fafnyr and Morvax harder, the Hall of Echoes softened |
| 0.61.0 (1213) | PIX-34 | The trophy shelf; the Crown of the Deathless at +2 to every stat |
| 0.81.0 (990) | PIX-31 | The opening ends on the whispers from below |
| 0.82.0 (961) | PIX-32 | Morvax's intro, the stairway scene after floor 10, the ending and credits |
| 0.83.0 (949) | PIX-141 | The XP curve aimed at about 10 at the Ashen Throne and 14 at floor 15 |
| 0.88.0 (888) | PIX-144 | The main quest in chapters, the last "The Deathless" |
| 0.89.0 (874) | PIX-145 | Village projects; the City once Morvax is cast down |
| 0.91.0 (850) | PIX-147 | Homecomings after Fafnyr and Morvax |
| 0.94.0 (814) | PIX-150 | Boss attacks (Morvax's ring and summons), the ending's town tour, Bram's imps |
| 0.96.0 (790) | PIX-153 | The Ember Seal: Liane's ten pages, Maren's graves, seal and confession |
| 0.97.0 (781) | PIX-154 | Three dreams in Morvax's voice |
| 0.100.0 (747) | PIX-157 | The throne choice, two endings, Maren's last words |
| 0.101.0 (736) | PIX-158 | The deeper wind, Morvax's theme, a theme per ending |
| 0.111.0 (621) | PIX-170 | The barred gate (the Ashen Mountain's), the mountain last, floors lifted (about 12 at the gate, 18-19 at the bottom) |
| 0.113.0 (600) | PIX-161 | The Deep Hunt |
| 0.121.0 (511) | PIX-186 | Boss health for real time; Morvax's raised dead at his level |
| 0.129.0 (435) | PIX-191 | Floor loot pools (the Obsidian Blade on the last floors); deep gear tiers |
| 0.134.0 (387) | PIX-180 | Deep gold made linear, replays pay a quarter |
| 0.136.0 (367) | PIX-188 | Floor epithets ("Sunless" … "Deathless", "Deep") |
| 0.144.0 (276) | PIX-199 | The throne screen keeps its key under a rank-up |
| 0.151.0 (210) | PIX-207 | The Lich Crown's every stat includes endurance |
| 0.152.0 (202) | PIX-208 | Switching language renames the Deep Hunt |
| 0.159.0 (128) | PIX-216 | Milestones and crystals, wardens, twists, the gate's tiers |
| 0.160.0 (117) | PIX-217 | Foes climb 1.5 levels a depth; the hoard's potion by depth |
| 0.161.0 (106) | PIX-218 | Deep gear for every slot, the deep bonus apart, Hilda's quench |
| 0.164.0 (76) | PIX-219 | The four deep named; Feats, with Ten Below and Thirty Below |

In passing: the Mirefen's mimics and fake chest (0.24.0, 0.27.0, 0.85.0, 0.119.0, 0.128.0), imp horns (0.86.0, 0.130.0, 0.139.0), and the skill tiers at 13 and 17 and the fifth rank at 20 (0.138.0, PIX-190), which only the Undermountain and the deep reach in practice.

---

## 2. What depends on it from elsewhere, and how strongly

**Hard**: breaks or locks something that stays. **Medium**: a system that stays loses its top end. **Soft**: flavour or dead content.

| # | What leans on it | How | Strength |
| -- | --- | --- | --- |
| 1 | **`Dungeons.floor_count()`** | Fifteen floors are the code's idea of "the last floor" and "where the deep begins" (1.2). Shrinking `levels` turns Fafnyr's floor into the final one and plays Morvax's throne and ending after the dragon. | **Hard**, structural |
| 2 | **The main story's finale** | Main quest chapter 4 (`stair`, `hoard`, `morvax`) and `mainQuest.done`; the throne choice; both endings and the credits; Maren's last words; the homecoming. Without a replacement the game has no end. PIX-253 rewrites it. | **Hard** |
| 3 | **Morvax's place in the story** | He is the antagonist from the opening on: the dreams, the crypt's shield, the forge's broken seal, pages I-VI, Fafnyr's dying words, Maren's confession ("Go down and end it"). Removing his lair leaves every one of those pointing at a door that isn't there. | **Hard** (narrative) |
| 4 | **The town's last age (the City)** | Age 4 requires floor 15 (`town.json:823-830`). Behind it: the City's two projects, the commissions (offered once every age is built), the City's sell premium (`economy.gd:59`), tier-4 shop stock (`everflask`, `aegis_of_the_ash`, `kings_signet` and `city_banquet` come from nowhere else, and `phoenix_draught` otherwise only from the deep's hoards or Vex's workshop once owned), two settlers (Serra, Fenn) and every villager's tier-4 lines. | **Hard** |
| 5 | **The relics' purpose** | Mechanically untouched: the relics open the Ashen Mountain's door (`Relics.gate_open`, `world.gd:500`), and the City's age 3 asks for them or floor 10. Narratively the relics are the five's, and the five's story ends on the stair below (pages VII-X, `maren_confession`). | Soft (mechanics), Medium (story) |
| 6 | **The level curve** | About 16 at Fafnyr, 18 at Morvax, foes from 19 and up in the deep. Without floors 11-15 and the deep, the strongest foes left are the top floors of the Ashen Mountain (15-16) and the Mirefen (mimics at 13, Gulp at 14), so levels past about 16 come slowly or not at all. The last two skill tiers open at 13 and 17 (`skillTierLevels`), the fifth rank at 20 (`hero_rules.gd:113-115`), and the beyond tree waits for a whole tree learned. `test_pacing` and `test_armour` model a level-18/19 hero at the bottom. | **Medium** |
| 7 | **The best gear** | `lich_crown` (floor 15 only; a +2-to-every-stat trophy); `obsidian_blade` (floor 12 and the deep; otherwise only Mirefen mimic loot, through `dropPools` floor 11); deep-forged tiers on every slot's best (`deepHunt.gearIds`) and Hilda's quench (deep pieces only); deep crystals; `phoenix_draught` (deep hoards, the City's alchemist, or owning Vex's workshop). | **Medium** |
| 8 | **Bounties** | Grandmother Gulp (Mirefen) is posted only after floor 12 (`combat.json:5539`): she and her `gulp_tooth` become unreachable. The four deep named go. | **Hard** (Gulp) |
| 9 | **Quests** | `bram_imps` (kill 2 imps) can't be finished: imps live only on floors 14-15, the deep and the prologue. `loras_horn` is fine. | **Hard** (one quest) |
| 10 | **Deeds and medals** | Ten Below and Thirty Below go. Every Bounty Paid counts the deep named and Gulp. Seen Them All counts every monster key: `boneknight` and `lich` would be unmeetable. | **Hard** (two medals), Medium |
| 11 | **Shared monsters** | `shade` (Deepwood), `mimic` (Mirefen, Gulp, the mimic chest), `imp` (the prologue's embers) and `dragon` (Fafnyr; also a deep warden) must stay. `boneknight` and `lich` live nowhere else. | Medium |
| 12 | **Maren and the villagers** | Maren's milestone words, her last words per ending, `maren_liane`'s "pages up there"; Loras's City line about Morvax's ending. | Soft |
| 13 | **Shops' stock stage** | `stock_stage = max(unlocked_level, relic step)`. The only stock above stage 10 is the alchemist's `greater_potion` at 11 (`economy.json:103`), which four relics or floor 11 reach; old saves keep it. | Soft |
| 14 | **Sound** | `deepwind` (floors > 10), the `morvax`, `ending` and `ending_rest` themes, the `victory` track (endings only). | Soft |
| 15 | **Pacing of the Mirefen** | The Mirefen is staged as the last region (stage 12, `economy.gd:228`, `dropFloor` 11), modelled as swept at floor 12 in `test_pacing`. It stays, but its place in the order was set by the Undermountain. | Soft |
| 16 | **Tests, flows, harness, docs, French** | 1.7-1.9. | Mechanical |

Not affected: the Night of Ash and its dawn (`dawn_screen.gd`, the `dawn`, `hounds` and `embers` flows), the Reach's four chapters and their relic bosses, floors 1-10, and the Ashen Mountain's barred door (the `gate` flow).

---

## 3. A removal plan

### 3.1 Rules that keep old saves whole

Saves are the web v4 format byte for byte, and the format can't change. So:

- **Never delete an id a save can hold.** Items stay in `catalog.json` (`lich_crown`, `obsidian_blade`, `deep_crystal_*`, `medal_ten_below`, `medal_thirty_below`, `phoenix_draught`…): `Catalog.item()` of an unknown id returns `{}` and some callers index it. Monsters stay in `combat.json monsters` (`progression.met`, the codex, `Bestiary.monster()`), even if nothing spawns them. Named ids (`hunted`), deed ids (`deeds`), story ids (`storySeen`: `morvax`, `ending`, `ending_rest`, `maren_peace`, `maren_after`), quest ids and once-ids (`firsts`) stay readable. Retire things from play, not from the tables.
- **Keep reading and writing every field.** `unlockedLevel` (up to 15), `clearedLevels` (may hold 11-15), `deepHunt`, `storySeen`, `hunted`, `deeds`, `met`; on gear, `deep` and `deepBonus`. `ProgressionState.deepest` stays as a field even when nothing raises it (`progression_state.gd:24-26`, `:47`, `:71-72`).
- **Keep old deep gear working.** `InventoryState.deep_name`, `deepBonus` in `HeroRules` and the deep tier in `Economy.gear_value` stay, so a "Deep-forged" or "Abyssal" piece keeps its name, stats and worth. Only new deepening stops. The pre-PIX-218 mend (`inventory_state.gd:150-155`) stays while such pieces can load.
- **A save never stands on a floor.** Below, the save keeps the hero at the gate (`world.gd:269-271`, `:918-921`), and a web save on its victory screen or floor select resumes into the world (`save_codec.gd:10-11`, `:124`). So a hero "in" the Undermountain is saved on the overworld beside the cave, at the cell they stepped back to (about (25,10)). If that cell ever becomes rock, `MapView.plan` already puts them at the overworld's spawn (`map_view.gd:152-153`). To send them home to town as the brief asks, add a small load-time rule in `GameState.apply` (not in `SaveCodec`, so codes still re-encode byte for byte): a hero whose position is within a few cells of (24,10) is moved to `Catalog.town_spawn()`. It writes an ordinary position, so the format doesn't change. The save can't tell a hero who quit below from one who was only standing by the cave, so both go home; that does no harm.
- **Levels, gear, gold and trophies are untouched by any of this.** Nothing in the removal touches `hero` or `pack`, so they are kept as they are.
- **The gate test:** `test_save_codec.gd:141` and `:160` (the late web save that beat Morvax) must pass unchanged in every PR. Add a Godot-written fixture with `deepHunt`, a deep-forged piece, `deep_crystal_10`, `medal_ten_below` and `storySeen` holding an ending, and check it loads, plays and re-saves byte for byte.

### 3.2 What old saves will see

| Hero | After the removal |
| --- | --- |
| Hasn't killed Fafnyr | Nothing changes until the new finale (PIX-253). |
| Fafnyr down, floors 11-14 partly cleared | Their cleared floors stay in the save but list nowhere. The main quest's next step is whatever PIX-253 puts after Fafnyr. Pages VII-X they found stay readable only if the journal still lists them (decide with PIX-253). |
| Morvax down, ending seen | `storySeen` holds `ending` or `ending_rest`. `MainQuest.next_step` is `{}` today; if PIX-253 adds steps, these heroes get a "Next:" again unless the new steps also accept `cleared 15` or an ending seen (the `orCleared` pattern of `town.json` ages 2 and 3). Their City (if built) stays: `settlement.town_tier` is saved. |
| Morvax down, City not yet reached | Age 4's new requirement must also accept `cleared 15`, or they lose a goal they had met. |
| In the Deep Hunt | `deepHunt` stays in the save; the journal and bounty lines go. Deep gear, crystals and medals keep working on the shelf and the hero. |

### 3.3 What can go outright

- **Code:** `throne_screen.gd`; `Dungeons.deep_def`, `deep_level`, `is_warden_depth`, `modifier_at`, `modifier`, `loot_luck`, `milestone*`, `deep_entries`, `deep_tier` (keep `is_deep` until the callers go, or replace them); `GameState.clear_deep`; `Hunts._deep_numbers` and `deep_guardian`; `world.skill_ward` (and its use in `player.gd:371`); the deep, twist, warden and named-guardian branches of `world.enter_floor`, `_floor_cleared`'s "deeper" hole, the `"deeper"` portal kind, `_play_reveals`' `deep` stop; `dungeon_screen`'s deep rows; the `deepest` lines in `journal_screen`, `bounty_screen` and `Npcs.on_map`; `Bestiary.roll_drop`'s deep branch and `goldLinearFrom`; `InventoryState.deepen` (keep `deep_affixes` if the reforge of old deep pieces stays); `Text.forget`'s `_deep`; the `deepest` deed kind; `enemy.pace` if nothing else uses it.
- **Data:** `levels` 11-15; `dungeons.undermountain`; `deepHunt`, `namedDeep`, `floorLift.goldLinearFrom/Step`; the four deep named; `bossIds` "lich", `bossPatterns.lich`, `bossAttacks.ring`/`summon` (if no lich fights anywhere); `floorPools` floor 12 (move `obsidian_blade` first, 3.4); `floorMaterials` 11 and 14; deeds `deep_10` and `deep_30` (their medals stay in the catalog and the trophy buffs); homecoming "15"; `levelCount` → 10.
- **Maps:** the portal at overworld (24,10) and the `undermountain_cave` waypoint. Turn the `cave` tile into ash (walkable) or mountain (then the 3.1 rule matters).
- **Assets:** `bed_deepwind.wav` and the `deepwind` bed (and `synth.py`'s deep wind), once `world.gd:671` stops asking for it.
- **Tests and flows:** as listed in 1.8.
- **Translations:** run `python3 godot/tools/i18n.py` after the strings go; it rewrites `messages.pot` and merges `fr.po` (CI runs `--check`).

### 3.4 What must move, and where

- **The finale (PIX-253).** Chapter 4, `mainQuest.done`, the throne choice, `ending`/`ending_rest`, the credits, `_play_ending`, `_lanterns`, the `victory` track, Maren's last words, the homecoming, `Story.ending_of`/`ending_scene`/`can_lay_to_rest`, the `descent` scene's last line and the title's tagline. `Dungeons.is_final` and the `victory` flag of `clear_floor` must point at wherever the new end is (a floor, a region boss, a story step), not at `floor_count()`. Morvax's foreshadowing (opening, dreams, crypt, forge, pages I-VI, `maren_confession`) is rewritten, re-aimed or kept, as Tom decides (question 3).
- **Dungeons with several floors (PIX-255).** Keep the machinery and drop the content: `DungeonFloor.plan`, `dungeon_screen.gd`, `Dungeons.dungeon()` and its per-dungeon floor lists, lifts, epithets, hoards, Liane's page per floor, `Gathering.floor_material`, the gate portal and the stairs back. Region dungeons can reuse them as new `dungeons` entries with their own floors. To make that possible, a floor's number must stop meaning "depth in the one mountain" (step 1 of 3.5).
- **The best gear's new home.** `obsidian_blade` (today only Mirefen mimic loot would remain), a crown-like top trophy if Tom wants one, the best pieces of `deepHunt.gearIds` and the quench sink: candidates are PIX-255's dungeon hoards, the named hunts, Fafnyr's hoard, or crafting. `phoenix_draught`, `everflask`, `aegis_of_the_ash`, `kings_signet` and `city_banquet` follow the City (next point).
- **The City.** Age 4 needs a new requirement (the new finale, Fafnyr, a project, or a PIX-255 dungeon), with `orCleared: 15` kept for heroes who already met the old one.
- **Gulp and Bram.** Gulp: `postedAfter` 10 or a `postedRelics` count. `bram_imps`: another target, or imps somewhere after the prologue.
- **Bone knights, imps and the lich.** Give `boneknight` (and the lich, if Morvax lives on) a new home, or leave them out of the Seen Them All count (a `retired` flag the bestiary deed and the codex skip).
- **The level curve.** Either PIX-255's dungeons carry heroes from 16 to 20, or the top of the curve comes down (`skillTierLevels` 17, rank 20, the beyond tree, `test_pacing`, `test_armour`).

### 3.5 A safe order of PRs

Each step leaves a playable game, and the late web save passes in each.

1. **Name the meanings of fifteen (no change in play).** Replace `floor_count()` where it means "the final floor", "where the deep begins" and "the deepest pool" with named accessors fed by data (for example a `final` floor id on the story's last floor and an explicit deep start). Make `--cleared` clamp. Tests pin today's behaviour. This makes every later step a data change rather than a surprise.
2. **Cut the ties from the rest of the game (play changes slightly).** Gulp's posting, `bram_imps`, the City's requirement (with `orCleared: 15`), the alchemist's stage-11 potion, the bestiary and bounty deeds, the `deepwind` threshold. Nothing here removes the Undermountain; it just stops other places needing it.
3. **The new finale (PIX-253).** The story ends somewhere that stays. Old finishers keep their ending (3.2). The throne and the endings move or are replaced. After this PR the Undermountain is optional content.
4. **Remove the Deep Hunt.** Code, data, deeds, named, the `deep` flow, `test_deep_hunt.gd`, most of `test_deep_gear.gd`, the deep lines in the journal, board and Maren. Old deep gear, crystals and medals keep working (3.1). It goes first because it hangs off "past the last floor".
5. **Close the Undermountain.** The portal, the waypoint, `dungeons.undermountain`, `levels` 11-15, `levelCount` 10, lore pages VII-X (or keep them findable elsewhere), the load-time move to town, the `throne` flow and harness flag, tests, `i18n.py`.
6. **Tidy.** Unused audio and sprites (`theme_morvax`, `bed_deepwind`, the Necromancer sheet if no lich remains), `README.md`, `godot/README.md`, `docs/godot-parity.md`, the project skill, a fresh `codegraph.py` run (nothing should reach `deep_*` any more).

**With the Solid Ground splits.** `docs/solid-ground-report.md` plans `world_delve.gd` (`enter_floor`, `_leave_floor`, `_floor_cleared`, `skill_ward`), `world_stage.gd` (`_play_ending`, `_lanterns`) and `state/spoils.gd` (`clear_floor`, `clear_deep`). Doing steps 4 and 5 before those splits saves moving code only to delete it.

---

## 4. Open questions for Tom

1. **How much goes?** « Le Sous-Mont » is floors 11-15 (Morvax). Does the Ashen Mountain (floors 1-10, Fafnyr, behind the relics' door) stay? This plan assumes it does.
2. **The Deep Hunt** (the endless depths below Morvax): does it go with the Undermountain, or move somewhere else as the endgame?
3. **Morvax:** keep him as the final boss somewhere else (where?), let Fafnyr be the last boss, or take Morvax out of the story? He is in the opening, the dreams, the crypt, the forge, Liane's pages and Maren's confession.
4. **The throne choice** (destroy him, or lay him to rest with Liane's last page): keep a choice like it in the new finale, or one ending?
5. **Heroes who already saw an ending:** is their story done, or does the new finale play for them too?
6. **The City** needs Morvax down today. What should open it instead?
7. **The Lich Crown** (+2 to every stat on the shelf): keep it working for heroes who have it (this plan does), and should a new top trophy be won somewhere?
8. **The best gear:** where should the obsidian blade, the deep-forged pieces and Hilda's quench live: PIX-255's dungeons, the hunts, Fafnyr's hoard, crafting? Keep the quench for old deep pieces?
9. **The level curve:** heroes reach about 16 at Fafnyr and 18 at Morvax. Should PIX-255's dungeons carry them to 20 (the last skill tier opens at 17, the fifth rank at 20), or should the top of the curve come down?
10. **Grandmother Gulp** (posted after floor 12) and **Bram's imp quest**: what posts her, and what should Bram ask for?
11. **Bone knights and the lich:** give them a new home, or take them out of the bestiary's Seen Them All count?
12. **The cave at (24,10):** fill it with rock, or leave a sealed mouth as a trace of the old way down?
