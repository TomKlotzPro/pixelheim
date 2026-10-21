extends GutTest
## The hubs grow (PIX-324): the place at the end of each post road with a
## waystation grows in three steps as its road carries the post, at the same
## marks for every road beside the signposts' and the waystation's; each
## step stands on the place's own map where it says, in no one's way, drawn
## in Shade's inks; handing the post over says what grew, and the place has
## a tour of each new step once; and what's toured comes back from a save.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var _saved := {}


func before_each() -> void:
	_saved = {"post": GameState.post, "prologue": GameState.progression.prologue}
	GameState.post = PostState.new()
	GameState.progression.prologue = Prologue.DONE


func after_each() -> void:
	GameState.post = _saved["post"]
	GameState.progression.prologue = _saved["prologue"]


## `place`'s road carried `n` pieces, on the autoload's post.
static func _carried(place: String, n: int) -> void:
	GameState.post.routes.erase(place)
	Routes.tally(GameState.post, place, "bram", n)


## `map_id` planned as a visit plans it, with the autoload's state.
func _planned(map_id: String) -> MapView:
	var map := MapData.load_by_id(map_id)
	var actors := Node2D.new()
	add_child_autofree(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	return view


## Every open cell reachable from `from` on `map`.
static func _reach(map: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var stack: Array[Vector2i] = [from]
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not seen.has(next) and map.grid.has(next) and map.is_walkable(next):
				seen[next] = true
				stack.append(next)
	return seen


# ---- The data ---------------------------------------------------------------------

func test_each_hub_grows_in_three_steps_at_marks_beside_the_roads_own() -> void:
	assert_eq(Hubs.places(), ["saltmere", "blackiron", "greyhold", "frostgate"] as Array[String], "the four hubs a waystation's road ends at")
	assert_eq(Hubs.marks(), [3, 5, 7], "a step with the signposts, one before the waystation, one past it")
	assert_eq(int(Hubs.marks()[0]), Routes.signs_at("saltmere"), "the first goes up with the signposts")
	assert_between(int(Hubs.marks()[1]), Routes.signs_at("saltmere") + 1, Routes.station_at("saltmere") - 1, "the second between them")
	for place: String in Hubs.places():
		assert_false(Routes.station(place).is_empty(), "%s's road has a waystation" % place)
		assert_eq(Hubs.steps(place).size(), 3, "%s grows in three steps" % place)
		assert_gte(int(Hubs.marks()[2]), Routes.station_at(place), "%s's last step comes once its waystation is offered" % place)
		for grown: Dictionary in Hubs.steps(place):
			assert_ne(String(grown["news"]), "", "%s: each step says what's new" % place)
			assert_ne(String(grown["line"]), "", "and what's said under it on the tour")
			assert_false((grown["pieces"] as Array).is_empty(), "and puts something up")
	assert_true(Hubs.steps("mirefen").is_empty(), "a road with no waystation has no hub to grow")


## Every hub's last step is within what its road can carry: the pieces the
## threads send to or from someone living there, not counting those the
## story brings home to Pixelheim (their later letters are the village's).
func test_every_hub_can_grow_all_the_way() -> void:
	var movers := {}
	for recruit: Dictionary in Npcs._data()["recruits"]:
		if recruit.has("comesHome"):
			movers[recruit["id"]] = true
	for place: String in Hubs.places():
		var carried := 0
		for thread: Dictionary in Post._data()["threads"]:
			for piece: Dictionary in thread["pieces"]:
				var here := false
				for who: String in [String(piece.get("from", "")), String(piece.get("to", ""))]:
					var npc_id := String(Post._data()["correspondents"].get(who, {}).get("npc", ""))
					var npc := Npcs.by_id(npc_id, [])
					here = here or (not movers.has(npc_id) and String(npc.get("mapId", "")) == place)
				carried += int(here)
		assert_gte(carried, int(Hubs.marks()[-1]), "%s's road can carry the %d its last step asks (%d)" % [place, Hubs.marks()[-1], carried])


# ---- Growing ------------------------------------------------------------------------

func test_a_hub_grows_a_step_at_each_mark_a_later_piece_in_place_of_the_one_before() -> void:
	for n in 8:
		_carried("saltmere", n)
		var expected := Hubs.marks().filter(func(mark: int) -> bool: return n >= mark).size()
		assert_eq(Hubs.step(GameState.post, "saltmere"), expected, "%d pieces carried: step %d" % [n, expected])
	_carried("saltmere", 2)
	assert_true(Hubs.dressing("saltmere", GameState.post).is_empty(), "nothing before the first mark")
	var arts: Array[String] = []
	for n: int in [3, 5, 7]:
		_carried("saltmere", n)
		var dressing := Hubs.dressing("saltmere", GameState.post)
		assert_eq(dressing.size(), 1, "one lighthouse at each step")
		arts.append(String(dressing[0]["art"]))
	assert_eq(arts, ["lighthouse_dark", "lighthouse_glass", "lighthouse"] as Array[String], "mended, glazed in sea glass, lit")
	assert_true(Hubs.dressing("saltmere", GameState.post)[0].get("lit", false), "lit, it burns at night")
	_carried("greyhold", 7)
	assert_eq(Hubs.dressing("greyhold", GameState.post).map(func(entry: Dictionary) -> String: return entry["art"]), ["sutler_tent", "market_stall", "market_stall_blue"],
		"Mabel's tent, a stall beside it, then a second: a market")
	_carried("blackiron", 7)
	assert_eq(Hubs.dressing("blackiron", GameState.post).map(func(entry: Dictionary) -> String: return entry["art"]), ["keg", "box", "ore_stall"],
		"goods come down, then the trestle that becomes a stall")
	_carried("frostgate", 7)
	assert_eq(Hubs.dressing("frostgate", GameState.post).map(func(entry: Dictionary) -> String: return entry["art"]), ["lodge"], "Gunnar's lodge, its fire lit")
	assert_true(Hubs.dressing("town", GameState.post).is_empty(), "nowhere else grows")
	assert_true(Hubs.dressing("overworld", GameState.post).is_empty())


func test_handing_the_post_over_says_what_grew() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1
	var piece := Post.piece("club_ola")
	assert_eq(Routes.ends(piece, state.progression, state.settlement), ["saltmere"] as Array[String], "Bram's parcel to Ola goes down the Saltmere road")
	Routes.tally(state.post, "saltmere", "bram", int(Hubs.marks()[0]) - 1)
	var notes := Routes.carry(state.post, piece, state.progression, state.settlement)
	assert_has(notes, String(Hubs.steps("saltmere")[0]["news"]), "the log says the lighthouse is mended")
	assert_eq(Hubs.grown_since(Hubs.now(state.post), state.post), [] as Array[String], "said once")


func test_a_hub_tours_each_new_step_once_and_the_tour_comes_back_from_a_save() -> void:
	_carried("frostgate", 5)
	var news := Hubs.news(GameState.post, "frostgate")
	assert_eq(news.map(func(entry: Dictionary) -> int: return entry["step"]), [1, 2], "the frame and the walls, both new")
	assert_eq(news[1]["art"], "lodge_walls", "the tour looks at what stood up")
	assert_eq(news[1]["cell"], Vector2i(37, 38), "behind Gunnar's post, inside his camp's fence")
	assert_eq(Hubs.stops(GameState.post, "frostgate").map(func(entry: Dictionary) -> int: return entry["step"]), [2], "the tour stops once at the lodge, as it stands now")
	_carried("blackiron", 7)
	assert_eq(Hubs.stops(GameState.post, "blackiron").map(func(entry: Dictionary) -> int: return entry["step"]), [1, 3], "the crates, then the stall the trestle became")
	Hubs.toured(GameState.post, "frostgate")
	assert_true(Hubs.news(GameState.post, "frostgate").is_empty(), "toured once")
	_carried("frostgate", 7)
	assert_eq(Hubs.news(GameState.post, "frostgate").map(func(entry: Dictionary) -> String: return entry["news"]), [String(Hubs.steps("frostgate")[2]["news"])], "then only the fire")
	var back := PostState.from_dict(SaveCodec.parse_json(JSON.stringify(GameState.post.to_dict())))
	assert_eq(back.hubs, {"frostgate": 2}, "the step toured comes back from a save")
	assert_true(PostState.from_dict({}).hubs.is_empty(), "a save from before: nothing toured, the hubs tour as they're reached")


# ---- Where it stands ---------------------------------------------------------------

## Each hub fully grown, planned as a visit plans it: every step's pieces
## stand (none left out), on open ground off the paths, clear of everyone's
## place and every door's step, and nothing walked to before is cut off.
func test_every_step_stands_where_it_says_and_closes_no_way() -> void:
	for place: String in Hubs.places():
		for n: int in Hubs.marks():
			_carried(place, n)
			var view := _planned(place)
			var grown := Hubs.dressing(place, GameState.post)
			var standing: Array = view.hamlet["pieces"].map(func(piece: Dictionary) -> Vector2i: return piece["cell"])
			for entry: Dictionary in grown:
				assert_has(standing, entry["cell"], "%s at %d: its %s stands at %s" % [place, n, entry["art"], entry["cell"]])
		var map := MapData.load_by_id(place)
		var kept := Hamlet.kept_on(map)
		var before := _reach(map, map.spawn)
		var blocks: Array = _planned(place).hamlet["blocks"]
		for cell: Vector2i in blocks:
			assert_false(kept.has(cell), "%s: %s keeps clear of villagers, portals, chests and packs" % [place, cell])
			assert_true(WorldTiles.is_walkable(map.tile_at(cell)), "%s: %s stands on open ground" % [place, cell])
			assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), "%s: %s off the paths" % [place, cell])
			assert_false(map.tile_at(cell + Vector2i.UP).begins_with("door"), "%s: %s is no door's step" % [place, cell])
			map.covered[cell] = true
		var after := _reach(map, map.spawn)
		for cell: Vector2i in before:
			if cell not in blocks:
				assert_true(after.has(cell), "%s: %s still reached from the spawn" % [place, cell])
		var hub := Routes.cell_of(Routes.route(place)["hub"])
		assert_true(after.has(hub), "%s: its hub still reached" % place)


