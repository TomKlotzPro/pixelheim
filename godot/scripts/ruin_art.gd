class_name RuinArt
## areas: travel field
## The ruins' pieces (Ruins, PIX-381), drawn once a session into one atlas:
## Shade's Puny Dungeon wall tops and faces (CC0) in each look's stone, grown
## over the look's way or knocked about on one side, then the ground at their
## foot - the shadow they cast, rubble, a tuft in a crack - and the plinth
## the shrine's stone knight stands on. The walls still standing in the open
## (StoneWalls, PIX-386) are built of the same stone, whole, a fort's with
## battlements. His stone and our own pixels in his dungeon palette: the
## same with or without the paid pack. Every tile is made with the tileset
## (a tile made later redraws every layer on it).

const TILE := 16
const COLUMNS := 16

## The looks, by the ground round a ruin (Ruins.look_of).
const LOOKS := ["wood", "mire", "snow", "ash"]
## Each look's stone, as a multiply on Shade's greys: a mossy green in the
## woods, darker and murkier in the mire, cold under snow, sooty in the ash.
const STONE := {
	"wood": Color(0.95, 0.98, 0.9), "mire": Color(0.8, 0.86, 0.76),
	"snow": Color(0.94, 0.97, 1.0), "ash": Color(0.78, 0.73, 0.72),
}
## What grows on it (or lies on it), dark to light.
const GROWTH := {
	"wood": [Color("2f5a3a"), Color("4c8a4e"), Color("7bb35a")],
	"mire": [Color("2c3a24"), Color("4a5c2e"), Color("72803c")],
	"snow": [Color("9aaabd"), Color("dfe8f0"), Color("ffffff")],
	"ash": [Color("201b1e"), Color("383034"), Color("5a4f4f")],
}
## How many clumps grow on a grown wall, by look (snow lies thickest).
const CLUMPS := {"wood": 4, "mire": 5, "snow": 7, "ash": 4}

## Shade's dungeon wall pieces a ruin is built of (PunyDungeon): tops where
## the wall ends and runs on north, faces, a lone column's foot.
const BASES := [0, 1, 2, 3, 26, 27, 28, 29, 78, 79, 80, 81, 52]
## The first BASES with no face, and where their courses of brick repeat:
## from the first mortar line (row 3) to the recess (row 9).
const TOPS := 8
const COURSES := 3
const BRICKS_FROM := 9
## How weathered a wall cell is.
const PLAIN := 0
const GROWN := 1
const CHIP_N := 2
const CHIP_W := 3
const CHIP_E := 4
const VARIANTS := 5
const WALLS := 4 * 13 * VARIANTS
## What lies on the ground at a wall's foot or on the floor.
const RUBBLE_A := 1
const RUBBLE_B := 2
const TUFT_A := 3
const TUFT_B := 4
const LITTER := 5
const SHADOWS := 4
## A wall's outer course fallen: a heap of its stones, a few of each look.
const MOUNDS_AT := WALLS + 4 * SHADOWS * LITTER
const MOUNDS := 4
## How many stones each heap is.
const HEAPED := [5, 4, 3, 2]
## A standing wall's battlements (StoneWalls, PIX-386): which sides of its
## top are lined with merlons.
const BATTLED_N := 1
const BATTLED_W := 2
const BATTLED_E := 4
## Every battled shape a standing wall takes: x its base (in BASES), y its
## battlements: a run's north end (its north and its outer side), down a run
## (its outer side), a face across (along its top). Unbattled, a standing
## wall is a ruin's PLAIN or GROWN piece.
const SHAPES := [
	Vector2i(0, 3), Vector2i(0, 5), Vector2i(1, 1), Vector2i(1, 3), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 5),
	Vector2i(4, 2), Vector2i(4, 4), Vector2i(5, 2), Vector2i(7, 4),
	Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1), Vector2i(11, 1),
]
## A standing wall's weathering, the ruins' first two: PLAIN or GROWN.
const STANDING_VARIANTS := 2
const STANDING_AT := MOUNDS_AT + 4 * MOUNDS
## The merlons: a crenel this wide every MERLON_EVERY pixels from
## CRENEL_FROM (so a run's meet the next cell's), cut this deep into a
## face's top, and into a top's sides.
const MERLON_EVERY := 8
const CRENEL_FROM := 5
const CRENEL := 3
const CRENEL_DEPTH := 3
const CRENEL_SIDE := 2
## SHAPES.size(), as a constant (test_stone_walls holds them together).
const SHAPE_COUNT := 15
const COUNT := STANDING_AT + 4 * SHAPE_COUNT * STANDING_VARIANTS

