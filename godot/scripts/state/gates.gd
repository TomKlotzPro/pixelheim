class_name Gates
## The gates (PIX-254, the main story v2's step 3; Tom: « bloquer des
## passages dans une autre zone tant qu'on n'a pas fait certaines choses »).
## Each region's way in from the Reach stays shut until the story reaches
## it, in the story's order: a rockfall on the cliff road to Saltmere until
## Maren's letters are out, the river bridge burnt until it's mended at the
## board (Old Wenna sends the rope), Ulla's barricade on the Greyhold road
## until Blackiron's ingot is won, an avalanche on the Frostgate road until
## Greyhold's captain stands down. The Deepwood and the Mirefen stay open,
## and the mountain's gate is Relics'.
## A gate is data (assets/data/gates.json): the cells something drawn blocks
## (MapView draws its `look`, GateArt), what opens it and the line it says
## while it's shut - walking up to it, in the journal, and as the arrow's
## words, the arrow leading to what opens it instead of to the closed road
## (detour). A hero already past a gate is never shut out of what they've
## earned: an old save finds it open when the ground past it was seen, a
## letter delivered or a keepsake won past it, a named monster slain there,
## or the hero is past a later gate or the mountain's own (its floors
## cleared) - all read from what the save already holds (web v4, no field
## added). Pure.

const NOWHERE := Vector2i(-1, -1)
const STEPS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static var _doc := {}
## Gate id -> what lies past it (beyond), worked out once from the maps.
static var _past := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/gates.json")))
	return _doc


## Every gate, in the story's order.
static func all() -> Array:
	return _data()["gates"]


static func by_id(gate_id: String) -> Dictionary:
	for gate: Dictionary in all():
		if gate["id"] == gate_id:
			return gate
	return {}


