extends GutTest
## The Post, step 6 (PIX-325): the post house, a work on the town's board
## once a waystation stands, brings a bag of five a morning (Wren's riders)
## and Pip's loft (a thread of its own), and stands behind the box on the
## square at every age; Morvax keeps count of the courier's lamps on his
## forge wall and says it after the story; and the map renames the Ash
## Fields as their ash heals round the lamps.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const STATIONS := ["waystation_saltmere", "waystation_blackiron", "waystation_greyhold", "waystation_frostgate"]

var state: Node
var _saved := {}


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 2
	_saved = {
		"projects": GameState.settlement.projects.duplicate(),
		"tier": GameState.settlement.town_tier,
		"quests": GameState.progression.quests.duplicate(true),
		"post": GameState.post,
		"steps": GameState.world.steps,
	}


func after_each() -> void:
	GameState.settlement.projects.assign(_saved["projects"])
	GameState.settlement.town_tier = _saved["tier"]
	GameState.progression.quests = _saved["quests"]
	GameState.post = _saved["post"]
	GameState.world.steps = _saved["steps"]


## `works` built on top of the age the hero's village stands at.
func _build(works: Array) -> void:
	state.settlement.projects.assign(Town.done_projects(state.settlement) + works)


## Chapter 2 as test_post has it: Maren's first letter in Wenna's hands, and
## Saltmere and the Reach walked.
func _chapter_two() -> void:
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	for map_id: String in ["saltmere", "overworld"]:
		var map := MapData.load_by_id(map_id)
		Discovery.discover_around(state.world.discovered, map, map.spawn)


# ---- The post house ------------------------------------------------------------------

func test_the_post_house_is_on_the_board_once_a_waystation_stands() -> void:
	var house := Town.work("post_house")
	assert_false(house.is_empty(), "a work on the town's board")
	assert_false(Town.work_offered("post_house", state.progression, state.settlement, state.post), "not before a waystation")
	assert_eq(Town.work_blocker("post_house", state.progression, state.settlement, 99999, {}, state.post), String(house["line"]) + ".")
	_build(["waystation_saltmere"])
	assert_true(Town.work_offered("post_house", state.progression, state.settlement, state.post), "offered once one stands")
	assert_eq(Routes.route_of_work("post_house"), "", "a work on the square, no road's")


func test_funded_the_box_holds_five_a_morning() -> void:
	_build(["waystation_saltmere"])
	assert_eq(Post.bag_size(state.settlement), 3, "three before the post house")
	assert_false(Post.house_built(state.settlement))
	var cost: Dictionary = Town.work("post_house")["cost"]
	state.pack.gold = int(cost["gold"])
	for item_id: String in cost["items"]:
		state.pack.add_item(item_id, int(cost["items"][item_id]))
	assert_eq(state.holdings.fund_work("post_house"), String(Town.work("post_house")["built"]))
	assert_eq(state.pack.gold, 0, "paid as a project is")
	assert_true(Post.house_built(state.settlement))
	assert_eq(Post.bag_size(state.settlement), 5, "Wren's riders bring five a morning")
	assert_eq(state.holdings.fund_work("post_house"), "", "built once")


func test_a_morning_brings_five_pieces_once_it_stands() -> void:
	_chapter_two()
	state.settlement.town_tier = 4
	state.settlement.projects.clear()
	var offered := Post.offered(state.post, state.progression, state.settlement, state.world.discovered)
	assert_gt(offered.size(), 5, "more threads waiting than a bag holds")
	assert_eq(Post.in_box(state.post, 3, state.progression, state.settlement, state.world.discovered).size(), 3)
	_build(STATIONS.slice(0, 1) + ["post_house"])
	assert_eq(Post.in_box(state.post, 3, state.progression, state.settlement, state.world.discovered).size(), 5)


