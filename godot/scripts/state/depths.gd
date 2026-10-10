class_name Depths
## A region's dungeon in floors (PIX-255, after Tom: « Les donjons, ça serait
## bien sur plusieurs étages, c'est un peu simple »). Each region's dungeon
## is a list of floors (assets/data/depths.json), top to bottom, each a map
## of its own: handcrafted (the sea cave's smugglers' caves, its grotto) or
## laid out by DungeonFloor from a seed (its drowned galleries), the same
## every visit. Between each floor and the next a stair down and a stair up;
## each floor's foes stand a little higher than the floor above's; the
## bottom one keeps the dungeon's boss, and once it has fallen a shortcut
## opens straight out to the way in. Nothing of it is saved: a floor reached
## is its fog of war (Discovery, by map id), a find its chest opened, the
## shortcut its boss among the named hunts, and a hero saved on any floor
## wakes at the dungeon's entrance. Pure: MapData lays and dresses the
## floors, the world draws and walks them.

const NOWHERE := Vector2i(-1, -1)
## How far from its door a boss may fall and the door still be its way out,
## in cells (PIX-292: "a few steps", and on the screen); further off, a way
## out opens where it fell as well.
const WAY_OUT_NEAR := 4.0
## How far round where a boss fell its way out may open, in cells, when
## that cell itself won't take it.
const WAY_OUT_REACH := 2

static var _doc := {}
## Map id -> its floor: the data's entry with its "dungeon" and its
## "number" (from 1, top down).
static var _floors := {}
## Map id -> a planned floor's layout (DungeonFloor.lay), worked out once
## and only read: generate() lays a fresh one to walk.
static var _plans := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/depths.json")))
		_floors = {}
		for dungeon_id: String in _doc["dungeons"]:
			var listed: Array = _doc["dungeons"][dungeon_id]["floors"]
			for i in listed.size():
				var entry: Dictionary = listed[i].duplicate()
				entry["dungeon"] = dungeon_id
				entry["number"] = i + 1
				_floors[entry["mapId"]] = entry
	return _doc


## Every region dungeon by id.
static func dungeons() -> Dictionary:
	return _data()["dungeons"]


static func dungeon(dungeon_id: String) -> Dictionary:
	return dungeons().get(dungeon_id, {})


## A dungeon's floors, top to bottom.
static func floors(dungeon_id: String) -> Array:
	return dungeon(dungeon_id).get("floors", [])


static func count(dungeon_id: String) -> int:
	return floors(dungeon_id).size()


## The floor `map_id` is ({mapId, dungeon, number, lift...}), {} for a map
## that is none.
static func floor_of(map_id: String) -> Dictionary:
	_data()
	return _floors.get(map_id, {})


## Which floor of its dungeon `map_id` is, from 1; 0 for any other map.
static func number(map_id: String) -> int:
	return int(floor_of(map_id).get("number", 0))


## The map a floor's tables go by - its music, how far into the Reach it
## lies: its dungeon's first floor (the sea cave for its galleries). Any
## other map goes by itself.
static func root(map_id: String) -> String:
	var entry := floor_of(map_id)
	return String(floors(entry["dungeon"])[0]["mapId"]) if not entry.is_empty() else map_id


## Whether `map_id` is a floor laid out from a seed rather than read.
static func is_planned(map_id: String) -> bool:
	return floor_of(map_id).has("plan")


## How many levels above their kind a floor's foes stand.
static func lift(map_id: String) -> int:
	return int(floor_of(map_id).get("lift", 0))


## A planned floor as DungeonFloor.lay takes it: its seed, a pack per room
## after the entrance, its region and lift, a stair down unless it's the
## bottom, its set piece.
static func _spec(map_id: String) -> Dictionary:
	var entry := floor_of(map_id)
	var planned: Dictionary = entry["plan"]
	var spec := {
		"seed": int(planned["seed"]), "id": map_id, "lift": lift(map_id),
		"region": String(dungeon(entry["dungeon"])["region"]), "encounters": planned["packs"],
		"down": int(entry["number"]) < count(entry["dungeon"]),
		# No pack at home within this many cells of where a hero comes in.
		"clear": int(Packs.rules()["safeTiles"]),
	}
	if planned.has("setPiece"):
		spec["setPiece"] = _data()["setPieces"][planned["setPiece"]]
	return spec


