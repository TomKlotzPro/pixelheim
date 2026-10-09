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
## patch: Vector2i (the floor's gathering patch, PIX-143)}
static func plan(level: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = level * 7919 + 17
	var encounters: Array = Dungeons.floor_def(level)["encounters"]
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
	map.id = "floor_%d" % level
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
			"lift": int(encounter.get("lift", Dungeons.lift(level))),
			# A Deep Hunt warden's own name (PIX-216).
			"name": String(encounter.get("name", "")),
		})
	# A patch of something worth picking in the first hall, clear of its foe.
	var hall := rooms[1]
	var open: Array[Vector2i] = []
	for cy in range(hall.position.y + 1, hall.end.y - 1):
		for cx in range(hall.position.x + 1, hall.end.x - 1):
			var cell := Vector2i(cx, cy)
			if map.grid[cell] == "floor" and cell.distance_to(foes[0]["cell"]) >= 2.5:
				open.append(cell)
	var patch: Vector2i = open[rng.randi() % open.size()] if not open.is_empty() else map.spawn
	return {"map": map, "foes": foes, "rooms": rooms, "stairs": stairs, "patch": patch}


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
