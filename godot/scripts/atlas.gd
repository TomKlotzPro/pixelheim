class_name Atlas
## The map screen's pages (PIX-266: "the map grew a lot"). The screen showed
## the map the hero stood on and, for a waypoint chosen there, that one's
## map; the Reach has since grown six regions and their caves off the
## Ashenreach's edges, and none of them could be looked at from anywhere
## else. Now every map the hero has set foot on is a page, turned in the
## world's order, and each page names what is on it: its wild regions over
## what has been seen of them, its ways to other places once their doors
## have been seen. What the fog hides stays hidden: only walked ground is
## drawn (Discovery), a region is named over seen ground only, a way out
## once its door is seen. The village on the Ashenreach is drawn as the
## overworld now draws it (PIX-248's Skyline): the town small inside its
## rampart, each house in its roof's colour. Pure: the map screen draws,
## this decides.

## The pages in the order they turn, and the order the waypoints are listed
## in: the Ashenreach, the village, then round the Reach from the south-west
## as its roads leave it, each region followed by the cave under it (and the
## cave's floors below, PIX-255).
const ORDER := [
	"overworld", "town", "saltmere", "seacave", "seacave_galleries", "seacave_grotto", "mirefen", "blackiron", "shafts",
	"frostgate", "icecave", "greyhold", "cellars", "deepwood",
]
## Pixels per tile on a page: whole, as large as the window allows, within these.
const MIN_TILE := 2
const MAX_TILE := 12
## Each roof's colour on the map: Shade's roofs as the town wears them
## (PunyTown.ROOF_ROWS), terracotta, straw, moss and slate. The map coloured
## every roof one brown, and the village read as a brown smear.
const ROOFS := {
	"roof": Color("a4553c"), "roof_awning": Color("a4553c"), "roof_thatch": Color("c49a4a"),
	"roof_moss": Color("6b8a3e"), "roof_slate": Color("5d6a80"),
}
## Between a label and what it names, and the page's edge.
const GAP := 4.0
## Where a label has no room.
const NOWHERE := Vector2(-1, -1)
## How much of a region must have been seen for the map to name it.
const REGION_SEEN := 25


## Every map of the Reach seen end to end, as a hero who has walked it all
## (the harness's `charted`, the look book's map): the pages drawn whole.
static func walk_all(discovered: Dictionary) -> void:
	for map_id: String in ORDER:
		var seen: Dictionary = discovered.get_or_add(map_id, {})
		for cell: Vector2i in MapData.load_by_id(map_id).grid:
			seen[cell] = true


## Whether the hero has set foot on `map_id`: anything of it seen.
static func found(discovered: Dictionary, map_id: String) -> bool:
	var seen: Dictionary = discovered.get(map_id, {})
	return not seen.is_empty()


## The pages the map screen turns through: every map in ORDER the hero has
## found, and the one they stand on wherever it is (a room in town, which
## isn't a page of its own, comes first).
static func pages(discovered: Dictionary, here: String) -> Array[String]:
	var out: Array[String] = []
	if here not in ORDER:
		out.append(here)
	for map_id: String in ORDER:
		if map_id == here or found(discovered, map_id):
			out.append(map_id)
	return out


## The page `delta` pages on from `at`, wrapping round.
static func turn(pages: Array[String], at: String, delta: int) -> String:
	if pages.is_empty():
		return at
	var index := pages.find(at)
	if index < 0:
		return pages[0]
	return pages[wrapi(index + delta, 0, pages.size())]


## Whole pixels per tile for a map `size` tiles big in a `box`, as large as
## it fits: the Ashenreach at 7, the village at 9, a region at 11 or 12.
static func tile_px(size: Vector2i, box: Vector2) -> int:
	return clampi(mini(int(box.x / size.x), int(box.y / size.y)), MIN_TILE, MAX_TILE)


