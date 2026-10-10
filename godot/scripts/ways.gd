class_name Ways
## The ways between maps (PIX-269: "it isn't clear where to walk to go on").
## Every portal that takes the hero to another map or a dungeon, read as one
## way on: an opening at the map's edge (its portal cells side by side), a
## cave mouth, a gate set in the rock or a rampart, a door, the stairs up out
## of a cave. Each knows the step that takes the hero through it, the cell
## they come at it from, the place it leads to, and where the signpost that
## names that place stands beside it: Shade's own signposts from the CC0
## Puny World sheet, so they stand with or without the paid packs.
## Pure: MapView draws the posts, the cave mouths' frames and torches and the
## gates in the rock; the HUD's nameplate names the place as the hero walks
## up; the world turns the hero on arrival to face into the new map
## (arrival_facing).
## A house in the Reach opens onto a room, and the dungeon is down in its
## cellar (PIX-256: "strange to walk into a house and find a dungeon"): a
## stairwell in the room's floor is a way "down", which asks before it takes
## the hero (going_down) and, like a room's door, needs no post: the
## nameplate names where it goes as the hero walks up.

const NOWHERE := Vector2i(-1, -1)
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## Shade's signposts (PunyTerrain's sheet): two flat boards (here), the top
## board turned away up the road (on ahead), the top board pointing right
## (left, flipped).
const POST_HERE := 817
const POST_AHEAD := 818
const POST_SIDE := 819
## A post's foot: the post itself, over the middle of the bottom of its cell
## like every blocker (x 4..12, y 7..15).
const POST_FOOT := Rect2(4, 7, 8, 9)
## Plain ground a post may stand on: not a road (it stands beside one), not
## a forest's trees, flowers or a field.
const POST_GROUND := ["grass", "ash", "sand", "marsh", "snow", "stone", "floor", "ice"]
## How far in from its way a post may stand (the length of a pass through
## the pines, to stand where it opens), and how far to the side of it.
const POST_DEPTH := 12
const POST_REACH := 3
## (A cave mouth is Shade's framed mine entrance: PunyTerrain.CAVE_MOUTH.)
## A gate set in the rock (the Ashen Mountain's): Shade's castle gate, its
## portcullis down while the gate is barred.
const ROCK_GATE := 802
const ROCK_GATE_BARRED := 803


## Every way on from `map`, in the map's own order (its portals list a way's
## road cell first): [{"cells": [Vector2i], "at": Vector2i, "kind": "edge" |
## "cave" | "gate" | "door" | "stairs", "rock": bool (a gate in the rock),
## "out": Vector2i (the step through), "from": Vector2i (the cell the hero
## comes at it from), "to": the portal's target, "name": the place,
## "about": how the way goes, "post": Vector2i (NOWHERE: no post), "look":
## [tile, flipped]}]. A post keeps off `taken` and off everything the map's
## data puts somewhere (taken_on): the cells where the hero arrives, its
## villagers, chests, packs and their camps. Dungeon floors have none.
static func on(map: MapData, taken := {}) -> Array[Dictionary]:
	var ways: Array[Dictionary] = []
	if map.floor_level > 0:
		return ways
	var avoid := taken.merged(taken_on(map))
	var signed := _signed(map.id)
	var room := indoors(map)
	var seen := {}
	for cell: Vector2i in map.portals:
		if seen.has(cell):
			continue
		var cells := _opening(map, cell)
		for part: Vector2i in cells:
			seen[part] = true
		var kind := kind_of(map, cell)
		var way := {"cells": cells, "at": _middle(map, cells), "kind": kind, "to": map.portals[cell]}
		way["rock"] = kind == "gate" and _in_rock(map, way["at"])
		way["out"] = _out(map, way)
		way["from"] = (way["at"] as Vector2i) - (way["out"] as Vector2i)
		way["name"] = place_of(way["to"])
		way["about"] = about(kind, way["out"])
		# Rooms have one door, and the town's shop doors their hanging boards.
		var posted := not room and not cells.any(func(part: Vector2i) -> bool: return signed.has(part))
		way["post"] = _post(map, way, avoid) if posted else NOWHERE
		way["look"] = post_look(way)
		ways.append(way)
	return ways


## A room or a hut: four walls round a floor, its door the one way out,
## which needs no post to name it.
static func indoors(map: MapData) -> bool:
	return PunyInterior.is_room(map.id) or (map.style != "cave" and not PunyTerrain.is_outdoor(map.grid))


