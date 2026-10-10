class_name Skyline
## The village seen from outside (PIX-248). The overworld holds Pixelheim as
## one block of roof inside a rampart, and it used to be drawn as a keep
## among Shade's one-tile house icons, on every other cell, in teal and red
## roofs the village doesn't have: nothing of the place the hero walks in.
## Now the block is the village itself, small: the town map as it stands
## (its ruins, its rebuilt houses, what each age added) read into the block
## cell by cell, and drawn with the town's own pieces - every house a hip-
## roofed wing in its own roof's colour (PunyTown), its windows lit at
## night and smoke from its roof; the river, its bridge and the dock, the
## streets, the fields and the woods on Shade's ground; ash and charred logs
## where a house still lies burnt; and one ring of the town's own rampart
## round it, its gatehouse where the road comes in as the town draws it
## (Rampart: the same stone, towers, raised portcullis, and as scorched while
## the ruins stand), whole-size, so the gate seen from the road is the gate
## the hero walks out of.
##
## The town is some three times the block's size each way: its columns
## shrink evenly, its rows by TOWN_ROWS. Everything stays whole 16px tiles,
## nothing is scaled. Pure: MapView draws what this plans; the block's cells
## stay what they were, so nothing is walked on.

## Each of the block's rows inside its ring, as the first of the town's rows
## (inside its walls) it stands for: two for the top of the inn's tall roof
## under the wall, three for the rest of it and the houses along the top
## street, the street, two for each band of houses below, the cottages'
## two, then the south river with the woods behind it. An even shrink lost
## the streets between the bands. Used when the block has as many rows as
## this; otherwise the rows shrink evenly too.
const TOWN_ROWS := [0, 2, 5, 8, 11, 14, 17, 20, 23, 26, 28, 32]
## How far in from the town map's edge its wall may stand: past it, the
## fields outside (PIX-248).
const FIELDS_OUTSIDE := 4
## What the town's tiles read as from afar; the rest is grass. The shrine's
## wooded hill reads as its woods: Shade's cliffs, three times too big for
## it, stood about like hedges.
const READS := {
	"water": "water", "bridge": "water", "dock": "water",
	"path": "path", "lamp": "path", "well": "path", "counter": "path",
	"ash": "ash", "forest": "forest", "crops": "crops", "mountain": "forest",
}
## Planks over the water: a bridge, the dock.
const SPANS := ["bridge", "dock"]
## The town's well, and the square's fountain once it's built: Shade's
## small overworld well.
const WELL := 815
## A burnt house's remains, seen small: his fallen logs and stumps.
const DEBRIS := [703, 784, 811, 838]
## A chimney stack on a roof tall enough to carry one, as the town's gables
## wear it (PunyTown.CHIMNEY's foot), and where each roof's smoke leaves it,
## from the cell's top-left.
const CHIMNEY := 2093
const SMOKE_AT := Vector2(8, 5)
## Without the paid Medieval Age pack, a house is Shade's one-tile house in
## the colour nearest its roof (his overworld sheet is CC0).
const ICONS := {"roof": 932, "roof_awning": 932, "roof_thatch": 734, "roof_moss": 923, "roof_slate": 923}


