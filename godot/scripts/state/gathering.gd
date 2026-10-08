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
