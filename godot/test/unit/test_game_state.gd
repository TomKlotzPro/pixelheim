extends GutTest
## GameState keeps the web reducers' invariants: CREATE_HERO's starting kit,
## openChest's payouts and carry limit, the world memory, and a lossless round
## trip for every web field Godot does not play yet.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())


func _chest(id: String) -> Dictionary:
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["id"] == id:
			return chest
	return {}


func test_new_game_matches_the_web_create_hero() -> void:
	assert_eq(state.hero.hero_name, "Wanderer")
	assert_eq(state.hero.role_id, "warrior")
	assert_eq(state.hero.level, 1)
	assert_eq(state.hero.xp_to_next, 38)
	assert_eq(state.hero.hp, 42, "warrior base maxHp")
	assert_eq(state.hero.skill_nodes, ["warrior_power_strike"])
	assert_eq(state.pack.gold, 30)
	assert_eq(state.pack.items, {"potion_hp": 2, "bread": 2, "cheese_wheel": 1})
	assert_eq(state.pack.gear.size(), 1)
	assert_eq(state.pack.gear[0]["itemId"], "rusty_sword")
	assert_eq(state.pack.equipped["weapon"], state.pack.gear[0]["uid"])
	assert_false(state.progression.intro_seen)
	# wakes in the village square, its surroundings already seen
	assert_eq(state.world.map_id, "town")
	assert_eq(state.world.cell, Vector2i(28, 30))
	assert_true(Discovery.is_discovered(state.world.discovered, "town", Vector2i(30, 32)))
	assert_false(Discovery.is_discovered(state.world.discovered, "town", Vector2i(31, 30)))


func test_rangers_string_a_bow() -> void:
	state.new_game("Robin", "ranger")
	assert_eq(state.pack.gear[0]["itemId"], "hunting_bow")


func test_state_round_trips_through_the_web_shape() -> void:
	var before: Dictionary = state.to_dict()
	state.apply(SaveCodec.migrate({"version": 4, "state": before}))
	assert_eq(state.to_dict(), before)


func test_fields_godot_does_not_play_yet_survive_untouched() -> void:
	var code := FileAccess.get_file_as_string("res://test/fixtures/web_save_v4.txt")
	var imported := SaveCodec.decode_code(code)
	state.apply(imported)
	assert_eq(state.to_dict(), imported)


func test_gold_chest_pays_once() -> void:
	var nook := _chest("town_nook")
	var result: Dictionary = state.open_chest(nook)
	assert_true(result["opened"])
	assert_eq(result["message"], "The chest holds 60g.")
	assert_eq(state.pack.gold, 90)
	assert_true(state.is_opened(nook))
	assert_false(state.open_chest(nook)["opened"], "an opened chest stays empty")
	assert_eq(state.pack.gold, 90)


func test_ground_treasure_speaks_in_its_own_words() -> void:
	assert_eq(state.open_chest(_chest("road_glint"))["message"], "Something glitters on the road: 45g.")
	var herb := {}
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["look"] == "herb":
			herb = chest
	var result: Dictionary = state.open_chest(herb)
	assert_string_starts_with(result["message"], "You gather %dx " % herb["loot"]["qty"])


func test_item_chest_stacks_into_the_pack() -> void:
	var result: Dictionary = state.open_chest(_chest("town_corner"))
	assert_eq(result["message"], "The chest holds 2x Health Potion.")
	assert_eq(state.pack.items["potion_hp"], 4)


func test_gear_chest_adds_an_instance() -> void:
	var result: Dictionary = state.open_chest(_chest("ash_west"))
	assert_eq(result["message"], "The chest holds Iron Sword!")
	assert_eq(state.pack.gear.size(), 2)
	assert_eq(state.pack.gear[1]["itemId"], "iron_sword")


func test_overloaded_pack_leaves_the_chest_closed() -> void:
	state.hero.stats["strength"] = 0  # capacity 60
	state.pack.items = {"potion_hp": 60}  # 60 weight; the worn sword weighs nothing
	assert_eq(state.carry_capacity(), 60)
	assert_eq(state.pack.carried_weight(), 60)
	var ash_west := _chest("ash_west")
	var result: Dictionary = state.open_chest(ash_west)
	assert_false(result["opened"])
	assert_eq(result["message"], "Too heavy to carry. Lighten the pack and come back.")
	assert_false(state.is_opened(ash_west))
	assert_eq(state.pack.gear.size(), 1)


func test_carry_passives_count_skills_and_only_the_deepest_path_step() -> void:
	var hero := HeroState.create("Robin", "ranger")
	assert_eq(hero.carry_bonus(), 0)
	hero.skill_nodes.append("ranger_fieldcraft")
	assert_eq(hero.carry_bonus(), 15)
	hero.spec = "beastmaster"  # a pre-graph save walks its spec
	assert_eq(hero.carry_bonus(), 35)
	hero.path = ["beastmaster", "packlord"]
	assert_eq(hero.carry_bonus(), 45)


func test_mimics_bite() -> void:
	var mimic := {}
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest.get("mimic", false):
			mimic = chest
	var result: Dictionary = state.open_chest(mimic)
	assert_true(result["mimic"])
	assert_true(state.is_opened(mimic))


func test_moving_remembers_position_and_sight() -> void:
	var town := MapData.load_by_id("town")
	state.world.slain.assign(["town_spawn_1"])
	state.move_to(town, Vector2i(20, 30), Vector2.LEFT)
	assert_eq(state.world.cell, Vector2i(20, 30))
	assert_eq(state.world.facing, "left")
	assert_true(Discovery.is_discovered(state.world.discovered, "town", Vector2i(18, 32)))
	assert_eq(state.world.slain, ["town_spawn_1"], "same map keeps its slain ledger")
	state.move_to(MapData.load_by_id("overworld"), Vector2i(48, 40), Vector2.UP)
	assert_eq(state.world.slain, [], "a new map clears it")
	assert_true(state.dirty)


func test_steps_are_whole_in_saves() -> void:
	state.walk(2.75)
	state.walk(1.5)
	assert_almost_eq(state.world.steps, 4.25, 0.001)
	assert_eq(state.to_dict()["worldSteps"], 4)


func test_owned_house_sign_reads_home() -> void:
	var labels := Interactables.signs_on("town", true).map(func(s: Dictionary) -> String: return s["label"])
	assert_has(labels, "HOME")
	assert_does_not_have(labels, "FOR SALE")
	state.settlement.house["owned"] = true
	assert_true(state.owns_house())
