class_name DungeonFloor
## A dungeon floor to walk (PIX-126). The web fights a floor's encounters as
## a run of turn-based battles; here each encounter waits in its own room,
## one foe per encounter as on the web, the floor's guardian in the last and
## largest, along a winding chain of halls from the stairs back up. The plan
## grows from the floor number, so a floor is the same every visit.
##
## Floors are built from our own tile ids, so walking and collision work as
## on any map: floor, wall, barrel, crate (a pot), lamp (a torch block) and
## cave (the stairs out, a portal back to the gate).
##
## Since PIX-255 the same rooms and halls lay a region dungeon's planned
## floors too (Depths: the sea cave's drowned galleries): `lay` takes the
## seed and the encounters, and a floor of a region (`region`) becomes a
## cave of it - a pack where each foe stood, its ground the region's, a
## stair down in the last room and its set piece there. The Undermountain's
## levels lay exactly as before (test_depths pins them).

const ENTRANCE := Vector2i(6, 5)
const ROOM_MIN := Vector2i(8, 6)
const ROOM_MAX := Vector2i(11, 8)
const GUARDIAN_ROOM := Vector2i(13, 9)
const HALL := 2
const HALL_MIN := 3
const HALL_MAX := 6
const MARGIN := 2
## How far a room may sit above or below its neighbour.
const STAGGER := 5


## {map: MapData, foes: [{id, elite, cell}], rooms: [Rect2i], stairs: Vector2i,
## patch_ground: [Vector2i] (where the floor's gathering patch may grow,
## PIX-143; Gathering.floor_patch picks the day's, PIX-250)}
static func plan(level: int) -> Dictionary:
	return lay({"seed": level * 7919 + 17, "level": level, "encounters": Dungeons.floor_def(level)["encounters"]})


## A floor laid out from `spec`: rooms from its `seed`, one per encounter
## after the entrance ({monsterId, elite, lift, name, size}), the last and
## largest for the last one; `level` the Undermountain's level (0 for a
## region's floor), `id` the map's id, `lift` how far its foes stand above
## their kind (else the level's). With a `region` it is that region's
## cave (_regional): its plan adds {spawns, down, find, piece_cells}.
static func lay(spec: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec["seed"])
	var encounters: Array = spec["encounters"]
	var level := int(spec.get("level", 0))
	var rooms: Array[Rect2i] = []
	var x := MARGIN
	var y := MARGIN + STAGGER
	for i in encounters.size() + 1:
		var size := ENTRANCE
		if i == encounters.size():
			size = GUARDIAN_ROOM
		elif i > 0:
			size = Vector2i(rng.randi_range(ROOM_MIN.x, ROOM_MAX.x), rng.randi_range(ROOM_MIN.y, ROOM_MAX.y))
		if i > 0:
			y = clampi(y + rng.randi_range(-STAGGER, STAGGER), MARGIN, MARGIN + 2 * STAGGER)
		rooms.append(Rect2i(Vector2i(x, y), size))
		x += size.x + rng.randi_range(HALL_MIN, HALL_MAX)
	var map := MapData.new()
	map.floor_level = level
	map.id = String(spec.get("id", "floor_%d" % level))
	var far := Vector2i.ZERO
	for room in rooms:
		far = Vector2i(maxi(far.x, room.end.x), maxi(far.y, room.end.y))
	map.size = far + Vector2i(MARGIN, MARGIN)
	for cy in map.size.y:
		for cx in map.size.x:
			map.grid[Vector2i(cx, cy)] = "wall"
	for room in rooms:
		_carve(map, room)
	var openings: Array[Vector2i] = []
	for i in rooms.size() - 1:
		openings.append_array(_hall(map, rooms[i], rooms[i + 1], rng))
	# The stairs back up stand against the entrance room's west wall.
	var first := rooms[0]
	var stairs := Vector2i(first.position.x, first.position.y + first.size.y / 2)
	map.grid[stairs] = "cave"
	map.portals[stairs] = {"kind": "gate"}
	map.spawn = stairs + Vector2i.RIGHT
	for i in rooms.size():
		_furnish(map, rooms[i], openings + [stairs, map.spawn], rng)
	var foes: Array[Dictionary] = []
	for i in encounters.size():
		var room := rooms[i + 1]
		var encounter: Dictionary = encounters[i]
		foes.append({
			"id": encounter["monsterId"],
			"elite": encounter.get("elite", false),
			"cell": room.position + room.size / 2,
			# The floor's lift, or the Deep Hunt's own per foe (PIX-161).
			"lift": int(encounter.get("lift", spec["lift"] if spec.has("lift") else Dungeons.lift(level))),
			# A Deep Hunt warden's own name (PIX-216).
			"name": String(encounter.get("name", "")),
		})
	# A patch of something worth picking in the first hall, clear of its foe:
	# where it may grow (each day picks one, PIX-250).
	var hall := rooms[1]
	var open: Array[Vector2i] = []
	for cy in range(hall.position.y + 1, hall.end.y - 1):
		for cx in range(hall.position.x + 1, hall.end.x - 1):
			var cell := Vector2i(cx, cy)
			if map.grid[cell] == "floor" and cell.distance_to(foes[0]["cell"]) >= 2.5:
				open.append(cell)
	if open.is_empty():
		open.append(map.spawn)
	var laid := {"map": map, "foes": foes, "rooms": rooms, "stairs": stairs, "patch_ground": open}
	if spec.has("region"):
		_regional(laid, spec)
	return laid


