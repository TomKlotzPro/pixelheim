class_name HarnessFlags
## The screenshot harness's flags (PIX-262), every one in a single table:
## its name, what it takes and what it does. Two features once read the same
## word (`motion` was both the walking check and the look book's filming,
## and froze the hero in every clip until the filming became `film`), and
## nothing said so while each step searched the command line on its own. So
## a flag is declared here once, the command line is parsed once against the
## table, and every reader - the harness's steps, the world, GameState, the
## lights, the look book - asks the parse. test_harness_flags keeps it so (no
## name twice; every flag the scripts read, and the tools and the README
## pass, is here) and `-- --help` prints it.
##
## Parsing by the table also keeps a flag's argument from reading as a flag:
## `--story ending` used to play the `ending` step too, `--foe mimic` the
## `mimic` one.

## Every flag: `flag`, the argument it takes (`takes`, "" for none) and what
## it does. In the order a run reads them: the boot's, then the harness's
## steps (harness.gd runs those in its own fixed order, whatever the order
## on the command line), then what the shot and the report line read.
const TABLE := [
	{"flag": "--screenshot", "takes": "", "does": "a harness run: a throwaway hero (no slot read or written), the steps below, then screenshot.png or --shot's file (not headless) and the report line, and quit"},
	{"flag": "--help", "takes": "", "does": "this table, then quit (nothing booted, no save touched)"},
	{"flag": "touch", "takes": "", "does": "the phone's canvas: the screen's own shape, not letterboxed (PIX-162)"},
	{"flag": "--lang", "takes": "<xx>", "does": "the game in that language for the run (PIX-195)"},
	{"flag": "--pseudo", "takes": "", "does": "every string a third longer and accented: where a longer language would overflow (PIX-195)"},
	{"flag": "--slot", "takes": "<n>", "does": "play save slot n, not a throwaway hero (it WRITES the slot)"},
	{"flag": "still", "takes": "", "does": "Reduce motion on, as a player can set it"},
	{"flag": "--town-tier", "takes": "<n>", "does": "the village at that age (default the Hamlet the flows were written for; 0 is a new hero's Ashes)"},
	{"flag": "--prologue", "takes": "<n>", "does": "the Night of Ash at its step n (harness runs skip it otherwise)"},
	{"flag": "--house-tier", "takes": "<n>", "does": "the hero's house at that tier"},
	{"flag": "--day", "takes": "<n>", "does": "the world's clock on the morning of day n: that day's patches (PIX-250) and weather; the report adds day= and patches="},
	{"flag": "--map", "takes": "<id>", "does": "boot at that map's spawn, not where the save stands"},
	{"flag": "title", "takes": "", "does": "the title over the world, as a launch shows it (with --keys, its menu walked)"},
	{"flag": "--look", "takes": "<name>", "does": "the desktop renderer in another of the app's looks (DesktopLook.LOOKS, PIX-227)"},
	{"flag": "fades", "takes": "", "does": "doors dissolve and the screen fades through the dark (harness runs cut at once); the report adds change= (dissolve, dark or cut: PIX-269) and dark= (PIX-238)"},
	{"flag": "--dissolve-at", "takes": "<s>", "does": "with fades: a door's dissolve held s seconds in (of its 0.25), for the shot (PIX-269)"},
	{"flag": "--set", "takes": "<a,b>", "does": "those settings on for this run only (large_text, clear_warnings)"},
	{"flag": "reentry", "takes": "", "does": "every outdoor map entered twice, first visit then back again: REENTRY lines with what each took (ms) and the memory kept, then BESIDE lines: each drawn beside the hero's map, its plan and build part by part (PIX-269)"},
	{"flag": "--floor", "takes": "<n>", "does": "walk down dungeon floor n"},
	{"flag": "--story", "takes": "<id>", "does": "a story scene from assets/data/story.json over the world"},
	{"flag": "gate", "takes": "", "does": "a dungeon gate's floor select (the relics brought home first, PIX-170)"},
	{"flag": "--dungeon", "takes": "<id>", "does": "with gate: which dungeon's gate (default mountain)"},
	{"flag": "descend", "takes": "", "does": "with gate: take the selected floor, as E would"},
	{"flag": "clear", "takes": "", "does": "fell every foe on the map at once: the floor's clear, its hoard, the way up"},
	{"flag": "leave", "takes": "", "does": "up the stairs, back to the gate"},
	{"flag": "--level", "takes": "<n>", "does": "a hero of that level: the rank's title (the hero looks the same at every rank)"},
	{"flag": "motion", "takes": "", "does": "the walking check (PIX-135): the hero walks right, measured frame by frame; the report adds backsteps= (needs a window)"},
	{"flag": "--fps", "takes": "<n>", "does": "the frames a second the run is stepped at (PIX-276): tools/flows.sh gives Godot --fixed-fps n (60 when not given, a frame a physics tick); with motion, its walk measured over as many frames as 0.75 s takes at that pace"},
	{"flag": "--role", "takes": "<id>", "does": "the hero's role, for how a role wears gear (PIX-175)"},
	{"flag": "--wear", "takes": "<ids>", "does": "gear put on the hero, drawn on them (PIX-129)"},
	{"flag": "--at", "takes": "<x,y>", "does": "stand the hero on that cell (before --walk, to test what stops them)"},
	{"flag": "--zoom", "takes": "<z>", "does": "the camera's zoom (`play`: the play zoom, CameraRig.ZOOM)"},
	{"flag": "--walk", "takes": "<l,d,r,u>", "does": "scripted steps, a fifth of a second each"},
	{"flag": "night", "takes": "", "does": "the hour at night, the night's packs out (PIX-252: on a wild map the report's packs= lists them)"},
	{"flag": "nightfall", "takes": "", "does": "night falls while the hero looks on: only the packs whose homes are off the screen change (PIX-252)"},
	{"flag": "overview", "takes": "", "does": "the camera frames the whole map"},
	{"flag": "--settlers", "takes": "<ids>", "does": "recruits already living in town (iva,wren)"},
	{"flag": "--cleared", "takes": "<n>", "does": "floors 1 to n beaten, the named monsters they post out in their lairs (PIX-156)"},
	{"flag": "festival", "takes": "", "does": "a festival day: stalls, barker, confetti, everyone on the square (PIX-159)"},
	{"flag": "dusk", "takes": "", "does": "evening: the town's folk on the square (PIX-159)"},
	{"flag": "ringtoss", "takes": "", "does": "the festival's ring toss"},
	{"flag": "waypoints", "takes": "", "does": "every waypoint found: the map's list at its longest"},
	{"flag": "charted", "takes": "", "does": "every map of the Reach walked end to end: the map screen's pages drawn whole, every waypoint found (PIX-266)"},
	{"flag": "worldmap", "takes": "", "does": "the world map (after --cleared, with the lairs it posts)"},
	{"flag": "rankup", "takes": "", "does": "enough XP to cross into the next rank: the ascension plays; the report adds ascension= and motes= (PIX-244)"},
	{"flag": "walk-path", "takes": "", "does": "with rankup: walk the new rank's path"},
	{"flag": "--rank-beat", "takes": "<beat>", "does": "with rankup: the ascension held still at that beat (hush, lift, flare, named, unlocks, settled; PIX-244); the report adds ascension= and motes="},
	{"flag": "levelup", "takes": "", "does": "a breath short of the next level: the first kill lifts it (PIX-211)"},
	{"flag": "--nodes", "takes": "<ids>", "does": "skills already learned, on the dock (PIX-190)"},
	{"flag": "--path", "takes": "<ids>", "does": "a path already walked (juggernaut,bastion)"},
	{"flag": "--cast", "takes": "<n>", "does": "dock key n pressed with energy to spare; prints the foes' hp before and after (PIX-190)"},
	{"flag": "stats", "takes": "", "does": "the stats sheet, points to spend"},
	{"flag": "skills", "takes": "", "does": "the skills sheet, points to spend"},
	{"flag": "splash", "takes": "", "does": "with title: the boot splash, every letter landed (tools/splash.sh)"},
	{"flag": "create", "takes": "", "does": "hero creation over the title, a role picked and a name typed"},
	{"flag": "whatsnew", "takes": "", "does": "with title: What's new over it"},
	{"flag": "options", "takes": "", "does": "the options: over the title with title, else from the pause menu"},
	{"flag": "pause", "takes": "", "does": "the pause menu"},
	{"flag": "scanlines", "takes": "", "does": "with pause or options: the scanlines on"},
	{"flag": "inventory", "takes": "", "does": "the pack, worth reading: a fine sword, armour and a ring worn, potions"},
	{"flag": "--tab", "takes": "<n|name>", "does": "the tab the opened screen shows: inventory and shop by number, journal by name (quests, letters, feats)"},
	{"flag": "codex", "takes": "", "does": "the codex, a record to read"},
	{"flag": "bestiary", "takes": "", "does": "with codex: its bestiary"},
	{"flag": "quest", "takes": "", "does": "the elder's conversation closes: Maren's tin opened, its letters and her quest taken (PIX-253)"},
	{"flag": "brew", "takes": "", "does": "a potion brewed at Vex's cauldron before her quest, then the quest taken and handed in (PIX-231)"},
	{"flag": "journal", "takes": "", "does": "the journal, a few quests in hand (PIX-171) and Maren's letters in the satchel, two delivered (PIX-253 step 2); the report adds tracked= (PIX-239)"},
	{"flag": "dockmenu", "takes": "", "does": "the dock's menu of screens, open"},
	{"flag": "lineup", "takes": "", "does": "every hero role, villager and monster sheet, walking down then right"},
	{"flag": "shop", "takes": "", "does": "the keeper's counter, 500g in hand (with --map town_shop, town_smith or town_alchemist)"},
	{"flag": "home", "takes": "", "does": "the house's fixtures (with --map town_house)"},
	{"flag": "--mode", "takes": "<mode>", "does": "with home: storage, workbench, trophies, nook or furniture"},
	{"flag": "hall", "takes": "", "does": "the town ledger, 20000g in hand"},
	{"flag": "bank", "takes": "", "does": "Mirelle's bank, 20000g in hand"},
	{"flag": "--own", "takes": "<map ids>", "does": "with hall or bank: deeds held, four days of rent waiting (PIX-178)"},
	{"flag": "saves", "takes": "", "does": "the saves screen"},
	{"flag": "--web-save", "takes": "<file>", "does": "with saves: a browser's web save (a code or JSON), offered as on a first visit"},
	{"flag": "--slots", "takes": "<dir>", "does": "with saves: the slots read from that folder (res://test/fixtures/slots: three heroes, the longest lines a card shows), nothing written (PIX-230)"},
	{"flag": "--ready", "takes": "<quest>", "does": "a quest accepted and its goal met (PIX-192)"},
	{"flag": "--take", "takes": "<quest>", "does": "a quest taken, nothing done yet"},
	{"flag": "--follow-wagon", "takes": "<s>", "does": "the hero walks beside the escort's wagon for s seconds (PIX-192)"},
	{"flag": "--talk-to", "takes": "<villager>", "does": "a conversation with that villager, wherever they stand, then --keys"},
	{"flag": "talk", "takes": "", "does": "below the map's first villager, facing them, E pressed, then --keys"},
	{"flag": "near", "takes": "", "does": "below the map's first villager, facing them (the prompt)"},
	{"flag": "chest", "takes": "", "does": "with --map town: the nook chest faced and opened"},
	{"flag": "station", "takes": "", "does": "the room's first station (a cauldron, a forge) faced and E pressed; the report adds tab= (PIX-234)"},
	{"flag": "sleep", "takes": "", "does": "with --map town_inn: the room's first bed faced and E pressed, a night slept; the report adds clock= (PIX-246)"},
	{"flag": "--hunted", "takes": "<ids>", "does": "named monsters already slain before the map loads (PIX-156; PIX-255: their lairs empty, a dungeon's shortcut open, a keepsake's family home); the report adds home= for them"},
	{"flag": "reveal", "takes": "", "does": "the town risen (PIX-147): the lamps' stop, then the age's; with --hunted, the first one's homecoming (or the door of whoever its keepsake brought home, PIX-255)"},
	{"flag": "rebuilt", "takes": "", "does": "back from the board with something built: the town redrawn, faded in, then its tour (PIX-238)"},
	{"flag": "--rise", "takes": "<project>", "does": "back from the board with that project built: its stop on the tour, the ruin giving way and the building rising in dust and confetti, then its name and what it brings (PIX-264); --wait counts from the rise; the report adds rise="},
	{"flag": "ending", "takes": "", "does": "the ending (PIX-150): home to the festival and the tour's first stop"},
	{"flag": "rest", "takes": "", "does": "with ending: the ending where Morvax is laid to rest (PIX-157)"},
	{"flag": "--seen", "takes": "<ids>", "does": "stories already told this hero"},
	{"flag": "throne", "takes": "", "does": "Morvax beaten: the choice (PIX-157)"},
	{"flag": "mimic", "takes": "", "does": "with --map mirefen: its mimic chest opened (--wait for the ambush)"},
	{"flag": "portal", "takes": "", "does": "walk into the map's nearest doorway, as a player would"},
	{"flag": "die", "takes": "", "does": "a blow no hero survives: the fall, then waking at the inn"},
	{"flag": "cast", "takes": "", "does": "a foe two steps off, then the first skill: the strike, the flash, the log"},
	{"flag": "fight", "takes": "", "does": "a foe two steps off and one swing, caught mid-swing"},
	{"flag": "--foe", "takes": "<species>", "does": "with fight: the foe (default orc; a named monster's id brings it out of its lair)"},
	{"flag": "--foe-distance", "takes": "<n>", "does": "with fight: the foe n cells off (an elite's opener from range)"},
	{"flag": "hurt", "takes": "", "does": "with fight: the foe may bite back"},
	{"flag": "elite", "takes": "", "does": "with fight: an elite foe"},
	{"flag": "slay", "takes": "", "does": "with fight: the foe felled outright, for what its death pays"},
	{"flag": "kill", "takes": "", "does": "with fight: swing until it drops (12 swings at most)"},
	{"flag": "flee", "takes": "", "does": "run for the map's first way out mid-fight (PIX-232)"},
	{"flag": "chapter", "takes": "", "does": "chapter cards on (harness runs skip them otherwise): the card of the chapter the story is at, as the world shows it once free, waited for with its entrance; the report adds chapter= and rose= (PIX-253 step 2)"},
	{"flag": "--keys", "takes": "<k,k>", "does": "real key presses, one at a time, at whatever the run opened (e, esc, space, enter, w, a, s, d...)"},
	{"flag": "--dawn-beat", "takes": "<n>", "does": "the Night of Ash's dawn jumped to beat n (PIX-197)"},
	{"flag": "lookbook", "takes": "", "does": "the look book (PIX-220): every staged scene saved and on one sheet (tools/lookbook.sh)"},
	{"flag": "perf", "takes": "", "does": "what the frames cost (PerfProbe); with lookbook, each shot's"},
	{"flag": "film", "takes": "", "does": "with lookbook: each shot filmed for a moment too"},
	{"flag": "--only", "takes": "<shot>", "does": "with lookbook: just that shot, by name (strike)"},
	{"flag": "--looks", "takes": "<a,b>", "does": "with lookbook: each shot in each of the app's looks named, a folder each (PIX-227)"},
	{"flag": "--out", "takes": "<dir>", "does": "with lookbook: where it saves (res://lookbook)"},
	{"flag": "--wait", "takes": "<s>", "does": "hold the shot s seconds (an entrance still playing)"},
	{"flag": "overflow", "takes": "", "does": "every piece of an open screen past the canvas, as OVERFLOW lines; the report adds overflow= (works headless)"},
	{"flag": "--draw-every", "takes": "<n>", "does": "a windowed run draws one frame in n, and every frame of the motion check's walk and of the picture at the end: stepped, the game is the same drawn or not, and software rendering takes most of a second a frame (tools/flows.sh: 60 in a window, a frame a second of the game's time, PIX-276)"},
	{"flag": "--shot", "takes": "<file>", "does": "save the picture there, not res://screenshot.png: runs side by side each keep their own (tools/flows.sh, PIX-270)"},
	{"flag": "-NSAppSleepDisabled", "takes": "YES", "does": "macOS's, not the game's: no napping a run whose window is hidden (tools/lookbook.sh)"},
]