## A planned floor's layout (DungeonFloor.lay plus {spawns, down, find,
## piece_cells}), for reading only.
static func plan(map_id: String) -> Dictionary:
	if not _plans.has(map_id):
		_plans[map_id] = DungeonFloor.lay(_spec(map_id))
	return _plans[map_id]


## A planned floor's map, laid out afresh to be walked (and changed).
static func generate(map_id: String) -> MapData:
	return DungeonFloor.lay(_spec(map_id))["map"]


## The packs of every planned floor (Bestiary keeps them with the others).
static func planned_spawns() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_data()
	for map_id: String in _floors:
		if is_planned(map_id):
			for spawn: Dictionary in plan(map_id)["spawns"]:
				out.append(spawn.duplicate())
	return out


## Where a planned floor's find stands (its set piece's chest), NOWHERE
## for any other map.
static func find_cell(map_id: String) -> Vector2i:
	return plan(map_id).get("find", NOWHERE) if is_planned(map_id) else NOWHERE


## A floor's stairs to the floors beside it: {"up": {cell, arrive},
## "down": {cell, arrive}}, each only where there's a floor that way - a
## planned floor's where its plan puts them, a handcrafted one's from the
## data. `arrive` is the cell a hero coming the other way lands on.
static func stairs(map_id: String) -> Dictionary:
	var entry := floor_of(map_id)
	var out := {}
	if entry.is_empty():
		return out
	var at := int(entry["number"])
	var deepest := count(entry["dungeon"])
	if entry.has("plan"):
		var laid := plan(map_id)
		var map: MapData = laid["map"]
		if at > 1:
			out["up"] = {"cell": laid["stairs"], "arrive": map.spawn}
		if at < deepest:
			out["down"] = {"cell": laid["down"], "arrive": laid["landing"]}
		return out
	for way: String in ["up", "down"]:
		if entry.has(way):
			out[way] = {"cell": _cell(entry[way]), "arrive": _cell(entry[way]["arrive"])}
	return out


## The floor beside `map_id`, `step` floors down (-1: the one above), {}
## past either end.
static func beside(map_id: String, step: int) -> Dictionary:
	var entry := floor_of(map_id)
	if entry.is_empty():
		return {}
	var index := int(entry["number"]) - 1 + step
	var listed := floors(entry["dungeon"])
	return floor_of(listed[index]["mapId"]) if index >= 0 and index < listed.size() else {}


## A floor of a dungeon as it stands every visit (MapData.load_by_id): its
## stone's tint and its own dark, its stair up landing beside the stair
## down of the floor above and its stair down beside the stair up of the
## one below, the shortcut's door shut (open_shortcut opens it), and its
## set piece's words. Any other map comes back as it was.
static func dress(map: MapData) -> MapData:
	var entry := floor_of(map.id)
	if entry.is_empty():
		return map
	if entry.has("tint"):
		map.tint = _color(entry["tint"])
	if entry.has("light"):
		map.light = _color(entry["light"])
	var ways := stairs(map.id)
	for way: String in ways:
		var other := beside(map.id, -1 if way == "up" else 1)
		var landing: Vector2i = stairs(other["mapId"])["down" if way == "up" else "up"]["arrive"]
		var cell: Vector2i = ways[way]["cell"]
		map.grid[cell] = "cave" if way == "up" else "stairwell"
		map.regions.erase(cell)
		map.portals[cell] = {"kind": "map", "mapId": other["mapId"], "x": landing.x, "y": landing.y}
	var door := shortcut_on(map.id)
	if not door.is_empty():
		map.grid[door["cell"]] = "sealed"
		map.pieces[door["cell"]] = PunyDungeon.DOORS[door["look"]][0]
	if entry.has("plan") and entry["plan"].has("setPiece"):
		var note := String(_data()["setPieces"][entry["plan"]["setPiece"]].get("note", ""))
		for cell: Vector2i in plan(map.id)["piece_cells"]:
			map.notes[cell] = note
	return map


