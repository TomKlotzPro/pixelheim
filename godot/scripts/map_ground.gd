class_name MapGround
## areas: travel
## The map screen's ground (PIX-403): each cell painted from the terrain the
## world draws it with, Shade's CC0 overworld tiles (PunyTerrain) shrunk to
## the page's pixels a cell, so the woods, the water, the snow, the Ash and
## the village read on the page as they do underfoot. One flat colour a tile
## made the world a quilt of swatches. The grounds the world tones (the Ash,
## the mire, the snow, the pass's stone) keep their texture in the map's
## colour for them, as region_tint.gdshader tones them; what the ground
## doesn't draw (roofs, the rampart, bridges, fields, the rooms' floors)
## keeps its flat colour, lightly grained.

## The tiles painted from the ground's own tiles; the rest are flat.
const TEXTURED := [
	"grass", "flowers", "forest", "mountain", "water", "path", "sand", "marsh", "ash",
	"shore", "sea", "deep_sea", "snow", "ice", "stone",
]
## The grounds the world tones from Shade's grass and dirt (PunyTerrain.TINTS):
## their texture in the map's colour for them.
const TONED := ["ash", "marsh", "snow", "ice", "stone"]
## How many of a terrain's tiles a page mixes, picked by the cell, so a field
## isn't one stamp repeated.
const VARIANTS := 4
## The untoned grounds' brightness and saturation on the page.
const GRADE := Vector2(0.8, 0.8)

## "tile:px:variant" -> its cell's Image, made once a session.
static var _swatches := {}
static var _sheet: Image


## The page `cells` big at `px` pixels a cell: `ground` (page cell -> tile
## id) painted, the night everywhere else.
static func paint(cells: Vector2i, px: int, ground: Dictionary) -> Image:
	var image := Image.create_empty(maxi(1, cells.x * px), maxi(1, cells.y * px), false, Image.FORMAT_RGBA8)
	image.fill(UiStyle.NIGHT)
	var whole := Rect2i(0, 0, px, px)
	for cell: Vector2i in ground:
		image.blit_rect(swatch(ground[cell], px, absi(hash(cell)) % VARIANTS), whole, cell * px)
	return image


## One cell of `tile`, `px` pixels square: its ground's tile `variant`
## (forests its pines' crowns over the grass) shrunk to it, or its flat
## colour grained.
static func swatch(tile: String, px: int, variant: int) -> Image:
	var key := "%s:%d:%d" % [tile, px, variant]
	if _swatches.has(key):
		return _swatches[key]
	var cut: Image
	if tile in TEXTURED:
		cut = _tile(PunyTerrain.ground_of(tile), variant)
		if tile == "forest":
			cut.blend_rect(_tile("trees", variant), Rect2i(0, 0, PunyTerrain.TILE, PunyTerrain.TILE), Vector2i.ZERO)
		if tile in TONED:
			_tone(cut, Atlas.color(tile))
		else:
			# Shade's sheet is brighter than his ground looks lit in the world.
			cut.adjust_bcs(GRADE.x, 1.0, GRADE.y)
		cut.resize(px, px, Image.INTERPOLATE_TRILINEAR)
	else:
		cut = Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
		var flat := Atlas.color(tile)
		for y in px:
			for x in px:
				cut.set_pixel(x, y, flat.darkened(0.06) if (x + y + variant) % 3 == 0 else flat)
	cut.convert(Image.FORMAT_RGBA8)
	_swatches[key] = cut
	return cut


## The overworld tile all of whose corners are `terrain`, the `variant`th.
static func _tile(terrain: String, variant: int) -> Image:
	if _sheet == null:
		_sheet = (load(PunyTerrain.SHEET) as Texture2D).get_image()
		if _sheet.is_compressed():
			_sheet.decompress()
		_sheet.convert(Image.FORMAT_RGBA8)
	var id := PunyTerrain.corner_tile([terrain, terrain, terrain, terrain], variant)
	return _sheet.get_region(Rect2i(PunyTerrain.sheet().region(id)))


## Recolours `image` to `tone`, keeping its light and shade: each pixel's
## brightness against the tile's mean scales the tone.
static func _tone(image: Image, tone: Color) -> void:
	var mean := 0.0
	for y in image.get_height():
		for x in image.get_width():
			mean += image.get_pixel(x, y).get_luminance()
	mean = maxf(mean / (image.get_width() * image.get_height()), 0.01)
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			var light := clampf(pixel.get_luminance() / mean, 0.7, 1.3)
			image.set_pixel(x, y, Color(tone.r * light, tone.g * light, tone.b * light, pixel.a))