## The gates standing on `map_id`.
static func on(map_id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for gate: Dictionary in all():
		if gate["mapId"] == map_id:
			out.append(gate)
	return out


## The cells a gate blocks while it's shut.
static func cells_of(gate: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell: Array in gate["cells"]:
		out.append(Vector2i(int(cell[0]), int(cell[1])))
	return out


## Whether a gate stands open for this hero: what opens it is done, or the
## hero is already past it. The gates follow the story, so a hero past a
## later one is past this one too - and past them all once past the
## mountain's own gate (Relics.gate_open: its relics home, or any of its
## floors cleared, as the late web hero who beat Morvax has) or into the
## Deep Hunt.
static func is_open(gate: Dictionary, progression: ProgressionState, settlement: SettlementState, discovered: Dictionary) -> bool:
	if Relics.gate_open(progression) or progression.deepest > 0:
		return true
	var later := false
	for each: Dictionary in all():
		later = later or each["id"] == gate["id"]
		if later and (opened(each, progression, settlement) or passed(each, progression, discovered)):
			return true
	return false


## Whether everything that opens a gate is done, in the story.
static func opened(gate: Dictionary, progression: ProgressionState, settlement: SettlementState) -> bool:
	return _waiting_on(gate, progression, settlement).is_empty()


## The gates on `map_id` still shut for this hero.
static func closed_on(map_id: String, progression: ProgressionState, settlement: SettlementState, discovered: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for gate: Dictionary in on(map_id):
		if not is_open(gate, progression, settlement, discovered):
			out.append(gate)
	return out


## What a shut gate says: the line of the first thing that opens it not done
## yet (the last one's once all are).
static func line(gate: Dictionary, progression: ProgressionState, settlement: SettlementState) -> String:
	var need := _waiting_on(gate, progression, settlement)
	if need.is_empty():
		need = gate["opens"][-1]
	return String(need["line"])


## What it's called on the map, where it stands.
static func mark(gate: Dictionary) -> String:
	return String(gate["mark"])


## The cell a gate's name and mark stand on: the middle of its cells.
static func middle(gate: Dictionary) -> Vector2i:
	var cells := cells_of(gate)
	var low := cells[0]
	var high := cells[0]
	for cell: Vector2i in cells:
		low = Vector2i(mini(low.x, cell.x), mini(low.y, cell.y))
		high = Vector2i(maxi(high.x, cell.x), maxi(high.y, cell.y))
	return (low + high) / 2


## The first of what opens a gate that isn't done, {} once all are: a main
## quest step (`step`) or a step's kind of condition (`when`).
static func _waiting_on(gate: Dictionary, progression: ProgressionState, settlement: SettlementState) -> Dictionary:
	for need: Dictionary in gate["opens"]:
		if not MainQuest.is_met(_as_step(need), progression, settlement):
			return need
	return {}


## One of what opens a gate as a main quest step, for MainQuest and Bearing:
## the story's own step, or one made of its condition and its line.
static func _as_step(need: Dictionary) -> Dictionary:
	if need.has("step"):
		return MainQuest.step(String(need["step"]))
	return {"id": "", "text": String(need["line"]), "when": need["when"], "chapter": ""}


## Whether the hero is already past a gate, by what the save holds (old
## saves, from before the gates): any of the maps past it set foot on, the
## ground past it seen (not merely glimpsed from the near side), a letter
## delivered or its keepsake won there, or a named monster slain there.
static func passed(gate: Dictionary, progression: ProgressionState, discovered: Dictionary) -> bool:
	var past := beyond(gate)
	for map_id: String in past["maps"]:
		if not (discovered.get(map_id, {}) as Dictionary).is_empty():
			return true
	if _seen_past(gate, discovered.get(gate["mapId"], {})):
		return true
	for quest: Dictionary in Letters.all():
		var to := Npcs.by_id(String(quest["objective"]["to"]), [])
		if past["maps"].has(String(to.get("mapId", ""))) and Letters.delivered(quest, progression):
			return true
	for named_id: String in progression.hunted:
		var named := Hunts.named(named_id)
		var lair_map := String(named.get("mapId", ""))
		if past["maps"].has(lair_map):
			return true
		if lair_map == gate["mapId"] and named.has("lair") and past["cells"].has(Hunts.lair(named)):
			return true
	return false


## Gate id -> the last fog of war read for it: {seen (that very map's
## dictionary), size, past}. What's seen only grows, so the same dictionary
## at the same size is the same answer: the arrow asks twice a second.
static var _seen_cache := {}


## Whether any of the ground deep past a gate is in `seen` (the gate map's
## fog of war).
static func _seen_past(gate: Dictionary, seen: Dictionary) -> bool:
	var cached: Dictionary = _seen_cache.get(gate["id"], {})
	if not cached.is_empty() and is_same(cached["seen"], seen) and int(cached["size"]) == seen.size():
		return cached["past"]
	var deep: Dictionary = beyond(gate)["deep"]
	# The smaller of the two read through, looked up in the other.
	var fewer := seen.size() < deep.size()
	var read: Dictionary = seen if fewer else deep
	var other: Dictionary = deep if fewer else seen
	var past := false
	for cell: Vector2i in read:
		if other.has(cell):
			past = true
			break
	_seen_cache[gate["id"]] = {"seen": seen, "size": seen.size(), "past": past}
	return past


## What lies past a gate, worked out once from the maps: {cells: the gate's
## map's cells a walk from its spawn reaches only through it, deep: those
## of them no one standing on the near side can see (Discovery's sight),
## maps: every map a way out of those cells leads to, and the maps behind
## those (a region, its rooms and caves), dungeons: whether a dungeon's gate
## stands there}.
static func beyond(gate: Dictionary) -> Dictionary:
	var gate_id := String(gate["id"])
	if _past.has(gate_id):
		return _past[gate_id]
	var map := MapData.load_by_id(String(gate["mapId"]))
	var shut := {}
	for cell: Vector2i in cells_of(gate):
		shut[cell] = true
	var near := walk(map, map.spawn, shut)
	var cells := {}
	for cell: Vector2i in walk(map, map.spawn, {}):
		if not near.has(cell) and not shut.has(cell):
			cells[cell] = true
	var reach := Discovery.SIGHT_RADIUS
	var deep := {}
	for cell: Vector2i in cells:
		var glimpsed := false
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				if near.has(cell + Vector2i(dx, dy)):
					glimpsed = true
		if not glimpsed:
			deep[cell] = true
	var near_maps := _maps_through(map, near)
	var maps := {}
	var dungeons := false
	var past_maps := _maps_through(map, cells)
	for map_id: String in past_maps:
		if map_id == "#dungeon":
			dungeons = true
		elif not near_maps.has(map_id):
			maps[map_id] = true
	var past := {"cells": cells, "deep": deep, "maps": maps, "dungeons": dungeons}
	_past[gate_id] = past
	return past


## The maps the ways out of `cells` of `map` lead to, and every map behind
## those but `map` itself: map id -> true ("#dungeon" for a dungeon's gate).
static func _maps_through(map: MapData, cells: Dictionary) -> Dictionary:
	var found := {}
	var queue: Array[String] = []
	for cell: Vector2i in map.portals:
		if cells.has(cell):
			_note_way(map.portals[cell], map.id, found, queue)
	while not queue.is_empty():
		var next := MapData.load_by_id(queue.pop_front())
		for cell: Vector2i in next.portals:
			_note_way(next.portals[cell], map.id, found, queue)
	return found


static func _note_way(target: Dictionary, home: String, found: Dictionary, queue: Array[String]) -> void:
	match String(target.get("kind", "")):
		"dungeon":
			found["#dungeon"] = true
		"map":
			var map_id := String(target["mapId"])
			if map_id != home and not found.has(map_id):
				found[map_id] = true
				queue.append(map_id)


## Every cell a walk on `map` from `from` reaches, never onto `shut` cells
## and never on through a way out (its cell is reached, not walked past).
static func walk(map: MapData, from: Vector2i, shut: Dictionary) -> Dictionary:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var here: Vector2i = queue.pop_back()
		if map.portals.has(here) and here != from:
			continue
		for step: Vector2i in STEPS:
			var next := here + step
			if not seen.has(next) and not shut.has(next) and map.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return seen


## Whether a gate stands between the Reach and `cell` of `map_id`: a map
## past it, or its own map's ground past it.
static func stands_before(gate: Dictionary, map_id: String, cell: Vector2i) -> bool:
	var past := beyond(gate)
	if past["maps"].has(map_id):
		return true
	return map_id == gate["mapId"] and past["cells"].has(cell)


## The first gate still shut between the Reach and `cell` of `map_id`, in
## the story's order; {} when the way is open.
static func in_the_way(map_id: String, cell: Vector2i, progression: ProgressionState, settlement: SettlementState, discovered: Dictionary) -> Dictionary:
	for gate: Dictionary in all():
		if stands_before(gate, map_id, cell) and not is_open(gate, progression, settlement, discovered):
			return gate
	return {}


## A lead (Bearing's) whose place lies past a shut gate, sent to what opens
## the gate instead (the arrow points there, the map's diamond stands
## there), its words the gate's line; what it follows (its title, its quest,
## the main story or not) stays the same. A lead with nothing in its way
## comes back as it was. What opens a gate may lie past an earlier one: then
## that one's line and what opens it.
static func detour(lead: Dictionary, progression: ProgressionState, settlement: SettlementState, items: Dictionary, discovered: Dictionary, depth := 0) -> Dictionary:
	if lead.is_empty() or String(lead.get("map_id", "")) == "" or depth > all().size():
		return lead
	var gate := in_the_way(String(lead["map_id"]), lead.get("cell", NOWHERE), progression, settlement, discovered)
	if gate.is_empty():
		return lead
	var need := _waiting_on(gate, progression, settlement)
	var way := Bearing.of_step(_as_step(need), progression, settlement, items)
	way["step"] = String(need["line"])
	way["gate"] = gate["id"]
	way = detour(way, progression, settlement, items, discovered, depth + 1)
	for key: String in ["title", "main", "quest_id", "named"]:
		way[key] = lead[key]
	way["progress"] = ""
	return way
