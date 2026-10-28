class_name RuinsLayer
extends MapLayer
## areas: travel field
## The old stone ruins in the open (Ruins, RuinArt, PIX-381) and the walls
## still standing there (StoneWalls, PIX-386): planned with the props, then
## laid on one tile layer of their own over the blockers' stone, so their
## shadow and rubble lie on the floor too; MapView's `plan_ruins` and `ruins`
## units. A map without either adds no node.


func plan(view: MapView, slices: Slicer) -> void:
	slices.add("plan_ruins", func() -> void:
		var outdoor := view.data.style != "cave" and not view.buildings.has("floor") and PunyTerrain.is_outdoor(view.data.grid)
		view.ruins = Ruins.plan(view.data.grid) if outdoor else {}
		view.stone_walls = StoneWalls.plan(view.data.grid, _drawn_elsewhere(view)) if outdoor else {})


func build(view: MapView, slices: Slicer) -> void:
	if view.ruins.get("walls", {}).is_empty() and view.stone_walls.get("walls", {}).is_empty():
		return
	slices.add("ruins", func() -> void:
		var layer := MapView.tile_layer_of(RuinArt.tileset())
		for plan: Dictionary in [view.ruins, view.stone_walls]:
			for part: String in ["walls", "ground"]:
				var tiles: Dictionary = plan.get(part, {})
				for cell: Vector2i in tiles:
					RuinArt.place(layer, cell, tiles[cell])
		view.under.add_child(layer)
		view.layers["ruins"] = layer)


## The walls drawn by something else: a ruin's, Pixelheim's rampart and its
## gatehouse (Rampart), the village far off's block (Skyline).
static func _drawn_elsewhere(view: MapView) -> Dictionary:
	var out: Dictionary = view.ruins.get("walls", {}).merged(view.rampart.get("pieces", {}))
	var village: Rect2i = view.skyline.get("block", Rect2i())
	for y in range(village.position.y, village.end.y):
		for x in range(village.position.x, village.end.x):
			out[Vector2i(x, y)] = true
	return out
