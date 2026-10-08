class_name Gathering
## Gathering spots (PIX-143): patches of each wild region's material that
## the hero picks by walking over, and that grow back after regrowSteps
## tiles walked; and one patch on every dungeon floor, of a material that
## deepens with the floors. Pure, over combat.json's "gathering" and
## "gatherSpots"; GameState picks, MapView draws.


static func rules() -> Dictionary:
	return Bestiary._data()["gathering"]


static func spots_on(map_id: String) -> Array:
	return Bestiary._data()["gatherSpots"].filter(func(spot: Dictionary) -> bool: return spot["mapId"] == map_id)


## What a wild patch grows: its region's forage material.
static func material_at(map: MapData, cell: Vector2i) -> String:
	return Bestiary._data()["regionMaterials"].get(map.region_at(cell), "")


## What a dungeon floor's patch grows: deeper floors, rarer finds.
static func floor_material(level: int) -> String:
	var found := ""
	for step: Array in rules()["floorMaterials"]:
		if level >= int(step[0]):
			found = step[1]
	return found


## A floor's patch has its own id, so it regrows like any other.
static func floor_spot_id(level: int) -> String:
	return "floor_%d_patch" % level


## Ready to pick: never picked, or grown back since.
static func is_ready(world: WorldState, spot_id: String) -> bool:
	if not world.gathered_at.has(spot_id):
		return true
	return world.steps - float(world.gathered_at[spot_id]) >= float(rules()["regrowSteps"])


# ---- fishing (PIX-165) -------------------------------------------------------

## The places to fish from: stand there facing the water and press E.
static func fishing_spot_at(map_id: String, cell: Vector2i) -> Dictionary:
	for spot: Dictionary in Bestiary._data().get("fishingSpots", []):
		if spot["mapId"] == map_id and Vector2i(int(spot["x"]), int(spot["y"])) == cell:
			return spot
	return {}


## A spot bites again once enough steps have passed since its last catch.
static func fish_ready(world: WorldState, spot_id: String) -> bool:
	if not world.gathered_at.has(spot_id):
		return true
	return world.steps - float(world.gathered_at[spot_id]) >= float(Bestiary._data()["fishing"]["regrowSteps"])


## What comes up on the line: a weighted pick of combat.json "fishing".
static func catch(roll: Callable) -> String:
	var catches: Array = Bestiary._data()["fishing"]["catches"]
	var total := 0
	for entry: Array in catches:
		total += int(entry[1])
	var pick: float = roll.call() * total
	for entry: Array in catches:
		pick -= int(entry[1])
		if pick < 0:
			return entry[0]
	return catches[0][0]
