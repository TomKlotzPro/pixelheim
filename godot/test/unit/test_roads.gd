extends GutTest
## The early Reach without walls (PIX-187): paved roads cross the Ash Fields
## to every new region with the strong packs and Cinderjaw kept off them,
## the Deepwood's arrival is clear of trolls, the Mirefen's mimics wait
## deep in Gulp's corner, and every hero's energy comes back out of a fight.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## How close a foe stronger than a fresh hero may stand to a road.
const ROAD_CLEARANCE := 6
const STRONG := 8


func _monster_level(species: String) -> int:
	return int(Bestiary.monster(species).get("level", 1))


func test_roads_reach_every_new_region() -> void:
	var map := MapData.load_by_id("overworld")
	for at: Array in [[2, 20], [47, 20], [50, 15], [93, 15], [50, 10], [68, 10], [68, 5]]:
		assert_eq(map.tile_at(Vector2i(at[0], at[1])), "path", "road at %s" % [at])


func test_strong_packs_and_lairs_keep_off_the_roads() -> void:
	var map := MapData.load_by_id("overworld")
	var road: Array[Vector2i] = []
	for cell: Vector2i in map.grid:
		if map.grid[cell] == "path":
			road.append(cell)
	var near := func(at: Vector2i) -> int:
		var best := 999
		for cell: Vector2i in road:
			best = mini(best, maxi(absi(cell.x - at.x), absi(cell.y - at.y)))
		return best
	for spawn: Dictionary in Bestiary.spawns_on("overworld"):
		var at := Vector2i(int(spawn["x"]), int(spawn["y"]))
		var species := Bestiary.species_of(spawn, map.region_at(at))
		if _monster_level(species) >= STRONG:
			assert_gte(near.call(at), ROAD_CLEARANCE, "%s (%s) keeps off the roads" % [spawn["id"], species])
	for entry: Dictionary in Hunts.all():
		if entry["mapId"] == "overworld" and int(entry["level"]) >= STRONG:
			assert_gte(near.call(Hunts.lair(entry)), ROAD_CLEARANCE, "%s's lair keeps off the roads" % entry["id"])


func test_the_deepwood_and_the_mirefen_greet_a_traveller_safely() -> void:
	var deep := MapData.load_by_id("deepwood")
	var arrival := Vector2i(2, 24)
	for spawn: Dictionary in Bestiary.spawns_on("deepwood"):
		var at := Vector2i(int(spawn["x"]), int(spawn["y"]))
		assert_gte(maxi(absi(at.x - arrival.x), absi(at.y - arrival.y)), 12, "%s stands back from the arrival" % spawn["id"])
		assert_true(deep.is_walkable(at))
	var mire := MapData.load_by_id("mirefen")
	for spawn: Dictionary in Bestiary.spawns_on("mirefen"):
		var at := Vector2i(int(spawn["x"]), int(spawn["y"]))
		assert_ne(Bestiary.species_of(spawn, mire.region_at(at)), "mimic", "%s is no mimic pack" % spawn["id"])
	var chest: Array = Interactables.chests_on("mirefen").filter(func(c: Dictionary) -> bool: return c["id"] == "mire_mimic")
	assert_true(mire.is_walkable(Vector2i(int(chest[0]["x"]), int(chest[0]["y"]))))
	assert_lt(int(chest[0]["x"]), 12, "the mimic waits in the west, by Gulp")


func test_energy_comes_back_out_of_a_fight() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "mage")
	state.hero.mp = 0
	var back: int = state.regen_resting()
	assert_gt(back, 0)
	assert_eq(state.hero.mp, back)
	state.hero.mp = int(state.hero.stats["maxMp"])
	assert_eq(state.regen_resting(), 0, "never past the top")
