class_name Ruins
## areas: travel field
## The old stone ruins standing in the open (PIX-381, Tom: « can you revamp
## this, there are many across the full map, it's super ugly »): a map's
## walls round a stone floor under the sky, the Mirefen's shrine and the
## Deepwood's courtyard. They were Shade's overworld castle pieces (a town's
## wall seen from afar), pale, striped and stacked in a hard grid. Now each is
## a weathered ruin in his Puny Dungeon stone: low walls with their tops and
## faces by the dungeon's grammar (PunyDungeon.wall_tile), knocked about on
## their open sides and grown over the region's way (moss in the woods, murk
## in the mire, snow in the north, soot in the ash), their shadow on the
## ground south and east of them, rubble at their foot and tufts in the
## floor's cracks. Each cell's piece is seeded by the cell, so no two ruins
## are alike. Pure: RuinsLayer lays the pieces RuinArt draws; the grid is
## untouched, so what blocks still blocks and the ways in stay open.

## Each ruin's look by the ground round it, the first of these found there
## at least `LOOK_CELLS` times: else the woods' moss.
const GROUND_LOOKS := [["snow", "snow"], ["ash", "ash"], ["marsh", "mire"]]
const LOOK_CELLS := 3
## Of a wall's outer course (no floor beside it), the share fallen into a
## heap of its stones; the course lining the floor always stands.
const FALLEN := 60
## Of a standing wall's cells, the share grown over and the share knocked
## about (on an open side); the rest plain stone.
const GROWN := 30
const CHIPPED := 28
## Of the open cells at a wall's foot, the share with rubble lying there, and
## of the floor's other cells the share with a tuft in a crack.
const RUBBLE := 40
const TUFTS := 22

const STEPS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]


## The ruins on `grid` (an outdoor map's): every wall touching a floor, and
## the walls joined to it. {"walls": {cell: RuinArt tile}, "ground": {cell:
## RuinArt tile} (the shadow, rubble and tufts on open cells), "looks":
## [one per run of wall]}, all of them empty on a map without ruins.
static func plan(grid: Dictionary) -> Dictionary:
	var out := {"walls": {}, "ground": {}, "looks": []}
	var seen := {}
	# A map's grid is read in rows (MapData.in_rows): the same order each time.
	for start: Vector2i in grid:
		if seen.has(start) or grid[start] != "wall":
			continue
		var walls := _joined(grid, start, ["wall"])
		for cell: Vector2i in walls:
			seen[cell] = true
		var floor_cells := {}
		for cell: Vector2i in walls:
			for step: Vector2i in STEPS:
				if grid.get(cell + step, "") == "floor" and not floor_cells.has(cell + step):
					floor_cells.merge(_joined(grid, cell + step, ["floor"]))
		if floor_cells.is_empty():
			continue
		var look := look_of(grid, walls)
		out["looks"].append(look)
		_lay(grid, walls, floor_cells, RuinArt.LOOKS.find(look), out)
	return out


## The look of the ruin standing on `walls`: by the ground round it.
static func look_of(grid: Dictionary, walls: Dictionary) -> String:
	var counts := {}
	for cell: Vector2i in walls:
		for y in range(-1, 2):
			for x in range(-1, 2):
				var tile: String = grid.get(cell + Vector2i(x, y), "")
				counts[tile] = int(counts.get(tile, 0)) + 1
	for pair: Array in GROUND_LOOKS:
		if int(counts.get(pair[0], 0)) >= LOOK_CELLS:
			return pair[1]
	return "wood"


## Every cell of `tiles` joined to `start` side by side, as a set.
static func _joined(grid: Dictionary, start: Vector2i, tiles: Array) -> Dictionary:
	var out := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var cell: Vector2i = todo.pop_back()
		for step: Vector2i in STEPS:
			var next: Vector2i = cell + step
			if not out.has(next) and grid.get(next, "") in tiles:
				out[next] = true
				todo.append(next)
	return out


