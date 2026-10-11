extends GutTest
## Each dungeon looks like its place (PIX-310, the audit: « five dungeons,
## one brick look »): the sea cave wet rock round pools of the sea, the
## Blackiron shafts timbered with a rail line through them and carts on it,
## the Greyhold cellars a crypt with its niches and cobwebs, the ice cave
## frosted, the Kings' Vault a treasury with its rugs and banners; and the
## planned floors no longer all open in the same room. None of it changes a
## map: what lies flat lies on open floor off the ways, what hangs hangs on
## a wall's face, never a torch, and what is swapped already blocked.

const PLANNED := ["seacave_galleries", "shafts_gallery", "cellars_crypt", "vault_1", "vault_2", "vault_3", "vault_4", "vault_5"]
## Each planned floor's cells east of its entrance room's wall, as they
## were laid before the entrance took a shape of its own (an md5): the
## rooms, halls, packs and finds beyond it never moved.
const BEYOND := {
	"seacave_galleries": "7df420be8b3aa4d1c23df9408d10cb3f", "shafts_gallery": "24b2ec95559c424b464e632c843b5e02",
	"cellars_crypt": "30e8fed14c7ecfbca7b477607362b99b", "vault_1": "f44a0206cc62d0be5a21dbf57fc3e20a",
	"vault_2": "facfdb31ccb86e1857986e3333781bbc", "vault_3": "f4396f9b0819473115aa0be59ef139dd",
	"vault_4": "630dd25d224bffe69c69471bc8f53444", "vault_5": "7f147c3d467ec7ca19517696fc60e008",
}


## Every floor of every dungeon, laid as a visit lays it.
func _floors() -> Array[MapData]:
	var out: Array[MapData] = []
	for dungeon_id: String in Depths.dungeons():
		for entry: Dictionary in Depths.floors(dungeon_id):
			out.append(MapData.load_by_id(entry["mapId"]))
	return out


## Everything a dungeon's floors are dressed in, counted, with the pack or
## without it.
func _counts(dungeon_id: String, paid: bool) -> Dictionary:
	var out := {}
	for entry: Dictionary in Depths.floors(dungeon_id):
		var counts: Dictionary = DungeonLook.plan(MapData.load_by_id(entry["mapId"]), paid)["counts"]
		for kind: String in counts:
			out[kind] = int(out.get(kind, 0)) + int(counts[kind])
	return out


func test_each_dungeon_has_a_look_of_its_own() -> void:
	var looks := {}
	for dungeon_id: String in Depths.dungeons():
		var look := String(DungeonLook.LOOKS.get(dungeon_id, ""))
		assert_ne(look, "", "%s has a look" % dungeon_id)
		assert_false(looks.has(look), "%s's look is its own" % dungeon_id)
		looks[look] = true
		assert_true(DungeonLook.SHADER.has(look), "the stone's shader knows %s" % look)
		for entry: Dictionary in Depths.floors(dungeon_id):
			assert_eq(DungeonLook.of(entry["mapId"]), look, "%s is dressed as its dungeon" % entry["mapId"])
	for map_id: String in ["town", "overworld", "saltmere", "town_inn", "mountain_road"]:
		assert_eq(DungeonLook.of(map_id), "", "%s is no dungeon" % map_id)


func test_each_look_draws_what_its_place_has() -> void:
	for paid: bool in [true, false]:
		var sea := _counts("seacave", paid)
		assert_gt(int(sea.get("water", 0)), 20, "the sea cave has pools of the sea (paid %s)" % paid)
		assert_gt(int(sea.get("weed", 0)), 20, "and weed at its walls' feet")
		var mine := _counts("shafts", paid)
		assert_gt(int(mine.get("rail", 0)), 100, "the shafts have a rail line through every floor (paid %s)" % paid)
		assert_gt(int(mine.get("props", 0)), 10, "and timber props along their walls")
		assert_gt(int(mine.get("ore", 0)), 0, "and ore heaped")
		var crypt := _counts("cellars", paid)
		assert_gt(int(crypt.get("niches", 0)), 10, "the cellars have niches in their walls (paid %s)" % paid)
		assert_gt(int(crypt.get("webs", 0)), 5, "and cobwebs in their corners")
		assert_gt(int(crypt.get("bones", 0)), 5, "and bones by their walls")
		var vault := _counts("vault", paid)
		assert_gt(int(vault.get("rugs", 0)), 15, "the Vault has a rug in its rooms (paid %s)" % paid)
		assert_gt(int(vault.get("banners", 0)), 15, "and the kings' banners on its walls")
	assert_gt(int(_counts("shafts", true).get("carts", 0)), 2, "with the pack, ore carts")


