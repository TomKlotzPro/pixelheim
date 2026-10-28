extends GutTest
## The Post's routes (PIX-322): each piece handed over counts toward the
## route from Pixelheim to the place at each of its ends, by who wrote it; a
## route that has carried a few has signposts at its forks, named after
## whoever wrote most along it; one that has carried enough has its
## waystation on the town's board, a work paid in gold and materials;
## built, the waystation stands halfway along its route beside the road (a
## hut, a bench that mends, a post box, an ember lamp) and is a stage to
## travel to; the map draws the routes in gold; and it all comes back whole
## from a save.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node
var _saved := {}


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1
	# MapView draws from the autoload's state: kept to put back.
	_saved = {
		"post": GameState.post,
		"projects": GameState.settlement.projects.duplicate(),
		"tier": GameState.settlement.town_tier,
		"prologue": GameState.progression.prologue,
		"steps": GameState.world.steps,
	}


func after_each() -> void:
	GameState.post = _saved["post"]
	GameState.settlement.projects.assign(_saved["projects"])
	GameState.settlement.town_tier = _saved["tier"]
	GameState.progression.prologue = _saved["prologue"]
	GameState.world.steps = _saved["steps"]
	if not TranslationServer.get_locale().begins_with("en"):
		Text.apply("en")


## Every route carried as far as its waystation (or its signposts, with
## none), the waystations built: on `post` and `settlement`.
static func _carried_all(post: PostState, settlement: SettlementState) -> void:
	for place: String in Routes.places():
		var far := Routes.station_at(place) if not Routes.station(place).is_empty() else Routes.signs_at(place)
		Routes.tally(post, place, "bram", far)
		var work := String(Routes.station(place).get("work", ""))
		if work != "":
			settlement.projects.assign(Town.done_projects(settlement) + [work])
	Routes.raise_signs(post)