## The waypoints as the list shows them: grouped by the page they stand on,
## in ORDER, each group in the data's order.
static func listed(waypoints: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for map_id: String in ORDER:
		for waypoint: Dictionary in waypoints:
			if waypoint["mapId"] == map_id:
				out.append(waypoint)
	for waypoint: Dictionary in waypoints:
		if waypoint["mapId"] not in ORDER:
			out.append(waypoint)
	return out


## Whether a map's wild regions have names of their own: only where it has
## several (the Ashenreach's ash, woods and marsh). On a map that is one
## region (Greyhold, the Frostgate Pass) the region is the place, which the
## title names.
static func names_regions(map: MapData) -> bool:
	var kinds := {}
	for cell: Vector2i in map.regions:
		kinds[map.regions[cell]] = true
		if kinds.size() > 1:
			return true
	return false


## A region's name as a line of its own ("The Ash Fields", « Les Champs de
## Cendres »: the data writes them for mid-sentence), or "".
static func region_title(region: String) -> String:
	var name := String(Bestiary.region(region).get("name", ""))
	return name.left(1).to_upper() + name.substr(1)


## The village on a page that holds it as one block (the Ashenreach), as the
## overworld draws it (PIX-248, Skyline.plan, with `town` as it has grown
## and its burnt houses' `ruins`): cell -> the tile each of the block's
## cells reads as - the rampart's wall and its gate, the town's streets,
## river, fields and ash small inside, each house its roof's kind. {} on
## other pages.
static func village(map: MapData, town: MapData, ruins: Array) -> Dictionary:
	var out := {}
	if map.id not in PunyTerrain.SKYLINE_MAPS:
		return out
	var plan := Skyline.plan(map.grid, town, ruins)
	var block: Rect2i = plan["block"]
	var roofs: Dictionary = plan["roofs"]
	var ground: Dictionary = plan["ground"]
	for y in range(block.position.y, block.end.y):
		for x in range(block.position.x, block.end.x):
			var cell := Vector2i(x, y)
			if roofs.has(cell):
				out[cell] = roofs[cell]
			elif ground.has(cell):
				out[cell] = ground[cell]
			else:
				out[cell] = "door" if map.tile_at(cell) == "door" else "wall"
	return out


## A tile's colour on the map: a roof in its kind's, the rest as the map
## has always coloured them (WorldTiles.map_color).
static func color(tile: String) -> Color:
	return ROOFS[tile] if ROOFS.has(tile) else WorldTiles.map_color(tile)


## What a page names, as [{text, at, way}] with `at` in cells (the middle of
## what it names): first each way to another place - a road off to another
## region, a cave's mouth, the village's gate - once its door has been seen
## (`way`); then each wild region of a map that has several, over the middle
## of what has been seen of it (`seen`: cell -> true), once at least
## REGION_SEEN of its cells have been (a corner glimpsed from a pass isn't
## the marsh). Doors into the village's rooms aren't ways to another place,
## and the gates down into a dungeon have their waypoints standing there. A
## door into a room with a stair down (PIX-256: Liane's room, Captain Hale's
## hall) is named for the cave below it, which is where it leads on to.
static func labels(map: MapData, seen: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var place := Catalog.place_name(map.id)
	var named := {}
	for cell: Vector2i in map.portals:
		var to: Dictionary = map.portals[cell]
		if to["kind"] != "map" or not seen.has(cell):
			continue
		var beyond := Ways.below(String(to["mapId"]))
		var name := Catalog.place_name(beyond if beyond != "" else String(to["mapId"]))
		if name == place or named.has(name):
			continue
		named[name] = true
		out.append({"text": name, "at": Vector2(cell) + Vector2(0.5, 0.5), "way": true})
	if not names_regions(map):
		return out
	var sums := {}
	var counts := {}
	for cell: Vector2i in seen:
		var region := map.region_at(cell)
		if region == "":
			continue
		sums[region] = sums.get(region, Vector2.ZERO) + Vector2(cell)
		counts[region] = int(counts.get(region, 0)) + 1
	var regions: Array = sums.keys()
	regions.sort()
	for region: String in regions:
		if int(counts[region]) >= REGION_SEEN:
			out.append({"text": region_title(region), "at": sums[region] / counts[region] + Vector2(0.5, 0.5), "way": false})
	return out


## Where a label `size` px big goes on a page `bounds` px big, about the
## spot it names (`spot`, in the page's px), kept on the page and clear of
## what's `taken` (the marks, the chosen waypoint's tag, the names placed
## already), or NOWHERE when there's no room for it: a way's name beside
## the marks on its door (`mark` px across, the goal's diamond round it
## too), in from the edge the door is on - right of a door on the left
## edge, else just under or over that; under one on the top edge - else
## over the door, or under it; a region's name on its spot, else just under
## or over it.
static func label_at(spot: Vector2, size: Vector2, bounds: Vector2, way: bool, mark: float, taken: Array[Rect2] = []) -> Vector2:
	var tries: Array[Vector2] = []
	if way:
		# Past the marker's dark rim, and the goal's diamond round it.
		var off := floorf(mark / 2.0) + 6.0 + GAP
		var under := spot.y + off
		var over := spot.y - off - size.y
		var beside := spot.y - size.y / 2.0
		var middle := spot.x - size.x / 2.0
		if spot.x < mark * 2.0 or spot.x > bounds.x - mark * 2.0:
			var x := spot.x + off if spot.x < mark * 2.0 else spot.x - off - size.x
			tries.append_array([Vector2(x, beside), Vector2(x, under), Vector2(x, over)])
		elif spot.y < mark * 2.0:
			tries.append(Vector2(middle, under))
		else:
			tries.append_array([Vector2(middle, over), Vector2(middle, under)])
	else:
		var middle := spot - size / 2.0
		tries.append_array([middle, middle + Vector2(0, size.y + GAP), middle - Vector2(0, size.y + GAP)])
	for at: Vector2 in tries:
		var kept := Vector2(
			clampf(at.x, GAP, maxf(GAP, bounds.x - size.x - GAP)),
			clampf(at.y, GAP, maxf(GAP, bounds.y - size.y - GAP)),
		).round()
		var rect := Rect2(kept, size)
		if not taken.any(func(other: Rect2) -> bool: return other.grow(2.0).intersects(rect)):
			return kept
	return NOWHERE
