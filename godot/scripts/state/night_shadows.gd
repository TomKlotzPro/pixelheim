class_name NightShadows
## areas: town field dungeon night
## The rules of the shadows the lantern and the lamps cast in the dark
## (PIX-490): what blocks their light, from what footprint, and which few
## lights cast. Until now a light shone through everything. A house, a
## cliff or a dungeon's wall blocks it by its cells; what stands among the
## actors (a tree, a rock, a stall, a cart, a barrel) by the foot it stands
## on, its body's box or the bottom of its picture; a villager or the hero
## by their feet, for the lamps only. The hero's lantern always casts, and
## the lamps nearest the hero up to a cap; the others light as before.
## Pure rules: NightShadowsLayer lays the occluders, the LightRig picks the
## lights frame by frame.

## How many lamps cast besides the hero's lantern, in the browser as on
## the desktop (three cost the web build's frame about 0.3 ms of 16.7:
## perf.md).
const LAMPS := 3
## A lamp casts only within this many pixels of the hero's feet (past the
## screen's edge), and its shadows come and go over this many seconds, so
## none pops as the hero walks from one lamp's pool to the next.
const REACH := 240.0
const FADE := 0.5
## How much of a light a shadow takes away: never all of it, and the
## night's own light is still under it, so a shadow is the night's blue,
## never black. A share of the light on any ground since the floors carry
## the art's colour into a shadow (PIX-528, relief.gdshaderinc): before,
## what was left was the light's own colour, nearly all of it over dark
## grass and a light rim along the edge.
const DEPTH := 0.6
## How soft a shadow's edge is (PointLight2D.shadow_filter_smooth).
const SOFT := 2.5
## The tiles that stand tall and block a light by their cell: rock, walls,
## roofs and house fronts. Not water or a garden bed (flat), nor a fence or
## a counter (low), nor anything a prop stands for (its body's foot does).
const TALL := ["mountain", "wall", "rock", "wreck", "sealed", "statue", "door_shut"]
## A body's box is widened this much each side, so the feet of a stall or
## a cart two cells long meet (each a box in the middle of its cell) and
## no sliver of light runs through its shadow.
const WIDER := 2.0
## A picture no taller than a cell is too low to cast (a tuft, a sheaf, a
## log) unless it is a tree's or a rock's (`tall`: Shade's free trees are a
## cell tall); what casts does from a foot this share of its width, at
## least and at most so many pixels across, and this deep.
const LOW := 16.0
const FOOT_SHARE := 0.4
const FOOT_WIDE := Vector2(4, 12)
const FOOT_DEEP := 3.0
## How near a tall cell a light may burn and still cast, in cells (an
## eighth: two pixels; a dungeon's wall torch burns three below its wall).
const NEAR_WALL := 0.125
## A flame burning within this many pixels of a standing thing's foot (a
## cell: a camp's torch against its tent, a lantern hung under a tree)
## casts nothing (PIX-495): so near, the foot's shadow took a quarter of
## the pool in one hard-edged wedge as far as the light reached. Its light
## is soft all round as before, and the hero's lantern still casts from
## the thing.
const AGAINST := 16.0
## A villager's or the hero's feet, in pixels.
const FEET := Vector2(8, 3)
## The occluders' light bits: the scenery blocks every casting light, the
## folk walking about only the lamps (the hero would block their own
## lantern). The scenery's is the floor's own (Lights.FLOOR): a light's
## shadow bits say what blocks it and what its shadows fall on, both.
const SCENERY := Lights.FLOOR
const FOLK := 1 << 11
## The outlines round the blocks of tall cells (cliffs, ramparts, houses)
## have a bit of their own: they block the lamps and the lantern, whose
## pools are small, and not the lightning's light (PIX-491), which reaches
## the whole view from beyond it - a shadow runs on to the end of its
## light, so one house laid a whole square in shadow, and the ring of rock
## round a valley the whole valley.
const WALLS := 1 << 12
## What blocks a lamp's light, the hero's lantern's and the lightning's.
const LAMP := SCENERY | FOLK | WALLS
const LANTERN := SCENERY | WALLS
const SKY := SCENERY | FOLK


