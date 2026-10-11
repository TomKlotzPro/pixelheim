class_name DungeonArt
## The small things a dungeon is dressed in that Shade's sheets don't draw
## (PIX-310): mine rails, timber props, crypt niches and cobwebs, banners,
## seaweed, bones and a rug's border, drawn here in code in his dungeon
## sheet's own palette (the barrels' woods, the cage's irons, the walls'
## greys), at 1x and on its 16 px grid, so they sit beside his art as his.
## Our own, so CC0 like the rest of the repository: they draw the same with
## or without the paid pack. One atlas a session, every piece cut up front
## (a tile made later redraws every layer on the tileset).

const TILE := 16
const COLUMNS := 16

## Shade's dungeon palette, a letter a colour: o his dark outline; the
## barrels' woods, dark to light (d w W m l L); the cage's irons (k i I j J);
## the walls' greys (T S s); the recess's dark (n N); bone (x b B); webs
## (c C, half-seen); weed (v g G h); banners' reds and blues (q r R, p u U)
## and their gold (z y Y); the urn's clay (e E).
const INKS := {
	"o": Color("2e2036"), "d": Color("4a3132"), "w": Color("644227"), "W": Color("79542d"),
	"m": Color("966a3a"), "l": Color("c18f4f"), "L": Color("d6a555"),
	"k": Color("2d2d2d"), "i": Color("585652"), "I": Color("6f6f70"), "j": Color("9a9b9e"), "J": Color("b5b7bb"),
	"T": Color("474747"), "S": Color("686868"), "s": Color("8a8a8a"),
	"n": Color("141318"), "N": Color("26252b"),
	"x": Color("6b6556"), "b": Color("b3aa8f"), "B": Color("e2dcc6"),
	"c": Color(0.92, 0.92, 0.96, 0.62), "C": Color(0.92, 0.92, 0.96, 0.32),
	"v": Color("1e3a2a"), "g": Color("2f5a3a"), "G": Color("4c8a4e"), "h": Color("7bb35a"),
	"q": Color("5a1c22"), "r": Color("8f2d2d"), "R": Color("c0463b"),
	"p": Color("1c2a5a"), "u": Color("3a5cb0"), "U": Color("6a90e0"),
	"z": Color("966a3a"), "y": Color("d6a555"), "Y": Color("fbe08a"),
	"e": Color("8a4a32"), "E": Color("c97a4a"),
}
## The bed a rail line lies in: dark ballast, softer at its edges, a lighter
## stone in it here and there.
const BALLAST := Color(0.1, 0.08, 0.11, 0.5)
const BALLAST_EDGE := Color(0.1, 0.08, 0.11, 0.25)
const GRAVEL := Color(0.56, 0.53, 0.5, 0.75)
## A rail's way in and out of its cell, as bits: north, east, south, west.
const N := 1
const E := 2
const S := 4
const W := 8
## Each piece's place in the atlas, by name.
const PIECES := [
	"rail_h", "rail_v", "rail_ne", "rail_es", "rail_sw", "rail_wn",
	"rail_end_e", "rail_end_w", "rail_end_n", "rail_end_s", "rail_x",
	"timber_beam", "timber_post", "web_l", "web_r", "niche_skull",
	"niche_urn", "banner_red", "banner_blue", "weed_a", "weed_b", "bones_a", "bones_b",
	"rug_0", "rug_1", "rug_2", "rug_3", "rug_4", "rug_5", "rug_6", "rug_7", "rug_8",
]
## A rail's piece by the ways it runs (N, E, S, W).
const RAIL_BY_WAYS := {
	E | W: "rail_h", N | S: "rail_v", N | E: "rail_ne", E | S: "rail_es", S | W: "rail_sw", W | N: "rail_wn",
	W: "rail_end_e", E: "rail_end_w", S: "rail_end_n", N: "rail_end_s",
}