func test_every_floor_has_its_rail_line_unbroken_from_the_way_in_to_the_way_on() -> void:
	for entry: Dictionary in Depths.floors("shafts"):
		var map := MapData.load_by_id(entry["mapId"])
		var plan := DungeonLook.plan(map, false)
		var line := DungeonLook.rail_line(map, DungeonLook._kept_clear(map))
		assert_gt(line.size(), 20, "%s has a line" % map.id)
		assert_eq(line[0], map.spawn, "%s's line starts where a hero comes in" % map.id)
		assert_eq(line[-1], DungeonLook._way_on(map), "%s's line runs to the way on" % map.id)
		for i in line.size():
			if i > 0:
				assert_eq((line[i] - line[i - 1]).length_squared(), 1, "%s: the line runs cell to cell at %s" % [map.id, line[i]])
			var ways := 0
			for other: int in [i - 1, i + 1]:
				if other >= 0 and other < line.size():
					ways |= DungeonLook._way_bit(line[other] - line[i])
			assert_eq(plan["flats"][line[i]]["tile"], DungeonArt.rail(ways), "%s: the rail at %s joins its neighbours" % [map.id, line[i]])


func test_dressing_a_floor_leaves_its_map_as_it_was() -> void:
	for map: MapData in _floors():
		var grid := map.grid.duplicate()
		var portals := map.portals.duplicate(true)
		var covered := map.covered.duplicate()
		for paid: bool in [true, false]:
			DungeonLook.plan(map, paid)
		assert_eq(map.grid, grid, "%s's cells" % map.id)
		assert_eq(map.portals, portals, "%s's ways" % map.id)
		assert_eq(map.covered, covered, "%s's blockers" % map.id)


func test_what_lies_flat_lies_on_open_floor_off_the_ways() -> void:
	for map: MapData in _floors():
		var chests := Interactables.chests_on(map.id).map(func(chest: Dictionary) -> Vector2i: return Vector2i(int(chest["x"]), int(chest["y"])))
		for paid: bool in [true, false]:
			var plan := DungeonLook.plan(map, paid)
			for kind: String in ["flats", "water"]:
				for cell: Vector2i in plan[kind]:
					assert_false(PunyDungeon._solid(map.grid, cell), "%s: %s at %s on the floor, not a wall" % [map.id, kind, cell])
					assert_false(map.portals.has(cell) or map.grid[cell] in DungeonLook.WAYS_OUT, "%s: nothing on the way at %s" % [map.id, cell])
					# A rug lies under what stands on it (a chest, the hoard,
					# a hero coming in); the rails run from the stair's foot.
					var piece := String(plan[kind][cell].get("kind", "")) if kind == "flats" else ""
					if piece == "rug":
						continue
					assert_eq(map.grid[cell], "floor", "%s: %s at %s on open floor" % [map.id, kind, cell])
					assert_true(map.is_walkable(cell), "%s: %s at %s walked over" % [map.id, kind, cell])
					assert_false(map.pieces.has(cell) or map.notes.has(cell), "%s: nor under the set piece at %s" % [map.id, cell])
					assert_false(cell in chests, "%s: nor under a chest at %s" % [map.id, cell])
					if piece != "rail":
						assert_ne(cell, map.spawn, "%s: nor where a hero comes in" % map.id)


func test_what_hangs_hangs_on_a_walls_face_never_a_torch() -> void:
	for map: MapData in _floors():
		for cell: Vector2i in DungeonLook.plan(map, true)["faces"]:
			assert_eq(map.grid[cell], "wall", "%s: hung on a wall at %s, not a torch" % [map.id, cell])
			assert_true(PunyDungeon.on_face(map.grid, cell), "%s: on the wall's face at %s" % [map.id, cell])


