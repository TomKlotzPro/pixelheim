class_name RoadWear
## The wear of wheels and feet on the dirt roads (PIX-307). The audit found
## every road in the Reach one flat band of Shade's dirt with a dithered
## edge, and Pixelheim's streets the same from the Ashes to the City. Now a
## cart's two ruts run along each road, broken here and there and wandering
## a pixel; on a country road grass grows on the crown between them and
## creeps in at the edges where the road meets a meadow, and pebbles lie
## about. In town the streets are trodden bare: ruts and stones, no grass on
## the crown.
## Drawn in code from Shade's CC0 dirt, grass and rock colours (it needs no
## paid art), as tiles on two layers over the ground: the wear (by where in
## the road's width a cell lies and which way the road runs) and the verges
## (tufts along each side that meets grass, or a gravelled street's edge
## stones: `kerbs`). The layers take the ground's own toning (region_tint),
## so a road through the frost or up the mountain wears its region's tone.
## Pure but for the art: `rows` and `kerbs` say which tile each cell wears.

const TILE := 16
## A road up to this many cells across, between ground that isn't road,
## runs ruts down its middle; anything wider (a square, a crossing) is worn
## but not rutted.
const MAX_WIDTH := 3
## Half the ruts' gauge in pixels, by the road's width in cells: a narrow
## track's cart runs its wheels nearer together.
const HALF_GAUGE := {1: 4, 2: 7, 3: 6}
## Which way a road runs: its ruts along x, or along y.
const ACROSS := 0
const DOWN := 1
## The two looks: a country road (grass on the crown) and a town street.
const COUNTRY := 0
const TOWN := 1
## A road's lanes, one per cell across it: one wide, two (first, second),
## three (first, middle, last).
const LANES := 6
const VARIANTS := 4
const VERGE_VARIANTS := 3
## The atlas: the rutted lanes, then the worn patches (crossings and
## squares), then the verges by which sides meet grass (N=1, E=2, S=4, W=8),
## then the kerbs the same way: a row of edge stones along a gravelled
## street's sides (Streets.KERBED).
const COLUMNS := 16
const PATCHES := 2 * 2 * LANES * VARIANTS
const VERGES := PATCHES + 2 * VARIANTS
const KERBS := VERGES + 15 * VERGE_VARIANTS
const COUNT := KERBS + 15 * VERGE_VARIANTS
## What a road is, and what grass grows in from beside it.
const ROAD := "path"
const GRASSY := ["grass", "forest", "flowers", "crops"]
const SIDES := {1: Vector2i.UP, 2: Vector2i.RIGHT, 4: Vector2i.DOWN, 8: Vector2i.LEFT}

## Shade's dirt (c4b253) worn deeper in the ruts, its lip catching the light;
## his grass's tufts; his rock's greys for a pebble.
const RUT := Color("a3903f")
const RUT_WALL := Color("b5a046")
const RUT_LIP := Color("cdbd62")
const SPECK := Color("b7a248")
const GRASS := Color("85a643")
const GRASS_LIGHT := Color("9fb747")
const GRASS_DARK := Color("7e9e3f")
const GRASS_MID := Color("96b146")
const STONE_LIGHT := Color("b2ba82")
const STONE := Color("99a16c")
const STONE_SHADOW := Color("9a873a")
## Tufts of grass, upright, by rows from the top: l light, d dark, m mid, g
## the grass under them (Shade's tuft from his meadow tile).
const TUFTS := [
	[".l.", "gld"],
	["..l.", ".dll", "gmdg"],
	[".l..", "dlm.", "gdmg"],
	["l.l", "mdl"],
]
const TUFT_COLORS := {"l": GRASS_LIGHT, "d": GRASS_DARK, "m": GRASS_MID, "g": GRASS}

static var _atlas: Image
static var _tileset: TileSet


## The tiles the road cells of `grid`'s rows [from, to) wear: {"wear":
## {cell: tile}, "verge": {cell: tile}}. `beyond(cell)` is the ground past
## the map's edges (so a road out runs on), `paved` the cells paving covers
## (Streets: worn no more), `origin` where cell (0, 0) lies in the plane (a
## road's wear runs on unbroken into the map beside), `style` COUNTRY or
## TOWN.
static func rows(grid: Dictionary, beyond: Callable, size: Vector2i, from: int, to: int, paved: Dictionary, origin: Vector2i, style: int) -> Dictionary:
	var wear := {}
	var verge := {}
	for y in range(from, mini(to, size.y)):
		for x in size.x:
			var cell := Vector2i(x, y)
			if grid.get(cell, "") != ROAD or paved.has(cell):
				continue
			wear[cell] = wear_tile(grid, beyond, cell, origin, style)
			var sides := 0
			for bit: int in SIDES:
				if _tile(grid, beyond, cell + SIDES[bit]) in GRASSY:
					sides |= bit
			if sides != 0:
				verge[cell] = VERGES + (sides - 1) * VERGE_VARIANTS + absi(hash(origin + cell)) % VERGE_VARIANTS
	return {"wear": wear, "verge": verge}


