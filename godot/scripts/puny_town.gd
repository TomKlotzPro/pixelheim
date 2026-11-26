class_name PunyTown
## areas: town +town-age*
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
const ROWS := 132

## Roof kind -> rows down the atlas to that colour's copy of the pieces;
## blue, crimson and teal are the Town's and the City's new houses' (PIX-525).
const ROOF_ROWS := {
	"roof": 0, "roof_awning": 0, "roof_thatch": 16, "roof_blue": 31, "roof_crimson": 46, "roof_teal": 61,
	"roof_moss": 76, "roof_slate": 91,
}
## The roof pieces (terracotta) sit in columns 76-119 of rows 0-15; the
## colour copies repeat that block lower down, 15 rows apart after the
## terracotta's 16. Walls, doors and windows are shared by every colour.
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
## A small house standing on its own (cottage, PIX-557): cells across and up.
const COTTAGE := Vector2i(3, 3)

## Which slope a roof piece lies on, for the roof's light (PIX-523,
## shaders/roof_light.gdshader): a gable's west and east, a wing's north
## (above its ridge) and south; a ridge piece is the two halves of the
## slopes either side of the ridge in its middle, down a gable, across a
## wing. EDGE_TOP marks a piece whose first row is the roof's top outline.
const SLOPE_WEST := 1
const SLOPE_EAST := 2
const SLOPE_NORTH := 3
const SLOPE_SOUTH := 4
const RIDGE_DOWN := 5
const RIDGE_ACROSS := 6
const EDGE_TOP := 8

static var _tileset: TileSet
static var _roof_light: ShaderMaterial
static var _source: TileSetAtlasSource
## The pack held back though it's here (the harness's `cc0`, PIX-318): the
## run draws what a build without the private art draws.
static var withheld := false


static func available() -> bool:
	return not withheld and ResourceLoader.exists(SHEET)


## Every building on a map: {"pieces": {cell: tile}, "decor": {cell: tile},
## "freed": [cells]}. `freed` are roof cells the new houses leave open (above
## a low lean-to): they become ground. Empty when the pack is missing.
## `style`: a settlement's own grammar (Hamlet.house_style, PIX-313).
static func compose(grid: Dictionary, style := {}) -> Dictionary:
	if not available():
		return {"pieces": {}, "decor": {}, "freed": []}
	return plan(grid, style)


## The houses as tile ids, whether or not the pack is here to draw them
## (what the tests check). A `style` (Hamlet.house_style, PIX-313) builds
## them in a settlement's own grammar: its `walls` (sets of [left end,
## middle, right end] for Shade's timber frame's, one per house in turn,
## PIX-400; [] keeps his) or its `fronts` (a set by door, PIX-525), a
## `chimney` on every roof (but a house with one of the settlement's own
## `stacks` cells: a forge's stack, a shed's door).
static func plan(grid: Dictionary, style := {}) -> Dictionary:
	var pieces := {}
	var decor := {}
	var freed: Array[Vector2i] = []
	var stacks: Array = style.get("stacks", [])
	var blobs := _blobs(grid)
	for i in blobs.size():
		var house := {}
		_building(blobs[i], grid, house, decor, style.get("chimney", false) and not blobs[i].any(func(cell: Vector2i) -> bool: return cell in stacks))
		var own: Array = walls_of(style, i, _door(blobs[i], grid))
		var swap := {WALL_LEFT: own[0], WALL: own[1], WALL_RIGHT: own[2]} if not own.is_empty() else {}
		for cell: Vector2i in house:
			pieces[cell] = swap.get(house[cell], house[cell])
		for cell: Vector2i in blobs[i]:
			if not pieces.has(cell):
				freed.append(cell)
	return {"pieces": pieces, "decor": decor, "freed": freed}


## The walls the `i`th house, its door at `door`, wears in `style`: its
## `fronts`' set by door (PIX-525: by door, so a house keeps its front as
## the ages raise more), else the `walls`' sets in turn (PIX-400:
## Saltmere's three were one cottage three times); [] keeps Shade's timber.
static func walls_of(style: Dictionary, i: int, door: Vector2i) -> Array:
	var fronts: Dictionary = style.get("fronts", {})
	if fronts.has(door):
		return fronts[door]
	var walls: Array = style.get("walls", [])
	return walls[i % walls.size()] if not walls.is_empty() else []


