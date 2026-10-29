class_name GroundLayer
extends MapLayer
## areas: town rooms travel +town-age*
## The open air's ground (PunyTerrain, KeptGround, PIX-269, PIX-305,
## PIX-307): its tile layers and their toning, the corner tiles a block at a
## time, the streets, the objects, the small things on the ground and the
## pieces standing on it; MapView's `ground_*` units on a map that is
## neither a dungeon nor a room (PIX-359).

## How far the wind leans what grows, in pixels at its top (PIX-223): a
## tree or a sheaf, a flower, a forest's crowns (all of a piece, so less).
const TREE_SWAY := 1.3
const FLOWER_SWAY := 0.7
const CANOPY_SWAY := 0.4


## The open air's ground in the ground's slot: neither a dungeon's nor a
## room's.
func build(view: MapView, slices: Slicer) -> void:
	if view.data.style != "cave" and not view.buildings.has("floor"):
		_ground_units(view, slices)


## The ground in Shade's Puny World tiles (PunyTerrain): grass, roads, sand,
## cliffs and rippling water on the dual grid, half a tile up-left of the
## cells so every terrain edge sits on a cell edge. All of it at once (the
## town's tour draws a past town over the town with it, draw_ground).
static func _build_ground(view: MapView, _data: MapData) -> Node2D:
	if view.buildings.has("floor"):
		return RoomsLayer._build_room(view, view.data)
	var root := _ground_layers(view)
	view.kept.lay_ground(view.ground_layer)
	view.kept.lay_rims(view.rim_layer)
	view.kept.lay_crowns(view.crown_layer)
	_plan_streets(view)
	for i in ceili(view.data.size.y / float(MapView.BLOCK)):
		_street_rows(view, i)
		_object_rows(view, i)
		_detail_rows(view, i)
	_ground_pieces(view)
	return root


## The ground's units: its layers, the tiles (a BLOCK a unit when sliced,
## else from the kept layers in one call), the objects a band of rows a
## unit, then the pieces (the village far off, gates in the rock, growth,
## flowers, houses).
static func _ground_units(view: MapView, slices: Slicer) -> void:
	if view.kept == null:
		view.kept = KeptGround.of(view.data, view.look(), MapView.EDGE_PAD)
	slices.add("ground_layers", func() -> void: view._ground_root(_ground_layers(view)))
	if view.sliced or view.kept.ground_cells.is_empty():
		var blocks := quadrants(view.kept.corners())
		slices.add_each("ground_tiles", blocks.size(), func(i: int) -> void:
			view.kept.lay_block(view.ground_layer, view.rim_layer, view.crown_layer, blocks[i])
			if view.sliced:
				view.draw_now()
			if i == blocks.size() - 1 and view.kept.ground_cells.is_empty():
				# Kept, for the next drawing to lay in one call.
				view.kept.ground_cells = view.ground_layer.tile_map_data
				view.kept.rim_cells = view.rim_layer.tile_map_data
				view.kept.crown_cells = view.crown_layer.tile_map_data)
	else:
		slices.add("ground_tiles", func() -> void:
			view.kept.lay_ground(view.ground_layer)
			view.kept.lay_rims(view.rim_layer)
			view.kept.lay_crowns(view.crown_layer))
	slices.add("ground_streets", func() -> void: _plan_streets(view))
	slices.add_each("ground_paving", ceili(view.data.size.y / float(MapView.BLOCK)), func(i: int) -> void: _street_rows(view, i))
	slices.add_each("ground_objects", ceili(view.data.size.y / float(MapView.BLOCK)), func(i: int) -> void: _object_rows(view, i))
	slices.add_each("ground_detail", ceili(view.data.size.y / float(MapView.BLOCK)), func(i: int) -> void: _detail_rows(view, i))
	slices.add("ground_pieces", func() -> void: _ground_pieces(view))


