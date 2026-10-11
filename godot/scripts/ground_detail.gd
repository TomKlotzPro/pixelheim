class_name GroundDetail
## The small things in the grass (PIX-305): tufts, clover, flowers, pebbles,
## twigs, and the mire's reeds and sedge, which Scatter.detail picks a cell
## at a time. Drawn here a pixel per letter in Shade's own Puny World and
## Medieval Age colours, in his manner (blades lit at the tip, shade at the
## foot, light from the top left), so they look the same with or without the
## paid pack; laid flat on the ground on a tile layer (MapView), toned with
## the region like the rest of the field's decor, and never in the way.

## Each kind's drawing, a pixel a letter ("." clear). A tile holds one, at
## one of VARIANTS' spots, mirrored for the odd ones, so no two neighbours
## look stamped.
const DRAWINGS := {
	"tuft": [
		"..L..L..",
		"L.BL.BL.",
		"LBLMLBLL",
		"DMLDMLDM",
		".DMDDMD.",
	],
	"tuft_small": [
		".L.L.",
		"LBLBL",
		"DMLMD",
		".DDD.",
	],
	"clover": [
		".GG.GG.",
		"GMLGMLG",
		".GGgGG.",
		"..GMLG.",
		"...Gg..",
	],
	"flowers_white": [
		".w.....",
		"wyw..w.",
		".w..wyw",
		".D...w.",
		".D.w.D.",
		"..wyw..",
		"...D...",
	],
	"flowers_yellow": [
		"..y....",
		".yoy.y.",
		"..y.yoy",
		"..D..y.",
		".y...D.",
		"yoy..D.",
		".y.....",
	],
	"flowers_red": [
		".r...r.",
		"rRr.rRr",
		".r...r.",
		".D.r.D.",
		"..rRr..",
		"...r...",
		"...D...",
	],
	"flowers_blue": [
		"..v..",
		".vVv.",
		"..v.v",
		"..DvV",
		"...Dv",
	],
	"pebbles": [
		"..ss...",
		".sSSz..",
		".zSz.s.",
		"..z.sSz",
		".....z.",
	],
	"twig": [
		"T......",
		".tT..T.",
		"..tTtT.",
		"....Tt.",
		".....T.",
	],
	"reeds": [
		".c...c.",
		".c.c.c.",
		".L.c.D.",
		".D.D.L.",
		"LD.DLD.",
		"DGLGDG.",
	],
	"sedge": [
		"L.....L",
		".L.L.L.",
		".DLDLD.",
		"..DGD..",
	],
}
## The colours, Shade's: his grass's light, dark and mid tufts, the Medieval
## Age's deeper greens, a bright tip; petals white, yellow, rose and
## lavender with their hearts; his stones and twig; a cattail's brown.
const INKS := {
	"L": Color("9fb747"), "D": Color("7e9e3f"), "M": Color("96b146"), "G": Color("6b9447"),
	"g": Color("506930"), "B": Color("b4ce45"),
	"w": Color("f2f2f2"), "y": Color("f1d068"), "o": Color("cbae41"), "r": Color("da866d"),
	"R": Color("b46150"), "v": Color("9a98e4"), "V": Color("8774b7"),
	"s": Color("b2ba82"), "S": Color("787f4f"), "z": Color("4b4f2b"),
	"t": Color("d4a753"), "T": Color("67463d"), "c": Color("603616"),
}
## Where in its cell a drawing's top-left stands, by variant (in pixels);
## the odd variants are mirrored.
const VARIANTS: Array[Vector2i] = [Vector2i(2, 3), Vector2i(7, 6), Vector2i(4, 8), Vector2i(8, 2)]
const TILE := 16

static var _tileset: TileSet
static var _kinds: Array = []


## The kinds in the sheet's order.
static func kinds() -> Array:
	if _kinds.is_empty():
		_kinds = DRAWINGS.keys()
		_kinds.sort()
	return _kinds


## The sheet's tile for a kind's variant: a column per variant, a row per
## kind.
static func coords(kind: String, variant: int) -> Vector2i:
	return Vector2i(variant % VARIANTS.size(), kinds().find(kind))


## Every drawing at every spot, one sheet, drawn once; every tile made with
## the tileset, so laying one never changes it (One Reach, PIX-269).
static func tileset() -> TileSet:
	if _tileset == null:
		var image := Image.create(TILE * VARIANTS.size(), TILE * kinds().size(), false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		for row in kinds().size():
			var drawing: Array = DRAWINGS[kinds()[row]]
			for variant in VARIANTS.size():
				_draw(image, drawing, Vector2i(variant * TILE, row * TILE) + VARIANTS[variant], variant % 2 == 1)
		_tileset = TileSet.new()
		_tileset.tile_size = Vector2i(TILE, TILE)
		var source := TileSetAtlasSource.new()
		source.texture = ImageTexture.create_from_image(image)
		source.texture_region_size = Vector2i(TILE, TILE)
		_tileset.add_source(source, 0)
		for row in kinds().size():
			for variant in VARIANTS.size():
				source.create_tile(Vector2i(variant, row))
	return _tileset


static func _draw(image: Image, drawing: Array, at: Vector2i, mirrored: bool) -> void:
	for y in drawing.size():
		var line: String = drawing[y]
		for x in line.length():
			var ink := line[line.length() - 1 - x] if mirrored else line[x]
			if INKS.has(ink):
				image.set_pixel(at.x + x, at.y + y, INKS[ink])


## Lays `cell`'s detail (`tile`: Scatter.detail_tile's) on `layer`.
static func place(layer: TileMapLayer, cell: Vector2i, tile: Vector2i) -> void:
	layer.set_cell(cell, 0, tile)