## The shadow a wall casts south and east (the light from the north-west):
## its alpha a pixel row (column) at a time from the wall's foot.
const SHADE := Color(0.06, 0.05, 0.09)
const SHADOW_S := [0.4, 0.3, 0.21, 0.13, 0.07, 0.03]
const SHADOW_E := [0.26, 0.15, 0.07, 0.02]

## Shade's dungeon greys and outline (his statue's), a letter each, for the
## stones and the plinth.
const INKS := {
	"J": Color("262726"), "B": Color("474747"), "F": Color("525252"), "H": Color("5e5e5e"),
	"E": Color("686868"), "C": Color("777777"), "I": Color("848484"), "L": Color("9a9a9a"),
}
## A fallen stone's sizes, in pixels (width, height): the rubble's at a
## wall's foot, then a heap's.
const RUBBLE_SIZE := [Vector2i(4, 3), Vector2i(6, 5)]
const HEAP_SIZE := [Vector2i(6, 4), Vector2i(9, 6)]
## A tuft, in the look's growth: d dark, m mid, l light.
const TUFT_STAMPS := [
	["l...l", ".m.m.", ".dmd."],
	[".l.", "lml", "dmd"],
	["l.l", "m.m", "dmd"],
]
## The plinth under the shrine's knight: its top face, a lip, its front.
const PLINTH := [
	"................", "................", "................", "................",
	"................", "................", "................",
	".JJJJJJJJJJJJJJ.",
	"JIIIIIIIIIIIIICJ",
	"JICCCCCCCCCCCCHJ",
	"JCCCCCCCCCCCCCHJ",
	"JHHHHHHHHHHHHHHJ",
	"JEEEEFEEEEEEFEEJ",
	"JFFFFBFFFFFFBFFJ",
	"JFFFFBFFFFFFBFFJ",
	".JJJJJJJJJJJJJJ.",
]
## How far the knight stands raised on it, in pixels.
const PLINTH_RISE := 5

static var _atlas: Image
static var _tileset: TileSet
static var _plinth: Texture2D


## A wall's tile: `look` (an index in LOOKS), `base` (in BASES), `variant`.
static func wall(look: int, base: int, variant: int) -> int:
	return (look * BASES.size() + base) * VARIANTS + variant


## The ground's tile: `shadow` (1 south, 2 east, 3 both), `litter`.
static func ground(look: int, shadow: int, litter: int) -> int:
	return WALLS + (look * SHADOWS + shadow) * LITTER + litter


## A fallen course's heap of stones: `variant` of MOUNDS.
static func mound(look: int, variant: int) -> int:
	return MOUNDS_AT + look * MOUNDS + variant


## A standing wall's tile: `look`, `shape` (in SHAPES), `variant`.
static func standing(look: int, shape: int, variant: int) -> int:
	return STANDING_AT + (look * SHAPES.size() + shape) * STANDING_VARIANTS + variant


static func coords(tile: int) -> Vector2i:
	return Vector2i(tile % COLUMNS, tile / COLUMNS)


## One TileSet over the atlas, every tile made at once.
static func tileset() -> TileSet:
	if _tileset == null:
		_tileset = TileSet.new()
		_tileset.tile_size = Vector2i(TILE, TILE)
		var source := TileSetAtlasSource.new()
		source.texture = ImageTexture.create_from_image(atlas())
		source.texture_region_size = Vector2i(TILE, TILE)
		for tile in COUNT:
			source.create_tile(coords(tile))
		_tileset.add_source(source, 0)
	return _tileset


static func place(layer: TileMapLayer, cell: Vector2i, tile: int) -> void:
	layer.set_cell(cell, 0, coords(tile))


