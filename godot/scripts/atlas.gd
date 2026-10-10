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
## The Reach is one page (One Reach, PIX-269, step 7): the Ashenreach and
## the six regions round its edges are one world underfoot, so the map draws
## them together, each where the plane puts it (ReachPlane), with the ridge
## seen from their edges between them. The page frames the maps found, so
## it opens as the Ashenreach alone and widens as the regions are found.
## Each map keeps its own cells - the fog of war, the waypoints, the marks -
## and only lies at its offset on the page. The village, the rooms and the
## caves keep pages of their own: places behind a door.

## The maps in the world's order, which the waypoints are listed in and the
## pages turn in: the Ashenreach, the village, then round the Reach from the
## south-west as its roads leave it, each region followed by the cave under
## it (and the cave's floors below, PIX-255); the regions are on the Reach's
## page, their caves and each cave's floor a page of their own.
const ORDER := [
	"overworld", "town", "saltmere", "seacave", "seacave_galleries", "seacave_grotto", "mirefen",
	"blackiron", "shafts", "shafts_gallery", "shafts_blackseam",
	"frostgate", "icecave", "greyhold", "cellars", "cellars_crypt", "cellars_hall", "deepwood",
]
## Pixels per tile on a page: whole, as large as the window allows, within these.
const MIN_TILE := 2
const MAX_TILE := 12
## The Reach's page goes by the Ashenreach's id, the plane's middle.
const REACH := "overworld"
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


## The page `map_id` is drawn on: the Reach's for the Ashenreach and its
## regions, else its own.
static func page_of(map_id: String) -> String:
	return REACH if ReachPlane.holds(map_id) else map_id


## The pages the map screen turns through: the page of every map in ORDER
## the hero has found, and of the one they stand on wherever it is (a room
## in town, which isn't a page of its own, comes first), each once.
static func pages(discovered: Dictionary, here: String) -> Array[String]:
	var out: Array[String] = []
	if here not in ORDER:
		out.append(page_of(here))
	for map_id: String in ORDER:
		var page := page_of(map_id)
		if page not in out and (map_id == here or found(discovered, map_id)):
			out.append(page)
	return out


## The maps drawn on `page`, each with where its cell (0, 0) lies on the
## page: [{"id", "at"}], the page's own map first. The Reach's page holds
## the Ashenreach, every region found and the one the hero stands on, each
## at its place in the plane, framed to them: a region not found yet takes
## no room on it. Any other page is its map alone.
static func sheets(page: String, discovered: Dictionary, here: String) -> Array[Dictionary]:
	if page != REACH:
		return [{"id": page, "at": Vector2i.ZERO}]
	var ids: Array[String] = []
	for map_id: String in ReachPlane.maps():
		if map_id == REACH or map_id == here or found(discovered, map_id):
			ids.append(map_id)
	var frame := ReachPlane.rect_of(REACH)
	for map_id: String in ids:
		frame = frame.merge(ReachPlane.rect_of(map_id))
	var out: Array[Dictionary] = []
	for map_id: String in ids:
		out.append({"id": map_id, "at": ReachPlane.origin(map_id) - frame.position})
	return out


## How big a page of `sheets` is, in cells (`sizes`: map id -> its size).
static func page_size(sheets: Array[Dictionary], sizes: Dictionary) -> Vector2i:
	var size := Vector2i.ZERO
	for sheet: Dictionary in sheets:
		size = size.max(sheet["at"] + sizes[sheet["id"]])
	return size


