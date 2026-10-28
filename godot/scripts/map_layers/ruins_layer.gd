class_name RuinsLayer
extends MapLayer
## areas: travel field
## The old stone ruins in the open (Ruins, RuinArt, PIX-381): planned with
## the props, then laid on one tile layer of their own over the blockers'
## stone, so their shadow and rubble lie on the floor too; MapView's
## `plan_ruins` and `ruins` units. A map without ruins adds no node.


func plan(view: MapView, slices: Slicer) -> void:
	slices.add("plan_ruins", func() -> void:
		var outdoor := view.data.style != "cave" and not view.buildings.has("floor") and PunyTerrain.is_outdoor(view.data.grid)
		view.ruins = Ruins.plan(view.data.grid) if outdoor else {})


func build(view: MapView, slices: Slicer) -> void:
	if view.ruins.get("walls", {}).is_empty():
		return
	slices.add("ruins", func() -> void:
		var layer := MapView.tile_layer_of(RuinArt.tileset())
		for part: String in ["walls", "ground"]:
			var tiles: Dictionary = view.ruins[part]
			for cell: Vector2i in tiles:
				RuinArt.place(layer, cell, tiles[cell])
		view.under.add_child(layer)
		view.layers["ruins"] = layer)