## The run's own flags, parsed once (`given()`).
static var _given: HarnessFlags
## flag -> its row in TABLE.
static var _rows := {}

## flag -> its argument ("" for a flag that takes none), as first given.
var _found := {}
## What the table doesn't know, and flags given without their argument: the
## harness warns of them.
var problems: PackedStringArray = []


## Parses `args` (what came after Godot's `--`) against the table: a flag
## that takes an argument takes the word after it, whatever it is, so an
## argument never reads as a flag. A flag given twice counts the first time
## (`FLOWS_EXTRA="--lang fr"` comes last).
func _init(args := PackedStringArray()) -> void:
	var at := 0
	while at < args.size():
		var word := args[at]
		at += 1
		var row := row_of(word)
		if row.is_empty():
			problems.append("unknown flag " + word)
			continue
		var takes: String = row["takes"]
		if takes == "":
			if not _found.has(word):
				_found[word] = ""
			continue
		if at >= args.size():
			problems.append(word + " takes " + takes)
			continue
		if not _found.has(word):
			_found[word] = args[at]
		at += 1


## The command line's flags, parsed the first time they're asked for.
static func given() -> HarnessFlags:
	if _given == null:
		_given = HarnessFlags.new(OS.get_cmdline_user_args())
	return _given


## The table's row for `flag`, or {} when it isn't one.
static func row_of(flag: String) -> Dictionary:
	if _rows.is_empty():
		for row: Dictionary in TABLE:
			_rows[row["flag"]] = row
	return _rows.get(flag, {})


