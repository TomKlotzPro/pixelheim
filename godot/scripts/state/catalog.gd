class_name Catalog
## Game data exported from the web game (assets/data/catalog.json, regenerated
## by pnpm godot:sync): item slots and weights, role base stats, skill-tree
## roots, carry-weight passives, the spawn points. Read-only — the web modules
## in src/game stay the source of truth until the web build is sunset.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/catalog.json"))
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


static func skill_carry_bonus(node_id: String) -> int:
	return _data()["carryBonus"]["skillNodes"].get(node_id, 0)


static func path_carry_bonus(node_id: String) -> int:
	return _data()["carryBonus"]["pathNodes"].get(node_id, 0)


## "The Ashenreach", "Pixelheim"...; interiors take their town's name.
static func place_name(map_id: String) -> String:
	return _data()["places"].get(map_id, map_id.capitalize())


static func level_count() -> int:
	return _data()["levelCount"]


## {mapId, x, y, facing}: where new heroes wake (TOWN_SPAWN in shared.ts).
static func town_spawn() -> Dictionary:
	return _data()["townSpawn"]
