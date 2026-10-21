extends GutTest
## The land heals round the lamps (PIX-323): each lit ember lamp's ring of
## green reaches a cell further into the ash each morning, up to
## Lamps.REACH, bare earth at its front and saplings nearest the lamp; only
## the ash heals; no night pack rises inside a ring and the Ash's air fades
## there, cell by cell; lamps close together share a light; and all of it
## comes from the day each lamp was lit, the one thing saved. PIX-324: each
## lamp of its region's kind, paid for on the board, with one rule (sea
## glass a cell further, frost lily twice as fast, grave moss thinning the
## Mirefen's fog); Aske trimming every ring a third wider; and a healed
## lamp's morning finds and visitors.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The Blackiron waystation's lamp stands in the Ash, the road beside it.
const PLACE := "blackiron"

var _saved := {}


func before_each() -> void:
	_saved = {
		"post": GameState.post,
		"projects": GameState.settlement.projects.duplicate(),
		"steps": GameState.world.steps,
	}
	GameState.post = PostState.new()


func after_each() -> void:
	GameState.post = _saved["post"]
	GameState.settlement.projects.assign(_saved["projects"])
	GameState.world.steps = _saved["steps"]


## The Blackiron waystation built, its lamp lit `mornings` ago, on the
## autoload's state.
static func _lit(mornings: int) -> void:
	var work := String(Routes.station(PLACE)["work"])
	GameState.settlement.projects.assign(Town.done_projects(GameState.settlement) + [work])
	GameState.world.steps = 10 * DayNight.DAY_CYCLE_STEPS + 100.0
	GameState.post.lit[PLACE] = Gathering.day_of(GameState.world.steps) - mornings


static func _lamp() -> Vector2i:
	return Routes.spot(PLACE, "lamp")


static func _ring(mornings: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"cell": Vector2i(10, 10), "mornings": mornings}]
	return out


func test_the_ring_reaches_a_cell_further_each_morning() -> void:
	for mornings in Lamps.REACH + 1:
		var ring := _ring(mornings)
		assert_eq(Lamps.reach(mornings), mornings)
		assert_eq(Lamps.stage(Vector2i(10 + mornings, 10), ring), Lamps.EARTH if mornings > 0 else 0, "morning %d: bare earth %d cells out, the ring's front" % [mornings, mornings])
		assert_eq(Lamps.stage(Vector2i(11 + mornings, 10), ring), 0, "morning %d: not a cell further" % mornings)
	# Behind the front the land grows a stage each morning.
	var cell := Vector2i(11, 10)
	var stages: Array[int] = []
	for mornings in range(1, 6):
		stages.append(Lamps.stage(cell, _ring(mornings)))
	assert_eq(stages, [Lamps.EARTH, Lamps.GRASS, Lamps.FLOWERS, Lamps.SAPLINGS, Lamps.SAPLINGS] as Array[int], "earth, grass, flowers, saplings")


func test_a_ring_stops_growing_at_its_reach() -> void:
	var whole := _ring(Lamps.REACH)
	var long_after := _ring(40)
	for d in range(0, Lamps.REACH + 3):
		var cell := Vector2i(10 + d, 10)
		assert_eq(Lamps.stage(cell, long_after), Lamps.stage(cell, whole), "%d cells out: as it was once whole" % d)
	assert_eq(Lamps.stage(Vector2i(10 + Lamps.REACH, 10), long_after), Lamps.EARTH, "bare earth at its edge")
	assert_eq(Lamps.stage(Vector2i(10 + Lamps.REACH - 1, 10), long_after), Lamps.GRASS, "grass inside it")
	assert_eq(Lamps.stage(Vector2i(10 + Lamps.REACH - 2, 10), long_after), Lamps.FLOWERS, "then flowers")
	assert_eq(Lamps.stage(Vector2i(11, 10), long_after), Lamps.SAPLINGS, "saplings nearest the lamp")
	assert_eq(Lamps.stage(Vector2i(10 + Lamps.REACH + 1, 10), long_after), 0, "never further")
	assert_eq(Lamps.stage(Vector2i(14, 14), long_after), 0, "round, not square: the corner past its reach")


