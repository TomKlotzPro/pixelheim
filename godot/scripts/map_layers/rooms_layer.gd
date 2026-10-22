class_name RoomsLayer
extends MapLayer
## areas: town rooms travel +town-age*
## Inside, Shade's rooms with the paid pack or from his CC0 sheets
## (PunyInterior, PIX-133, PIX-163, PIX-318): the room planned, then drawn
## with its windows and the ice cave's stair frost; MapView's `plan_room`
## and `ground_room` units (PIX-359).


## The room planned.
func plan(view: MapView, slices: Slicer) -> void:
	slices.add("plan_room", func() -> void: _plan_room(view))


## A room's floor, walls and furniture in the ground's slot.
func build(view: MapView, slices: Slicer) -> void:
	if view.data.style != "cave" and view.buildings.has("floor"):
		slices.add("ground_room", func() -> void: view._ground_root(_build_room(view, view.data)))


## Inside, Shade's rooms (PunyInterior): furniture spreading onto the floor
## blocks it, like the rest of the furniture.
static func _plan_room(view: MapView) -> void:
	if not PunyInterior.is_room(view.data.id):
		return
	# Without the paid pack, from Shade's CC0 sheets (PIX-318): it stood on
	# grass.
	if not PunyTown.available():
		_plan_free_room(view)
		return
	var room: Dictionary = PunyInterior.plan(view.data.id, view.data.grid)
	# Then Shade's furnished corners (PIX-163), clear of the way in, the
	# keepers and the hero's own furniture.
	var placed: Array = GameState.household.furniture() if view.data.id == "town_house" else []
	var dressed := PunyInterior.furnish(view.data.id + view.data.variant, view.data.grid, PunyInterior.reserved(view.data, placed))
	view.buildings = {
		"pieces": room["pieces"], "decor": {}, "freed": [], "floor": room["floor"], "walls": room["walls"], "void": room["void"], "over": room["over"],
		"rug": dressed["rug"], "objects": dressed["objects"], "tops": dressed["tops"], "lifted": dressed["lifted"], "art": dressed["art"],
	}
	RoomArt.shut_books(view.buildings["art"], Letters.shut_on(view.data.id, GameState.progression))
	for cell: Vector2i in room["blocked"] + dressed["blocked"]:
		view.data.grid[cell] = "wall"


## A room without the paid pack (PIX-318, PunyInterior.plan_free): his
## dungeon's walls and his pier's boards, and what furniture has a CC0
## likeness, his corners' that do (furnish_free) clear of the way in, the
## keepers and the hero's own furniture; what they stand on blocks.
static func _plan_free_room(view: MapView) -> void:
	var room := PunyInterior.plan_free(view.data.id, view.data.grid)
	var placed: Array = GameState.household.furniture() if view.data.id == "town_house" else []
	var dressed := PunyInterior.furnish_free(view.data.id + view.data.variant, view.data.grid, PunyInterior.reserved(view.data, placed))
	view.buildings = room.merged({"decor": {}, "freed": [], "objects": dressed["objects"], "flames": dressed["flames"]})
	view.buildings["rug"] = (dressed["rug"] as Dictionary).merged(room["rug"], true)
	RoomArt.shut_books(view.buildings["objects"], Letters.shut_on(view.data.id, GameState.progression))
	for cell: Vector2i in dressed["blocked"]:
		view.data.grid[cell] = "wall"


## A room in Shade's Medieval Age pack (PunyInterior): the dark beyond its
## walls, the floor, walls and rugs, then door and furniture (on the walls
## where they lean on them, PIX-237), then his furnished corners (PIX-163):
## what stands, what stands on it, and what sits on that, 6 px up as in his
## samples. The windows' glass is full of the day until night, under what
## leans on the wall; a keeper's pieces drawn in code (RoomArt, PIX-315)
## stand with the furniture.
static func _build_room(view: MapView, data: MapData) -> Node2D:
	if view.buildings.get("free", false):
		return _build_free_room(view, data)
	var root := Node2D.new()
	root.add_child(MapView._dark_beyond(data))
	var frost := _stair_frost(view, data, root)
	for part: String in ["floor", "walls", "rug", "pieces", "objects", "tops", "lifted"]:
		var layer := MapView.tile_layer_of(PunyTown.tileset())
		for cell: Vector2i in view.buildings.get(part, {}):
			PunyTown.place(layer, cell, view.buildings[part][cell])
		if part == "lifted":
			layer.position.y = -6
		if frost != null and part in ["floor", "rug", "pieces"]:
			layer.material = frost
		root.add_child(layer)
		if part == "walls":
			_day_windows(view, root)
		elif part == "objects":
			for cell: Vector2i in view.buildings.get("art", {}):
				var piece := Sprite2D.new()
				piece.texture = RoomArt.texture(view.buildings["art"][cell])
				piece.centered = false
				piece.position = Vector2(cell * TILE)
				root.add_child(piece)
	return root


