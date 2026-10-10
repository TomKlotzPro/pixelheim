extends GutTest
## The gates (PIX-254, the main story v2's step 3): each region's way in from
## the Reach shut until the story reaches it, in its order - the cliff road's
## rockfall until Maren's letters are out, the river bridge until it's
## mended at the board (Wenna's rope), Ulla's barricade until Blackiron's
## ingot is won, the avalanche until Greyhold's captain stands down. A shut
## gate blocks the walk to its region's road and says what opens it, and the
## arrow leads there; an old save is never shut out of what it has earned,
## worked out from what the save holds.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const LATE := "res://test/fixtures/web_save_late.txt"
const ORDER := ["cliff", "bridge", "barricade", "avalanche"]
## The region each gate stands before, and the maps past it.
const REGIONS := {"cliff": "saltmere", "bridge": "blackiron", "barricade": "greyhold", "avalanche": "frostgate"}

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


## The gates open for `hero` (the test's own by default), in order.
func _open(hero: Node = null) -> Array:
	var who: Node = hero if hero != null else state
	return Gates.all().filter(func(gate: Dictionary) -> bool:
		return Gates.is_open(gate, who.progression, who.settlement, who.world.discovered)).map(func(gate: Dictionary) -> String: return gate["id"])


func _win(named_id: String) -> void:
	state.spoils.defeat_monster(Hunts.fighter(named_id), Hunts.named(named_id)["mapId"], "", 10)


func _walked(map_id: String, cell: Vector2i) -> void:
	Discovery.discover_around(state.world.discovered, MapData.load_by_id(map_id), cell)


## The hero as their save has them: written out (web v4) and read back.
func _reloaded() -> Node:
	var copy: Node = autofree(GameStateScript.new())
	copy.apply(SaveCodec.migrate(SaveCodec.parse_json(SaveCodec.serialize(state.to_dict()))))
	return copy


## Whether a walk on the Reach from its spawn reaches the road into
## `region`, `shut` cells not walked on.
func _reaches(region: String, shut: Dictionary) -> bool:
	var reach := MapData.load_by_id("overworld")
	var walked := Gates.walk(reach, reach.spawn, shut)
	for cell: Vector2i in reach.portals:
		if String(reach.portals[cell].get("mapId", "")) == region and walked.has(cell):
			return true
	return false


## The cells of the gates `hero` finds shut.
func _shut_for(hero: Node) -> Dictionary:
	var shut := {}
	for gate: Dictionary in Gates.closed_on("overworld", hero.progression, hero.settlement, hero.world.discovered):
		for cell: Vector2i in Gates.cells_of(gate):
			shut[cell] = true
	return shut


# ---- The gates as data ------------------------------------------------------------

func test_four_gates_in_the_storys_order_on_the_reach() -> void:
	assert_eq(Gates.all().map(func(gate: Dictionary) -> String: return gate["id"]), ORDER)
	var reach := MapData.load_by_id("overworld")
	for gate: Dictionary in Gates.all():
		assert_eq(gate["mapId"], "overworld", "%s stands on the Reach's side" % gate["id"])
		assert_ne(Gates.mark(gate), "", "%s is named on the map" % gate["id"])
		for cell: Vector2i in Gates.cells_of(gate):
			assert_true(reach.is_walkable(cell), "%s stands on the road at %s" % [gate["id"], cell])
			assert_false(reach.portals.has(cell), "%s stands before the way out, not in it" % gate["id"])
		for need: Dictionary in gate["opens"]:
			assert_ne(String(need["line"]), "", "%s says what opens it" % gate["id"])
			if need.has("step"):
				assert_false(MainQuest.step(String(need["step"])).is_empty(), "%s waits on a real step" % gate["id"])
		var past: Dictionary = Gates.beyond(gate)
		assert_true(past["maps"].has(REGIONS[gate["id"]]), "%s stands before %s" % [gate["id"], REGIONS[gate["id"]]])
		for open_region: String in ["mirefen", "deepwood", "town"]:
			assert_false(past["maps"].has(open_region), "%s leaves %s open" % [gate["id"], open_region])
	assert_true(Gates.beyond(Gates.by_id("bridge"))["maps"].has("mountain_road"), "the mountain's gate is past the bridge, onto its road (PIX-253 step 8)")
	for region: String in ["saltmere", "seacave"]:
		assert_true(Gates.beyond(Gates.by_id("cliff"))["maps"].has(region), "the cliff road leads to %s" % region)
	for region: String in ["blackiron", "shafts", "greyhold", "keep", "cellars", "frostgate", "observatory", "icecave"]:
		assert_true(Gates.beyond(Gates.by_id("bridge"))["maps"].has(region), "the river bridge leads to %s" % region)