## What a portal cell is, as a way: a cave mouth (the stairs up, in a cave),
## the stairs down from a room, a gate (in a rampart or in the rock), a
## door, or an opening at the edge.
static func kind_of(map: MapData, cell: Vector2i) -> String:
	var tile := map.tile_at(cell)
	if tile == "stairwell":
		return "down"
	if tile == "cave":
		return "stairs" if map.style == "cave" else "cave"
	if tile.begins_with("door"):
		if indoors(map):
			return "door"
		var walled := PunyTerrain.wall_piece(map.grid, cell) == PunyTerrain.GATE
		return "gate" if walled or _in_rock(map, cell) else "door"
	if cell.x == 0 or cell.y == 0 or cell.x == map.size.x - 1 or cell.y == map.size.y - 1:
		return "edge"
	return "door"


## The place a way leads to, in the player's language: a map's place name
## (the waypoints' list names places the same way), a dungeon's name.
static func place_of(target: Dictionary) -> String:
	match String(target.get("kind", "")):
		"map":
			return Catalog.place_name(String(target["mapId"]))
		"dungeon":
			return String(Dungeons.dungeon(String(target["dungeon"])).get("name", String(target["dungeon"]).capitalize()))
	return ""


## The nameplate's second line: the way the road leaves, or what the hero
## goes through.
static func about(kind: String, out: Vector2i) -> String:
	match kind:
		"cave":
			return Text.t("Through the cave")
		"gate":
			return Text.t("Through the gate")
		"door":
			return Text.t("Through the door")
		"stairs":
			return Text.t("Up the stairs")
		"down":
			return Text.t("Down the stairs")
	match out:
		Vector2i.UP:
			return Text.t("The road north")
		Vector2i.RIGHT:
			return Text.t("The road east")
		Vector2i.DOWN:
			return Text.t("The road south")
	return Text.t("The road west")


## Which of Shade's signposts names a way, and whether it's flipped: an
## arrow pointing the way the road leaves (right, or flipped for left), the
## board turned away for a way on ahead (north), two plain boards for south
## and for stairs.
static func post_look(way: Dictionary) -> Array:
	if way["kind"] == "stairs":
		return [POST_HERE, false]
	match way["out"]:
		Vector2i.RIGHT:
			return [POST_SIDE, false]
		Vector2i.LEFT:
			return [POST_SIDE, true]
		Vector2i.UP:
			return [POST_AHEAD, false]
	return [POST_HERE, false]


## Where nothing of the map's data may be covered by a post: every cell the
## hero arrives on here (through a portal from anywhere, or a waypoint),
## the spawn, waypoints' markers, villagers' homes, chests, fishing spots,
## and the packs' homes with the ring round them and their camps.
static func taken_on(map: MapData) -> Dictionary:
	var out := {map.spawn: true}
	for cell: Vector2i in arrivals_into(map.id):
		out[cell] = true
	for waypoint: Dictionary in Interactables.waypoints():
		if waypoint["mapId"] == map.id:
			out[Vector2i(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))] = true
			out[Vector2i(int(waypoint["arrival"]["x"]), int(waypoint["arrival"]["y"]))] = true
	for npc: Dictionary in Npcs._data()["npcs"]:
		if npc["mapId"] == map.id:
			out[Vector2i(int(npc["x"]), int(npc["y"]))] = true
	for recruit: Dictionary in Npcs._data()["recruits"]:
		var found: Dictionary = recruit.get("found", {})
		if found.get("mapId", "") == map.id:
			out[Vector2i(int(found["x"]), int(found["y"]))] = true
	for chest: Dictionary in Interactables.chests_on(map.id):
		out[Vector2i(int(chest["x"]), int(chest["y"]))] = true
	for spot: Dictionary in Bestiary._data().get("fishingSpots", []):
		if spot["mapId"] == map.id:
			out[Vector2i(int(spot["x"]), int(spot["y"]))] = true
	for spawn: Dictionary in Bestiary.spawns_on(map.id):
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				out[Vector2i(int(spawn["x"]) + dx, int(spawn["y"]) + dy)] = true
	for cell: Vector2i in MapView.plan_camps(map):
		out[cell] = true
	return out


static var _arrivals := {}