## The kerb of each cell of `kerbed` (cells of a paved street that lays edge
## stones) in rows [from, to): its stones along the sides where the street
## ends, against ground neither paved nor road: cell -> tile.
static func kerbs(kerbed: Dictionary, paved: Dictionary, grid: Dictionary, from: int, to: int) -> Dictionary:
	var out := {}
	for cell: Vector2i in kerbed:
		if cell.y < from or cell.y >= to:
			continue
		var sides := 0
		for bit: int in SIDES:
			var next: Vector2i = cell + SIDES[bit]
			if not paved.has(next) and grid.get(next, ROAD) != ROAD:
				sides |= bit
		if sides != 0:
			out[cell] = KERBS + (sides - 1) * VERGE_VARIANTS + absi(hash(cell)) % VERGE_VARIANTS
	return out


## Where in a road `cell` lies: [which way it runs, its width in cells, the
## cell's lane counted from the left or top], or [] for a crossing, a bend
## or a square (wider than MAX_WIDTH both ways).
static func lane_of(grid: Dictionary, beyond: Callable, cell: Vector2i) -> Array:
	var left := _run(grid, beyond, cell, Vector2i.LEFT)
	var up := _run(grid, beyond, cell, Vector2i.UP)
	var along_x := left + _run(grid, beyond, cell, Vector2i.RIGHT) + 1
	var along_y := up + _run(grid, beyond, cell, Vector2i.DOWN) + 1
	if along_y <= MAX_WIDTH and along_x > along_y:
		return [ACROSS, along_y, up]
	if along_x <= MAX_WIDTH and along_y > along_x:
		return [DOWN, along_x, left]
	return []


## The wear tile of road cell `cell`: its lane's ruts in one of their
## variants, the same for every lane across the road at that point (so a
## crown's tuft or a pebble split between two lanes meets itself), or a worn
## patch.
static func wear_tile(grid: Dictionary, beyond: Callable, cell: Vector2i, origin: Vector2i, style: int) -> int:
	var lane := lane_of(grid, beyond, cell)
	var at := origin + cell
	if lane.is_empty():
		return PATCHES + style * VARIANTS + absi(hash(at)) % VARIANTS
	var axis: int = lane[0]
	# The road's first cell across, so its lanes pick alike.
	var first := at - (Vector2i(0, lane[2]) if axis == ACROSS else Vector2i(lane[2], 0))
	var variant := absi(hash(first)) % VARIANTS
	return lane_tile(style, axis, lane[1], lane[2], variant)


static func lane_tile(style: int, axis: int, width: int, index: int, variant: int) -> int:
	var lane: int = [0, 1, 3][width - 1] + index
	return ((style * 2 + axis) * LANES + lane) * VARIANTS + variant


## Road cells from `cell` toward `step`, up to MAX_WIDTH + 1.
static func _run(grid: Dictionary, beyond: Callable, cell: Vector2i, step: Vector2i) -> int:
	var count := 0
	while count <= MAX_WIDTH and _tile(grid, beyond, cell + step * (count + 1)) == ROAD:
		count += 1
	return count


## The ground at `cell`: the map's, or past its edges what lies there.
static func _tile(grid: Dictionary, beyond: Callable, cell: Vector2i) -> String:
	return grid[cell] if grid.has(cell) else beyond.call(cell)


## A tile's place on the atlas.
static func coords(tile: int) -> Vector2i:
	return Vector2i(tile % COLUMNS, tile / COLUMNS)


## One TileSet over the atlas, every tile made at once (One Reach, PIX-269:
## a tile made later redraws every layer drawn with it).
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


