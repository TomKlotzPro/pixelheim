class_name HarnessReport
extends RefCounted
## The screenshot harness's report line (PIX-273): `screenshot saved;
## map=town cell=(40, 33) hp=... gate=bridge`, every field declared once in
## TABLE and written by its own function below. Each branch used to add its
## field to the end of one long print in harness.gd, so any two at once
## conflicted there, and a flow anchored on the line's end (`packs=...$`)
## broke when another field came after it. Now a field is a row and a
## function, the line joins them in TABLE's order, and the flows
## (tools/flows.txt) match fields by name, never by where they stand.
##
## A new field: a row in TABLE in its place by name (after the head), and
## its function `field_<name>()` in the same place among the functions,
## returning its text, or "" when this run has none (the line leaves it
## out). A value the run knows only part-way (the clock as the hero wakes)
## is `note`d by the harness then, and its function reads it back with
## `noted`. test_harness_report keeps it so: no field twice, the head first
## and the rest by name, each with its function in the table's order,
## harness.gd writing no field itself, and every field a flow expects here.

## Every field, in the order the line shows them, and what it says. The
## head (every run's) first; then the rest by name.
const TABLE := [
	{"field": "map", "says": "the map the hero stands on"},
	{"field": "cell", "says": "the hero's cell"},
	{"field": "hp", "says": "the hero's hit points"},
	{"field": "gold", "says": "the gold in the pack"},
	{"field": "save", "says": "where the save stands: its map and cell (a dungeon floor's stays at the gate)"},
	{"field": "draws", "says": "draw calls in the frame"},
	{"field": "paused", "says": "whether the world is held still"},
	{"field": "open", "says": "the screens and conversations open over the world, by script name, or none"},
	{"field": "night", "says": "the Night of Ash's step"},
	{"field": "mobs", "says": "monsters standing (not dying)"},
	{"field": "ascension", "says": "with rankup: the ascension's beat, closed once it's gone (PIX-244)"},
	{"field": "backsteps", "says": "with motion: frames the hero stepped back on screen while walking forward, lost if found in too few to judge (PIX-135, PIX-275)"},
	{"field": "beside", "says": "with seamless: the maps drawn beside the hero's, by id, or none (PIX-269)"},
	{"field": "card", "says": "the card naming the place the hero has come to, while it's up (PIX-269)"},
	{"field": "change", "says": "with fades: how the last change of scene looked: dissolve, dark or cut, or seamless for a line walked over (PIX-269)"},
	{"field": "chapter", "says": "a chapter card's chapter, while it's up (PIX-253)"},
	{"field": "clock", "says": "with sleep: the clock the hero woke at (PIX-246)"},
	{"field": "continued", "says": "the honest card where the story runs out, while it's up: the chapter it waits on (PIX-253 step 8)"},
	{"field": "dark", "says": "with fades: what's left of a fade from the dark (PIX-238)"},
	{"field": "day", "says": "with --day: the day (PIX-250)"},
	{"field": "delivered", "says": "Maren's letters delivered, once any is out (PIX-253)"},
	{"field": "dest", "says": "the waypoint the map's list has chosen, while the map is open (PIX-241)"},
	{"field": "fell", "says": "bosses fallen, when one fell (PIX-232)"},
	{"field": "firstnight", "says": "hero creation's first night: play or skip (PIX-228)"},
	{"field": "fled", "says": "monsters that ran from a hero far above them, when any did (PIX-251)"},
	{"field": "floats", "says": "what floated up from where it was won, merged, when anything did (PIX-245)"},
	{"field": "floor", "says": "on a floor of a region's dungeon: which of how many, 2/3 (PIX-255)"},
	{"field": "frames", "says": "with crossing: the walk's frames, the most work and the 99th percentile in ms: 240 max 3.1 p99 2.4 (PIX-269)"},
	{"field": "gate", "says": "the gate the story keeps shut that said its line on this run (PIX-254)"},
	{"field": "home", "says": "who the story brought home to live in town, by first name: wenna (PIX-255)"},
	{"field": "letters", "says": "Maren's letters in the pack, once any is out (PIX-253)"},
	{"field": "logged", "says": "with floats: the lines the battle log showed (PIX-245)"},
	{"field": "maps", "says": "the maps drawn on the map's page, while the map is open: 7 on the Reach's with every region found (PIX-269)"},
	{"field": "motes", "says": "with rankup: the ascension's motes and sparks flying (PIX-244)"},
	{"field": "music", "says": "with fled: the track playing (PIX-251)"},
	{"field": "next", "says": "the main quest's next step, by id, once the Night of Ash is over: shield (PIX-255)"},
	{"field": "older", "says": "on the journal's Letters page: the older papers under the letters (PIX-253)"},
	{"field": "overflow", "says": "with overflow: pieces of an open screen running off the canvas (Solid Ground)"},
	{"field": "packs", "says": "on a wild map: the packs standing in the hero's region, :asleep by their fire (PIX-252)"},
	{"field": "page", "says": "the map's page, while the map is open (PIX-266)"},
	{"field": "patches", "says": "with --day: the patches still to pick, by cell (PIX-250)"},
	{"field": "read", "says": "on the journal's Letters page: the letters it reads (PIX-253)"},
	{"field": "rise", "says": "with --rise: how far the building on the tour has risen: ruin, rising, built (PIX-264)"},
	{"field": "rose", "says": "a chapter card's title, how far it rose coming in (PIX-253)"},
	{"field": "saves", "says": "with seamless: the saves crossing lines made (once for crossing back and forth, PIX-269)"},
	{"field": "shortcut", "says": "on a dungeon floor with a shortcut out to its way in: open or shut (PIX-255)"},
	{"field": "speaker", "says": "who the open conversation is with, by id: innkeeper (PIX-283)"},
	{"field": "stood", "says": "named foes that stood down rather than fell, when one did (PIX-255)"},
	{"field": "story", "says": "the main story's hollow diamond on the map's page, while something else is followed (PIX-253)"},
	{"field": "tab", "says": "with station: the tab the counter opened on (PIX-234)"},
	{"field": "top", "says": "the screen drawn on top when one is opened over another (the title's Options); two sharing the top layer read a=b"},
	{"field": "tracked", "says": "the quest or bounty followed, while the journal is open or one is (PIX-239)"},
]
## How many of TABLE's first rows are the head every run shows.
const HEAD := 10

