class_name Waypoints
## Fast travel's choice on the map screen (PIX-241: "on a waypoint, show
## where it takes you"): which waypoint the list starts on, how the choice
## moves, and what the map shows of the one chosen - a ring round its
## marker that breathes (and holds still with reduce motion), and a tag with
## its name and the region it sets you down in. Pure: the map screen draws,
## this decides.
## The ring and its marker are drawn about one pixel of the screen (PIX-267):
## in a full-screen browser the canvas is stretched by an uneven amount, and
## a marker centred half a pixel off the ring's centre came out a whole
## screen pixel off it. Every mark now stands on a corner of the screen's
## pixels with whole pixels each way (`snap_square`), whatever the stretch.

## How far from the landing a region still names it: the passes set you down
## on open road a step or two from the woods and the marsh they lead past.
const REGION_REACH := 3
## The ring's breath: one in this many milliseconds...
const PULSE_MS := 1200
## ...growing by up to this many pixels, two at a time (the UI's pixel grid).
const PULSE_PX := 8
## With reduce motion the ring holds still, this much grown.
const STEADY_PX := 4
## Between the marker's colour and the ring's gold at its smallest: the
## marker's dark rim and a dark line.
const RING_GAP := 6.0
## Between the ring and the tag, and the tag and the map's edge.
const TAG_GAP := 4.0


## The cell a waypoint's marker stands on, where the map draws it.
static func cell(waypoint: Dictionary) -> Vector2i:
	return Vector2i(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))


## Where travelling there sets the hero down.
static func landing(waypoint: Dictionary) -> Vector2i:
	return Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))


## Where the list's choice starts: the first waypoint in `usable` on the map
## the hero stands on, so the map opens on where they are; -1 (none chosen)
## when every one is elsewhere, since choosing one turns the map to its page.
static func first_on(usable: Array, map_id: String) -> int:
	for index in usable.size():
		if usable[index]["mapId"] == map_id:
			return index
	return -1


## The choice moved by `delta` through `count` waypoints, wrapping round;
## with none chosen yet, down takes the first and up the last.
static func step(selected: int, delta: int, count: int) -> int:
	if count <= 0:
		return -1
	if selected < 0:
		return 0 if delta >= 0 else count - 1
	return wrapi(selected + delta, 0, count)


## The encounter region where travelling to `waypoint` sets you down ("ash",
## "forest"...), else the nearest within REGION_REACH; "" on open ground
## (the town's gate, the square).
static func region_of(waypoint: Dictionary, map: MapData) -> String:
	var at := landing(waypoint)
	for reach in REGION_REACH + 1:
		for y in range(at.y - reach, at.y + reach + 1):
			for x in range(at.x - reach, at.x + reach + 1):
				if maxi(absi(x - at.x), absi(y - at.y)) != reach:
					continue
				var region := map.region_at(Vector2i(x, y))
				if region != "":
					return region
	return ""


## That region's name as a line of its own ("The Ash Fields", « Les Champs
## de Cendres »), or "". Only where the map has regions of its own names
## (Atlas.names_regions, PIX-266): on a map that is one region the place is
## the region, and the list and the tag would say Greyhold twice.
static func region_name(waypoint: Dictionary, map: MapData) -> String:
	var region := region_of(waypoint, map)
	if region == "" or not Atlas.names_regions(map):
		return ""
	return Atlas.region_title(region)


## How many pixels the ring has grown `elapsed` ms after its waypoint was
## chosen: at its widest the moment the choice lands (the eye goes to it),
## then breathing in and out in steps of two; still with reduce motion.
static func ring_grow(elapsed: int, reduce_motion: bool) -> int:
	if reduce_motion:
		return STEADY_PX
	var breath := (cos(float(posmod(elapsed, PULSE_MS)) / PULSE_MS * TAU) + 1.0) / 2.0
	return int(roundf(breath * PULSE_PX / 2.0)) * 2


