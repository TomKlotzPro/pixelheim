class_name RoadShape
extends RefCounted
## areas: travel field +deepwood* +blackiron* +mirefen* +saltmere* +frostgate* +overworld* +mountain_road*
## The shape of a country road's ends and turns (PIX-404), as a mask the
## ground's shader reads (shaders/road_shape.gdshaderinc). Shade's dual grid
## draws a road as its cells' block, its dirt a few pixels past their edges
## and its corners barely rounded, so the Deepwood glade's stubs ended in
## square blocks of dirt; and where a road and its ground are both his dirt
## (Blackiron's ash), the edge was the region tint's cell boundary, and the
## roads stepped in sharp rectangles. Now the shader smooths the road's
## cells, each by its weight, into one field: a turn rounds out on its outside
## and fills in on its inside, and a lane's last cells weigh less, so a road
## narrows to a worn tip where it ends in the open. Where the road meets open
## country ground (OPEN) the ground's tone follows that field; near an end or
## a turn on Shade's grass his dirt and grass are drawn again to it. Never
## where it meets stone, a wall, water or rock: Greyhold's courtyard
## (PIX-399), a cliff's foot and a bank keep their own. Only the drawing
## changes: the grid, and so where the hero walks, doesn't. Worked out a few
## rows a slice (KeptGround), or at once (`image`); pure.

## How many cells past the map's edges the mask reaches: the ground drawn
## past them (MapView.EDGE_PAD), and the two more its field reads.
const RING := 6
## The ground a country road meets in the open, its shape drawn there.
const OPEN := ["grass", "forest", "flowers", "crops", "ash", "marsh", "snow", "sand", "earth"]
## The open ground Shade draws as grass (or sand, which settles to grass
## beside his dirt): where a road's dirt meets it is his corner tiles' edge,
## drawn again. The ash and the healed earth are his dirt as the road is:
## there the tone alone draws the road's edge.
const GRASSY := ["grass", "sand"]
## A lane's cells by how far they lie from its end in the open (0: the
## last), by the road's width: a track narrows over its last two cells to a
## worn tip. A one-cell path's end, already round, barely gives.
const TAPER := {1: [0.8, 1.0], 2: [0.45, 0.8], 3: [0.4, 0.75]}
## The mask's channels: red the cell's weight in the road (0 off it), green
## whether it's OPEN ground, blue where the ground is drawn again (ZONE; a
## cell inside a turn that the road may fill, FILLS), alpha where the road
## meets open ground within a cell (the tone follows the field there).
const ZONE := 0.5
const FILLS := 1.0
## The maps whose long straight roads are worn wider here and there
## (PIX-397, the Reach's: seen whole a ruler-drawn grid), as the shader
## reads the field (road_worn): each edge wanders out off its cells by up to
## this many pixels and back, never in, so the ruts (RoadWear, on the cells
## some 7 pixels in from the edge) never meet it; straight by the map's
## edges and round each `still` cell, where the road meets what's drawn
## straight (the bridge's middle, the town's gate). The tone draws it (the
## Ash's, the marsh's), and on Shade's grass his dirt and grass are drawn
## again along every edge of the road, not only round its ends and turns
## (`_wanders`).
const WANDERS := {"overworld": {"wander": 8.0, "still": [Vector2i(48, 29), Vector2i(48, 42)]}}

## The mask, a cell a texel: texel (0, 0) is cell (-RING, -RING).
var image: Image
var _look: Dictionary
var _beyond: Callable
var _size: Vector2i
## The road's cells paved (Streets: the Frostgate's cobbles), whose stone
## keeps its cells' shape, and the ground round it with it.
var _paved: Dictionary
## Whether the map's roads wander (WANDERS): their straight edges on
## Shade's grass are drawn again too, so it shows there.
var _wanders: bool
## What the first pass read: open ground, the grass among it, the road's
## cells and their weights, and the cells beside an unpaved road.
var _open := {}
var _grassy := {}
var _weights := {}
var _near := {}
## The second pass's: the vertex rows looked at, and the cells near a turn
## or a narrowing on Shade's grass.
var _vertex_rows := {}
var _zone := {}


## The mask of `look`'s country roads (a map's ground as drawn, `size`
## cells, the `paved` among them), where `beyond(cell)` says what lies past
## its edges, at once; `wanders` if its roads wander (WANDERS).
static func image_of(look: Dictionary, beyond: Callable, size: Vector2i, paved := {}, wanders := false) -> Image:
	var shaping := RoadShape.new(look, beyond, size, paved, wanders)
	shaping.read_rows(0, shaping.read_count())
	shaping.draw_rows(0, shaping.draw_count())
	return shaping.image


func _init(look: Dictionary, beyond: Callable, size: Vector2i, paved := {}, wanders := false) -> void:
	_look = look
	_beyond = beyond
	_size = size
	_paved = paved
	_wanders = wanders
	image = Image.create(size.x + 2 * RING, size.y + 2 * RING, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))


## How many rows the first pass reads: the mask's, and one more all round
## (its edge's neighbours).
func read_count() -> int:
	return _size.y + 2 * RING + 2


func draw_count() -> int:
	return _size.y + 2 * RING


