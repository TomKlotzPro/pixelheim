# Pixelheim — Godot

Pixelheim in Godot 4.7 ([Godot Migration](https://linear.app/pixelheim/project/godot-migration-4ba6c77b3226) project). Its maps and data tables live here (`assets/maps/`, `assets/data/`) and are edited directly; see [Data](#data).

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
the game runs on Shade's free art alone: the town's houses, props and paid
icons are missing, and collision is the same.

Combat runs on the game's numbers since its first edition: the hero's real HP
and stats, each species' stats per region, elites, ailments (a turn of the
first edition = 1 s), drops, xp and level-ups; defeat wakes you at the inn.
Monsters stand in packs at their spawn points and stay cleared until you leave
the map.

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

Slot files (`user://saves/slot_<n>.save`; IndexedDB on the web export) are
Pixelheim's own save format, v5 (`save_codec.gd`): the format's version and
the game's, when it was saved and the time played, a card the Saves screen
reads alone (name, class, look, level, place, chapter, time played), then a
section for each part of the game (hero, pack, home, town, story, quests,
world, the Post, buffs), the fog of war a bitmap per map. A fully explored
hero's save is 9 KB (298 KB in the first edition's format). Until the beta
there is no backward compatibility: nothing reads what only an old save
held (the old mountain's floors, the Deep Hunt, the old throne's endings),
and a change old saves can't take bumps the version with no migration: a
slot holding a save from before v5 (the first edition's `slot_<n>.json`)
shows as an older version's, never free and never written. Device settings
live apart in `user://settings.cfg`.

No hero is lost to a file (`save_slots.gd`): a save is written to a temp
file, read back and decoded, then the slot's file becomes `slot_<n>.save.bak`
(the save before) and the temp file takes its place. When a slot's file
can't be read, the game plays the save before and says so (a line on the
card, a word on the title or the plate). A file it can't read at all, or one
a newer version wrote, is never an empty slot: it gets its own card, New
Game, Duplicate and Paste pass it by, nothing is written over it, and
clearing it asks twice.

