class_name StoneWalls
## areas: travel field
## The walls standing in the open that are neither a ruin nor Pixelheim's
## rampart (PIX-386, Tom on PIX-381's ruins: the other walls built from the
## same pale pieces): Greyhold's fort, a hut's walls. They were Shade's
## overworld castle pieces, a tiny tower or run a cell, near-white, striped
## and stacked in a hard grid. Now they are whole walls in the ruins' stone
## (RuinArt): the Puny Dungeon's tops and faces by its grammar (Ruins.base_of),
## so a run reads as one wall with its corners and ends, battlements along
## a fort's open sides, a little moss and a crack here and there, the look of
## the ground round them (Ruins.look_of: woods, mire, snow, ash), their
## shadow south and east and a tuft or a stone at their foot. Each cell's
## piece is seeded by the cell. Pure: RuinsLayer lays the pieces; the grid
## is untouched, so every wall still blocks and every gate and gap stays
## where it was.

## How many joined cells a wall runs to before it is a fort's: battlements
## on its open sides. A hut's walls and a lone pillar stand plain.
const FORT := 12
## Of a wall's cells, the share cracked and grown over; the rest plain
## stone. Kept low: a wall someone still mans.
const GROWN := 22
## Of the open cells at a wall's foot, the share with a tuft and the share
## with a stone lying there.
const TUFTS := 14
const RUBBLE := 5
## What lies at a wall's foot lies on open ground, never on a road.
const LITTERED := ["grass", "stone", "floor", "sand", "snow", "ash", "marsh"]
const SHADED := LITTERED + ["path", "flowers"]


## The standing walls on `grid` (an outdoor map's): every wall cell but
## those in `skip` (a ruin's, the rampart's, the village far off). {"walls":
## {cell: RuinArt tile}, "ground": {cell: RuinArt tile} (shadow and litter
## on open cells), "looks": [one per run of wall]}.
static func plan(grid: Dictionary, skip: Dictionary) -> Dictionary:
	var out := {"walls": {}, "ground": {}, "looks": []}
	var seen := {}
	# A map's grid is read in rows (MapData.in_rows): the same order each
	# time. Its tiles as an array: most maps have no wall to find.
	var cells: Array = grid.keys()
	var tiles: Array = grid.values()
	for i in cells.size():
		var start: Vector2i = cells[i]
		if tiles[i] != "wall" or seen.has(start) or skip.has(start):
			continue
		var walls := Ruins.joined(grid, start, ["wall"])
		for cell: Vector2i in walls.keys():
			seen[cell] = true
			if skip.has(cell):
				walls.erase(cell)
		var look := Ruins.look_of(grid, walls)
		out["looks"].append(look)
		_lay(grid, walls, RuinArt.LOOKS.find(look), walls.size() >= FORT, skip, out)
	return out


## One wall's pieces into `out`: each cell's stone, then the ground at its
## foot.
static func _lay(grid: Dictionary, walls: Dictionary, look: int, fort: bool, skip: Dictionary, out: Dictionary) -> void:
	var foot := {}
	# Its outer side, for a run down it: away from the middle of the wall.
	var span := Rect2i(walls.keys()[0], Vector2i.ONE)
	for cell: Vector2i in walls:
		span = span.expand(cell).expand(cell + Vector2i.ONE)
	for cell: Vector2i in walls:
		var outer := Vector2i.LEFT if cell.x * 2 < span.position.x + span.end.x - 1 else Vector2i.RIGHT
		var base := Ruins.base_of(walls, cell)
		var battled := battlements(walls, cell, outer) if fort else 0
		var variant := RuinArt.GROWN if Ruins.cell_dice(cell, "standing") % 100 < GROWN else RuinArt.PLAIN
		if battled == 0:
			out["walls"][cell] = RuinArt.wall(look, base, variant)
		else:
			out["walls"][cell] = RuinArt.standing(look, RuinArt.SHAPES.find(Vector2i(base, battled)), variant)
		# Its shadow falls south and east, what lies at its foot beside it.
		for step: Vector2i in Ruins.STEPS:
			var next := cell + step
			if not walls.has(next) and not skip.has(next) and grid.get(next, "") in SHADED:
				foot[next] = true
	for cell: Vector2i in foot:
		var shadow := (1 if walls.has(cell + Vector2i.UP) else 0) + (2 if walls.has(cell + Vector2i.LEFT) else 0)
		var litter := 0
		var dice := Ruins.cell_dice(cell, "foot")
		if grid[cell] in LITTERED:
			if dice % 100 < TUFTS:
				litter = RuinArt.TUFT_A + (dice >> 8) % 2
			elif dice % 100 < TUFTS + RUBBLE:
				litter = RuinArt.RUBBLE_A
		if shadow > 0 or litter > 0:
			out["ground"][cell] = RuinArt.ground(look, shadow, litter)


## The sides of a wall cell's top lined with merlons (RuinArt.BATTLED_*):
## a face (its south open) along its top where nothing joins it from the
## north; a top seen from above along its north if open, and its `outer`
## side (Vector2i.LEFT or RIGHT) if open: the wall's inner side has none.
static func battlements(walls: Dictionary, cell: Vector2i, outer: Vector2i) -> int:
	var north := 0 if walls.has(cell + Vector2i.UP) else RuinArt.BATTLED_N
	if not walls.has(cell + Vector2i.DOWN) or walls.has(cell + outer):
		return north
	return north | (RuinArt.BATTLED_W if outer == Vector2i.LEFT else RuinArt.BATTLED_E)