var harness: Node
var world: Node
var flags: HarnessFlags
## What the run noted part-way, by field.
var _noted := {}


func _init(run: Node, given: HarnessFlags) -> void:
	harness = run
	world = run.world
	flags = given


## The report line: every field this run has, in TABLE's order.
func line() -> String:
	var texts := {}
	for row: Dictionary in TABLE:
		texts[row["field"]] = String(call("field_" + String(row["field"])))
	return joined(texts)


## `screenshot saved; ` and each field with text, as `name=text`, in TABLE's
## order (a field TABLE doesn't hold is never shown).
static func joined(texts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for row: Dictionary in TABLE:
		var text: String = texts.get(row["field"], "")
		if text != "":
			parts.append("%s=%s" % [row["field"], text])
	return "screenshot saved; " + " ".join(parts)


## Whether TABLE holds `field`.
static func has(field: String) -> bool:
	return TABLE.any(func(row: Dictionary) -> bool: return row["field"] == field)


## A field's value the run knows part-way through (the clock as the hero
## wakes, the counter's tab as it opens), for the line at the end.
func note(field: String, text: String) -> void:
	assert(has(field), "%s is not a field in HarnessReport.TABLE" % field)
	_noted[field] = text


func noted(field: String) -> String:
	return _noted.get(field, "")


## The menus and conversations still open over the world, by script name.
func screens() -> PackedStringArray:
	var out: PackedStringArray = []
	for node in world.get_children():
		if node is CanvasLayer and node.get_script() != null:
			var path: String = node.get_script().resource_path
			if path.ends_with("_screen.gd") or path.ends_with("dialogue_box.gd"):
				out.append(path.get_file().get_basename())
	return out


## The open map screen, or null.
func _map_screen() -> Node:
	for node in world.get_children():
		if node.has_method("destination_id"):
			return node
	return null


## The chapter card up, or null.
func _chapter_card() -> Node:
	for node in world.get_children():
		if node.has_method("rise_left"):
			return node
	return null


## The journal on its Letters page, or null.
func _letters_page() -> Node:
	for node in world.get_children():
		if node.get_script() == preload("res://scripts/journal_screen.gd") and node.tab == "letters":
			return node
	return null


## Maren's letters once any is out (PIX-253).
## Maren's letters taken: the four, and the fifth once she's given it.
func _letters() -> Array:
	var all: Array = Letters.all()
	all.append(Letters.fifth_quest())
	return all.filter(func(quest: Dictionary) -> bool: return GameState.progression.quests.has(quest["id"]))


# --- The head ----------------------------------------------------------------

func field_map() -> String:
	return world.map.id


func field_cell() -> String:
	return str(world.player_cell)


func field_hp() -> String:
	return str(world.player.hp)


func field_gold() -> String:
	return str(GameState.pack.gold)


func field_save() -> String:
	return "%s%s" % [GameState.world.map_id, GameState.world.cell]


func field_draws() -> String:
	return str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))


