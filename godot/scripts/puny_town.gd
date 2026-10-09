class_name PunyTown
## The town's buildings from Shade's Puny World Medieval Age (PIX-133): every
## house the web map draws as a cluster of roof cells (door and signs on its
## bottom row) is rebuilt from the pack's pieces, the way Shade's sample
## villages compose them:
## - a 9-wide gabled house, centred on the door when the facade is wide
##   enough: gable top, roof body (as many rows as the cluster is tall), the
##   ridge's foot, the eave and a timber wall with windows and the door;
## - hip-roofed wings of any width for the rest: the columns beside the gable
##   (each column group with its own top and its own wall row), or the whole
##   house when it is too narrow for a gable;
## - the roof colour from the web's roof kind, as a fixed row shift into the
##   pack's colour blocks.
## The pack is paid and lives outside the public repository (assets/puny/
## medieval/, fetched from the private pixelheim-assets repo); without it the
## town keeps its old buildings.

const SHEET := "res://assets/puny/medieval/punyworld-atlas.png"
const COLUMNS := 220

## Roof kind -> rows down the atlas to that colour's copy of the pieces.
const ROOF_ROWS := {
	"roof": 0, "roof_awning": 0, "roof_thatch": 16, "roof_moss": 76, "roof_slate": 91,
}
## The roof pieces (terracotta) sit in columns 76-119 of rows 0-15; the
## colour copies repeat that block lower down. Walls, doors and windows are
## shared by every colour.
const ROOF_COLS := Vector2i(76, 119)
const ROOF_BLOCK_ROWS := 16

## The 9-wide gable (sample village 1's cottage).
const GABLE_TOP := [742, 743, 744, 745, 1402, 747, 748, 749, 750]
const GABLE_BODY := [
	[962, 83, 84, 522, 1622, 308, 529, 310, 970],
	[962, 82, 524, 303, 1622, 90, 308, 310, 970],
	[962, 522, 304, 523, 1622, 89, 528, 310, 970],
	[962, 82, 304, 303, 1622, 89, 310, 310, 970],
	[962, 523, 522, 302, 1622, 529, 88, 529, 970],
]
const GABLE_FOOT := [962, 83, 82, 965, 1842, 967, 88, 89, 970]
const GABLE_EAVE := [311, 312, 313, 314, 315, 316, 317, 318, 319]
const GABLE_WALL := [941, 945, 3659, 949, 4095, 941, 3659, 945, 949]
const CHIMNEY := [1873, 2093]

## Hip-roof wings (sample villages 1 and 2): [left end, middle, right end].
const WING_TOP := [79, 80, 81]
const WING_UPPER := [299, -1, 301]
const WING_RIDGE := [1399, 1400, 1401]
const WING_LOWER := [739, -1, 741]
const WING_EAVE := [959, 960, 961]
const UPPER_FILL := [297, 77, 297, 78, 296, 297, 517]
const LOWER_FILL := [1617, 1617, 1837, 1618, 1617, 1838]

const WALL_LEFT := 941
const WALL := 945
const WALL_RIGHT := 949
const WINDOW := 3659
const DOOR := 4095

static var _tileset: TileSet
static var _source: TileSetAtlasSource


static func available() -> bool:
	return ResourceLoader.exists(SHEET)


## Every building on a map: {"pieces": {cell: tile}, "decor": {cell: tile},
## "freed": [cells]}. `freed` are roof cells the new houses leave open (above
## a low lean-to): they become ground. Empty when the pack is missing.
static func compose(grid: Dictionary) -> Dictionary:
	if not available():
		return {"pieces": {}, "decor": {}, "freed": []}
	return plan(grid)


## The houses as tile ids, whether or not the pack is here to draw them
## (what the tests check).
static func plan(grid: Dictionary) -> Dictionary:
	var pieces := {}
	var decor := {}
	var freed: Array[Vector2i] = []
	for blob: Array in _blobs(grid):
		_building(blob, grid, pieces, decor)
		for cell: Vector2i in blob:
			if not pieces.has(cell):
				freed.append(cell)
	return {"pieces": pieces, "decor": decor, "freed": freed}


## The cells that make houses: roofs, and the doors and signs set in them.
static func _is_house(tile: String) -> bool:
	return tile.begins_with("roof") or tile.begins_with("sign_") or tile == "door" or tile == "door_shut"