## The wear, drawn once a session: every lane of every width both ways in
## both looks, the worn patches and the verges, each from its own seed (the
## same pixels every time).
static func atlas() -> Image:
	if _atlas != null:
		return _atlas
	_atlas = Image.create(COLUMNS * TILE, ceili(COUNT / float(COLUMNS)) * TILE, false, Image.FORMAT_RGBA8)
	for style in 2:
		for axis in 2:
			for width in range(1, MAX_WIDTH + 1):
				for variant in VARIANTS:
					var band := _band(style, axis, width, variant)
					for index in width:
						var tile := lane_tile(style, axis, width, index, variant)
						var from := Vector2i(index * TILE, 0) if axis == DOWN else Vector2i(0, index * TILE)
						_atlas.blit_rect(band, Rect2i(from, Vector2i(TILE, TILE)), coords(tile) * TILE)
		for variant in VARIANTS:
			_atlas.blit_rect(_patch(style, variant), Rect2i(0, 0, TILE, TILE), coords(PATCHES + style * VARIANTS + variant) * TILE)
	for sides in range(1, 16):
		for variant in VERGE_VARIANTS:
			_atlas.blit_rect(_verge(sides, variant), Rect2i(0, 0, TILE, TILE), coords(VERGES + (sides - 1) * VERGE_VARIANTS + variant) * TILE)
			_atlas.blit_rect(_kerb(sides, variant), Rect2i(0, 0, TILE, TILE), coords(KERBS + (sides - 1) * VERGE_VARIANTS + variant) * TILE)
	return _atlas


## A road `width` cells across running `axis`, a cell long: its two ruts
## either side of its middle, grass on its crown (COUNTRY), a pebble or two.
## Drawn as a band, then cut into its lanes, so what crosses a lane's edge
## carries on into the next.
static func _band(style: int, axis: int, width: int, variant: int) -> Image:
	var size := Vector2i(width * TILE, TILE) if axis == DOWN else Vector2i(TILE, width * TILE)
	var band := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([style, axis, width, variant, "band"])
	var middle := width * TILE / 2
	var half: int = HALF_GAUGE[width]
	# The crown first, so a rut wandering into a tuft runs over it.
	if style == COUNTRY:
		var along := dice.randi_range(0, 4)
		while along < TILE:
			if dice.randf() < 0.7:
				_tuft(band, axis, along, middle + dice.randi_range(-1, 0), dice.randi() % TUFTS.size())
			along += dice.randi_range(5, 8)
	for side in [-1, 1]:
		_rut(band, axis, middle + side * half, dice)
	var stones := 1 if style == COUNTRY else 2
	for i in stones:
		if dice.randf() < 0.75:
			var across := dice.randi_range(1, width * TILE - 3)
			if absi(absi(across - middle) - half) > 1:
				_pebble(band, axis, dice.randi_range(1, TILE - 3), across, dice.randf() < 0.5)
	return band


## One rut `across` pixels into the band: its groove the whole cell long but
## for a gap or two, the wall before it in shade and its far lip lit; it
## wanders a pixel off its line in the middle of the cell and meets it again
## at both ends, so the next cell's rut carries it on.
static func _rut(band: Image, axis: int, across: int, dice: RandomNumberGenerator) -> void:
	var gaps := {}
	for i in dice.randi_range(1, 3):
		var start := dice.randi_range(1, TILE - 4)
		for along in range(start, start + dice.randi_range(1, 3)):
			gaps[along] = true
	var bend_from := dice.randi_range(3, 7)
	var bend_to := dice.randi_range(bend_from + 2, TILE - 3)
	var bend := 1 if dice.randf() < 0.5 else -1
	for along in TILE:
		if gaps.has(along):
			# A gap is the rut worn shallow, not gone: its wall goes on, faint.
			if dice.randf() < 0.4:
				_put(band, axis, along, across, RUT_WALL)
			continue
		var at := across + (bend if along >= bend_from and along <= bend_to else 0)
		_put(band, axis, along, at, RUT)
		if dice.randf() < 0.7:
			_put(band, axis, along, at - 1, RUT_WALL)
		if dice.randf() < 0.4:
			_put(band, axis, along, at + 1, RUT_LIP)


## A tuft of grass standing on (`along`, `across`) of the band, upright.
static func _tuft(band: Image, axis: int, along: int, across: int, kind: int) -> void:
	var shape: Array = TUFTS[kind]
	var foot := Vector2i(along, across) if axis == ACROSS else Vector2i(across, along)
	var top_left := foot - Vector2i(String(shape[0]).length() / 2, shape.size() - 1)
	_stamp(band, top_left, shape)


## A pebble on the band: two pixels of stone lit from the top left, its
## shadow on the dirt under it; or one.
static func _pebble(band: Image, axis: int, along: int, across: int, big: bool) -> void:
	var at := Vector2i(along, across) if axis == ACROSS else Vector2i(across, along)
	_dot(band, at, STONE_LIGHT if big else STONE)
	_dot(band, at + Vector2i.DOWN, STONE_SHADOW)
	if big:
		_dot(band, at + Vector2i.RIGHT, STONE)
		_dot(band, at + Vector2i(1, 1), STONE_SHADOW)