## The units of a tile layer (BLOCK square) that `rect` (of its cells)
## covers, each clipped to it: whole rendering quadrants (LIGHT_BLOCK), so a
## quadrant laid in one unit is drawn once.
static func quadrants(rect: Rect2i) -> Array[Rect2i]:
	var out: Array[Rect2i] = []
	var first := Vector2i(floori(rect.position.x / float(MapView.BLOCK)), floori(rect.position.y / float(MapView.BLOCK)))
	var last := Vector2i(floori((rect.end.x - 1) / float(MapView.BLOCK)), floori((rect.end.y - 1) / float(MapView.BLOCK)))
	for qy in range(first.y, last.y + 1):
		for qx in range(first.x, last.x + 1):
			out.append(Rect2i(Vector2i(qx, qy) * MapView.BLOCK, Vector2i(MapView.BLOCK, MapView.BLOCK)).intersection(rect))
	return out


## The ground's layers, empty but for their materials, in drawing order:
## the corner tiles, the crowns, the objects, then the village's growth, the
## flowers and the houses where there are any.
static func _ground_layers(view: MapView) -> Node2D:
	var root := Node2D.new()
	view.ground_layer = MapView.tile_layer_of(PunyTerrain.tileset())
	view.ground_layer.position = Vector2(-TILE, -TILE) / 2.0
	# The ground as drawn: the map's, but for the village far off (PIX-248),
	# whose streets, river and ash lie where its block's cells are. On past
	# the map's edges: below the dock the camera looks past the south edge
	# (CameraRig.set_limits, PIX-269), and sees the ground go on, as it lies
	# there in the Reach's plane (the map beside, or the ridge's rock).
	# Worked out on the map's first visit this session, and kept (PIX-269).
	if view.kept == null:
		view.kept = KeptGround.of(view.data, view.look(), MapView.EDGE_PAD)
	# Ash and mire are toned from Shade's dirt and grass, decor included.
	view._toned = []
	view.ground_tint = ShaderMaterial.new()
	view.ground_tint.shader = preload("res://shaders/region_tint.gdshader")
	view.ground_tint.set_shader_parameter("tint_map", view.kept.tint_map)
	view.ground_tint.set_shader_parameter("map_pixels", Vector2(view.data.size * TILE))
	# Where the map lies in the plane: what the shader's slow noise and the
	# water's light read, so they run on unbroken into a map beside it.
	var origin := ReachPlane.origin(view.data.id) if ReachPlane.holds(view.data.id) else Vector2i.ZERO
	view.ground_tint.set_shader_parameter("map_origin", Vector2(origin * TILE))
	view._toned.append(view.ground_tint)
	# The water swells, glints and foams at the shore (PIX-223).
	var water := _toning(view)
	water.set_shader_parameter("water_life", true)
	# And the open ground has its patches, drifts, murk and puddles (PIX-305).
	water.set_shader_parameter("ground_life", true)
	water.set_shader_parameter("water_map", view.kept.water_map)
	view.ground_tint.set_shader_parameter("water_map", view.kept.water_map)
	view.ground_layer.material = water
	# The floor answers to a boss's glow too (Lights.FLOOR, PIX-314).
	view.ground_layer.light_mask |= Lights.FLOOR
	root.add_child(view.ground_layer)
	# The open ground's patches of the Medieval Age's greens and snow, in
	# their own colours (the region's tone would whiten its snow's blue tufts
	# away) with the ground's own patches over the greens (PIX-305); the
	# floor, a boss's glow too.
	view.patch_layer = null
	if not view.kept.patches.is_empty() and PunyTown.available():
		view.patch_layer = MapView.tile_layer_of(PunyTown.tileset())
		var patched := _toning(view)
		patched.set_shader_parameter("ground_life", true)
		patched.set_shader_parameter("strength", 0.0)
		view.patch_layer.material = patched
		view.patch_layer.light_mask |= Lights.FLOOR
		root.add_child(view.patch_layer)
	# The streets' paving (PIX-307), the pack's own stone, untoned but where
	# a region tones all its ground (the Frostgate's snow: its road's stone
	# greys and the snow drifts in at its edges); then the roads' wear and
	# the grass at their edges, toned as the ground is.
	view.paving_layer = null
	if PunyTown.available():
		view.paving_layer = MapView.tile_layer_of(PunyTown.tileset())
		if view.kept.crowns_toned:
			view.paving_layer.material = view.ground_tint
		root.add_child(view.paving_layer)
	view.wear_layer = MapView.tile_layer_of(RoadWear.tileset())
	view.wear_layer.material = view.ground_tint
	root.add_child(view.wear_layer)
	view.verge_layer = MapView.tile_layer_of(RoadWear.tileset())
	view.verge_layer.material = view.ground_tint
	root.add_child(view.verge_layer)
	# The open ground's small things (PIX-305), toned with the region, over
	# the grass at the roads' edges.
	view.detail_layer = MapView.tile_layer_of(GroundDetail.tileset())
	view.detail_layer.material = view.ground_tint
	view.detail_layer.light_mask |= Lights.FLOOR
	root.add_child(view.detail_layer)
	# The Ash's cinders on a layer of their own, glowing (PIX-308).
	view.ember_layer = MapView.tile_layer_of(GroundDetail.tileset())
	var glowing := ShaderMaterial.new()
	glowing.shader = preload("res://shaders/embers.gdshader")
	view.ember_layer.material = glowing
	root.add_child(view.ember_layer)
	# The ground darker under the forest (PIX-309).
	if view.kept.shade_map != null:
		root.add_child(_canopy_shade(view))
	# Shade's cliffs standing in the water, the sand and the roads
	# (PunyTerrain.rimmed), toned as the ground is, but still: the water
	# under them swells.
	view.rim_layer = MapView.tile_layer_of(PunyTerrain.tileset())
	view.rim_layer.position = view.ground_layer.position
	# Their tops scorched where the rock burns (PIX-308).
	var rims := _toning(view)
	rims.set_shader_parameter("scorch_life", true)
	view.rim_layer.material = rims
	view.rim_layer.light_mask |= Lights.FLOOR
	root.add_child(view.rim_layer)
	view.decor_sway = _swaying(view, TREE_SWAY, true)
	view.woods_sway = _swaying(view, TREE_SWAY, true)
	view.woods_sway.set_shader_parameter("strength", 0.0)
	view.flowers_sway = _swaying(view, FLOWER_SWAY, false)
	view.flowers_sway.set_shader_parameter("strength", 0.0)
	view.canopy = _toning(view)
	view.canopy.set_shader_parameter("canopy", CANOPY_SWAY)
	view.crown_layer = MapView.tile_layer_of(PunyTerrain.tileset())
	view.crown_layer.position = view.ground_layer.position
	# Under snow the pines on the ridges whiten with the ground (PIX-169),
	# and a few cells past a snowfield's edge (PIX-309, KeptGround
	# .crown_map); elsewhere they keep their green (but along a line with a
	# snowy map beside, where they whiten as its own do: set_masks).
	if view.kept.crown_map == null:
		view.canopy.set_shader_parameter("strength", 0.0)
	else:
		view.canopy.set_shader_parameter("tint_map", view.kept.crown_map)
	view.crown_layer.material = view.canopy
	root.add_child(view.crown_layer)
	# Bridges, cave mouths and ramparts stand on that ground as Puny objects;
	# the village far off brings its own rampart, wells and growth.
	view._objects_layer = MapView.tile_layer_of(PunyTerrain.tileset())
	# The river Shade drew between a bridge's planks takes the water's own
	# look (PIX-306): the mire's murk under its bridges, not his cyan.
	var planks := _toning(view)
	planks.set_shader_parameter("strength", 0.0)
	planks.set_shader_parameter("planks", true)
	view._objects_layer.material = planks
	root.add_child(view._objects_layer)
	# Pixelheim's rampart in the Medieval Age's stone, its gatehouse at the
	# road (PIX-248); what the fire left of it darker, on a layer of its own.
	view._rampart_layers = []
	if not view.rampart.is_empty() and PunyTown.available():
		for scorched: bool in [false, true]:
			var stone := MapView.tile_layer_of(PunyTown.tileset())
			if scorched:
				stone.modulate = Rampart.SCORCHED
			root.add_child(stone)
			view._rampart_layers.append(stone)
	view._growth_layer = null
	if not view.skyline.get("growth", {}).is_empty():
		# Its woods and fields lean in the wind together.
		view._growth_layer = MapView.tile_layer_of(PunyTerrain.tileset())
		view._growth_layer.material = _swaying(view, TREE_SWAY, false)
		root.add_child(view._growth_layer)
	# Shade's flowers, flat on the ground (the hero walks through them).
	if not view.outdoor_props["flat"].is_empty():
		var flowers := MapView.tile_layer_of(PunyTown.tileset())
		flowers.material = view.flowers_sway
		root.add_child(flowers)
		view.layers["flowers"] = flowers
	# The houses, their roofs under the snow where a settlement's lie under it
	# (PIX-313: the Frostgate's, shaders/snowed_roof.gdshader), then what stands on
	# their roofs (chimneys).
	for part: String in ["pieces", "snowed", "decor"]:
		if part == "snowed":
			if not view.house_style.get("snow", false) or view.buildings["pieces"].is_empty():
				continue
		elif view.buildings[part].is_empty():
			continue
		var houses := MapView.tile_layer_of(PunyTown.tileset())
		if part == "snowed":
			var snowed := ShaderMaterial.new()
			snowed.shader = preload("res://shaders/snowed_roof.gdshader")
			houses.material = snowed
		root.add_child(houses)
		view.layers[part] = houses
	return root


