class_name Relief
## areas: town field night dungeon rooms
## Light relief's plain material (PIX-528): what a map draws with no
## material of its own (a prop, a lamp post, a crate, a stall, a cart, a
## room's furniture) wears shaders/relief.gdshader, so the lamps and the
## lantern shape it as they shape the ground and the houses
## (region_tint, roof_light). MapView dresses its drawing once it stands,
## and what comes to stand among the actors later.

static var _material: ShaderMaterial
static var _tiles: ShaderMaterial


## The one material every plain sprite shares, or every plain tile layer
## (`tiles`: its taps never clamped to a tile, as a TileSet pads its tiles).
static func material(tiles := false) -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/relief.gdshader")
		_tiles = _material.duplicate() as ShaderMaterial
		_tiles.set_shader_parameter("cut", false)
	return _tiles if tiles else _material


## `node` and everything under it: each sprite and tile layer with no
## material of its own, nor its parent's, wears material(). Never an
## animated sprite (flames, the fountain's jet, boats, animals), never what
## has a material already (unshaded, a glow, the ground's toning, see-through).
static func dress(node: Node) -> void:
	var pieces := node.find_children("*", "", true, false)
	pieces.append(node)
	for piece: Node in pieces:
		if (piece is Sprite2D or piece is TileMapLayer) and (piece as CanvasItem).material == null and not (piece as CanvasItem).use_parent_material:
			(piece as CanvasItem).material = material(piece is TileMapLayer)


## How many pieces under `node` wear material() (the report's relief=).
static func worn(node: Node) -> int:
	if _material == null:
		return 0
	return node.find_children("*", "", true, false).filter(func(piece: Node) -> bool: return piece is CanvasItem and (piece as CanvasItem).material in [_material, _tiles]).size()