func test_pips_loft_writes_once_the_post_house_stands() -> void:
	_chapter_two()
	state.settlement.town_tier = 4
	state.settlement.projects.clear()
	assert_eq(Post.thread_of("loft_doves"), "the_loft")
	var offered := Post.offered(state.post, state.progression, state.settlement, state.world.discovered)
	assert_does_not_have(offered, "loft_doves", "no loft before the post house")
	_build(["waystation_saltmere", "post_house"])
	offered = Post.offered(state.post, state.progression, state.settlement, state.world.discovered)
	assert_has(offered, "loft_doves", "Pip in charge of the doves")
	assert_eq(Post.addressee(Post.piece("loft_doves")), "elder")
	assert_eq(Post.addressee(Post.piece("loft_steve")), "settler_wren", "and the riders hear about it")


## The post house stands behind the box on open ground at every age of the
## village, nobody's spot or pacing on it, and its foot blocks as the art.
func test_it_stands_behind_the_box_at_every_age() -> void:
	var cells := Post.house_cells()
	assert_eq(cells, [Post.box_cell() + Vector2i.UP, Post.box_cell() + Vector2i(1, -1)] as Array[Vector2i])
	GameState.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	GameState.post = PostState.new()
	var settled: Array = Npcs._data()["recruits"].map(func(recruit: Dictionary) -> String: return recruit["id"])
	for tier in range(0, Town.MAX_TIER + 1):
		var done := Town.projects_through(tier)
		GameState.settlement.town_tier = tier
		GameState.settlement.projects.assign(done + ["waystation_saltmere", "post_house"])
		var map := MapData.load_tiered("town", done, 1)
		var view := MapView.new(map, null)
		view.plan(map.spawn)
		assert_eq(view.camps.get(cells[0], {}).get("kind", ""), "post_house", "age %d: the post house behind the box" % tier)
		assert_eq(view.camps.get(Post.box_cell(), {}).get("kind", ""), "post", "age %d: the box before it" % tier)
		for cell: Vector2i in cells:
			assert_true(map.covered.has(cell), "age %d: %s blocks" % [tier, cell])
			assert_false(map.portals.has(cell), "age %d: no door under it" % tier)
		assert_true(map.is_walkable(Post.box_cell() + Vector2i.DOWN), "age %d: the box is still faced from open ground" % tier)
		for npc: Dictionary in Npcs.on_map("town", tier, [], done) + Npcs.on_map("town", tier, settled, done):
			for offset: Vector2i in Npcs.LOOP if npc["wander"] else [Vector2i.ZERO]:
				assert_does_not_have(cells, Vector2i(npc["x"], npc["y"]) + offset, "age %d: %s keeps off it" % [tier, npc["id"]])
	var foot := MapView.POST_HOUSE_FOOT
	for left in [0, MapView.TILE]:
		assert_true(foot.has_point(Vector2(left + 4, 7)) and foot.has_point(Vector2(left + 12, 15)), "each cell blocked over x 4..12, y 7..15")
	assert_eq(HamletArt.size("post_house"), Vector2i(32, 44), "two cells wide")


# ---- Morvax's count ------------------------------------------------------------------

func test_morvax_counts_the_couriers_lamps_line_by_line() -> void:
	assert_eq(Homecoming.count_line(0), "", "nothing to count before a lamp")
	var said: Array = Homecoming.data()["count"]["lines"]
	var lines: Array[String] = []
	for lamps in range(1, said.size() + 3):
		lines.append(Homecoming.count_line(lamps))
	assert_string_starts_with(lines[0], "Forty-two.", "the village's forty-one and the courier's one")
	assert_string_contains(lines[0], "That's yours, isn't it.")
	assert_string_starts_with(lines[1], "Forty-three.")
	assert_string_starts_with(lines[2], "Forty-four.")
	assert_string_starts_with(lines[3], "Forty-five.", "a lamp at every waystation")
	for lamps in range(1, said.size()):
		assert_ne(lines[lamps - 1], lines[lamps], "a new line for each lamp more")
	assert_eq(lines[said.size() - 1], lines[-1], "more than he has wall for: the last line")


func test_his_wall_says_the_count_under_the_newest_row() -> void:
	var tally := Letters.reading("morvax_tally")
	assert_eq(Letters.reading_lines(tally, state.progression, 2), tally["lines"], "the first reading as before")
	state.mark_seen("morvax_tally")
	assert_eq(Letters.reading_lines(tally, state.progression), [tally["again"]], "no lamp: the forty as before")
	var counted: Array = Letters.reading_lines(tally, state.progression, 2)
	assert_eq(counted.size(), 1)
	assert_string_contains(String(counted[0]), Homecoming.count_line(2), "two lamps: his count of them")


