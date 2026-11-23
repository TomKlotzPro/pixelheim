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
## sandstone's 10%, the walls' more).
const JOINT := 0.08
## The pavings carved: great flags, each stone wider than its bevels.
const FLAGS := ["flags", "sandstone", "mossy"]

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
## the great flags' fills (FLAGS), the keep's and Morvax's stone walls (not
## the town's plaster), the rampart's walls and towers. All else lies flat,
## as PIX-529's pictures had it: the gravel (pebbles, no joints); the
## cobbles, the setts and every set's edge stones (a mottle: lumped, a
## band of slanted dark hatch strokes round the City's basket and the
## observatory yard's rim); the basket's bricks, a room's stone floor and
## planks (3-px rows: pillowed, a bright row over a dark one, a
## corrugation).
static func carved() -> Dictionary:
	var out := {}
	for look: String in FLAGS:
		for fill: Array in Streets.LOOKS[look]["fill"]:
			out[int(fill[1]) * PunyTown.COLUMNS + int(fill[0])] = JOINT
	var walls: Array = []
	for offset: int in PunyInterior.WALL_SETS.values():
		walls.append_array(PunyInterior.WALLS.values().map(func(tile: int) -> int: return tile + offset))
	for tile: int in walls + Rampart.WALL.values() + Rampart.TOWER:
		out[tile] = JOINT
	return out


## carved() as a texture, a texel a tile of the sheet (its red the step, 0
## for no stone), for the shaders' `relief_joints`: made from ids, with the
## pack or without.
static func joints() -> ImageTexture:
	if _joints == null:
		var map := Image.create(PunyTown.COLUMNS, PunyTown.ROWS, false, Image.FORMAT_R8)
		var stone := carved()
		for tile: int in stone:
			map.set_pixel(tile % PunyTown.COLUMNS, tile / PunyTown.COLUMNS, Color(stone[tile], 0.0, 0.0))
		_joints = ImageTexture.create_from_image(map)
	return _joints