## Whether the run gave `flag` (with its argument, if it takes one).
func has(flag: String) -> bool:
	_declared(flag)
	return _found.has(flag)


## The argument `flag` was given, or `default` when it wasn't.
func value(flag: String, default := "") -> String:
	_declared(flag)
	return _found.get(flag, default)


## The argument of a flag that takes a list (`--walk l,d,r`), split on its
## commas; empty when it wasn't given.
func list(flag: String) -> PackedStringArray:
	return value(flag).split(",") if has(flag) else PackedStringArray()


## A flag read that the table doesn't declare is a mistake in the reader.
func _declared(flag: String) -> void:
	if row_of(flag).is_empty():
		push_error("HarnessFlags: %s is read but not in the table (scripts/harness_flags.gd)" % flag)


## The table as `-- --help` prints it: each flag and its argument, then
## what it does.
static func help() -> String:
	var width := 0
	for row: Dictionary in TABLE:
		width = maxi(width, _usage(row).length())
	var lines: PackedStringArray = [
		"godot --path godot -- --screenshot [flags]   (scripts/harness_flags.gd, PIX-262)",
		"The steps run in harness.gd's own order, whatever the order they're given in.",
		"",
	]
	for row: Dictionary in TABLE:
		lines.append("  " + _usage(row).rpad(width + 2) + String(row["does"]))
	return "\n".join(lines)


static func _usage(row: Dictionary) -> String:
	return String(row["flag"]) + ("" if row["takes"] == "" else " " + String(row["takes"]))
