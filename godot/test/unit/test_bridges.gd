extends GutTest
## Bridges cross the water (PIX-235, PIX-236). The web drew a bridge as one
## sprite whatever lay round it, so its maps laid spans along a river, out to
## an island and over a road; Shade's planks run the way PunyTerrain reads
## the span, over the river drawn beneath them. On every map, the village at
## every age: a bridge's planks run from walkable land to walkable land, with
## water off both its sides and none of its planks on dry ground, and the
## hero can walk onto it from the map's spawn. A dock is a pier: it runs out
## from a bank the hero can reach, into the sea. Out into a river it reads as
## a bridge left half built (PIX-287: Tom, « un demi pont au sud du
## village », the village's fishing dock two planks out into a river four
## wide, from the green and again from the Reach).

const SIDES := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]


## Every map on disk (the house's tiers are rooms), and the village as each
## age leaves it.
func _maps() -> Array[MapData]:
	var out: Array[MapData] = []
	for file: String in DirAccess.get_files_at("res://assets/maps"):
		if file.ends_with(".json") and file != "interactables.json":
			out.append(MapData.load_from("res://assets/maps/%s" % file))
	for tier in range(Town.MAX_TIER + 1):
		var town := MapData.load_tiered("town", Town.projects_through(tier), 1)
		town.id = "town@%d" % tier
		out.append(town)
	return out


## Every cell the hero can walk to from the map's spawn.
func _reachable(map: MapData) -> Dictionary:
	var seen := {map.spawn: true}
	var queue: Array[Vector2i] = [map.spawn]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in SIDES:
			var next := cell + step
			if not seen.has(next) and map.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return seen


## The spans of `tile` on a map, each the list of its cells.
func _spans(map: MapData, tile: String) -> Array:
	var out := []
	var seen := {}
	for cell: Vector2i in map.grid:
		if map.grid[cell] != tile or seen.has(cell):
			continue
		var span: Array[Vector2i] = []
		var queue: Array[Vector2i] = [cell]
		seen[cell] = true
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			span.append(at)
			for step: Vector2i in SIDES:
				if map.tile_at(at + step) == tile and not seen.has(at + step):
					seen[at + step] = true
					queue.append(at + step)
		out.append(span)
	return out


func _is_land(map: MapData, cell: Vector2i) -> bool:
	return map.is_walkable(cell) and not map.tile_at(cell) in PunyTerrain.SPANS


func _is_water(map: MapData, cell: Vector2i) -> bool:
	return map.tile_at(cell) in PunyTerrain.WATERS


func test_every_bridge_crosses_the_water_from_bank_to_bank() -> void:
	var bridges := 0
	for map: MapData in _maps():
		var reach := _reachable(map)
		for span: Array in _spans(map, "bridge"):
			bridges += 1
			var at: Vector2i = span[0]
			var axis := PunyTerrain.span_axis(map.grid, at)
			var side := Vector2i(axis.y, axis.x)
			var water_before := false
			var water_after := false
			for cell: Vector2i in span:
				assert_eq(PunyTerrain.span_axis(map.grid, cell), axis, "%s: the span at %s runs one way" % [map.id, at])
				for end: Vector2i in [PunyTerrain.span_end(map.grid, cell, -axis), PunyTerrain.span_end(map.grid, cell, axis)]:
					assert_true(_is_land(map, end), "%s: the bridge at %s lands on walkable ground at %s" % [map.id, cell, end])
				var before := _is_water(map, PunyTerrain.span_end(map.grid, cell, -side))
				var after := _is_water(map, PunyTerrain.span_end(map.grid, cell, side))
				assert_true(before or after, "%s: the bridge at %s has water beside it, not dry ground" % [map.id, cell])
				water_before = water_before or before
				water_after = water_after or after
			assert_true(water_before and water_after, "%s: the span at %s has water off both sides" % [map.id, at])
			assert_true(reach.has(at), "%s: the hero can walk onto the bridge at %s" % [map.id, at])
	assert_gt(bridges, 3, "the Reach has its bridges")


func test_every_dock_runs_out_from_a_bank_the_hero_reaches() -> void:
	var docks := 0
	for map: MapData in _maps():
		var reach := _reachable(map)
		for span: Array in _spans(map, "dock"):
			docks += 1
			var at: Vector2i = span[0]
			var axis := PunyTerrain.span_axis(map.grid, at)
			for cell: Vector2i in span:
				assert_eq(PunyTerrain.span_axis(map.grid, cell), axis, "%s: the dock at %s runs one way" % [map.id, at])
				var landed := [-axis, axis].any(func(step: Vector2i) -> bool: return _is_land(map, PunyTerrain.span_end(map.grid, cell, step)))
				assert_true(landed, "%s: the dock at %s runs out from the bank" % [map.id, cell])
				for step: Vector2i in SIDES:
					assert_ne(map.tile_at(cell + step), "water", "%s: the dock at %s stands in the sea, not part way over a river" % [map.id, cell])
			assert_true(reach.has(at), "%s: the hero can walk onto the dock at %s" % [map.id, at])
	assert_gt(docks, 0, "the coast has its jetty")


func test_the_mirefen_chests_can_be_walked_to() -> void:
	var map := MapData.load_by_id("mirefen")
	var reach := _reachable(map)
	for chest: Dictionary in Interactables.chests_on("mirefen"):
		var cell := Vector2i(int(chest["x"]), int(chest["y"]))
		assert_true(reach.has(cell), "%s, the maze's on its crossing" % chest["id"])