## Where the tag naming the chosen waypoint goes on a `bounds`-sized map:
## centred over its ring (`center`, reaching `reach` px out at its widest),
## under it when there's no room above, and kept inside the map at the sides.
static func tag_at(center: Vector2, reach: float, tag: Vector2, bounds: Vector2) -> Vector2:
	var x := clampf(center.x - tag.x / 2.0, TAG_GAP, maxf(TAG_GAP, bounds.x - tag.x - TAG_GAP))
	var y := center.y - reach - TAG_GAP - tag.y
	if y < TAG_GAP:
		y = center.y + reach + TAG_GAP
	return Vector2(x, y).round()


## Where a marker stands for `cell` on a page of `px` pixels a tile: its
## cell's middle.
static func mark_at(cell: Vector2i, px: int) -> Vector2:
	return Vector2(cell) * px + Vector2.ONE * px / 2.0


## How far the ring reaches each way from its marker's middle, a marker
## `mark` px across, grown by `grow`: at its smallest it hugs the marker's
## dark rim, at its widest it takes in the spot two steps off where
## travelling sets you down.
static func ring_half(mark: float, grow: int) -> float:
	return floorf(mark / 2.0) + RING_GAP + grow


## The map's pixel `at` moved onto the nearest corner of the screen's
## pixels it is shown on (`shown`: the map's px to the screen's, the
## canvas layer and the window's stretch included).
static func snap_point(at: Vector2, shown: Transform2D) -> Vector2:
	return shown.affine_inverse() * (shown * at).round()


## A length on the map that is whole pixels on the screen, at least one.
static func snap_length(length: float, shown: Transform2D) -> float:
	var scale := shown.get_scale().x
	return maxf(1.0, roundf(length * scale)) / scale


## A square reaching `half` px each way from `center` on the map, with its
## middle on a corner of the screen's pixels and whole screen pixels each
## way: squares about one middle stay about one pixel at any stretch, as
## near as the screen can draw them.
static func snap_square(center: Vector2, half: float, shown: Transform2D) -> Rect2:
	var mid := snap_point(center, shown)
	var reach := snap_length(half, shown)
	return Rect2(mid - Vector2(reach, reach), Vector2(reach, reach) * 2.0)


## A marker `mark` px across at `center`: its dark rim, then its colour.
static func marker_squares(center: Vector2, mark: float, shown: Transform2D) -> Array[Rect2]:
	var half := floorf(mark / 2.0)
	return [snap_square(center, half + 2.0, shown), snap_square(center, half, shown)]


## The goal's diamond, reaching `half` px each way to its gold's points
## (PIX-240), as bands from the outside in: [outer, inner, gold], whole
## screen pixels each, inner 0 where a band is filled to the middle. A dark
## rim, then the gold; hollow (PIX-253 step 2: the main story's, kept on
## the map while something else leads), the gold is a band between the rim
## and a dark line inside it, and the page shows through the middle.
static func diamond_bands(half: float, hollow: bool, shown: Transform2D) -> Array:
	var rim := snap_length(half + 3.0, shown)
	var edge := snap_length(half, shown)
	if not hollow:
		return [[rim, edge, false], [edge, 0.0, true]]
	var inside := snap_length(half - 3.0, shown)
	return [[rim, edge, false], [edge, inside, true], [inside, snap_length(half - 5.0, shown), false]]


## The chosen waypoint's ring round a marker `mark` px across, grown by
## `grow`: two pixels of gold between dark lines, as the squares its bands
## run between, outermost first - the dark line's outside, the gold's
## outside, the gold's inside, the dark line's inside.
static func ring_squares(center: Vector2, mark: float, grow: int, shown: Transform2D) -> Array[Rect2]:
	var half := ring_half(mark, grow)
	return [
		snap_square(center, half + 2.0, shown),
		snap_square(center, half, shown),
		snap_square(center, half - 4.0, shown),
		snap_square(center, half - 6.0, shown),
	]
