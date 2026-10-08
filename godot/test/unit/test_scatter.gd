extends GutTest
## Field decor that blocks (PIX-137): bushes, stumps and marsh trees stand in
## the way only where they can never close one. Checked on every outdoor map
## as the world builds it (houses, then props): whatever the hero could reach
## from the map's spawn, they still can, bar the decor's own cells.

const MAPS := ["town", "town@2", "town@3", "town@4", "overworld", "deepwood", "mirefen"]


## The map as world.gd enters it: houses block and free their cells, props
## cover theirs.
func _as_entered(id: String) -> MapData:
	var data := _load(id)
	var houses := PunyTown.plan(data.grid) if id.begins_with("town") else {"pieces": {}, "freed": []}
	for cell: Vector2i in houses["pieces"]:
		if not String(data.grid[cell]).begins_with("door"):
			data.grid[cell] = "roof"
	for cell: Vector2i in houses["freed"]:
		data.grid[cell] = "grass"
	for prop: Dictionary in PunyProps.plan(data.grid)["props"]:
		if (prop["foot"] as Rect2).has_area():
			for cell: Vector2i in prop["covers"]:
				data.covered[cell] = true
	return data


func _reachable(data: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if not seen.has(next) and data.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return seen


func test_field_decor_never_cuts_a_way_off() -> void:
	var total := 0
	for id: String in MAPS:
		var data := _as_entered(id)
		var before := _reachable(data, data.spawn)
		var solid := Scatter.solid(data, {data.spawn: true}, {})
		total += solid.size()
		for cell: Vector2i in solid:
			data.covered[cell] = true
		var after := _reachable(data, data.spawn)
		var lost := before.keys().filter(func(cell: Vector2i) -> bool: return not after.has(cell) and not solid.has(cell))
		assert_eq(lost, [], "%s: cut off by decor" % id)
	assert_gt(total, 20, "the fields do grow some")


func test_only_field_decor_blocks_and_never_where_kept() -> void:
	var data := _as_entered("overworld")
	var everything := Scatter.solid(data, {}, {})
	var some: Vector2i = everything.keys()[0]
	assert_false(Scatter.solid(data, {some: true}, {}).has(some), "a kept cell (an arrival, a home, a chest)")
	for cell: Vector2i in everything:
		assert_true(data.grid[cell] in Scatter.FIELDS)
		assert_true(everything[cell] in Scatter.SOLID)


func test_a_solid_foot_covers_the_middle_of_its_cell() -> void:
	assert_true(Scatter.FOOT.encloses(Rect2(4, 7, 8, 8)), "the hero's position never enters a blocked cell")


## A town as grown through an age ("town@3"), or any other map by id.
func _load(id: String) -> MapData:
	if id.begins_with("town@"):
		return MapData.load_tiered("town", Town.projects_through(int(id.get_slice("@", 1))), 1)
	return MapData.load_by_id(id)
