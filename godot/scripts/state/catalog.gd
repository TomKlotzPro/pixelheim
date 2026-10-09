class_name Catalog
## Game data exported from the web game (assets/data/catalog.json, regenerated
## by pnpm godot:sync): item slots and weights, role base stats, skill-tree
## roots, carry-weight passives, the spawn points. Read-only — the web modules
## in src/game stay the source of truth until the web build is sunset.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/catalog.json")))
	return _doc


static func item(item_id: String) -> Dictionary:
	return _data()["items"].get(item_id, {})


static func item_name(item_id: String) -> String:
	return item(item_id).get("name", item_id.capitalize())


static func role(role_id: String) -> Dictionary:
	return _data()["roles"].get(role_id, {})


## A role's tier-0 skills in branch order; index 0 is the free starting skill.
static func skill_roots(role_id: String) -> Array:
	return _data()["skillRoots"].get(role_id, [])


## "The Ashenreach", "Pixelheim"...; interiors take their town's name.
static func place_name(map_id: String) -> String:
	return _data()["places"].get(map_id, map_id.capitalize())


static func level_count() -> int:
	return _data()["levelCount"]


## {mapId, x, y, facing}: where new heroes wake (TOWN_SPAWN in shared.ts).
static func town_spawn() -> Dictionary:
	return _data()["townSpawn"]


## An armour set (PIX-166): {name, pieces: [item ids], bonuses: {"3": {...},
## "5": {...}}}, or {}.
static func armour_set(set_id: String) -> Dictionary:
	return _data().get("sets", {}).get(set_id, {})


## One line saying what a set gives and how much of it is worn, each tier
## with all it adds up to by then (PIX-183: the tiers stack): "Saltmere
## Oilskin (3/5): 3 pieces +2 DEX; 5 pieces +5 DEX, +3 armor".
static func set_line(set_id: String, worn: int) -> String:
	var entry := armour_set(set_id)
	var parts: Array[String] = []
	var bonuses: Dictionary = entry.get("bonuses", {})
	var tiers := bonuses.keys()
	tiers.sort_custom(func(a: String, b: String) -> bool: return int(a) < int(b))
	var grants := {}
	var armor := 0
	for at: String in tiers:
		for stat: String in bonuses[at].get("grants", {}):
			grants[stat] = int(grants.get(stat, 0)) + int(bonuses[at]["grants"][stat])
		armor += int(bonuses[at].get("armor", 0))
		var gives: Array[String] = []
		for stat: String in grants:
			gives.append("+%d %s" % [int(grants[stat]), Text.t(stat.substr(0, 3).to_upper())])
		if armor > 0:
			gives.append(Text.t("+%d armor") % armor)
		parts.append(Text.t("%s pieces %s") % [at, ", ".join(gives)])
	return Text.t("%s (%d/%d): %s") % [entry.get("name", set_id), worn, entry.get("pieces", []).size(), "; ".join(parts)]