## The village in the overworld's block (empty without one):
## - block: the block, rampart included;
## - ground: cell -> the tile its ground is drawn as (streets, the river,
##   ash where a house burnt, the fields and woods under their growth);
## - rampart: the ring round it and its gatehouse, as Rampart.plan draws
##   them (scorched while `ruins` stand);
## - objects: cell -> Shade's overworld tile (wells, burnt logs);
## - growth: cell -> his trees and wheat;
## - pieces, decor: cell -> Medieval Age tile (the houses, their chimneys);
## - icons: cell -> one-tile house, drawn instead without the paid pack;
## - roofs: cell -> the roof kind of the house standing on it (the map
##   screen colours each house by it, PIX-266);
## - smoke: where each roof's smoke rises, in map pixels;
## - lamps: the cells the town's lamps light at night;
## - ruins: the burnt houses, in the block's cells, smouldering.
## `town` is the town map as it has grown, `ruins` its burnt houses (Town.ruins'
## rects).
static func plan(grid: Dictionary, town: MapData, ruins: Array = []) -> Dictionary:
	var out := {
		"block": Rect2i(), "ground": {}, "rampart": {}, "objects": {}, "growth": {}, "pieces": {}, "decor": {},
		"icons": {}, "roofs": {}, "smoke": [], "lamps": [], "ruins": [],
	}
	var outer := block(grid)
	var room := outer.grow(-1)
	var from := inside(town)
	if room.size.x < 2 or room.size.y < 2 or not from.has_area():
		return out
	out["block"] = outer
	var cols := _spans(room.size.x, from.position.x, from.size.x, [])
	var rows := _spans(room.size.y, from.position.y, from.size.y, TOWN_ROWS)
	out["rampart"] = _rampart(grid, outer, not ruins.is_empty())
	var ground: Dictionary = out["ground"]
	for j in rows.size():
		for i in cols.size():
			ground[room.position + Vector2i(i, j)] = _reads(town.grid, cols[i], rows[j])
	_lay_spans(town.grid, room, cols, rows, ground)
	var houses := _houses(town, room, cols, rows, out)
	for i in cols.size():
		for j in rows.size():
			var cell := room.position + Vector2i(i, j)
			if houses.has(cell):
				continue
			var tiles := _tiles_in(town.grid, cols[i], rows[j])
			if "lamp" in tiles:
				out["lamps"].append(cell)
			if "well" in tiles and ground[cell] == "path":
				out["objects"][cell] = WELL
			elif ground[cell] in ["forest", "crops"]:
				var growth := Scatter.choice(ground, cell)
				if growth >= 0:
					out["growth"][cell] = growth
	# What still lies burnt: ash, charred logs and stumps where it stood.
	for ruin: Rect2i in ruins:
		var shrunk := _shrink(ruin, room, cols, rows)
		out["ruins"].append(shrunk)
		for y in range(shrunk.position.y, shrunk.end.y):
			for x in range(shrunk.position.x, shrunk.end.x):
				var cell := Vector2i(x, y)
				if houses.has(cell) or ground[cell] == "water":
					continue
				ground[cell] = "ash"
				out["growth"].erase(cell)
				var h := absi(hash(cell))
				if h % 5 < 2:
					out["objects"][cell] = DEBRIS[(h >> 4) % DEBRIS.size()]
	return out


## The block the town stands in on `grid`: its roofs and the rampart round
## them (Rect2i() when there are none).
static func block(grid: Dictionary) -> Rect2i:
	var low := Vector2i(1 << 20, 1 << 20)
	var high := Vector2i(-1, -1)
	for cell: Vector2i in grid:
		if String(grid[cell]).begins_with("roof"):
			low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
			high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	if high.x < 0:
		return Rect2i()
	var rect := Rect2i(low, high - low + Vector2i.ONE)
	for side: int in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		while _edge(rect.grow_side(side, 1), side).all(func(cell: Vector2i) -> bool: return grid.get(cell, "") in PunyTerrain.RAMPART):
			rect = rect.grow_side(side, 1)
	return rect


## The town inside its own walls: its map less the wall round it and the
## fields beyond it (up to FIELDS_OUTSIDE lines in from each edge).
static func inside(town: MapData) -> Rect2i:
	var rect := Rect2i(Vector2i.ZERO, town.size)
	for side: int in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		var probe := rect
		var steps := 0
		while probe.has_area() and steps < FIELDS_OUTSIDE and not _mostly_wall(town.grid, _edge(probe, side)):
			probe = probe.grow_side(side, -1)
			steps += 1
		if not probe.has_area() or not _mostly_wall(town.grid, _edge(probe, side)):
			continue
		while probe.has_area() and _mostly_wall(town.grid, _edge(probe, side)):
			probe = probe.grow_side(side, -1)
		rect = probe
	return rect


