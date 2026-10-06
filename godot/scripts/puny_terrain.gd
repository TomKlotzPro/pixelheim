class_name PunyTerrain
## Shade's Puny World overworld (assets/puny/world, CC0, PIX-130) drawn over
## the web game's maps. The tile grid stays the truth for walking; Puny's
## corner wang tiles go on the dual grid: one tile on every cell corner, whose
## four quarters belong to the four cells meeting there. A terrain boundary
## therefore falls on the very cell edges the hero collides on.
##
## The wang tables come straight from Shade's Tiled tileset (.tsx): which
## tile has which terrain in each corner, and how the water animates.

const SHEET := "res://assets/puny/world/punyworld-overworld-tileset.png"
const TSX := "res://assets/puny/world/punyworld-overworld-tiles.tsx"
const COLUMNS := 27
const TILE := 16

## Our tile id -> the overworld wang terrain its ground is drawn as; anything
## else stands on grass (forests, flowers, houses, props...).
const GROUND := {
	"water": "river", "bridge": "river", "mountain": "cliff",
	"path": "dirt", "ash": "dirt", "sand": "sand",
}
## Shade pairs every terrain with grass only. Where two others meet at one
## corner, the first of these keeps its corners and the rest fall back to
## grass: cliffs stand over water, water over roads, roads over sand.
const STRENGTH := ["cliff", "river", "dirt", "sand", "trees"]
## Puny Dungeon (assets/puny/dungeon, CC0): its plain stone paves floors
## under the open sky (ruins), cut to one tile for the tile layer.
const DUNGEON_SHEET := "res://assets/puny/dungeon/punyworld-dungeon-tileset.png"
const DUNGEON_COLUMNS := 26
const RUIN_FLOOR := 4

## Regions Shade didn't paint, toned from his grass and dirt by
## shaders/region_tint.gdshader: tile id -> hue. Ash wastes go a burnt warm
## grey, the mire a murky green.
const TINTS := {
	"ash": Color(0.47, 0.45, 0.43),
	"marsh": Color(0.30, 0.42, 0.34),
}
## Ground the hero can walk out onto; maps with none are interiors.
const OUTDOOR := ["grass", "forest", "marsh", "ash", "sand"]

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

## "tl,tr,br,bl" terrain names -> tile ids drawing that corner set.
static var _combos := {}
## tile id -> [[frame tile id, seconds], ...] (the water ripples).
static var _animations := {}
static var _tileset: TileSet
## tile id -> [atlas source id, atlas coords] in _tileset.
static var _slots := {}


static func _load() -> void:
	if not _combos.is_empty():
		return
	var parser := XMLParser.new()
	if parser.open(TSX) != OK:
		push_error("PunyTerrain: cannot read %s" % TSX)
		return
	var tile_id := -1
	var wangset := ""
	var colors: Array[String] = []
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		match parser.get_node_name():
			"tile":
				tile_id = int(parser.get_named_attribute_value("id"))
			"frame":
				var frames: Array = _animations.get_or_add(tile_id, [])
				frames.append([
					int(parser.get_named_attribute_value("tileid")),
					float(parser.get_named_attribute_value("duration")) / 1000.0,
				])
			"wangset":
				wangset = parser.get_named_attribute_value("name")
				colors = []
			"wangcolor":
				colors.append(parser.get_named_attribute_value("name"))
			"wangtile":
				if wangset != "overworld":
					continue
				# Tiled's wangid runs clockwise from the top edge:
				# top, top-right, right, bottom-right, bottom, bottom-left, left, top-left.
				var ids := parser.get_named_attribute_value("wangid").split(",")
				var key := ",".join([
					colors[int(ids[7]) - 1], colors[int(ids[1]) - 1],
					colors[int(ids[3]) - 1], colors[int(ids[5]) - 1],
				])
				var tiles: Array = _combos.get_or_add(key, [])
				tiles.append(int(parser.get_named_attribute_value("tileid")))


## The ground terrain a cell of ours is drawn as.
static func ground_of(tile: String) -> String:
	return GROUND.get(tile, "grass")


## The tile for four corner terrains [tl, tr, br, bl]; `pick` chooses among
## equal tiles (grass has nine) so fields don't repeat.
static func corner_tile(corners: Array, pick: int) -> int:
	_load()
	var key := ",".join(corners)
	if not _combos.has(key):
		key = ",".join(settle(corners))
	var tiles: Array = _combos[key]
	return tiles[absi(pick) % tiles.size()]