func test_what_is_drawn_as_something_else_already_blocked() -> void:
	for map: MapData in _floors():
		for paid: bool in [true, false]:
			for cell: Vector2i in DungeonLook.plan(map, paid)["swaps"]:
				assert_has(["barrel", "crate"], map.grid[cell], "%s: a barrel or a pot at %s" % [map.id, cell])
				assert_false(map.is_walkable(cell), "%s: %s blocked already" % [map.id, cell])


func test_without_the_pack_it_keeps_to_shades_cc0_sheet_and_our_own() -> void:
	for map: MapData in _floors():
		var plan := DungeonLook.plan(map, false)
		assert_eq(plan["floors"], {}, "%s: Shade's dungeon floor" % map.id)
		for kind: String in ["flats", "faces", "swaps"]:
			for cell: Vector2i in plan[kind]:
				assert_ne(plan[kind][cell]["sheet"], "props", "%s: no Medieval Age %s at %s" % [map.id, kind, cell])


func test_with_the_pack_each_look_lays_its_own_ground() -> void:
	for dungeon_id: String in Depths.dungeons():
		var map := MapData.load_by_id(Depths.floors(dungeon_id)[0]["mapId"])
		var floors: Dictionary = DungeonLook.plan(map, true)["floors"]
		for cell: Vector2i in map.grid:
			assert_eq(floors.has(cell), not PunyDungeon._solid(map.grid, cell), "%s: the floor laid under every open cell, %s" % [map.id, cell])
	var firsts := DungeonLook.FLOORS.values().map(func(block: Array) -> int: return int(block[0]))
	for i in firsts.size():
		for j in range(i + 1, firsts.size()):
			assert_ne(firsts[i], firsts[j], "each look's ground is its own")


func test_the_dressing_is_the_same_every_visit() -> void:
	for map_id: String in ["seacave", "shafts_gallery", "cellars_crypt", "icecave", "vault_3"]:
		assert_eq(DungeonLook.plan(MapData.load_by_id(map_id), true), DungeonLook.plan(MapData.load_by_id(map_id), true), map_id)


func test_the_stones_mask_reads_each_cell() -> void:
	var map := MapData.load_by_id("seacave_galleries")
	var plan := DungeonLook.plan(map, true)
	var mask := DungeonLook.mask(map, plan["water"])
	for cell: Vector2i in map.grid:
		var texel := mask.get_pixelv(cell)
		if not PunyDungeon._solid(map.grid, cell):
			assert_almost_eq(texel.r, 1.0, 0.01, "open ground at %s" % cell)
			assert_almost_eq(texel.g, float(plan["water"].get(cell, 0.0)), 0.01, "the sea's depth at %s" % cell)
		elif not PunyDungeon.is_visible_wall(map.grid, cell):
			assert_almost_eq(texel.r, 0.0, 0.01, "rock nobody sees at %s" % cell)
		elif not PunyDungeon._solid(map.grid, cell + Vector2i.DOWN):
			assert_almost_eq(texel.r, 2.0 / 3.0, 0.01, "a wall's face at %s" % cell)
		else:
			assert_almost_eq(texel.r, 1.0 / 3.0, 0.01, "a wall's top at %s" % cell)
	for cell: Vector2i in plan["water"]:
		assert_gte(float(plan["water"][cell]), DungeonLook.SHALLOWEST, "a pool's every cell shows water inside its foam")


# ---- The way in ---------------------------------------------------------------------

func test_no_two_planned_floors_open_in_the_same_room() -> void:
	var seen := {}
	for map_id: String in PLANNED:
		var plan := Depths.plan(map_id)
		var map: MapData = plan["map"]
		var entrance: Rect2i = plan["rooms"][0]
		var shape: PackedStringArray = []
		for y in range(entrance.position.y - 1, entrance.end.y + 1):
			var row := ""
			for x in range(entrance.position.x - 1, entrance.end.x + 1):
				row += "#" if PunyDungeon._solid(map.grid, Vector2i(x, y)) else "."
			shape.append(row)
		var key := "\n".join(shape)
		assert_false(seen.has(key), "%s opens in a room of its own, not %s's" % [map_id, seen.get(key, "")])
		seen[key] = map_id


