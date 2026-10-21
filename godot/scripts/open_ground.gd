class_name OpenGround
## areas: town travel field
## The Medieval Age's greens and snow laid as patches over Shade's grass
## (PIX-305), so a meadow's hollows and the snow's drifts have edges of their
## own, tufted the way the pack's sample maps lay them; the ground's shader
## (shaders/open_ground.gdshaderinc) tones the grass in slow patches, these
## included, and they stand where it is lush (the pack's third green in the
## meadows) or where a drift's blue shadow lies (its snow). Pure: MapView
## lays what `plan` picks, on the cells, from the paid pack (none without it:
## the shader's patches alone, PunyTown.available()), on the maps of the
## Reach's plane (KeptGround: in Pixelheim's yards and gardens, a few cells
## across, a patch read as a rug laid on the lawn).

## The patches' noise, as the shader reads it (patch_noise there): two
## octaves of value noise over the plane, broad swells and the clumps along
## them, in cells, each turned off the grid ([cos, sin] of its turn).
const PATCH_SCALES := Vector2(6.0, 2.0)
const PATCH_WEIGHTS := Vector2(0.62, 0.38)
const SWELLS_TURN := Vector2(0.8775826, 0.4794255)
const CLUMPS_TURN := Vector2(0.4535961, 0.8912074)
const CLUMPS_AT := Vector2(31.7, 31.7)
## Tile -> where a patch lies (the noise above `above` at the cell's middle)
## and its block on the Medieval Age sheet: four columns of fill, then its
## edges and corners (EDGES). The shader's lush greens and its drifts'
## shadows begin at 0.58: the pack's third green stands in the one, its snow
## in the other, a big patch where the swells are deepest, never a speck.
const PATCHES := {
	"grass": {"above": 0.64, "block": Vector2i(0, 8)},
	"snow": {"above": 0.7, "block": Vector2i(0, 20)},
}
## Regions whose ground takes no patch: the mire's grass is the mire's own
## (PunyTerrain.REGION_GRASS), its murk the shader's.
const BARE_REGIONS := ["mire"]
## A patch keeps this many cells clear of the map's edge, so it never meets
## the line with a map beside it.
const MARGIN := 2
## The sheet's columns (PunyTown.COLUMNS).
const COLUMNS := 220
## The pieces of a block, [column, row] from its top-left, by which of the
## four sides lie outside the patch (N, E, S, W): its sample maps' way. Two
## sides facing each other out is never left in a patch (`plan` trims it).
const EDGES := {
	"N": [[13, 0], [14, 0]], "NE": [[15, 0]], "E": [[15, 1], [15, 2]], "SE": [[15, 3]],
	"S": [[13, 3], [14, 3]], "SW": [[12, 3]], "W": [[12, 1], [12, 2]], "NW": [[12, 0]],
}
## A corner of the patch cut in (every side in, one diagonal out), by the
## diagonal outside.
const NOTCHES := {"NW": [9, 1], "NE": [10, 1], "SW": [9, 2], "SE": [10, 2]}
const DIAGONALS := {"NW": Vector2i(-1, -1), "NE": Vector2i(1, -1), "SW": Vector2i(-1, 1), "SE": Vector2i(1, 1)}
## The sides of a cell, as bits, and all four.
const SIDE_BITS := {"N": 1, "E": 2, "S": 4, "W": 8}
const ALL_SIDES := 15


## The patches of a map: cell -> Medieval Age tile. `origin` is the map's
## corner in the Reach's plane (zero off it), where the shader's noise runs.
static func plan(grid: Dictionary, size: Vector2i, regions: Dictionary, origin: Vector2i) -> Dictionary:
	var lattice := {}
	var kind := {}
	rows(grid, size, regions, origin, 0, size.y, lattice, kind)
	return shape(kind)


## Rows [from, to) of `plan`'s first step (KeptGround works it out a few
## rows a frame): the cells a patch may cover, into `kind` (cell -> tile).
static func rows(grid: Dictionary, size: Vector2i, regions: Dictionary, origin: Vector2i, from: int, to: int, lattice: Dictionary, kind: Dictionary) -> void:
	for y in range(maxi(from, MARGIN), mini(to, size.y - MARGIN)):
		for x in range(MARGIN, size.x - MARGIN):
			var cell := Vector2i(x, y)
			var tile: String = grid.get(cell, "")
			if not PATCHES.has(tile) or regions.get(cell, "") in BARE_REGIONS:
				continue
			if noise(Vector2(origin + cell) + Vector2(0.5, 0.5), lattice) > float(PATCHES[tile]["above"]) and _open_round(grid, cell):
				kind[cell] = tile