## The first pass, its rows [from, to) (from 0, the row a cell above the
## mask's first): the ground, and each road cell's weight.
func read_rows(from: int, to: int) -> void:
	for row in range(from, mini(to, read_count())):
		var y := row - RING - 1
		for x in range(-RING - 1, _size.x + RING + 1):
			var cell := Vector2i(x, y)
			var tile := RoadWear.ground_at(_look, _beyond, cell)
			if tile == RoadWear.ROAD and _paved.has(cell):
				_weights[cell] = 1.0
			elif tile == RoadWear.ROAD:
				_weights[cell] = weight(_look, _beyond, cell)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						_near[cell + Vector2i(dx, dy)] = true
			elif tile in OPEN:
				_open[cell] = true
				if PunyTerrain.ground_of(tile) in GRASSY:
					_grassy[cell] = true


## The second pass, once the first is done, its rows [from, to) (from 0,
## the mask's first): each cell's texel.
func draw_rows(from: int, to: int) -> void:
	for row in range(from, mini(to, draw_count())):
		var y := row - RING
		# A cell lies near a turn when one of the sixteen corners round it
		# does: the vertex rows y - 1 to y + 2.
		for vy in range(y - 1, y + 3):
			_turns(vy)
		for x in range(-RING, _size.x + RING):
			var cell := Vector2i(x, y)
			var road := _weights.has(cell)
			var open := _open.has(cell)
			if not open and not road:
				continue
			var drawn := 0.0
			if _zone.has(cell) and (road or _grassy.has(cell)) and not _paved.has(cell):
				drawn = FILLS if _grassy.has(cell) and (_inside_turn(cell) or (_wanders and not _between(cell))) else ZONE
			var edge := open and _near.has(cell)
			if road and not _paved.has(cell):
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						edge = edge or _open.has(cell + Vector2i(dx, dy))
			image.set_pixel(x + RING, y + RING, Color(_weights.get(cell, 0.0), 1.0 if open else 0.0, drawn, 1.0 if edge else 0.0))


## The vertices of row `vy` where the road turns or narrows on Shade's
## grass: the cells round each, and a ring more, are near it.
func _turns(vy: int) -> void:
	if _vertex_rows.has(vy):
		return
	_vertex_rows[vy] = true
	for vx in range(-RING, _size.x + RING + 1):
		var vertex := Vector2i(vx, vy)
		if _shaped(vertex):
			for dy in range(-2, 2):
				for dx in range(-2, 2):
					_zone[vertex + Vector2i(dx, dy)] = true


## Road cell `cell`'s weight: 1, or less over its lane's last cells before
## an end in the open (TAPER). A crossing, a bend or a square weighs whole.
static func weight(look: Dictionary, beyond: Callable, cell: Vector2i) -> float:
	var lane := RoadWear.lane_of(look, beyond, cell)
	if lane.is_empty():
		return 1.0
	var from_end := ends_in(look, beyond, cell, lane[0])
	return TAPER[lane[1]][from_end] if from_end >= 0 else 1.0


## How many cells road cell `cell` lies from its lane's end in OPEN ground,
## either way along `axis` (RoadWear.ACROSS or DOWN): 0 the last, 1 the one
## before; -1 further, or where the lane runs on into anything else (a door,
## a bridge, stone, the map beside). A lane that ends beside another running
## on narrows the road into it; the other runs on whole.
static func ends_in(look: Dictionary, beyond: Callable, cell: Vector2i, axis: int) -> int:
	var along := Vector2i.RIGHT if axis == RoadWear.ACROSS else Vector2i.DOWN
	var nearest := -1
	for way: int in [1, -1]:
		for from_end in 2:
			var at: Vector2i = cell + along * way * from_end
			if RoadWear.ground_at(look, beyond, at) != RoadWear.ROAD:
				break
			if RoadWear.ground_at(look, beyond, at + along * way) in OPEN:
				if nearest < 0 or from_end < nearest:
					nearest = from_end
				break
	return nearest


## Whether the road's outline turns or narrows at `vertex` (the corner its
## cells (x - 1, y - 1) to (x, y) share) on Shade's grass: one or three of
## them road, two across a diagonal, or two along a narrowing edge (along
## any edge where the map's roads wander); and the others grass. Inside a
## road (four of them) it's the edges that turn.
func _shaped(vertex: Vector2i) -> bool:
	var cells := [vertex + Vector2i(-1, -1), vertex + Vector2i(0, -1), vertex, vertex + Vector2i(-1, 0)]
	var roads := 0
	var narrows := false
	for cell: Vector2i in cells:
		if _paved.has(cell):
			return false
		if _weights.has(cell):
			roads += 1
			narrows = narrows or _weights[cell] < 1.0
		elif not _grassy.has(cell):
			return false
	if roads == 2:
		return narrows or _wanders or _weights.has(cells[0]) == _weights.has(cells[2])
	return roads == 1 or roads == 3


## Whether road lies on two sides of `cell` at a right angle (inside a turn):
## the road may fill its corner. Not a strip of ground between two roads.
func _inside_turn(cell: Vector2i) -> bool:
	var across := _weights.has(cell + Vector2i.LEFT) or _weights.has(cell + Vector2i.RIGHT)
	var down := _weights.has(cell + Vector2i.UP) or _weights.has(cell + Vector2i.DOWN)
	return across and down


## Whether `cell` is a strip of ground between two roads (road on opposite
## sides): where the roads wander it never fills, or the two would run
## together.
func _between(cell: Vector2i) -> bool:
	return (_weights.has(cell + Vector2i.LEFT) and _weights.has(cell + Vector2i.RIGHT)) or (_weights.has(cell + Vector2i.UP) and _weights.has(cell + Vector2i.DOWN))