func field_paused() -> String:
	return str(world.get_tree().paused)


func field_open() -> String:
	var open := screens()
	return ",".join(open) if not open.is_empty() else "none"


func field_night() -> String:
	return str(GameState.progression.prologue)


func field_mobs() -> String:
	return str(world.get_tree().get_nodes_in_group("mobs").filter(func(mob: Node) -> bool: return not mob.dying).size())


# --- The rest, by name -------------------------------------------------------

func field_ascension() -> String:
	if not flags.has("rankup"):
		return ""
	var screen: Node = harness._ascension()
	return screen.phase if screen != null else "closed"


func field_backsteps() -> String:
	return noted("backsteps")


func field_beside() -> String:
	if not flags.has("seamless"):
		return ""
	var ids: Array = world.neighbours.drawn.keys()
	ids.sort()
	return ",".join(ids) if not ids.is_empty() else "none"


func field_card() -> String:
	var card: Variant = world.hud.place_card
	return (card as PanelContainer).get_child(0).get_child(0).text if is_instance_valid(card) else ""


func field_change() -> String:
	if not flags.has("fades"):
		return ""
	var change: String = world.scene_change
	return change if change != "" else "none"


func field_chapter() -> String:
	var card := _chapter_card()
	return str(card.number) if card != null and not card.continued else ""


func field_clock() -> String:
	return noted("clock")


func field_continued() -> String:
	var card := _chapter_card()
	return str(card.number) if card != null and card.continued else ""


func field_dark() -> String:
	if not flags.has("fades"):
		return ""
	return str(world.hud.root.get_children().filter(func(node: Node) -> bool: return node.has_meta("fade") and node.color.a > 0.5).size())


func field_day() -> String:
	return str(Gathering.day_of(GameState.world.steps)) if flags.has("--day") else ""


func field_delivered() -> String:
	var letters := _letters()
	if letters.is_empty():
		return ""
	return str(letters.filter(func(quest: Dictionary) -> bool: return GameState.progression.quests[quest["id"]]["done"]).size())


func field_dest() -> String:
	var screen := _map_screen()
	if screen == null:
		return ""
	var chosen: String = screen.destination_id()
	return chosen if chosen != "" else "none"


func field_fell() -> String:
	return str(world.foes.bosses_fallen) if world.foes.bosses_fallen > 0 else ""


func field_firstnight() -> String:
	for node in world.get_children():
		if node.get_script() == preload("res://scripts/create_screen.gd"):
			return "play" if node.play_night else "skip"
	return ""


func field_fled() -> String:
	return str(world.foes.fled) if world.foes.fled > 0 else ""


func field_floats() -> String:
	return Gains.summary(world.fx.floated) if not Gains.is_empty(world.fx.floated) else ""


func field_floor() -> String:
	if Depths.number(world.map.id) <= 0:
		return ""
	var entry := Depths.floor_of(world.map.id)
	return "%d/%d" % [int(entry["number"]), Depths.count(entry["dungeon"])]


func field_frames() -> String:
	return noted("frames")


func field_gate() -> String:
	return world.interaction.gate_said


func field_home() -> String:
	var homecomers: Array = Npcs._data()["recruits"].filter(func(recruit: Dictionary) -> bool:
		return recruit.has("comesHome") and GameState.holdings.is_settled(recruit["id"]))
	if homecomers.is_empty():
		return ""
	return ",".join(homecomers.map(func(recruit: Dictionary) -> String: return String(recruit["id"]).get_slice("_", 1)))