## Every cell a portal on any named map sets the hero down on in `map_id`,
## learned once from the maps on disk.
static func arrivals_into(map_id: String) -> Array:
	if _arrivals.is_empty():
		for from_id: String in _map_ids():
			var data := MapData.load_by_id(from_id)
			for cell: Vector2i in data.portals:
				var target: Dictionary = data.portals[cell]
				if target.get("kind", "") != "map":
					continue
				var into := String(target["mapId"])
				if not _arrivals.has(into):
					_arrivals[into] = []
				(_arrivals[into] as Array).append(Vector2i(int(target["x"]), int(target["y"])))
	return _arrivals.get(map_id, [])


## Every named map (Bearing learns its doors from the same list).
static func _map_ids() -> Array[String]:
	var ids: Array[String] = []
	for map_id: String in Catalog._data()["places"]:
		ids.append(map_id)
	return ids


## Which way the hero faces arriving on `arrival` from `from_map`: away
## from the way back (the nearest portal there that leads to `from_map`),
## along the longer of the two ways first, onto open ground; else the way
## they walked in (`facing`), else any way that's open.
static func arrival_facing(map: MapData, arrival: Vector2i, from_map: String, facing: Vector2) -> Vector2:
	var back := NOWHERE
	var best := INF
	for cell: Vector2i in map.portals:
		if String(map.portals[cell].get("mapId", "")) != from_map:
			continue
		var distance := Vector2(cell - arrival).length()
		if distance < best:
			best = distance
			back = cell
	var order: Array[Vector2i] = []
	if back != NOWHERE:
		var away := arrival - back
		var across := Vector2i(signi(away.x), 0)
		var down := Vector2i(0, signi(away.y))
		order.append_array([across, down] if absi(away.x) > absi(away.y) else [down, across])
	order.append(Vector2i(facing))
	order.append_array(STEPS)
	for step: Vector2i in order:
		if step != Vector2i.ZERO and open_ground(map, arrival + step):
			return Vector2(step)
	return facing


## Whether `cell` is a way down from a room (a stairwell that leads
## somewhere): walking onto it, or E facing it, asks first.
static func goes_down(map: MapData, cell: Vector2i) -> bool:
	return map.portals.has(cell) and kind_of(map, cell) == "down"


static var _below := {}


## Where the stairs in a room go down to (PIX-256): the map under `map_id`,
## or "" for a room with none and any other map. Learned once per map.
static func below(map_id: String) -> String:
	if not _below.has(map_id):
		var under := ""
		if PunyInterior.is_room(map_id):
			var room := MapData.load_by_id(map_id)
			for cell: Vector2i in room.portals:
				if goes_down(room, cell):
					under = String(room.portals[cell].get("mapId", ""))
		_below[map_id] = under
	return _below[map_id]


## The question a way down asks (PIX-256), as a conversation with no face:
## {id, name, lines, choices}; the first answer goes down. One page, the
## question on it with its answers: the stairs under a place the story knows
## say what's below before they ask.
static func going_down(map: MapData, cell: Vector2i) -> Dictionary:
	var place := place_of(map.portals.get(cell, {}))
	var line := Text.t("Go down into %s?") % Text.mid(place)
	match map.id:
		"observatory":
			line = Text.t("Liane's stair goes down through the floor, and the cold comes up it like a draught.") + " " + line
		"keep":
			line = Text.t("The keep's stair goes down to the cellars, where something still stands the old watch.") + " " + line
	return {
		"id": "way_down",
		"name": Text.t("The stairs"),
		"lines": [line],
		"choices": [Text.t("Go down"), Text.t("Stay")],
	}


## Where a hero saved at `cell` stands when the save loads (PIX-256): there,
## on open ground; off a doorway onto the open ground beside it (below
## first, the way out of a door), so a save made in the frame of a door that
## now leads somewhere else wakes outside it; else the map's spawn.
static func standing(map: MapData, cell: Vector2i) -> Vector2i:
	if open_ground(map, cell):
		return cell
	if map.portals.has(cell):
		for step: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			if open_ground(map, cell + step):
				return cell + step
	return map.spawn


## Ground the hero can stand on that doesn't take them anywhere.
static func open_ground(map: MapData, cell: Vector2i) -> bool:
	return map.is_walkable(cell) and not map.portals.has(cell)


