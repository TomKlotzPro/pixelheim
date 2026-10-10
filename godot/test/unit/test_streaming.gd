extends GutTest
## A map drawn beside the hero's a few units a frame (One Reach, PIX-269,
## step 5) is the very map a door draws in one go: the same ground, crowns
## and blockers, the same cells covered, the same nodes - its kept ground and
## the decks its patches are dealt from worked out a slice at a time too.
## And a gate the story keeps shut blocks on a map drawn that way.


func before_all() -> void:
	KeptGround.forget()


func after_all() -> void:
	KeptGround.forget()


## Every node under `node`, itself included.
static func _count(node: Node) -> int:
	var total := 1
	for child: Node in node.get_children():
		total += _count(child)
	return total


## A tile layer's cells: cell -> [source, atlas coords].
static func _cells(layer: TileMapLayer) -> Dictionary:
	var out := {}
	for cell: Vector2i in layer.get_used_cells():
		out[cell] = [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell)]
	return out


## `map_id` drawn as a door draws it, or a slice of 3 ms a frame as
## Neighbours draws it beside the hero: what it drew.
func _draw(map_id: String, sliced: bool) -> Dictionary:
	var root := Node2D.new()
	add_child_autofree(root)
	var standing := Node2D.new()
	root.add_child(standing)
	var data := MapData.load_by_id(map_id)
	var view := MapView.new(data, standing)
	var frames := 0
	if sliced:
		view.sliced = true
		var slices := Slicer.new()
		KeptGround.decks_working(data, slices)
		view.planning(data.spawn, slices)
		slices.add("plan_kept", func() -> void:
			view.kept = KeptGround.working(data, view.look(), MapView.EDGE_PAD, slices)
			slices.add("plan_draw", func() -> void: view.building(root, slices)))
		while not slices.run(3.0):
			frames += 1
	else:
		view.plan(data.spawn)
		view.build(root)
	return {
		"nodes": _count(root), "ground": _cells(view.ground_layer), "crowns": _cells(view.crown_layer), "rims": _cells(view.rim_layer),
		"blockers": _cells(view.tile_layer), "covered": data.covered.keys(), "frames": frames, "view": view, "data": data,
	}


func test_a_map_drawn_in_slices_is_the_map_a_door_draws() -> void:
	for map_id: String in ReachPlane.maps():
		# Worked out from scratch in slices first, then drawn in one go from
		# what was kept.
		var sliced := _draw(map_id, true)
		var whole := _draw(map_id, false)
		assert_gt(sliced["frames"], 2, "%s took a few frames" % map_id)
		for part: String in ["nodes", "ground", "rims", "crowns", "blockers", "covered"]:
			assert_eq(sliced[part], whole[part], "%s: its %s the same" % [map_id, part])
		var kept: KeptGround = whole["view"].kept
		assert_eq(sliced["ground"].size(), kept.ground.size(), "%s: every corner of its kept ground laid, its edges' padding too" % map_id)


func test_a_shut_gate_blocks_on_a_map_drawn_in_slices() -> void:
	var drawn := _draw("overworld", true)
	var view: MapView = drawn["view"]
	var data: MapData = drawn["data"]
	assert_false(view.gates.is_empty(), "a new hero finds the Reach's roads shut")
	var bodies := {}
	for node: Node in view.stand.get_children():
		if node is StaticBody2D:
			bodies[Vector2i(((node as Node2D).position / MapView.TILE).floor())] = true
	for gate: Dictionary in view.gates:
		for cell: Vector2i in Gates.cells_of(gate):
			assert_false(data.is_walkable(cell), "%s's %s is shut" % [gate["id"], cell])
			assert_true(bodies.has(cell), "%s's %s has its box" % [gate["id"], cell])


## Every tile the open air draws on its tile layers is made with its
## tileset (PunyTerrain, PunyTown): one made later changes the tileset under
## every layer drawn with it, and they all draw again (the town's sheet
## redraws its padded copy, some 20 ms) - in the hero's frame, as a map is
## drawn beside theirs.
func test_every_tile_the_reach_draws_is_made_ahead() -> void:
	var terrain := PunyTerrain.made_ahead(PunyTerrain.sheet())
	var town := {}
	for tile: int in PunyTown.pieces():
		town[tile] = true
	for map_id: String in ReachPlane.maps():
		var drawn := _draw(map_id, false)
		var view: MapView = drawn["view"]
		var used := {}
		for tiles: PackedInt32Array in [view.kept.ground, view.kept.rims, view.kept.crowns]:
			for tile: int in tiles:
				if tile >= 0:
					used[tile] = true
		var look := view.look()
		for cell: Vector2i in look:
			for tile: int in [PunyTerrain.object_at(look, cell), PunyTerrain.wall_piece(view.data.grid, cell)]:
				if tile >= 0:
					used[tile] = true
		for part: String in ["objects", "growth", "icons"]:
			for tile: int in view.skyline.get(part, {}).values():
				used[tile] = true
		for tile: int in view.rampart.get("fallback", {}).values():
			used[tile] = true
		for tile: int in used:
			assert_true(terrain.has(tile), "%s draws Puny World tile %d, made ahead" % [map_id, tile])
		var built: Array = view.buildings["pieces"].values() + view.buildings["decor"].values() + view.outdoor_props["flat"].values() \
			+ view.rampart.get("pieces", {}).values()
		for tile: int in built:
			assert_true(town.has(tile), "%s draws house or flower tile %d, made ahead" % [map_id, tile])
