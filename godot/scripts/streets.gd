class_name Streets
## areas: town travel +town-age* +greyhold* +frostgate* +overworld*
## Paving in the Medieval Age's stone (PIX-307). The audit found
## Pixelheim's street and square flat yellow dirt from the Ashes to the City
## (its "lamplit avenues" dirt with a tiny fountain), Greyhold's courtyard
## flat grey with dithered paths on it, and the Frostgate's road a blur. Now
## the town's streets show its age: trodden dirt in the Ashes and the Hamlet
## (RoadWear's ruts), gravel with edge stones from the Village, Upper Street
## and the gate road cobbled in the Town, and in the City every street
## cobbled, the square and the avenue to the gate in sandstone flags.
## The square is laid by a mason (PIX-522: it was the flattest thing on
## screen, the Town's gravel bare sand over 17x9 cells, the City's three
## stones rectangles with hard seams and a brick mat under the fountain): a
## border course of setts round its outer ring from the Town, mossy flags
## inside it with grass in their joints off the ways its folk walk
## (RoadWear), and in the City sandstone with a rosette of basket weave
## round the fountain and a line of it from the hall's door and in from the
## west street. Greyhold's courtyard is flagged, its
## paths in sandstone, the road from its gate to the keep (PIX-337: cobbles
## on its grey flags didn't show, by night least); the Frostgate's
## observatory stands in a flagged yard at the end of a cobbled road.
## Which cells take which look is data (assets/data/streets.json: a map's
## areas, each a rectangle of the grounds it paves and its look by the
## town's age, later areas over earlier ones, and over an area's own look
## its `border`'s on its rectangle's outer ring and its `inlay`'s on its
## `rects`, each by age too); the look's pieces are the pack's: its paving's
## 47 edge pieces by which neighbours are paved too (a 12x4 block in the
## sheet), and the fill for a cell paved all round. Two looks meet in a
## straight join, but a `soft` look's stones end in their own soft edge
## wherever they meet another stone, never a ruler line.
## Paid art: without the pack nothing is drawn paved and the streets keep a
## road's wear (RoadWear). Pure: MapView lays the tiles this hands it.

const DATA := "res://assets/data/streets.json"
const COLUMNS := PunyTown.COLUMNS
## The grey set's cobbles.
const COBBLES := [[30, 40], [31, 40], [32, 40], [33, 40], [30, 41], [31, 41], [32, 41], [33, 41], [30, 42], [31, 42], [32, 42], [33, 42], [30, 43], [31, 43], [32, 43], [33, 43]]
## Each look: the top-left of its 12x4 block of edge pieces on the sheet
## (column, row), and its fill, [column, row] each, picked by cell; `soft`:
## its stones join only stones of their own fill (Streets.mask), so they
## end in their soft edge (each set's flat block, rounded and notched)
## against any other.
const LOOKS := {
	# The yellow set's flat paving: gravel packed in the dirt's own colours,
	# its edge stones darker.
	"gravel": {"edges": Vector2i(34, 64), "fill": [[30, 56], [31, 56], [32, 56], [33, 56], [30, 57], [31, 57], [32, 57], [33, 57], [30, 58], [31, 58], [32, 58], [33, 58], [30, 59], [31, 59], [32, 59], [33, 59]]},
	"cobbles": {"edges": Vector2i(34, 48), "fill": COBBLES},
	# Its great flagstones, edged with its cobbles: a castle's yard.
	"flags": {"edges": Vector2i(34, 48), "fill": [[24, 40], [25, 40], [26, 40]]},
	# The sand set's warm flagstones, edged with the grey cobbles: the City's
	# square and its avenue.
	"sandstone": {"edges": Vector2i(34, 48), "fill": [[24, 32], [25, 32], [26, 32]]},
	# The green-grey set's great flagstones, edged with its own stones: the
	# Town's square, grass in their joints (RoadWear's moss, MOSSY).
	"mossy": {"edges": Vector2i(34, 80), "fill": [[24, 72], [25, 72], [26, 72]]},
	# A square's border course: the streets' cobbles, soft against the
	# square's flags and the gravel, one with a cobbled street.
	"setts": {"edges": Vector2i(34, 48), "fill": COBBLES, "soft": true},
	# The terracotta set's basket weave in its own soft stones: the City's
	# rosette round the fountain, and its lines from the hall's door and the
	# west street (a line one cell wide is all edge).
	"basket": {"edges": Vector2i(34, 112), "fill": [[27, 109], [28, 109], [29, 109]], "soft": true},
}
## The looks that set a row of edge stones where they end (RoadWear.kerbs):
## gravel has no edge of its own.
const KERBED := ["gravel"]
## The looks with grass in their flags' joints off the ways folk walk
## (RoadWear.MOSS, Streets.trodden, PIX-522).
const MOSSY := ["mossy"]
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
## Over its own look, the stones a mason sets in it once the town reaches
## their age (PIX-522): its `border`'s on its rectangle's outer ring, its
## `inlay`'s on the inlay's `rects`, on cells the area paves.
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
		var bordered: Dictionary = area.get("border", {})
		var inlaid_by: Dictionary = area.get("inlay", {})
		var border := look_at(bordered, tier)
		var inlay := look_at(inlaid_by, tier)
		var inlaid: Array[Rect2i] = []
		for r: Array in inlaid_by.get("rects", []):
			inlaid.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
		for cell: Vector2i in cells:
			if grid.get(cell, "") not in grounds:
				continue
			out[cell] = look
			if border != "" and rect.has_area() and not rect.grow(-1).has_point(cell):
				out[cell] = border
			if inlay != "" and inlaid.any(func(r: Rect2i) -> bool: return r.has_point(cell)):
				out[cell] = inlay
	return out


