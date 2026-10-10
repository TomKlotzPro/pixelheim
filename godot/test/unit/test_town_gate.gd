extends GutTest
## Pixelheim's rampart and its gate (PIX-248, Tom: "double rempart ça fait
## bizarre à l'intérieur du village et l'entrée est pas claire ni la
## sortie"): one wall round the village, not two; its gate three wide like
## the Reach's passes, between two towers, torches either side, the road
## running on through it; the same gatehouse in town and on the village
## seen small from the Reach; scorched while the ruins stand; the ways
## through it land on the open road facing away from it; and a save from
## before wakes inside the walls. Pure: none of it needs the paid art.

const GATE := [Vector2i(39, 2), Vector2i(40, 2), Vector2i(41, 2)]
const REACH_GATE := [Vector2i(47, 42), Vector2i(48, 42), Vector2i(49, 42)]
const INSIDE := Vector2i(40, 3)
const OUTSIDE := Vector2i(48, 41)
const AGES := [0, 1, 2, 3, 4]


func _town(age := 1) -> MapData:
	return MapData.load_tiered("town", Town.projects_through(age), 1)


func _planned(map: MapData) -> MapData:
	MapView.new(map, null).plan(map.spawn)
	return map


func _wall(map: MapData, cell: Vector2i) -> bool:
	return map.tile_at(cell) in PunyTerrain.RAMPART


func test_one_wall_round_the_town_not_two() -> void:
	var map := MapData.load_by_id("town")
	# A wall two deep is four cells of it in a square somewhere; one wall,
	# even round its corners, never is.
	for cell: Vector2i in map.grid:
		var square := [cell, cell + Vector2i.RIGHT, cell + Vector2i.DOWN, cell + Vector2i.ONE]
		assert_false(square.all(func(c: Vector2i) -> bool: return _wall(map, c)), "one wall at %s, not a band" % cell)
	for x in map.size.x:
		for y in [0, 1]:
			assert_false(_wall(map, Vector2i(x, y)), "the fields outside at (%d, %d)" % [x, y])
		var top := Vector2i(x, 2)
		if x == 0 or x == map.size.x - 1:
			assert_false(_wall(map, top), "a field past the corner at %s" % top)
		elif top in GATE:
			assert_eq(map.tile_at(top), "door", "the gate at %s" % top)
		elif map.tile_at(top) != "water":
			assert_eq(map.tile_at(top), "wall", "the north wall at %s" % top)
	for y in range(3, map.size.y):
		assert_false(_wall(map, Vector2i(0, y)), "a field west of the wall")
		assert_false(_wall(map, Vector2i(map.size.x - 1, y)), "and east of it")
		assert_eq(map.tile_at(Vector2i(1, y)), "wall", "the west wall")
		assert_eq(map.tile_at(Vector2i(map.size.x - 2, y)), "wall", "the east wall")
	for x in range(1, map.size.x - 1):
		assert_eq(map.tile_at(Vector2i(x, map.size.y - 1)), "wall", "the south wall")
	assert_eq(map.tile_at(Vector2i(67, 2)), "water", "the river runs in under the north wall")


func test_the_gate_is_three_wide_on_both_sides() -> void:
	var town := MapData.load_by_id("town")
	var overworld := MapData.load_by_id("overworld")
	for cell: Vector2i in GATE:
		assert_eq(town.tile_at(cell), "door")
		assert_eq(_lands(town.portals[cell]), ["overworld", OUTSIDE], "%s leads out" % cell)
	for cell: Vector2i in REACH_GATE:
		assert_eq(overworld.tile_at(cell), "door")
		assert_eq(_lands(overworld.portals[cell]), ["town", INSIDE], "%s leads in" % cell)
	var gates := Rampart.gates(town.grid)
	assert_eq(gates.size(), 1, "one gate in the town's wall")
	assert_eq(str(gates[0]["cells"]), str(GATE))
	assert_eq(gates[0]["towers"], [Vector2i(38, 2), Vector2i(42, 2)], "between two towers")
	for map: MapData in [town, overworld]:
		var through: Array = Ways.on(map).filter(func(way: Dictionary) -> bool: return way["to"].get("mapId", "") in ["town", "overworld"])
		assert_eq(through.size(), 1, "%s: one way through the gate" % map.id)
		assert_eq(through[0]["kind"], "gate", "%s: a gate in the rampart" % map.id)
		assert_eq(through[0]["cells"].size(), 3, "%s: three wide" % map.id)
	assert_eq(Ways.on(town).filter(func(way: Dictionary) -> bool: return way["kind"] == "gate")[0]["out"], Vector2i.UP, "out of town up the road")


## Where a portal sets the hero down: [map, cell].
func _lands(target: Dictionary) -> Array:
	return [String(target.get("mapId", "")), Vector2i(int(target["x"]), int(target["y"]))]