## The plinth the shrine's knight stands on.
static func plinth() -> Texture2D:
	if _plinth == null:
		var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
		_stamp(image, PLINTH, Vector2i.ZERO, INKS, Color.WHITE)
		_plinth = ImageTexture.create_from_image(image)
	return _plinth


## Every piece, drawn once a session, each from its own seed (the same
## pixels every time).
static func atlas() -> Image:
	if _atlas != null:
		return _atlas
	_atlas = Image.create(COLUMNS * TILE, ceili(COUNT / float(COLUMNS)) * TILE, false, Image.FORMAT_RGBA8)
	var sheet: Image = (load(PunyDungeon.SHEET) as Texture2D).get_image()
	sheet.convert(Image.FORMAT_RGBA8)
	for look in LOOKS.size():
		var name: String = LOOKS[look]
		for base in BASES.size():
			var stone := _tinted(sheet, BASES[base], STONE[name])
			if base < TOPS:
				_run_bricks(stone)
			for variant in VARIANTS:
				var piece := stone.duplicate() as Image
				var dice := RandomNumberGenerator.new()
				dice.seed = hash([name, base, variant])
				if variant != PLAIN:
					_crack(piece, dice, STONE[name])
				if variant == GROWN:
					_grow(piece, dice, GROWTH[name], CLUMPS[name])
				elif variant != PLAIN:
					_chip(piece, dice, variant, STONE[name])
					_grow(piece, dice, GROWTH[name], 1)
				_atlas.blit_rect(piece, Rect2i(0, 0, TILE, TILE), coords(wall(look, base, variant)) * TILE)
				# The same stone standing with its battlements.
				for shape in SHAPES.size():
					if variant < STANDING_VARIANTS and SHAPES[shape].x == base:
						var battled := piece.duplicate() as Image
						_battle(battled, SHAPES[shape].y, STONE[name])
						_atlas.blit_rect(battled, Rect2i(0, 0, TILE, TILE), coords(standing(look, shape, variant)) * TILE)
		for shadow in SHADOWS:
			for litter in LITTER:
				var dice := RandomNumberGenerator.new()
				dice.seed = hash([name, shadow, litter, "ground"])
				_atlas.blit_rect(_ground_piece(name, shadow, litter, dice), Rect2i(0, 0, TILE, TILE), coords(ground(look, shadow, litter)) * TILE)
		for variant in MOUNDS:
			var dice := RandomNumberGenerator.new()
			dice.seed = hash([name, variant, "mound"])
			_atlas.blit_rect(_mound(name, variant, dice), Rect2i(0, 0, TILE, TILE), coords(mound(look, variant)) * TILE)
	return _atlas


## Merlons along the `battled` sides of a wall's top: crenels cut out (the
## ground shows through), the stone round each outlined as Shade outlines.
static func _battle(image: Image, battled: int, tint: Color) -> void:
	var cut := {}
	for at in range(CRENEL_FROM, TILE, MERLON_EVERY):
		for i in CRENEL:
			for d in CRENEL_DEPTH:
				if battled & BATTLED_N:
					cut[Vector2i(at + i, d)] = true
				if d < CRENEL_SIDE and battled & BATTLED_W:
					cut[Vector2i(d, at + i)] = true
				if d < CRENEL_SIDE and battled & BATTLED_E:
					cut[Vector2i(TILE - 1 - d, at + i)] = true
	for pixel: Vector2i in cut:
		image.set_pixelv(pixel, Color(0, 0, 0, 0))
	var edge := Color(INKS["B"] * tint, 1.0)
	for pixel: Vector2i in cut:
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := pixel + step
			if Rect2i(0, 0, TILE, TILE).has_point(next) and not cut.has(next) and image.get_pixelv(next).a > 0.0:
				image.set_pixelv(next, edge)


