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
## sand and grass again to it in his own colours and edge dither. Only the
## drawing changes: the grid, and so where the hero walks, doesn't. Pure.

## The maps drawn so: the fix is Saltmere's (PIX-551 goes to no other map).
const MAPS := ["saltmere"]
## How many cells past the map's edges the mask reaches, as the road's.
const RING := RoadShape.RING
## The mask's green, where the ground is drawn again: a sand or grass cell
## beside the other (or sand beside a road), nothing round it but sand,
## grass, sea and road. NEAR a road, whose own edge of dirt stays; PLAIN
## away from one, where his edge's dither is drawn again too. Beside rock or
## a river the cell keeps Shade's own (a cliff's grassy top is no dune).
const NEAR := 0.5
const PLAIN := 1.0
## The grounds the sand's field counts as sand: his sea meets his sand
## already (PIX-532's waterline stays), so the edge never bends toward it.
const SANDY := ["sand", "seawater-light", "seawater-medium", "seawater-deep"]


## The mask of `look` (a map's ground as drawn, `size` cells), where
## `beyond(cell)` says what lies past its edges, a cell a texel from cell
## (-RING, -RING): red the cell's weight in the sand's field, green where the
## ground is drawn again (NEAR, PLAIN), blue how far the edge may wander
## there (1, or 0 within two cells of rock or a river, where a cell keeps
## Shade's own and the two must meet).
static func image_of(look: Dictionary, beyond: Callable, size: Vector2i) -> Image:
	var image := Image.create(size.x + 2 * RING, size.y + 2 * RING, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 1))
	var drawn := {}
	var rock := {}
	for y in range(-RING - 2, size.y + RING + 2):
		for x in range(-RING - 2, size.x + RING + 2):
			var cell := Vector2i(x, y)
			var ground := _ground(look, beyond, cell)
			if ground not in SANDY and ground not in ["grass", "dirt"]:
				rock[cell] = true
			var zone := _zone(look, beyond, cell)
			if zone > 0.0:
				drawn[cell] = zone
	for y in range(-RING, size.y + RING):
		for x in range(-RING, size.x + RING):
			var cell := Vector2i(x, y)
			var free := true
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					free = free and not rock.has(cell + Vector2i(dx, dy))
			var sandy := _ground(look, beyond, cell) in SANDY
			image.set_pixel(x + RING, y + RING, Color(1.0 if sandy else 0.0, drawn.get(cell, 0.0), 1.0 if free else 0.0, 1.0))
	return image


static func _ground(look: Dictionary, beyond: Callable, cell: Vector2i) -> String:
	return PunyTerrain.ground_of(RoadWear.ground_at(look, beyond, cell))


## Whether the ground is drawn again at `cell` (NEAR, PLAIN; 0 where it
## isn't): sand with anything but sand and sea beside it, or grass with sand
## beside it, on any of its eight sides.
static func _zone(look: Dictionary, beyond: Callable, cell: Vector2i) -> float:
	var ground := _ground(look, beyond, cell)
	if ground != "sand" and ground != "grass":
		return 0.0
	var edge := false
	var road := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var beside := _ground(look, beyond, cell + Vector2i(dx, dy))
			if beside == "dirt":
				road = true
			elif beside != "grass" and beside not in SANDY:
				return 0.0
			edge = edge or (beside == "sand" if ground == "grass" else beside in ["grass", "dirt"])
	if not edge:
		return 0.0
	return NEAR if road else PLAIN
