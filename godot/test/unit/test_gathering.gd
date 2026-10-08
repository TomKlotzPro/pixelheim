extends GutTest
## Gathering (PIX-143): patches of each region's material that grow back,
## one on every dungeon floor, and the crafting quests that start a trade.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_every_patch_is_open_ground_with_something_to_pick() -> void:
	var seen := {}
	for map_id: String in ["overworld", "deepwood", "mirefen"]:
		var map := MapData.load_by_id(map_id)
		var view := MapView.new(map, null)
		view.plan(map.spawn)
		var spots := Gathering.spots_on(map_id)
		assert_gt(spots.size(), 3, "%s has patches" % map_id)
		for spot: Dictionary in spots:
			var cell := Vector2i(spot["x"], spot["y"])
			assert_false(seen.has(spot["id"]), "%s is one patch" % spot["id"])
			seen[spot["id"]] = true
			assert_true(map.is_walkable(cell), "%s is open ground" % spot["id"])
			assert_ne(Gathering.material_at(map, cell), "", "%s grows a material" % spot["id"])
			assert_eq(view.patches[cell]["id"], spot["id"])
	var regions := {}
	for region_id: String in Bestiary._data()["regionMaterials"]:
		regions[region_id] = false
	for spot: Dictionary in Bestiary._data()["gatherSpots"]:
		regions[String(spot["id"]).get_slice("_patch", 0)] = true
	assert_false(false in regions.values(), "every region has patches: %s" % regions)


func test_a_patch_is_picked_and_grows_back() -> void:
	state.roll = func() -> float: return 0.99
	state.world.steps = 50.0
	assert_eq(state.gather("forest_patch_1", "forest_herb"), ["You gather 1 Forest Herb."] as Array[String])
	assert_eq(state.pack.items["forest_herb"], 1)
	assert_eq(state.hero.jobs["foraging"]["xp"], 5)
	assert_true(state.gather("forest_patch_1", "forest_herb").is_empty(), "picked bare")
	state.world.steps = 349.0
	assert_false(Gathering.is_ready(state.world, "forest_patch_1"))
	state.world.steps = 350.0
	assert_true(Gathering.is_ready(state.world, "forest_patch_1"), "grown back")
	var saved := {}
	state.world.write_into(saved)
	assert_eq(saved["world"]["gatheredAt"], {"forest_patch_1": 50})
	assert_eq(WorldState.from_dict(saved).gathered_at, {"forest_patch_1": 50})


func test_every_floor_has_a_patch_that_deepens() -> void:
	for level in range(1, Dungeons.floor_count() + 1):
		var plan := DungeonFloor.plan(level)
		var map: MapData = plan["map"]
		assert_eq(map.grid[plan["patch"]], "floor", "floor %d's patch is on the floor" % level)
		assert_ne(plan["patch"], plan["foes"][0]["cell"])
	assert_eq(Gathering.floor_material(1), "forest_herb")
	assert_eq(Gathering.floor_material(5), "marsh_reed")
	assert_eq(Gathering.floor_material(15), "grave_moss")


func test_a_first_brew_for_vex_and_a_buckler_for_hilda() -> void:
	assert_eq(Quests.by_id("herbs_for_vex")["objective"]["kind"], "craft")
	assert_eq(Quests.by_id("hildas_buckler")["giver"], "smith")
	state.resolve_quests("alchemist_vex")
	state.world.map_id = "town_alchemist"
	state.pack.items.merge({"forest_herb": 1, "marsh_reed": 1})
	assert_false(Quests.is_ready(Quests.by_id("herbs_for_vex"), state.progression.quests, state.pack.items))
	state.roll = func() -> float: return 0.99
	assert_true(state.craft("brew_potion_hp")["made"])
	assert_true(Quests.is_ready(Quests.by_id("herbs_for_vex"), state.progression.quests, state.pack.items), "one brewed")
	assert_string_starts_with(state.resolve_quests("alchemist_vex"), "Quest complete - A First Brew!")