## The cells along one side of `rect`, inside it.
static func _edge(rect: Rect2i, side: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if side == SIDE_TOP or side == SIDE_BOTTOM:
		var y := rect.position.y if side == SIDE_TOP else rect.end.y - 1
		for x in range(rect.position.x, rect.end.x):
			out.append(Vector2i(x, y))
	else:
		var x := rect.position.x if side == SIDE_LEFT else rect.end.x - 1
		for y in range(rect.position.y, rect.end.y):
			out.append(Vector2i(x, y))
	return out


static func _mostly_wall(grid: Dictionary, line: Array[Vector2i]) -> bool:
	return line.filter(func(cell: Vector2i) -> bool: return grid.get(cell, "") == "wall").size() * 2 > line.size()


## The town's lines each of `count` cells stands for, as [first, end): from
## `start`, `length` long, by `tuned` (each one's first, from `start`) when
## it has `count` of them and fits, else evenly.
static func _spans(count: int, start: int, length: int, tuned: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var use := tuned.size() == count and length > int(tuned[-1])
	for i in count:
		if use:
			out.append(Vector2i(start + int(tuned[i]), start + (length if i == count - 1 else int(tuned[i + 1]))))
		else:
			out.append(Vector2i(start + i * length / count, start + (i + 1) * length / count))
	return out


## One ring of the town's rampart round the block, where the overworld's
## band is two thick (at a third of the town's size, its two cells of wall
## are less than one), drawn as the town draws its own (Rampart.plan): the
## stone, and the gatehouse where the doors are; `ashen` while the ruins
## stand.
static func _rampart(grid: Dictionary, outer: Rect2i, ashen: bool) -> Dictionary:
	var ring := {}
	for side: int in [SIDE_TOP, SIDE_BOTTOM, SIDE_LEFT, SIDE_RIGHT]:
		for cell in _edge(outer, side):
			ring[cell] = grid.get(cell, "wall") if grid.get(cell, "") in PunyTerrain.RAMPART else "wall"
	return Rampart.plan(ring, ashen)


## The town's tiles over `cols` x `rows`, each once.
static func _tiles_in(grid: Dictionary, cols: Vector2i, rows: Vector2i) -> Array:
	var out := []
	for y in range(rows.x, rows.y):
		for x in range(cols.x, cols.y):
			var tile: String = grid.get(Vector2i(x, y), "")
			if tile not in out:
				out.append(tile)
	return out


## What a stretch of the town reads as from afar: water when a third of it
## is (the river stays whole), a street when a third is (streets are narrow),
## else what most of it is.
static func _reads(grid: Dictionary, cols: Vector2i, rows: Vector2i) -> String:
	var counts := {}
	var total := 0
	for y in range(rows.x, rows.y):
		for x in range(cols.x, cols.y):
			var kind: String = READS.get(grid.get(Vector2i(x, y), ""), "grass")
			counts[kind] = int(counts.get(kind, 0)) + 1
			total += 1
	for kind: String in ["water", "path"]:
		if int(counts.get(kind, 0)) * 3 >= total:
			return kind
	var best := "grass"
	for kind: String in counts:
		if int(counts[kind]) > int(counts.get(best, 0)):
			best = kind
	return best


## The bridge and the dock as planks over the shrunk water: on the cells that
## hold the most of the town's, one row of them where a span straddles two.
static func _lay_spans(grid: Dictionary, room: Rect2i, cols: Array[Vector2i], rows: Array[Vector2i], ground: Dictionary) -> void:
	for kind: String in SPANS:
		var counts := {}
		for j in rows.size():
			for i in cols.size():
				var count := 0
				for y in range(rows[j].x, rows[j].y):
					for x in range(cols[i].x, cols[i].y):
						if grid.get(Vector2i(x, y), "") == kind:
							count += 1
				counts[Vector2i(i, j)] = count
		for at: Vector2i in counts:
			var here: int = counts[at]
			var cell := room.position + at
			if here > 0 and ground[cell] == "water" and here > int(counts.get(at + Vector2i.UP, 0)) and here >= int(counts.get(at + Vector2i.DOWN, 0)):
				ground[cell] = kind


## The town's houses, shrunk into the block: each on the cells it covers at
## least half of, never less than two by two, the biggest first and each
## after it fitted round them. Returns the cells they stand on.
static func _houses(town: MapData, room: Rect2i, cols: Array[Vector2i], rows: Array[Vector2i], out: Dictionary) -> Dictionary:
	var taken := {}
	var houses := PunyTown.houses(town.grid)
	houses.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a["rect"] as Rect2i).get_area() > (b["rect"] as Rect2i).get_area())
	for house: Dictionary in houses:
		var want := _at_least_two(_shrink(house["rect"], room, cols, rows), room)
		var door: Vector2i = house["door"]
		var door_x := want.position.x + want.size.x / 2
		if door.x >= 0:
			door_x = clampi(room.position.x + _index_of(door.x, cols), want.position.x, want.end.x - 1)
		var rect := _fit(want, door_x, taken)
		if not rect.has_area():
			continue
		var kind: String = house["kind"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				taken[Vector2i(x, y)] = true
				out["ground"][Vector2i(x, y)] = "grass"
				out["roofs"][Vector2i(x, y)] = kind
		var pieces := PunyTown.wing_house(rect, door_x, kind)
		# A window in every bit of wall but the door (and a wide house's
		# corner posts): from afar the houses are small, and each shows its
		# light at night.
		for x in range(rect.position.x, rect.end.x):
			var wall := Vector2i(x, rect.end.y - 1)
			if x != door_x and (rect.size.x <= 3 or pieces.get(wall, -1) == PunyTown.WALL):
				pieces[wall] = PunyTown.WINDOW
		out["pieces"].merge(pieces, true)
		# Smoke from each roof's top, a stack under it where the roof is tall
		# enough to carry one (on a low roof it hid the roof).
		var chimney := Vector2i(rect.end.x - 2 if rect.size.x >= 3 else rect.end.x - 1, rect.position.y)
		if rect.size.y >= 3:
			out["decor"][chimney] = CHIMNEY
		out["smoke"].append(Vector2(chimney * PunyTerrain.TILE) + SMOKE_AT)
		out["icons"][Vector2i(door_x, rect.end.y - 1)] = ICONS.get(kind, ICONS["roof"])
	return taken


## Which of `spans` holds town line `at` (the last one past them all).
static func _index_of(at: int, spans: Array[Vector2i]) -> int:
	for i in spans.size():
		if at < spans[i].y:
			return i
	return spans.size() - 1


## A town rectangle in the block's cells: the columns and rows it covers at
## least half of (the one its middle falls in, when it covers none so much).
static func _shrink(rect: Rect2i, room: Rect2i, cols: Array[Vector2i], rows: Array[Vector2i]) -> Rect2i:
	var across := _covered(rect.position.x, rect.end.x, cols)
	var down := _covered(rect.position.y, rect.end.y, rows)
	return Rect2i(room.position + Vector2i(across.x, down.x), Vector2i(across.y - across.x, down.y - down.x))


## The spans [first, end) that town lines `from`..`to` cover at least half of.
static func _covered(from: int, to: int, spans: Array[Vector2i]) -> Vector2i:
	var first := -1
	var last := -1
	for i in spans.size():
		var overlap := mini(to, spans[i].y) - maxi(from, spans[i].x)
		if overlap * 2 >= spans[i].y - spans[i].x:
			first = i if first < 0 else first
			last = i
	if first < 0:
		var middle := _index_of((from + to) / 2, spans)
		return Vector2i(middle, middle + 1)
	return Vector2i(first, last + 1)


## Two cells each way at least, inside the block: wider to the right, taller
## upwards (a roof over the wall), back inside where that ran out.
static func _at_least_two(rect: Rect2i, room: Rect2i) -> Rect2i:
	if rect.size.x < 2:
		rect = rect.grow_side(SIDE_RIGHT, 2 - rect.size.x)
	if rect.size.y < 2:
		rect = rect.grow_side(SIDE_TOP, 2 - rect.size.y)
	rect.position = rect.position.clamp(room.position, room.end - rect.size)
	return rect


## The biggest part of `want` (two by two at least, its door column kept)
## clear of the cells `taken`; Rect2i() when none is.
static func _fit(want: Rect2i, door_x: int, taken: Dictionary) -> Rect2i:
	var best := Rect2i()
	for top in range(want.position.y, want.end.y - 1):
		for left in range(want.position.x, door_x + 1):
			for right in range(want.end.x, door_x, -1):
				var rect := Rect2i(left, top, right - left, want.end.y - top)
				if rect.size.x < 2 or rect.get_area() <= best.get_area() or _overlaps(rect, taken):
					continue
				best = rect
	return best


static func _overlaps(rect: Rect2i, taken: Dictionary) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if taken.has(Vector2i(x, y)):
				return true
	return false
