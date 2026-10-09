extends GutTest
## The town economy, ported from src/game/economy and reducers/economy.ts.
## Rule tests mirror shop/recipes/jobs.test.ts; the numbers in the *_match_the_web
## tests were printed from the web functions themselves; the GameState tests
## port economy.test.ts (CRAFT and the home workbench) plus buy/sell/forge.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())


func _stand_in(map_id: String) -> void:
	state.world.map_id = map_id


# ---- rules -------------------------------------------------------------------

func test_stock_matches_the_web() -> void:
	var expected := {
		"odo@1": "bread,cheese_wheel,apple,dried_meat,furn_candles,furn_plant",
		"odo@3": "bread,cheese_wheel,apple,dried_meat,furn_candles,furn_plant,furn_rug,furn_bench",
		"smith@1": "rusty_sword,hunting_bow,traveler_cloak,wool_gloves,worn_boots",
		"smith@3": "rusty_sword,hunting_bow,traveler_cloak,leather_armor,iron_sword,apprentice_staff,wool_gloves,worn_boots,leather_cap,bone_charm",
		"alchemist@1": "potion_hp,potion_mp,antidote",
		"alchemist@3": "potion_hp,potion_mp,antidote",
		"alchemist@15": "potion_hp,potion_mp,antidote,elixir,ember_salve,greater_potion",
	}
	for key: String in expected:
		var parts := key.split("@")
		assert_eq(",".join(Economy.shop_stock(parts[0], int(parts[1]))), expected[key], key)


func test_every_shop_only_stocks_its_own_trade_and_never_shrinks() -> void:
	for shop_id in Economy._data()["shops"]:
		var sells: Array = Economy.shop(shop_id)["sells"]
		var late := Economy.shop_stock(shop_id, 15)
		for item_id in late:
			assert_has(sells, Catalog.item(item_id)["category"])
		for item_id in Economy.shop_stock(shop_id, 1):
			assert_has(late, item_id)


func test_sell_prices_match_the_web() -> void:
	var expected := {
		"forest_herb/odo/1": 3, "forest_herb/alchemist/1": 6, "forest_herb/alchemist/4": 7,
		"potion_hp/odo/1": 12, "potion_hp/odo/4": 15, "wolf_pelt/alchemist/4": 48,
		"bread/smith/4": 2, "iron_sword/smith/1": 36, "iron_sword/smith/4": 43, "iron_sword/odo/4": 36,
	}
	for key: String in expected:
		var p := key.split("/")
		assert_eq(Economy.sell_price_at(p[1], p[0], int(p[2])), expected[key], key)


func test_gear_prices_carry_rarity_like_the_web() -> void:
	var expected := {
		"common/odo/1": 75, "common/smith/4": 108, "fine/smith/1": 180, "fine/odo/4": 180,
		"epic/smith/4": 432, "epic/odo/1": 300,
	}
	for key: String in expected:
		var p := key.split("/")
		var armor := {"uid": "x", "itemId": "iron_armor", "rarity": p[0], "bonus": 0}
		assert_eq(Economy.gear_sell_price_at(p[1], armor, int(p[2])), expected[key], key)


func test_forge_costs_match_the_web() -> void:
	var expected := {
		"0/1": 20, "0/10": 20, "3/1": 60, "3/6": 48, "3/10": 38, "6/1": 105, "6/6": 84, "6/10": 67,
	}
	for key: String in expected:
		var p := key.split("/")
		assert_eq(Economy.forge_cost_for("iron_sword", int(p[0]), int(p[1])), expected[key], key)
	assert_eq(Economy.forge_cost("rusty_sword", 0), 20, "the 20g floor")
	assert_eq(Economy.forge_cap_for(1), 7)
	assert_eq(Economy.forge_cap_for(5), 8)


func test_forge_gets_pricier_with_every_bonus() -> void:
	var previous := 0
	for bonus in 7:
		var cost := Economy.forge_cost("iron_sword", bonus)
		assert_gte(cost, maxi(20, previous))
		previous = cost


