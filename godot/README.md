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
The map has a page for every map you've found, turned with A/D, each naming
its regions and its roads out; beside it every waypoint, by place, and fast
travel to those you've found (`scripts/map_screen.gd`, `scripts/atlas.gd`).

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
briefly, saves `screenshot.png` into `godot/` (or where `--shot <file>` says),
and quits. It lives in
`scripts/harness.gd`, which `world.gd` adds only when `--screenshot` is
passed. Harness runs play a fresh throwaway hero and never touch save slots
unless `--slot N` is passed. Every flag is declared once, with its argument
and what it does, in `HarnessFlags.TABLE` (`scripts/harness_flags.gd`): the
command line is parsed once against it, so a flag's argument never reads as
another flag, and `test_harness_flags` fails on a name declared twice or a
flag read or passed that the table doesn't know. `-- --help` prints it:

```sh
godot --headless --path godot -- --help               # every flag, its argument and what it does
godot --path godot -- --screenshot                    # new hero in the village
godot --path godot -- --screenshot --slot 1           # resume (and write) slot 1
godot --path godot -- --screenshot --map town         # boot into another map
godot --path godot -- --screenshot --walk l,d,d,d     # scripted steps first
godot --path godot -- --screenshot --at 40,27 --walk u,u,u  # stand on a cell, then walk: what stops you
godot --path godot -- --screenshot fight              # orc fight, mid-swing
godot --path godot -- --screenshot fight kill         # swing until it dies (its XP, gold and drops float up over it: floats=, logged=)
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
godot --path godot -- --screenshot saves --slots res://test/fixtures/slots
                                                      # every slot full (the longest lines a card shows); nothing written
godot --path godot -- --screenshot --map town portal  # walk into the nearest doorway
godot --path godot -- --screenshot die                # fall, then wake at the inn
godot --path godot -- --screenshot title options     # options over the title, before any hero
godot --path godot -- --screenshot title --wait 8      # hold the shot (the dragon crosses the moon about 8 s in)
godot --path godot -- --screenshot title still        # with Reduce motion on (no sway, drift, dragon or shine)
godot --path godot -- --screenshot title --keys enter --wait 6.5   # the opening, mid-way (Fafnyr wakes); `--keys enter,esc` skips it
godot --path godot -- --screenshot --map vault_3 clear   # a floor of the Kings' Vault, every foe on it felled (its guardian too)
godot --path godot -- --screenshot --story ending --wait 20  # any story scene over the world (vault_door, ending: the credits roll)
godot --path godot -- --screenshot title --keys s,s,s # walk the title's menu with real keys (w, s, e, enter, esc, space)
godot --path godot -- --screenshot dockmenu           # the dock's menu of screens, open
godot --path godot -- --screenshot inventory --keys i # press keys at whatever screen the run opened (here: I closes the pack)
godot --path godot -- --screenshot --map town --look browser   # the desktop renderer in another of the app's looks (below)
```

The final `print` line reports the map id, hero cell, HP, gold, the save's place, draw calls, whether the world is held still (`paused=`) and which screens are open (`open=`), for assertions, then whatever else the run has, by name: after anything was won, what floated up from where it was won (`floats=+13 XP;+14 gold`) and how many lines the battle log showed (`logged=`); a gate's line (`gate=`), the packs on a wild map (`packs=`), and so on. Every field is a row of `HarnessReport.TABLE` (`scripts/harness_report.gd`, PIX-273) with its own function, `field_<name>()`, which returns its text, or nothing when the run has none: a new field is a row in its place by name (after the head) and its function in the same place. harness.gd never writes a field itself; a value it knows only part-way through (the clock as the hero wakes) it hands over with `report.note("clock", ...)`.

### Release flows

`godot/tools/flows.sh` runs the flows a release must not break (spawn,
portal, chest, shop, craft, quest, rank-up, fight, death and the inn, saves,
reading a conversation to its end, leaving one with Esc, and walking without
the camera shake)
through the harness. Each one checks the harness's report line and leaves its
picture in `godot/flows/<name>.png` (gitignored). `godot/tools/flows.sh fight die`
runs just those.

The flows are `godot/tools/flows.txt`, one a line under a comment saying
what it walks through (PIX-273):

```
# A named boss falls as a boss does, and holds the way out while it hunts (PIX-232).
bossfell | --map icecave fight slay --foe rimefang --wait 0.3 | map=icecave fell=1 | combat dungeon
```