func test_the_ways_through_land_on_the_open_road_facing_away() -> void:
	for age: int in AGES:
		var town := _planned(_town(age))
		assert_eq(town.tile_at(INSIDE), "path", "age %d: on the gate road" % age)
		assert_true(Ways.open_ground(town, INSIDE), "age %d: open ground just inside the gate" % age)
		assert_eq(Ways.arrival_facing(town, INSIDE, "overworld", Vector2.UP), Vector2.DOWN, "age %d: facing into town, away from the gate" % age)
	var overworld := _planned(MapData.load_by_id("overworld"))
	assert_eq(overworld.tile_at(OUTSIDE), "path", "on the Reach's road")
	assert_true(Ways.open_ground(overworld, OUTSIDE), "open ground just outside the gate")
	assert_eq(Ways.arrival_facing(overworld, OUTSIDE, "town", Vector2.DOWN), Vector2.UP, "facing up the road, away from the gate")


func test_the_road_runs_on_through_the_gate() -> void:
	var town := MapData.load_by_id("town")
	for x in range(39, 42):
		for y in [0, 1, 3, 4]:
			assert_eq(town.tile_at(Vector2i(x, y)), "path", "the road at (%d, %d)" % [x, y])
		assert_eq(PunyTerrain.ground_at(town.grid, Vector2i(x, 2)), "dirt", "the gate stands on the road")
	var overworld := MapData.load_by_id("overworld")
	for x in range(47, 50):
		for y in range(34, 42):
			assert_eq(overworld.tile_at(Vector2i(x, y)), "path", "the Reach's road straight to the gate at (%d, %d)" % [x, y])
		assert_eq(PunyTerrain.ground_at(overworld.grid, Vector2i(x, 42)), "dirt")
	assert_eq(PunyTerrain.ground_at(town.grid, Vector2i(30, 10)), "grass", "a house's door is no gate")


func test_a_torch_either_side_lit_at_night() -> void:
	for spot: Array in [["town", [Vector2i(38, 3), Vector2i(42, 3)]], ["overworld", [Vector2i(45, 41), Vector2i(51, 41)]]]:
		var map := MapData.load_by_id(spot[0])
		var lamps: Array = PunyProps.plan(map.grid)["props"].filter(func(prop: Dictionary) -> bool: return prop["kind"] == "lamp").map(func(prop: Dictionary) -> Vector2i: return prop["cell"])
		for cell: Vector2i in spot[1]:
			assert_eq(map.tile_at(cell), "lamp", "%s: a torch at %s" % spot)
			assert_has(lamps, cell, "%s: one of the lamps that light at night" % spot[0])


func test_the_same_gatehouse_in_town_and_from_the_reach() -> void:
	for ashen: bool in [false, true]:
		var inside := _gatehouse(Rampart.plan(MapData.load_by_id("town").grid, ashen))
		var done := Town.projects_through(0 if ashen else 1)
		var ruins: Array = Town.ruins(done).map(func(ruin: Dictionary) -> Rect2i: return ruin["rect"])
		var ring: Dictionary = Skyline.plan(MapData.load_by_id("overworld").grid, _town(0 if ashen else 1), ruins)["rampart"]
		assert_eq(_gatehouse(ring), inside, "the same towers, roofs and gate (ashen: %s)" % ashen)
		assert_false(inside.is_empty())


## A plan's gatehouse, by cell from the gate's middle: its pieces, with or
## without the pack, and what the fire left darker.
func _gatehouse(plan: Dictionary) -> Dictionary:
	var out := {}
	var gate: Dictionary = plan["gates"][0]
	var middle: Vector2i = gate["cells"][gate["cells"].size() / 2]
	var cells: Array = []
	for part: String in ["cells", "towers", "tops"]:
		cells.append_array(gate[part])
	for cell: Vector2i in cells:
		out[cell - middle] = [plan["pieces"][cell], plan["fallback"][cell], plan["scorched"].has(cell)]
	return out


func test_ulla_keeps_the_gate_beside_it_not_in_it() -> void:
	# Once she's come home (PIX-255), at every age: on open ground just
	# inside the gate, off its towers, its torches and the road through it.
	var home: Dictionary = Npcs.by_id("greyhold_ulla", ["greyhold_ulla"])
	var cell := Vector2i(int(home["x"]), int(home["y"]))
	assert_eq(home["mapId"], "town")
	for age: int in AGES:
		var town := _planned(_town(age))
		var plan := Rampart.plan(town.grid)
		assert_true(town.is_walkable(cell), "age %d: Ulla at %s on open ground" % [age, cell])
		assert_false(town.portals.has(cell), "age %d: not in the gate" % age)
		assert_false(plan["pieces"].has(cell), "age %d: not in the wall or a tower" % age)
		assert_ne(town.tile_at(cell), "path", "age %d: off the road through it" % age)
		assert_lte(Vector2(cell).distance_to(Vector2(GATE[1])), 3.5, "age %d: beside the gate" % age)
		assert_true(Ways._walked_from(town, town.spawn).has(cell), "age %d: a walk reaches her" % age)