## A crypt's niche in a wall's face: an arched recess, a skull on its sill
## (or an urn), the wall's stone lip round it.
const NICHE_SKULL := [
	"................",
	".....oooooo.....",
	"....oNNNNNNo....",
	"...oNnnnnnnNo...",
	"...oNnnnnnnNo...",
	"...oNnnbBbnNo...",
	"...oNnbBBBbNo...",
	"...oNnBkBkBNo...",
	"...oNnbBBBbNo...",
	"...oNnnxBxnNo...",
	"..osssssssssso..",
	"..oSSSSSSSSSSo..",
	"...oooooooooo...",
	"................",
	"................",
	"................",
]
const NICHE_URN := [
	"................",
	".....oooooo.....",
	"....oNNNNNNo....",
	"...oNnnnnnnNo...",
	"...oNnnoonnNo...",
	"...oNnoEEonNo...",
	"...oNnnoeonNo...",
	"...oNnoEEeoNo...",
	"...oNoEEEeeoo...",
	"...oNoEeeeeoo...",
	"..osssssssssso..",
	"..oSSSSSSSSSSo..",
	"...oooooooooo...",
	"................",
	"................",
	"................",
]
## A banner of the old kings on a wall's face: hung from an iron rod, gold
## down its sides, a crown on it, its foot cut in a swallowtail. `r` is its
## cloth: the reds or the blues.
const BANNER := [
	"...kjJJJJJJJjk..",
	"....oyrrrrryo...",
	"....oyRRRRRyo...",
	"....oyRRRRRyo...",
	"....oyRYRYRyo...",
	"....oyRYYYRyo...",
	"....oyRzzzRyo...",
	"....oyRRRRRyo...",
	"....oyRRRRRyo...",
	"....oyrRRRryo...",
	"....oyrrRrryo...",
	"....oyro.oryo...",
	"....oyo...oyo...",
	"....oo.....oo...",
	"................",
	"................",
]
const BANNER_CLOTH := {
	"red": {"r": "r", "R": "R"},
	"blue": {"r": "u", "R": "U"},
}
## Bones on a crypt's floor: a skull and a long bone; a jaw and two more.
const BONES_A := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".....obBbo......",
	"....obBBBBo.....",
	"....oBkBkBo..ob.",
	"....obBBBbo.obBo",
	".....oxbxo.obBo.",
	"......ooo.obBo..",
	"........obBBo...",
	".......obBbo....",
	"........ooo.....",
	"................",
]
const BONES_B := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"..ob.......bo...",
	"..obBo...obBo...",
	"...obBo.obBo....",
	"....obBbBbo.....",
	"...obBo.obBo....",
	"..obBo...obBo...",
	"..obo.....obo...",
	"................",
	"................",
]

static var _atlas: ImageTexture
static var _tileset: TileSet
static var _textures := {}


## Where piece `name` sits in the atlas.
static func coords(name: String) -> Vector2i:
	var index := PIECES.find(name)
	if index < 0:
		push_error("DungeonArt: no piece called " + name)
		index = 0
	return Vector2i(index % COLUMNS, index / COLUMNS)


## The rail for a cell joined to the cells round it by `ways` (N, E, S, W
## bits): straight, round a corner, its end (a buffer stop), or a crossing.
static func rail(ways: int) -> String:
	if RAIL_BY_WAYS.has(ways):
		return RAIL_BY_WAYS[ways]
	return "rail_x" if ways != 0 else "rail_h"


## The atlas of every piece, drawn once a session.
static func atlas() -> ImageTexture:
	if _atlas == null:
		var rows := ceili(PIECES.size() / float(COLUMNS))
		var image := Image.create(COLUMNS * TILE, rows * TILE, false, Image.FORMAT_RGBA8)
		for i in PIECES.size():
			var piece := draw(String(PIECES[i]))
			image.blit_rect(piece, Rect2i(0, 0, TILE, TILE), Vector2i((i % COLUMNS) * TILE, (i / COLUMNS) * TILE))
		_atlas = ImageTexture.create_from_image(image)
	return _atlas


## A tileset over the atlas, every piece made up front.
static func tileset() -> TileSet:
	if _tileset == null:
		_tileset = TileSet.new()
		_tileset.tile_size = Vector2i(TILE, TILE)
		var source := TileSetAtlasSource.new()
		source.texture = atlas()
		source.texture_region_size = Vector2i(TILE, TILE)
		for i in PIECES.size():
			source.create_tile(Vector2i(i % COLUMNS, i / COLUMNS))
		_tileset.add_source(source, 0)
	return _tileset


static func place(layer: TileMapLayer, cell: Vector2i, name: String) -> void:
	tileset()
	layer.set_cell(cell, 0, coords(name))


## One piece as its own texture (a sprite's).
static func texture(name: String) -> Texture2D:
	if not _textures.has(name):
		var cut := AtlasTexture.new()
		cut.atlas = atlas()
		cut.region = Rect2(Vector2(coords(name) * TILE), Vector2(TILE, TILE))
		_textures[name] = cut
	return _textures[name]


## Piece `name`, drawn: a 16 px image.
static func draw(name: String) -> Image:
	var image := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	if name.begins_with("rail_"):
		_rail(image, name)
	elif name.begins_with("rug_"):
		_rug(image, int(name.trim_prefix("rug_")))
	else:
		match name:
			"timber_beam":
				_timber(image, false)
			"timber_post":
				_timber(image, true)
			"web_l":
				_web(image, false)
			"web_r":
				_web(image, true)
			"niche_skull":
				_rows(image, NICHE_SKULL)
			"niche_urn":
				_rows(image, NICHE_URN)
			"banner_red":
				_rows(image, BANNER, BANNER_CLOTH["red"])
			"banner_blue":
				_rows(image, BANNER, BANNER_CLOTH["blue"])
			"weed_a":
				_weed(image, 7)
			"weed_b":
				_weed(image, 23)
			"bones_a":
				_rows(image, BONES_A)
			"bones_b":
				_rows(image, BONES_B)
	return image