its name, the harness's arguments, the report fields it expects and its
tags. A field is `name=pattern`, matched by name wherever it stands on the
line: the pattern is a regular expression the field's whole value must match
(`map=town` is the town, `map=town_.*` any of its rooms), spaces allowed, and
a field the report doesn't show fails the flow. A new flow is a new line
beside its kind and nothing else: two branches adding flows no longer
conflict (`.gitattributes` merges the file by union, and a flow both
branches changed comes out twice, which `tools/flows.py` refuses).

The flows run side by side, `-j N` at a time (the machine's cores less two
by default; `-j 1` runs them one after another). Each run keeps its picture
(`--shot`), output and log in its own folder under `godot/flows/runs/`, and
the lines still come out in the flows' order, each with its time, the five
slowest at the end. `--quiet` runs them headless with nothing on the screen
(the motion flow, which needs a window, is skipped); a windowed run draws
a frame a second of the game's time and the frames of its picture
(`--draw-every 60`: stepped, the game is the same drawn or not) and walks
the motion flow alone after the rest, every frame of its walk drawn. `--shard K/N` runs every Nth flow from the Kth. `godot/tools/flows.sh --boot` boots every
map the data lists (each map file, the village's ages, the house's tiers,
every dungeon's floors, the Kings' Vault's among them), by day and at night,
headless, and fails on any script error: GUT never loads the world's scripts.

The Godot CI runs both on every pull request, after GUT, headless, with as
many flows at once as the runner has cores, and puts each result in the
job's summary. A fork's pull request gets no key to the paid art, so both
run on Shade's CC0 art alone, which they pass too.

A flow is the same run every time (PIX-276). `flows.sh` steps Godot
(`--fixed-fps 60`): each frame is a sixtieth of a second of the game's time
however long the machine takes to draw it, so a flow headless on a fast
core, beside twenty others on a loaded runner, or in a window that software
draws at a few frames a second lives the same seconds, and its timers,
`--wait` and keys with it. The game reads that time, `GameClock` (the
world's physics ticks), wherever it asks how long since (a foe's grace on
arrival, the place's card, a message, a second press to confirm), never the
machine's clock, which only measuring the machine reads (`test_game_clock`
keeps it so); and a harness run throws the same dice
(`GameState.HARNESS_SEED`: the same loot, crits and wanderings). So a report
is the same on every run, window or not (but `draws=`), and no flow gets a
second try: the motion flow and the festival's and the board's had one, and
it only hid what made the first fail. A flow can ask for another pace with
`--fps N` (the motion flow walks at 144, a fast screen's frames between the
ticks).

The `Steady flows` workflow (`.github/workflows/flakes.yml`) keeps it so:
every night on main, and on demand on any branch (`gh workflow run
flakes.yml --ref <branch> -f runners=10`), it runs every flow five times
headless with twice as many flows at once as the runner has cores, and once
in a window, and its summary (`tools/flakes.py`) names every flow that failed
even once, why and the end of its output, and every flow whose report
changed between runs (headless with the paid art, or in a window with
Shade's CC0 art alone: Godot's particles draw from the game's dice, so the
paid houses' chimney smoke changes what a kill drops between the two), and
it fails on either.

On the laptop, `godot/tools/check.sh quick` runs only what a branch's diff
against `origin/main` could break, in under a minute and with nothing on the
screen: the release and catalogue checks, the import when art or scripts
changed, GUT beside a boot of the town and of the maps the diff touches, and
the flows tagged with the areas it touches. Each flow ends on its tags in
`flows.txt` (town, rooms, travel, field, combat, dungeon, trade, story, quest,
screen, lang, save, gathering, title, rank, night), and `AREAS` in
`check.sh` says which areas each file touches; a file it doesn't know runs
every flow. `--plan` shows what it would run and why. `check.sh full` runs
everything CI runs. Neither opens the motion flows' window: `quick` says when
a change to the hero's sprite, walk, the camera or the hand-over at a line
between two maps calls for `godot/tools/flows.sh motion line-motion`.

What needs a window runs in CI too (PIX-275), beside the checks: a virtual
display (xvfb) with Mesa's software rendering (the flows on the desktop
renderer as on the Mac, Forward+ on lavapipe; the look book on the
browser's, as `lookbook.sh` shoots it), the release flows windowed in two
shares side by side (the `windowed` jobs, `flows.sh --shard`, the look book
with the second), and the `pictures` job, which puts every flow's picture on
one contact sheet (`tools/flows_sheet.py`) and passes when both shares did.
Stepped, a window drawn by software at a few frames a second lives the same
seconds as a headless run, so each windowed report must show what its flow
expects too, the motion flow's steps back among them: that is the motion
flow `check.sh quick` calls for, run on every pull request. The pictures are
the run's artifacts, and a comment on the pull request links them (the two
sheets open in the browser). They are always of Shade's CC0 art alone: the
repository is public, and so are its artifacts, so the paid art is never
fetched there.
The Mac's windowed runs (`flows.sh`, `lookbook.sh`, both muted) stay the
way to judge the paid art's looks.

The motion check walks the hero's first three quarters of a second at the
run's pace (`--fps 144`: two or three frames between the physics ticks,
where the camera rides the hero as the interpolation draws them), keeps the
sky clear while it walks (a cloud's shadow over the shirt changes the reds
it finds the hero by), counts frames only while the hero walks (where the
river stops the walk, the camera catching up would read as a step back),
and looks closely only at pure reds (turning every pixel into its hex took
most of a slow frame).

