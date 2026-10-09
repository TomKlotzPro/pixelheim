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
	var made: Dictionary = state.trade.craft("brew_wolfstooth_collar")
	assert_true(made["made"])
	assert_eq(state.hero.jobs["alchemy"]["xp"], Economy.craft_xp(Economy.recipe("brew_wolfstooth_collar")), "the collar is brewed")
	assert_eq(state.hero.jobs["smithing"]["xp"], 0)


func test_a_trade_level_is_announced() -> void:
	state.world.map_id = "town_smith"
	state.hero.jobs["smithing"]["xp"] = Economy.job_xp_to_next(1) - 5
	state.pack.items["marsh_reed"] = 3
	var made: Dictionary = state.trade.craft("craft_reed_buckler")
	assert_eq(made["level_line"], "Smithing reached 2!")
	assert_eq(Economy.job_line(state.hero.jobs, "smithing"), "Smithing 2 (5/50 XP)")


func test_a_missing_material_says_where_it_comes_from() -> void:
	assert_eq(Economy.where_to_find("wolf_pelt"), "Wolf Pelt: Dire Wolf, 50% (the Whispering Forest, the Sunken Marsh, floor 4)")
	assert_eq(Economy.where_to_find("marsh_reed"), "Marsh Reed: picked from patches and foraged after fights in the Sunken Marsh")
	assert_eq(Economy.where_to_find("dragon_scale"), "Dragon Scale: Fafnyr the Ashen, sure the first time, then 10% (floor 10)")


## PIX-181: no dead recipes, trades that keep up.
func _value(needs: Dictionary) -> int:
	var total := 0
	for item_id: String in needs:
		total += int(Catalog.item(item_id).get("value", 0)) * int(needs[item_id])
	return total


func test_no_recipe_is_worth_less_than_what_goes_in() -> void:
	for entry: Dictionary in Economy._data()["recipes"]:
		var out := Catalog.item(entry["itemId"])
		assert_gte(int(out.get("value", 0)), _value(entry["needs"]), "%s is worth making" % entry["id"])


func test_no_early_recipe_waits_on_a_late_monster() -> void:
	for entry: Dictionary in Economy._data()["recipes"]:
		if int(entry["job"]["level"]) <= 4:
			assert_false(entry["needs"].has("imp_horn"), "%s needs no L14 imp" % entry["id"])
			assert_false(entry["needs"].has("dragon_scale"), "%s needs no dragon" % entry["id"])


func test_the_bucklers_climb_and_the_dragon_gear_is_endgame() -> void:
	var armor := func(item_id: String) -> int: return int(Catalog.item(item_id)["armor"])
	assert_lt(armor.call("reed_buckler"), armor.call("saltwood_buckler"), "the starter buckler gives way to the coast's")
	assert_lte(armor.call("saltwood_buckler"), armor.call("blackiron_bulwark"))
	assert_lte(armor.call("blackiron_bulwark"), armor.call("warden_kite"))
	assert_gt(armor.call("grave_ward"), armor.call("warden_kite"), "the grave ward tops the shields the forge makes")
	assert_gt(armor.call("scaled_mail"), armor.call("city_plate"), "dragon scale beats the city's plate")
	assert_gte(int(Catalog.item("dragon_tonic")["restoreHp"]), 999, "a dragon tonic is everything back")


func test_no_hoard_gives_away_what_the_forge_makes() -> void:
	var forged := {}
	for entry: Dictionary in Economy._data()["recipes"]:
		if Catalog.item(entry["itemId"]).has("slot"):
			forged[entry["itemId"]] = true
	for level: Dictionary in Bestiary._data()["levels"]:
		for item_id: String in level.get("rewardItemIds", []):
			assert_false(forged.has(item_id), "floor %d's hoard: %s" % [level["level"], item_id])


func test_each_trade_level_is_a_handful_of_crafts_away() -> void:
	for job: String in ["smithing", "alchemy"]:
		var recipes: Array = Economy._data()["recipes"].filter(func(e: Dictionary) -> bool: return e["job"]["id"] == job)
		var crafts := 0
		for level in range(1, 8):
			# The best practice a hero of this level has: its hardest open recipe.
			var best := 0
			for entry: Dictionary in recipes:
				if int(entry["job"]["level"]) <= level:
					best = maxi(best, Economy.craft_xp(entry))
			var needed := ceili(float(Economy.job_xp_to_next(level)) / best)
			assert_lte(needed, 6, "%s %d to %d" % [job, level, level + 1])
			crafts += needed
			if job == "alchemy" and level == 3:
				assert_lte(crafts, 14, "the Frostweave (Alchemy 4) by the Frostgate")


