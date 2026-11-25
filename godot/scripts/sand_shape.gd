class_name SandShape
extends RefCounted
## areas: travel field +saltmere*
## Where Saltmere's sand meets its grass and its road (PIX-551), as a mask the
## ground's shader reads (shaders/sand_shape.gdshaderinc). Shade's dual grid
## draws the sand as its cells' block, so the dunes met the grass on a
## staircase of whole cells beside a sea whose own shoreline is ragged; and
## he pairs sand with grass only, so a road through the sand wore a ruled
## green strip along its side. Now the shader smooths the sand's cells into
## one field (RoadShape's spline), bends its edge off the grid, and draws his
## sand and grass again to it in his own colours and edge dither; and the
## road's own dirt edge, where it runs through the sand, wanders off the grid
## too. Only the drawing changes: the grid, and so where the hero walks,
## doesn't. Pure.

## The maps drawn so: the fix is Saltmere's (PIX-551 goes to no other map).
const MAPS := ["saltmere"]
## How many cells past the map's edges the mask reaches, as the road's.
const RING := RoadShape.RING
## The mask's green, where the ground is drawn again: a sand or grass cell
## beside the other (or sand beside a road), nothing round it but sand,
## grass, sea and road. NEAR a road: a sand cell there has the road's dirt
## edge drawn again too, a grass cell keeps it as Shade drew it; PLAIN away
## from one, where his edge's dither is drawn again too. Beside rock or a
## river the cell keeps Shade's own (a cliff's grassy top is no dune).
## ROADSIDE: a road's own cell with sand beside it, where only its green is
## drawn again (the grass a turn rounds its outside with, PIX-404, cut off
## at the cell's line when it was never drawn: PIX-551's review); rock
## beside it but corner to corner leaves it so (the cave road's turn).
const ROADSIDE := 0.25
const NEAR := 0.5
const PLAIN := 1.0
## The grounds the sand's field counts as sand: his sea meets his sand
## already (PIX-532's waterline stays), so the edge never bends toward it.
const SANDY := ["sand", "seawater-light", "seawater-medium", "seawater-deep"]
## The mask's alpha: the road's dirt edge bends out over the sand and in;
## only in where the sea is a cell off (out, it ran into Shade's ring of wet
## sand at the waterline: PIX-551's review).
const WORN := 1.0
const WORN_IN := 0.5
## The grounds the mask tells apart, a byte a cell (KINDS); anything else is
## rock to it: a cliff, a river, a wall.
enum { ROCK, GRASS, DIRT, SAND, SEA }
const KINDS := {"grass": GRASS, "dirt": DIRT, "sand": SAND, "seawater-light": SEA, "seawater-medium": SEA, "seawater-deep": SEA}


## The mask, once drawn: a cell a texel from cell (-RING, -RING).
var image: Image
var _look: Dictionary
var _beyond: Callable
var _size: Vector2i
## Each cell's ground, read once (the first pass), and whether rock lies
## within two cells of it along its row: a row `_across` cells from
## (-RING - 2, -RING - 2), the mask and two more all round, as far as its
## rock reads (PIX-551's review: each cell read again for every neighbour,
## the whole mask took 37 ms of one frame).
var _across: int
var _kinds := PackedByteArray()
var _rock_by := PackedByteArray()


## The mask of `look` (a map's ground as drawn, `size` cells), where
## `beyond(cell)` says what lies past its edges, at once: red the cell's
## weight in the sand's field, green where the ground is drawn again
## (ROADSIDE, NEAR, PLAIN), blue how far the edge may wander there (1, or 0 within two cells
## of rock or a river, where a cell keeps Shade's own and the two must meet),
## alpha how far the road's dirt edge may (WORN on sand beside a road with
## no grass beside it, so it eases back to Shade's straight edge where the
## road runs on between grass, and as the blue by rock; WORN_IN with the sea
## beside it too).
static func image_of(look: Dictionary, beyond: Callable, size: Vector2i) -> Image:
	var shaping := SandShape.new(look, beyond, size)
	shaping.read_rows(0, shaping.read_count())
	shaping.draw_rows(0, shaping.draw_count())
	return shaping.image


func _init(look: Dictionary, beyond: Callable, size: Vector2i) -> void:
	_look = look
	_beyond = beyond
	_size = size
	_across = size.x + 2 * RING + 4
	_kinds.resize(_across * read_count())
	_rock_by.resize(_kinds.size())
	image = Image.create(size.x + 2 * RING, size.y + 2 * RING, false, Image.FORMAT_RGBA8)


## How many rows the first pass reads, and the second draws (KeptGround
## slices both a few rows a frame, as the road's).
func read_count() -> int:
	return _size.y + 2 * RING + 4


func draw_count() -> int:
	return _size.y + 2 * RING


## The first pass, its rows [from, to) (from 0, two rows above the mask's
## first): each cell's ground.
func read_rows(from: int, to: int) -> void:
	for row in range(from, mini(to, read_count())):
		var first := row * _across
		for col in _across:
			_kinds[first + col] = KINDS.get(PunyTerrain.ground_of(RoadWear.ground_at(_look, _beyond, Vector2i(col - RING - 2, row - RING - 2))), ROCK)
		for col in _across:
			var by := 0
			for x in range(maxi(col - 2, 0), mini(col + 3, _across)):
				by = by | int(_kinds[first + x] == ROCK)
			_rock_by[first + col] = by


## The second pass, once the first is done, its rows [from, to) (from 0, the
## mask's first): each cell's texel.
func draw_rows(from: int, to: int) -> void:
	for row in range(from, mini(to, draw_count())):
		for col in _size.x + 2 * RING:
			var at := (row + 2) * _across + col + 2
			var free := true
			for dy in range(-2, 3):
				free = free and _rock_by[at + dy * _across] == 0
			var kind := _kinds[at]
			image.set_pixel(col, row, Color(1.0 if kind == SAND or kind == SEA else 0.0, _zone(at), 1.0 if free else 0.0, _worn(at) if free else 0.0))


## How far the road's dirt edge may wander at the cell read at `at` (WORN,
## WORN_IN; 0 where it may not): sand with a road beside it and no grass, on
## any of its eight sides.
func _worn(at: int) -> float:
	if _kinds[at] != SAND:
		return 0.0
	var road := false
	var sea := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var beside := _kinds[at + dy * _across + dx]
			if beside == GRASS:
				return 0.0
			road = road or beside == DIRT
			sea = sea or beside == SEA
	return 0.0 if not road else WORN_IN if sea else WORN


## Whether the ground is drawn again at the cell read at `at` (ROADSIDE,
## NEAR, PLAIN; 0 where it isn't): sand with anything but sand and sea
## beside it, or grass with sand beside it, on any of its eight sides; or a
## road with sand beside it and no rock straight beside it.
func _zone(at: int) -> float:
	var kind := _kinds[at]
	if kind == DIRT:
		for step: int in [-_across, -1, 1, _across]:
			if _kinds[at + step] == ROCK:
				return 0.0
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if _kinds[at + dy * _across + dx] == SAND:
					return ROADSIDE
		return 0.0
	if kind != SAND and kind != GRASS:
		return 0.0
	var edge := false
	var road := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var beside := _kinds[at + dy * _across + dx]
			if beside == ROCK:
				return 0.0
			road = road or beside == DIRT
			edge = edge or (beside == SAND if kind == GRASS else beside == GRASS or beside == DIRT)
	if not edge:
		return 0.0
	return NEAR if road else PLAIN
