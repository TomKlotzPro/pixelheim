class_name DungeonLayer
extends MapLayer
## areas: town rooms travel +town-age*
## A dungeon floor in Shade's Puny Dungeon (PunyDungeon, DungeonLook,
## PIX-255, PIX-291, PIX-292, PIX-310): its stone, torches, ice and dressing,
## and its ways straight out lit and signed; MapView's `ground_dungeon`
## unit (PIX-359).

## A wall torch's glow (PIX-291): [radius px, peak], round its flame, which
## burns this far from its cell's middle (over the wall's top).
const TORCH_GLOW := [13, 0.28]
const TORCH_FLAME := Vector2(0, -3)
## The pool of a wall torch's light its dust drifts in (PIX-310), in pixels,
## from its flame down onto the floor before it, centred this far below it.
const TORCH_MOTES := Vector2(40, 40)
const MOTES_BELOW := 9.0
## One cold light over the ice (PIX-255) in every so many cells across and down.
const ICE_LIGHT_EVERY := Vector2i(6, 5)
## How far a way out's light reaches, in pixels (PIX-292), and how far
## over its cell its plate stands.
const WAY_OUT_GLOW := 80.0
const WAY_OUT_PLATE := 4.0
static var _motes_texture: ImageTexture
static var _glow_textures := {}


## A dungeon floor in the ground's slot.
func build(view: MapView, slices: Slicer) -> void:
	if view.data.style == "cave":
		slices.add("ground_dungeon", func() -> void: view._ground_root(_build_dungeon(view, view.data)))


## A dungeon floor in Shade's Puny Dungeon: stone, walls by his grammar and
## the dark beyond, torches flickering on the walls, barrels, pots and the
## stairs up; dressed as its own place (DungeonLook, PIX-310): the look's
## floor (the Medieval Age's, with the pack), its stone worn and lit by
## shaders/dungeon.gdshader, what lies flat on it, what hangs on its walls'
## faces, what its barrels and pots are drawn as, and dust drifting in each
## torch's light.
static func _build_dungeon(view: MapView, data: MapData) -> Node2D:
	var root := Node2D.new()
	root.add_child(MapView._dark_beyond(data))
	var dungeon := PunyDungeon.sheet()
	var paid := PunyProps.available()
	view.dressing = DungeonLook.plan(data, paid)
	var stone := _stone(view, data)
	var layer := MapView.tile_layer_of(dungeon.tileset)
	layer.material = stone
	# Its floor and walls answer to a boss's glow (Lights.FLOOR, PIX-314);
	# what stands on them doesn't.
	layer.light_mask |= Lights.FLOOR
	# The Medieval Age's floor, and what stands drawn from it (ore carts),
	# only with the pack: its sheet isn't there without it.
	var floors: Dictionary = view.dressing["floors"]
	var laid: TileMapLayer = MapView.tile_layer_of(PunyTown.tileset()) if paid else null
	var standing: TileMapLayer = MapView.tile_layer_of(PunyTown.tileset()) if paid else null
	if laid != null:
		laid.material = stone
		laid.light_mask |= Lights.FLOOR
	var swaps: Dictionary = view.dressing["swaps"]
	view.dungeon_objects = MapView.tile_layer_of(dungeon.tileset)
	view.wall_torches = []
	for cell: Vector2i in data.grid:
		var tile: String = data.grid[cell]
		match tile:
			"wall":
				dungeon.place(layer, cell, PunyDungeon.wall_tile(data.grid, cell))
				continue
			"lamp":
				# A torch fixed to the wall's face (PIX-291): the wall runs on
				# through it, the torch over it.
				dungeon.place(layer, cell, PunyDungeon.wall_tile(data.grid, cell))
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.TORCH)
				view.wall_torches.append(cell)
				# Its fire lights the floor before it (PIX-221).
				root.add_child(Lights.make(MapView.center(cell) + Vector2(0, TILE * 0.7), 92.0, Lights.FIRE, Lights.TORCH_ENERGY, true))
				continue
		if floors.has(cell):
			PunyTown.place(laid, cell, int(floors[cell]))
		else:
			dungeon.place(layer, cell, PunyDungeon.floor_tile(cell))
		# What a region dungeon's floor draws over a cell (PIX-255): a wreck's
		# beams, the shortcut's door, shut or open.
		if data.pieces.has(cell):
			dungeon.place(view.dungeon_objects, cell, int(data.pieces[cell]))
			continue
		# A blocker the look draws as something else: an ore cart, ore.
		if swaps.has(cell):
			var swap: Dictionary = swaps[cell]
			if swap["sheet"] == "props" and standing != null:
				PunyTown.place(standing, cell, int(swap["tile"]))
			else:
				dungeon.place(view.dungeon_objects, cell, int(swap["tile"]))
			continue
		match tile:
			"barrel":
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.BARRELS[absi(hash(cell)) % 2])
			"crate":
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.POT)
			"cave":
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.STAIRS)
			"stairwell":
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.STAIRS_DOWN)
			"rock":
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.BOULDERS[absi(hash(cell)) % PunyDungeon.BOULDERS.size()])
			"winch":
				# The ore cage's winch by its gate (PIX-255: the Black Seam).
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.WHEEL)
			# The Greyhold cellars' stone knights and iron grilles (PIX-255).
			"statue":
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.STATUE)
			"grille":
				dungeon.place(view.dungeon_objects, cell, PunyDungeon.GRILLE)
	root.add_child(layer)
	_keep(root, laid)
	root.add_child(_dressed(view.dressing["flats"]))
	var ice := _frozen(data, floors)
	if ice != null:
		ice.light_mask |= Lights.FLOOR
		root.add_child(ice)
		# The ice gives the dark back a little cold light, here and there.
		for cell: Vector2i in data.grid:
			if data.grid[cell] == "ice" and posmod(cell.x, ICE_LIGHT_EVERY.x) == 2 and posmod(cell.y, ICE_LIGHT_EVERY.y) == 2:
				root.add_child(Lights.make(MapView.center(cell), 72.0, Lights.ICE, Lights.ICE_ENERGY))
	root.add_child(_dressed(view.dressing["faces"]))
	root.add_child(view.dungeon_objects)
	_keep(root, standing)
	# Each torch's flame glows softly on the wall round it (PIX-291), and
	# dust drifts in its light (PIX-310), but for reduced motion.
	for cell: Vector2i in view.wall_torches:
		root.add_child(_torch_glow(cell))
		if not GameState.settings.reduce_motion:
			root.add_child(_torch_motes(cell))
	return root