## A heap of fallen stones filling a cell (it still blocks): a dark bed
## under it, the big stones at the back, smaller ones tumbled in front, the
## look's growth between them.
static func _mound(look: String, variant: int, dice: RandomNumberGenerator) -> Image:
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in range(3, TILE):
		for x in TILE:
			var off := Vector2(x - 7.5, y - 10.0) / Vector2(8.5, 6.5)
			if off.length() < 1.0:
				image.set_pixel(x, y, Color(SHADE, 0.32 * (1.0 - off.length() * 0.6)))
	# From a heap as high as the wall stood to a few stones in the grass;
	# the back ones first, the front ones over them.
	var count: int = HEAPED[variant]
	for i in count:
		var size := Vector2i(dice.randi_range(HEAP_SIZE[0].x, HEAP_SIZE[1].x), dice.randi_range(HEAP_SIZE[0].y, HEAP_SIZE[1].y))
		var top := TILE - size.y - (count - 1 - i) * 3 - dice.randi_range(0, 1)
		_stone(image, Rect2i(Vector2i(dice.randi_range(0, TILE - size.x), maxi(0, top)), size), STONE[look])
	_grow(image, dice, GROWTH[look], 2)
	return image


## A stone lying in `rect`: a rounded block in Shade's greys, lit from the
## north-west, outlined.
static func _stone(image: Image, rect: Rect2i, tint: Color) -> void:
	var middle := Vector2(rect.position) + Vector2(rect.size - Vector2i.ONE) / 2.0
	var radius := Vector2(rect.size) / 2.0
	var inside := func(x: int, y: int) -> bool:
		var off := (Vector2(x, y) - middle) / radius
		return absf(off.x) ** 2.4 + absf(off.y) ** 2.4 < 1.05
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if x < 0 or x >= TILE or y < 0 or y >= TILE or not inside.call(x, y):
				continue
			var edge: bool = not (inside.call(x - 1, y) and inside.call(x + 1, y) and inside.call(x, y - 1) and inside.call(x, y + 1))
			var key := "J" if edge else ("L" if not inside.call(x, y - 2) else ("H" if y >= rect.end.y - 2 else "C"))
			var ink: Color = INKS[key]
			image.set_pixel(x, y, Color(ink.r * tint.r, ink.g * tint.g, ink.b * tint.b, 1.0))


## Shade's dungeon tile `tile` in `tint`.
static func _tinted(sheet: Image, tile: int, tint: Color) -> Image:
	var at := Vector2i(tile % PunyDungeon.COLUMNS, tile / PunyDungeon.COLUMNS) * TILE
	var out := sheet.get_region(Rect2i(at, Vector2i(TILE, TILE)))
	for y in TILE:
		for x in TILE:
			var pixel := out.get_pixel(x, y)
			out.set_pixel(x, y, Color(pixel.r * tint.r, pixel.g * tint.g, pixel.b * tint.b, pixel.a))
	return out


## A wall's top runs its courses of brick on through the cell: Shade's top
## has a dungeon's pillars and the dark recess between them in its lower
## half, read in the open as a grid of windows. Its rows from the first
## mortar line down, again.
static func _run_bricks(image: Image) -> void:
	for y in range(BRICKS_FROM, TILE):
		for x in TILE:
			image.set_pixel(x, y, image.get_pixel(x, COURSES + (y - BRICKS_FROM) % (BRICKS_FROM - COURSES)))


## A crack across the stone: a few dark pixels wandering down from an edge.
static func _crack(image: Image, dice: RandomNumberGenerator, tint: Color) -> void:
	var at := Vector2i(dice.randi_range(3, 12), dice.randi_range(1, 8))
	var ink := Color(INKS["B"] * tint, 1.0)
	for i in dice.randi_range(3, 6):
		if at.x < 0 or at.x >= TILE or at.y >= TILE or image.get_pixelv(at).a == 0.0:
			return
		image.set_pixelv(at, ink)
		at += [Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, 0)][dice.randi() % 4]