func test_nothing_waits_or_lands_inside_a_gate() -> void:
	var shut := {}
	for gate: Dictionary in Gates.all():
		for cell: Vector2i in Gates.cells_of(gate):
			shut[cell] = true
	var reach := MapData.load_by_id("overworld")
	assert_false(shut.has(reach.spawn), "the Reach's spawn")
	for waypoint: Dictionary in Interactables.waypoints():
		if waypoint["mapId"] != "overworld":
			continue
		for key: String in ["at", "arrival"]:
			var at := Vector2i(int(waypoint[key]["x"]), int(waypoint[key]["y"]))
			assert_false(shut.has(at), "the waypoint %s's %s" % [waypoint["id"], key])
	for spawn: Dictionary in Bestiary.spawns_on("overworld"):
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				assert_false(shut.has(Vector2i(int(spawn["x"]) + dx, int(spawn["y"]) + dy)), "the pack %s's home" % spawn["id"])
	for named: Dictionary in Hunts.all():
		if named.get("mapId", "") == "overworld":
			assert_false(shut.has(Hunts.lair(named)), "%s's lair" % named["id"])
	for npc: Dictionary in Npcs.on_map("overworld", 4, []):
		assert_false(shut.has(Vector2i(int(npc["x"]), int(npc["y"]))), "%s stands clear" % npc["id"])
	for map_id: String in Catalog._data()["places"]:
		var map := MapData.load_by_id(map_id)
		for cell: Vector2i in map.portals:
			var target: Dictionary = map.portals[cell]
			if target.get("mapId", "") == "overworld":
				assert_false(shut.has(Vector2i(int(target["x"]), int(target["y"]))), "arriving from %s" % map_id)


# ---- What opens each, in the story ------------------------------------------------

func test_each_gate_opens_with_its_step_of_the_story() -> void:
	assert_eq(_open(), [], "a new hero: every way in shut")
	# The tin: the letters are out, and Bram's crew clears the cliff road.
	state.questing.finish_dialogue("elder")
	assert_eq(_open(), ["cliff"])
	var bridge := Gates.by_id("bridge")
	assert_string_contains(Gates.line(bridge, state.progression, state.settlement), "Saltmere", "the bridge wants Saltmere's rope")
	assert_false(Town.work_offered("river_bridge", state.progression, state.settlement), "nothing to mend it with yet")
	# Wenna's letter: her rope comes home, and the bridge is the board's.
	state.questing.finish_dialogue("saltmere_wenna")
	assert_eq(_open(), ["cliff"], "rope isn't a bridge")
	assert_eq(Gates.line(bridge, state.progression, state.settlement), "The river bridge burned on the Night of Ash. Mend it at the board on the square.")
	assert_true(Town.work_offered("river_bridge", state.progression, state.settlement))
	state.pack.gold = 500
	assert_ne(state.holdings.fund_work("river_bridge"), "", "mended at the board")
	assert_eq(_open(), ["cliff", "bridge"])
	# Blackiron done: Pell writes ahead, and Ulla lets the courier by.
	_win("seam_warden")
	assert_eq(_open(), ["cliff", "bridge", "barricade"])
	# Greyhold's captain stands down: Ulla's wardens dig the Frostgate road out.
	_win("hollow_captain")
	assert_eq(_open(), ORDER)


func test_a_shut_gate_blocks_the_walk_to_its_regions_road() -> void:
	for gate: Dictionary in Gates.all():
		var shut := {}
		for cell: Vector2i in Gates.cells_of(gate):
			shut[cell] = true
		var region: String = REGIONS[gate["id"]]
		assert_false(_reaches(region, shut), "%s shut: no road to %s" % [gate["id"], region])
		assert_true(_reaches(region, {}), "%s open: the road to %s" % [gate["id"], region])
		for open_region: String in ["mirefen", "deepwood", "town"]:
			assert_true(_reaches(open_region, shut), "%s shut: %s still open" % [gate["id"], open_region])
	# A new hero: only the Mirefen, the Deepwood and the village.
	var shut := _shut_for(state)
	for region: String in REGIONS.values():
		assert_false(_reaches(region, shut), "a new hero can't walk to %s" % region)
	var reach := MapData.load_by_id("overworld")
	assert_false(Gates.walk(reach, reach.spawn, shut).has(Vector2i(48, 6)), "nor to the mountain's gate")
	assert_true(reach.portals[Vector2i(48, 6)].get("barred", false), "(the mountain's gate, barred until Maren's promise)")
	# Each opened in turn opens its road.
	state.questing.finish_dialogue("elder")
	assert_true(_reaches("saltmere", _shut_for(state)))
	assert_false(_reaches("blackiron", _shut_for(state)))
	_win("hollow_captain")
	for region: String in REGIONS.values():
		assert_true(_reaches(region, _shut_for(state)), "past Greyhold's captain: the road to %s" % region)


