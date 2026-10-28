class_name Streets
## areas: town travel +town-age* +greyhold* +frostgate* +overworld*
## Paving in the Medieval Age's stone (PIX-307). The audit found
## Pixelheim's street and square flat yellow dirt from the Ashes to the City
## (its "lamplit avenues" dirt with a tiny fountain), Greyhold's courtyard
## flat grey with dithered paths on it, and the Frostgate's road a blur. Now
## the town's streets show its age: trodden dirt in the Ashes and the Hamlet
## (RoadWear's ruts), gravel with edge stones from the Village, Upper Street
## and the gate road cobbled in the Town, and in the City every street
## cobbled, the square and the avenue to the gate in sandstone flags, a
## ring of brick round the fountain. Greyhold's courtyard is flagged, its
## paths in sandstone, the road from its gate to the keep (PIX-337: cobbles
## on its grey flags didn't show, by night least); the Frostgate's
## observatory stands in a flagged yard at the end of a cobbled road.
## Which cells take which look is data (assets/data/streets.json: a map's
## areas, each a rectangle of the grounds it paves and its look by the
## town's age, later areas over earlier ones); the look's pieces are the
## pack's: its paving's 47 edge pieces by which neighbours are paved too
## (a 12x4 block in the sheet), and the fill for a cell paved all round.
## Paid art: without the pack nothing is drawn paved and the streets keep a
## road's wear (RoadWear). Pure: MapView lays the tiles this hands it.

const DATA := "res://assets/data/streets.json"
const COLUMNS := PunyTown.COLUMNS
## Each look: the top-left of its 12x4 block of edge pieces on the sheet
## (column, row), and its fill, [column, row] each, picked by cell.
const LOOKS := {
	# The yellow set's flat paving: gravel packed in the dirt's own colours,
	# its edge stones darker.
	"gravel": {"edges": Vector2i(34, 64), "fill": [[30, 56], [31, 56], [32, 56], [33, 56], [30, 57], [31, 57], [32, 57], [33, 57], [30, 58], [31, 58], [32, 58], [33, 58], [30, 59], [31, 59], [32, 59], [33, 59]]},
	# The grey set's cobbles.
	"cobbles": {"edges": Vector2i(34, 48), "fill": [[30, 40], [31, 40], [32, 40], [33, 40], [30, 41], [31, 41], [32, 41], [33, 41], [30, 42], [31, 42], [32, 42], [33, 42], [30, 43], [31, 43], [32, 43], [33, 43]]},
	# Its great flagstones, edged with its cobbles: a castle's yard.
	"flags": {"edges": Vector2i(34, 48), "fill": [[24, 40], [25, 40], [26, 40]]},
	# The sand set's warm flagstones, edged with the grey cobbles: the City's
	# square and its avenue.
	"sandstone": {"edges": Vector2i(34, 48), "fill": [[24, 32], [25, 32], [26, 32]]},
	# The terracotta set's bricks in a herringbone, edged the same: the ring
	# round the fountain.
	"bricks": {"edges": Vector2i(34, 48), "fill": [[27, 106], [28, 106], [29, 106]]},
}
## The looks that set a row of edge stones where they end (RoadWear.kerbs):
## gravel has no edge of its own.
const KERBED := ["gravel"]
## The pieces of a 12x4 edge block (rows of columns) by which of a cell's
## eight neighbours are paved (N=1, NE=2, E=4, SE=8, S=16, SW=32, W=64,
## NW=128; a corner counts only with both its sides); -1 marks the block's
## two empty places. Read off the pack's snow, whose edges are plain.
const BLOCK := [
	[16, 20, 84, 80, 213, 92, 116, 87, 28, 125, 124, 112],
	[17, 21, 85, 81, 29, 127, 253, 113, 31, 119, -1, 245],
	[1, 5, 69, 65, 23, 223, 247, 209, 95, -1, 221, 241],
	[0, 4, 68, 64, 117, 71, 197, 93, 7, 199, 215, 193],
]
const FULL := 255
const NEIGHBOURS := {
	1: Vector2i(0, -1), 2: Vector2i(1, -1), 4: Vector2i(1, 0), 8: Vector2i(1, 1),
	16: Vector2i(0, 1), 32: Vector2i(-1, 1), 64: Vector2i(-1, 0), 128: Vector2i(-1, -1),
}
## A corner and the two sides it needs.
const CORNERS := {2: [1, 4], 8: [4, 16], 32: [16, 64], 128: [64, 1]}