func test_the_towers_tops_block_where_they_stand() -> void:
	var town := _planned(_town())
	for cell: Vector2i in [Vector2i(38, 1), Vector2i(42, 1)]:
		assert_true(town.covered.has(cell), "the town's towers above the wall at %s" % cell)
	var overworld := _planned(MapData.load_by_id("overworld"))
	for cell: Vector2i in [Vector2i(46, 41), Vector2i(50, 41)]:
		assert_true(overworld.covered.has(cell), "the Reach's towers above the wall at %s" % cell)
	for x in range(47, 50):
		assert_true(overworld.is_walkable(Vector2i(x, 41)), "the road to the gate stays open")


func test_the_gate_after_the_fire_and_mended() -> void:
	for age: int in AGES:
		var done := Town.projects_through(age)
		var map := _town(age)
		var ashen := Rampart.ashen(done)
		assert_eq(ashen, age == 0, "age %d" % age)
		var plan := Rampart.plan(map.grid, ashen)
		for cell: Vector2i in GATE:
			assert_true(map.portals.has(cell), "age %d: the gate opens" % age)
			assert_eq(plan["pieces"][cell], Rampart.GATE, "age %d: its portcullis up" % age)
		if age == 0:
			assert_eq(plan["pieces"][Vector2i(38, 1)], Rampart.ROOF_BURNT, "the west tower's roof burnt off")
			assert_eq(plan["pieces"][Vector2i(42, 1)], Rampart.ROOF[1], "the east tower's still on")
			for cell: Vector2i in GATE + [Vector2i(38, 1), Vector2i(42, 1)]:
				assert_true(plan["scorched"].has(cell), "scorched at %s" % cell)
			assert_false(plan["scorched"].has(Vector2i(38, 2)), "its stone stood")
		else:
			assert_eq(plan["pieces"][Vector2i(38, 1)], Rampart.ROOF[0], "age %d: mended" % age)
			assert_true(plan["scorched"].is_empty(), "age %d: nothing burnt" % age)


func test_the_wall_is_one_piece_a_cell() -> void:
	var plan := Rampart.plan(MapData.load_by_id("town").grid)
	assert_eq(plan["pieces"][Vector2i(1, 2)], Rampart.WALL[6], "the north-west corner")
	assert_eq(plan["pieces"][Vector2i(82, 2)], Rampart.WALL[12], "the north-east corner")
	assert_eq(plan["pieces"][Vector2i(1, 43)], Rampart.WALL[3], "the south-west corner")
	assert_eq(plan["pieces"][Vector2i(20, 2)], Rampart.WALL[10], "a run across, its face to the south")
	assert_eq(plan["pieces"][Vector2i(1, 20)], Rampart.WALL[5], "a run down")
	assert_eq(plan["pieces"][Vector2i(66, 2)], Rampart.WALL[8], "ending at the river")
	assert_eq(plan["pieces"][Vector2i(71, 2)], Rampart.WALL[2], "and on past it")
	for cell: Vector2i in plan["fallback"]:
		assert_true(plan["pieces"].has(cell), "without the pack, the same cells drawn (%s)" % cell)


func test_a_save_from_before_wakes_inside_the_walls() -> void:
	var town := _town()
	assert_eq(Ways.standing(town, Vector2i(40, 1)), INSIDE, "in the old slot through the double wall: on the gate road")
	assert_eq(Ways.standing(town, Vector2i(40, 0)), INSIDE, "in the old gate")
	assert_eq(Ways.standing(town, Vector2i(40, 2)), INSIDE, "in the gate: just inside it")
	assert_eq(Ways.standing(town, Vector2i(20, 2)), Vector2i(20, 3), "where the wall stands now: beside it")
	assert_eq(Ways.standing(town, Vector2i(40, 30)), Vector2i(40, 30), "on the square, where it stood")
	for outside: Vector2i in [Vector2i(25, 0), Vector2i(0, 20), Vector2i(83, 20)]:
		var woke := Ways.standing(town, outside)
		assert_true(Rect2i(2, 3, 80, 40).has_point(woke), "out in the fields at %s: inside the walls (%s)" % [outside, woke])
		assert_true(Ways.open_ground(town, woke), "on open ground (%s)" % woke)
	var overworld := MapData.load_by_id("overworld")
	assert_eq(Ways.standing(overworld, Vector2i(47, 42)), Vector2i(47, 41), "in the Reach's gate: on the road before it")
	assert_eq(Ways.standing(overworld, OUTSIDE), OUTSIDE, "on the road, where it stood")