## Bridges, cave mouths and ramparts on cell rows [i * BLOCK, (i + 1) *
## BLOCK): a band of the objects layer's quadrants, whole.
static func _object_rows(view: MapView, i: int) -> void:
	var drawn := view.look()
	var outdoor := PunyTerrain.is_outdoor(view.data.grid)
	var village: Rect2i = view.skyline.get("block", Rect2i())
	var walled: Dictionary = view.rampart.get("pieces", {})
	# A ruin's walls are its own (RuinsLayer, PIX-381), as are the walls
	# standing in the open (StoneWalls, PIX-386): a gate in a band of wall
	# keeps Shade's archway.
	var ruined: Dictionary = view.ruins.get("walls", {})
	var standing: Dictionary = view.stone_walls.get("walls", {})
	for y in range(i * MapView.BLOCK, mini((i + 1) * MapView.BLOCK, view.data.size.y)):
		for x in view.data.size.x:
			var cell := Vector2i(x, y)
			if not drawn.has(cell):
				continue
			var object := PunyTerrain.object_at(drawn, cell)
			if outdoor and object < 0 and not village.has_point(cell) and not walled.has(cell) and not ruined.has(cell) and not standing.has(cell):
				object = PunyTerrain.wall_piece(view.data.grid, cell)
			if object >= 0 and not view.gate_hides.has(cell):
				PunyTerrain.place(view._objects_layer, cell, object)
	if view.sliced:
		view._objects_layer.update_internals()