## The ridge between the maps on the Reach's page that the hero has had in
## sight, as page cells: the plane's cells no map holds within
## Discovery.SIGHT_RADIUS of ground seen at a map's edge (every map is
## rimmed with the ridge's cliffs). Empty on any other page.
static func ridge(sheets: Array[Dictionary], discovered: Dictionary) -> Dictionary:
	var out := {}
	if sheets.is_empty() or not ReachPlane.holds(sheets[0]["id"]):
		return out
	var reach := Discovery.SIGHT_RADIUS
	var sizes := {}
	for sheet: Dictionary in sheets:
		sizes[sheet["id"]] = ReachPlane.size_of(sheet["id"])
	var page := Rect2i(Vector2i.ZERO, page_size(sheets, sizes))
	# The plane's cell under the page's (0, 0).
	var corner: Vector2i = ReachPlane.origin(sheets[0]["id"]) - sheets[0]["at"]
	for sheet: Dictionary in sheets:
		var size: Vector2i = sizes[sheet["id"]]
		var bounds := Rect2i(Vector2i.ZERO, size)
		var inside := bounds.grow(-reach)
		for cell: Vector2i in discovered.get(sheet["id"], {}):
			if inside.has_point(cell):
				continue
			for dy in range(-reach, reach + 1):
				for dx in range(-reach, reach + 1):
					var near := cell + Vector2i(dx, dy)
					var on_page: Vector2i = near + sheet["at"]
					if bounds.has_point(near) or out.has(on_page) or not page.has_point(on_page):
						continue
					if ReachPlane.at(on_page + corner).is_empty():
						out[on_page] = true
	return out


## Where the way from map `from` to map `to` leaves the maps on a page
## (`on_page`: their ids), as {"map", "cell"}: the door on the last of them
## it crosses, followed map to map as Bearing.way_out finds it; {} with no
## way there. On a page of one map, that map's door that starts the way.
static func way_off(on_page: Array, from: String, to: String) -> Dictionary:
	var here := from
	for hop in on_page.size():
		var door := Bearing.way_out(here, to)
		if door == Bearing.NOWHERE:
			return {}
		var next := Bearing.through(here, door)
		if next not in on_page:
			return {"map": here, "cell": door}
		here = next
	return {}


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
## hall) is named for the cave below it, which is where it leads on to. A
## way to a map drawn on the same page (`drawn`: their ids) isn't named:
## its road runs on into it there.
static func labels(map: MapData, seen: Dictionary, drawn: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var place := Catalog.place_name(map.id)
	var named := {}
	for cell: Vector2i in map.portals:
		var to: Dictionary = map.portals[cell]
		if to["kind"] != "map" or not seen.has(cell) or String(to["mapId"]) in drawn:
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


## What a page of `sheets` ([{"id", "at", "map"}], Atlas.sheets with each
## map) names, as labels gives it but with `at` in the page's cells: first
## each map on it but the page's own (the title names that one: on the
## Reach's page, the six regions) over the middle of what's been seen of
## it, then each map's ways to places off the page and its own regions.
static func page_labels(sheets: Array[Dictionary], discovered: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var drawn: Array = sheets.map(func(sheet: Dictionary) -> String: return sheet["id"])
	for sheet: Dictionary in sheets.slice(1):
		var seen: Dictionary = discovered.get(sheet["id"], {})
		if seen.is_empty():
			continue
		var sum := Vector2.ZERO
		for cell: Vector2i in seen:
			sum += Vector2(cell)
		out.append({"text": Catalog.place_name(sheet["id"]), "at": sum / seen.size() + Vector2(0.5, 0.5) + Vector2(sheet["at"]), "way": false})
	for sheet: Dictionary in sheets:
		for label: Dictionary in labels(sheet["map"], discovered.get(sheet["id"], {}), drawn):
			label["at"] += Vector2(sheet["at"])
			out.append(label)
	return out


## Where a label `size` px big goes on a page `bounds` px big, about the
## spot it names (`spot`, in the page's px), kept on the page and clear of
## what's `taken` (the marks, the chosen waypoint's tag, the names placed
## already), or NOWHERE when there's no room for it: a way's name beside
## the marks on its door (`mark` px across, the goal's diamond round it
## too), in from the edge the door is on - right of a door on the left
## edge, else just under or over that; under one on the top edge - else
## over the door, or under it; a region's name on its spot, else just under
## or over it, else a line further (the Reach's page is small print, and a
## chosen waypoint's tag may sit on a region's middle).
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
		var step := Vector2(0, size.y + GAP)
		tries.append_array([middle, middle + step, middle - step, middle + step * 2.0, middle - step * 2.0])
	for at: Vector2 in tries:
		var kept := Vector2(
			clampf(at.x, GAP, maxf(GAP, bounds.x - size.x - GAP)),
			clampf(at.y, GAP, maxf(GAP, bounds.y - size.y - GAP)),
		).round()
		var rect := Rect2(kept, size)
		if not taken.any(func(other: Rect2) -> bool: return other.grow(2.0).intersects(rect)):
			return kept
	return NOWHERE