func test_jobs_level_chain_and_cap() -> void:
	assert_eq(Economy.job_xp_to_next(1), 35)
	assert_eq(Economy.job_xp_to_next(9), 155)
	var jobs := HeroState.fresh_jobs()
	assert_eq(Economy.grant_job_xp(jobs, "alchemy", Economy.job_xp_to_next(1) + Economy.job_xp_to_next(2)), 2)
	assert_eq(jobs["alchemy"]["level"], 3)
	jobs["foraging"]["level"] = 10
	assert_eq(Economy.grant_job_xp(jobs, "foraging", 999), 0)
	assert_eq(jobs["foraging"]["level"], 10)


func test_double_brew_odds() -> void:
	assert_eq(Economy.double_brew_chance(1), 0.0)
	assert_almost_eq(Economy.double_brew_chance(6), 0.3, 0.0001)
	assert_eq(Economy.double_brew_chance(20), 0.5)


func test_recipes_use_real_items_and_demand_the_full_bill() -> void:
	assert_gte(Economy.recipes().size(), 14)
	for entry: Dictionary in Economy.recipes():
		assert_false(Catalog.item(entry["itemId"]).is_empty(), entry["id"])
		for need: String in entry["needs"]:
			assert_false(Catalog.item(need).is_empty(), "%s needs %s" % [entry["id"], need])
	var first: Dictionary = Economy.recipes()[0]
	var jobs := HeroState.fresh_jobs()
	var exact: Dictionary = first["needs"].duplicate()
	assert_true(Economy.can_craft(first, exact, jobs))
	var short := exact.duplicate()
	short[short.keys()[0]] -= 1
	assert_false(Economy.can_craft(first, short, jobs))
	assert_false(Economy.can_craft(first, {}, jobs))


func test_the_gate_is_the_making() -> void:
	var mail := Economy.recipe("craft_scaled_mail")
	var jobs := HeroState.fresh_jobs()
	assert_false(Economy.can_craft(mail, mail["needs"], jobs), "Smithing 1 < 6")
	jobs["smithing"]["level"] = 6
	assert_true(Economy.can_craft(mail, mail["needs"], jobs))


# ---- GameState: buy / sell / forge --------------------------------------------

func test_buying_needs_the_shop_the_stock_and_the_gold() -> void:
	_stand_in("town")
	assert_false(state.trade.buy_item("bread"), "no shop on the street")
	_stand_in("town_shop")
	assert_false(state.trade.buy_item("iron_sword"), "Odo doesn't sell steel")
	assert_false(state.trade.buy_item("furn_banner"), "stock for later in the story (PIX-176)")
	assert_true(state.trade.buy_item("bread"))
	assert_eq(state.pack.gold, 30 - Economy.buy_price("bread"))
	assert_eq(state.pack.items["bread"], 3)
	state.pack.gold = 0
	assert_false(state.trade.buy_item("bread"))


func test_bought_gear_is_a_common_instance() -> void:
	_stand_in("town_smith")
	state.pack.gold = 100  # the bow costs 45, a new hero has 30
	assert_true(state.trade.buy_item("hunting_bow"))
	assert_eq(state.pack.gear.size(), 2)
	assert_eq(state.pack.gear[1]["itemId"], "hunting_bow")
	assert_eq(state.pack.gear[1]["rarity"], "common")


func test_selling_pays_the_shop_rate_with_city_and_trophy_bonuses() -> void:
	_stand_in("town_alchemist")
	state.pack.items = {"forest_herb": 3}
	assert_eq(state.trade.sell_item("forest_herb"), 6)
	state.settlement.town_tier = 4
	assert_eq(state.trade.sell_item("forest_herb"), 7)
	state.settlement.house["trophies"] = ["gem"]
	assert_eq(state.trade.sell_item("forest_herb"), 7, "floor(7 * 1.1)")
	assert_false(state.pack.items.has("forest_herb"), "an emptied stack disappears")
	assert_eq(state.trade.sell_item("forest_herb"), 0)


func test_a_whole_stack_sells_at_the_one_by_one_price() -> void:
	_stand_in("town_alchemist")
	state.pack.items = {"forest_herb": 3}
	state.pack.gold = 0
	assert_eq(state.trade.sell_item("forest_herb", 99), 18, "three herbs at 6g, never more than are carried")
	assert_eq(state.pack.gold, 18)
	assert_false(state.pack.items.has("forest_herb"))


