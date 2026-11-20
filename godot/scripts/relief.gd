class_name Relief
## areas: town field night dungeon rooms
## Light relief's materials and the stone it carves (PIX-528, PIX-529): what
## a map draws with no material of its own wears shaders/relief.gdshader, a
## sprite standing among the actors (a prop, a lamp post, a crate, a stall,
## a cart, a room's furniture) domed from its outline, a tile layer (the
## town's flags, a keep's stone walls, the rampart) carved from its stones'
## joints, so the lamps and the lantern shape them by their forms
## (shaders/relief.gdshaderinc). Which of the Medieval Age's tiles are stone
## (carved()) is worked out from their ids alone, never from the pack's
## pixels. MapView dresses its drawing once it stands, and what comes to
## stand among the actors later.

## The forms, as relief.gdshaderinc's RELIEF_PLAIN, CARVED and DOMED.
const PLAIN := 0
const CARVED := 1
const DOMED := 2
## How much darker than a stone its joint is: one tone step (the
## sandstone's 10%, the floors' and the walls' more).
const JOINT := 0.08
## The cobbles' step: a mottle of three tones, only the darkest a joint.
const MOTTLED := 0.17

static var _materials := {}
static var _joints: ImageTexture


## The one material every piece of a `form` shares (`tiles`: a tile layer,
## its taps kept on its tile of the TileSet's padded sheet).
static func material(form: int, tiles: bool) -> ShaderMaterial:
	var key := form * 2 + int(tiles)
	if not _materials.has(key):
		var made := ShaderMaterial.new()
		made.shader = preload("res://shaders/relief.gdshader")
		made.set_shader_parameter("relief_form", form)
		made.set_shader_parameter("relief_tiles", tiles)
		made.set_shader_parameter("relief_joints", joints())
		_materials[key] = made
	return _materials[key]


## `node` and everything under it: each tile layer with no material of its
## own, nor its parent's, carved; each such sprite domed when it stands
## (`standing`: among the actors), left flat when it lies under them (a
## rug, a door sign, a pickup). Never an animated sprite (flames, the
## fountain's jet, boats, animals), never what has a material already
## (unshaded, a glow, the ground's toning, see-through), never a
## character's (on_character).
static func dress(node: Node, standing := true) -> void:
	var pieces := node.find_children("*", "", true, false)
	pieces.append(node)
	for piece: Node in pieces:
		if not (piece is TileMapLayer or (standing and piece is Sprite2D)):
			continue
		var item := piece as CanvasItem
		if item.material == null and not item.use_parent_material and not on_character(piece):
			item.material = material(CARVED, true) if piece is TileMapLayer else material(DOMED, false)


## Whether `piece` is part of the hero, a foe, a villager or an animal (its
## ground shadow, the hero's ailment icon): characters stay lit as they were,
## a 14 px face would turn to bumps.
static func on_character(piece: Node) -> bool:
	var at := piece
	while at != null:
		if at is CharacterBody2D or at is AnimatableBody2D:
			return true
		at = at.get_parent()
	return false


## How many pieces under `node` wear material() (the report's relief=).
static func worn(node: Node) -> int:
	var ours := _materials.values()
	if ours.is_empty():
		return 0
	return node.find_children("*", "", true, false).filter(func(piece: Node) -> bool: return piece is CanvasItem and (piece as CanvasItem).material in ours).size()


## The Medieval Age's stone, tile id -> how much darker its joints are:
## every paving's fill but the gravel's (pebbles, no joints), the cobbles'
## at MOTTLED; every set's edge stones (edges()), at MOTTLED; a room's
## stone floor and planks; the keep's and Morvax's stone walls (not the
## town's plaster); the rampart's walls and towers. In the shader a big
## stone is bevelled, a small one (a brick's 3-px row) a pillow, a mottle
## (a cobble, an edge stone) lumped (PIX-529's pictures).
static func carved() -> Dictionary:
	var out := {}
	for look: String in Streets.LOOKS:
		var paving: Dictionary = Streets.LOOKS[look]
		if look == "gravel":
			continue
		for fill: Array in paving["fill"]:
			out[int(fill[1]) * PunyTown.COLUMNS + int(fill[0])] = MOTTLED if paving["fill"] == Streets.COBBLES else JOINT
	for tile: int in edges():
		out[tile] = MOTTLED
	var walls: Array = []
	for offset: int in PunyInterior.WALL_SETS.values():
		walls.append_array(PunyInterior.WALLS.values().map(func(tile: int) -> int: return tile + offset))
	for tile: int in PunyInterior.STONE + PunyInterior.PLANKS + walls + Rampart.WALL.values() + Rampart.TOWER:
		out[tile] = JOINT
	return out


## Every paving's edge stones but the gravel's (its 12x4 block's pieces):
## small soft stones in a mottle as the cobbles are, and no fill, so the
## shader keeps its taps on the piece (a street one cell wide is all edge).
static func edges() -> Array[int]:
	var out: Array[int] = []
	for look: String in Streets.LOOKS:
		var paving: Dictionary = Streets.LOOKS[look]
		for row: int in Streets.BLOCK.size():
			for column: int in (Streets.BLOCK[row] as Array).size():
				var edge := Vector2i(paving["edges"]) + Vector2i(column, row)
				var tile := edge.y * PunyTown.COLUMNS + edge.x
				if look != "gravel" and int(Streets.BLOCK[row][column]) >= 0 and tile not in out:
					out.append(tile)
	return out


## carved() as a texture, a texel a tile of the sheet (its red the step, 0
## for no stone; its green 1 for an edge stone, its taps mirrored at the
## piece's edge, not wrapped), for the shaders' `relief_joints`: made from ids, with the pack
## or without.
static func joints() -> ImageTexture:
	if _joints == null:
		var map := Image.create(PunyTown.COLUMNS, PunyTown.ROWS, false, Image.FORMAT_RG8)
		var stone := carved()
		var edge := edges()
		for tile: int in stone:
			map.set_pixel(tile % PunyTown.COLUMNS, tile / PunyTown.COLUMNS, Color(stone[tile], 1.0 if tile in edge else 0.0, 0.0))
		_joints = ImageTexture.create_from_image(map)
	return _joints