func test_only_the_ash_heals() -> void:
	var grid := {}
	for y in 21:
		for x in 21:
			grid[Vector2i(x, y)] = "ash"
	grid[Vector2i(10, 12)] = "path"
	grid[Vector2i(12, 10)] = "mountain"
	grid[Vector2i(8, 10)] = "grass"
	var healed := Lamps.healed(grid, _ring(40))
	assert_false(healed.has(Vector2i(10, 12)), "the road stays a road")
	assert_false(healed.has(Vector2i(12, 10)), "the rock stays rock")
	assert_false(healed.has(Vector2i(8, 10)), "the green stays as it is")
	assert_eq(healed[Vector2i(11, 10)], "grove")
	assert_eq(healed[Vector2i(13, 10)], "meadow")
	assert_eq(healed[Vector2i(14, 10)], "grass")
	assert_eq(healed[Vector2i(15, 10)], "earth")
	assert_false(healed.has(Vector2i(16, 10)), "the ash past it")
	assert_true(Lamps.healed(grid, _ring(0)).is_empty(), "nothing the day it's lit")


func test_the_day_a_lamp_is_lit_is_kept_and_the_rest_follows_from_it() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1
	state.world.steps = 3 * DayNight.DAY_CYCLE_STEPS + 50.0
	# Saltmere's, the waystation test_routes funds.
	Routes.tally(state.post, "saltmere", "bram", Routes.station_at("saltmere"))
	state.pack.gold = 1000
	state.pack.add_item("sea_glass", 3)
	state.pack.add_item("ember_shard", 1)
	assert_ne(state.holdings.fund_work("waystation_saltmere"), "", "built at the board")
	assert_eq(state.post.lit, {"saltmere": 3}, "its lamp lit today")
	var lamp := Routes.spot("saltmere", "lamp")
	assert_eq(Lamps.rings(Routes.MAP, state.settlement, state.post, 3), [{"place": "saltmere", "cell": lamp, "kind": "sea_glass", "reach": Lamps.REACH + 1, "mornings": 0}] as Array[Dictionary], "no ring yet")
	assert_eq(Lamps.rings(Routes.MAP, state.settlement, state.post, 5)[0]["mornings"], 2, "two mornings on")
	assert_true(Lamps.rings("saltmere", state.settlement, state.post, 5).is_empty(), "lamps burn on the Ashenreach only")
	var back := PostState.from_dict(SaveCodec.parse_json(JSON.stringify(state.post.to_dict())))
	assert_eq(back.lit, {"saltmere": 3}, "the day comes back from a save")
	# A lamp with no day kept has burnt long enough to be whole.
	state.post.lit.clear()
	assert_eq(Lamps.rings(Routes.MAP, state.settlement, state.post, 5)[0]["mornings"], Lamps.REACH + 1, "whole: its sea glass's ring a cell wider (PIX-324)")


func test_no_night_pack_rises_inside_a_ring() -> void:
	var ring := _ring(Lamps.REACH)
	assert_true(Lamps.keeps_off({"x": 12, "y": 11, "hours": "night"}, ring), "a night pack's home inside: it stays home")
	assert_false(Lamps.keeps_off({"x": 10 + Lamps.REACH + 1, "y": 10, "hours": "night"}, ring), "outside, it rises")
	assert_false(Lamps.keeps_off({"x": 12, "y": 11}, ring), "a pack out at all hours keeps them")
	assert_false(Lamps.keeps_off({"x": 12, "y": 11, "hours": "night"}, _ring(1)), "the ring as far as it has grown")
	assert_false(Lamps.keeps_off({"x": 12, "y": 11, "hours": "night"}, [] as Array[Dictionary]))
	# No night pack's home on the Ashenreach today lies by a waystation.
	_lit(Lamps.REACH)
	for spawn: Dictionary in Bestiary.spawns_on(Routes.MAP):
		assert_false(Lamps.keeps_off(spawn, Lamps.now(Routes.MAP)), "%s rises as before" % spawn["id"])