const NOWHERE := Vector2i(-1, -1)


## A region's floor (PIX-255): a cave of the region (`region`, its ground
## for packs, patches and loot), each foe now a pack at home where it stood
## (`size` of them, spawns with ids of the map's, none within `clear` cells
## of where a hero comes in), a stair down in the middle of the last room's
## east side when `down`, and the `setPiece` ({rows}: see depths.json) in
## the last room's lower half with a free ring round it, so it never closes
## a way. Adds {spawns, down, landing (the cell beside the stair down that a
## hero coming up lands on), find (the set piece's chest cell), piece_cells}.
static func _regional(laid: Dictionary, spec: Dictionary) -> void:
	var map: MapData = laid["map"]
	var rooms: Array[Rect2i] = laid["rooms"]
	map.style = "cave"
	var last := rooms[-1]
	var down := NOWHERE
	if spec.get("down", false):
		down = Vector2i(last.end.x - 1, last.position.y + last.size.y / 2)
		map.grid[down] = "stairwell"
	var placed := {"find": NOWHERE, "cells": [] as Array[Vector2i], "box": Rect2i(NOWHERE, Vector2i.ZERO)}
	if spec.has("setPiece"):
		placed = _set_piece(map, last, spec["setPiece"])
	for cell: Vector2i in map.grid:
		if map.grid[cell] == "floor" and cell != placed["find"]:
			map.regions[cell] = String(spec["region"])
	var encounters: Array = spec["encounters"]
	var spawns: Array[Dictionary] = []
	var keep_off: Rect2i = (placed["box"] as Rect2i).grow(1)
	# No pack waits where a hero comes in (Packs' safeTiles, `clear`): the
	# stairs both ways and the cells they land on.
	var arrivals: Array[Vector2i] = [laid["stairs"], map.spawn]
	if down != NOWHERE:
		arrivals.append_array([down, down + Vector2i.LEFT])
	for i in laid["foes"].size():
		var foe: Dictionary = laid["foes"][i]
		var home := _open_near(map, foe["cell"], rooms[i + 1], keep_off, arrivals, int(spec.get("clear", 0)))
		foe["cell"] = home
		spawns.append({
			"id": "%s_%d" % [map.id, i + 1], "mapId": map.id, "x": home.x, "y": home.y,
			"species": foe["id"], "size": int(encounters[i].get("size", 3)),
		})
	laid["spawns"] = spawns
	laid["down"] = down
	laid["landing"] = down + Vector2i.LEFT if down != NOWHERE else NOWHERE
	laid["find"] = placed["find"]
	laid["piece_cells"] = placed["cells"]