func test_the_entrance_keeps_its_stair_and_lights_and_leaves_the_floor_beyond_as_it_was() -> void:
	for map_id: String in PLANNED:
		var plan := Depths.plan(map_id)
		var map: MapData = plan["map"]
		var entrance: Rect2i = plan["rooms"][0]
		assert_eq(plan["stairs"], Vector2i(2, 9), "%s: the stair up where it was" % map_id)
		assert_eq(map.spawn, Vector2i(3, 9), "%s: a hero arrives where they did" % map_id)
		assert_true(entrance.has_point(map.spawn), "%s: in the entrance" % map_id)
		assert_eq(entrance.position.x, 2, "%s: grown north or south only" % map_id)
		assert_eq(entrance.size.x, DungeonFloor.ENTRANCE.x, "%s: as wide as it was" % map_id)
		assert_between(entrance.size.y, DungeonFloor.ENTRANCE.y, DungeonFloor.ENTRANCE.y + 2 * DungeonFloor.ENTRANCE_GROWTH, map_id)
		# Every open cell of it reached from where a hero arrives.
		var reached := {map.spawn: true}
		var queue: Array[Vector2i] = [map.spawn]
		while not queue.is_empty():
			var at: Vector2i = queue.pop_back()
			for step: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
				var next := at + step
				if entrance.has_point(next) and map.is_walkable(next) and not reached.has(next):
					reached[next] = true
					queue.append(next)
		for y in range(entrance.position.y, entrance.end.y):
			for x in range(entrance.position.x, entrance.end.x):
				var cell := Vector2i(x, y)
				if map.is_walkable(cell):
					assert_true(reached.has(cell), "%s: %s reached from the stair" % [map_id, cell])
		# Beyond its east wall the floor lays as it did before the entrance
		# took its shape (test_depths pins it).
		assert_eq(_beyond_entrance(map), BEYOND[map_id], "%s: the floor beyond the entrance as it was" % map_id)


## An md5 of a planned floor's cells east of its entrance's wall.
static func _beyond_entrance(map: MapData) -> String:
	var cells: Array = map.grid.keys()
	cells.sort()
	var rows: PackedStringArray = []
	for cell: Vector2i in cells:
		if cell.x >= DungeonFloor.MARGIN + DungeonFloor.ENTRANCE.x:
			rows.append("%d,%d=%s" % [cell.x, cell.y, map.grid[cell]])
	return "|".join(rows).md5_text()


# ---- Drawn --------------------------------------------------------------------------

func test_a_floor_is_drawn_dressed_its_stone_worn_and_dust_in_each_torchs_light() -> void:
	var still: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false
	for map_id: String in ["seacave", "shafts_gallery", "cellars_crypt", "icecave", "vault_1"]:
		var map := MapData.load_by_id(map_id)
		var root := Node2D.new()
		add_child_autofree(root)
		var actors := Node2D.new()
		root.add_child(actors)
		var view := MapView.new(map, actors)
		view.plan(map.spawn)
		view.build(root)
		assert_eq(view.dressing["look"], DungeonLook.of(map_id), map_id)
		var stone := root.find_children("*", "TileMapLayer", true, false).filter(func(layer: Node) -> bool:
			var material := (layer as TileMapLayer).material as ShaderMaterial
			return material != null and material.shader == preload("res://shaders/dungeon.gdshader"))
		assert_gt(stone.size(), 0, "%s's stone is worn as its place" % map_id)
		var motes := root.find_children("*", "Sprite2D", true, false).filter(func(node: Node) -> bool:
			var material := (node as Sprite2D).material as ShaderMaterial
			return material != null and material.shader == preload("res://shaders/torch_motes.gdshader"))
		assert_eq(motes.size(), view.wall_torches.size(), "%s: dust in each torch's light" % map_id)
	GameState.settings.reduce_motion = still