func test_after_the_story_he_says_his_count() -> void:
	_build(STATIONS)
	assert_eq(Routes.lamps(state.settlement).size(), 4)
	var four := Homecoming.count_line(4)
	state.mark_seen(Story.ending_scene(Homecoming.STAY))
	var at_forge := Homecoming.lines(state.progression, state.settlement, false, 3)
	assert_eq(at_forge[0], four, "at his forge: his count first")
	assert_false(" ".join(at_forge).contains("forty-one"), "in place of the forty-one he stopped at")
	assert_eq(at_forge.slice(1), Array(Homecoming.data()["peace"]).slice(1))
	assert_eq(Homecoming.lines(state.progression, state.settlement, true, 3), Homecoming.data()["festival"], "festival days are for pie")
	var home: Node = autofree(GameStateScript.new())
	home.new_game("Robin", "warrior")
	home.settlement.projects.assign(Town.done_projects(home.settlement) + STATIONS.slice(0, 2))
	home.mark_seen(Story.ending_scene(Homecoming.HOME))
	var bench := Homecoming.lines(home.progression, home.settlement, false, 3)
	assert_eq(bench[1], Homecoming.count_line(2), "on his bench: after the day's argument")
	var none: Node = autofree(GameStateScript.new())
	none.new_game("Robin", "warrior")
	none.mark_seen(Story.ending_scene(Homecoming.STAY))
	assert_eq(Homecoming.lines(none.progression, none.settlement, false, 3), Homecoming.data()["peace"], "no lamp: as before")


# ---- The fields' names ---------------------------------------------------------------

func test_the_map_renames_the_fields_as_they_heal() -> void:
	var ash := Bestiary.region("ash")
	var names: Array[String] = []
	for healed in [0, 49, 50, 179, 180, 1400]:
		names.append(Lamps.region_name(ash, healed))
	assert_eq(names, ["the Ash Fields", "the Ash Fields", "the Greening", "the Greening", "the Lantern Meadows", "the Lantern Meadows"] as Array[String])
	assert_eq(Lamps.region_name(Bestiary.region("forest"), 1400), String(Bestiary.region("forest")["name"]), "only the ash is renamed")


## On the Reach: one whole ring is the Greening; every ring on the ash whole
## is the Lantern Meadows; the map's label and the place's card say it.
func test_the_reach_is_named_by_its_healed_ground() -> void:
	var reach := MapData.load_by_id(Routes.MAP)
	GameState.post = PostState.new()
	GameState.world.steps = 20 * DayNight.DAY_CYCLE_STEPS + 100.0
	var today := Gathering.day_of(GameState.world.steps)
	GameState.settlement.projects.assign(Town.done_projects(GameState.settlement))
	assert_eq(Atlas.region_title("ash", reach), "The Ash Fields")
	GameState.settlement.projects.append("waystation_blackiron")
	GameState.post.lit["blackiron"] = today - Lamps.REACH
	assert_eq(Atlas.region_title("ash", reach), "The Greening", "one whole ring")
	GameState.settlement.projects.append_array(["waystation_greyhold", "waystation_frostgate"])
	GameState.post.lit["greyhold"] = today - 1
	GameState.post.lit["frostgate"] = today - 1
	assert_eq(Atlas.region_title("ash", reach), "The Greening", "new rings, barely begun")
	GameState.post.lit["greyhold"] = today - Lamps.REACH
	GameState.post.lit["frostgate"] = today - Lamps.REACH
	assert_gte(Lamps.healed_on(reach), 180)
	assert_eq(Atlas.region_title("ash", reach), "The Lantern Meadows", "every ring on the ash whole")
	var cell := Routes.spot("blackiron", "lamp") + Vector2i.DOWN
	assert_eq(reach.region_at(cell), "ash")
	assert_eq(PlaceTitle.at(reach, cell, true)["region"], "The Lantern Meadows", "the place's card says it")
	assert_eq(Atlas.region_title("ash"), "The Ash Fields", "off the map, its own name")