## Whether `tile` is a house's wall (its timber, a settlement's own, a
## window or the door) rather than its roof: what a snowed roof leaves bare.
static func is_wall(tile: int) -> bool:
	return tile in [WALL_LEFT, WALL, WALL_RIGHT, WINDOW, DOOR] or tile in Hamlet.pieces()


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
		out.append({"rect": Rect2i(low, high - low + Vector2i.ONE), "kind": roof_kind(blob, grid), "door": _door(blob, grid)})
	return out


## The house whose door is `door`: its cells' bounding box, empty for none.
static func house_of(grid: Dictionary, door: Vector2i) -> Rect2i:
	for house: Dictionary in houses(grid):
		if house["door"] == door:
			return house["rect"]
	return Rect2i()


## A house's door: the last one on its bottom row ((-1, -1) for none).
static func _door(blob: Array, grid: Dictionary) -> Vector2i:
	var bottom: int = blob.map(func(cell: Vector2i) -> int: return cell.y).max()
	var door := Vector2i(-1, -1)
	for cell: Vector2i in blob:
		if cell.y == bottom and String(grid[cell]).begins_with("door"):
			door = cell
	return door


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


## A small house standing on its own among the actors (PIX-557: a
## waystation's hut, a Mirefen stilt hut, Gunnar's lodge; ours stood at
## 60% of these houses' scale, the hero taller than their doors): COTTAGE
## cells, a narrow house as the town's three tall are (_wing): the
## hip-roofed wing's ridge over its eave in roof `kind`'s colour (its top
## and eave alone were a flat slab: PIX-557's review), over a wall of
## `front`'s tiles left to right, closed at its ends as _wing closes it
## (a door or a wall's end, the window beside the door); its roof under the
## Frostgate's snow when `snow` (as the houses' layers lay it). Drawn as
## the houses are, its roof taking the light, its bottom-left at the node's
## origin. Only with the pack.
static func cottage(kind: String, front: Array, snow := false) -> Node2D:
	var house := Node2D.new()
	var walls := MapView.tile_layer_of(tileset())
	walls.material = roof_light()
	house.add_child(walls)
	var roof := walls
	if snow:
		roof = MapView.tile_layer_of(tileset())
		var snowed := ShaderMaterial.new()
		snowed.shader = preload("res://shaders/snowed_roof.gdshader")
		roof.material = snowed
		house.add_child(roof)
	var shift: int = ROOF_ROWS[kind] * COLUMNS
	for x in COTTAGE.x:
		var end := 0 if x == 0 else (2 if x == COTTAGE.x - 1 else 1)
		place(roof, Vector2i(x, -3), _tint(WING_RIDGE[end], shift))
		place(roof, Vector2i(x, -2), _tint(WING_EAVE[end], shift))
		place(walls, Vector2i(x, -1), front[x])
	return house


static func _building(blob: Array, grid: Dictionary, pieces: Dictionary, decor: Dictionary, chimney := false) -> void:
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
	# A settlement's chimney on every roof (PIX-313), where Shade's gable
	# put none: on the main house's ridge, a column in from its east end.
	var roof_top := _top(top_of, main_left, main_right)
	if chimney and not _chimneyed(decor, main_left, main_right, roof_top, bottom):
		if bottom - roof_top + 1 >= 2:
			var ridge := roof_top + (1 if bottom - roof_top + 1 >= 4 else 0)
			decor[Vector2i(maxi(main_left, main_right - 1), ridge)] = CHIMNEY[1]


## Whether a chimney already stands on the house over columns a..b, rows
## `top` to its wall's `bottom` (PIX-399: not a house further up the same
## columns, Greyhold's keep over its smithy).
static func _chimneyed(decor: Dictionary, a: int, b: int, top: int, bottom: int) -> bool:
	for cell: Vector2i in decor:
		if decor[cell] == CHIMNEY[1] and cell.x >= a and cell.x <= b and cell.y >= top and cell.y < bottom:
			return true
	return false


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


## One atlas source over the whole sheet; tiles are created as first used,
## but for every piece of a house (in each roof colour) and the flowers,
## made at once with it (One Reach, PIX-269): a tile made later redraws the
## source's padded copy of this whole sheet, some 20 ms, and a map drawn
## beside the hero's with flowers or houses the session hadn't drawn yet
## made the hero's frame that long.
static func tileset() -> TileSet:
	if _tileset == null:
		_tileset = TileSet.new()
		_tileset.tile_size = Vector2i(16, 16)
		_source = TileSetAtlasSource.new()
		_source.texture = load(SHEET)
		_source.texture_region_size = Vector2i(16, 16)
		_tileset.add_source(_source, 0)
		if available():
			for tile: int in pieces():
				var coords := Vector2i(tile % COLUMNS, tile / COLUMNS)
				if not _source.has_tile(coords):
					_source.create_tile(coords)
	return _tileset