## The open ground's patches and small things on cell rows [i * BLOCK,
## (i + 1) * BLOCK) (PIX-305): whole quadrants of their layers. Nothing
## small grows where something stands or a way leads on (`bare`).
static func _detail_rows(view: MapView, i: int) -> void:
	for y in range(i * MapView.BLOCK, mini((i + 1) * MapView.BLOCK, view.data.size.y)):
		for x in view.data.size.x:
			var cell := Vector2i(x, y)
			if view.patch_layer != null and view.kept.patches.has(cell):
				PunyTown.place(view.patch_layer, cell, view.kept.patches[cell])
			if view.kept.details.has(cell) and not view.bare.has(cell) and not view.worked.has(cell):
				var tile: Vector2i = view.kept.details[cell]
				GroundDetail.place(view.ember_layer if GroundDetail.glows(tile) else view.detail_layer, cell, tile)
	if view.sliced:
		view.detail_layer.update_internals()
		view.ember_layer.update_internals()
		if view.patch_layer != null:
			view.patch_layer.update_internals()


## The streets this visit paves (PIX-307): each cell's look at the town's
## age (Streets), and with the pack the tile for it and where its traffic
## has worn it (PIX-382 step 4); without it the streets stay bare dirt, worn
## as a road is.
static func _plan_streets(view: MapView) -> void:
	view.streets = Streets.plan(view.data.id, view.data.grid, GameState.town_tier())
	view._paved = view.streets if view.paving_layer != null else {}
	view.worn_paving = Streets.worn(view.data.id, view.data.grid, view._paved, GameState.town_tier())
	view.street_tiles = Streets.tiles(view._paved)
	# By band of rows, for _street_rows: the paving's tiles, and the cells of
	# a look that sets kerbs.
	view._street_bands = []
	for i in ceili(view.data.size.y / float(MapView.BLOCK)):
		view._street_bands.append({"tiles": {}, "kerbed": {}})
	for cell: Vector2i in view.street_tiles:
		var band: Dictionary = view._street_bands[floori(cell.y / float(MapView.BLOCK))]
		band["tiles"][cell] = view.street_tiles[cell]
		if view._paved[cell] in Streets.KERBED:
			band["kerbed"][cell] = true


