extends GutTest
## Pixelheim rebuilt by design (PIX-198): a village on a river bend under the
## mountain. These keep the plan honest: the gate road looks straight down to
## the hall, which faces the square; every door, villager, stall and corner
## worth finding can be walked to from the gate at every age; the square's
## boards and lanterns stand on it; the river is crossed only where the
## bridge does (the fishing dock that ran part way over it went, PIX-287);
## and each age stands more houses than the last, on ground nobody needs
## (PIX-382 step 3).

const AGES := [0, 1, 2, 3, 4]


## Every cell reachable on foot from the gate, the way MapView lays the town
## out at `tier` (houses, props and decor covering what they cover).
func _reach(tier: int) -> Array:
	var map := MapData.load_tiered("town", Town.projects_through(tier), 1)
	MapView.new(map, null).plan(map.spawn)
	# The gate road just inside the gate (PIX-248), where the Reach sets a
	# hero down.
	var gate := Vector2i(40, 3)
	var seen := {gate: true}
	var queue: Array[Vector2i] = [gate]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if seen.has(next):
				continue
			if map.is_walkable(next) or map.portals.has(next):
				seen[next] = true
				if not map.portals.has(next):
					queue.append(next)
	return [map, seen]


func test_the_gate_road_runs_straight_to_the_hall_on_the_square() -> void:
	var map := MapData.load_by_id("town")
	assert_eq(map.tile_at(Vector2i(40, 2)), "door", "the gate")
	for y in range(3, 12):
		assert_eq(map.tile_at(Vector2i(40, y)), "path", "the gate road at (40, %d)" % y)
	var hall := Vector2i(40, 19)
	assert_true(map.portals.has(hall), "the hall's door on the road's line")
	assert_eq(map.portals[hall]["mapId"], "town_hall")
	assert_eq(map.tile_at(hall + Vector2i.DOWN), "path", "and it opens onto the square")
	var square := Town.square()
	assert_eq(square.x, hall.x, "the square's heart below the hall's door")


func test_every_door_and_villager_can_be_walked_to_from_the_gate_at_every_age() -> void:
	for tier: int in AGES:
		var found := _reach(tier)
		var map: MapData = found[0]
		var seen: Dictionary = found[1]
		for cell: Vector2i in map.portals:
			assert_true(seen.has(cell), "age %d: the door at %s" % [tier, cell])
		for npc: Dictionary in Npcs.on_map("town", tier, [], Town.projects_through(tier)):
			var home := Vector2i(int(npc["x"]), int(npc["y"]))
			assert_true(seen.has(home), "age %d: %s at %s" % [tier, npc["id"], home])


func test_the_corners_worth_finding_can_be_reached() -> void:
	var seen: Dictionary = _reach(4)[1]
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["mapId"] == "town":
			var cell := Vector2i(int(chest["x"]), int(chest["y"]))
			var beside := [cell + Vector2i.LEFT, cell + Vector2i.RIGHT, cell + Vector2i.UP, cell + Vector2i.DOWN]
			assert_true(beside.any(func(c: Vector2i) -> bool: return seen.has(c)), "the chest %s" % chest["id"])
	assert_true(seen.has(Vector2i(40, 34)), "the green's end on the river bank")
	assert_true(seen.has(Vector2i(78, 21)), "the farms across the bridge")
	assert_true(seen.has(Vector2i(10, 6)) or seen.has(Vector2i(10, 7)), "the shrine yard")


func test_the_river_is_crossed_only_by_the_bridge() -> void:
	var map := MapData.load_by_id("town")
	var crossings := 0
	for y in map.size.y:
		var row := ""
		for x in range(64, 73):
			row += map.tile_at(Vector2i(x, y)).left(1)
		if "b" in row:
			crossings += 1
	assert_eq(crossings, 2, "the bridge is two cells wide, one crossing")
	for x in range(3, 66):
		var south: String = map.tile_at(Vector2i(x, 37))
		assert_eq(south, "water", "the bend at (%d, 37) keeps the far bank out of reach" % x)


func test_the_squares_boards_and_lanterns_stand_on_it() -> void:
	var square := Town.square()
	for spot: Vector2i in [Town.project_board(), Town.bounty_board()] + Town.lanterns():
		assert_lt(Vector2(spot).distance_to(Vector2(square)), 6.0, "%s by the square's heart" % spot)
		assert_eq(MapData.load_by_id("town").tile_at(spot), "path", "%s on the square's ground" % spot)
	assert_eq(Town.lanterns().size(), 5)


func test_every_building_faces_south() -> void:
	var map := MapData.load_by_id("town")
	for cell: Vector2i in map.portals:
		if map.portals[cell].get("mapId", "") == "overworld":
			continue
		assert_true(map.tile_at(cell + Vector2i.UP).begins_with("roof"), "%s has its house above it" % cell)
		assert_false(map.tile_at(cell + Vector2i.DOWN).begins_with("roof"), "%s opens onto open ground" % cell)


