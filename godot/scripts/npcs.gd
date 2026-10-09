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
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/npcs.json")))
	return _doc


## Who is on a map right now (npcsOn): townsfolk the town has grown enough
## for, and recruits where they wait — or at home in town once settled.
## While a keeper's building is still rubble (PIX-146, `done` the projects
## built; null skips it), they trade from a stall on the town square; in the
## Ashes the elder and the mayor say their Ashes lines.
static func on_map(map_id: String, town_tier: int, settlers: Array, done: Variant = null, gate_open := true) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc: Dictionary in _data()["npcs"]:
		var stall: Dictionary = npc.get("stall", {})
		if done != null and not stall.is_empty() and stall["project"] not in done:
			if map_id == "town":
				var at_stall := npc.duplicate()
				at_stall.merge({"mapId": "town", "x": stall["x"], "y": stall["y"], "wander": false}, true)
				out.append(at_stall)
			continue
		if npc["mapId"] == map_id and int(npc.get("minTownTier", 1)) <= town_tier:
			if town_tier == 0 and npc.has("ashesLines"):
				npc = npc.duplicate()
				npc["lines"] = npc["ashesLines"]
			elif not gate_open and npc.has("gateLines"):
				# Maren keeps the barred gate's lines till it opens (PIX-204).
				npc = npc.duplicate()
				npc["lines"] = npc["gateLines"]
			elif npc.has("linesByTier"):
				npc = npc.duplicate()
				npc["lines"] = lines_for_tier(npc["linesByTier"], town_tier, npc["lines"])
			out.append(npc)
	for recruit: Dictionary in _data()["recruits"]:
		var npc := as_npc(recruit, recruit["id"] in settlers, town_tier)
		if npc["mapId"] == map_id:
			out.append(npc)
	# Builders at the village's construction sites (PIX-147).
	if done != null and map_id == "town":
		out.append_array(Town.site_workers(done))
	return out


## What a villager says about the hero's latest deed (PIX-149), or "": only
## the town's own folk (not keepers, builders or animals) gossip, each
## picking one of the deed's lines by who they are.
static func reaction(npc: Dictionary, deed: Dictionary) -> String:
	if deed.is_empty() or npc.get("mapId", "") != "town" or npc.has("stall"):
		return ""
	var id: String = npc["id"]
	if id.begins_with("worker_") or id.begins_with("town_") or id in ["elder", "mayor"]:
		return ""
	var lines: Array = _data()["reactions"].get(deed["kind"], [])
	if lines.is_empty():
		return ""
	var line: String = lines[id_hash(id) % lines.size()]
	for key: String in deed:
		line = line.replace("{%s}" % key, str(deed[key]))
	return line


## The lines for the town's age (PIX-148): the latest age's at or below it,
## else `fallback`.
static func lines_for_tier(by_tier: Dictionary, town_tier: int, fallback: Array) -> Array:
	var best := -1
	for key: String in by_tier:
		if int(key) <= town_tier and int(key) > best:
			best = int(key)
	return by_tier[str(best)] if best >= 0 else fallback


## A recruit as a walking villager: where they wait, or where they live once
## settled (recruitNpc), saying what the town's age has them say.
## Faces (PIX-206): Shade drew fewer people than Pixelheim has, so those
## who share a sheet wear different tints, and no two on the same map look
## alike. A person keeps one tint everywhere: the first that no one sharing
## their sheet and one of their maps already wears, in the data's order.
const FACE_TINTS: Array[Color] = [
	Color.WHITE, Color(1.0, 0.8, 0.76), Color(0.78, 0.86, 1.0),
	Color(0.84, 1.0, 0.78), Color(1.0, 0.93, 0.68), Color(0.9, 0.8, 1.0),
]
static var _faces := {}


## The tint a person wears (white for anyone not in the data).
static func tint_of(person_id: String) -> Color:
	if _faces.is_empty():
		_faces = face_indexes()
	return FACE_TINTS[mini(int(_faces.get(person_id, 0)), FACE_TINTS.size() - 1)]


## Everyone with a face: their sheet (and size), and the maps they can stand
## on - their own, the square while their trade has no roof, and for a
## settler where they were found and the town.
static func people() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc: Dictionary in _data()["npcs"]:
		var maps: Array = [npc["mapId"]]
		if npc.has("stall"):
			maps.append("town")
		out.append({"id": npc["id"], "look": _look(npc["sprite"]), "maps": maps})
	for recruit: Dictionary in _data()["recruits"]:
		out.append({"id": recruit["id"], "look": _look(recruit["sprite"]), "maps": [recruit["found"]["mapId"], "town"]})
	var barker: Dictionary = _data()["festivalBarker"]
	out.append({"id": barker["id"], "look": _look(barker["sprite"]), "maps": ["town"]})
	return out


static func _look(sprite: String) -> String:
	var art := PunyArt.villager(sprite)
	return "%s@%s" % [art["sheet"], art.get("scale", 1.0)]


## Each person's tint index, by the rule above.
static func face_indexes() -> Dictionary:
	var everyone := people()
	var out := {}
	for i in everyone.size():
		var taken := {}
		for j in i:
			if everyone[j]["look"] == everyone[i]["look"] and everyone[j]["maps"].any(func(map_id: String) -> bool: return map_id in everyone[i]["maps"]):
				taken[out[everyone[j]["id"]]] = true
		var pick := 0
		while taken.has(pick):
			pick += 1
		out[everyone[i]["id"]] = pick
	return out


static func as_npc(recruit: Dictionary, settled: bool, town_tier := 1) -> Dictionary:
	var spot: Dictionary = recruit["home"] if settled else recruit["found"]
	return {
		"id": recruit["id"],
		"mapId": "town" if settled else spot["mapId"],
		"x": spot["x"],
		"y": spot["y"],
		"sprite": recruit["sprite"],
		"name": recruit["name"],
		"lines": lines_for_tier(recruit.get("townLinesByTier", {}), town_tier, recruit["townLines"]) if settled else recruit["meetLines"],
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