## Every tile a house may be built of, in each roof colour, the flowers
## (PunyProps.FLOWERS), Pixelheim's rampart and gatehouse (Rampart) and the
## streets' paving (Streets), the open ground's patches of green and snow
## (OpenGround, PIX-305), the settlements' own walls (Hamlet, PIX-313) and
## the ivy up the town's (Yards, PIX-525).
static func pieces() -> Array[int]:
	var base: Array = GABLE_TOP + GABLE_FOOT + GABLE_EAVE + GABLE_WALL + CHIMNEY + WING_TOP + WING_UPPER + WING_RIDGE \
		+ WING_LOWER + WING_EAVE + UPPER_FILL + LOWER_FILL + [WALL_LEFT, WALL, WALL_RIGHT, WINDOW, DOOR]
	for row: Array in GABLE_BODY:
		base.append_array(row)
	var out: Array[int] = []
	for tile: int in base:
		if tile < 0:
			continue
		for rows: int in ROOF_ROWS.values():
			var tinted := _tint(tile, rows * COLUMNS)
			if tinted not in out:
				out.append(tinted)
	var more: Array = PunyProps.FLOWERS + Rampart.WALL.values() + [Rampart.GATE, Rampart.ROOF_BURNT] + Rampart.TOWER + Rampart.ROOF \
		+ Streets.pieces() + OpenGround.pieces() + Hamlet.pieces() + Yards.IVY_RAGGED.values() + Yards.IVY_FULL.values()
	for tile: int in more:
		if tile not in out:
			out.append(tile)
	return out


## Each roof piece (in the terracotta, before its colour's shift) -> the
## slope it lies on (SLOPE_*, RIDGE_*, + EDGE_TOP).
static func roof_slopes() -> Dictionary:
	var out := {}
	var gable: Array = [GABLE_TOP] + GABLE_BODY + [GABLE_FOOT, GABLE_EAVE]
	for r in gable.size():
		var row: Array = gable[r]
		for c in row.size():
			var slope := SLOPE_WEST if c < 4 else (RIDGE_DOWN if c == 4 else SLOPE_EAST)
			out[row[c]] = slope + (EDGE_TOP if r == 0 else 0)
	var wing := {
		SLOPE_NORTH + EDGE_TOP: WING_TOP, SLOPE_NORTH: WING_UPPER + UPPER_FILL, RIDGE_ACROSS: WING_RIDGE,
		SLOPE_SOUTH: WING_LOWER + LOWER_FILL + WING_EAVE,
	}
	for slope: int in wing:
		for tile: int in (wing[slope] as Array):
			if tile >= 0:
				out[tile] = slope
	return out


## The houses' layer's material (PIX-523): roofs that take the sun and the
## moon (shaders/roof_light.gdshader), made once.
static func roof_light() -> ShaderMaterial:
	if _roof_light == null:
		_roof_light = ShaderMaterial.new()
		_roof_light.shader = preload("res://shaders/roof_light.gdshader")
		_roof_light.set_shader_parameter("slopes", ImageTexture.create_from_image(roof_map()))
		_roof_light.set_shader_parameter("columns", float(COLUMNS))
	return _roof_light


## What the roof's light reads, a texel per tile of the atlas: r the roof
## piece's slope (0 for anything else), g how many rows down its copy in
## another roof colour lies, +128 (what the two copies share is the wall
## under the roof). Every colour in ROOF_ROWS is in it, so a roof colour
## added there takes the light too.
static func roof_map() -> Image:
	var map := Image.create(COLUMNS, ROWS, false, Image.FORMAT_RG8)
	var slopes := roof_slopes()
	var furthest: int = ROOF_ROWS.values().max()
	for tile: int in slopes:
		for rows: int in ROOF_ROWS.values():
			var tinted := _tint(tile, rows * COLUMNS)
			map.set_pixel(tinted % COLUMNS, tinted / COLUMNS, Color8(int(slopes[tile]), 128 + (furthest if rows == 0 else -rows), 0))
	return map


static func place(layer: TileMapLayer, cell: Vector2i, tile: int) -> void:
	tileset()
	var coords := Vector2i(tile % COLUMNS, tile / COLUMNS)
	if not _source.has_tile(coords):
		_source.create_tile(coords)
	layer.set_cell(cell, 0, coords)