## Corners Shade never drew together, reduced to ones he did: the strongest
## terrain keeps its corners, the others become grass; a pairing still
## missing (water touching only diagonally) floods with the strong terrain so
## no blocked cell ever looks walkable.
static func settle(corners: Array) -> Array:
	_load()
	var strongest := "grass"
	for terrain: String in STRENGTH:
		if terrain in corners:
			strongest = terrain
			break
	var settled := corners.map(func(c: String) -> String: return c if c == strongest else "grass")
	if not _combos.has(",".join(settled)):
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


## The per-cell mask region_tint.gdshader reads: a region's hue with full
## coverage, premultiplied so blending between cells keeps the hue true.
static func tint_map(grid: Dictionary, size: Vector2i) -> ImageTexture:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for cell: Vector2i in grid:
		if TINTS.has(grid[cell]):
			image.set_pixelv(cell, TINTS[grid[cell]])
	return ImageTexture.create_from_image(image)


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
		"bridge":
			var span := ["bridge"]
			var across := _run(grid, cell, Vector2i.LEFT, span) + _run(grid, cell, Vector2i.RIGHT, span) + 1
			var down := _run(grid, cell, Vector2i.UP, span) + _run(grid, cell, Vector2i.DOWN, span) + 1
			var water_runs_down: bool = (
				grid.get(cell + Vector2i.UP, "") == "water" or grid.get(cell + Vector2i.DOWN, "") == "water"
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


## One Puny Dungeon tile as its own texture.
static func dungeon_tile(tile_id: int) -> Texture2D:
	var sheet := (load(DUNGEON_SHEET) as Texture2D).get_image()
	var at := Vector2i(tile_id % DUNGEON_COLUMNS, tile_id / DUNGEON_COLUMNS) * TILE
	return ImageTexture.create_from_image(sheet.get_region(Rect2i(at, Vector2i(TILE, TILE))))


## A Puny tile's rectangle on the sheet, for sprites cut from it.
static func region(tile_id: int) -> Rect2:
	return Rect2((tile_id % COLUMNS) * TILE, (tile_id / COLUMNS) * TILE, TILE, TILE)


## The animation frames of a tile ([] when it holds still).
static func animation(tile_id: int) -> Array:
	_load()
	return _animations.get(tile_id, [])


## One TileSet over the Puny sheet, its tiles created on first use.
static func tileset() -> TileSet:
	if _tileset == null:
		_tileset = TileSet.new()
		_tileset.tile_size = Vector2i(TILE, TILE)
	return _tileset


## Sets `cell` of `layer` (built on tileset()) to Puny tile `tile_id`.
static func place(layer: TileMapLayer, cell: Vector2i, tile_id: int) -> void:
	var slot := _slot(tile_id)
	layer.set_cell(cell, slot[0], slot[1])


## Where a tile lives in the TileSet. Animated water keeps its frames 2-4 rows
## apart on Shade's sheet, so frame strips can cross other tiles: a tile that
## doesn't fit an existing atlas source gets a fresh source on the same sheet.
static func _slot(tile_id: int) -> Array:
	if _slots.has(tile_id):
		return _slots[tile_id]
	var coords := Vector2i(tile_id % COLUMNS, tile_id / COLUMNS)
	var frames := animation(tile_id)
	var count := maxi(1, frames.size())
	var columns := 0
	var separation := Vector2i.ZERO
	if count > 1:
		var stride: int = frames[1][0] - frames[0][0]
		# Separation counts whole tiles between frames.
		if stride >= COLUMNS:
			columns = 1  # frames run down the sheet
			separation = Vector2i(0, stride / COLUMNS - 1)
		else:
			separation = Vector2i(stride - 1, 0)
	var atlas := tileset()
	var source: TileSetAtlasSource = null
	var source_id := -1
	for i in atlas.get_source_count():
		var candidate := atlas.get_source(atlas.get_source_id(i)) as TileSetAtlasSource
		if candidate.has_room_for_tile(coords, Vector2i.ONE, columns, separation, count):
			source = candidate
			source_id = atlas.get_source_id(i)
			break
	if source == null:
		source = TileSetAtlasSource.new()
		source.texture = load(SHEET)
		source.texture_region_size = Vector2i(TILE, TILE)
		source_id = atlas.add_source(source)
	source.create_tile(coords)
	if count > 1:
		source.set_tile_animation_columns(coords, columns)
		source.set_tile_animation_separation(coords, separation)
		source.set_tile_animation_frames_count(coords, count)
		for i in count:
			source.set_tile_animation_frame_duration(coords, i, frames[i][1])
	_slots[tile_id] = [source_id, coords]
	return _slots[tile_id]