## Letter rows onto `image`, a pixel a letter ('.' left clear), letters
## swapped first by `swap`.
static func _rows(image: Image, rows: Array, swap := {}) -> void:
	for y in rows.size():
		var row := String(rows[y])
		for x in row.length():
			var letter := row[x]
			letter = String(swap.get(letter, letter))
			if INKS.has(letter):
				image.set_pixel(x, y, INKS[letter])


## A rail: two iron rails on wooden sleepers, straight across the cell or
## round a quarter turn from one side to the next, or ending at a buffer of
## timber; a crossing is both straights.
static func _rail(image: Image, name: String) -> void:
	match name:
		"rail_h":
			_straight(image, true, 0, 16)
		"rail_v":
			_straight(image, false, 0, 16)
		"rail_x":
			_straight(image, true, 0, 16)
			_straight(image, false, 0, 16)
		"rail_end_e":
			_straight(image, true, 0, 12)
			_buffer(image, true, 12)
		"rail_end_w":
			_straight(image, true, 4, 16)
			_buffer(image, true, 1)
		"rail_end_n":
			_straight(image, false, 4, 16)
			_buffer(image, false, 1)
		"rail_end_s":
			_straight(image, false, 0, 12)
			_buffer(image, false, 12)
		_:
			# A quarter turn about the cell's corner between its two ways.
			var corner: Vector2 = {
				"rail_ne": Vector2(16, 0), "rail_es": Vector2(16, 16), "rail_sw": Vector2(0, 16), "rail_wn": Vector2(0, 0),
			}[name]
			_turn(image, corner)


## Sleepers then rails along a straight, from `from` to `to` pixels along it.
static func _straight(image: Image, across: bool, from: int, to: int) -> void:
	for along in range(from, to):
		# The bed of dark ballast the line is laid in, a stone in it here
		# and there.
		for side in range(2, 14):
			_put(image, across, along, side, BALLAST if side > 2 and side < 13 else BALLAST_EDGE)
			if posmod(along * 5 + side * 3, 11) == 0:
				_put(image, across, along, side, GRAVEL)
		# A sleeper two pixels wide every four: lit on top, dark below.
		if posmod(along, 4) in [1, 2]:
			for side in range(3, 13):
				_put(image, across, along, side, INKS["W"] if posmod(along, 4) == 1 else INKS["d"])
		# The two rails: lit on their top (or west) edge.
		for rail_at: int in [4, 10]:
			_put(image, across, along, rail_at, INKS["J"])
			_put(image, across, along, rail_at + 1, INKS["i"])


## A pixel `along` a straight and `side` across it.
static func _put(image: Image, across: bool, along: int, side: int, color: Color) -> void:
	if across:
		image.set_pixel(along, side, color)
	else:
		image.set_pixel(side, along, color)


## A buffer stop: a timber block across the rails' end, at `at` along them.
static func _buffer(image: Image, across: bool, at: int) -> void:
	for along in range(at, mini(at + 3, 16)):
		for side in range(2, 14):
			var tone := "m" if along == at else ("w" if along == at + 1 else "d")
			if side in [2, 13]:
				tone = "o"
			_put(image, across, along, side, INKS[tone])


## A quarter turn: sleepers fanned about `corner`, the rails two arcs round
## it at the straights' distances (4-5 and 10-11 px in from the side).
static func _turn(image: Image, corner: Vector2) -> void:
	for y in TILE:
		for x in TILE:
			var at := Vector2(x + 0.5, y + 0.5) - corner
			var reach := at.length()
			var angle := rad_to_deg(atan2(absf(at.y), absf(at.x)))
			if reach >= 2.5 and reach < 14.0:
				image.set_pixel(x, y, BALLAST if reach >= 3.5 and reach < 13.0 else BALLAST_EDGE)
				if posmod(x * 5 + y * 3, 11) == 0:
					image.set_pixel(x, y, GRAVEL)
			if reach >= 3.5 and reach < 13.0 and fposmod(angle, 22.5) < 7.5:
				image.set_pixel(x, y, INKS["W"] if fposmod(angle, 22.5) < 3.75 else INKS["d"])
			# The outer rail runs 11-12 px out (the straight's 4-5 from the
			# far side), the inner 5-6 (its 10-11).
			for rail_at: float in [11.0, 5.0]:
				if reach >= rail_at - 0.5 and reach < rail_at + 0.5:
					image.set_pixel(x, y, INKS["J"])
				elif reach >= rail_at + 0.5 and reach < rail_at + 1.5:
					image.set_pixel(x, y, INKS["i"])