## The portal cells of one way: `cell` and the portals beside it, side by
## side, that lead to the same place.
static func _opening(map: MapData, cell: Vector2i) -> Array[Vector2i]:
	var target: Dictionary = map.portals[cell]
	var cells: Array[Vector2i] = [cell]
	var queue: Array[Vector2i] = [cell]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_front()
		for step: Vector2i in STEPS:
			var next := here + step
			if next in cells or not map.portals.has(next) or map.portals[next] != target:
				continue
			cells.append(next)
			queue.append(next)
	return cells


## A way's middle: its road cell (the first the map lists), else the middle
## of its cells.
static func _middle(map: MapData, cells: Array[Vector2i]) -> Vector2i:
	for cell: Vector2i in cells:
		if map.tile_at(cell) == "path":
			return cell
	var sorted := cells.duplicate()
	sorted.sort()
	return sorted[sorted.size() >> 1]


## The step that takes the hero through a way: off the map at its edge,
## else from the open ground before it into it (the road's side first, then
## the side facing the middle of the map).
static func _out(map: MapData, way: Dictionary) -> Vector2i:
	var at: Vector2i = way["at"]
	if way["kind"] == "edge":
		if at.x == 0:
			return Vector2i.LEFT
		if at.x == map.size.x - 1:
			return Vector2i.RIGHT
		return Vector2i.UP if at.y == 0 else Vector2i.DOWN
	var middle := Vector2(map.size) / 2.0
	var best := Vector2i.ZERO
	var score := -INF
	for step: Vector2i in STEPS:
		var before := at - step
		if not open_ground(map, before):
			continue
		var value := (10.0 if map.tile_at(before) == "path" else 0.0) + Vector2(-step).dot((middle - Vector2(at)).normalized())
		if value > score:
			score = value
			best = step
	return best if best != Vector2i.ZERO else Vector2i.UP


## A gate with rock on both its sides (the mountain's), not in a rampart.
static func _in_rock(map: MapData, cell: Vector2i) -> bool:
	var rock := func(step: Vector2i) -> bool: return map.tile_at(cell + step) == "mountain"
	return (rock.call(Vector2i.LEFT) and rock.call(Vector2i.RIGHT)) or (rock.call(Vector2i.UP) and rock.call(Vector2i.DOWN))


## The cells of door signs on a map (either house sign): those doors carry
## their own boards.
static func _signed(map_id: String) -> Dictionary:
	var out := {}
	for sign_def: Dictionary in Interactables.signs_on(map_id, false) + Interactables.signs_on(map_id, true):
		out[Vector2i(int(sign_def["x"]), int(sign_def["y"]))] = true
	return out


## Where a way's post stands: the nearest plain ground in from it, beside
## the road (on the right going out, else the left), out of the opening
## itself and past the rock round it, on nothing `avoid` holds. A mouth or a
## door may have it right beside it; an edge's stands in from the edge.
static func _post(map: MapData, way: Dictionary, avoid: Dictionary) -> Vector2i:
	var at: Vector2i = way["at"]
	var inward: Vector2i = -(way["out"] as Vector2i)
	# The right hand going out.
	var side := Vector2i(inward.y, -inward.x)
	var reach := 0
	for cell: Vector2i in way["cells"]:
		var off: Vector2i = cell - at
		reach = maxi(reach, absi(off.x * side.x + off.y * side.y))
	for depth in range(1 if way["kind"] == "edge" else 0, POST_DEPTH + 1):
		for far in range(1, reach + POST_REACH + 1):
			for hand in [1, -1]:
				var cell: Vector2i = at + inward * depth + side * hand * far
				if _post_fits(map, cell, side, reach, avoid):
					return cell
	return NOWHERE


static func _post_fits(map: MapData, cell: Vector2i, side: Vector2i, reach: int, avoid: Dictionary) -> bool:
	if avoid.has(cell) or not open_ground(map, cell) or map.tile_at(cell) not in POST_GROUND:
		return false
	if cell.x <= 0 or cell.y <= 0 or cell.x >= map.size.x - 1 or cell.y >= map.size.y - 1:
		return false
	# Not in the pass itself: rock close on both hands.
	var walled := func(hand: Vector2i) -> bool:
		for far in range(1, reach + 3):
			if not map.is_walkable(cell + hand * far):
				return true
		return false
	return not (walled.call(side) and walled.call(-side))
