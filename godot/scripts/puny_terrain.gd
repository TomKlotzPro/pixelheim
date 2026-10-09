class_name PunyTerrain
## Shade's Puny World overworld (assets/puny/world, CC0, PIX-130) drawn over
## the web game's maps. The tile grid stays the truth for walking; Puny's
## corner wang tiles go on the dual grid: one tile on every cell corner, whose
## four quarters belong to the four cells meeting there. A terrain boundary
## therefore falls on the very cell edges the hero collides on.
##
## The wang tables come straight from Shade's Tiled tileset (.tsx) through
## PunySheet: which tile has which terrain in each corner, and how the water
## animates.

const SHEET := "res://assets/puny/world/punyworld-overworld-tileset.png"
const TSX := "res://assets/puny/world/punyworld-overworld-tiles.tsx"
const COLUMNS := 27
const TILE := 16

## Our tile id -> the overworld wang terrain its ground is drawn as; anything
## else stands on grass (forests, flowers, houses, props...).
const GROUND := {
	"water": "river", "bridge": "river", "mountain": "cliff",
	"path": "dirt", "ash": "dirt", "sand": "sand",
	# PIX-164: Shade's sea in three depths (it meets sand, then itself);
	# snow is his grass whitened, ice his sand frosted, stone his dirt greyed.
	"shore": "seawater-light", "dock": "seawater-light", "sea": "seawater-medium", "deep_sea": "seawater-deep",
	"snow": "grass", "ice": "sand", "stone": "dirt",
}
## Shade pairs every terrain with grass only. Where two others meet at one
## corner, the first of these keeps its corners and the rest fall back to
## grass: cliffs stand over water, water over roads, roads over sand.
const STRENGTH := ["cliff", "seawater-deep", "seawater-medium", "seawater-light", "river", "dirt", "sand", "trees"]
## Regions Shade didn't paint, toned from his grass and dirt by
## shaders/region_tint.gdshader: tile id -> hue. Ash wastes go a burnt warm
## grey, the mire a murky green.
const TINTS := {
	"ash": Color(0.47, 0.45, 0.43),
	"marsh": Color(0.30, 0.42, 0.34),
	"snow": Color(0.8, 0.84, 0.9),
	"ice": Color(0.5, 0.66, 0.78),
	"stone": Color(0.56, 0.56, 0.58),
}
## Regions whose every ground cell takes a tone, trees' included (the pass's
## snow under its pines).
const REGION_TINTS := {"frost": "snow"}
## And their roads, which would whiten to a glare: the pass's road is trodden
## grey.
const REGION_PATHS := {"frost": "stone"}
## What a bridge or a dock spans.
const WATERS := ["water", "shore", "sea", "deep_sea"]
## The tiles a span is laid in: a bridge from bank to bank, a dock out from
## one.
const SPANS := ["bridge", "dock"]
## Ground the hero can walk out onto; maps with none are interiors.
const OUTDOOR := ["grass", "forest", "marsh", "ash", "sand", "snow", "stone"]

## Ramparts in Shade's castle pieces: towers on corners and every few steps
## along a run, crenellated runs across and down, a dark gate in the door.
const TOWER := 770
const TOWER_ACROSS := 797
const WALL_ACROSS := 721
const WALL_DOWN := 747
const GATE := 802
const TOWER_EVERY := 8
const RAMPART := ["wall", "door", "door_shut"]

## Maps that show the whole village as one block of roofs (the overworld):
## Skyline draws the village there, small (PIX-248).
const SKYLINE_MAPS := ["overworld"]

static var _sheet: PunySheet


## Shade's overworld sheet, read once.
static func sheet() -> PunySheet:
	if _sheet == null:
		_sheet = PunySheet.new(SHEET, TSX, COLUMNS)
	return _sheet


static func _combos() -> Dictionary:
	return sheet().corners.get("overworld", {})


## The ground terrain a cell of ours is drawn as.
static func ground_of(tile: String) -> String:
	return GROUND.get(tile, "grass")


## The ground drawn under one cell of a map. A dock stands in the water
## around it: the coast's piers over their pale shallows, but one built out
## into a river (the village's, PIX-236) over the river, or a pale square of
## sea would show round its planks.
static func ground_at(grid: Dictionary, cell: Vector2i) -> String:
	var tile: String = grid.get(cell, "")
	if tile == "dock":
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if grid.get(span_end(grid, cell, step), "") == "water":
				return ground_of("water")
	return ground_of(tile)


## The tile for four corner terrains [tl, tr, br, bl]; `pick` chooses among
## equal tiles (grass has nine) so fields don't repeat.
static func corner_tile(corners: Array, pick: int) -> int:
	var key := ",".join(corners)
	if not _combos().has(key):
		key = ",".join(settle(corners))
	var tiles: Array = _combos()[key]
	return tiles[absi(pick) % tiles.size()]