## The dungeon's stone (shaders/dungeon.gdshader): its look, and the mask
## of its cells, its sea and its walls (DungeonLook.mask).
static func _stone(view: MapView, data: MapData) -> ShaderMaterial:
	var stone := ShaderMaterial.new()
	stone.shader = preload("res://shaders/dungeon.gdshader")
	var cells := ImageTexture.create_from_image(DungeonLook.mask(data, view.dressing.get("water", {})))
	stone.set_shader_parameter("cells", cells)
	stone.set_shader_parameter("cells_soft", cells)
	stone.set_shader_parameter("map_pixels", Vector2(data.size * TILE))
	stone.set_shader_parameter("look", int(DungeonLook.SHADER.get(String(view.dressing.get("look", "")), 0)))
	return stone


## What a dungeon's look lays on its cells (DungeonLook's flats or faces),
## a tile layer a sheet: Shade's, the Medieval Age's (only with the pack:
## the plan has none without it), our own.
static func _dressed(pieces: Dictionary) -> Node2D:
	var root := Node2D.new()
	var layers := {}
	for cell: Vector2i in pieces:
		var piece: Dictionary = pieces[cell]
		var sheet := String(piece["sheet"])
		if not layers.has(sheet):
			var tile_set: TileSet = DungeonArt.tileset() if sheet == "art" else (PunyTown.tileset() if sheet == "props" else PunyDungeon.sheet().tileset)
			layers[sheet] = MapView.tile_layer_of(tile_set)
		match sheet:
			"art":
				DungeonArt.place(layers[sheet], cell, String(piece["tile"]))
			"props":
				PunyTown.place(layers[sheet], cell, int(piece["tile"]))
			"dungeon":
				PunyDungeon.sheet().place(layers[sheet], cell, int(piece["tile"]))
	for sheet: String in ["dungeon", "props", "art"]:
		if layers.has(sheet):
			root.add_child(layers[sheet])
	return root


## `layer` under `root` when it holds any tile; otherwise let go.
static func _keep(root: Node, layer: TileMapLayer) -> void:
	if layer == null:
		return
	if layer.get_used_cells().is_empty():
		layer.free()
	else:
		root.add_child(layer)


## Dust drifting in a torch's light (PIX-310, shaders/torch_motes.gdshader):
## a few motes over the pool its fire lights on the floor before it.
static func _torch_motes(cell: Vector2i) -> Sprite2D:
	if _motes_texture == null:
		var blank := Image.create(int(TORCH_MOTES.x), int(TORCH_MOTES.y), false, Image.FORMAT_RGBA8)
		blank.fill(Color.WHITE)
		_motes_texture = ImageTexture.create_from_image(blank)
	var motes := Sprite2D.new()
	motes.texture = _motes_texture
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/torch_motes.gdshader")
	material.set_shader_parameter("size", TORCH_MOTES)
	material.set_shader_parameter("seed", float(absi(hash(cell)) % 997) / 97.0)
	motes.material = material
	motes.position = MapView.center(cell) + Vector2(0, MOTES_BELOW)
	return motes