## Pixelheim grows with each age (PIX-382 step 3: the Town and the City
## stood the same thirteen houses): every age stands more houses than the
## one before and keeps every one of them.
func test_each_age_stands_more_houses_and_keeps_the_last() -> void:
	var before: Array = []
	for tier: int in AGES:
		var map := MapData.load_tiered("town", Town.projects_through(tier), 1)
		var rects := PunyTown.houses(map.grid).map(func(house: Dictionary) -> Rect2i: return house["rect"])
		assert_gt(rects.size(), before.size(), "age %d stands more houses than the one before" % tier)
		for rect: Rect2i in before:
			assert_has(rects, rect, "age %d keeps the house at %s" % [tier, rect])
		before = rects


## The houses an age raises stand once the whole age is built, never
## before, and on ground nobody needs: open ground off the roads, no
## door, portal or step, nothing a project builds or stakes, no house's
## neighbour (each its own), no villager's place or pacing nor a spot the
## story stands someone on (Yards.kept, Hamlet.kept_on), no animal's patch
## nor the yards' pieces; their doors shut, each onto open ground.
func test_the_houses_the_ages_raise_stand_clear_of_everything_in_use() -> void:
	var base := MapData.load_by_id("town")
	var built := {}
	for project_id: String in Town.projects_through(Town.MAX_TIER):
		for rect: Rect2i in Town.footprint(project_id):
			for cell in _cells(rect):
				built[cell] = project_id
	var pens := {}
	for entry: Dictionary in FarmAnimals.HERD:
		for cell in _cells(entry["pen"]):
			pens[cell] = true
	var laid := {}
	for entry: Dictionary in Yards.PIECES + Yards.hedges():
		for cell: Vector2i in Hamlet.cells_of(entry):
			laid[cell] = true
	var raised := 0
	for entry: Dictionary in Town.ages():
		var tier := int(entry["tier"])
		var done := Town.projects_through(tier)
		var map := MapData.load_tiered("town", done, 1)
		var kept := Hamlet.kept_on(map)
		kept.merge(Yards.kept(map))
		for house: Dictionary in entry.get("houses", []):
			raised += 1
			var corners: Array = house["rect"]
			var rect := Rect2i(int(corners[0]), int(corners[1]), int(corners[2]) - int(corners[0]) + 1, int(corners[3]) - int(corners[1]) + 1)
			var door := Vector2i(int(house["door"][0]), int(house["door"][1]))
			assert_eq(map.tile_at(door), "door_shut", "age %d: the house at %s stands once the age is built" % [tier, rect])
			assert_false(Town.age_houses(done.slice(0, done.size() - 1)).has(door), "age %d: %s waits for the age's last project" % [tier, rect])
			assert_eq(door.y, rect.end.y - 1, "age %d: %s's door on its bottom row, facing south" % [tier, rect])
			assert_false(map.portals.has(door), "age %d: %s's door leads nowhere" % [tier, rect])
			assert_true(map.is_walkable(door + Vector2i.DOWN), "age %d: %s's door opens onto open ground" % [tier, rect])
			for cell in _cells(rect.grow(1)):
				var tile := map.tile_at(cell)
				if not rect.has_point(cell):
					assert_false(tile.begins_with("roof") or tile.begins_with("door") or tile.begins_with("sign_"), "age %d: %s stands apart, not at %s" % [tier, rect, cell])
					continue
				assert_false(WorldTiles.is_walkable(tile), "age %d: %s blocks at %s" % [tier, rect, cell])
				var ground := base.tile_at(cell)
				assert_true(WorldTiles.is_walkable(ground) and ground not in Hamlet.WAYS, "age %d: %s on open ground, not %s at %s" % [tier, rect, ground, cell])
				assert_false(base.tile_at(cell + Vector2i.UP).begins_with("door") or base.portals.has(cell), "age %d: %s on no door nor its step (%s)" % [tier, rect, cell])
				assert_false(built.has(cell), "age %d: %s off %s (%s)" % [tier, rect, built.get(cell, ""), cell])
				assert_false(kept.has(cell), "age %d: %s keeps clear of the folk and the story's spots (%s)" % [tier, rect, cell])
				assert_false(pens.has(cell), "age %d: %s off the animals' patches (%s)" % [tier, rect, cell])
				assert_false(laid.has(cell), "age %d: %s off the yards' pieces (%s)" % [tier, rect, cell])
			# Its yard only clears the woods and the lawn in front of it.
			var yard: Array = house.get("yard", [0, 0, -1, -1])
			for cell in _cells(Rect2i(int(yard[0]), int(yard[1]), int(yard[2]) - int(yard[0]) + 1, int(yard[3]) - int(yard[1]) + 1)):
				assert_has(["grass", "forest", "flowers"], base.tile_at(cell), "age %d: %s's yard at %s" % [tier, rect, cell])
				assert_false(built.has(cell), "age %d: %s's yard off %s (%s)" % [tier, rect, built.get(cell, ""), cell])
	assert_gt(raised, 0, "the ages raise houses")


static func _cells(rect: Rect2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	return out