func test_the_top_trade_levels_give_something() -> void:
	assert_gt(Economy.forge_cap_for(9), Economy.forge_cap_for(8), "Smithing 9 forges higher")
	assert_false(Economy.forges_fine(9))
	assert_true(Economy.forges_fine(10), "Smithing 10 forges Fine")
	assert_gt(Economy.double_brew_chance(9), Economy.double_brew_chance(6), "brewing doubles more often")


func test_steeping_turns_bought_potions_into_practice_never_doubles() -> void:
	state.world.map_id = "town_alchemist"
	state.roll = func() -> float: return 0.0
	state.hero.jobs["alchemy"]["level"] = 9
	state.pack.items = {"potion_hp": 2}
	var made: Dictionary = state.trade.craft("steep_potion_hp")
	assert_true(made["made"])
	assert_eq(made["count"], 1, "two potions steep into one, whatever the trade's luck")
	assert_eq(state.pack.items.get("greater_potion", 0), 1)


func test_pearls_are_found_at_the_jetty() -> void:
	var spot := Gathering.fishing_spot("saltmere_jetty")
	var total := 0.0
	var pearls := 0.0
	for catch: Array in spot["catches"]:
		total += float(catch[1])
		if catch[0] == "pearl":
			pearls = float(catch[1])
	assert_gte(pearls / total, 0.15, "the tidecutter's pearl is a fair catch")


## PIX-182: mastery shows in the work, and old gear goes back to the forge.
func test_mastery_makes_finer_work() -> void:
	var dice := func(value: float) -> Callable: return func() -> float: return value
	assert_eq(Economy.craft_rarity(4, 4, dice.call(0.0)), "common", "a recipe at your level comes out plain")
	assert_eq(Economy.craft_rarity(6, 4, dice.call(0.15)), "fine", "two levels above: a fine chance")
	assert_eq(Economy.craft_rarity(9, 4, dice.call(0.05)), "epic", "far above: an epic chance")
	assert_eq(Economy.craft_rarity(4, 4, dice.call(0.05), 1), "fine", "the home workbench counts a level more")
	var fine_at := func(level: int) -> int:
		var count := 0
		for i in 100:
			var roll := float(i) / 100.0
			if Economy.craft_rarity(level, 2, func() -> float: return roll) != "common":
				count += 1
		return count
	assert_gt(fine_at.call(6), fine_at.call(4), "more levels above, more fine work")


func test_salvage_gives_back_half_of_what_went_in() -> void:
	var helm := InventoryState.create_gear("blackiron_helm")
	assert_eq(Economy.salvage_yield(helm), {"blackiron_ore": 1}, "3 ore and a pelt: one ore back")
	var plate := InventoryState.create_gear("blackiron_plate")
	assert_eq(Economy.salvage_yield(plate), {"blackiron_ore": 2, "ember_shard": 1})
	var bought := InventoryState.create_gear("iron_sword", "epic", func() -> float: return 0.0)
	assert_eq(Economy.salvage_yield(bought), {"ember_shard": 3}, "a piece no recipe makes gives shards by its rarity")
	state.world.map_id = "town_smith"
	state.pack.gear.append(plate)
	assert_string_contains(state.trade.salvage_gear(plate["uid"]), "Hilda breaks it down")
	assert_eq(state.pack.items.get("blackiron_ore", 0), 2)
	assert_eq(state.pack.gear_by_uid(plate["uid"]), {}, "the piece is gone")
	state.world.map_id = "town"
	var sword: String = state.pack.equipped["weapon"]
	assert_eq(state.trade.salvage_gear(sword), "", "only at Hilda's, and never what you wear")


func test_reforging_waits_for_smithing_8_and_never_goes_down() -> void:
	state.world.map_id = "town_smith"
	state.pack.gold = 5000
	var epic := InventoryState.create_gear("war_hammer", "epic", func() -> float: return 0.0)
	state.pack.gear.append(epic)
	assert_eq(state.trade.reforge_gear(epic["uid"]), "", "not before Smithing 8")
	state.hero.jobs["smithing"]["level"] = 8
	state.roll = func() -> float: return 0.99
	assert_string_contains(state.trade.reforge_gear(epic["uid"]), "Hilda reforges it")
	assert_eq(epic["rarity"], "epic", "a common roll keeps it epic")
	assert_eq(epic["affixes"].size(), 2)
	assert_lt(state.pack.gold, 5000, "paid for")


func test_each_region_has_a_crafting_quest() -> void:
	var crafted := {}
	for quest: Dictionary in Quests.all():
		if quest["objective"]["kind"] == "craft":
			crafted[quest["giver"]] = quest["objective"]["itemId"]
	assert_eq(crafted.get("saltmere_brin"), "oilskin_coat")
	assert_eq(crafted.get("mines_garrick"), "blackiron_helm")
	assert_eq(crafted.get("frost_linnea"), "frost_hood")
