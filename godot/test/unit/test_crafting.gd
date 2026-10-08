extends GutTest
## Crafting you can do (PIX-143): every recipe's materials can be had again
## and again, a first smithing recipe at level 1, monsters that carry what
## the recipes need, a trade that learns from its own crafts, and hints that
## say where a missing material comes from.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_every_material_can_be_had_again() -> void:
	for entry: Dictionary in Economy.recipes():
		for need: String in entry["needs"]:
			var kinds := Economy.material_sources(need).map(func(source: Dictionary) -> String: return source["kind"])
			assert_true(kinds.any(func(kind: String) -> bool: return kind != "hoard"), "%s for %s" % [need, entry["id"]])


func test_each_trade_starts_at_level_one() -> void:
	for job: String in ["smithing", "alchemy"]:
		var first := Economy.recipes().filter(func(entry: Dictionary) -> bool:
			return entry["job"]["id"] == job and int(entry["job"]["level"]) == 1
		)
		assert_false(first.is_empty(), "%s has a first recipe" % job)
	assert_eq(Economy.recipe("craft_reed_buckler")["needs"], {"marsh_reed": 3})
	assert_eq(Economy.recipe("craft_scaled_mail")["needs"]["dragon_scale"], 1)


func test_wolves_carry_pelts_and_fafnyr_his_scales() -> void:
	state.roll = func() -> float: return 0.4
	var log: Array[String] = state.defeat_monster(Bestiary.spawn("wolf"), "forest", "", 1)
	assert_has(log, "Dire Wolf drops: Wolf Pelt.")
	assert_eq(state.pack.items.get("wolf_pelt", 0), 1)
	state.roll = func() -> float: return 0.99
	state.defeat_monster(Bestiary.spawn("dragon"), "", "", 10)
	assert_eq(state.pack.items.get("dragon_scale", 0), 1, "a scale on every kill")
	assert_true("the Whispering Forest" in Bestiary.where_found("wolf"), "wolves live in the forest")


func test_a_craft_teaches_its_own_trade() -> void:
	state.world.map_id = "town_alchemist"
	state.hero.jobs["alchemy"]["level"] = 4
	state.pack.items.merge({"wolf_pelt": 2, "grave_moss": 1})
	var made: Dictionary = state.craft("brew_wolfstooth_collar")
	assert_true(made["made"])
	assert_eq(state.hero.jobs["alchemy"]["xp"], Economy.craft_xp("alchemy"), "the collar is brewed")
	assert_eq(state.hero.jobs["smithing"]["xp"], 0)


func test_a_trade_level_is_announced() -> void:
	state.world.map_id = "town_smith"
	state.hero.jobs["smithing"]["xp"] = Economy.job_xp_to_next(1) - 5
	state.pack.items["marsh_reed"] = 3
	var made: Dictionary = state.craft("craft_reed_buckler")
	assert_eq(made["level_line"], "Smithing reached 2!")
	assert_eq(Economy.job_line(state.hero.jobs, "smithing"), "Smithing 2 (5/50 XP)")


func test_a_missing_material_says_where_it_comes_from() -> void:
	assert_eq(Economy.where_to_find("wolf_pelt"), "Wolf Pelt: Dire Wolf, 50% (the Whispering Forest, the Sunken Marsh, floor 4)")
	assert_eq(Economy.where_to_find("marsh_reed"), "Marsh Reed: foraged after fights in the Sunken Marsh")
	assert_eq(Economy.where_to_find("dragon_scale"), "Dragon Scale: Fafnyr the Ashen, every time (floor 10)")