## The paving, the wear, the verges and a gravelled street's kerbs on cell
## rows [i * BLOCK, (i + 1) * BLOCK): a band of their layers' quadrants,
## whole. A road's wear reads the ground past the map's edges where it runs
## on out (the plane's, or the edge carried on), so its ruts meet the next
## map's.
static func _street_rows(view: MapView, i: int) -> void:
	var from := i * MapView.BLOCK
	var to := mini((i + 1) * MapView.BLOCK, view.data.size.y)
	var band: Dictionary = view._street_bands[i]
	for cell: Vector2i in band["tiles"]:
		PunyTown.place(view.paving_layer, cell, band["tiles"][cell])
	var plane := ReachPlane.holds(view.data.id)
	var origin := ReachPlane.origin(view.data.id) if plane else Vector2i.ZERO
	var beyond := func(cell: Vector2i) -> String:
		if plane:
			return ReachPlane.tile(origin + cell)
		return view.data.grid.get(Vector2i(clampi(cell.x, 0, view.data.size.x - 1), clampi(cell.y, 0, view.data.size.y - 1)), "")
	var style := RoadWear.TOWN if view.data.id in Rampart.MAPS else RoadWear.COUNTRY
	var worn := RoadWear.rows(view.data.grid, beyond, view.data.size, from, to, view._paved, origin, style, view.worn_paving)
	for cell: Vector2i in worn["wear"]:
		RoadWear.place(view.wear_layer, cell, worn["wear"][cell])
	for cell: Vector2i in worn["verge"]:
		RoadWear.place(view.verge_layer, cell, worn["verge"][cell])
	var kerbs := RoadWear.kerbs(band["kerbed"], view._paved, view.data.grid, from, to)
	for cell: Vector2i in kerbs:
		RoadWear.place(view.verge_layer, cell, kerbs[cell])
	if view.sliced:
		for layer: TileMapLayer in [view.paving_layer, view.wear_layer, view.verge_layer]:
			if layer != null:
				layer.update_internals()


