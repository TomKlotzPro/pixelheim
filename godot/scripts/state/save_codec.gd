class_name SaveCodec
## The web save contract (src/state/save.ts, schema v4) in GDScript: the
## version envelope, the migration chain every historical save replays, the
## rebase onto current defaults, and PXH1 save codes. It works on web-shaped
## Dictionaries, so a Godot save IS a web save: either game loads the other's.

const SAVE_VERSION := 4
const CODE_PREFIX := "PXH1."
## Never resume mid-battle or mid-menu; wake up back in the world.
const RESUME_INTO := {
	"screen": "world", "battle": null, "openPanel": null, "dungeonSelect": null,
	"worldMessage": null, "dialogue": null,
}


## initialState in src/state/shared.ts.
static func initial_state() -> Dictionary:
	return {
		"screen": "title", "hero": null, "gold": 0, "inventory": {}, "gear": [], "equipped": {},
		"unlockedLevel": 1, "clearedLevels": [], "battle": null, "openPanel": null,
		"house": {"owned": false, "storage": {}}, "properties": [], "townTier": 1, "settlers": [],
		"quests": {}, "world": null, "dungeonSelect": null, "introSeen": true,
		"worldMessage": null, "worldSteps": 0, "dialogue": null,
	}


## Silent JSON parse (null on garbage) with integers restored.
static func parse_json(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return intify(json.data)


## JSON numbers arrive as floats; the web's integers must stay integers so
## saves round-trip byte for byte.
static func intify(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT:
			return int(value) if value == floorf(value) and absf(value) < 9.0e15 else value
		TYPE_DICTIONARY:
			var out := {}
			for key: Variant in value:
				out[key] = intify(value[key])
			return out
		TYPE_ARRAY:
			var out := []
			for entry: Variant in value:
				out.append(intify(entry))
			return out
	return value


## Keys keep the order the save came with (Godot sorts them by default), so a
## web save Godot loads and writes back is the very text the web would write.
static func serialize(state: Dictionary) -> String:
	return JSON.stringify({"version": SAVE_VERSION, "state": state}, "", false)


## Takes any historical save payload and upgrades it to the current version.
## Returns {} for saves from the future and for garbage.
static func migrate(raw: Variant) -> Dictionary:
	var version := 1
	var state: Variant = raw
	if raw is Dictionary and raw.has("state") and typeof(raw.get("version")) in [TYPE_INT, TYPE_FLOAT]:
		version = int(raw["version"])
		state = raw["state"]
	if version < 1 or version > SAVE_VERSION or not state is Dictionary:
		return {}
	var upgraded: Dictionary = state.duplicate(true)
	while version < SAVE_VERSION:
		match version:
			2:
				upgraded = _v2_world_memory(upgraded)
			3:
				upgraded = _v3_gear_instances(upgraded)
			# v1 -> v2 only introduced the envelope; the shape did not change.
		version += 1
	return normalize(upgraded)


## v2 -> v3: `world` grew from a flat position into {position, discovered,
## openedChests}. Saves that never entered the world keep world: null.
static func _v2_world_memory(state: Dictionary) -> Dictionary:
	var world: Variant = state.get("world")
	if not world is Dictionary or not world.get("mapId"):
		state["world"] = null
	else:
		state["world"] = {"position": world, "discovered": {}, "openedChests": []}
	return state


## v3 -> v4: weapon/apparel counts become common gear instances, and equipped
## slots switch from item ids to instance uids.
static func _v3_gear_instances(state: Dictionary) -> Dictionary:
	var inventory: Dictionary = state.get("inventory", {}).duplicate()
	var equipped: Dictionary = state.get("equipped", {}).duplicate()
	var gear: Array = []
	for item_id: String in inventory.keys():
		if not Catalog.item(item_id).has("slot"):
			continue
		for i in int(inventory[item_id]):
			gear.append(InventoryState.create_gear(item_id))
		inventory.erase(item_id)
	for slot: String in equipped.keys():
		if not equipped[slot]:
			continue
		var instance := InventoryState.create_gear(equipped[slot])
		gear.append(instance)
		equipped[slot] = instance["uid"]
	state["inventory"] = inventory
	state["equipped"] = equipped
	state["gear"] = gear
	return state


## Validates a parsed save and rebases it on the current defaults (normalizeSave):
## purely additive fields need no version bump, they pick up their defaults here.
static func normalize(state: Dictionary) -> Dictionary:
	if not _valid_hero(state.get("hero")):
		return {}
	var save := initial_state()
	save.merge(state, true)
	save.merge(RESUME_INTO, true)
	var hero: Dictionary = save["hero"]
	# Heroes from before spendable growth start banking from their next level.
	if not hero.has("statPoints"):
		hero["statPoints"] = 0
	# Heroes from before professions start every job at level 1.
	if not hero.has("jobs"):
		hero["jobs"] = HeroState.fresh_jobs()
	# Heroes from before the endurance stat get their role's base grit.
	if not hero["stats"].has("endurance"):
		hero["stats"]["endurance"] = Catalog.role(hero["roleId"])["baseStats"]["endurance"]
	# Heroes from before the skill tree keep the skills their level had earned
	# under the old gates (1/3/6) and bank the leftover points retroactively.
	if not hero.has("skillNodes"):
		var roots := Catalog.skill_roots(hero["roleId"])
		var owned := [roots[0]]
		if hero["level"] >= 3 and roots.size() > 1:
			owned.append(roots[1])
		if hero["level"] >= 6 and roots.size() > 2:
			owned.append(roots[2])
		hero["skillNodes"] = owned
		hero["skillPoints"] = maxi(0, hero["level"] - 1 - (owned.size() - 1))
	# Saves from before visible monsters have no kill ledger for the map.
	if save["world"] is Dictionary and not save["world"].has("slain"):
		save["world"]["slain"] = []
	# Saves from the hub era have no world position: they wake up in town.
	if not save["world"] is Dictionary:
		save["world"] = fresh_world()
	# New floors must open for players who cleared the old final floor.
	var max_cleared := 0
	for level: int in save["clearedLevels"]:
		max_cleared = maxi(max_cleared, level)
	save["unlockedLevel"] = maxi(save["unlockedLevel"], mini(max_cleared + 1, Catalog.level_count()))
	return save


## A web world record standing at the town spawn, its surroundings seen.
static func fresh_world() -> Dictionary:
	var spawn := Catalog.town_spawn()
	var discovered := {}
	Discovery.discover_around(discovered, MapData.load_by_id(spawn["mapId"]), Vector2i(spawn["x"], spawn["y"]))
	return {
		"position": spawn.duplicate(),
		"discovered": WorldState.discovered_to_json(discovered),
		"openedChests": [],
		"slain": [],
	}


## The web trusts any truthy hero; Godot also refuses heroes it could not play.
static func _valid_hero(hero: Variant) -> bool:
	if not hero is Dictionary:
		return false
	for key in ["name", "roleId", "level", "xp", "xpToNext", "hp", "mp"]:
		if not hero.has(key):
			return false
	return hero.get("stats") is Dictionary and not Catalog.role(str(hero["roleId"])).is_empty()


## A copy-pastable code (encodeSaveCode), e.g. to move progress between devices.
static func encode_code(state: Dictionary) -> String:
	return CODE_PREFIX + Marshalls.utf8_to_base64(serialize(state))


## Parses a save code from any past version of either game; {} on anything invalid.
static func decode_code(code: String) -> Dictionary:
	var trimmed := code.strip_edges()
	if not trimmed.begins_with(CODE_PREFIX):
		return {}
	var payload := trimmed.substr(CODE_PREFIX.length())
	# Validate first: Godot's decoder logs engine errors on malformed input.
	var base64 := RegEx.create_from_string("^[A-Za-z0-9+/]+={0,2}$")
	if payload.length() % 4 != 0 or base64.search(payload) == null:
		return {}
	return migrate(parse_json(Marshalls.base64_to_utf8(payload)))