static var _doc: Dictionary
static var _pieces := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string(DATA))
	return _doc


## The areas a map paves (streets.json), in order.
static func areas(map_id: String) -> Array:
	return _data().get(map_id, [])


## The look each paved cell of `map_id` takes at the town's age `tier`:
## cell -> look. Each area paves the cells of its grounds inside its
## rectangle (the whole map without one) with its look at that age (`from`:
## the age it's laid from, the newest one reached), over what an area before
## it laid; an area the town hasn't reached the age of yet lays nothing.
static func plan(map_id: String, grid: Dictionary, tier: int) -> Dictionary:
	var out := {}
	for area: Dictionary in areas(map_id):
		var look := look_at(area, tier)
		if look == "":
			continue
		var grounds: Array = area["ground"]
		var rect := _rect(area)
		var cells: Array = grid.keys()
		if rect.size != Vector2i.ZERO:
			cells = []
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					cells.append(Vector2i(x, y))
		for cell: Vector2i in cells:
			if grid.get(cell, "") in grounds:
				out[cell] = look
	return out


## An area's look at the town's age `tier`: its look from the newest age it
## lists that the town has reached ("" for none yet).
static func look_at(area: Dictionary, tier: int) -> String:
	var look := ""
	var reached := -1
	var from: Dictionary = area["from"]
	for age: String in from:
		if int(age) <= tier and int(age) > reached:
			reached = int(age)
			look = from[age]
	return look


## The street cells of `grid` (its roads, and whatever `paved` lays) with
## water at a side (PunyTerrain.WATERS): none on a settlement's map
## (PIX-390). Tom found Pixelheim's south street running straight into its
## river, the kerb on the water; a grassy bank lies between them now, with
## Shade's shore and reeds at its foot (Scatter's `bank`).
static func on_water(grid: Dictionary, paved: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Vector2i in grid:
		if grid[cell] != "path" and not paved.has(cell):
			continue
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if grid.get(cell + step, "") in PunyTerrain.WATERS:
				out.append(cell)
				break
	return out


static func _rect(area: Dictionary) -> Rect2i:
	if not area.has("rect"):
		return Rect2i()
	var r: Array = area["rect"]
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


## The pack's tile for each paved cell: its look's edge piece by which
## neighbours are paved (any look: two meet in a straight join), or one of
## its fills where all eight are.
static func tiles(paved: Dictionary) -> Dictionary:
	var out := {}
	for cell: Vector2i in paved:
		out[cell] = tile(paved, cell)
	return out


static func tile(paved: Dictionary, cell: Vector2i) -> int:
	var look: Dictionary = LOOKS[paved[cell]]
	var bits := mask(paved, cell)
	if bits == FULL:
		var fill: Array = look["fill"][absi(hash(cell)) % look["fill"].size()]
		return int(fill[1]) * COLUMNS + int(fill[0])
	var at: Vector2i = look["edges"] + _place(bits)
	return at.y * COLUMNS + at.x


## Which of `cell`'s eight neighbours are paved, a corner only with both its
## sides (the 47 cases the edge block draws).
static func mask(paved: Dictionary, cell: Vector2i) -> int:
	var bits := 0
	for bit: int in NEIGHBOURS:
		if paved.has(cell + NEIGHBOURS[bit]):
			bits |= bit
	for corner: int in CORNERS:
		if not (bits & CORNERS[corner][0] and bits & CORNERS[corner][1]):
			bits &= ~corner
	return bits


## Where the piece for `bits` sits in an edge block.
static func _place(bits: int) -> Vector2i:
	if _pieces.is_empty():
		for row in BLOCK.size():
			for column in BLOCK[row].size():
				if BLOCK[row][column] >= 0:
					_pieces[BLOCK[row][column]] = Vector2i(column, row)
	return _pieces[bits]


## Every tile a look may draw, for PunyTown's tileset to make up front.
static func pieces() -> Array[int]:
	var out: Array[int] = []
	for look: Dictionary in LOOKS.values():
		for row in BLOCK.size():
			for column in BLOCK[row].size():
				if BLOCK[row][column] >= 0:
					var at: Vector2i = look["edges"] + Vector2i(column, row)
					out.append(at.y * COLUMNS + at.x)
		for fill: Array in look["fill"]:
			out.append(int(fill[1]) * COLUMNS + int(fill[0]))
	return out