# ---- Old saves ---------------------------------------------------------------------

func test_an_old_save_at_each_stage_finds_what_it_earned_open() -> void:
	assert_eq(_open(_reloaded()), [], "fresh")
	state.mark_seen(Letters.scene_id())
	assert_eq(_open(_reloaded()), ["cliff"], "after the tin")
	_walked("saltmere", Vector2i(16, 2))
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	assert_eq(_open(_reloaded()), ["cliff"], "after Wenna: the bridge waits on the board")
	state.progression.hunted.append("tidecaller")
	state.progression.hunted.append("seam_warden")
	_walked("blackiron", Vector2i(53, 30))
	assert_eq(_open(_reloaded()), ["cliff", "bridge", "barricade"], "after the ingot")
	state.progression.hunted.append("hollow_captain")
	assert_eq(_open(_reloaded()), ORDER, "after the shield")
	var late: Node = autofree(GameStateScript.new())
	late.apply(SaveCodec.decode_code(FileAccess.get_file_as_string(LATE)))
	assert_false(late.world.discovered.is_empty(), "the late web hero has walked")
	assert_eq(_open(late), ORDER, "the late web hero who beat Morvax: every way in open")


func test_a_hero_already_past_a_gate_finds_it_open() -> void:
	# Ground past a gate seen from its near side is a glimpse, not a visit.
	_walked("overworld", Vector2i(48, 31))
	_walked("overworld", Vector2i(16, 61))
	assert_eq(_open(), [], "glimpsed over the bridge and the rockfall")
	_walked("overworld", Vector2i(93, 15))
	_walked("overworld", Vector2i(68, 6))
	assert_false(Gates.passed(Gates.by_id("barricade"), state.progression, state.world.discovered), "glimpsed over the barricade")
	assert_false(Gates.passed(Gates.by_id("avalanche"), state.progression, state.world.discovered), "glimpsed over the avalanche")
	before_each()
	# The Ash Fields walked, past the bridge (a hero from before it burned).
	_walked("overworld", Vector2i(48, 24))
	assert_eq(_open(), ["cliff", "bridge"], "the bridge, and the cliff road before it in the story")
	before_each()
	_walked("blackiron", Vector2i(35, 20))
	assert_eq(_open(), ["cliff", "bridge"], "Blackiron set foot in")
	before_each()
	_walked("icecave", Vector2i(4, 25))
	assert_eq(_open(), ORDER, "the Frostgate's ice cave, past every gate")
	before_each()
	state.progression.hunted.append("cinderjaw")
	assert_eq(_open(), ["cliff", "bridge"], "a named monster slain in the Ash Fields")
	before_each()
	state.progression.quests["letter_hale"] = {"progress": 1, "done": true}
	assert_eq(_open(), ["cliff", "bridge", "barricade"], "Captain Hale's letter delivered")
	before_each()
	state.progression.cleared_levels.append(1)
	assert_eq(_open(), ORDER, "a floor of the mountain cleared")
	before_each()
	state.progression.deepest = 1
	assert_eq(_open(), ORDER, "down in the Deep Hunt")


# ---- Saying what opens it ----------------------------------------------------------

func test_the_story_past_a_shut_gate_leads_to_what_opens_it() -> void:
	state.questing.finish_dialogue("elder")
	state.questing.finish_dialogue("saltmere_wenna")
	_win("tidecaller")
	assert_eq(MainQuest.next_step(state.progression, state.settlement)["id"], "letter_pell")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq(lead["gate"], "bridge")
	assert_eq(lead["step"], "The river bridge burned on the Night of Ash. Mend it at the board on the square.")
	assert_eq([lead["map_id"], lead["cell"]], ["town", Town.project_board()], "to the board on the square")
	assert_true(lead["main"], "still the main story's: the arrow stays gold")
	assert_true(Bearing.tells_story(lead))
	var rows := Journal.rows(state.progression, state.settlement, state.pack.items)
	assert_eq(rows[0]["line"], Bearing.line(lead), "the journal's story row says the gate's line")
	var pell: Dictionary = rows.filter(func(row: Dictionary) -> bool: return row["id"] == "letter_pell")[0]
	assert_eq(pell["lead"]["gate"], "bridge", "and so does Pell's letter in the satchel")
	# Mended: Pell, at last.
	state.pack.gold = 500
	state.holdings.fund_work("river_bridge")
	lead = Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_false(lead.has("gate"))
	assert_eq(lead["who"], "mines_pell")