## Corners Shade never drew together, reduced to ones he did: the strongest
## terrain keeps its corners, the others become grass; a pairing still
## missing (water touching only diagonally) floods with the strong terrain so
## no blocked cell ever looks walkable.
static func settle(corners: Array) -> Array:
	var strongest := "grass"
	for terrain: String in STRENGTH:
		if terrain in corners:
			strongest = terrain
			break
	var settled := corners.map(func(c: String) -> String: return c if c == strongest else "grass")
	if not _combos().has(",".join(settled)):
		settled = [strongest, strongest, strongest, strongest]
	return settled


## Every ground tile of a map, keyed by dual cell: dual cell (x, y) sits on
## the corner shared by cells (x-1, y-1) to (x, y), so the layer drawing them
## is shifted half a tile up-left. Off-map cells repeat the nearest edge.
static func ground_tiles(grid: Dictionary, size: Vector2i) -> Dictionary:
	return _dual_tiles(size, func(cell: Vector2i) -> String: return ground_at(grid, cell))


## The pine forest crowning the mountains, on the same dual grid: it covers
## mountain cells walled in by mountains on all four sides, so the cliff rim
## at a range's edge stays in view. Bare corners ("air") are left out.
static func forest_tiles(grid: Dictionary, size: Vector2i) -> Dictionary:
	var crowned := func(cell: Vector2i) -> String:
		for step: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var near := Vector2i(clampi(cell.x + step.x, 0, size.x - 1), clampi(cell.y + step.y, 0, size.y - 1))
			if grid.get(near, "") != "mountain":
				return "air"
		return "trees"
	var tiles := _dual_tiles(size, crowned)
	for cell: Vector2i in tiles.keys():
		if tiles[cell] == corner_tile(["air", "air", "air", "air"], 0):
			tiles.erase(cell)
	return tiles


static func _dual_tiles(size: Vector2i, terrain_at: Callable) -> Dictionary:
	var at := func(x: int, y: int) -> String:
		return terrain_at.call(Vector2i(clampi(x, 0, size.x - 1), clampi(y, 0, size.y - 1)))
	var tiles := {}
	for y in size.y + 1:
		for x in size.x + 1:
			var corners := [at.call(x - 1, y - 1), at.call(x, y - 1), at.call(x, y), at.call(x - 1, y)]
			tiles[Vector2i(x, y)] = corner_tile(corners, hash(Vector2i(x, y)))
	return tiles


## The grounds Shade draws as water: the river and the sea's three depths
## (under bridges and docks too).
const WATER_GROUNDS := ["river", "seawater-light", "seawater-medium", "seawater-deep"]


## Where the water lies, cell by cell, for the shaders (PIX-223). Red is 1 on
## water and 0 on land, for the foam region_tint.gdshader lays along the
## shore: filtered between cells it reads a half on the shore line, rising
## out into the water. Green counts the water cells straight above (/255), so
## reflections.gdshader finds the bank that a cell's water mirrors.
static func water_map(grid: Dictionary, size: Vector2i) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RG8)
	for x in size.x:
		var above := 0
		for y in size.y:
			var cell := Vector2i(x, y)
			if ground_of(grid.get(cell, "")) in WATER_GROUNDS:
				image.set_pixelv(cell, Color(1.0, mini(above, 255) / 255.0, 0.0))
				above += 1
			else:
				above = 0
	return ImageTexture.create_from_image(image)


## The per-cell mask region_tint.gdshader reads: a region's hue with full
## coverage, premultiplied so blending between cells keeps the hue true.
static func tint_map(grid: Dictionary, size: Vector2i, regions := {}) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for cell: Vector2i in grid:
		var tile: String = grid[cell]
		var region: String = regions.get(cell, "")
		if tile == "path" and REGION_PATHS.has(region):
			tile = REGION_PATHS[region]
		elif not TINTS.has(tile) and REGION_TINTS.has(region):
			tile = REGION_TINTS[region]
		if TINTS.has(tile):
			image.set_pixelv(cell, TINTS[tile])
	# Water takes the tone of the land beside it, two cells out (PIX-247).
	# Water is never toned itself (the shader keeps its colours), but the soft
	# edge reads round each pixel, and an untoned shore thinned the land's
	# tone to nothing along it.
	for ring in 2:
		var spilled := {}
		for cell: Vector2i in grid:
			if grid[cell] not in WATERS or image.get_pixelv(cell).a > 0.0:
				continue
			for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var next := cell + side
				if next.x >= 0 and next.y >= 0 and next.x < size.x and next.y < size.y and image.get_pixelv(next).a > 0.0:
					spilled[cell] = image.get_pixelv(next)
					break
		for cell: Vector2i in spilled:
			image.set_pixelv(cell, spilled[cell])
	return ImageTexture.create_from_image(image)


## Whether a region of the map tones every cell, the mountains' pines too.
static func region_toned(regions: Dictionary) -> bool:
	return regions.values().any(func(region: String) -> bool: return REGION_TINTS.has(region))


## Whether a map lies under the sky (any grass, forest, marsh, ash or sand).
static func is_outdoor(grid: Dictionary) -> bool:
	for tile: String in grid.values():
		if tile in OUTDOOR:
			return true
	return false