## Whether `tile` stands tall and blocks a light by its cell.
static func blocks(tile: String) -> bool:
	return tile in TALL or tile.begins_with("roof") or tile.begins_with("sign_")


## The outlines of the blocks `solid` cells make (cell -> anything), in
## cells' corners: one closed loop round each block, and one round each
## hole in it, every edge with its block on its right (clockwise on the
## screen round a block). A block is one occluder, not a box a cell: a
## light passes its near edges and stops at its far ones (the occluder's
## cull), so the wall facing the light stays lit, as the ground inside the
## block does, and no edge between two of its cells casts a shadow of its
## own (a row of boxes lit along its length threw a saw's teeth of light).
static func outlines(solid: Dictionary) -> Array[PackedVector2Array]:
	# Each edge between a solid cell and an open one, from its first corner.
	var edges := {}
	for cell: Vector2i in solid:
		for side: Array in SIDES:
			if not solid.has(cell + side[0]):
				var from: Vector2i = cell + side[1]
				if not edges.has(from):
					edges[from] = []
				edges[from].append(cell + side[2])
	var out: Array[PackedVector2Array] = []
	for start: Vector2i in edges:
		while not edges[start].is_empty():
			var loop := PackedVector2Array()
			var at := start
			var heading := Vector2i.ZERO
			while true:
				var ways: Array = edges[at]
				var to: Vector2i = ways[0]
				# Where two blocks meet at a corner, turn right: round the
				# block this loop began on.
				var right := at + Vector2i(-heading.y, heading.x)
				if right in ways:
					to = right
				ways.erase(to)
				if to - at != heading:
					loop.append(Vector2(at))
				heading = to - at
				at = to
				if at == start:
					break
			out.append(loop)
	return out


## A cell's four sides, clockwise from the top: [the cell beyond it, the
## corner the edge starts on, the corner it ends on], from the cell.
const SIDES := [
	[Vector2i(0, -1), Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 1)],
	[Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 1)],
	[Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, 0)],
]


