extends GutTest
## The land heals round the lamps (PIX-323): each lit ember lamp's ring of
## green reaches a cell further into the ash each morning, up to
## Lamps.REACH, bare earth at its front and saplings nearest the lamp; only
## the ash heals; no night pack rises inside a ring and the Ash's air fades
## there, cell by cell; lamps close together share a light; and all of it
## comes from the day each lamp was lit, the one thing saved.

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
	assert_eq(Lamps.rings(Routes.MAP, state.settlement, state.post, 3), [{"cell": lamp, "mornings": 0}] as Array[Dictionary], "no ring yet")
	assert_eq(Lamps.rings(Routes.MAP, state.settlement, state.post, 5)[0]["mornings"], 2, "two mornings on")
	assert_true(Lamps.rings("saltmere", state.settlement, state.post, 5).is_empty(), "lamps burn on the Ashenreach only")
	var back := PostState.from_dict(SaveCodec.parse_json(JSON.stringify(state.post.to_dict())))
	assert_eq(back.lit, {"saltmere": 3}, "the day comes back from a save")
	# A lamp with no day kept has burnt long enough to be whole.
	state.post.lit.clear()
	assert_eq(Lamps.rings(Routes.MAP, state.settlement, state.post, 5)[0]["mornings"], Lamps.REACH)


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
