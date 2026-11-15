class_name PuddlesLayer
extends MapLayer
## areas: field town night
## What the rain leaves on a map under the sky (PIX-491): one sheet over
## the ground and everything lying flat on it, under what stands, drawn by
## shaders/puddles.gdshader - the ground darker while it is wet, and
## puddles gathering in the hollows of the paths and, fewer, of the grass,
## mirroring the sky by day and the lamps, the lantern and the lightning
## at night. Where puddles may lie is a mask of the map's own cells (a
## cell a texel: paths whole, grass less, nothing on water, rock, sand,
## snow, ash or under a roof), read softly so no puddle ends on a cell's
## edge; how wet and how full is the Storm node's, from Weather's clock.
## The same with the paid art or without: it reads the map, not the art.

## The sheets' group: the Storm node shows them only while the ground is
## wet or a puddle is left, so a dry day pays nothing.
const GROUP := "puddles"
## How readily a puddle gathers on each tile, 0..1; none on the rest.
const GATHERS := {"path": 1.0, "stone": 1.0, "lamp": 1.0, "grass": 0.5, "flowers": 0.3}

func build(view: MapView, slices: Slicer) -> void:
	if not Lights.under_sky(view.data):
		return
	slices.add("puddles", func() -> void:
		if view.ground == null or not is_instance_valid(view.ground):
			return
		var sheet := Sprite2D.new()
		sheet.texture = mask(view.data)
		sheet.centered = false
		sheet.scale = Vector2(TILE, TILE)
		sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		sheet.material = _material()
		# The floor's bit, so the lamps' and the lightning's shadows fall on
		# the puddles as on the ground round them (art.md, PIX-490).
		sheet.light_mask |= Lights.FLOOR
		sheet.visible = false
		sheet.add_to_group(GROUP)
		view.ground.add_child(sheet)
		# Over the ground's own layers, under what else lies flat and the
		# scenery's shadows.
		if view.detail_layer != null and is_instance_valid(view.detail_layer) and view.detail_layer.get_parent() == view.ground:
			view.ground.move_child(sheet, view.detail_layer.get_index() + 1))


## Where puddles may gather on `map`, a cell a texel: in its red how
## readily (GATHERS), nothing where something drawn covers the cell; in
## its green a street lamp's cell, where the ground is trodden hollow
## round the post's foot, so every lamp has water to shine in.
static func mask(map: MapData) -> ImageTexture:
	var image := Image.create(map.size.x, map.size.y, false, Image.FORMAT_RGB8)
	for cell: Vector2i in map.grid:
		var lamp: bool = map.grid[cell] == "lamp"
		var gathers: float = GATHERS.get(map.grid[cell], 0.0)
		# A lamp's post covers its own cell: its hollow lies there all the same.
		if gathers > 0.0 and (lamp or not map.covered.has(cell)):
			image.set_pixelv(cell, Color(gathers, float(lamp), 0.0))
	return ImageTexture.create_from_image(image)


static var _shared: ShaderMaterial

static func _material() -> ShaderMaterial:
	if _shared == null:
		_shared = ShaderMaterial.new()
		_shared.shader = preload("res://shaders/puddles.gdshader")
	return _shared