## The dungeon's boss: the named monster on its bottom floor ("" if none).
static func boss(dungeon_id: String) -> String:
	var listed := floors(dungeon_id)
	return String(listed[-1].get("boss", "")) if not listed.is_empty() else ""


## The shortcut out of `map_id`'s dungeon when it's on that floor: {cell,
## to (the portal: the dungeon's way in), opened (what's said as it opens),
## boss, look (PunyDungeon.DOORS: the sea cave's wooden gate, the shafts'
## ore cage, the cellars' north stair), fell (what's said as a way out opens
## where the boss fell, PIX-292), sign (where it leads, over a way out as
## the hero comes near)}; {} otherwise.
static func shortcut_on(map_id: String) -> Dictionary:
	var entry := floor_of(map_id)
	if entry.is_empty():
		return {}
	var cut: Dictionary = dungeon(entry["dungeon"]).get("shortcut", {})
	if String(cut.get("mapId", "")) != map_id:
		return {}
	return {
		"cell": _cell(cut), "to": cut["to"], "opened": String(cut.get("opened", "")), "boss": boss(entry["dungeon"]),
		"look": String(cut.get("look", "gate")), "fell": String(cut.get("fell", "")), "sign": String(cut.get("sign", "")),
	}


## Whether the shortcut on `map_id` stands open for a hero who has felled
## `hunted`: its dungeon's boss is down.
static func shortcut_open(map_id: String, hunted: Array) -> bool:
	var door := shortcut_on(map_id)
	return not door.is_empty() and door["boss"] in hunted


## The shortcut as it stands for a hero who has felled `hunted`: once the
## boss is down, a dark doorway (or a stair up) straight out to the way in
## (one way: there is no door on the far side). Returns whether it opened.
static func open_shortcut(map: MapData, hunted: Array) -> bool:
	if not shortcut_open(map.id, hunted):
		return false
	var door := shortcut_on(map.id)
	var cell: Vector2i = door["cell"]
	map.grid[cell] = "cave"
	map.pieces[cell] = PunyDungeon.DOORS[door["look"]][1]
	map.portals[cell] = (door["to"] as Dictionary).duplicate()
	return true


## Where a way out opens beside a boss that fell at `fell` (PIX-292, Tom:
## « Porte de sortie direct après un boss »): NOWHERE when its floor has no
## shortcut or the door stands within WAY_OUT_NEAR of it, else the open
## floor nearest where it fell (that cell first, then out to WAY_OUT_REACH),
## never a portal, nor `avoid` (where the hero stands: a way out opens to
## be stepped onto).
static func way_out_cell(map: MapData, fell: Vector2i, avoid := NOWHERE) -> Vector2i:
	var door := shortcut_on(map.id)
	if door.is_empty() or fell == NOWHERE or Vector2(fell).distance_to(Vector2(door["cell"])) <= WAY_OUT_NEAR:
		return NOWHERE
	var best := NOWHERE
	for dy in range(-WAY_OUT_REACH, WAY_OUT_REACH + 1):
		for dx in range(-WAY_OUT_REACH, WAY_OUT_REACH + 1):
			var cell := fell + Vector2i(dx, dy)
			if cell == avoid or map.portals.has(cell) or not map.is_walkable(cell):
				continue
			if String(map.grid.get(cell, "")) not in ["floor", "ice", "stone"]:
				continue
			if best == NOWHERE or fell.distance_squared_to(cell) < fell.distance_squared_to(best):
				best = cell
	return best