## A room without the paid pack (PIX-318, PunyInterior.plan_free), as
## _build_room draws one with it: the dark beyond, the floor, the walls
## and their windows (the day in their recess until night), the rugs, then
## the doors and furniture and his furnished corners' likenesses; Liane's
## frost over the floor, rugs and stair as with the pack.
static func _build_free_room(view: MapView, data: MapData) -> Node2D:
	var root := Node2D.new()
	root.add_child(MapView._dark_beyond(data))
	var frost := _stair_frost(view, data, root)
	for part: String in ["floor", "walls", "rug", "pieces", "objects"]:
		for node: Node2D in _free_pieces(view.buildings.get(part, {})):
			if frost != null and part in ["floor", "rug", "pieces"] and node is TileMapLayer:
				node.material = frost
			root.add_child(node)
		if part == "walls":
			_free_windows(view, root)
	return root


## CC0 pieces (PunyInterior's "<sheet>:<tile>") drawn: a tile layer for each
## of Shade's sheets and DungeonArt's in use, then the pieces drawn in code
## as sprites on their cells (a forge's fire glowing in its mouth).
static func _free_pieces(pieces: Dictionary) -> Array[Node2D]:
	var layers := {}
	var sprites: Array[Node2D] = []
	for cell: Vector2i in pieces:
		var piece := PunyInterior.free_piece(pieces[cell])
		var sheet: String = piece[0]
		match sheet:
			"d", "w", "a":
				match sheet:
					"d":
						if not layers.has(sheet):
							layers[sheet] = MapView.tile_layer_of(PunyDungeon.sheet().tileset)
						PunyDungeon.sheet().place(layers[sheet], cell, piece[1])
					"w":
						if not layers.has(sheet):
							layers[sheet] = MapView.tile_layer_of(PunyTerrain.tileset())
						PunyTerrain.place(layers[sheet], cell, piece[1])
					"a":
						if not layers.has(sheet):
							layers[sheet] = MapView.tile_layer_of(DungeonArt.tileset())
						DungeonArt.place(layers[sheet], cell, piece[1])
			"h", "r":
				var sprite := Sprite2D.new()
				sprite.texture = HamletArt.texture(piece[1]) if sheet == "h" else RoomArt.texture(piece[1])
				sprite.centered = false
				sprite.position = Vector2(cell * TILE)
				sprites.append(sprite)
				if piece[1] == "forge_stack":
					var fire := Sprite2D.new()
					fire.texture = HamletArt.texture("forge_mouth")
					fire.centered = false
					fire.material = Lights.unshaded()
					fire.position = sprite.position
					sprites.append(fire)
	var out: Array[Node2D] = []
	for sheet: String in ["d", "w", "a"]:
		if layers.has(sheet):
			out.append(layers[sheet])
	out.append_array(sprites)
	return out


## A CC0 room's windows (PIX-318): the recess in the wall's face, and by day
## the sky in it, bright whatever the room's own light, shown until night.
static func _free_windows(view: MapView, root: Node2D) -> void:
	var recesses := MapView.tile_layer_of(DungeonArt.tileset())
	for cell: Vector2i in view.buildings.get("windows", []):
		DungeonArt.place(recesses, cell, "window")
	root.add_child(recesses)
	for cell: Vector2i in view.buildings.get("windows", []):
		var pane := Sprite2D.new()
		pane.texture = LampArt.recess_panes()
		pane.centered = false
		pane.position = Vector2(cell * TILE)
		pane.material = Lights.unshaded()
		root.add_child(pane)
		view.day_glows.append(pane)


## A room's windows by day (PIX-311): the sky in their glass, bright whatever
## the room's own light, shown until night.
static func _day_windows(view: MapView, root: Node2D) -> void:
	var glass := LampArt.day_panes()
	for cell: Vector2i in view.buildings.get("walls", {}):
		if view.buildings["walls"][cell] != PunyTown.WINDOW or glass == null:
			continue
		var pane := Sprite2D.new()
		pane.texture = glass
		pane.centered = false
		pane.position = Vector2(cell * TILE)
		pane.material = Lights.unshaded()
		root.add_child(pane)
		view.day_glows.append(pane)


## The ice cave's stair down through Liane's floor (PIX-290, EntranceArt):
## frost creeps out over the boards, the carpet and the stair
## (shaders/stair_frost.gdshader: rime and crystals in its blues, cold
## under the room's warm light, PIX-317), and the cold's pale light comes
## up it, keeping the way down seen at night. The material, or null in a
## room with no such stair.
static func _stair_frost(view: MapView, data: MapData, root: Node2D) -> ShaderMaterial:
	var stairs := EntranceArt.frosted_stairs(data)
	if stairs.is_empty():
		return null
	var stair := stairs[0]
	root.add_child(Lights.make(MapView.center(stair), EntranceArt.FROST_GLOW, Lights.ICE, EntranceArt.FROST_ENERGY))
	var frost := ShaderMaterial.new()
	frost.shader = preload("res://shaders/stair_frost.gdshader")
	frost.set_shader_parameter("stair", MapView.center(stair) + view.offset)
	frost.set_shader_parameter("reach", EntranceArt.FROST_REACH * TILE)
	frost.set_shader_parameter("rim_range", EntranceArt.FROST_RIM)
	frost.set_shader_parameter("stair_half", TILE / 2.0)
	frost.set_shader_parameter("warm_sharpness", EntranceArt.WARM_SHARPNESS)
	for tone: String in EntranceArt.FROST_TONES:
		var color: Color = EntranceArt.FROST_TONES[tone]
		frost.set_shader_parameter(tone, Vector3(color.r, color.g, color.b))
	return frost
