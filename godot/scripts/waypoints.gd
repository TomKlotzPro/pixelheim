class_name Waypoints
## Fast travel's choice on the map screen (PIX-241: "on a waypoint, show
## where it takes you"): which waypoint the list starts on, how the choice
## moves, and what the map shows of the one chosen - a ring round its
## marker that breathes (and holds still with reduce motion), and a tag with
## its name and the region it sets you down in. Pure: the map screen draws,
## this decides.

## How far from the landing a region still names it: the passes set you down
## on open road a step or two from the woods and the marsh they lead past.
const REGION_REACH := 3
## The ring's breath: one in this many milliseconds...
const PULSE_MS := 1200
## ...growing by up to this many pixels, two at a time (the UI's pixel grid).
const PULSE_PX := 8
## With reduce motion the ring holds still, this much grown.
const STEADY_PX := 4
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
## de Cendres »: the data writes them for mid-sentence), or "".
static func region_name(waypoint: Dictionary, map: MapData) -> String:
	var region := region_of(waypoint, map)
	if region == "":
		return ""
	var name := String(Bestiary.region(region).get("name", ""))
	return name.left(1).to_upper() + name.substr(1)


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