## Whether a light burning `at` (in cells) is in one of the `solid` cells
## (cell -> anything) or within NEAR_WALL of one: a lamp against a wall, a
## torch on a dungeon's. Inside a block's outline every edge is a far one
## and the whole pool goes dark, so such a light casts nothing.
static func shut_in(solid: Dictionary, at: Vector2) -> bool:
	for step: Vector2 in [Vector2.ZERO, Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		if solid.has(Vector2i((at + step * NEAR_WALL).floor())):
			return true
	return false


## The cells of a house that block a light, of the cells it is drawn over
## (`bounds`): its lowest rows, the ground it stands on (ShadowsLayer's
## share of its drawing, as the sun's shadow of it); the rows above are its
## roof seen from the front, over ground that lies behind it.
static func house_foot(bounds: Rect2i) -> Rect2i:
	var rows := clampi(roundi(bounds.size.y * ShadowsLayer.HOUSE_GROUND), 1, bounds.size.y)
	return Rect2i(bounds.position.x, bounds.end.y - rows, bounds.size.x, rows)


## The cells of `grid` that block a light, each -> true: the tall ones
## (`blocks`) but a prop's (`props`, cell -> anything: its body's foot
## casts) and, of each house (`houses`, the cells each is drawn over, as
## PunyTown.houses' rects), all but its foot; none of a house when it isn't
## `drawn` (without the paid art nothing stands there to cast). Never a
## cell the hero can stand on: the lantern is never shut in.
static func solid(grid: Dictionary, props: Dictionary, houses: Array, drawn: bool) -> Dictionary:
	var roofs := {}
	for bounds: Rect2i in houses:
		var foot := house_foot(bounds)
		for y in range(bounds.position.y, bounds.end.y):
			for x in range(bounds.position.x, bounds.end.x):
				var cell := Vector2i(x, y)
				if (not drawn or not foot.has_point(cell)) and is_house(grid.get(cell, "")):
					roofs[cell] = true
	var out := {}
	for cell: Vector2i in grid:
		if blocks(grid[cell]) and not props.has(cell) and not roofs.has(cell) and not WorldTiles.is_walkable(grid[cell]):
			out[cell] = true
	return out


## Whether `tile` is a house's: its roof, a sign or a shut door set in it
## (a rampart's or a dungeon's wall is not).
static func is_house(tile: String) -> bool:
	return tile.begins_with("roof") or tile.begins_with("sign_") or tile == "door_shut"


## Whether a map has such shadows at all: under the sky and underground,
## not in a room (its furniture stands against the walls its candles hang
## on).
static func on_map(map: MapData) -> bool:
	return map != null and not PunyInterior.is_room(map.id)


## The foot a standing picture `size` pixels casts from, from the middle of
## its bottom up: none (Vector2.ZERO) when it's too low and not `tall`.
static func foot_of(size: Vector2, tall := false) -> Vector2:
	if size.y <= LOW and not tall:
		return Vector2.ZERO
	return Vector2(clampf(size.x * FOOT_SHARE, FOOT_WIDE.x, FOOT_WIDE.y), FOOT_DEEP)


## The foot a body's box `size` pixels casts from: the box, WIDER.
static func foot_of_body(size: Vector2) -> Vector2:
	return size + Vector2(WIDER * 2.0, 0.0)


## Whether one of `lights` burns in the foot `rect` (or within `near`
## pixels of it): a lamp's post, a campfire's stones. It casts none, or
## its own light would be shut in.
static func holds_light(rect: Rect2, lights: PackedVector2Array, near := 6.0) -> bool:
	var reach := rect.grow(near)
	for at in lights:
		if reach.has_point(at):
			return true
	return false


## A foot's outline as a light sees it: its box's two diagonals, drawn in
## one stroke (corner to corner, up its side, corner to corner). A line
## through the box always meets one of them, so it blocks the light from
## every side as the box would; it has no inside, so a lantern carried
## over it (the hero walks under a forest's trees) is never shut in; and
## where two strokes join, the other diagonal stands behind, so no sliver
## of light slips through the joint (a Z across the box let one through
## at each end of its shadow).
static func outline(size: Vector2) -> PackedVector2Array:
	var half := size / 2.0
	return PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, half.y), Vector2(half.x, -half.y), Vector2(-half.x, half.y)])


## Which lamps should cast, by how far each burns from the hero's feet
## (`distances`, in pixels): the `cap` nearest within REACH, by their place
## in `distances`.
static func nearest(distances: PackedFloat32Array, cap: int) -> PackedInt32Array:
	var order: Array = range(distances.size()).filter(func(i: int) -> bool: return distances[i] <= REACH)
	# The nearest first; of two as near, the first listed (the same every run).
	order.sort_custom(func(a: int, b: int) -> bool:
		return distances[a] < distances[b] or (distances[a] == distances[b] and a < b))
	return PackedInt32Array(order.slice(0, maxi(cap, 0)))


## A lamp's casting `strength` (0 to 1) a frame of `delta` seconds on: up
## toward 1 while it is `wanted`, down to 0 once it isn't, FADE seconds
## either way. One not yet casting only starts when there is `room` under
## the cap (those fading out still count), so no more than the cap ever
## cast at once.
static func faded(strength: float, wanted: bool, room: bool, delta: float) -> float:
	if wanted and (strength > 0.0 or room):
		return minf(strength + delta / FADE, 1.0)
	if wanted:
		return 0.0
	return maxf(strength - delta / FADE, 0.0)


## What a light of `color` and `energy` leaves in its shadow when it casts
## with `strength` (PointLight2D.shadow_color): the light a shadowed pixel
## still gets. Godot blends from the light's colour times its energy to
## this colour times its alpha, so the colour carries the energy too: with
## the bare colour a dim lantern's shadow was nearly as bright as its
## light, and brighter than it along its edge. The floors' light() carries
## the art's colour into it too (SHADOW_MODULATE, PIX-528).
static func left_in_shadow(color: Color, energy: float, strength: float) -> Color:
	var lit := minf(energy, 1.0)
	return Color(color.r * lit, color.g * lit, color.b * lit, 1.0 - DEPTH * clampf(strength, 0.0, 1.0))