## A mine's timbering on a wall's face: the cap beam along the top, and on a
## post cell the prop standing under it.
static func _timber(image: Image, post: bool) -> void:
	for x in TILE:
		image.set_pixel(x, 0, INKS["o"])
		image.set_pixel(x, 1, INKS["l"])
		image.set_pixel(x, 2, INKS["m"])
		image.set_pixel(x, 3, INKS["w"])
		image.set_pixel(x, 4, INKS["o"])
		# A grain mark here and there.
		if posmod(x * 7, 11) == 3:
			image.set_pixel(x, 2, INKS["W"])
	if not post:
		return
	for y in range(4, TILE):
		image.set_pixel(5, y, INKS["o"])
		image.set_pixel(6, y, INKS["l"])
		image.set_pixel(7, y, INKS["m"])
		image.set_pixel(8, y, INKS["m"] if posmod(y, 5) != 2 else INKS["W"])
		image.set_pixel(9, y, INKS["w"])
		image.set_pixel(10, y, INKS["o"])
	# An iron band near its top and its foot.
	for y: int in [6, 13]:
		for x in range(5, 11):
			image.set_pixel(x, y, INKS["i"] if x in [5, 10] else INKS["j"])


## A cobweb in a room's top corner, slung from the wall's corner: five
## threads fanned out from it and three rings strung from thread to thread,
## fading toward its edge. `east`: the room's east corner, the web mirrored.
static func _web(image: Image, east: bool) -> void:
	var spokes: Array[Vector2] = [Vector2(1, 0), Vector2(2, 1).normalized(), Vector2(1, 1).normalized(), Vector2(1, 2).normalized(), Vector2(0, 1)]
	var strands := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	for spoke: Vector2 in spokes:
		_line(strands, Vector2i.ZERO, Vector2i((spoke * 12.0).round()), INKS["C"])
	for ring: float in [4.0, 7.5, 11.0]:
		for i in spokes.size() - 1:
			_line(strands, Vector2i((spokes[i] * ring).round()), Vector2i((spokes[i + 1] * ring).round()), INKS["c"] if ring < 8.0 else INKS["C"])
	for y in TILE:
		for x in TILE:
			var thread := strands.get_pixel(x, y)
			if thread.a > 0.0:
				image.set_pixel(TILE - 1 - x if east else x, y, thread)


## A line of pixels from `a` to `b`, both ends in.
static func _line(image: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in steps + 1:
		var at := Vector2(a).lerp(Vector2(b), i / float(maxi(steps, 1))).round()
		var cell := Vector2i(at)
		if cell.x >= 0 and cell.y >= 0 and cell.x < image.get_width() and cell.y < image.get_height():
			image.set_pixelv(cell, color)


## Weed at a wet wall's foot: fronds of kelp up from the floor's edge, dark
## at the root, lit at the tip, a barnacle or two. `seed` varies the stand.
static func _weed(image: Image, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for x in TILE:
		var height := rng.randi_range(0, 7) if rng.randf() < 0.7 else 0
		var lean := rng.randi_range(-1, 1)
		for step in height:
			var y := TILE - 1 - step
			var at := clampi(x + (lean if step > height / 2 else 0), 0, TILE - 1)
			var tone := "v" if step == 0 else ("g" if step < height - 2 else ("G" if step < height - 1 else "h"))
			image.set_pixel(at, y, INKS[tone])
	for i in 2:
		var x := rng.randi_range(2, 13)
		var y := rng.randi_range(9, 13)
		image.set_pixel(x, y, INKS["j"])
		image.set_pixel(x + 1, y, INKS["J"])
		image.set_pixel(x, y + 1, INKS["I"])


## One of a rug's nine parts (0 the top-left corner, 4 its middle, 8 the
## bottom-right, row by row): the old kings' red, a gold border and a dark
## line inside it, a lattice of gold lozenges over the field.
static func _rug(image: Image, part: int) -> void:
	var column := part % 3
	var row := part / 3
	for y in TILE:
		for x in TILE:
			# How far in from the rug's edge this pixel is, across and down.
			var in_x := x if column == 0 else (TILE - 1 - x if column == 2 else 99)
			var in_y := y if row == 0 else (TILE - 1 - y if row == 2 else 99)
			var edge := mini(in_x, in_y)
			var tone := "R"
			if edge == 0:
				tone = "q"
			elif edge <= 2:
				tone = "y" if (posmod(x + y, 4) != 0) else "z"
			elif edge == 3:
				tone = "q"
			else:
				# The field: lozenges on a four-pixel lattice.
				var diamond := absi(posmod(x, 8) - 4) + absi(posmod(y, 8) - 4)
				tone = "y" if diamond == 3 else ("r" if diamond < 3 else "R")
			image.set_pixel(x, y, INKS[tone])
