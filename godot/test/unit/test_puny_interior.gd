extends GutTest
## PunyInterior furnishes the town's rooms in Shade's Medieval Age style
## (PIX-133). Pure tile ids, so checked without the paid pack: every room
## keeps its door, its walls drawn or dark, floor under everything, and
## furniture never shuts the way from the entrance to the door.

const ROOMS := [
	"town_inn", "town_shop", "town_smith", "town_alchemist", "town_hall",
	"town_house", "town_house@2", "town_house@3",
]


func _room(name: String) -> MapData:
	var data := MapData.load_from("res://assets/maps/%s.json" % name)
	return data


## Shade's wall tiles and the window: what a wall cell may be drawn as.
func _wall_tiles() -> Array:
	return PunyInterior.WALLS.values() + [PunyInterior.WINDOW]


func test_every_room_keeps_its_door_floor_and_walls() -> void:
	for name: String in ROOMS:
		var data := _room(name)
		var plan := PunyInterior.plan(data.id, data.grid)
		for cell: Vector2i in data.grid:
			var tile: String = data.grid[cell]
			if tile.begins_with("door"):
				assert_eq(plan["pieces"].get(cell), PunyInterior.DOOR, "%s door at %s" % [name, cell])
			elif tile == "wall":
				# A wall is drawn as a wall (whatever stands against it), or
				# dark beyond the room, or it is the ground furniture stands
				# on where it reaches into the wall line (PIX-237): never the
				# backdrop through a piece's open pixels.
				var drawn: bool = plan["walls"].get(cell, -1) in _wall_tiles()
				var under: bool = plan["floor"].has(cell) and plan["pieces"].has(cell)
				assert_true(drawn or under or plan["void"].has(cell), "%s wall at %s drawn or dark" % [name, cell])
			else:
				assert_true(plan["floor"].has(cell), "%s floor under %s" % [name, cell])


## The black squares around the smithy's forges (PIX-237): furniture
## reaching into the wall line stands on something. A part above its cell
## leans on a plain wall (a window would show through the forge's top), a
## part on the ground has floor under it, and no piece is drawn over
## another's (the Cottage's hearth hid its bed's foot).
func test_furniture_in_the_wall_line_stands_on_wall_or_floor() -> void:
	for name: String in ROOMS:
		var data := _room(name)
		var plan := PunyInterior.plan(data.id, data.grid)
		var walls: Dictionary = plan["walls"]
		var drawn := {}
		for cell: Vector2i in data.grid:
			var tile: String = data.grid[cell]
			if PunyInterior.RUNS.has(tile) or not PunyInterior.FURNITURE.has(tile):
				continue
			for part: Array in PunyInterior.FURNITURE[tile]:
				var at: Vector2i = cell + part[0]
				assert_false(drawn.has(at), "%s: the %s at %s is drawn over the %s" % [name, tile, cell, drawn.get(at, "")])
				drawn[at] = "%s at %s" % [tile, cell]
				assert_eq(plan["pieces"].get(at), part[1], "%s: the %s at %s drawn whole (%s)" % [name, tile, cell, at])
				if data.grid.get(at, "") != "wall":
					continue
				if part[0].y < 0:
					assert_true(walls.get(at, -1) in PunyInterior.WALLS.values(), "%s: a plain wall behind the %s's top at %s" % [name, tile, at])
				else:
					assert_true(plan["floor"].has(at) and not walls.has(at), "%s: floor under the %s at %s" % [name, tile, at])


## Every bed is a bed (PIX-237): its foot drawn, open, the bed's when E
## meets it (a rest; nothing placed there) and reachable from the door.
func test_every_bed_can_be_slept_in() -> void:
	for name: String in ROOMS:
		var data := _room(name)
		var plan := PunyInterior.plan(data.id, data.grid)
		var blocked := {}
		for cell: Vector2i in plan["blocked"]:
			blocked[cell] = true
		var seen := {data.spawn: true}
		var queue: Array[Vector2i] = [data.spawn]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_front()
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + step
				if not seen.has(next) and not blocked.has(next) and data.grid.get(next, "wall") == "floor":
					seen[next] = true
					queue.append(next)
		for cell: Vector2i in data.grid:
			if data.grid[cell] != "bed":
				continue
			var foot := cell + Vector2i.DOWN
			assert_eq(plan["pieces"].get(foot), 1482, "%s: the bed at %s has its foot" % [name, cell])
			assert_eq(plan["over"].get(foot), "bed", "%s: E at the foot of %s rests" % [name, cell])
			assert_true(seen.has(foot), "%s: the bed at %s can be reached" % [name, cell])


func test_furniture_never_shuts_the_way_out() -> void:
	for name: String in ROOMS:
		var data := _room(name)
		var plan := PunyInterior.plan(data.id, data.grid)
		var blocked := {}
		for cell: Vector2i in plan["blocked"]:
			blocked[cell] = true
		assert_false(blocked.has(data.spawn), "%s entrance stays open" % name)
		# Walk from the entrance over open floor: the door must be reachable.
		var seen := {data.spawn: true}
		var queue: Array[Vector2i] = [data.spawn]
		var door_reached := false
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_front()
			if String(data.grid.get(cell, "")).begins_with("door"):
				door_reached = true
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next := cell + step
				var tile: String = data.grid.get(next, "wall")
				if seen.has(next) or blocked.has(next) or not (tile == "floor" or tile.begins_with("door")):
					continue
				seen[next] = true
				queue.append(next)
		assert_true(door_reached, "%s door reachable from the entrance" % name)


func test_walls_follow_their_neighbours() -> void:
	# A bare 5x4 room: corners, straight runs, the door's wall ends.
	var rows := ["#####", "#___#", "#___#", "##D##"]
	var grid := {}
	for y in rows.size():
		for x in rows[y].length():
			grid[Vector2i(x, y)] = {"#": "wall", "_": "floor", "D": "door"}[rows[y][x]]
	var plan := PunyInterior.plan("town_shop", grid)
	var walls: Dictionary = plan["walls"]
	assert_eq(walls[Vector2i(0, 0)], PunyInterior.WALLS[6], "top-left corner")
	assert_eq(walls[Vector2i(4, 0)], PunyInterior.WALLS[12], "top-right corner")
	assert_eq(walls[Vector2i(0, 1)], PunyInterior.WALLS[5], "a side wall")
	assert_eq(walls[Vector2i(1, 3)], PunyInterior.WALLS[8], "the wall ends left of the door")
	assert_eq(walls[Vector2i(3, 3)], PunyInterior.WALLS[2], "and starts again right of it")
	assert_eq(plan["pieces"][Vector2i(2, 3)], PunyInterior.DOOR)


func test_the_inn_wakes_its_guests_in_an_open_bed() -> void:
	var data := _room("town_inn")
	var plan := PunyInterior.plan(data.id, data.grid)
	var rest: Dictionary = Catalog._data()["innRest"]
	var bed_foot := Vector2i(int(rest["x"]), int(rest["y"]))
	assert_false(plan["blocked"].has(bed_foot), "where defeat wakes the hero stays walkable")
	assert_eq(plan["pieces"].get(bed_foot), 1482, "and it is the bed's foot")


func test_every_piece_of_furniture_has_shades_art() -> void:
	for id: String in Catalog._data()["items"]:
		if Catalog.item(id).get("category", "") == "furniture":
			assert_true(PunyInterior.PLACED.has(id), "%s needs a PunyInterior.PLACED entry" % id)