func test_a_followed_thread_past_a_shut_gate_leads_there_too() -> void:
	state.questing.finish_dialogue("elder")
	# Pell's letter followed before Wenna has hers: the bridge wants her rope.
	assert_true(Journal.follow(state.progression, "letter_pell"))
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq(lead["gate"], "bridge")
	assert_eq(lead["who"], "saltmere_wenna", "to Wenna, and her rope")
	assert_eq(lead["quest_id"], "letter_pell", "still following Pell's letter")
	assert_false(lead["main"])
	assert_true(Bearing.tells_story(lead), "a letter carries the story: gold")
	# Captain Hale's, past the bridge and Ulla's barricade both: the first.
	assert_true(Journal.follow(state.progression, "letter_hale"))
	assert_eq(Bearing.active(state.progression, state.settlement, state.pack.items)["gate"], "bridge")
	state.pack.gold = 500
	state.questing.finish_dialogue("saltmere_wenna")
	state.holdings.fund_work("river_bridge")
	lead = Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq(lead["gate"], "barricade", "then Ulla's barricade")
	assert_eq([lead["map_id"], lead["cell"]], ["shafts_blackseam", Hunts.lair(Hunts.named("seam_warden"))], "to the Seam Warden, whose ingot opens it")
	# A hero who has walked everywhere is never detoured.
	var everywhere := {}
	Atlas.walk_all(everywhere)
	assert_eq(Bearing.active(state.progression, state.settlement, state.pack.items, everywhere)["who"], "greyhold_ulla")


func test_wenna_sends_the_rope_home_with_her_answer() -> void:
	state.questing.finish_dialogue("elder")
	var logged: Array = []
	state.noted.connect(func(lines: Array) -> void: logged.append_array(lines))
	state.questing.finish_dialogue("saltmere_wenna")
	assert_true(logged.any(func(line: String) -> bool: return "Brin's best rope" in line), "a story beat in the log: %s" % [logged])


# ---- The river bridge on the board -------------------------------------------------

func test_the_river_bridge_is_a_work_on_the_board_not_an_age() -> void:
	assert_eq(Town.age_of("river_bridge"), 0, "part of no age")
	assert_true(Town.project("river_bridge").is_empty())
	assert_eq(Town.work("river_bridge")["gate"], "bridge")
	state.questing.finish_dialogue("elder")
	assert_eq(Town.work_blocker("river_bridge", state.progression, state.settlement, 9999, {}), "It wants rope, and the best rope is in Saltmere.")
	state.questing.finish_dialogue("saltmere_wenna")
	assert_string_contains(Town.work_blocker("river_bridge", state.progression, state.settlement, 0, {}), "gold")
	assert_eq(Town.work_blocker("river_bridge", state.progression, state.settlement, 9999, {}), "")
	# A save from before the projects, in the Hamlet: its ages are kept.
	state.settlement.town_tier = 1
	state.settlement.projects.clear()
	var hamlet := Town.done_projects(state.settlement)
	var age := Town.current_age(state.settlement)
	state.pack.gold = 200
	assert_ne(state.holdings.fund_work("river_bridge"), "")
	assert_eq(state.pack.gold, 200 - int(Town.work("river_bridge")["cost"]["gold"]))
	assert_true("river_bridge" in Town.done_projects(state.settlement))
	for project_id: String in hamlet:
		assert_true(project_id in Town.done_projects(state.settlement), "%s still stands" % project_id)
	assert_eq(Town.current_age(state.settlement), age, "the town builds the same age")
	assert_eq(Town.work_blocker("river_bridge", state.progression, state.settlement, 9999, {}), "Already built.")
	assert_eq(state.holdings.fund_work("river_bridge"), "", "built once")


# ---- How they look -----------------------------------------------------------------

func test_each_gate_is_drawn_across_its_cells_in_art_the_game_has() -> void:
	for paid: bool in [true, false]:
		for gate: Dictionary in Gates.all():
			var art := GateArt.plan(gate, paid)
			assert_false(art["pieces"].is_empty(), "%s is drawn" % gate["id"])
			var cells := Gates.cells_of(gate)
			for piece: Dictionary in art["pieces"]:
				var near := cells.any(func(cell: Vector2i) -> bool: return maxi(absi(cell.x - piece["cell"].x), absi(cell.y - piece["cell"].y)) <= 1)
				assert_true(near, "%s's pieces stand on it" % gate["id"])
				assert_true(String(piece["sheet"]) in ["world", "dungeon", "villager"] + (["props"] if paid else []), "%s: art the game has%s" % [gate["id"], "" if paid else ", without the paid pack"])
	assert_eq(GateArt.plan(Gates.by_id("bridge"), true)["hides"], Gates.cells_of(Gates.by_id("bridge")), "the burnt bridge's planks are gone where it's shut")
	var guards: Array = GateArt.plan(Gates.by_id("barricade"), false)["pieces"].filter(func(piece: Dictionary) -> bool: return piece["sheet"] == "villager")
	assert_eq(guards.size(), 1, "one of Ulla's guard keeps the barricade")
	assert_eq(guards[0]["sprite"], "guard")