## The castle piece a rampart cell shows, -1 if the cell isn't one. Ramparts
## are bands of wall up to three thick: a cell whose band runs across shows
## a crenellated run, down a side run, both ways (a corner) a tower; a door
## set in a band is its gate.
static func wall_piece(grid: Dictionary, cell: Vector2i) -> int:
	var tile: String = grid.get(cell, "")
	var gate := tile == "door" or tile == "door_shut"
	if tile != "wall" and not gate:
		return -1
	var across := _run(grid, cell, Vector2i.LEFT, RAMPART) + _run(grid, cell, Vector2i.RIGHT, RAMPART) + 1
	var down := _run(grid, cell, Vector2i.UP, RAMPART) + _run(grid, cell, Vector2i.DOWN, RAMPART) + 1
	if gate:
		return GATE if across > 3 or down > 3 else -1
	if across > 3 and down > 3:
		return TOWER
	if across > 3:
		return TOWER_ACROSS if cell.x % TOWER_EVERY == 0 else WALL_ACROSS
	if down > 3:
		return WALL_DOWN
	return TOWER


## Cells of `tiles` in a row from `cell` toward `step`, up to 4.
static func _run(grid: Dictionary, cell: Vector2i, step: Vector2i, tiles: Array) -> int:
	var count := 0
	var next := cell + step
	while count < 4 and grid.get(next, "") in tiles:
		count += 1
		next += step
	return count


## Puny objects standing on our cells, -1 where none: bridges and docks as
## planks the way they span (span_axis: a single plank, or the ends and
## middles of a run) and cave mouths.
static func object_at(grid: Dictionary, cell: Vector2i) -> int:
	match grid.get(cell, ""):
		"bridge", "dock":
			if span_axis(grid, cell) == Vector2i.RIGHT:
				var west := _run(grid, cell, Vector2i.LEFT, SPANS) > 0
				var east := _run(grid, cell, Vector2i.RIGHT, SPANS) > 0
				if not west and not east:
					return 821
				return 876 if west and east else (875 if east else 877)
			var north := _run(grid, cell, Vector2i.UP, SPANS) > 0
			var south := _run(grid, cell, Vector2i.DOWN, SPANS) > 0
			if not north and not south:
				return 848
			return 847 if north and south else (820 if south else 874)
		"cave":
			return 128
	return -1


## Which way the planks of a bridge or dock run through `cell`:
## Vector2i.RIGHT west to east, Vector2i.DOWN north to south. A span runs
## between ground the hero walks on: the way whose two ends land wins, then
## the way with one (a dock is a pier out from its bank). The web drew a
## bridge as one sprite whatever lay round it, and its shape alone laid
## planks along a river (PIX-235); only a span landing both ways alike
## falls back on its longer side, a square one crossing the water.
static func span_axis(grid: Dictionary, cell: Vector2i) -> Vector2i:
	var lands_across := _lands(grid, cell, Vector2i.LEFT) + _lands(grid, cell, Vector2i.RIGHT)
	var lands_down := _lands(grid, cell, Vector2i.UP) + _lands(grid, cell, Vector2i.DOWN)
	if lands_across != lands_down:
		return Vector2i.RIGHT if lands_across > lands_down else Vector2i.DOWN
	var across := _run(grid, cell, Vector2i.LEFT, SPANS) + _run(grid, cell, Vector2i.RIGHT, SPANS) + 1
	var down := _run(grid, cell, Vector2i.UP, SPANS) + _run(grid, cell, Vector2i.DOWN, SPANS) + 1
	var water_runs_down: bool = (
		grid.get(cell + Vector2i.UP, "") in WATERS or grid.get(cell + Vector2i.DOWN, "") in WATERS
	)
	return Vector2i.RIGHT if across > down or (across == down and water_runs_down) else Vector2i.DOWN


## The first cell past the span through `cell`, going toward `step`.
static func span_end(grid: Dictionary, cell: Vector2i, step: Vector2i) -> Vector2i:
	var next := cell + step
	while grid.get(next, "") in SPANS:
		next += step
	return next


## 1 when the span through `cell` lands toward `step` on ground the hero
## walks on, 0 at water, a wall or the map's edge.
static func _lands(grid: Dictionary, cell: Vector2i, step: Vector2i) -> int:
	return 1 if WorldTiles.is_walkable(grid.get(span_end(grid, cell, step), "")) else 0


## A Puny tile's rectangle on the sheet, for sprites cut from it.
static func region(tile_id: int) -> Rect2:
	return sheet().region(tile_id)


## The animation frames of a tile ([] when it holds still).
static func animation(tile_id: int) -> Array:
	return sheet().animation(tile_id)


## One TileSet over the Puny sheet, its tiles created on first use.
static func tileset() -> TileSet:
	return sheet().tileset


## Sets `cell` of `layer` (built on tileset()) to Puny tile `tile_id`.
static func place(layer: TileMapLayer, cell: Vector2i, tile_id: int) -> void:
	sheet().place(layer, cell, tile_id)