## A torch's soft glow on the wall round its flame (PIX-291): added onto the
## dark, never darkened by it, under the dungeon's own dark as much as at
## night.
static func _torch_glow(cell: Vector2i) -> Sprite2D:
	var key := "%d:%f" % [TORCH_GLOW[0], TORCH_GLOW[1]]
	if not _glow_textures.has(key):
		_glow_textures[key] = TitleScene.glow_texture(TORCH_GLOW[0], Color(1.0, 0.72, 0.38), TORCH_GLOW[1], 4)
	var glow := Sprite2D.new()
	glow.texture = _glow_textures[key]
	glow.material = Lights.glow()
	glow.position = MapView.center(cell) + TORCH_FLAME
	return glow


## Ice over a dungeon's stone (PIX-255: the ice cave's frozen lake, and its
## glass hall's floor): the floor of its `ice` cells and of the stone round
## them laid again, frozen by shaders/frozen.gdshader from a mask a texel a
## cell (the shore runs between cells, bent off the grid, frost creeping out
## over the stone). Between the floor and what stands on it; null for a map
## with no ice. The stone under it is the floor as laid (`floors`: the
## look's Medieval Age floor, PIX-310), Shade's elsewhere.
static func _frozen(data: MapData, floors: Dictionary) -> Node2D:
	var mask := Image.create(maxi(data.size.x, 1), maxi(data.size.y, 1), false, Image.FORMAT_L8)
	var frozen := false
	for cell: Vector2i in data.grid:
		if data.grid[cell] == "ice":
			mask.set_pixelv(cell, Color.WHITE)
			frozen = true
	if not frozen:
		return null
	var dungeon := PunyDungeon.sheet()
	var layer := MapView.tile_layer_of(dungeon.tileset)
	var laid: TileMapLayer = MapView.tile_layer_of(PunyTown.tileset()) if not floors.is_empty() else null
	for cell: Vector2i in data.grid:
		if data.grid[cell] not in ["wall", "lamp"] and _by_ice(data, cell):
			if floors.has(cell):
				PunyTown.place(laid, cell, int(floors[cell]))
			else:
				dungeon.place(layer, cell, PunyDungeon.floor_tile(cell))
	var frost := ShaderMaterial.new()
	frost.shader = preload("res://shaders/frozen.gdshader")
	frost.set_shader_parameter("ice_map", ImageTexture.create_from_image(mask))
	frost.set_shader_parameter("map_pixels", Vector2(data.size * TILE))
	var root := Node2D.new()
	for each: TileMapLayer in [layer, laid]:
		if each != null:
			each.material = frost
			_keep(root, each)
	return root


## Whether `cell` is ice or touches it, corners too: where the frost may
## reach.
static func _by_ice(data: MapData, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if data.grid.get(cell + Vector2i(dx, dy), "") == "ice":
				return true
	return false


## A way straight out of a dungeon's bottom floor (PIX-292: its shortcut's
## door, or a way out opened where its boss fell): a lamp of daylight over
## it that breathes, and its plate as the hero comes near - "Way out", and
## where it leads (depths.json `sign`).
static func light_way_out(view: MapView, cell: Vector2i) -> void:
	var door := Depths.shortcut_on(view.data.id)
	# The door in the rock spills its daylight onto the floor before it, as a
	# torch in the wall does; a way out in the floor lights round itself.
	var spill := Vector2(0, TILE * 0.7) if door.get("cell") == cell else Vector2.ZERO
	var lamp := Lights.make(MapView.center(cell) + spill, WAY_OUT_GLOW, Lights.WAY_OUT, Lights.WAY_OUT_ENERGY)
	lamp.set_meta("pulse", true)
	view.props.add_child(lamp)
	sign_way_out(view, cell)


## A way out's plate as the hero comes near (PIX-292): "Way out", and where
## it leads; a stair rising where a boss fell (StairRise) gets it once open.
static func sign_way_out(view: MapView, cell: Vector2i) -> void:
	var about := String(Depths.shortcut_on(view.data.id).get("sign", ""))
	view.door_signs.append({"door": cell, "name": Text.t("Way out"), "about": about, "node": null, "over": WAY_OUT_PLATE})
