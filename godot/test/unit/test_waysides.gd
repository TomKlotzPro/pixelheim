extends GutTest
## The Reach's wayside lanterns (PIX-397, step 4): one at each fork of the
## Post's roads but the gate's and one at the bridge, each beside its road
## and near its fork or the bridge; off the roads, portals, packs, chests,
## the story's spots, the cell under a signpost, and well off every
## waystation's ember lamp (they're not doubled); no way closed; lit at
## night alone, a light each.

const Hamlets := preload("res://test/unit/test_hamlet.gd")
const Farmlands := preload("res://test/unit/test_farmland.gd")


static func _map() -> MapData:
	return MapData.load_by_id(Waysides.MAP)


## Where each lantern belongs: its fork's signpost, or the bridge's north
## end.
static func _belongs(map: MapData, where: String) -> Vector2i:
	if where == "bridge":
		var ends := map.grid.keys().filter(func(cell: Vector2i) -> bool: return map.tile_at(cell) == "bridge" and map.tile_at(cell + Vector2i.UP) == "path")
		return ends[0] + Vector2i.UP
	return Routes.cell_of(Routes.fork(where)["at"])


func test_one_at_each_fork_but_the_gate_and_at_the_bridge() -> void:
	var map := _map()
	var lanterns := Waysides.plan_on(map, Hamlet.kept_on(map, {}))
	var expected := ["bridge"]
	for fork: Dictionary in Routes.forks():
		if fork["id"] != "gate":
			expected.append(fork["id"])
	expected.sort()
	var laid: Array = lanterns.keys()
	laid.sort()
	assert_eq(laid, expected, "every lantern laid where it belongs")
	for where: String in lanterns:
		var cell: Vector2i = lanterns[where]
		var beside := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT].any(func(step: Vector2i) -> bool: return map.tile_at(cell + step) == "path")
		assert_true(beside, "%s's lantern beside its road" % where)
		var near := _belongs(map, where)
		assert_lte(maxi(absi(cell.x - near.x), absi(cell.y - near.y)), 4, "%s's lantern by its fork or bridge (%s)" % [where, near])


func test_off_every_road_spot_signpost_and_ember_lamp() -> void:
	var map := _map()
	var kept := Hamlet.kept_on(map, {})
	var spots := Farmlands._spots(map)
	var lamps: Array[Vector2i] = []
	for place: String in Routes.places():
		var lamp := Routes.lamp_of(place)
		if not lamp.is_empty():
			lamps.append(lamp["cell"])
	assert_gt(lamps.size(), 3, "the waystations' lamps")
	var signposts: Array = Routes.forks().map(func(fork: Dictionary) -> Vector2i: return Routes.cell_of(fork["at"]))
	for where: String in Waysides.LANTERNS:
		var cell: Vector2i = Waysides.LANTERNS[where]
		var at := "%s's lantern at %s" % [where, cell]
		assert_does_not_have(Hamlet.WAYS, map.tile_at(cell), at + " off the road")
		assert_true(map.is_walkable(cell), at + " on open ground")
		assert_false(map.portals.has(cell), at + " off the portals")
		assert_false(kept.has(cell), at + " off the packs, chests and patches")
		assert_false(spots.has(cell), at + " off the story's spots")
		# Two cells tall: neither on a signpost nor standing under one.
		assert_false(cell in signposts or cell + Vector2i.UP in signposts, at + " clear of the signposts")
		for lamp: Vector2i in lamps:
			assert_gte(maxi(absi(cell.x - lamp.x), absi(cell.y - lamp.y)), Waysides.LAMP_APART, at + " well off the ember lamp at %s" % lamp)
		var gate := Routes.cell_of(Routes.fork("gate")["at"])
		assert_gt(maxi(absi(cell.x - gate.x), absi(cell.y - gate.y)), 4, at + " off the gate's corner, which the town lights")


func test_no_way_is_closed() -> void:
	var map := _map()
	var before := Hamlets._reach(map, map.spawn)
	var lanterns: Array = Waysides.plan_on(map, Hamlet.kept_on(map, {})).values()
	for cell: Vector2i in lanterns:
		map.covered[cell] = true
	var after := Hamlets._reach(map, map.spawn)
	for cell: Vector2i in before:
		if cell not in lanterns:
			assert_true(after.has(cell), "%s still reached from the spawn" % cell)


func test_lit_at_night_alone_a_light_each() -> void:
	var map := _map()
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	var lanterns: Dictionary = view.get_meta("waysides")
	assert_eq(lanterns.size(), Waysides.LANTERNS.size(), "every lantern stands")
	for cell: Vector2i in lanterns.values():
		assert_false(map.is_walkable(cell), "%s blocks its cell" % cell)
	view.set_night(false)
	assert_string_ends_with(Waysides.describe(view), " lit 0", "dark by day")
	view.set_night(true)
	assert_string_ends_with(Waysides.describe(view), " lit %d" % lanterns.size(), "lit at night")
	var lamps: Array = view.get_meta("wayside_lamps")
	for lamp: Dictionary in lamps:
		assert_true(lamp["glow"].has_meta("light"), "a light of its own")
	assert_eq(Waysides.plan_on(MapData.load_by_id("saltmere"), {}).size(), 0, "nothing off the Reach")