The Saves screen (`scripts/saves_screen.gd`, its cards' lines in
`scripts/state/slot_card.gd`) is one column of the three slots: each hero's
card shows them as they left, dressed, with their class and level, where
they are and the chapter, how long they've played and when they were last
saved. On the chosen slot `E` continues the hero, `D` copies them into the
first empty slot, `X` asks with their name, level and hours and a second
`X` deletes them (their file waits beside the empty slot,
`slot_<n>.save.deleted`, and `R` brings them back until another hero takes
the slot), `C` copies their save code (`PXH2.`: the save deflated behind a
checksum, so a code cut short or changed is caught) and `V` pastes one from
the clipboard (raw save JSON works too; an older version's says so), asking
first before it replaces a hero. A new hero starts from the title's New
Game alone, in the first free slot, and with none free New Game says so
rather than writing over anyone.

## Data

Maps (`assets/maps/<id>.json`, one row of tiles per line) and the data
tables (`assets/data/*.json`: items, monsters and their packs, quests,
villagers, the town, the economy, audio, the story, the dungeons' floors, the
changelog) are the source: edit them directly, keeping their shape. A region
map can be drawn as a sketch in `maps-src/` and written by `tools/mapgen.py`.
Nothing regenerates them, so the unit tests keep them whole:

- `test_map_files.gd` reads every file in `assets/maps/`: a rectangle of
  known tiles (`WorldTiles.TILE_INFO`), its id its file's name, its spawn on
  open ground, its regions the map's size and known to `combat.json`; every
  way between maps (the planned dungeon floors' too) leads to a map that
  exists and lands on open ground; every pack stands on open ground in an
  encounter region, off the ways out.
- `test_interactables.gd`: every chest has its own id and known loot, stands
  on open ground off any way out and clear of the packs; a mimic stands in
  an encounter region.
- `test_ways.gd`, `test_reach_plane.gd`, `test_waypoints.gd`, `test_depths.gd`,
  `test_item_icons.gd` and the regions' own tests hold the rest: a road up to
  every way, the Reach's seams, the waypoints, the floors, an icon for every
  item.

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
godot --path godot -- --screenshot shop --map town_smith --tab 2   # a keeper's counter (500g, a pack to sell), tab by index
godot --path godot -- --screenshot station --map town_alchemist   # E at the room's first cauldron or forge (report: tab=Craft)
godot --path godot -- --screenshot hall --map town_hall   # the town ledger (20000g); `bank` for Mirelle's
godot --path godot -- --screenshot --map town --town-tier 4  # preview the village at another age
godot --path godot -- --screenshot home --map town_house --house-tier 3 --mode nook  # a house fixture (storage|workbench|trophies|nook|furniture)
godot --path godot -- --screenshot lineup             # every hero role, villager and monster sheet, walking down and right
godot --path godot -- --screenshot saves              # the saves screen
godot --path godot -- --screenshot saves --slots res://test/fixtures/slots
                                                      # every slot full (the longest lines a card shows); nothing written
godot --path godot -- --screenshot --map town portal  # walk into the nearest doorway
godot --path godot -- --screenshot die                # fall, then wake at the inn
godot --path godot -- --screenshot title options     # options over the title, before any hero
godot --path godot -- --screenshot title --wait 8      # hold the shot (the dragon crosses the moon about 8 s in)
godot --path godot -- --screenshot title still        # with Reduce motion on (no sway, drift, dragon or shine)
godot --path godot -- --screenshot title --keys enter --wait 6.5   # the opening, mid-way (Fafnyr wakes); `--keys enter,esc` skips it
godot --path godot -- --screenshot --map vault_3 clear   # a floor of the Kings' Vault, every foe on it felled (its guardian too)
godot --path godot -- --screenshot --story ending_home --wait 20  # any story scene over the world (vault_door, ending_home: the credits roll)
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
screen: the release, catalogue and layout checks, the import when art or scripts
changed, GUT beside a boot of the town and of the maps the diff touches, and
the flows tagged with the areas it touches. Each flow ends on its tags in
`flows.txt` (town, rooms, travel, field, combat, dungeon, trade, story, quest,
screen, lang, save, gathering, title, rank, night). A script says which areas
it touches on an `## areas:` line under its `class_name`/`extends`, and
`tools/areas.txt` says it for every other file (PIX-353); a file neither
names runs every flow. `--plan` shows what it would run and why. `check.sh full` runs
everything CI runs. Neither opens the motion flows' window: `quick` says when
a change to the hero's sprite, walk, the camera or the hand-over at a line
between two maps calls for `godot/tools/flows.sh motion line-motion`.

What needs a window runs in CI too (PIX-275), beside the checks: a virtual
display (xvfb) with Mesa's software rendering (the flows on the desktop
renderer as on the Mac, Forward+ on lavapipe; the look book on the
browser's, as `lookbook.sh` shoots it), the release flows windowed in four
shares side by side (the `windowed` jobs, `flows.sh --shard`, PIX-350) and
the look book on a fifth, and the `pictures` job, which puts every flow's
picture on one contact sheet (`tools/flows_sheet.py`) and passes when every
share did.
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

While the game loads it shows the title's night (PIX-296): `assets/splash.png`,
drawn pixel by pixel by `tools/splash.py` (no pack art, so it lives in the
repo): the dithered sky, the moon, the Ashen Mountain smoking, the pine
hills, the lake, the village asleep with its windows lit, and PIXELHEIM
exactly where the title draws it. It is the desktop app's boot splash
(`boot_splash/image`, unsmoothed, in black bars on a window of another shape
like the game's canvas) and the web page's picture: the web export uses the
game's own shell, `web/shell.html`, where the picture shows from the first
instant and comes alive while the build downloads (stars twinkling, embers
off the summit, smoke from the chimneys) as the village's windows light one
by one, left to right, with the dock's pixel bar where the title's menu will
rise; reduced motion keeps only the progress. No words but the logo, so
nothing shows in English before the title (PIX-295), and the tab and the
window are titled just "Pixelheim". The game tells the page when its first
screen is up (`window.pixelheimShown`, from `world.gd`), and a launch's
title rises out of the same picture, laid under the name so the name holds
still; titles after it (back from the saves) rise out of the night's colour.
`python3 godot/tools/splash.py` redraws the picture and writes its live
points (the twinkling stars, the windows, the chimneys) into the shell;
`--check` says when either is stale.

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
headers needed, so any static host works — GitHub Pages included (~17.3 MB
gzipped over the wire: the engine's wasm 10.3 MB, the game's pack 7 MB).
Every preset's `exclude_filter` leaves `test/` and `addons/gut` out of the
game (PIX-351, `tools/test_export.py`). The deploy puts it at the root of
the Pages site, and nothing else: the web edition's old `/classic/`,
`/godot/` and pull request preview pages are gone (PIX-301).

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
`user://saves/slot_<n>.save` under the pinned user dir
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
godot/tools/lookbook.sh --only strike                # one shot, by its name (or a few: bosses,boss_lair)
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
- `assets/fonts/` — Pixeloid (OFL) for all text, Press Start 2P (OFL) for the logo (`FONTS.txt`)
- `assets/puny/` — art by Shade, CC0 (`LICENSE.txt`): characters (hero, villagers, bestiary) from [Puny Characters + PunyMonsters](https://merchant-shade.itch.io/16x16-puny-characters) and [Mini World Sprites](https://merchant-shade.itch.io/16x16-mini-world-sprites), the overworld from [Puny World](https://merchant-shade.itch.io/16x16-puny-world) and stone from [Puny Dungeon](https://merchant-shade.itch.io/16x16-puny-dungeon). `scripts/puny_art.gd` assigns who wears which sheet; `scripts/puny_terrain.gd` lays Puny World over the maps (wang corners on the dual grid, read from Shade's Tiled `.tsx`), raises ramparts and bridges, `scripts/skyline.gd` draws the village small in its block on the overworld, as the town stands (PIX-248), `scripts/rampart.gd` raises Pixelheim's own rampart, one wall in the Medieval Age's stone with its gatehouse where the road runs through (three wide between two towers, scorched until the Hamlet is built; Shade's CC0 castle pieces without the paid pack), in town and on the village far off alike, and `shaders/region_tint.gdshader` tones ash and mire
- `assets/maps/*.json` — all world maps (grid one row per line, spawn, portals), and `interactables.json` (chests, signs, waypoints); edit them directly
- `assets/data/catalog.json` — items, roles and skill data
- `assets/data/npcs.json` — villagers and recruits with their lines
- `assets/data/changelog.json` — every release, newest first: What's new, and the game's version
- `assets/data/economy.json` — shops and their stock per unlocked floor, recipes, stations, rarities
- `assets/data/town.json` — town tiers, deeds, rest and bank tuning; `assets/maps/town@N.json` / `town_house@N.json` are the tier redraws

Every script, with the first sentence of its own `##` doc comment. The list
is written by `tools/layout.py` from the scripts themselves: change a
script's doc there, then run `python3 godot/tools/layout.py`; CI and
`check.sh` fail on a stale list (`layout.py --check`).

<!-- layout.py: from here -->
- `scripts/ash_art.gd` — What burnt land and a mine stand in that Shade's sheets don't draw (PIX-308)
- `scripts/ash_land.gd` — The Ash and Blackiron as burnt land (PIX-308, the audit's "flat and empty": the whole north of the Reach, all of Blackiron and the mountain road's flats were Shade's dirt toned one grey-brown, their outcrops green grass mesas with green pines, and Blackiron a mining country with no mining in it).
- `scripts/atlas.gd` — The map screen's pages (PIX-266: "the map grew a lot").
- `scripts/atmosphere.gd` — Each region's air and the weather, frame by frame (PIX-224)
- `scripts/bank_screen.gd` — Mirelle's bank (Bank.tsx), open once she has settled in town
- `scripts/boss_bar.gd` — The boss bar (PIX-210): across the top of the screen while a boss - or a named monster - hunts the hero.
- `scripts/boss_brain.gd` — A boss that fights back (PIX-150): between bites, Fafnyr casts his own attacks, each told first by a red mark on the ground so a hero who reads it can step out
- `scripts/bounty_screen.gd` — The bounty board on the square (PIX-156): the named monsters posted so far, the wanted first, then the slain.
- `scripts/changelog_screen.gd` — What's new (the web's Changelog page): every release, newest first, its version, codename and date over its notes, in one scrolling window.
- `scripts/chapter_screen.gd` — A chapter card (PIX-253 step 2, v2 §5: "Main quests stand out")
- `scripts/codex_screen.gd` — The codex (Codex.tsx): the trophy case.
- `scripts/controls.gd` — The keys (src/app/settings.ts bindings, grown for real-time play)
- `scripts/create_screen.gd` — Hero creation (CharacterCreation.tsx): seven roles with their pitch, the chosen one walking in their colours, the stats against the whole roster, the skills they start toward, a name, and how the game opens
- `scripts/cutscene.gd` — A story moment (PIX-31): a scene from assets/data/story.json played as ordered steps over a letterboxed stage, so writing one is editing data.
- `scripts/dawn_screen.gd` — The dawn after the Night of Ash (PIX-197), played on the town itself rather than told over it.
- `scripts/day_night.gd` — The day/night wheel, ported verbatim from src/render/dayNight.ts: one deterministic clock turned by steps walked, interpolating sky-tint stops.
- `scripts/desktop_look.gd` — The desktop app's extras (PIX-227).
- `scripts/dialogue_box.gd` — A conversation: the speaker in a portrait slot and a gold name tab on the window's edge, one line at a time in the body type, and the keys that move it on (ADVANCE_DIALOGUE).
- `scripts/discovery.gd` — Fog-of-war bookkeeping, ported from src/world/discover.ts: the hero sees SIGHT_RADIUS tiles around themselves (Chebyshev), and what was seen stays seen.
- `scripts/dissolve.gd` — A door's dissolve (One Reach, PIX-269; Tom: "crossing is a cut").
- `scripts/dungeon_art.gd` — The small things a dungeon is dressed in that Shade's sheets don't draw (PIX-310)
- `scripts/dungeon_floor.gd` — A dungeon floor laid out from a seed (PIX-126, PIX-255)
- `scripts/dungeon_look.gd` — Each dungeon dressed as its place (PIX-310, the audit's "five dungeons, one brick look": the sea cave, the shafts, the cellars, the ice cave and the Kings' Vault were the same cut-brick halls in a different tint, on one floor tile).
- `scripts/elite_brain.gd` — An elite's one trick (PIX-155), by its family, told before it lands
- `scripts/enemy.gd` — A monster in the field: wanders near its home, notices a hero it can see (a "!" and a hop first), chases, bites after a tell, and gives up a chase that strays too far, walking home to heal (PIX-142).
- `scripts/entrance_art.gd` — What a dungeon's way in looks like (PIX-290, Tom: « Pas super beau les entrées de donjon, porte du Fernoir et le premier »).
- `scripts/escort.gd` — An escort (PIX-192): Gunnar's last wagon down the Frostgate - an old mammoth hauling the pass's last crates.
- `scripts/fire_art.gd` — The fires of a burning house (PIX-327): the Night of Ash's ruins and the Night of Bells' roofs.
- `scripts/firebolt.gd` — A fireborn elite's firebolt (PIX-155): flies straight, burns the hero it meets, and gutters out against a wall or after eight tiles.
- `scripts/gait.gd` — How the cast walks (PIX-243): the hero, the villagers, the monsters and the wagon all step through their sheet's walk (PunyArt.WALKS) by the ground they cover, not by the clock, so their feet keep pace with the ground at any speed
- `scripts/game_clock.gd` — The game's own clock (PIX-276): the time the world has lived, counted in its physics ticks, sixty a second.
- `scripts/gate_art.gd` — What a shut gate looks like (PIX-254, Gates), in art already in the game
- `scripts/ground_detail.gd` — The small things in the grass (PIX-305): tufts, clover, flowers, pebbles, twigs, and the mire's reeds and sedge, which Scatter.detail picks a cell at a time.
- `scripts/hamlet.gd` — Each settlement beyond Pixelheim its own (PIX-313, the audit's « bare and all alike »: Saltmere's long thatch slabs on an empty lawn, the same slate cottage at Greyhold, the Frostgate, Blackiron and the mountain, no fence, garden, net or boat, no smoke by day, and barrels as tall as the villagers beside them), and Morvax's smithy at the top of the mountain road (PIX-312: the stock cottage, no chimney, no fire).
- `scripts/hamlet_art.gd` — What the settlements beyond Pixelheim are dressed in that Shade's sheets don't draw (PIX-313), and the story's last set pieces (PIX-312)
- `scripts/harness.gd` — The agent verification harness, loaded only for `--screenshot` runs (world.gd adds it; it never ships in play)
- `scripts/harness_flags.gd` — The screenshot harness's flags (PIX-262), every one in a single table: its name, what it takes and what it does.
- `scripts/harness_report.gd` — The screenshot harness's report line (PIX-273)
- `scripts/home_screen.gd` — The house's fixtures, one screen per `mode` (HouseStorage, Trophies, Nook and the pack's Craft/Place in the web game)
- `scripts/hub_art.gd` — What the hubs grow as their post roads fill (PIX-324, Hubs)
- `scripts/hud_dock.gd` — The hero's dock along the bottom of the screen (PIX-138): one wooden plate in the windows' carved frame, centred, so the rest of the screen is world.
- `scripts/ink.gd` — Where the pixels are (PIX-268): the ink a word draws in a pixel font and the head a figure's frame draws, measured on the pixels themselves, so a mark over a head is centred on the one by the other.
- `scripts/interactables.gd` — Treasure chests, door signs and waypoints (assets/maps/interactables.json, edited by hand).
- `scripts/inventory_screen.gd` — The pack and the paperdoll (Inventory.tsx)
- `scripts/item_icons.gd` — Every item's icon and the ailment marks, all Shade's (PIX-138), as mapped in assets/puny/icons.json
- `scripts/journal_screen.gd` — The journal (Journal.tsx; PIX-171, redone for PIX-239 after Tom's playtest: « le journal c'est pas clair »).
- `scripts/juice.gd` — How a fight feels (PIX-226): a pure-white flash when a blow lands, a death that dissolves pixel by pixel into embers, a squash and stretch on the hero, and a slash's arc trailing every swing in the weapon's colour.
- `scripts/kept_ground.gd` — A map's ground as its first visit this session worked it out (One Reach, PIX-269, step 4)
- `scripts/keycap.gd` — A key the player can press, drawn as one (PIX-193)
- `scripts/lamp_art.gd` — Lamps and lit windows (PIX-311).
- `scripts/layout.gd` — Where a screen's pieces may go (Solid Ground, PIX-229/230): inside the canvas the player sees.
- `scripts/ledger_screen.gd` — Shared frame for the town's ledgers (town hall, bank)
- `scripts/light_rig.gd` — The world's light, frame by frame (PIX-221)
- `scripts/lights.gd` — Light and darkness (PIX-221).
- `scripts/lookbook.gd` — The look book (PIX-220): the same scenes, staged the same way every time
- `scripts/map_data.gd` — A world map loaded from its JSON (assets/maps/<id>.json, edited by hand or drawn as a sketch in maps-src and run through tools/mapgen.py)
- `scripts/map_screen.gd` — The map screen (M/Tab): a map in a window, painted with the tiles' map colours where the hero has been and night where they haven't (mapColors.ts port), the hero, the waypoints and the lairs the bounty board has posted (PIX-156) marked
- `scripts/map_view.gd` — One visit to a map, as drawn (PIX-136): Shade's ground, houses, rooms and dungeons, the props, field scatter, chests and door signs, the house's placed furniture, and the invisible boxes on what the hero can't walk into.
- `scripts/marks.gd` — The marks over the world (PIX-284, PIX-289), one family in the UI's palette
- `scripts/motes.gd` — The small life of the world (PIX-225): fireflies at dusk and night over the grass and in the woods, leaves falling in the forests, dust floating in a room's light, embers off forges, hearths and camp fires, dust and splashes under the hero's feet, sparks where steel meets armour.
- `scripts/npc.gd` — A villager: their Puny sheet (PunyArt, PIX-130), a body the hero bumps into, and — for wanderers — an amble around the pacing loop, walking the way they step.
- `scripts/npcs.gd` — Villagers (assets/data/npcs.json): the fixed townsfolk, tier-gated settlers included, and the recruits who wait in the wilds until they move to town.
- `scripts/open_ground.gd` — The Medieval Age's greens and snow laid as patches over Shade's grass (PIX-305), so a meadow's hollows and the snow's drifts have edges of their own, tufted the way the pack's sample maps lay them
- `scripts/options_screen.gd` — Options (Options.tsx): sound, the CRT scanlines, fullscreen, reduced motion, and the keys.
- `scripts/pause_screen.gd` — The Escape menu (PauseMenu.tsx): resume, the saves (slots and codes), options, or back to the title.
- `scripts/perf_probe.gd` — The perf guard (PIX-220): how long each stage of a frame takes, from the engine's own signals
- `scripts/place_title.gd` — The card that names where the hero has come to (PIX-269, after Tom's "I still don't like the door between maps").
- `scripts/player.gd` — The action hero, drawn from Shade's Puny sheet for the hero's role (PunyArt, PIX-130)
- `scripts/postmark.gd` — The courier's book's postmarks (PIX-321)
- `scripts/puny_art.gd` — Who wears which of Shade's CC0 sheets (assets/puny, PIX-130), and how each sheet family is laid out.
- `scripts/puny_dungeon.gd` — Shade's Puny Dungeon (assets/puny/dungeon, CC0, PIX-130)
- `scripts/puny_interior.gd` — The rooms behind the town's doors in Shade's Puny World Medieval Age (PIX-133), the way his sample cottages and smithy are furnished
- `scripts/puny_props.gd` — What stands on the outdoor ground, in Shade's Puny World Medieval Age (PIX-137)
- `scripts/puny_sheet.gd` — One of Shade's 16px tilesets with its Tiled tileset (.tsx)
- `scripts/puny_terrain.gd` — Shade's Puny World overworld (assets/puny/world, CC0, PIX-130) drawn over the web game's maps.
- `scripts/puny_town.gd` — The town's buildings from Shade's Puny World Medieval Age (PIX-133)
- `scripts/rampart.gd` — Pixelheim's rampart and its gate (PIX-248, Tom: "double rempart ça fait bizarre à l'intérieur du village et l'entrée est pas claire ni la sortie").
- `scripts/rankup_screen.gd` — The ascension (RankUpOverlay.tsx, useRankUp; PIX-244 made it a moment).
- `scripts/reach_plane.gd` — The Reach as one plane (One Reach, PIX-269, step 3).
- `scripts/rebuild_rise.gd` — A building rising on the town's tour (PIX-264).
- `scripts/reveal_screen.gd` — The town risen (PIX-147): after a project is funded, the camera walks the town to what was built
- `scripts/ring_toss_screen.gd` — The festival's ring toss (PIX-159): a ring slides along the rail, back and forth, quicker each throw; E throws it, and it lands if it's over the peg.
- `scripts/road_wear.gd` — The wear of wheels and feet on the dirt roads (PIX-307).
- `scripts/room_art.gd` — A keeper's room its own (PIX-315): Liane keeps the stars in her observatory, and nothing in Shade's packs is a telescope, a star chart or a globe of the sky.
- `scripts/route_art.gd` — What the Post's routes put up beside the road (PIX-322)
- `scripts/saves_screen.gd` — The saves screen (Esc, and Saves on the title): the heroes you have, in three slots, one column that gets the whole window (PIX-302).
- `scripts/scatter.gd` — Puny World objects scattered on terrain (PIX-130), and which of them stand in the way (PIX-137).
- `scripts/screen.gd` — What every screen shares (PIX-136): the menus, pages and conversations that open over the world.
- `scripts/seam.gd` — The lines between the Reach's maps (One Reach, PIX-269, steps 5 and 6).
- `scripts/shop_screen.gd` — A keeper's counter (talk to anyone in a shop): Buy, Sell, the Forge at the smithy, and Craft at the forge and the cauldron.
- `scripts/shop_sign.gd` — The town's shop signs (PIX-134): a wooden board with a carved rim hanging by two chains from an iron bar over each door, painted with its trade in Shade's own icons (cheese for the general store, a tankard for the inn, the anvil, the brewing pot, the hall's ledger, a key for the house).
- `scripts/skills_screen.gd` — The skill tree (SkillTree.tsx): once the hero has ranked, the Path Graph on top (six identities, walked edges lit, a pending step to claim), then the role's three branches of six tiers (PIX-190 added the last two, open at 11 and 14 since PIX-233), one line a node, the selected one in full below.
- `scripts/skyline.gd` — The village seen from outside (PIX-248).
- `scripts/slicer.gd` — Work cut into slices a frame (One Reach, PIX-269, step 5)
- `scripts/sound.gd` — The game's ears (PIX-128).
- `scripts/stair_rise.gd` — A way out opening where a dungeon's boss fell (PIX-339, Tom: « ça fait bizarre de tuer un boss et qu'un escalier pop »).
- `scripts/state/ailments.gd` — Status effects on one combatant (combat.ts), in real time: a web turn lasts TURN_SECONDS.
- `scripts/state/bearing.gd` — Where the hero is headed, their bearing (PIX-239, PIX-240)
- `scripts/state/bells.gd` — The Night of Bells (PIX-253 step 9, chapter 7): the dragon comes back to the square, and this time the village is ready.
- `scripts/state/bestiary.gd` — The monsters and what fighting them pays, ported from src/game/combat (monsters, encounters, drops, combat formulas) and hero/mastery.ts.
- `scripts/state/catalog.gd` — Game data (assets/data/catalog.json, edited by hand)
- `scripts/state/deeds.gd` — Deeds (PIX-219): long goals for a hero who has done the rest, read off what the save already knows
- `scripts/state/depths.gd` — A region's dungeon in floors (PIX-255, after Tom: « Les donjons, ça serait bien sur plusieurs étages, c'est un peu simple »).
- `scripts/state/economy.gd` — The town economy's rules, ported from src/game/economy/{shop,jobs,recipes, rarity}.ts
- `scripts/state/gains.gd` — What the hero wins, as things the world shows rather than words in the log (PIX-245: Tom found it "beaucoup d'écrit")
- `scripts/state/game_settings.gd` — Device preferences (src/app/settings.ts), deliberately NOT part of the save so they never travel inside a save code
- `scripts/state/game_state.gd` — The one game state (autoload `GameState`): typed sections for the hero, the pack, the settlement, progression and the explored world.
- `scripts/state/gates.gd` — The gates (PIX-254, the main story v2's step 3; Tom: « bloquer des passages dans une autre zone tant qu'on n'a pas fait certaines choses »).
- `scripts/state/gathering.gd` — Gathering spots (PIX-143): patches of each wild region's material that the hero picks by walking over.
- `scripts/state/hero_rules.gd` — What the hero's numbers add up to, ported from src/game/hero/{character, skillTree,paths,ranks}.ts
- `scripts/state/hero_state.gd` — The hero record, field for field the web `Hero` (src/game/types.ts).
- `scripts/state/holdings.gd` — The hero's stake in Pixelheim (PIX-261, out of game_state.gd)
- `scripts/state/homecoming.gd` — Coming Home (PIX-253 step 10, chapter 8): Morvax's choice and the endings.
- `scripts/state/household.gd` — The hero's house (PIX-261, out of game_state.gd)
- `scripts/state/hubs.gd` — The hubs grow (PIX-324, Something to Come Back To's step 5)
- `scripts/state/hunts.gd` — The named monsters (PIX-156): one notorious creature per wild region, each bigger and meaner than its kind, with a lair it keeps to and one move of its own.
- `scripts/state/inventory_state.gd` — Gold and everything carried (web GameState: gold, inventory, gear, equipped).
- `scripts/state/journal.gd` — The journal's quest page as rows (PIX-239, after Tom's playtest: "le journal c'est pas clair")
- `scripts/state/lamps.gd` — The land heals round the lamps (PIX-323, Something to Come Back To's step 4)
- `scripts/state/letters.gd` — Maren's five letters (PIX-253, the main story's new beginning).
- `scripts/state/main_quest.gd` — The main quest (PIX-144): chapters of steps read from the save, so the game can always say what comes next
- `scripts/state/packs.gd` — Wild packs with homes (PIX-142): each pack lives at its spawn's home, wanders a few tiles from it, notices a hero it can see, gives up a chase that strays too far and walks home healed
- `scripts/state/post.gd` — The Pixelheim Post (PIX-320, Something to Come Back To's first step)
- `scripts/state/post_state.gd` — The Pixelheim Post as the hero has kept it (PIX-320): only what they did.
- `scripts/state/posting.gd` — The Pixelheim Post in play (PIX-320): the day's post taken from the box on the square, a piece handed over to its addressee (their line, the tip, a reply to carry back).
- `scripts/state/progression_state.gd` — The quest ledger, the story's, the hunts and deeds (the save's story and quests sections).
- `scripts/state/prologue.gd` — The Night of Ash (PIX-152): the courier's first night, played.
- `scripts/state/questing.gd` — Quests, conversations and the Night of Ash (PIX-261, out of game_state.gd)
- `scripts/state/quests.gd` — The villagers' quests (src/game/quests.ts): talking to a giver accepts their quest, talking again with the objective met turns it in.
- `scripts/state/ranks.gd` — Rank evolution (src/game/hero/ranks.ts): every 5 levels the hero ascends to a new title and banks a bonus skill point (HeroRules.apply_level_ups).
- `scripts/state/relics.gd` — The five relics (PIX-170): what the five climbers left in the Reach
- `scripts/state/routes.gd` — The Post's routes (PIX-322, Something to Come Back To's step 3): the roads the courier carries the post along, and what they grow.
- `scripts/state/save_codec.gd` — Pixelheim's own save format, v5 (PIX-302)
- `scripts/state/save_slots.gd` — Save slots on disk: <dir>/slot_<n>.save, each a v5 save file (SaveCodec, PIX-302).
- `scripts/state/settlement_state.gd` — The hero's stake in Pixelheim village (web GameState: house, properties, townTier, settlers, bardSong, investments).
- `scripts/state/skills.gd` — The skill trees (hero/skillTree.ts) and the stat sheet (hero/statInfo.ts, applyStatPoint)
- `scripts/state/slot_card.gd` — What a hero's card on the Saves screen says (PIX-302), from the slot's summary (`SaveSlots.summary`, read off the save's card)
- `scripts/state/spoils.gd` — What the hero wins (PIX-261, out of game_state.gd)
- `scripts/state/story.gd` — The Ember Seal told through play (PIX-153)
- `scripts/state/text.gd` — The game in more than one language (PIX-195).
- `scripts/state/text_budget.gd` — One rule for the words on the screen (PIX-334: Tom, after a fight with a pack, « y'a aussi trop d'infos qui pop d'un coup sur l'écran en texte »).
- `scripts/state/town.gd` — Pixelheim's growth and money that works, ported from src/game/economy/ {town,bank}.ts and settlers.ts
- `scripts/state/trade.gd` — The hero at the counter (PIX-261, out of game_state.gd)
- `scripts/state/training.gd` — The hero's skills and stats (PIX-261, out of game_state.gd)
- `scripts/state/upkeep.gd` — The hero's body and kit (PIX-261, out of game_state.gd)
- `scripts/state/vault.gd` — The Kings' Vault (PIX-257, the main story's step 11): what comes after the story.
- `scripts/state/world_state.gd` — Where the hero stands and what they have explored (web WorldState plus the top-level worldSteps).
- `scripts/stats_screen.gd` — The stat sheet (WorldHud's sheet + statInfo): who the hero is, the pools and defenses, and the five stats with what each point would buy, spent here with E.
- `scripts/streets.gd` — Paving in the Medieval Age's stone (PIX-307).
- `scripts/telegraph.gd` — A danger marked on the ground before it lands (PIX-150, shared by the bosses and, PIX-155, the elites)
- `scripts/throne_screen.gd` — Morvax's choice (PIX-253 step 10; the old throne's choice, PIX-157, re-aimed): the courier's last word.
- `scripts/title_scene.gd` — The title's backdrop (PIX-139): Pixelheim's street at night under the Ashen Mountain, in Shade's art, drawn in art pixels at 2x.
- `scripts/title_screen.gd` — The title (PIX-139): Pixelheim's street at night under the Ashen Mountain (TitleScene, alive under a drifting camera since PIX-249), PIXELHEIM cut in gold above it, and the menu
- `scripts/touch.gd` — The phone version (PIX-162): whether to play by touch, and how the game's 1280x720 canvas sits on a screen of another shape.
- `scripts/touch_controls.gd` — On-screen controls for a phone (PIX-162)
- `scripts/town_hall_screen.gd` — The village's projects (PIX-145), across the mayor's counter or at the board on the square
- `scripts/ui_style.gd` — The game's one look (PIX-138): pages of a village ledger.
- `scripts/waypoints.gd` — Fast travel's choice on the map screen (PIX-241: "on a waypoint, show where it takes you")
- `scripts/ways.gd` — The ways between maps (PIX-269: "it isn't clear where to walk to go on").
- `scripts/weather.gd` — Each region's air and the sky's weather (PIX-224).
- `scripts/woods.gd` — The woods as they stand (PIX-309).
- `scripts/world.gd` — World orchestration: loads the maps (assets/maps), builds their TileMapLayer, moves the hero through portals and doors, and runs the frame.
- `scripts/world_bells.gd` — The Night of Bells on the town map (PIX-253 step 9): Bells holds its rules, this plays them.
- `scripts/world_camera.gd` — The world's camera (Solid Ground, PIX-260: moved out of world.gd as it was).
- `scripts/world_delve.gd` — The dungeons' floors as the hero walks them (Solid Ground, PIX-260: moved out of world.gd as they were)
- `scripts/world_foes.gd` — The world's foes (Solid Ground, PIX-260: moved out of world.gd as they were)
- `scripts/world_folk.gd` — The villagers (Solid Ground, PIX-260: moved out of world.gd as it was)
- `scripts/world_fx.gd` — What flashes and floats over the world (Solid Ground, PIX-260: moved out of world.gd as it was)
- `scripts/world_hud.gd` — The HUD over the world (Solid Ground, PIX-260: moved out of world.gd as it was)
- `scripts/world_interaction.gd` — What E does in the world (Solid Ground, PIX-260: moved out of world.gd as it was), in the web's INTERACT order
- `scripts/world_messages.gd` — What the world tells the hero in words (Solid Ground, PIX-260: moved out of world.gd as it was)
- `scripts/world_neighbours.gd` — The maps drawn beside the hero's (One Reach, PIX-269, steps 5 and 6).
- `scripts/world_soundscape.gd` — What the hero hears (Solid Ground, PIX-260: moved out of world.gd as it was)
- `scripts/world_stage.gd` — The story played over the world (Solid Ground, PIX-260: moved out of world.gd as it was)
- `scripts/world_tiles.gd` — Tile tables: the tile ids a map file may use (test_map_files refuses any other), which the hero walks on, and their colours on the map screen.
<!-- layout.py: to here -->