## `count` clumps of growth on the stone, most along its back edge (where
## moss and snow gather), each a few pixels walked out from a seed, lit on
## top and dark below.
static func _grow(image: Image, dice: RandomNumberGenerator, inks: Array, count: int) -> void:
	for clump in count:
		var at := Vector2i(dice.randi_range(0, TILE - 1), dice.randi_range(0, 3) if dice.randf() < 0.65 else dice.randi_range(4, 12))
		var pixels: Array[Vector2i] = []
		for i in dice.randi_range(3, 7):
			if at.x >= 0 and at.x < TILE and at.y >= 0 and at.y < TILE and image.get_pixel(at.x, at.y).a > 0.0:
				pixels.append(at)
			at += [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN][dice.randi() % 5]
		for pixel: Vector2i in pixels:
			var above := pixels.has(pixel + Vector2i.UP)
			var below := pixels.has(pixel + Vector2i.DOWN)
			image.set_pixelv(pixel, inks[1] if above and below else (inks[2] if not above else inks[0]))


## A bite knocked out of the stone's `side` (CHIP_N its back edge, CHIP_W or
## CHIP_E its end): the ground shows through, the broken edge dark.
static func _chip(image: Image, dice: RandomNumberGenerator, side: int, tint: Color) -> void:
	var start := dice.randi_range(2, 8)
	var length := dice.randi_range(4, 7)
	var edge := INKS["B"] * tint
	for i in length:
		var depth := 1 + dice.randi_range(0, 1) + (1 if i > 0 and i < length - 1 else 0)
		for d in depth + 1:
			var pixel := Vector2i(start + i, d)
			if side == CHIP_W:
				pixel = Vector2i(d, start + i)
			elif side == CHIP_E:
				pixel = Vector2i(TILE - 1 - d, start + i)
			if pixel.x < 0 or pixel.x >= TILE or pixel.y < 0 or pixel.y >= TILE:
				continue
			if d < depth:
				image.set_pixelv(pixel, Color(0, 0, 0, 0))
			elif image.get_pixelv(pixel).a > 0.0:
				image.set_pixelv(pixel, Color(edge, 1.0))


## The ground at a wall's foot: its shadow (`shadow`: 1 south of it, 2 east
## of it), then what lies there (`litter`).
static func _ground_piece(look: String, shadow: int, litter: int, dice: RandomNumberGenerator) -> Image:
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for y in TILE:
		for x in TILE:
			var alpha := 0.0
			if shadow & 1 and y < SHADOW_S.size():
				alpha = SHADOW_S[y]
			if shadow & 2 and x < SHADOW_E.size():
				alpha = maxf(alpha, SHADOW_E[x])
			if alpha > 0.0:
				image.set_pixel(x, y, Color(SHADE, alpha))
	var tint: Color = STONE[look]
	if litter == RUBBLE_A or litter == RUBBLE_B:
		# The stones lie near the wall they fell from.
		for i in (2 if litter == RUBBLE_A else 3):
			var size := Vector2i(dice.randi_range(RUBBLE_SIZE[0].x, RUBBLE_SIZE[1].x), dice.randi_range(RUBBLE_SIZE[0].y, RUBBLE_SIZE[1].y))
			var at := Vector2i(dice.randi_range(0, TILE - size.x), dice.randi_range(0, 7))
			if shadow == 2:
				at = Vector2i(dice.randi_range(0, 6), dice.randi_range(0, TILE - size.y))
			_stone(image, Rect2i(at, size), tint)
	elif litter == TUFT_A or litter == TUFT_B:
		var inks: Array = GROWTH[look]
		var growth := {"d": inks[0], "m": inks[1], "l": inks[2]}
		for i in (1 if litter == TUFT_A else 2):
			var stamp: Array = TUFT_STAMPS[dice.randi() % TUFT_STAMPS.size()]
			_stamp(image, stamp, Vector2i(dice.randi_range(1, TILE - 6), dice.randi_range(2, TILE - 4)), growth, Color.WHITE)
	return image


## `rows` (a letter an ink, "." none) drawn on `image` at `at`, in `tint`.
static func _stamp(image: Image, rows: Array, at: Vector2i, inks: Dictionary, tint: Color) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var key := row[x]
			var pixel := at + Vector2i(x, y)
			if key == "." or pixel.x >= TILE or pixel.y >= TILE:
				continue
			var ink: Color = inks[key]
			image.set_pixelv(pixel, Color(ink.r * tint.r, ink.g * tint.g, ink.b * tint.b, 1.0))
