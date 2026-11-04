class_name MapGround
## areas: travel
## The map screen's ground (PIX-403): each cell painted from the terrain the
## world draws it with, Shade's CC0 overworld tiles (PunyTerrain) shrunk to
## the page's pixels a cell, so the woods, the water, the snow, the Ash and
## the village read on the page as they do underfoot. One flat colour a tile
## made the world a quilt of swatches. A ground the world tones keeps its
## texture in the tone the world's tint mask gives it (PunyTerrain.toned_as:
## the Ash, the mire, the pass's stone, and a region's every ground, the
## Frostgate's snow and the Mountain Road's ash), so the page shows no green
## the world doesn't. The rock is drawn as rock, not as the grassy top Shade
## draws his cliffs with, so the page shows where the land is shut; what the
## ground doesn't draw (roofs, the rampart, bridges, fields, the rooms'
## floors) keeps its flat colour, lightly grained.

## The tiles painted from the ground's own tiles; the rest are flat.
const TEXTURED := [
	"grass", "flowers", "forest", "water", "path", "sand", "marsh", "ash",
	"shore", "sea", "deep_sea", "snow", "ice", "stone",
]
## The rock: flat in its own grey (the ridges' and the mountains' on the
## page before PIX-403), or in a toned region its tone ROCK_SHADE darker, a
## cliff's face in the snow or the ash, so it never reads as the ground.
const ROCK := ["mountain"]
const ROCK_SHADE := 0.35
## How many of a terrain's tiles a page mixes, picked by the cell, so a field
## isn't one stamp repeated.
const VARIANTS := 4
## The untoned grounds' brightness and saturation on the page.
const GRADE := Vector2(0.8, 0.8)

## "tile:tone:px:variant:dim" -> its cell's Image, made once a session.
static var _swatches := {}
## The overworld sheet, decoded while swatches are cut and let go after the
## paint (as PunySheet lets go of its own, PIX-269): the swatches are kept.
static var _sheet: Image


## The page `cells` big at `px` pixels a cell: `ground` (page cell -> tile
## id) painted in its `regions`' tones (page cell -> region id), the night
## everywhere else; each cell `dim` of the way to the night (the lookout's
## panorama), in plain colour values as its flat colours were: a see-through
## night over the page reads far lighter on the desktop's linear canvas.
static func paint(cells: Vector2i, px: int, ground: Dictionary, regions: Dictionary, dim := 0.0) -> Image:
	var image := Image.create_empty(maxi(1, cells.x * px), maxi(1, cells.y * px), false, Image.FORMAT_RGBA8)
	image.fill(UiStyle.NIGHT)
	var whole := Rect2i(0, 0, px, px)
	# tile -> region -> its VARIANTS swatches, so a cell costs no key of its own.
	var cut := {}
	for cell: Vector2i in ground:
		var tile: String = ground[cell]
		var region: String = regions.get(cell, "")
		var in_region: Dictionary = cut.get_or_add(tile, {})
		if not in_region.has(region):
			var tone := tone_of(tile, region)
			in_region[region] = range(VARIANTS).map(func(variant: int) -> Image: return swatch(tile, px, variant, dim, tone))
		image.blit_rect(in_region[region][absi(hash(cell)) % VARIANTS], whole, cell * px)
	_sheet = null
	return image


## The tone `tile` takes in `region` (a PunyTerrain.TINTS key, "" for
## none): the world's tint mask's where the page draws the ground or the
## rock; the water keeps its own, as region_tint.gdshader keeps it.
static func tone_of(tile: String, region: String) -> String:
	if tile in PunyTerrain.WATERS or not (tile in TEXTURED or tile in ROCK):
		return ""
	return PunyTerrain.toned_as(tile, region)


## One cell of `tile`, `px` pixels square, toned `tone` (tone_of): its
## ground's tile `variant` (forests its pines' crowns over the grass) shrunk
## to it, or the rock's or its flat colour grained; `dim` of the way to the
## night.
static func swatch(tile: String, px: int, variant: int, dim := 0.0, tone := "") -> Image:
	var key := "%s:%s:%d:%d:%s" % [tile, tone, px, variant, dim]
	if _swatches.has(key):
		return _swatches[key]
	var cut: Image
	if tile in TEXTURED:
		cut = _tile(PunyTerrain.ground_of(tile), variant)
		if tile == "forest":
			cut.blend_rect(_tile("trees", variant), Rect2i(0, 0, PunyTerrain.TILE, PunyTerrain.TILE), Vector2i.ZERO)
		# The ice is its lake's blue over the snow, in any region.
		if tile == "ice" or tone != "":
			_tone(cut, Atlas.color(tile) if tile == "ice" else PunyTerrain.TINTS[tone])
		else:
			# Shade's sheet is brighter than his ground looks lit in the world.
			cut.adjust_bcs(GRADE.x, 1.0, GRADE.y)
		cut.resize(px, px, Image.INTERPOLATE_TRILINEAR)
	else:
		cut = Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
		var flat: Color = PunyTerrain.TINTS[tone].darkened(ROCK_SHADE) if tile in ROCK and tone != "" else Atlas.color(tile)
		for y in px:
			for x in px:
				cut.set_pixel(x, y, flat.darkened(0.06) if (x + y + variant) % 3 == 0 else flat)
	cut.convert(Image.FORMAT_RGBA8)
	if dim > 0.0:
		for y in px:
			for x in px:
				var pixel := cut.get_pixel(x, y)
				cut.set_pixel(x, y, Color(pixel.lerp(UiStyle.NIGHT, dim), pixel.a))
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