func test_worn_gear_is_never_sold() -> void:
	_stand_in("town_smith")
	var worn: String = state.pack.equipped["weapon"]
	assert_eq(state.trade.sell_gear(worn), 0)
	state.pack.gold = 100
	assert_true(state.trade.buy_item("hunting_bow"))
	var spare: String = state.pack.gear[1]["uid"]
	assert_gt(state.trade.sell_gear(spare), 0)
	assert_true(state.pack.gear_by_uid(spare).is_empty())


func test_the_forge_raises_bonus_for_gold_and_smithing_xp() -> void:
	_stand_in("town_shop")
	var sword: String = state.pack.equipped["weapon"]
	state.pack.gold = 1000
	assert_false(state.trade.upgrade_gear(sword), "Odo has no forge")
	_stand_in("town_smith")
	assert_true(state.trade.upgrade_gear(sword))
	assert_eq(state.pack.gear_by_uid(sword)["bonus"], 1)
	assert_eq(state.pack.gold, 1000 - Economy.forge_cost_for("rusty_sword", 0, 1))
	assert_eq(state.hero.jobs["smithing"]["xp"], 10)
	state.pack.gear_by_uid(sword)["bonus"] = 7
	assert_false(state.trade.upgrade_gear(sword), "the cap holds at smithing 1")


# ---- GameState: CRAFT (economy.test.ts) -----------------------------------------

func test_forges_gear_as_an_instance_and_pays_smithing_xp() -> void:
	_stand_in("town_smith")
	state.hero.jobs["smithing"]["level"] = 3
	state.pack.items = {"wolf_pelt": 2, "ember_shard": 2}
	assert_true(state.trade.craft("craft_beast_cleaver")["made"])
	assert_eq(state.pack.gear[-1]["itemId"], "beast_cleaver")
	assert_false(state.pack.items.has("wolf_pelt"))
	assert_eq(state.hero.jobs["smithing"]["xp"], 20, "PIX-181: 5 + 5 a recipe level (a level-3 cleaver)")


func test_refuses_a_recipe_above_the_job_level() -> void:
	_stand_in("town_smith")
	state.pack.items = {"wolf_pelt": 2, "ember_shard": 2}
	assert_false(state.trade.craft("craft_beast_cleaver")["made"])
	assert_eq(state.pack.items["wolf_pelt"], 2)


func test_a_skilled_alchemist_brews_doubles() -> void:
	_stand_in("town_alchemist")
	state.roll = func() -> float: return 0.01
	state.hero.jobs["alchemy"]["level"] = 6
	state.pack.items = {"forest_herb": 1, "marsh_reed": 1}
	assert_eq(state.trade.craft("brew_potion_hp")["count"], 2)
	assert_eq(state.pack.items["potion_hp"], 2)
	assert_eq(state.hero.jobs["alchemy"]["xp"], 10, "a level-1 brew")


func test_refuses_to_craft_away_from_the_station() -> void:
	_stand_in("town")
	state.hero.jobs["smithing"]["level"] = 3
	state.pack.items = {"wolf_pelt": 2, "ember_shard": 2}
	assert_false(state.trade.craft("craft_beast_cleaver")["made"])
	assert_eq(state.pack.items["wolf_pelt"], 2)


func test_the_home_workbench_crafts_both_trades_only_at_home() -> void:
	_stand_in("town_house")
	state.settlement.house["owned"] = true
	state.hero.jobs["smithing"]["level"] = 3
	state.pack.items = {"wolf_pelt": 2, "ember_shard": 2, "forest_herb": 1, "marsh_reed": 1}
	assert_false(state.trade.craft("craft_beast_cleaver")["made"], "an owned house is not a station")
	state.settlement.house["workbench"] = true
	assert_true(state.trade.craft("craft_beast_cleaver")["made"])
	assert_true(state.trade.craft("brew_potion_hp")["made"])
	_stand_in("town")
	state.pack.items = {"wolf_pelt": 2, "ember_shard": 2}
	assert_false(state.trade.craft("craft_beast_cleaver")["made"], "the workbench does not travel")


func test_the_craft_guide_knows_which_trades_are_here() -> void:
	assert_eq(Economy.jobs_here("town_smith", false), ["smithing"])
	assert_eq(Economy.jobs_here("town_alchemist", false), ["alchemy"])
	assert_eq(Economy.jobs_here("town_house", false), [], "no workbench yet")
	assert_eq(Economy.jobs_here("town_house", true).size(), 2, "the workbench does both")
	assert_eq(Economy.jobs_here("overworld", true), [])
	assert_string_contains(Economy.station_hint("smithing"), "Hilda")