## A way out opened at `cell` (way_out_cell): a stair up, straight out to
## the dungeon's way in as the shortcut is. Only for this visit: the floor
## is laid afresh on the next, its door in the rock standing open.
static func open_way_out(map: MapData, cell: Vector2i) -> void:
	var door := shortcut_on(map.id)
	if door.is_empty() or cell == NOWHERE:
		return
	map.grid[cell] = "cave"
	map.pieces[cell] = PunyDungeon.STAIRS
	map.portals[cell] = (door["to"] as Dictionary).duplicate()


## The ways straight out of `map` to its dungeon's way in (PIX-292): the
## shortcut's door once open, and a way out opened where its boss fell, in
## the order they opened; [] for any other map.
static func exits(map: MapData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var door := shortcut_on(map.id)
	if door.is_empty():
		return out
	var to: Dictionary = door["to"]
	for cell: Vector2i in map.portals:
		var target: Dictionary = map.portals[cell]
		if String(target.get("mapId", "")) == String(to["mapId"]) and int(target.get("x", -1)) == int(to["x"]) and int(target.get("y", -1)) == int(to["y"]):
			out.append(cell)
	return out


## The way out the arrow takes from `map` toward `to_map` for a hero at
## `from` (PIX-292): once its boss is down, the nearest of its exits, for
## anywhere but the floors above (their stairs lead there); NOWHERE
## otherwise (nowhere to go, or no way out open), and the arrow goes by the
## doors as before.
static func way_out_toward(map: MapData, to_map: String, from: Vector2i) -> Vector2i:
	var door := shortcut_on(map.id)
	if door.is_empty() or to_map == "" or to_map == map.id:
		return NOWHERE
	var upstairs := String(floor_of(to_map).get("dungeon", "")) == String(floor_of(map.id)["dungeon"])
	if upstairs and to_map != String(door["to"]["mapId"]):
		return NOWHERE
	var best := NOWHERE
	for cell: Vector2i in exits(map):
		if best == NOWHERE or from.distance_squared_to(cell) < from.distance_squared_to(best):
			best = cell
	return best


## Where a hero saved at `cell` of `map_id` wakes: at the entrance of the
## dungeon's first floor when the save stands on any of its floors (old
## saves inside the sea cave too, its grotto now two floors down); in town
## when it stands by a way that's shut now (`shut`, PIX-257: the
## Undermountain's cave, filled in); anywhere else, where it stood (by the
## mountain's gate, for a save made on its old floors: the save kept the
## gate). {mapId, cell}.
static func waking(map_id: String, cell: Vector2i) -> Dictionary:
	for way: Dictionary in _data().get("shut", []):
		var rect: Array = way["rect"]
		if String(way["mapId"]) == map_id and Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])).has_point(cell):
			var home: Dictionary = Catalog._data()["townSpawn"]
			return {"mapId": String(home["mapId"]), "cell": Vector2i(int(home["x"]), int(home["y"]))}
	var entry := floor_of(map_id)
	if entry.is_empty():
		return {"mapId": map_id, "cell": cell}
	return {"mapId": String(floors(entry["dungeon"])[0]["mapId"]), "cell": _cell(dungeon(entry["dungeon"])["entrance"])}


## The battle log's word on arriving on a floor: "The Sea Cave, floor 2
## of 3".
static func floor_line(map_id: String) -> String:
	var entry := floor_of(map_id)
	if entry.is_empty():
		return ""
	return Text.t("%s, floor %d of %d") % [dungeon(entry["dungeon"])["name"], int(entry["number"]), count(entry["dungeon"])]


## How strong a floor's foes stand: the mean level of its packs' leaders,
## lifted with the floor (each floor's above the one over it).
static func foe_level(map_id: String) -> float:
	var spawns := Bestiary.spawns_on(map_id)
	if spawns.is_empty():
		return 0.0
	var total := 0.0
	for spawn: Dictionary in spawns:
		total += int(Bestiary.monster(String(spawn["species"]))["level"])
	return total / spawns.size() + lift(map_id)


static func _cell(at: Dictionary) -> Vector2i:
	return Vector2i(int(at["x"]), int(at["y"]))


static func _color(rgb: Array) -> Color:
	return Color(float(rgb[0]), float(rgb[1]), float(rgb[2]))
