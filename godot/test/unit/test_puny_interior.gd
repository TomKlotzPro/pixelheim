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


func test_every_room_keeps_its_door_floor_and_walls() -> void:
	for name: String in ROOMS:
		var data := _room(name)
		var plan := PunyInterior.plan(data.id, data.grid)
		for cell: Vector2i in data.grid:
			var tile: String = data.grid[cell]
			if tile.begins_with("door"):
				assert_eq(plan["pieces"].get(cell), PunyInterior.DOOR, "%s door at %s" % [name, cell])
			elif tile == "wall":
				assert_true(plan["pieces"].has(cell) or plan["void"].has(cell), "%s wall at %s drawn or dark" % [name, cell])
			else:
				assert_true(plan["floor"].has(cell), "%s floor under %s" % [name, cell])


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
	var pieces: Dictionary = PunyInterior.plan("town_shop", grid)["pieces"]
	assert_eq(pieces[Vector2i(0, 0)], PunyInterior.WALLS[6], "top-left corner")
	assert_eq(pieces[Vector2i(4, 0)], PunyInterior.WALLS[12], "top-right corner")
	assert_eq(pieces[Vector2i(0, 1)], PunyInterior.WALLS[5], "a side wall")
	assert_eq(pieces[Vector2i(1, 3)], PunyInterior.WALLS[8], "the wall ends left of the door")
	assert_eq(pieces[Vector2i(3, 3)], PunyInterior.WALLS[2], "and starts again right of it")
	assert_eq(pieces[Vector2i(2, 3)], PunyInterior.DOOR)


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