### Loading

While the game loads there is nothing but the title's night sky colour
(`#080c28`, `boot_splash/bg_color` with no picture) and, on the web, a quiet
thin bar in the middle of the page (`html/head_include` in
`export_presets.cfg`); the tab and the window are titled just "Pixelheim".
No words, so nothing shows in English before the title (PIX-295: the old
title's picture, with its English tagline, outlived the title). The title
then rises out of that colour.

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
godot/tools/lookbook.sh --only strike                # one shot, by its name
python3 godot/tools/lookbook_compare.py godot/lookbook-desktop/browser godot/lookbook-desktop/app godot/lookbook-compare
```

A shot is a key of `SHOTS` in `scripts/lookbook.gd`: its name (the picture's
file, never a number: every branch adding a shot took the same next one,
PIX-273) and its `area`, one of `AREAS`, which orders the sheet (the village,
its rooms, the Reach, the regions, the ways between, underground, a fight,
the game's pages). Each folder gets `shots.txt`, the sheet's order, which
`lookbook_compare.py` follows.

## Releasing

Every change a player can see ships as a release (PIX-274): an entry at the
top of `assets/data/changelog.json` (its version is the game's, its notes
What's new), the root README's "Currently vX.Y" line, the catalogue
regenerated and the French filled in `locale/fr.po`. `tools/release.py` makes
the four edits together from a spec, a JSON file kept outside the repo:

```json
{
  "version": "0.204.0",
  "codename": ["Open Country", "Rase campagne"],
  "notes": [["The roads run out through the ridge", "Les routes sortent par la crête"]],
  "extra": {"A string the change added": "Sa traduction"}
}
```

```sh
python3 godot/tools/release.py ~/release.json   # cut the release, print what changed
python3 godot/tools/release.py --linear         # its section for Linear's Changelog
python3 godot/tools/release.py --check          # what CI checks
python3 -m unittest discover -s godot/tools -p 'test_*.py'   # the script's tests
```

- The version is the next patch, minor or major after the newest entry
  (0.203.1, 0.204.0 or 1.0.0 after 0.203.0), never a repeat or a jump.
- Type the French plainly: it's written with straight apostrophes and a
  narrow no-break space (U+202F) before `: ; ! ?` and inside « », except in
  clocks, links and placeholders. Address the player as « vous », and keep
  them gender-neutral: no être + past participle agreeing with « vous ».
- Every string the change added needs its French in `extra`: the script
  refuses to leave a string untranslated in fr.po. A refused release changes
  nothing.
- Its paths are its own checkout's: run it from the worktree being released.
- A string added between releases: `python3 godot/tools/i18n.py` puts it in
  `locale/messages.pot` and `fr.po`. Their `#:` references name the file a
  string is in, never its line (PIX-273), and entries sort by file, then
  text, so editing a script changes the catalogue only when one of its
  strings changes; `i18n.py --check` refuses a reference with a line.

The Godot CI runs `release.py --check` on every pull request: the README's
version is the newest release's, every codename and note has its French in
fr.po, and no msgstr has a plain or no-break space where U+202F belongs.

## Layout

- `scenes/main.tscn` — entry scene; all other nodes are built in code
- `scripts/world_tiles.gd` — what each tile lets the hero do (walkability) and its colour on the map
- `scripts/map_data.gd` — loads the JSON maps in `assets/maps/` (pure data, unit-tested)
- `scripts/world.gd` — the play: entering maps, the hero, villagers and monsters, the HUD, interaction, combat, music
- `scripts/map_view.gd` — one visit to a map as drawn (PIX-136): Shade's ground, houses, rooms and dungeons, props, field scatter, chests, door signs, the house's furniture and the invisible blockers; `plan` marks what all that covers on the map before anything is drawn, `build` draws it behind the world's y-sorted actors
- `scripts/world_neighbours.gd` + `scripts/seam.gd` + `scripts/slicer.gd` — one land (PIX-269): near a road out of a map under the Reach's sky, the map past it drawn beside it where `assets/data/plane.json` puts it, a few units a frame within 3 ms (`Slicer`), stitched along the line (`Seam`), let go again further off; walking over the line hands the hero over to it with no fade (`world.hand_over`); every map of the Reach worked out ahead early in a session (`KeptGround`)
- `scripts/harness.gd` — the screenshot harness below, added only for `--screenshot` runs
- `scripts/state/` — the `GameState` autoload and its typed sections (hero, pack, settlement, progression, world), the save codec, slots and settings
- `scripts/player.gd` / `scripts/enemy.gd` — live combat actors
- `scripts/npcs.gd` / `scripts/npc.gd` / `scripts/dialogue_box.gd` — villagers: who lives where (ported from `src/world/npcs.ts`), their pacing, and conversations
- `scripts/state/economy.gd` + `scripts/shop_screen.gd` — shops, forge and crafting rules (ported from `src/game/economy`) and the keeper's counter
- `scripts/state/town.gd` + `scripts/{town_hall,bank}_screen.gd` (on `ledger_screen.gd`) — town tiers, deeds, the bank, recruits, the inn
- `scripts/state/quests.gd` + `scripts/journal_screen.gd` — the villagers' quests (ported from `src/game/quests.ts`): a giver's first word accepts, kills tick bounties, deliveries leave the pack on turn-in (`GameState.questing.resolve_quests`); Q opens the journal
- `scripts/state/ranks.gd` + `scripts/rankup_screen.gd` — rank titles every five levels (ported from `src/game/hero/ranks.ts`; the hero looks the same at every rank), the Path Graph's choices (`hero/paths.ts`, `GameState.training.choose_path`), and the ascension scene that plays when a rank is crossed, holding at a fork for the path cards
- `scripts/state/skills.gd` + `scripts/stats_screen.gd` + `scripts/skills_screen.gd` — the stat sheet (ported from `hero/statInfo.ts`, `applyStatPoint`) on C and the skill tree with the Path Graph (`hero/skillTree.ts`, `SkillTree.tsx`) on K; points are spent through `GameState.training.spend_stat_point` / `buy_skill_node`
- `scripts/title_screen.gd` + `scripts/title_scene.gd` + `scripts/create_screen.gd` — the title (PIX-139: Pixelheim's street at night under the smoking Ashen Mountain, built from Shade's art at 2x, with lit windows, torches, the watchman's round, the hero in the street and the dragon crossing the moon; the gold logo; Continue / New Game / Saves / Options / What's new) and hero creation (`CharacterCreation.tsx`: role, look among Shade's colourways, name). A plain launch with no hero keeps an unsaved stand-in behind the title (`GameState.standing_in`) until one is made
- `scripts/cutscene.gd` + `assets/data/story.json` — story moments (PIX-31): a scene is data, ordered steps (stage, fade, caption, tint, ash, shake, actor, eyes, logo, wait) the Cutscene screen plays over a letterboxed stage; E moves on, Esc skips to what comes next, Reduce motion keeps the words and drops the movement. The opening plays on New Game, before hero creation; `moments` in story.json map play to scenes (a boss's floor, the first clear of floor 10, victory), each played once per hero (`storySeen` in the save, written only once there is one)
- `scripts/screen.gd` — what every menu, page and conversation shares (PIX-136): built in `_open`, `dim()` behind, keys through `_command` (handled before they run), Esc / the menu key / its own key close it, and it holds the world still, counted, so the world runs again only when the last screen closes
- `scripts/pause_screen.gd` + `scripts/options_screen.gd` + `scripts/controls.gd` — Esc's pause menu (Resume, Saves, Options, Quit to title) and the options (volumes, CRT scanlines, fullscreen, reduced motion, key rebinding); `Controls` rebuilds the InputMap from `GameSettings.bindings` (one rebindable primary per action plus fixed alternates and the pad)
- `scripts/inventory_screen.gd` — the pack and paperdoll on I (ported from `Inventory.tsx`): nine slots around the hero and the numbers gear makes, everything carried by category; equip, take off, drink, place furniture, drop (`GameState.upkeep.equip` / `unequip` / `use_item` / `drop_item` / `drop_gear`). item icons are Shade's (`scripts/item_icons.gd`, `assets/puny/icons.json`), and a Craft tab guides crafting
- `scripts/codex_screen.gd` — the codex on B (ported from `Codex.tsx`): family masteries with their Slayer tiers, and the bestiary of every monster whose family the hero has met
- `scripts/state/depths.gd` + `scripts/dungeon_floor.gd` + `scripts/state/vault.gd` — every dungeon as a list of floors (`assets/data/depths.json`), handcrafted or laid from a seed (a pack a room, the last and largest for the last), their stairs both ways, the boss's shortcut out; the Kings' Vault after the story, behind a door that opens once the dragon is freed (the old mountain's fifteen numbered floors and the Deep Hunt left play with PIX-257)
- `scripts/puny_sheet.gd` / `scripts/puny_dungeon.gd` — one Shade tileset with its `.tsx` (animations, wang corners, a lazily built TileSet), and Puny Dungeon's wall grammar, stone, torches, barrels and stairs
- `scripts/home_screen.gd` — the house's barrel, workbench, trophy shelf, nook and furniture placement (house rules live in `state/town.gd`)
- `scripts/ui_style.gd` — the one look (PIX-138): parchment pages in carved wooden frames, ink on the page and cream on the dark, pixel fonts at whole scales, Press Start 2P headings
- `scripts/hud_dock.gd` — the hero's dock centred along the bottom: experience along its top, portrait, rank, health and energy, the six skill slots by their number keys (a click casts too), gold and a menu of every screen with its key and waiting points
- `scripts/sound.gd` (autoload `Sound`) + `assets/audio/` — 17 stingers, a seamless loop per theme and ambient one-shots with variants (`assets/data/audio.json`), rendered once from the old web game's synth, plus the pages' UI sounds synthesized at start. Music crossfades per place, battle/boss while something hunts the hero; Music/SFX/Ambience buses follow the options
- `assets/fonts/` — Pixeloid (OFL) for all text, Press Start 2P (OFL) for the logo (`FONTS.txt`)
- `assets/puny/` — art by Shade, CC0 (`LICENSE.txt`): characters (hero, villagers, bestiary) from [Puny Characters + PunyMonsters](https://merchant-shade.itch.io/16x16-puny-characters) and [Mini World Sprites](https://merchant-shade.itch.io/16x16-mini-world-sprites), the overworld from [Puny World](https://merchant-shade.itch.io/16x16-puny-world) and stone from [Puny Dungeon](https://merchant-shade.itch.io/16x16-puny-dungeon). `scripts/puny_art.gd` assigns who wears which sheet; `scripts/puny_terrain.gd` lays Puny World over the maps (wang corners on the dual grid, read from Shade's Tiled `.tsx`), raises ramparts and bridges, `scripts/skyline.gd` draws the village small in its block on the overworld, as the town stands (PIX-248), `scripts/rampart.gd` raises Pixelheim's own rampart, one wall in the Medieval Age's stone with its gatehouse where the road runs through (three wide between two towers, scorched until the Hamlet is built; Shade's CC0 castle pieces without the paid pack), in town and on the village far off alike, and `shaders/region_tint.gdshader` tones ash and mire
- `assets/maps/*.json` — all world maps (grid one row per line, spawn, portals), and `interactables.json` (chests, signs, waypoints); edit them directly
- `assets/data/catalog.json` — items, roles and skill data
- `assets/data/npcs.json` — villagers and recruits with their lines
- `assets/data/changelog.json` — every release, newest first: What's new, and the game's version
- `assets/data/economy.json` — shops and their stock per unlocked floor, recipes, stations, rarities
- `assets/data/town.json` — town tiers, deeds, rest and bank tuning; `assets/maps/town@N.json` / `town_house@N.json` are the tier redraws