func test_hub_art_is_drawn_on_the_grid_in_shade_s_inks() -> void:
	for art: String in HubArt.PIECES:
		assert_false(HamletArt.PIECES.has(art), "%s: one name for one piece" % art)
		var rows: Array = HubArt.PIECES[art]
		var width := String(rows[0]).length()
		assert_eq(width % HamletArt.TILE, 0, "%s: whole cells wide" % art)
		assert_eq(String(rows[-1]).replace(".", "") != "", true, "%s: its foot on its bottom row" % art)
		for row: String in rows:
			assert_eq(row.length(), width, "%s: every row as wide" % art)
			for key in row:
				assert_true(key == "." or HamletArt.INKS.has(key), "%s: %s is one of the inks" % [art, key])
	for place: String in Hubs.places():
		for grown: Dictionary in Hubs.steps(place):
			for piece: Dictionary in grown["pieces"]:
				assert_true(HamletArt.PIECES.has(piece["art"]) or HubArt.PIECES.has(piece["art"]), "%s: %s is drawn" % [place, piece["art"]])
				if piece.get("lit", false):
					var burns := (HamletArt.shine(piece["art"]) as ImageTexture).get_image().get_used_rect()
					assert_gt(burns.get_area(), 0, "%s: something burns in %s at night" % [place, piece["art"]])