func test_the_air_is_read_cell_by_cell() -> void:
	var reach := MapData.load_by_id(Routes.MAP)
	var lamp := _lamp()
	var inside := lamp + Vector2i(2, 2)
	var outside := lamp + Vector2i(Lamps.REACH + 2, 0)
	assert_eq(reach.region_at(inside), "ash")
	assert_eq(reach.region_at(outside), "ash")
	assert_eq(Weather.air_at(reach, inside), "ash", "the Ash's heat and embers before any lamp is lit")
	_lit(Lamps.REACH)
	assert_eq(Weather.air_at(reach, inside), "", "inside the ring, they fade")
	assert_eq(Weather.air_at(reach, outside), "ash", "outside, the Ash as it was")
	_lit(1)
	assert_eq(Weather.air_at(reach, inside), "ash", "the ring not grown that far yet")
	assert_eq(Weather.air_at(reach, lamp + Vector2i.RIGHT), "", "only as far as it has")
	assert_eq(Weather.air_at(MapData.load_by_id("blackiron"), lamp + Vector2i(2, 2)), "ash", "another map's Ash, untouched")


func test_the_reach_draws_the_ring_and_the_scorch_gives_way() -> void:
	_lit(3)
	KeptGround.forget()
	var map := MapData.load_by_id(Routes.MAP)
	var actors := Node2D.new()
	add_child_autofree(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	assert_false(view.healed.is_empty(), "the ash round the lamp healed")
	var look := view.look()
	var lamp := _lamp()
	var front := lamp + Vector2i(0, -3)
	var meadow := lamp + Vector2i(-1, -1)
	assert_eq(map.tile_at(front), "ash", "drawn over the map's own ash")
	assert_eq(look[front], "earth", "three mornings on: bare earth at the front")
	assert_eq(look[meadow], "meadow", "flowers by the lamp")
	assert_eq(map.tile_at(meadow), "ash", "what anyone walks on unchanged")
	var kept := KeptGround.of(map, look, MapView.EDGE_PAD)
	assert_true(_near(kept.tint_image.get_pixelv(front), PunyTerrain.TINTS["earth"]), "bare earth toned as earth, not ash: no scorch")
	assert_ne(PunyTerrain.tone_at(kept.tint_image, meadow), "tone", "the meadow untoned: Shade's grass")
	assert_true(_near(kept.tint_image.get_pixelv(lamp + Vector2i(0, -(Lamps.REACH + 2))), PunyTerrain.TINTS["ash"]), "the ash past it as it was")
	var cinders := GroundDetail.kinds().find("cinders")
	for cell: Vector2i in view.healed:
		if kept.details.has(cell):
			assert_ne(kept.details[cell].y, cinders, "no cinders on healed ground")
	KeptGround.forget()


static func _near(tone: Color, of: Color) -> bool:
	return Vector3(tone.r - of.r, tone.g - of.g, tone.b - of.b).length() < 0.01


func test_lamps_close_together_share_a_light() -> void:
	var road: Array[Vector2i] = []
	for x in range(4, 44):
		road.append(Vector2i(x, 21))
	var lit := Lamps.lit_among(road)
	assert_lt(lit.size(), road.size() / 3, "dozens of lamps, a few lights")
	for cell: Vector2i in road:
		assert_true(lit.any(func(other: Vector2i) -> bool: return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < Lamps.LIGHT_APART), "%s lit by one near it" % cell)
	for i in lit.size():
		for j in range(i + 1, lit.size()):
			assert_gte(maxi(absi(lit[i].x - lit[j].x), absi(lit[i].y - lit[j].y)), Lamps.LIGHT_APART, "lights stand apart")
	var stations: Array[Vector2i] = []
	for place: String in Routes.places():
		if not Routes.station(place).is_empty():
			stations.append(Routes.spot(place, "lamp"))
	assert_eq(Lamps.lit_among(stations), stations, "the waystations' lamps stand far apart: each its own light")


# ---- Lamp kinds, Aske's trimming, and what a healed lamp draws (PIX-324) -------------

## Every lamp's work built, each lit `mornings` ago, on the autoload's state.
static func _all_lit(mornings: int) -> void:
	var done := Town.done_projects(GameState.settlement)
	for place: String in Routes.places():
		var lamp := Routes.lamp_of(place)
		if not lamp.is_empty():
			done.append(String(lamp["work"]))
			GameState.post.lit[place] = 10 - mornings
	GameState.settlement.projects.assign(done)
	GameState.world.steps = 10 * DayNight.DAY_CYCLE_STEPS + 100.0


static func _ring_of(rings: Array[Dictionary], place: String) -> Dictionary:
	for ring: Dictionary in rings:
		if ring["place"] == place:
			return ring
	return {}


func test_each_lamp_is_of_its_regions_kind_paid_for_on_the_board() -> void:
	var kinds := {}
	for place: String in Routes.places():
		var lamp := Routes.lamp_of(place)
		if not lamp.is_empty():
			kinds[place] = lamp["kind"]
	assert_eq(kinds, {"saltmere": "sea_glass", "blackiron": "ember", "greyhold": "ember", "frostgate": "frost_lily", "mirefen": "grave_moss"},
		"sea glass on the coast road, frost lily on the pass's, grave moss at the Mirefen Pass, ember elsewhere")
	for place: String in kinds:
		assert_true(Lamps.KINDS.has(kinds[place]), "%s: a kind with a rule" % place)
		var work := Town.work(String(Routes.lamp_of(place)["work"]))
		assert_false(work.is_empty(), "%s's lamp is a work on the board" % place)
		assert_eq(Routes.route_of_work(String(work["id"])), place)
		var items: Dictionary = work["cost"]["items"]
		assert_true(items.has("ember_shard"), "%s: a shard of the mountain's warmth in it" % place)
		if kinds[place] != "ember":
			assert_true(items.has(Lamps.KIND_FINDS[kinds[place]]), "%s: paid for in its kind's own material" % place)
	var mirefen := Town.work("lamp_mirefen")
	assert_eq(Town.age_of("lamp_mirefen"), 0, "part of no age")
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1
	assert_false(Town.work_offered("lamp_mirefen", state.progression, state.settlement, state.post), "not before the Saltmere road's waystation")
	state.settlement.projects.assign(Town.done_projects(state.settlement) + ["waystation_saltmere"])
	assert_true(Town.work_offered("lamp_mirefen", state.progression, state.settlement, state.post), "then on the board")
	state.pack.gold = 1000
	state.pack.add_item("grave_moss", 3)
	state.pack.add_item("ember_shard", 1)
	state.world.steps = 4 * DayNight.DAY_CYCLE_STEPS + 50.0
	assert_ne(state.holdings.fund_work("lamp_mirefen"), "", "built at the board")
	assert_eq(state.pack.gold, 1000 - int(mirefen["cost"]["gold"]))
	assert_eq(state.post.lit.get("mirefen"), 4, "its lamp lit today")
	assert_eq(Routes.lamps(state.settlement).map(func(lamp: Dictionary) -> String: return lamp["place"]), ["saltmere", "mirefen"], "a lamp of its own where the Mirefen road leaves the Reach")
	assert_eq(Routes.built(state.settlement), ["saltmere"] as Array[String], "no waystation: no hut, bench or box")


func test_each_kind_keeps_its_one_rule() -> void:
	_all_lit(3)
	var rings := Lamps.rings(Routes.MAP, GameState.settlement, GameState.post, 10)
	assert_eq(_ring_of(rings, "blackiron")["reach"], Lamps.REACH, "an ember lamp as before")
	assert_eq(_ring_of(rings, "blackiron")["mornings"], 3)
	assert_eq(_ring_of(rings, "saltmere")["reach"], Lamps.REACH + 1, "sea glass carries the light a cell further")
	assert_eq(_ring_of(rings, "frostgate")["mornings"], 6, "a frost lily's ring grows two cells a morning")
	assert_eq(_ring_of(rings, "frostgate")["reach"], Lamps.REACH, "as far as an ember's")
	var lily: Vector2i = _ring_of(rings, "frostgate")["cell"]
	assert_eq(Lamps.stage(lily + Vector2i(Lamps.REACH, 0), [_ring_of(rings, "frostgate")] as Array[Dictionary]), Lamps.EARTH, "three mornings on, whole already")
	var ember: Vector2i = _ring_of(rings, "blackiron")["cell"]
	assert_eq(Lamps.stage(ember + Vector2i(Lamps.REACH, 0), [_ring_of(rings, "blackiron")] as Array[Dictionary]), 0, "an ember's not yet")
	# Grave moss thins the Mirefen's fog inside its ring; the others don't.
	var moss: Dictionary = _ring_of(rings, "mirefen")
	var near: Vector2i = moss["cell"] + Vector2i(1, 2)
	var reach := MapData.load_by_id(Routes.MAP)
	assert_eq(reach.region_at(near), "marsh", "the Mirefen's fog rolls over the Reach's marsh")
	assert_true(Lamps.clears("mire", near, [moss] as Array[Dictionary]), "grave moss thins it")
	assert_false(Lamps.clears("mire", near, [_ring_of(rings, "saltmere").merged({"cell": near}, true)] as Array[Dictionary]), "sea glass doesn't")
	assert_true(Lamps.clears("ash", near, [_ring_of(rings, "saltmere").merged({"cell": near}, true)] as Array[Dictionary]), "every ring fades the Ash's heat")
	assert_eq(Weather.air_at(reach, near), "", "the air by the Mirefen lamp open")
	assert_eq(Weather.air_at(reach, moss["cell"] + Vector2i(0, Lamps.REACH + 3)), "mire", "the fog past its ring as it was")
	GameState.post.lit["mirefen"] = 10
	assert_eq(Weather.air_at(reach, near), "mire", "the night it's lit, the fog still in")


func test_aske_widens_every_ring_a_third() -> void:
	_all_lit(Lamps.REACH + 5)
	var trimmed := Lamps.rings(Routes.MAP, GameState.settlement, GameState.post, 10, 0.33)
	assert_eq(_ring_of(trimmed, "blackiron")["reach"], 7, "five cells and a third: seven")
	assert_eq(_ring_of(trimmed, "saltmere")["reach"], 8, "sea glass's six and a third: eight")
	var ember: Dictionary = _ring_of(trimmed, "blackiron")
	assert_true(Lamps.inside(ember["cell"] + Vector2i(7, 0), ember), "the ring reaches seven cells")
	var aske: Dictionary = Town.recruit("frost_aske")
	assert_almost_eq(float(aske["perkValues"]["lantern"]), 0.33, 0.001, "his share, the lantern's")
	var settlers := GameState.settlement.settlers.duplicate()
	GameState.settlement.settlers.append("frost_aske")
	assert_eq(_ring_of(Lamps.now(Routes.MAP), "blackiron")["reach"], 7, "once he's home, every lamp trimmed")
	GameState.settlement.settlers.assign(settlers)
	assert_eq(_ring_of(Lamps.now(Routes.MAP), "blackiron")["reach"], Lamps.REACH, "before, as PIX-323 had it")


func test_a_healed_lamp_draws_a_find_some_mornings_and_now_and_then_a_visitor() -> void:
	_all_lit(Lamps.REACH + 5)
	var rings := Lamps.rings(Routes.MAP, GameState.settlement, GameState.post, 10)
	var finds := 0
	var visits := 0
	var items := {}
	var days := 200
	for day in days:
		var found := Lamps.finds(rings, day)
		assert_eq(found, Lamps.finds(rings, day), "day %d: the same finds every time" % day)
		for cell: Vector2i in found:
			items[found[cell]["item"]] = true
			finds += 1
		var came := Lamps.visitors(rings, day)
		var names := came.map(func(npc: Dictionary) -> String: return npc["name"])
		for name: String in names:
			assert_eq(names.count(name), 1, "day %d: %s at one lamp at a time" % [day, name])
		visits += came.size()
	var lamps := rings.size()
	assert_between(finds, days * lamps * 30 / 100, days * lamps * 50 / 100, "a find some mornings (%d of %d)" % [finds, days * lamps])
	assert_between(visits, days * lamps * 15 / 100, days * lamps * 35 / 100, "a visitor now and then (%d)" % visits)
	for item: String in items:
		assert_ne(Catalog.item_name(item), item, "%s is an item the game has" % item)
	assert_true(items.has("sea_glass") and items.has("grave_moss") and items.has("frost_lily"), "each lamp's own material among them")
	# Not before its ring is whole.
	_all_lit(2)
	var young := Lamps.rings(Routes.MAP, GameState.settlement, GameState.post, 10)
	for day in 50:
		assert_true(Lamps.finds(young, day).is_empty(), "nothing while the ground still heals")
		assert_true(Lamps.visitors(young, day).is_empty())


func test_a_find_lies_by_its_lamp_and_is_picked_as_a_patch_is() -> void:
	_all_lit(Lamps.REACH + 5)
	var view_map := MapData.load_by_id(Routes.MAP)
	var actors := Node2D.new()
	add_child_autofree(actors)
	var view := MapView.new(view_map, actors)
	view.plan(view_map.spawn)
	var rings := Lamps.now(Routes.MAP)
	var standing: Array = view.routes["pieces"].filter(func(piece: Dictionary) -> bool: return piece["kind"] == "lamp").map(func(piece: Dictionary) -> String:
		return "%s:%s" % [piece["place"], piece["lamp"]])
	assert_eq(standing, ["saltmere:sea_glass", "blackiron:ember", "greyhold:ember", "frostgate:frost_lily", "mirefen:grave_moss"], "every lamp stands, of its kind, the Mirefen Pass's too")
	for place: String in Routes.places():
		var lamp := Routes.lamp_of(place)
		if lamp.is_empty():
			continue
		for spot: String in ["find", "visit"]:
			var cell: Vector2i = lamp[spot]
			assert_true(view.data.is_walkable(cell), "%s's %s cell %s is open ground, nothing standing on it" % [place, spot, cell])
			assert_lte(Lamps.distance(cell, lamp["cell"]), Lamps.REACH, "%s's %s by its lamp, inside its ring" % [place, spot])
			assert_false(view.data.portals.has(cell))
		assert_ne(lamp["find"], lamp["visit"], "%s: the visitor never stands on the find" % place)
	# A morning with finds: they lie among the day's patches and are picked by walking over them.
	var day := 10
	while Lamps.finds(rings, day).is_empty():
		day += 1
	GameState.world.steps = day * DayNight.DAY_CYCLE_STEPS + 100.0
	view.patch_day = -1
	view.deal_patches(day)
	var found := Lamps.finds(rings, day)
	for cell: Vector2i in found:
		assert_eq(view.patches[cell], found[cell], "the find at %s among the patches" % cell)
	var cell: Vector2i = found.keys()[0]
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.world.steps = GameState.world.steps
	var picked: Dictionary = state.spoils.gather(found[cell]["id"], found[cell]["item"])
	assert_false(Gains.is_empty(picked["gains"]), "picked up")
	assert_gt(int(state.pack.items.get(found[cell]["item"], 0)), 0, "into the pack")
	assert_false(Gathering.is_ready(state.world, found[cell]["id"]), "gone until the next morning")
	state.world.steps += DayNight.DAY_CYCLE_STEPS
	assert_true(Gathering.is_ready(state.world, found[cell]["id"]), "and another may lie there then")


func test_a_visitor_is_someone_from_the_village_by_the_lamp() -> void:
	_all_lit(Lamps.REACH + 5)
	var rings := Lamps.rings(Routes.MAP, GameState.settlement, GameState.post, 10)
	var day := 0
	while Lamps.visitors(rings, day).is_empty():
		day += 1
	for npc: Dictionary in Lamps.visitors(rings, day):
		var place := String(npc["id"]).trim_prefix("lamp_visitor_")
		assert_eq(Vector2i(npc["x"], npc["y"]), Routes.lamp_of(place)["visit"], "%s stands by the %s lamp" % [npc["name"], place])
		assert_eq(npc["mapId"], Routes.MAP)
		assert_false(npc["wander"], "and stays there")
		assert_false((npc["lines"] as Array).is_empty(), "with something to say")
		assert_false(PunyArt.villager(String(npc["sprite"])).is_empty(), "drawn as themselves")
	for who: Dictionary in Routes._data()["visitors"]:
		assert_false(Npcs.by_id(String(who["npc"]), []).is_empty(), "%s lives in the data" % who["npc"])
		assert_eq(String(Npcs.by_id(String(who["npc"]), [])["mapId"]), "town", "%s is from the village" % who["npc"])
