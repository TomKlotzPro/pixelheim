class_name Npcs
## Villagers exported from the web game (assets/data/npcs.json): the fixed
## townsfolk, tier-gated settlers included, and the recruits who wait in the
## wilds until they move to town. Pure rules ported from src/world/npcs.ts —
## who stands on which map, where a wanderer paces, who is beside the hero —
## so the scene code only draws and moves them.

## The pacing loop, clockwise around home (LOOP in npcs.ts).
const LOOP: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]
## Up, down, left, right: the order npcBeside tries after the faced side.
const SIDES: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/npcs.json"))
	return _doc


## Who is on a map right now (npcsOn): townsfolk the town has grown enough
## for, and recruits where they wait — or at home in town once settled.
static func on_map(map_id: String, town_tier: int, settlers: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc: Dictionary in _data()["npcs"]:
		if npc["mapId"] == map_id and int(npc.get("minTownTier", 1)) <= town_tier:
			out.append(npc)
	for recruit: Dictionary in _data()["recruits"]:
		var npc := as_npc(recruit, recruit["id"] in settlers)
		if npc["mapId"] == map_id:
			out.append(npc)
	return out


## A recruit as a walking villager: where they wait, or where they live once
## settled (recruitNpc).
static func as_npc(recruit: Dictionary, settled: bool) -> Dictionary:
	var spot: Dictionary = recruit["home"] if settled else recruit["found"]
	return {
		"id": recruit["id"],
		"mapId": "town" if settled else spot["mapId"],
		"x": spot["x"],
		"y": spot["y"],
		"sprite": recruit["sprite"],
		"name": recruit["name"],
		"lines": recruit["townLines"] if settled else recruit["meetLines"],
		"wander": spot["wander"],
	}


## Any speaking villager by id, recruits included (npcById); {} if unknown.
static func by_id(id: String, settlers: Array) -> Dictionary:
	for npc: Dictionary in _data()["npcs"]:
		if npc["id"] == id:
			return npc
	for recruit: Dictionary in _data()["recruits"]:
		if recruit["id"] == id:
			return as_npc(recruit, id in settlers)
	return {}


## Pacing offsets that are walkable and portal-free on the villager's map,
## computed on demand because homes move as the town grows (offsetsFor).
static func offsets_for(npc: Dictionary, map: MapData) -> Array[Vector2i]:
	var home := Vector2i(npc["x"], npc["y"])
	var out: Array[Vector2i] = []
	for offset in LOOP:
		if map.is_walkable(home + offset) and not map.portals.has(home + offset):
			out.append(offset)
	if out.is_empty():
		out.append(Vector2i.ZERO)
	return out


static func id_hash(id: String) -> int:
	var value := 0
	for code in id.to_utf8_buffer():
		value = (value * 31 + code) % 997
	return value


## Where a wanderer stands at `beat` (npcPosition): one pace every four beats,
## phase-shifted per villager so the village never marches in step. The web
## counts beats in hero steps; real-time Godot counts them on a clock.
static func pace_offset(npc: Dictionary, offsets: Array[Vector2i], beat: int) -> Vector2i:
	if not npc["wander"]:
		return Vector2i.ZERO
	return offsets[floori((beat + id_hash(npc["id"])) / 4.0) % offsets.size()]


## The villager beside `cell` (npcBeside): the faced side wins, any other
## side follows. `occupied` maps cell -> villager. Returns {npc, side} or {}.
static func beside(occupied: Dictionary, cell: Vector2i, facing: Vector2i) -> Dictionary:
	var order: Array[Vector2i] = [facing]
	for side in SIDES:
		if side != facing:
			order.append(side)
	for side in order:
		if occupied.has(cell + side):
			return {"npc": occupied[cell + side], "side": side}
	return {}