func field_letters() -> String:
	var letters := _letters()
	if letters.is_empty():
		return ""
	return str(letters.filter(func(quest: Dictionary) -> bool: return int(GameState.pack.items.get(quest["objective"]["itemId"], 0)) > 0).size())


func field_logged() -> String:
	return str(world.messages.logged) if not Gains.is_empty(world.fx.floated) else ""


func field_maps() -> String:
	var screen := _map_screen()
	return str(screen.painting.sheets.size()) if screen != null else ""


func field_motes() -> String:
	if not flags.has("rankup"):
		return ""
	var screen: Node = harness._ascension()
	var flying := 0
	if screen != null:
		for node in screen.find_children("*", "CPUParticles2D", true, false):
			if (node as CPUParticles2D).emitting:
				flying += 1
	return str(flying)


func field_music() -> String:
	return str(Sound.track) if world.foes.fled > 0 else ""


func field_next() -> String:
	if GameState.progression.prologue != Prologue.DONE:
		return ""
	return String(MainQuest.next_step(GameState.progression, GameState.settlement).get("id", ""))


func field_older() -> String:
	return str(Story.found_pages(GameState.progression.cleared_levels).size()) if _letters_page() != null else ""


func field_overflow() -> String:
	return noted("overflow")


func field_packs() -> String:
	if Bestiary.spawns_on(world.map.id).is_empty():
		return ""
	var packs: PackedStringArray = world.foes.standing_report(world.map.region_at(world.player_cell))
	return ",".join(packs) if not packs.is_empty() else "none"


func field_page() -> String:
	var screen := _map_screen()
	return String(screen.page_id()) if screen != null else ""


func field_patches() -> String:
	if not flags.has("--day"):
		return ""
	var cells: Array = world.view.patches.keys().filter(func(cell: Vector2i) -> bool:
		return Gathering.is_ready(GameState.world, world.view.patches[cell]["id"]))
	cells.sort()
	return ";".join(cells.map(func(cell: Vector2i) -> String: return "%d,%d" % [cell.x, cell.y])) if not cells.is_empty() else "none"


func field_read() -> String:
	if _letters_page() == null:
		return ""
	return str(Letters.satchel(GameState.progression).filter(func(carried: Dictionary) -> bool: return carried["delivered"]).size())


func field_rise() -> String:
	if not flags.has("--rise"):
		return ""
	var rise: RebuildRise = harness._rise()
	return rise.phase if rise != null else ("built" if harness._rise_phase != "none" else "none")


func field_rose() -> String:
	var card := _chapter_card()
	return str(roundi(card.rose)) if card != null else ""


func field_saves() -> String:
	return str(world.neighbours.saves) if flags.has("seamless") else ""


func field_shortcut() -> String:
	if Depths.number(world.map.id) <= 0:
		return ""
	var door := Depths.shortcut_on(world.map.id)
	if door.is_empty():
		return ""
	return "open" if world.map.portals.has(door["cell"]) else "shut"


func field_speaker() -> String:
	for node in world.get_children():
		if node.has_method("_advance"):
			return String(node.npc.get("id", ""))
	return ""


func field_stood() -> String:
	return str(world.foes.stood) if world.foes.stood > 0 else ""


func field_story() -> String:
	var screen := _map_screen()
	if screen == null:
		return ""
	var story: Vector2i = screen.painting.story_cell()
	return "%d,%d" % [story.x, story.y] if story != Bearing.NOWHERE else ""


func field_tab() -> String:
	return noted("tab")


func field_top() -> String:
	var shown: Array[CanvasLayer] = []
	_screens_in(world, shown)
	if shown.size() < 2:
		return ""
	var most := -1000
	for layer in shown:
		most = maxi(most, layer.layer)
	var names: PackedStringArray = []
	for layer in shown:
		if layer.layer == most:
			names.append(layer.get_script().resource_path.get_file().get_basename())
	return "=".join(names)


## Every screen shown under `node`, those opened over another screen included.
func _screens_in(node: Node, out: Array[CanvasLayer]) -> void:
	for child in node.get_children():
		if child is CanvasLayer and child.get_script() != null and child.visible and String(child.get_script().resource_path).ends_with("_screen.gd"):
			out.append(child)
		_screens_in(child, out)


func field_tracked() -> String:
	var tracked := GameState.progression.tracked
	if not screens().has("journal_screen") and tracked == "":
		return ""
	return tracked if tracked != "" else "none"