## What stands on the ground but the objects: the village far off's wells,
## Pixelheim's rampart and its gatehouse, a gate in the rock, growth, the
## flowers and the houses.
static func _ground_pieces(view: MapView) -> void:
	if not view.skyline.is_empty():
		var drawn: Dictionary = view.skyline["objects"].merged({} if PunyTown.available() else view.skyline["icons"])
		for cell: Vector2i in drawn:
			PunyTerrain.place(view._objects_layer, cell, drawn[cell])
	# Pixelheim's rampart in Shade's CC0 castle pieces, without the paid pack.
	if not PunyTown.available():
		for cell: Vector2i in view.rampart.get("fallback", {}):
			PunyTerrain.place(view._objects_layer, cell, view.rampart["fallback"][cell])
	for layer: TileMapLayer in view._rampart_layers:
		var scorched := layer == view._rampart_layers[-1]
		for cell: Vector2i in view.rampart["pieces"]:
			if view.rampart["scorched"].has(cell) == scorched:
				PunyTown.place(layer, cell, view.rampart["pieces"][cell])
	# A gate set in the rock (the Ashen Mountain's, PIX-269; its other side
	# at the foot of the mountain road, PIX-253 step 8; the Kings' Vault's
	# door under the summit, PIX-257), where nothing stood in the notch:
	# Shade's castle gate, its portcullis down while the story bars it
	# (`barred`: until Maren's promise, until the dragon is freed). One drawn
	# as an entrance in its setting (EntranceArt, PIX-290) has its own.
	for way: Dictionary in view.ways:
		if way["rock"] and not view.gate_hides.has(way["at"]):
			var barred: bool = Ways.barred(way["to"], GameState.progression, GameState.settlement)
			PunyTerrain.place(view._objects_layer, way["at"], Ways.ROCK_GATE_BARRED if barred else Ways.ROCK_GATE)
	if view._growth_layer != null:
		for cell: Vector2i in view.skyline["growth"]:
			PunyTerrain.place(view._growth_layer, cell, view.skyline["growth"][cell])
	if view.layers.has("flowers"):
		for cell: Vector2i in view.outdoor_props["flat"]:
			PunyTown.place(view.layers["flowers"], cell, view.outdoor_props["flat"][cell])
	for part: String in ["pieces", "decor"]:
		if view.layers.has(part):
			for cell: Vector2i in view.buildings[part]:
				var tile: int = view.buildings[part][cell]
				var layer: TileMapLayer = view.layers[part]
				if part == "pieces" and view.layers.has("snowed") and not PunyTown.is_wall(tile):
					layer = view.layers["snowed"]
				PunyTown.place(layer, cell, tile)
	if view.sliced:
		for layer: Node in view.ground.get_children():
			if layer is TileMapLayer and layer not in [view.ground_layer, view.rim_layer, view.crown_layer]:
				(layer as TileMapLayer).update_internals()


## The ground's toning, leaning in the wind `sway` pixels at the top: each
## sprite on its own beat (`alone`), or a layer's tiles together.
static func _swaying(view: MapView, sway: float, alone: bool) -> ShaderMaterial:
	var material := _toning(view)
	material.set_shader_parameter("sway", sway)
	material.set_shader_parameter("sway_alone", alone)
	return material


## A material toned as the ground is, kept in step with its masks.
static func _toning(view: MapView) -> ShaderMaterial:
	var material := view.ground_tint.duplicate() as ShaderMaterial
	view._toned.append(material)
	return material


## The ground darker under the forest's canopy (PIX-309): the kept mask, a
## cell a texel, filtered between cells and drawn over the ground in two
## dithered steps (shaders/canopy_shade.gdshader).
static func _canopy_shade(view: MapView) -> Sprite2D:
	var shade := Sprite2D.new()
	shade.texture = view.kept.shade_map
	shade.centered = false
	shade.scale = Vector2(TILE, TILE)
	shade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/canopy_shade.gdshader")
	shade.material = material
	return shade
