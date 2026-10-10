class_name Ways
## The ways between maps (PIX-269: "it isn't clear where to walk to go on").
## Every portal that takes the hero to another map or a dungeon, read as one
## way on: an opening at the map's edge (its portal cells side by side), a
## cave mouth, a gate set in the rock or a rampart, a door, the stairs up out
## of a cave. Each knows the step that takes the hero through it and the
## cell they come at it from.
## A way on is the land itself (Tom, 2026-10-10: "I still don't like the
## door between maps"): the cliffs part and the road runs out through them,
## a cave is a dark mouth in the rock. No signpost names it and no frame or
## torch marks it; the place's name shows once the hero is there
## (PlaceTitle). The one thing drawn on a way is the Ashen Mountain's gate,
## its portcullis down while the story bars it.
## A house in the Reach opens onto a room, and the dungeon is down in its
## cellar (PIX-256: "strange to walk into a house and find a dungeon"): a
## stairwell in the room's floor is a way "down", which asks before it takes
## the hero (going_down), its question naming where it goes.
## Pure: MapView draws the gate in the rock; the world turns the hero on
## arrival to face into the new map (arrival_facing).

const NOWHERE := Vector2i(-1, -1)
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
## A gate set in the rock (the Ashen Mountain's): Shade's castle gate, its
## portcullis down while the gate is barred - a story gate the player must
## read as shut, so it stays built where every other way is bare ground.
const ROCK_GATE := 802
const ROCK_GATE_BARRED := 803


## Every way on from `map`, in the map's own order (its portals list a way's
## road cell first): [{"cells": [Vector2i], "at": Vector2i, "kind": "edge" |
## "cave" | "gate" | "door" | "stairs" | "down" (a room's stair), "rock":
## bool (a gate in the rock), "out": Vector2i (the step through), "from":
## Vector2i (the cell the hero comes at it from), "to": the portal's
## target}]. Dungeon floors have none.
static func on(map: MapData) -> Array[Dictionary]:
	var ways: Array[Dictionary] = []
	if map.floor_level > 0:
		return ways
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
		ways.append(way)
	return ways


## A room or a hut: four walls round a floor, its door the one way out.
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
## (the waypoints' list names places the same way), a dungeon's name - what
## a stair's question asks about.
static func place_of(target: Dictionary) -> String:
	match String(target.get("kind", "")):
		"map":
			return Catalog.place_name(String(target["mapId"]))
		"dungeon":
			return String(Dungeons.dungeon(String(target["dungeon"])).get("name", String(target["dungeon"]).capitalize()))
	return ""


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


## How far under the ground a map lies: 0 under the sky or in a room, 1 in
## a cave or a cellar, deeper on a dungeon's floors, one step a floor - a
## region dungeon's too (PIX-255: the sea cave's grotto lies 3 down).
static func depth(map: MapData) -> int:
	if map.floor_level > 0:
		return 1 + map.floor_level
	if Depths.number(map.id) > 0:
		return Depths.number(map.id)
	return 1 if map.style == "cave" else 0


## Whether the way from `from` to `to` goes down under the ground (into a
## cave, a cellar, a dungeon's floor or the next one down): the change of
## scene keeps a brief dark there, the mood of going under (One Reach,
## PIX-269). Every other way, and every way back up, dissolves.
static func goes_under(from: MapData, to: MapData) -> bool:
	return depth(to) > depth(from)


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


## How far from where a save stood the hero may wake when that ground is
## gone.
const NEARBY := 6


## Where a hero saved at `cell` stands when the save loads (PIX-256): there,
## on open ground; off a doorway onto the open ground beside it (below
## first, the way out of a door), so a save made in the frame of a door that
## now leads somewhere else wakes outside it; on the nearest open ground
## within NEARBY that the map's way in reaches, where the ground is rock or
## wood now (One Reach, PIX-269: the roads out of four regions moved along
## their edges, and the cliff closed over the old ones); else the map's
## spawn. The save's format is the same (web v4): only where it wakes moves.
static func standing(map: MapData, cell: Vector2i) -> Vector2i:
	if open_ground(map, cell):
		return cell
	if map.portals.has(cell):
		for step: Vector2i in [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT]:
			if open_ground(map, cell + step):
				return cell + step
	var reached := {}
	for radius in range(1, NEARBY + 1):
		var best := NOWHERE
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var near := cell + Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius or not open_ground(map, near):
					continue
				if best == NOWHERE or Vector2(near - cell).length() < Vector2(best - cell).length():
					if reached.is_empty():
						reached = _walked_from(map, map.spawn)
					if reached.has(near):
						best = near
		if best != NOWHERE:
			return best
	return map.spawn


## Every cell a walk from `from` reaches without being taken anywhere.
static func _walked_from(map: MapData, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		for step: Vector2i in STEPS:
			var next := here + step
			if not seen.has(next) and open_ground(map, next):
				seen[next] = true
				queue.append(next)
	return seen


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