## A crossing or a square, worn but not rutted: trodden specks and pebbles.
static func _patch(style: int, variant: int) -> Image:
	var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([style, variant, "patch"])
	# One variant in four lies bare, so the specks don't fall in a pattern.
	if variant == 0:
		return tile
	for i in dice.randi_range(0, 2):
		_dot(tile, Vector2i(dice.randi_range(0, TILE - 1), dice.randi_range(0, TILE - 1)), SPECK)
	if dice.randf() < (0.4 if style == COUNTRY else 0.6):
		_pebble(tile, ACROSS, dice.randi_range(1, TILE - 3), dice.randi_range(1, TILE - 3), dice.randf() < 0.5)
	return tile


## Grass creeping in at a road's edges, on `sides` (N=1, E=2, S=4, W=8):
## tufts standing a pixel or two in from each, and blades of the meadow's
## green breaking its line.
static func _verge(sides: int, variant: int) -> Image:
	var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([sides, variant, "verge"])
	for bit: int in SIDES:
		if sides & bit == 0:
			continue
		var along := dice.randi_range(0, 3)
		while along < TILE:
			var depth := dice.randi_range(0, 1)
			if dice.randf() < 0.6:
				var shape: Array = TUFTS[dice.randi() % TUFTS.size()]
				var width := String(shape[0]).length()
				var height := shape.size()
				var top_left: Vector2i
				match bit:
					1:
						top_left = Vector2i(along, depth)
					4:
						top_left = Vector2i(along, TILE - height - depth)
					8:
						top_left = Vector2i(depth, along)
					_:
						top_left = Vector2i(TILE - width - depth, along)
				_stamp(tile, top_left, shape)
			else:
				var blade := Vector2i(along, 0)
				match bit:
					4:
						blade = Vector2i(along, TILE - 1)
					8:
						blade = Vector2i(0, along)
					2:
						blade = Vector2i(TILE - 1, along)
				_dot(tile, blade, GRASS)
			along += dice.randi_range(3, 6)
	return tile


## Edge stones along a street's `sides` (N=1, E=2, S=4, W=8): a row of
## stones two or three pixels long, set end to end with a crack between,
## each lit on top and shadowed on the gravel below it.
static func _kerb(sides: int, variant: int) -> Image:
	var tile := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	var dice := RandomNumberGenerator.new()
	dice.seed = hash([sides, variant, "kerb"])
	for bit: int in SIDES:
		if sides & bit == 0:
			continue
		var along := dice.randi_range(0, 1)
		while along < TILE:
			var length := mini(dice.randi_range(2, 3), TILE - along)
			for step in length:
				var a := along + step
				match bit:
					1:
						_dot(tile, Vector2i(a, 0), STONE_LIGHT)
						_dot(tile, Vector2i(a, 1), STONE)
						_dot(tile, Vector2i(a, 2), STONE_SHADOW)
					4:
						_dot(tile, Vector2i(a, TILE - 2), STONE_LIGHT)
						_dot(tile, Vector2i(a, TILE - 1), STONE)
					8:
						_dot(tile, Vector2i(0, a), STONE_LIGHT if step == 0 else STONE)
						_dot(tile, Vector2i(1, a), STONE)
						_dot(tile, Vector2i(2, a), STONE_SHADOW)
					_:
						_dot(tile, Vector2i(TILE - 2, a), STONE_LIGHT if step == 0 else STONE)
						_dot(tile, Vector2i(TILE - 1, a), STONE)
			along += length + 1
	return tile


static func _stamp(image: Image, top_left: Vector2i, shape: Array) -> void:
	for row in shape.size():
		var line := String(shape[row])
		for column in line.length():
			if TUFT_COLORS.has(line[column]):
				_dot(image, top_left + Vector2i(column, row), TUFT_COLORS[line[column]])


## A pixel (along, across) of a band running `axis`.
static func _put(band: Image, axis: int, along: int, across: int, color: Color) -> void:
	_dot(band, Vector2i(along, across) if axis == ACROSS else Vector2i(across, along), color)


static func _dot(image: Image, at: Vector2i, color: Color) -> void:
	if at.x >= 0 and at.y >= 0 and at.x < image.get_width() and at.y < image.get_height():
		image.set_pixelv(at, color)