## One ruin's pieces into `out`: each wall's, then the ground's at its foot
## and on its floor.
static func _lay(grid: Dictionary, walls: Dictionary, floor_cells: Dictionary, look: int, out: Dictionary) -> void:
	var standing := {}
	for cell: Vector2i in walls:
		if inner(grid, cell) or _dice(cell, "fall") % 100 >= FALLEN:
			standing[cell] = true
	var foot := {}
	for cell: Vector2i in walls:
		if standing.has(cell):
			out["walls"][cell] = RuinArt.wall(look, base_of(standing, cell), _variant(standing, cell))
		else:
			out["walls"][cell] = RuinArt.mound(look, _dice(cell, "mound") % RuinArt.MOUNDS)
		for y in range(-1, 2):
			for x in range(-1, 2):
				var next := cell + Vector2i(x, y)
				if not walls.has(next) and grid.has(next):
					foot[next] = true
	for cell: Vector2i in floor_cells:
		foot[cell] = true
	for cell: Vector2i in foot:
		var shadow := (1 if standing.has(cell + Vector2i.UP) else 0) + (2 if standing.has(cell + Vector2i.LEFT) else 0)
		var litter := 0
		var dice := _dice(cell, "litter")
		# Nothing lies under what stands on the floor (the shrine's knight).
		if grid[cell] in ["floor", "grass", "forest", "marsh", "snow", "ash", "sand", "path"]:
			var by_wall := STEPS.any(func(step: Vector2i) -> bool: return walls.has(cell + step))
			if by_wall and dice % 100 < RUBBLE:
				litter = RuinArt.RUBBLE_A + (dice >> 8) % 2
			elif grid[cell] == "floor" and dice % 100 < TUFTS + (RUBBLE if by_wall else 0):
				litter = RuinArt.TUFT_A + (dice >> 8) % 2
		if shadow > 0 or litter > 0:
			out["ground"][cell] = RuinArt.ground(look, shadow, litter)


## Whether a wall cell lines the ruin's floor (its inner course, always
## standing): the floor or the shrine beside it, even diagonally.
static func inner(grid: Dictionary, cell: Vector2i) -> bool:
	for y in range(-1, 2):
		for x in range(-1, 2):
			if grid.get(cell + Vector2i(x, y), "") in ["floor", "shrine"]:
				return true
	return false


## A standing wall cell's stone by the dungeon's grammar (PunyDungeon.wall_tile), every
## wall of the ruin seen: its top, its face where its south is open, a lone
## column's foot. An index into RuinArt.BASES.
static func base_of(walls: Dictionary, cell: Vector2i) -> int:
	var east := walls.has(cell + Vector2i.RIGHT)
	var west := walls.has(cell + Vector2i.LEFT)
	var column := (1 if east and not west else 0) + (2 if east and west else 0) + (3 if west and not east else 0)
	var north := walls.has(cell + Vector2i.UP)
	if not walls.has(cell + Vector2i.DOWN):
		return RuinArt.BASES.find(PunyDungeon.COLUMN_FOOT if north and column == 0 else PunyDungeon.FACE[column])
	return RuinArt.BASES.find(PunyDungeon.TOP_RUN[column] if north else PunyDungeon.TOP_END[column])


## How weathered a wall cell is (RuinArt.PLAIN, GROWN or a CHIP_*): knocked
## about only on a side it has open, by its own dice.
static func _variant(walls: Dictionary, cell: Vector2i) -> int:
	var dice := _dice(cell, "wall")
	var roll := dice % 100
	if roll < GROWN:
		return RuinArt.GROWN
	if roll < GROWN + CHIPPED:
		var open: Array[int] = []
		for pair: Array in [[Vector2i.UP, RuinArt.CHIP_N], [Vector2i.LEFT, RuinArt.CHIP_W], [Vector2i.RIGHT, RuinArt.CHIP_E]]:
			if not walls.has(cell + pair[0]):
				open.append(pair[1])
		if not open.is_empty():
			return open[(dice >> 8) % open.size()]
	return RuinArt.PLAIN


static func _dice(cell: Vector2i, what: String) -> int:
	return absi(hash([cell.x, cell.y, what]))