## The patch cells `kind` (cell -> its tile) trimmed to shapes the pack has
## pieces for, each with its piece.
static func shape(kind: Dictionary) -> Dictionary:
	var cells := kind.duplicate()
	# Strips first, until none is left (a strip's end cuts two corners into
	# the patch it leaves), then any cell still cut at two corners, and the
	# strips that leaves; each cell trimmed asks again of its neighbours.
	var waiting: Array = cells.keys()
	var cut_too := false
	while not waiting.is_empty() or not cut_too:
		if waiting.is_empty():
			cut_too = true
			waiting = cells.keys()
		var next: Array = []
		for cell: Vector2i in waiting:
			if not cells.has(cell):
				continue
			var inside := _sides(cells, cell)
			var whole := inside == ALL_SIDES
			if _strip(inside) or (cut_too and whole and _cut(cells, cell).size() > 1):
				cells.erase(cell)
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						next.append(cell + Vector2i(dx, dy))
		waiting = next
	var out := {}
	for cell: Vector2i in cells:
		out[cell] = piece(cells, cell, PATCHES[cells[cell]]["block"])
	return out


## Whether a cell whose `inside` sides are in is a strip a cell wide either
## way: the pack has no piece for one.
static func _strip(inside: int) -> bool:
	return inside & 5 == 0 or inside & 10 == 0


## The tile for `cell` of a patch (`cells`), its block's top-left at
## `block`: an edge or a corner where a side lies outside, a cut corner
## where a diagonal does, else one of the fills.
static func piece(cells: Dictionary, cell: Vector2i, block: Vector2i) -> int:
	var inside := _sides(cells, cell)
	var out := ""
	for side: String in ["N", "S", "E", "W"]:
		if inside & int(SIDE_BITS[side]) == 0:
			out += side
	var h := absi(hash(cell))
	var at: Array
	if out != "":
		var choices: Array = EDGES[out]
		at = choices[h % choices.size()]
	else:
		var cut := _cut(cells, cell)
		at = NOTCHES[cut[0]] if not cut.is_empty() else [h % 4, (h >> 4) % 4]
	return (block.y + int(at[1])) * COLUMNS + block.x + int(at[0])


## Which sides of `cell` lie in the patch, as SIDE_BITS.
static func _sides(cells: Dictionary, cell: Vector2i) -> int:
	var inside := 0
	if cells.has(cell + Vector2i.UP):
		inside |= 1
	if cells.has(cell + Vector2i.RIGHT):
		inside |= 2
	if cells.has(cell + Vector2i.DOWN):
		inside |= 4
	if cells.has(cell + Vector2i.LEFT):
		inside |= 8
	return inside


## The diagonals outside a patch round a cell whose sides are all in.
static func _cut(cells: Dictionary, cell: Vector2i) -> Array:
	var out := []
	for diagonal: String in DIAGONALS:
		if not cells.has(cell + DIAGONALS[diagonal]):
			out.append(diagonal)
	return out


## Whether every cell round `cell` is Shade's grass to the edge: a patch
## stays clear of roads, water, sand and cliffs and their tufted edges.
static func _open_round(grid: Dictionary, cell: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if PunyTerrain.ground_at(grid, cell + Vector2i(dx, dy)) != "grass":
				return false
	return true


## Every tile a patch may draw, for PunyTown's tileset to make up front.
static func pieces() -> Array[int]:
	var out: Array[int] = []
	for tile: String in PATCHES:
		var block: Vector2i = PATCHES[tile]["block"]
		var at: Array = []
		for y in 4:
			for x in 4:
				at.append([x, y])
		for side: String in EDGES:
			at.append_array(EDGES[side])
		at.append_array(NOTCHES.values())
		for spot: Array in at:
			var id := (block.y + int(spot[1])) * COLUMNS + block.x + int(spot[0])
			if id not in out:
				out.append(id)
	return out


## The patches' noise at a point of the plane, in cells (0..1), as the
## shader's patch_noise reads it at that point's pixel; `lattice` keeps the
## hashes of the lattice's points a map reads many times.
static func noise(at: Vector2, lattice: Dictionary) -> float:
	return PATCH_WEIGHTS.x * _value(_turned(at / PATCH_SCALES.x, SWELLS_TURN), lattice) \
		+ PATCH_WEIGHTS.y * _value(_turned(at / PATCH_SCALES.y, CLUMPS_TURN) + CLUMPS_AT, lattice)


static func _turned(p: Vector2, turn: Vector2) -> Vector2:
	return Vector2(p.x * turn.x - p.y * turn.y, p.x * turn.y + p.y * turn.x)


static func _value(p: Vector2, lattice: Dictionary) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _lattice(i, lattice)
	var b := _lattice(i + Vector2(1.0, 0.0), lattice)
	var c := _lattice(i + Vector2(0.0, 1.0), lattice)
	var d := _lattice(i + Vector2(1.0, 1.0), lattice)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


static func _lattice(i: Vector2, lattice: Dictionary) -> float:
	if not lattice.has(i):
		lattice[i] = ground_hash(i)
	return lattice[i]


## The shader's ground_hash: a point -> 0..1, with no sine.
static func ground_hash(p: Vector2) -> float:
	var p3 := Vector3(p.x, p.y, p.x) * 0.1031
	p3 = p3 - p3.floor()
	p3 += Vector3.ONE * p3.dot(Vector3(p3.y, p3.z, p3.x) + Vector3(33.33, 33.33, 33.33))
	var v := (p3.x + p3.y) * p3.z
	return v - floorf(v)