## Connected clusters of house cells that hold at least one roof.
static func _blobs(grid: Dictionary) -> Array:
	var seen := {}
	var blobs := []
	for start: Vector2i in grid:
		if seen.has(start) or not _is_house(grid[start]):
			continue
		var blob: Array[Vector2i] = []
		var stack: Array[Vector2i] = [start]
		var roofed := false
		while not stack.is_empty():
			var cell: Vector2i = stack.pop_back()
			if seen.has(cell) or not _is_house(grid.get(cell, "")):
				continue
			seen[cell] = true
			blob.append(cell)
			roofed = roofed or String(grid[cell]).begins_with("roof")
			for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				stack.append(cell + step)
		if roofed:
			blobs.append(blob)
	return blobs


## Every house on a map as the far-off view needs it (PIX-248, Skyline): its
## cells' bounding box, its roof kind, and its door (-1, -1 for none) - the
## same clusters the town builds its houses from.
static func houses(grid: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for blob: Array in _blobs(grid):
		var low: Vector2i = blob[0]
		var high: Vector2i = blob[0]
		for cell: Vector2i in blob:
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
		var door := Vector2i(-1, -1)
		for cell: Vector2i in blob:
			if cell.y == high.y and String(grid[cell]).begins_with("door"):
				door = cell
		out.append({"rect": Rect2i(low, high - low + Vector2i.ONE), "kind": roof_kind(blob, grid), "door": door})
	return out


## The roof a house wears: the kind most of its roof cells are.
static func roof_kind(blob: Array, grid: Dictionary) -> String:
	var kinds := {}
	for cell: Vector2i in blob:
		var tile: String = grid[cell]
		if tile.begins_with("roof"):
			kinds[tile] = kinds.get(tile, 0) + 1
	return kinds.keys().reduce(func(a: String, b: String) -> String: return a if kinds[a] >= kinds[b] else b)


## One hip-roofed house filling `rect`, in roof `kind`'s colour, its door at
## column `door_x` (-1 for none): cell -> tile. The town's narrow houses are
## built so; far off, every house is (PIX-248).
static func wing_house(rect: Rect2i, door_x: int, kind: String) -> Dictionary:
	var pieces := {}
	_wing(rect.position.x, rect.end.x - 1, rect.position.y, rect.end.y - 1, door_x, "", ROOF_ROWS.get(kind, 0) * COLUMNS, pieces)
	return pieces


static func _building(blob: Array, grid: Dictionary, pieces: Dictionary, decor: Dictionary) -> void:
	var bottom := -1
	var top_of := {}
	var bottom_of := {}
	for cell: Vector2i in blob:
		bottom = maxi(bottom, cell.y)
		top_of[cell.x] = mini(top_of.get(cell.x, cell.y), cell.y)
		bottom_of[cell.x] = maxi(bottom_of.get(cell.x, cell.y), cell.y)
	var shift: int = ROOF_ROWS.get(roof_kind(blob, grid), 0) * COLUMNS
	var facade: Array = blob.filter(func(cell: Vector2i) -> bool: return cell.y == bottom).map(func(cell: Vector2i) -> int: return cell.x)
	var left: int = facade.min()
	var right: int = facade.max()
	var door_x := -1
	for cell: Vector2i in blob:
		if cell.y == bottom and String(grid[cell]).begins_with("door"):
			door_x = cell.x
	var xs: Array = top_of.keys()
	xs.sort()
	# The main house stands on the facade; wings fill the columns either side.
	var main_left := left
	var main_right := right
	if right - left + 1 >= GABLE_TOP.size():
		var centre := door_x if door_x >= 0 else (left + right) / 2
		main_left = clampi(centre - 4, left, right - 8)
		main_right = main_left + 8
		var top := _top(top_of, main_left, main_right)
		if bottom - top + 1 >= 4:
			_gable(main_left, top, bottom, door_x, shift, pieces, decor)
		else:
			_wing(main_left, main_right, top, bottom, door_x, "", shift, pieces)
	else:
		_wing(left, right, _top(top_of, left, right), bottom, door_x, "", shift, pieces)
	# The rest, in runs of neighbouring columns: each its own lower wing.
	for side: Array in [xs.filter(func(x: int) -> bool: return x < main_left), xs.filter(func(x: int) -> bool: return x > main_right)]:
		if side.is_empty():
			continue
		var a: int = side.min()
		var b: int = side.max()
		var low := -1
		for x: int in side:
			low = maxi(low, bottom_of[x])
		var attached := "right" if b < main_left else "left"
		var top := _top(top_of, a, b)
		# A single column as tall as the house reads as a tower: it becomes a
		# low lean-to instead (its ridge, eave and wall).
		if a == b:
			top = maxi(top, low - 2)
		_wing(a, b, top, low, -1, attached, shift, pieces)


static func _top(top_of: Dictionary, a: int, b: int) -> int:
	var top := 1 << 20
	for x in range(a, b + 1):
		if top_of.has(x):
			top = mini(top, top_of[x])
	return top


static func _gable(x0: int, top: int, bottom: int, door_x: int, shift: int, pieces: Dictionary, decor: Dictionary) -> void:
	var rows: Array = [GABLE_TOP]
	var body := bottom - top + 1 - 3
	for i in body - 1:
		rows.append(GABLE_BODY[i % GABLE_BODY.size()])
	if body >= 1:
		rows.append(GABLE_FOOT)
	rows.append(GABLE_EAVE)
	var wall := GABLE_WALL.duplicate()
	if door_x >= 0 and door_x != x0 + 4:
		wall[4] = WALL
		wall[door_x - x0] = DOOR
	rows.append(wall)
	for r in rows.size():
		for c in 9:
			pieces[Vector2i(x0 + c, top + r)] = _tint(rows[r][c], shift)
	if bottom - top + 1 >= 6:
		decor[Vector2i(x0 + 6, top)] = CHIMNEY[0]
		decor[Vector2i(x0 + 6, top + 1)] = CHIMNEY[1]


## A hip-roofed wing over columns a..b: its top edge, the upper slope, the
## ridge, the lower slope, the eave and a wall with windows (and the door).
## `attached` names the side it leans on ("left", "right"): that end runs on
## instead of closing.
static func _wing(a: int, b: int, top: int, bottom: int, door_x: int, attached: String, shift: int, pieces: Dictionary) -> void:
	var height := bottom - top + 1
	var slopes := maxi(0, height - 4)
	var upper := slopes / 2
	var lower := slopes - upper
	var plan: Array = []
	if height >= 4:
		plan.append(["top", WING_TOP])
	for i in upper:
		plan.append(["upper", WING_UPPER])
	if height >= 3:
		plan.append(["ridge", WING_RIDGE])
	for i in lower:
		plan.append(["lower", WING_LOWER])
	if height >= 2:
		plan.append(["eave", WING_EAVE])
	for r in plan.size():
		var part: Array = plan[r][1]
		for x in range(a, b + 1):
			var at_left := x == a and attached != "left"
			var at_right := x == b and attached != "right"
			var tile: int = part[0] if at_left else (part[2] if at_right else part[1])
			if tile < 0:
				var fill: Array = UPPER_FILL if plan[r][0] == "upper" else LOWER_FILL
				tile = fill[absi(x * 7 + r * 13) % fill.size()]
			pieces[Vector2i(x, top + r)] = _tint(tile, shift)
	for x in range(a, b + 1):
		var tile := WALL
		if x == a and attached != "left":
			tile = WALL_LEFT
		elif x == b and attached != "right":
			tile = WALL_RIGHT
		elif (x - a) % 3 == 1 and b - a >= 2:
			tile = WINDOW
		if x == door_x:
			tile = DOOR
		pieces[Vector2i(x, bottom)] = tile


## A roof piece in the building's colour; walls, doors and windows are shared.
static func _tint(tile: int, shift: int) -> int:
	var col := tile % COLUMNS
	var row := tile / COLUMNS
	if col >= ROOF_COLS.x and col <= ROOF_COLS.y and row < ROOF_BLOCK_ROWS:
		return tile + shift
	return tile


## One atlas source over the whole sheet; tiles are created as first used.
static func tileset() -> TileSet:
	if _tileset == null:
		_tileset = TileSet.new()
		_tileset.tile_size = Vector2i(16, 16)
		_source = TileSetAtlasSource.new()
		_source.texture = load(SHEET)
		_source.texture_region_size = Vector2i(16, 16)
		_tileset.add_source(_source, 0)
	return _tileset


static func place(layer: TileMapLayer, cell: Vector2i, tile: int) -> void:
	tileset()
	var coords := Vector2i(tile % COLUMNS, tile / COLUMNS)
	if not _source.has_tile(coords):
		_source.create_tile(coords)
	layer.set_cell(cell, 0, coords)
