extends GutTest
## Torches hang on the walls (PIX-291, Tom: « Pas super beau les torches dans
## le donjon »). A torch's cell counted as open ground to the walls' grammar,
## so the wall over it showed its face and the walls beside it their ends,
## and on a planned floor it stood on the room's top row: a torch in a
## square box cut into the wall. Now the wall runs on through it, its cuff on
## the face and its flame over the top, on every floor of every dungeon,
## handcrafted and planned, the Kings' Vault's too.

const FACES := [PunyDungeon.FACE[0], PunyDungeon.FACE[1], PunyDungeon.FACE[2], PunyDungeon.FACE[3], PunyDungeon.COLUMN_FOOT]


## Every floor of every dungeon, laid as a visit lays it.
func _floors() -> Array[MapData]:
	var out: Array[MapData] = []
	for dungeon_id: String in Depths.dungeons():
		for entry: Dictionary in Depths.floors(dungeon_id):
			out.append(MapData.load_by_id(entry["mapId"]))
	return out


func _torches(map: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in map.grid:
		if map.grid[cell] == "lamp":
			out.append(cell)
	return out


func test_every_dungeon_floor_has_torches() -> void:
	var floors := _floors()
	assert_gt(floors.size(), 12, "the region dungeons' floors and the Vault's")
	for map: MapData in floors:
		assert_gt(_torches(map).size(), 0, "%s is lit" % map.id)


func test_every_torch_hangs_on_a_wall_s_face() -> void:
	for map: MapData in _floors():
		for cell: Vector2i in _torches(map):
			assert_true(PunyDungeon.on_face(map.grid, cell), "%s: the torch at %s has wall over it and ground before it" % [map.id, cell])
			assert_has(FACES, PunyDungeon.wall_tile(map.grid, cell), "%s: the torch at %s is on a wall's face" % [map.id, cell])


func test_the_wall_runs_on_through_a_torch() -> void:
	# The walls round a torch draw as they would with plain wall there: no
	# face over it, no ends either side of it.
	for map: MapData in _floors():
		var walled := map.grid.duplicate()
		for cell: Vector2i in _torches(map):
			walled[cell] = "wall"
		for cell: Vector2i in _torches(map):
			assert_eq(PunyDungeon.wall_tile(map.grid, cell), PunyDungeon.wall_tile(walled, cell), "%s: the torch at %s is the wall's own piece" % [map.id, cell])
			for step: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i(-1, -1), Vector2i(1, -1)]:
				var next := cell + step
				if map.grid.get(next, "wall") == "wall":
					assert_eq(PunyDungeon.wall_tile(map.grid, next), PunyDungeon.wall_tile(walled, next), "%s: the wall at %s beside the torch at %s" % [map.id, next, cell])


func test_a_planned_floor_hangs_its_torches_over_its_rooms() -> void:
	for map_id: String in ["seacave_galleries", "shafts_gallery", "cellars_crypt", "vault_1", "vault_3", "vault_5"]:
		var plan := Depths.plan(map_id)
		var map: MapData = plan["map"]
		var hung := 0
		for room: Rect2i in plan["rooms"]:
			for x in range(room.position.x, room.end.x):
				# Nothing stands on a room's top row but what the room holds.
				assert_ne(map.grid[Vector2i(x, room.position.y)], "lamp", "%s: no torch on the floor of the room at %s" % [map_id, room])
				if map.grid[Vector2i(x, room.position.y - 1)] == "lamp":
					hung += 1
		assert_eq(hung, plan["rooms"].size() * 2, "%s: two torches over each room, in its north wall" % map_id)


func test_a_dungeon_floor_draws_every_torch_on_the_wall() -> void:
	for map_id: String in ["shafts", "vault_1"]:
		var map := MapData.load_by_id(map_id)
		var root := Node2D.new()
		add_child_autofree(root)
		var actors := Node2D.new()
		root.add_child(actors)
		var view := MapView.new(map, actors)
		view.plan(map.spawn)
		view.build(root)
		assert_eq(view.wall_torches.size(), _torches(map).size(), "%s: a torch drawn for each" % map_id)
		var glows := root.find_children("*", "Sprite2D", true, false).filter(func(node: Node) -> bool: return node.material == Lights.glow())
		assert_eq(glows.size(), view.wall_torches.size(), "%s: each torch glowing softly on its wall" % map_id)