## Fully grown and drawn: what's lit burns only at night, with a light of
## its own; and the town's light budget holds there.
func test_a_hub_drawn_burns_its_lit_pieces_at_night() -> void:
	for place: String in ["saltmere", "frostgate"]:
		var lights := {}
		var shines := {}
		for n: int in [5, 7]:
			_carried(place, n)
			var root := Node2D.new()
			add_child_autofree(root)
			var actors := Node2D.new()
			root.add_child(actors)
			var map := MapData.load_by_id(place)
			var view := MapView.new(map, actors)
			view.plan(map.spawn)
			view.build(root)
			lights[n] = root.find_children("*", "PointLight2D", true, false).size()
			var burning := root.find_children("*", "Sprite2D", true, false).filter(func(sprite: Sprite2D) -> bool:
				return sprite.texture == HamletArt.shine(String(Hubs.steps(place)[2]["pieces"][-1]["art"])))
			shines[n] = burning.size()
			view.set_night(false)
			assert_true(burning.all(func(sprite: Sprite2D) -> bool: return not sprite.visible), "%s: dark by day" % place)
			view.set_night(true)
			assert_true(burning.all(func(sprite: Sprite2D) -> bool: return sprite.visible), "%s: alight at night" % place)
		assert_eq(shines[5], 0, "%s: nothing burns before its last step" % place)
		assert_eq(shines[7], 1, "%s: its last step burns" % place)
		assert_eq(lights[7], lights[5] + 1, "%s: with a light of its own" % place)