## The paved road cells of `map_id` its traffic has worn by the town's age
## `tier` (PIX-382 step 4: the City's streets lay as new as the Village's):
## each area's that has reached its `worn` age (Upper Street from the
## Village, the gate road and the ways down to the square from the Town,
## the square in the City), of what `paved` paves now: cell -> whether it
## lies on a square. RoadWear draws a street's ruts over the stone, and a
## square's scuffs: a square wears only where its folk walk (its `trodden`
## rects: from the ways in to the fountain, round it, along the stalls), and
## never in ruts (the review found its flags sprinkled all over, and stubs of
## rut wherever a crate narrowed it to a street's width).
static func worn(map_id: String, grid: Dictionary, paved: Dictionary, tier: int) -> Dictionary:
	var out := {}
	for area: Dictionary in areas(map_id):
		if int(area.get("worn", Town.MAX_TIER + 1)) > tier:
			continue
		var square := area.has("trodden")
		var rects: Array[Rect2i] = [_rect(area)]
		if square:
			rects.assign(area["trodden"].map(func(r: Array) -> Rect2i: return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))))
		for cell: Vector2i in paved:
			if grid.get(cell, "") != RoadWear.ROAD:
				continue
			for rect: Rect2i in rects:
				if rect.size == Vector2i.ZERO or rect.has_point(cell):
					out[cell] = square
					break
	return out


## The cells a map's squares' folk walk (their `trodden` rects), worn yet or
## not: the Town's mossy flags grow no grass in their joints there, so its
## ways in to the fountain show before the City wears them (PIX-522).
static func trodden(map_id: String) -> Dictionary:
	var out := {}
	for area: Dictionary in areas(map_id):
		for r: Array in area.get("trodden", []):
			for y in range(int(r[1]), int(r[1]) + int(r[3])):
				for x in range(int(r[0]), int(r[0]) + int(r[2])):
					out[Vector2i(x, y)] = true
	return out


## An area's look at the town's age `tier`: its look from the newest age it
## lists that the town has reached ("" for none yet).
static func look_at(area: Dictionary, tier: int) -> String:
	var look := ""
	var reached := -1
	var from: Dictionary = area.get("from", {})
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
## neighbours are paved (any look: two meet in a straight join; a soft
## look's, by its own stone: Streets.mask), or one of its fills where all
## eight are.
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
## sides (the 47 cases the edge block draws). A soft look counts only the
## neighbours laid in its own stone (its fill: the setts and a cobbled
## street are one), so it rounds off against any other (PIX-522).
static func mask(paved: Dictionary, cell: Vector2i) -> int:
	var look: Dictionary = LOOKS[paved[cell]]
	var soft: bool = look.get("soft", false)
	var bits := 0
	for bit: int in NEIGHBOURS:
		var next: String = paved.get(cell + NEIGHBOURS[bit], "")
		if next != "" and (not soft or LOOKS[next]["fill"] == look["fill"]):
			bits |= bit
	for corner: int in CORNERS:
		if not (bits & CORNERS[corner][0] and bits & CORNERS[corner][1]):
			bits &= ~corner
	return bits


## Where the piece for `bits` sits in an edge block.
static func _place(bits: int) -> Vector2i:
	if _pieces.is_empty():
		for row in BLOCK.size():
			for column: int in BLOCK[row].size():
				if BLOCK[row][column] >= 0:
					_pieces[BLOCK[row][column]] = Vector2i(column, row)
	return _pieces[bits]


## Every tile a look may draw, for PunyTown's tileset to make up front.
static func pieces() -> Array[int]:
	var out: Array[int] = []
	for look: Dictionary in LOOKS.values():
		for row in BLOCK.size():
			for column: int in BLOCK[row].size():
				if BLOCK[row][column] >= 0:
					var at: Vector2i = look["edges"] + Vector2i(column, row)
					out.append(at.y * COLUMNS + at.x)
		for fill: Array in look["fill"]:
			out.append(int(fill[1]) * COLUMNS + int(fill[0]))
	return out