# ---- PIX-180: late-game gold -----------------------------------------------------

func test_the_deep_hunts_gold_climbs_by_a_step_not_a_curve() -> void:
	var at := func(depth: int) -> int:
		var base := Bestiary.monster("troll")
		return int(Bestiary.lifted(base, 18 + depth - int(base["level"]))["gold"])
	var first: int = at.call(1)
	assert_lt(float(at.call(30)) / first, 3.2, "depth 30 pays under about three times depth 1")
	assert_lt(at.call(20) - at.call(10), (at.call(10) - at.call(1)) * 1.4, "and each ten depths add about the same")
	# The mountain itself keeps its curve.
	var slime := Bestiary.spawn("slime", false, Dungeons.lift(1))
	assert_gt(int(slime["gold"]), 50)


func test_fafnyrs_scale_is_sure_once_then_rare() -> void:
	state.roll = func() -> float: return 0.5
	state.defeat_monster(Bestiary.spawn("dragon"), "", "", 10)
	assert_eq(state.pack.items.get("dragon_scale", 0), 1, "the first time, always")
	assert_has(state.progression.firsts, "fafnyr_scale")
	state.defeat_monster(Bestiary.spawn("dragon"), "", "", 10)
	assert_eq(state.pack.items.get("dragon_scale", 0), 1, "then a tenth of the time (the roll was a half)")
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(saved["firsts"], ["fafnyr_scale"], "kept in the save")


func test_masterwork_forging_past_the_cap() -> void:
	_stand_in("town_smith")
	var sword: String = state.pack.equipped["weapon"]
	state.pack.gold = 1000000
	state.hero.jobs["smithing"]["level"] = 8
	var cap := Economy.forge_cap_for(8)
	state.pack.gear_by_uid(sword)["bonus"] = cap
	assert_false(state.trade.upgrade_gear(sword), "a gem a step")
	state.pack.items["gem"] = 2
	var first := Economy.masterwork_cost("rusty_sword", cap, 8)
	assert_true(state.trade.upgrade_gear(sword))
	assert_eq(state.pack.gear_by_uid(sword)["bonus"], cap + 1)
	assert_eq(state.pack.items.get("gem", 0), 1)
	assert_gt(Economy.masterwork_cost("rusty_sword", cap + 1, 8), first * 2, "each step dearer")
	state.pack.gear_by_uid(sword)["bonus"] = 12
	state.pack.items["gem"] = 5
	assert_false(state.trade.upgrade_gear(sword), "+12 at most")
	state.hero.jobs["smithing"]["level"] = 7
	state.pack.gear_by_uid(sword)["bonus"] = Economy.forge_cap_for(7)
	assert_false(state.trade.upgrade_gear(sword), "not before Smithing 8")


func test_commissions_wait_for_every_age_and_give_a_lasting_edge() -> void:
	state.pack.gold = 100000
	assert_eq(state.fund_commission("lantern_walk"), "", "not while an age is still being built")
	state.settlement.projects.assign(Town.projects_through(Town.MAX_TIER))
	state.settlement.town_tier = Town.MAX_TIER
	assert_ne(state.fund_commission("lantern_walk"), "")
	assert_eq(state.fund_commission("lantern_walk"), "", "once")
	assert_almost_eq(state.commission_buff("gold"), 0.1, 0.0001)
	state.roll = func() -> float: return 0.99
	var before: int = state.pack.gold
	state.defeat_monster(Bestiary.wild(Bestiary.spawn("wolf")), "forest", "", 1)
	assert_eq(state.pack.gold - before, roundi(int(Bestiary.wild(Bestiary.spawn("wolf"))["gold"]) * 1.1), "a tenth more gold a kill")


func test_the_city_sells_rare_stock() -> void:
	for item_id: String in ["kings_signet", "aegis_of_the_ash", "everflask"]:
		var price := Economy.buy_price(item_id)
		assert_between(price, 2000, 5000, "%s is a city-tier buy" % item_id)
	assert_has(Economy.shop_stock("odo", 15, 4), "kings_signet")
	assert_false(Economy.shop_stock("odo", 15, 3).has("kings_signet"), "only in the City")
