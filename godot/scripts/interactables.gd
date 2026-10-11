class_name Interactables
## Treasure chests, door signs and waypoints (assets/maps/interactables.json,
## edited by hand). test_interactables checks every chest: its own id, known
## loot, open ground off any way out, clear of the packs.

static var _doc := {}


static func _data() -> Dictionary:
	if _doc.is_empty():
		var raw := FileAccess.get_file_as_string("res://assets/maps/interactables.json")
		var doc: Dictionary = JSON.parse_string(raw)
		var signs: Dictionary = doc["signs"].duplicate(true)
		var owned: Variant = doc.get("signsHouseOwned", {}).duplicate(true)
		_doc = Text.localize(doc)
		# A sign's label is its id (PIX-196, PIX-208 for the owner's signs): the
		# icon and the door go by it; where it's shown, it translates itself.
		_doc["signs"] = signs
		_doc["signsHouseOwned"] = owned
		# A chest on a region dungeon's planned floor (PIX-255) stands where
		# the floor's plan puts its find.
		for chest: Dictionary in _doc["chests"]:
			if Depths.is_planned(String(chest["mapId"])):
				var at := Depths.find_cell(String(chest["mapId"]))
				chest["x"] = at.x
				chest["y"] = at.y
	return _doc


static func chests_on(map_id: String) -> Array:
	return _data()["chests"].filter(func(chest: Dictionary) -> bool: return chest["mapId"] == map_id)


## Door signs; the house sign reads HOME instead of FOR SALE once it is owned.
static func signs_on(map_id: String, house_owned := false) -> Array:
	if house_owned and _data()["signsHouseOwned"].has(map_id):
		return _data()["signsHouseOwned"][map_id]
	return _data()["signs"].get(map_id, [])


static func waypoints() -> Array:
	return _data()["waypoints"]


## A waypoint unlocks the moment its marker tile has been seen.
static func waypoint_discovered(waypoint: Dictionary, discovered: Dictionary) -> bool:
	var at := Vector2i(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))
	return Discovery.is_discovered(discovered, waypoint["mapId"], at)


## Discovered AND staffed: a settler-run post only works once they moved in.
static func waypoint_usable(
	waypoint: Dictionary, discovered: Dictionary, settlers: Array
) -> bool:
	if not waypoint_discovered(waypoint, discovered):
		return false
	var required: String = waypoint.get("requiresSettler", "")
	return required == "" or required in settlers