## The Ashenreach planned as a visit plans it, with the autoload's state.
func _planned() -> MapView:
	var map := MapData.load_by_id(Routes.MAP)
	var actors := Node2D.new()
	add_child_autofree(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	return view


## Steps walked on `map` from `from`, over open ground, to every cell reached.
static func _walked(map: MapData, from: Vector2i) -> Dictionary:
	var out := {from: 0}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + step
			if not out.has(next) and map.is_walkable(next):
				out[next] = int(out[cell]) + 1
				queue.append(next)
	return out


## Where a route leaves the Ashenreach: the way out just past its road's
## end.
static func _way_out(place: String) -> Vector2i:
	var path := Routes.path_cells(place)
	return path[-1] + (path[-1] - path[-2])


# ---- The data ---------------------------------------------------------------------

func test_every_route_runs_along_the_road_from_the_gate_to_a_way_out() -> void:
	var reach := MapData.load_by_id(Routes.MAP)
	assert_eq(Routes.places().size(), 7, "a road to each place the Post reaches beyond the village")
	for place: String in Routes.places():
		assert_false(Post.page(place).is_empty(), "%s is a page of the courier's book" % place)
		var path := Routes.path_cells(place)
		assert_eq(path[0], Vector2i(48, 41), "%s's road starts on the gate's landing" % place)
		for cell: Vector2i in path:
			assert_has(["path", "bridge"], reach.tile_at(cell), "%s's road runs on the road at %s" % [place, cell])
		assert_true(reach.portals.has(_way_out(place)), "%s's road ends at a way out of the Ashenreach" % place)
		for fork_id: String in Routes.route(place)["forks"]:
			var at := Routes.cell_of(Routes.fork(fork_id)["at"])
			# Beside the road: the gate's road is three cells wide, its line
			# down the middle.
			assert_true(path.any(func(cell: Vector2i) -> bool: return maxi(absi(cell.x - at.x), absi(cell.y - at.y)) <= 2),
				"%s's signpost stands beside %s's road" % [fork_id, place])
		assert_lte(Routes.signs_at(place), Routes.station_at(place), "%s's signposts before its waystation" % place)


func test_each_fork_is_named_with_a_place_for_a_name() -> void:
	for entry: Dictionary in Routes.forks():
		assert_string_contains(String(entry["name"]), "%s", "%s's name takes its writer's" % entry["id"])
		assert_true(Routes.places().any(func(place: String) -> bool: return entry["id"] in Routes.route(place)["forks"]), "%s is on a road" % entry["id"])
	for who: String in Post._data()["correspondents"]:
		assert_ne(Post.name_of(who), "", "%s has a name to give a signpost" % who)


## A waystation stands halfway: between a quarter and three quarters of the
## way from the gate's landing to its place's hub, walked along its road
## and on into its place's map.
func test_each_waystation_stands_halfway_along_its_route() -> void:
	var reach := MapData.load_by_id(Routes.MAP)
	var built := 0
	for place: String in Routes.places():
		if Routes.station(place).is_empty():
			continue
		built += 1
		var path := Routes.path_cells(place)
		var way: Dictionary = reach.portals[_way_out(place)]
		var region := MapData.load_by_id(String(way["mapId"]))
		var hub := Routes.cell_of(Routes.route(place)["hub"])
		var beyond: Dictionary = _walked(region, Vector2i(int(way["x"]), int(way["y"])))
		assert_true(beyond.has(hub), "%s's hub is walked to from its way in" % place)
		var total := path.size() + int(beyond[hub])
		var arrival := Routes.spot(place, "arrival")
		var nearest := 0
		for i in path.size():
			if (path[i] - arrival).length_squared() < (path[nearest] - arrival).length_squared():
				nearest = i
		assert_between(nearest, total / 4, total * 3 / 4, "%s's waystation is halfway along its %d steps (at %d)" % [place, total, nearest])
	assert_eq(built, 4, "a waystation on the road to each hub: Saltmere, Blackiron, Greyhold, the Frostgate")


## Where a route has no waystation, its halfway falls at its way out of the
## Ashenreach, where a waypoint stands already (the passes, the mountain's
## gate).
func test_a_road_with_no_waystation_ends_at_a_waypoint() -> void:
	var reach := MapData.load_by_id(Routes.MAP)
	for place: String in Routes.places():
		if not Routes.station(place).is_empty():
			continue
		var way := _way_out(place)
		assert_true(Interactables.waypoints().any(func(waypoint: Dictionary) -> bool:
			return waypoint["mapId"] == Routes.MAP and (Waypoints.cell(waypoint) - way).length() <= 1.5), "%s's way out is a waypoint" % place)
		assert_true(reach.portals.has(way))


func test_each_waystation_is_a_work_on_the_board_at_a_fair_price() -> void:
	var gold := 0
	for place: String in Routes.places():
		if Routes.station(place).is_empty():
			continue
		var work := Town.work(String(Routes.station(place)["work"]))
		assert_false(work.is_empty(), "%s's waystation is a works entry" % place)
		assert_eq(String(work["route"]), place)
		assert_eq(Routes.route_of_work(String(work["id"])), place)
		assert_eq(Town.age_of(String(work["id"])), 0, "part of no age")
		var cost: Dictionary = work["cost"]
		assert_gt(int(cost["gold"]), gold, "%s costs more than the road before it, further out" % place)
		assert_lte(int(cost["gold"]), 500, "and no more than a Village's project (PIX-294's curve)")
		gold = int(cost["gold"])
		assert_true((cost["items"] as Dictionary).has("ember_shard"), "%s's lamp is a shard of the mountain's warmth" % place)
		for item_id: String in cost["items"]:
			assert_ne(Catalog.item_name(item_id), item_id, "%s asks for an item the game has" % place)


# ---- What's carried ---------------------------------------------------------------

func test_a_piece_counts_toward_the_road_to_each_of_its_ends_by_who_wrote_it() -> void:
	var to_saltmere := Post.piece("club_ola")
	assert_eq(Routes.ends(to_saltmere, state.progression, state.settlement), ["saltmere"] as Array[String], "Pixelheim to Saltmere: one road")
	var across := Post.piece("canary_bite")
	assert_eq(Routes.ends(across, state.progression, state.settlement), ["saltmere", "blackiron"] as Array[String], "Saltmere to Blackiron: both roads")
	var at_home := Post.piece("dragon_letter")
	assert_eq(Routes.ends(at_home, state.progression, state.settlement), [] as Array[String], "within the village: no road")
	var within := Post.piece("charge_orders")
	state.settlement.settlers.clear()
	assert_eq(Routes.ends(within, state.progression, state.settlement), ["greyhold"] as Array[String], "within Greyhold: its road, once")
	Routes.carry(state.post, to_saltmere, state.progression, state.settlement)
	Routes.carry(state.post, across, state.progression, state.settlement)
	assert_eq(Routes.count(state.post, "saltmere"), 2)
	assert_eq(Routes.count(state.post, "blackiron"), 1)
	assert_eq(state.post.routes, {"saltmere": {"bram": 1, "wenna": 1}, "blackiron": {"wenna": 1}}, "by who wrote each")
	assert_eq(Routes.carried(state.post), ["saltmere", "blackiron"] as Array[String], "the map's gold: the roads carried along")


func test_whoever_wrote_most_names_the_road_the_first_on_a_tie() -> void:
	Routes.tally(state.post, "saltmere", "wenna", 2)
	Routes.tally(state.post, "saltmere", "bram", 2)
	assert_eq(Routes.writer(state.post, "saltmere"), "wenna", "the first to write that many")
	Routes.tally(state.post, "saltmere", "bram", 1)
	assert_eq(Routes.writer(state.post, "saltmere"), "bram")
	assert_eq(Routes.writer(state.post, "greyhold"), "", "nobody yet")


# ---- Signposts ----------------------------------------------------------------------

func test_a_few_pieces_put_signposts_up_at_the_roads_forks_named_after_its_writer() -> void:
	Routes.tally(state.post, "saltmere", "bram", Routes.signs_at("saltmere") - 1)
	assert_eq(Routes.raise_signs(state.post), [] as Array[String], "not yet")
	Routes.tally(state.post, "saltmere", "bram", 1)
	assert_eq(Routes.raise_signs(state.post), ["gate", "saltmere_fork"] as Array[String], "each of its forks")
	assert_eq(Routes.fork_name("gate", state.post), "Bram's Corner", "named after whoever wrote most")
	assert_eq(Routes.fork_about("gate", state.post), "The post road to Saltmere")
	assert_eq(Routes.raise_signs(state.post), [] as Array[String], "once")
	# Another road through the same fork: the signpost keeps its name, and
	# points down both.
	Routes.tally(state.post, "mirefen", "vex", Routes.signs_at("mirefen"))
	Routes.raise_signs(state.post)
	assert_eq(Routes.fork_name("gate", state.post), "Bram's Corner", "named the day it went up")
	assert_eq(Routes.fork_about("saltmere_fork", state.post), "The post roads to Saltmere and the Mirefen")
	Routes.tally(state.post, "blackiron", "dagny", Routes.signs_at("blackiron"))
	assert_eq(Routes.raise_signs(state.post), ["river_fork"] as Array[String], "a new road's own forks")
	assert_eq(Routes.fork_name("river_fork", state.post), "Dagny's Crossing")
	assert_eq(Routes.signposts(state.post), ["gate", "saltmere_fork", "river_fork"] as Array[String])


func test_in_french_the_signposts_are_named_too() -> void:
	Text.apply("fr")
	Routes.tally(state.post, "saltmere", "bram", Routes.signs_at("saltmere"))
	Routes.raise_signs(state.post)
	assert_eq(Routes.fork_name("gate", state.post), "Le Coin de Bram")
	assert_string_contains(Routes.fork_about("gate", state.post), "Saltmere")


func test_handing_post_over_puts_the_signposts_up_and_says_so() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	Routes.tally(state.post, "saltmere", "ola", Routes.signs_at("saltmere") - 1)
	var said: Array = []
	state.noted.connect(func(lines: Array) -> void: said.append_array(lines))
	state.post.bag.assign(["club_ola"])
	assert_ne(state.posting.deliver("saltmere_ola"), "", "the wheel handed over")
	assert_true(said.any(func(line: String) -> bool: return line.contains("Ola's Corner")), "the log says the signposts went up: %s" % [said])
	assert_eq(state.post.signs.get("gate", ""), "ola")


func test_a_settler_brought_home_keeps_their_places_page_and_road() -> void:
	# PIX-375: Iva home in the village, her post stamped Pixelheim's page and
	# the Mirefen's road never had its signposts.
	state.mark_seen(Letters.scene_id())
	state.progression.quests["letter_wenna"] = {"progress": 1, "done": true}
	state.settlement.settlers.append("settler_iva")
	assert_eq(Post.place_for("settler_iva", state.progression, state.settlement), "town", "she lives in the village now")
	assert_eq(Post.page_for("settler_iva", state.progression, state.settlement), "mirefen", "her page is still the fen's")
	Routes.tally(state.post, "mirefen", "vex", Routes.signs_at("mirefen") - 1)
	state.post.threads["reagents"] = Post.thread("reagents")["pieces"].map(func(entry: Dictionary) -> String: return entry["id"]).find("reagents_reeds")
	state.post.bag.assign(["reagents_reeds"])
	assert_ne(state.posting.deliver("settler_iva"), "", "Vex's reeds handed over in the village")
	assert_eq(state.post.places.get("reagents_reeds", ""), "mirefen", "stamped on the Mirefen's page")
	assert_true(state.post.stamps.has("mirefen"))
	assert_eq(Routes.count(state.post, "mirefen"), Routes.signs_at("mirefen"), "counted on the Mirefen's road")
	for fork: String in Routes.route("mirefen")["forks"]:
		assert_true(state.post.signs.has(fork), "the signpost at %s goes up" % fork)


# ---- Waystations ---------------------------------------------------------------------

func test_a_road_that_has_carried_enough_has_its_waystation_on_the_board() -> void:
	var work := "waystation_saltmere"
	Routes.tally(state.post, "saltmere", "bram", Routes.station_at("saltmere") - 1)
	assert_false(Town.work_offered(work, state.progression, state.settlement, state.post), "not yet")
	assert_false(Town.work_offered(work, state.progression, state.settlement), "never without the post's word")
	assert_eq(Town.work_blocker(work, state.progression, state.settlement, 9999, {"sea_glass": 9, "ember_shard": 9}, state.post), "The Saltmere road wants more post carried first.")
	var said: Array[String] = []
	var entry := Post.piece("rope_ask")
	said = Routes.carry(state.post, entry, state.progression, state.settlement)
	assert_true(said.any(func(line: String) -> bool: return line.contains("waystation")), "the log says the board has it: %s" % [said])
	assert_true(Town.work_offered(work, state.progression, state.settlement, state.post))
	assert_string_contains(Town.work_blocker(work, state.progression, state.settlement, 0, {}, state.post), "gold")
	assert_string_contains(Town.work_blocker(work, state.progression, state.settlement, 9999, {}, state.post), "Sea Glass")
	assert_eq(Town.work_blocker(work, state.progression, state.settlement, 9999, {"sea_glass": 9, "ember_shard": 9}, state.post), "")


func test_funding_a_waystation_builds_it_halfway_along_its_road() -> void:
	Routes.tally(state.post, "saltmere", "bram", Routes.station_at("saltmere"))
	state.pack.gold = 1000
	state.pack.add_item("sea_glass", 3)
	state.pack.add_item("ember_shard", 1)
	assert_eq(Routes.built(state.settlement), [] as Array[String])
	assert_ne(state.holdings.fund_work("waystation_saltmere"), "", "built at the board")
	assert_eq(state.pack.gold, 1000 - int(Town.work("waystation_saltmere")["cost"]["gold"]), "paid in gold")
	assert_eq(int(state.pack.items.get("sea_glass", 0)), 0, "and in the place's own material")
	assert_eq(int(state.pack.items.get("ember_shard", 0)), 0, "and the lamp's shard")
	assert_eq(Routes.built(state.settlement), ["saltmere"] as Array[String])
	assert_eq(state.holdings.fund_work("waystation_saltmere"), "", "built once")
	assert_eq(Routes.lamps(state.settlement), [{"place": "saltmere", "mapId": Routes.MAP, "cell": Routes.spot("saltmere", "lamp"), "kind": "sea_glass"}] as Array[Dictionary],
		"its ember lamp where PIX-323 heals the land round it")


func test_the_waystations_bench_mends_the_hero() -> void:
	state.hero.hp = 1
	state.hero.mp = 0
	var line: String = state.upkeep.rest_on_bench()
	assert_eq(state.hero.hp, int(state.hero.stats["maxHp"]), "whole again")
	assert_eq(state.hero.mp, int(state.hero.stats["maxMp"]), "mana or stamina too")
	assert_string_contains(line, "bench")
	var bench := Routes.spot("saltmere", "bench")
	assert_eq(Routes.station_with("bench", Routes.MAP, bench, state.settlement), "", "no bench before it's built")
	state.settlement.projects.assign(Town.done_projects(state.settlement) + ["waystation_saltmere"])
	assert_eq(Routes.station_with("bench", Routes.MAP, bench, state.settlement), "saltmere", "faced, E sits on it")
	assert_eq(Routes.station_with("box", Routes.MAP, Routes.spot("saltmere", "box"), state.settlement), "saltmere", "and its post box takes the day's post")
	assert_eq(Routes.station_with("bench", "town", bench, state.settlement), "", "only on the Ashenreach")


func test_a_waystation_built_is_a_stage_to_travel_to() -> void:
	assert_eq(Routes.every_waypoint(state.settlement).size(), Interactables.waypoints().size(), "none before one is built")
	state.settlement.projects.assign(Town.done_projects(state.settlement) + ["waystation_blackiron"])
	var waypoints := Routes.every_waypoint(state.settlement)
	assert_eq(waypoints.size(), Interactables.waypoints().size() + 1)
	var stage: Dictionary = waypoints[-1]
	assert_eq(stage["id"], "waystation_blackiron")
	assert_eq(stage["mapId"], Routes.MAP)
	assert_eq(stage["name"], "The Blackiron Waystation")
	assert_false(Interactables.waypoint_usable(stage, state.world.discovered, state.settlement.settlers), "found once its hut is seen")
	Discovery.discover_around(state.world.discovered, MapData.load_by_id(Routes.MAP), Routes.spot("blackiron", "hut"))
	assert_true(Interactables.waypoint_usable(stage, state.world.discovered, state.settlement.settlers))
	assert_eq(Atlas.listed(waypoints).filter(func(waypoint: Dictionary) -> bool: return waypoint["mapId"] == Routes.MAP)[-1]["id"], "waystation_blackiron",
		"listed with the Ashenreach's waypoints")


# ---- What stands -------------------------------------------------------------------------

## Every signpost and waystation on the Ashenreach at once: each piece where
## the data puts it (none left out for not fitting), on open ground off the
## road, clear of what else stands there (MapView.bare: the camps, the ways,
## the gates, the chests, the villagers), two cells or more from a pack's
## home, and no ground the hero could walk to before cut off.
func test_what_the_roads_put_up_stands_beside_the_road_and_closes_no_way() -> void:
	GameState.progression.prologue = Prologue.DONE
	GameState.post = PostState.new()
	var before := _planned()
	_carried_all(GameState.post, GameState.settlement)
	var view := _planned()
	var pieces: Array = view.routes["pieces"]
	assert_eq(pieces.size(), Routes.forks().size() + 4 * 4, "every signpost, and each waystation's hut, lamp, box and bench")
	var homes: Array[Vector2i] = []
	for spawn: Dictionary in Bestiary.spawns_on(Routes.MAP):
		homes.append(Vector2i(int(spawn["x"]), int(spawn["y"])))
	var roads := {}
	for place: String in Routes.places():
		for cell: Vector2i in Routes.path_cells(place):
			roads[cell] = true
	for cell: Vector2i in view.routes["blocks"]:
		assert_true(WorldTiles.is_walkable(view.data.tile_at(cell)), "%s stands on open ground" % cell)
		assert_false(view.data.tile_at(cell) in Hamlet.WAYS or roads.has(cell), "%s is off the road" % cell)
		assert_false(before.bare.has(cell), "%s is clear of what stands there already" % cell)
		assert_false(view.data.portals.has(cell), "%s is no way in" % cell)
		for home: Vector2i in homes:
			assert_gt(maxi(absi(cell.x - home.x), absi(cell.y - home.y)), 2, "%s keeps off the pack's home at %s" % [cell, home])
		for gate: Dictionary in Gates.on(Routes.MAP):
			assert_false(cell in Gates.cells_of(gate), "%s is no gate" % cell)
		assert_true(view.data.covered.has(cell), "%s blocks" % cell)
		assert_true(view.bare.has(cell), "%s grows no decor" % cell)
		assert_false(view.patches.has(cell), "%s grows no patch" % cell)
	# Walked from where the hero comes onto the Ashenreach and from each
	# waystation's arrival (the river's bridge may stand shut between):
	# nothing walked to before is cut off, each waystation sets the hero
	# down on ground that reaches its road, and its bench and post box are
	# faced from there.
	var starts: Array[Vector2i] = [view.data.spawn]
	for place: String in Routes.built(GameState.settlement):
		starts.append(Routes.spot(place, "arrival"))
	for start: Vector2i in starts:
		assert_true(view.data.is_walkable(start), "%s is open ground, no decor grown on it" % start)
		assert_true(view.bare.has(start) or start == view.data.spawn, "%s grows nothing" % start)
		if not before.data.is_walkable(start):
			continue
		var open_before := _walked(before.data, start)
		var open_after := _walked(view.data, start)
		for cell: Vector2i in open_before:
			if not view.routes["blocks"].has(cell) and not view.data.covered.has(cell):
				assert_true(open_after.has(cell), "%s is still walked to from %s" % [cell, start])
	for place: String in Routes.built(GameState.settlement):
		var reached := _walked(view.data, Routes.spot(place, "arrival"))
		assert_true(Routes.path_cells(place).any(func(cell: Vector2i) -> bool: return reached.has(cell)), "%s's waystation is walked to from its road" % place)
		for part: String in ["bench", "box"]:
			var spot := Routes.spot(place, part)
			assert_true([Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN].any(func(step: Vector2i) -> bool: return reached.has(spot + step)),
				"%s's %s can be faced" % [place, part])


func test_nothing_stands_before_its_road_has_carried_enough_nor_off_the_ashenreach() -> void:
	GameState.progression.prologue = Prologue.DONE
	GameState.post = PostState.new()
	Routes.tally(GameState.post, "saltmere", "bram", Routes.signs_at("saltmere") - 1)
	assert_eq((_planned().routes["pieces"] as Array).size(), 0, "no signpost yet")
	Routes.tally(GameState.post, "saltmere", "bram", 1)
	Routes.raise_signs(GameState.post)
	var view := _planned()
	assert_eq((view.routes["pieces"] as Array).map(func(piece: Dictionary) -> String: return piece["kind"]), ["signpost", "signpost"], "its two forks signed, no waystation")
	_carried_all(GameState.post, GameState.settlement)
	var town := MapData.load_tiered("town", Town.done_projects(GameState.settlement), 1)
	assert_true((Routes.plan(town, GameState.post, GameState.settlement, {})["pieces"] as Array).is_empty(), "the village has none")


## The Ashenreach drawn with every waystation built: its pieces in the
## tree, its signs' plates, and its lamps alight only at night.
func test_a_waystation_is_drawn_with_its_ember_lamp_lit_at_night() -> void:
	GameState.progression.prologue = Prologue.DONE
	GameState.post = PostState.new()
	_carried_all(GameState.post, GameState.settlement)
	GameState.world.steps = 0.0
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var map := MapData.load_by_id(Routes.MAP)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	assert_eq(view.waystations, ["saltmere", "blackiron", "greyhold", "frostgate"] as Array[String])
	assert_eq(view.post_boxes.size(), 4, "a post box at each")
	assert_eq(view.ember_lamps.size(), 4, "an ember lamp at each")
	var plates: Array = view.door_signs.map(func(entry: Dictionary) -> String: return entry["name"])
	assert_has(plates, "Bram's Corner", "the signposts' names on their plates")
	assert_has(plates, "The Saltmere Waystation", "and the waystations'")
	view.set_night(false)
	assert_false((view.ember_lamps["saltmere"] as Node2D).visible, "dull by day")
	view.set_night(true)
	assert_true((view.ember_lamps["saltmere"] as Node2D).visible, "alight at night")


# ---- The save ------------------------------------------------------------------------

func test_the_roads_signposts_and_waystations_come_back_whole_from_a_save() -> void:
	Routes.tally(state.post, "saltmere", "bram", 5)
	Routes.tally(state.post, "saltmere", "wenna", 2)
	Routes.tally(state.post, "greyhold", "fenwick", 3)
	Routes.raise_signs(state.post)
	state.settlement.projects.assign(Town.done_projects(state.settlement) + ["waystation_saltmere"])
	var file := SaveCodec.to_file(state.to_dict())
	assert_eq(file["post"]["routes"], {"saltmere": {"bram": 5, "wenna": 2}, "greyhold": {"fenwick": 3}}, "the roads' counts, in the post's own section")
	assert_eq(file["post"]["signs"], {"gate": "bram", "saltmere_fork": "bram", "river_fork": "fenwick", "greyhold_fork": "fenwick"}, "and whom each signpost is named after")
	var other: Node = autofree(GameStateScript.new())
	other.apply(SaveCodec.reread(state.to_dict()))
	assert_eq(JSON.stringify(other.post.to_dict(), "", false), JSON.stringify(state.post.to_dict(), "", false), "saved and loaded, the same")
	assert_eq(Routes.count(other.post, "saltmere"), 7)
	assert_eq(Routes.fork_name("river_fork", other.post), "Fenwick's Crossing")
	assert_eq(Routes.built(other.settlement), ["saltmere"] as Array[String], "the waystation still stands")
	assert_true(PostState.from_dict({}).routes.is_empty(), "a hero with no post yet: no roads")