## The set piece's rows laid in `room`'s lower half, centred, a row of
## floor all round it, clear of the room's torches and barrels (its top and
## bottom rows): `=` a hull beam (or a rail), `|` a mast, `w` a wheel, `r`
## a fallen rock and `l` a lever (the shafts' canary, PIX-255), drawn on the
## dungeon sheet over a blocking "wreck" cell; `o` a barrel, `p` a pot; `s`
## a stone knight and `#` an iron grille (the Greyhold crypt's); `c` the
## floor's find, a chest's cell; `.` floor. {find, cells (what blocks: the
## set piece's words go with them), box}.
static func _set_piece(map: MapData, room: Rect2i, piece: Dictionary) -> Dictionary:
	var rows: Array = piece["rows"]
	var size := Vector2i(String(rows[0]).length(), rows.size())
	var at := Vector2i(room.position.x + (room.size.x - size.x) / 2, room.end.y - 2 - size.y)
	var cells: Array[Vector2i] = []
	var find := NOWHERE
	for y in size.y:
		var row := String(rows[y])
		for x in size.x:
			var cell := at + Vector2i(x, y)
			var tile := "wreck"
			match row[x]:
				"=":
					# A beam is two cells long: its left half, then its right.
					var run := 0
					while x - run - 1 >= 0 and row[x - run - 1] == "=":
						run += 1
					var beam: Array = PunyDungeon.BEAMS[absi(cell.y + x - run) % PunyDungeon.BEAMS.size()]
					map.pieces[cell] = beam[run % 2]
				"|":
					map.pieces[cell] = PunyDungeon.MAST
				"w":
					map.pieces[cell] = PunyDungeon.WHEEL
				"r":
					map.pieces[cell] = PunyDungeon.BOULDERS[absi(hash(cell)) % PunyDungeon.BOULDERS.size()]
				"l":
					map.pieces[cell] = PunyDungeon.LEVER
				"o":
					tile = "barrel"
				"p":
					tile = "crate"
				"s":
					tile = "statue"
				"#":
					tile = "grille"
				"c":
					tile = "floor"
					find = cell
				_:
					tile = "floor"
			map.grid[cell] = tile
			if tile != "floor":
				cells.append(cell)
	return {"find": find, "cells": cells, "box": Rect2i(at, size)}


## The open floor cell of `room` nearest `cell` (itself when open), outside
## `keep_off` and `apart` cells or more (across or down, whichever is more)
## from each of `arrivals`: where a pack makes its home.
static func _open_near(map: MapData, cell: Vector2i, room: Rect2i, keep_off: Rect2i, arrivals: Array[Vector2i], apart: int) -> Vector2i:
	var best := cell
	var nearest := INF
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var at := Vector2i(x, y)
			if map.grid.get(at, "") != "floor" or keep_off.has_point(at):
				continue
			if arrivals.any(func(arrival: Vector2i) -> bool: return maxi(absi(arrival.x - at.x), absi(arrival.y - at.y)) < apart):
				continue
			var distance := float((at - cell).length_squared())
			if distance < nearest:
				nearest = distance
				best = at
	return best


static func _carve(map: MapData, rect: Rect2i) -> void:
	for cy in range(rect.position.y, rect.end.y):
		for cx in range(rect.position.x, rect.end.x):
			map.grid[Vector2i(cx, cy)] = "floor"


## A hall two cells wide from one room's east wall to the next room's west
## wall, turning once in the gap when the rooms don't line up. Returns the
## room cells it opens onto (kept clear of furniture).
static func _hall(map: MapData, from: Rect2i, to: Rect2i, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var leave := rng.randi_range(from.position.y + 1, from.end.y - HALL - 1)
	var arrive := rng.randi_range(to.position.y + 1, to.end.y - HALL - 1)
	var turn := (from.end.x + to.position.x) / 2
	_carve(map, Rect2i(from.end.x, leave, turn - from.end.x + HALL, HALL))
	_carve(map, Rect2i(turn, mini(leave, arrive), HALL, absi(arrive - leave) + HALL))
	_carve(map, Rect2i(turn, arrive, to.position.x - turn, HALL))
	var openings: Array[Vector2i] = []
	for i in HALL:
		openings.append(Vector2i(from.end.x - 1, leave + i))
		openings.append(Vector2i(to.position.x, arrive + i))
	return openings


## Torch blocks in the north corners, barrels and a pot by the south wall,
## never in a doorway's way.
static func _furnish(map: MapData, room: Rect2i, keep_clear: Array, rng: RandomNumberGenerator) -> void:
	var spots := [
		[Vector2i(room.position.x + 1, room.position.y), "lamp"],
		[Vector2i(room.end.x - 2, room.position.y), "lamp"],
		[Vector2i(room.position.x, room.end.y - 1), "barrel"],
		[Vector2i(room.end.x - 1, room.end.y - 1), "crate" if rng.randf() < 0.5 else "barrel"],
		[Vector2i(room.position.x + 1, room.end.y - 1), "barrel"],
	]
	for spot: Array in spots:
		var cell: Vector2i = spot[0]
		var crowded := false
		for other: Vector2i in keep_clear:
			if absi(other.x - cell.x) <= 1 and absi(other.y - cell.y) <= 1:
				crowded = true
		if not crowded and (spot[1] == "lamp" or rng.randf() < 0.6):
			map.grid[cell] = spot[1]
