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

## Maps that show a whole town as one block of roofs (the overworld): Puny
## draws it as a walled city of house icons around a keep instead.
const SKYLINE_MAPS := ["overworld"]
## Shade's single-tile houses: thatch, teal and red roofs.
const HOUSES := [
	709, 710, 711, 733, 734, 735, 736, 737, 738, 760, 761, 762, 763, 764, 765,
	895, 896, 897, 898, 899, 900, 922, 923, 924, 925, 926, 927,
	904, 905, 906, 907, 908, 909, 931, 932, 933, 934, 935, 936,
]
## The keep, 2x2 from its top-left.
const KEEP := [[Vector2i(0, 0), 714], [Vector2i(1, 0), 715], [Vector2i(0, 1), 741], [Vector2i(1, 1), 742]]

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
	return _dual_tiles(size, func(cell: Vector2i) -> String: return ground_of(grid.get(cell, "")))


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


## The skyline of a town drawn as one roof block (SKYLINE_MAPS): a keep at
## the block's heart and houses on every other cell around it, none right
## behind a gate. Cell -> Puny tile.
static func skyline(grid: Dictionary) -> Dictionary:
	var roofs: Array[Vector2i] = []
	for cell: Vector2i in grid:
		if (grid[cell] as String).begins_with("roof"):
			roofs.append(cell)
	if roofs.is_empty():
		return {}
	var low := roofs[0]
	var high := roofs[0]
	for cell in roofs:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	var keep_at := (low + high) / 2
	var drawn := {}
	for piece: Array in KEEP:
		drawn[keep_at + piece[0]] = piece[1]
	for cell in roofs:
		if drawn.has(cell) or cell.x % 2 != 0 or cell.y % 2 != 0:
			continue
		var by_gate := false
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			if grid.get(cell + step, "") in ["door", "door_shut"]:
				by_gate = true
		if not by_gate:
			drawn[cell] = HOUSES[absi(hash(cell)) % HOUSES.size()]
	return drawn


## Puny objects standing on our cells, -1 where none: bridges by the way
## they span (a single plank, or the ends and middles of a span along its
## longer side; square spans cross the water) and cave mouths.
static func object_at(grid: Dictionary, cell: Vector2i) -> int:
	match grid.get(cell, ""):
		"bridge", "dock":
			var span := ["bridge", "dock"]
			var across := _run(grid, cell, Vector2i.LEFT, span) + _run(grid, cell, Vector2i.RIGHT, span) + 1
			var down := _run(grid, cell, Vector2i.UP, span) + _run(grid, cell, Vector2i.DOWN, span) + 1
			var water_runs_down: bool = (
				grid.get(cell + Vector2i.UP, "") in WATERS or grid.get(cell + Vector2i.DOWN, "") in WATERS
			)
			if across > down or (across == down and water_runs_down):
				if across == 1:
					return 821
				var west := _run(grid, cell, Vector2i.LEFT, span) > 0
				var east := _run(grid, cell, Vector2i.RIGHT, span) > 0
				return 876 if west and east else (875 if east else 877)
			if down == 1:
				return 848
			var north := _run(grid, cell, Vector2i.UP, span) > 0
			var south := _run(grid, cell, Vector2i.DOWN, span) > 0
			return 847 if north and south else (820 if south else 874)
		"cave":
			return 128
	return -1


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
