extends GutTest
## Town tiers, deeds, the bank, recruits and the inn, ported from
## src/game/economy/{town,bank}.ts, settlers.ts and their tests. Numbers in the
## *_match_the_web tests were printed from the web functions themselves.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())


# ---- rules -------------------------------------------------------------------

func test_caravans_match_the_web_hash() -> void:
	var expected := {
		"0:500": "W800", "1:500": "W800", "12:500": "L200", "480:500": "L200", "777:500": "L200",
		"4321:500": "W800", "99999:500": "W800", "123456:750": "L300", "2500000:500": "L200",
		"3000001:1234": "L493",
	}
	for key: String in expected:
		var p := key.split(":")
		var outcome := Town.venture_outcome(int(p[1]), int(p[0]))
		assert_eq("%s%d" % ["W" if outcome["won"] else "L", outcome["payout"]], expected[key], key)
	var wins := 0
	for at in 1000:
		if Town.venture_outcome(500, at)["won"]:
			wins += 1
	assert_eq(wins, 715, "same 1000 departures as the web")


func test_savings_match_the_web() -> void:
	var expected := {0: 500, 479: 500, 480: 510, 1440: 530, 4800: 600, 9999: 600}
	for steps: int in expected:
		assert_eq(Town.savings_value(500, 0, steps), expected[steps], "steps %d" % steps)
	assert_eq(Town.savings_value(333, 20, 1000), 346)


func test_perks_match_the_web() -> void:
	assert_eq([1, 2, 3, 4].map(Town.rent_per_property), [2, 3, 3, 3])
	assert_eq([1, 2, 3, 4].map(Town.rest_cost_for), [10, 10, 5, 5])


## Village projects (PIX-145): an age opens with its requirements, each
## project asks gold and a region's material, and the last raises the age.
func test_a_project_waits_for_its_age_then_for_its_price() -> void:
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1
	var blocker := func() -> String:
		return Town.project_blocker("street_lamps", state.progression, state.settlement, state.pack.gold, state.pack.items)
	assert_string_contains(blocker.call(), "Ruined Watchtower")
	state.progression.cleared_levels.append(5)
	assert_string_contains(blocker.call(), "settler")
	state.settlement.settlers.append("settler_iva")
	state.pack.gold = 100
	assert_eq(blocker.call(), "The treasury asks 150g.")
	state.pack.gold = 1000
	assert_eq(blocker.call(), "It takes 3 Marsh Reed.")
	state.pack.items["marsh_reed"] = 3
	assert_eq(blocker.call(), "")
	assert_string_contains(Town.project_blocker("fountain", state.progression, state.settlement, 99999, {"dragon_scale": 9}), "Finish the Village")


func test_the_last_project_of_an_age_raises_the_town() -> void:
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1
	state.progression.cleared_levels.append(5)
	state.settlement.settlers.append("settler_iva")
	state.pack.gold = 5000
	state.pack.items.merge({"marsh_reed": 8, "wolf_pelt": 2})
	assert_eq(state.fund_project("street_lamps"), "Street lamps: built. Walk outside and see.")
	assert_eq(state.pack.items["marsh_reed"], 5)
	assert_eq(state.town_tier(), 1, "one of three")
	state.fund_project("market_stalls")
	assert_eq(state.fund_project("thatch_cottage"), "A thatched cottage: built - and Pixelheim is a village now.")
	assert_eq(state.town_tier(), 2)
	assert_eq(state.pack.gold, 5000 - 150 - 250 - 400)
	assert_eq(state.fund_project("thatch_cottage"), "", "once")
	assert_eq(Town.current_age(state.settlement), 3)


func test_a_save_from_before_projects_keeps_its_town() -> void:
	var town := SettlementState.new()
	town.town_tier = 3
	assert_eq(Town.done_projects(town), Town.projects_through(3))
	assert_eq(Town.current_age(town), 4)
	var written := {}
	town.write_into(written)
	assert_false(written.has("projects"), "saves from before stay byte for byte")
	town.projects.assign(["street_lamps"])
	town.write_into(written)
	assert_eq(written["projects"], ["street_lamps"])


func test_each_project_changes_the_town_at_once() -> void:
	var base := MapData.load_by_id("town")
	for project_id: String in Town.projects_through(4):
		var map := MapData.load_tiered("town", [project_id], 1)
		assert_ne(map.grid, base.grid, "%s changes the map" % project_id)
	for tier in range(1, 5):
		var map := MapData.load_tiered("town", Town.projects_through(tier), 1)
		assert_eq(map.id, "town")
		assert_eq(map.portals.keys().size(), base.portals.keys().size(), "age %d keeps every door" % tier)
		for cell: Vector2i in map.portals:
			assert_true(map.is_walkable(cell), "age %d door %s blocked" % [tier, cell])
	for tier in range(1, 4):
		assert_eq(MapData.load_tiered("town_house", [], tier).id, "town_house")


func test_the_projects_fit_what_the_game_pays() -> void:
	# A hero earns about 900g by floor 5, 4000g by Fafnyr and 9500g by Morvax
	# in one pass (fights, hoards and quests; PIX-145's estimate).
	var budget := {1: 600, 2: 900, 3: 4000, 4: 9500}
	for entry: Dictionary in Town.ages():
		var total := 0
		for candidate: Dictionary in entry["projects"]:
			total += int(candidate["cost"]["gold"])
			for item_id: String in candidate["cost"]["items"]:
				assert_false(Economy.material_sources(item_id).is_empty(), "%s can be had" % item_id)
		assert_lt(total, budget[int(entry["tier"])], "age %d costs %dg" % [entry["tier"], total])


# ---- GameState: hall, deeds, bank -----------------------------------------------

func test_deeds_sell_only_where_you_stand() -> void:
	state.pack.gold = 10000
	assert_false(state.buy_property("town_shop"), "not standing in Odo's")
	state.world.map_id = "town_shop"
	assert_true(state.buy_property("town_shop"))
	assert_false(state.buy_property("town_shop"), "once")
	assert_eq(state.pack.gold, 7500)


func test_deposits_fold_interest_and_withdraw_pays_it() -> void:
	state.pack.gold = 2000
	assert_true(state.bank_deposit(500))
	state.world.steps = 960.0  # two days
	assert_true(state.bank_deposit(500))
	assert_eq(state.investments()["savings"], {"principal": 1020, "at": 960})
	state.world.steps = 1440.0
	assert_eq(state.bank_withdraw(), 1040)
	assert_eq(state.pack.gold, 1000 + 1040)
	assert_false(state.investments().has("savings"))


func test_one_caravan_at_a_time_sealed_at_departure() -> void:
	state.pack.gold = 2000
	state.world.steps = 4321.0
	assert_true(state.fund_venture())
	assert_false(state.fund_venture(), "one on the road")
	assert_eq(state.collect_venture(), {}, "not back yet")
	state.world.steps = 4321.0 + 240
	assert_eq(state.collect_venture(), {"won": true, "payout": 800})
	assert_eq(state.pack.gold, 2000 - 500 + 800)


func test_expansions_cost_once_on_owned_businesses() -> void:
	state.pack.gold = 5000
	assert_false(state.expand_property("town_shop"), "not owned")
	state.settlement.properties.append("town_shop")
	assert_true(state.expand_property("town_shop"))
	assert_false(state.expand_property("town_shop"), "once")
	assert_eq(state.pack.gold, 4000)


func test_investments_round_trip_in_the_web_shape() -> void:
	state.pack.gold = 2000
	state.bank_deposit(100)
	state.fund_venture()
	var saved: Dictionary = state.to_dict()["investments"]
	assert_eq(saved["savings"]["principal"], 100)
	assert_eq(saved["venture"]["stake"], 500)
	assert_eq(saved["expansions"], [])


# ---- GameState: recruits and services (settlers.test.ts) --------------------------

## A recruit's help is a quest (PIX-148): taken on the first word, turned in
## when it's done, and the turn-in moves them to town.
func test_a_recruits_story_is_a_quest_that_brings_them_home() -> void:
	state.settlement.town_tier = 1
	var messages: Array[String] = []
	state.message.connect(func(text: String) -> void: messages.append(text))
	state.finish_dialogue("settler_iva")
	assert_string_starts_with(messages[0], "Quest accepted - Reeds for a Healer:")
	assert_false(state.is_settled("settler_iva"))
	state.pack.items["marsh_reed"] = 3
	var moved := [false]
	state.settlers_changed.connect(func() -> void: moved[0] = true)
	state.finish_dialogue("settler_iva")
	assert_string_starts_with(messages[1], "Quest complete - Reeds for a Healer! +25 xp. Reeds enough")
	assert_true(state.is_settled("settler_iva"))
	assert_false(state.pack.items.has("marsh_reed"), "the reeds were handed over")
	assert_true(moved[0])
	assert_eq(Npcs.by_id("settler_iva", state.settlement.settlers)["mapId"], "town")


func test_the_bards_lute_is_with_a_troll() -> void:
	state.settlement.town_tier = 2
	state.finish_dialogue("settler_loras")
	assert_true(state.progression.quests.has("loras_lute"))
	state.roll = func() -> float: return 0.99
	state.defeat_monster(Bestiary.spawn("troll"), "deepwood", "", 8)
	state.finish_dialogue("settler_loras")
	assert_true(state.is_settled("settler_loras"))
	assert_has(Town.settler_perks(state.settlement.settlers), "Loras plays a marching song before a hunt: +12% crit until it ends")


func test_finer_folk_hold_out_for_a_finer_town() -> void:
	state.settlement.town_tier = 2
	var messages: Array[String] = []
	state.message.connect(func(text: String) -> void: messages.append(text))
	state.finish_dialogue("settler_mirelle")
	assert_string_contains(messages[0], "into a town")
	assert_false(state.progression.quests.has("mirelle_vault"), "no story until there's a town")


func test_settlers_speak_for_the_towns_age() -> void:
	var at := func(tier: int) -> Array:
		return Npcs.on_map("town", tier, ["settler_iva"]).filter(func(npc: Dictionary) -> bool: return npc["id"] == "settler_iva")[0]["lines"]
	assert_eq(at.call(1)[0], "Sit. Breathe. There - whole again. My door is always open to the town's patron.")
	assert_string_contains(at.call(3)[0], "fountain")
	assert_string_contains(at.call(4)[0], "city")


func test_iva_heals_her_patron_for_free_at_home_in_town() -> void:
	state.settlement.settlers.append("settler_iva")
	state.hero.hp = 1
	state.world.map_id = "town"
	var healed := [false]
	state.healed.connect(func() -> void: healed[0] = true)
	state.finish_dialogue("settler_iva")
	assert_eq(state.hero.hp, state.hero.stats["maxHp"])
	assert_true(healed[0])


func test_the_bard_plays_a_marching_song() -> void:
	state.settlement.settlers.append("settler_loras")
	state.world.map_id = "town"
	state.finish_dialogue("settler_loras")
	assert_true(state.settlement.bard_song)
	assert_true(state.to_dict()["bardSong"])


func test_closing_any_conversation_is_announced() -> void:
	var closed: Array[String] = []
	state.dialogue_closed.connect(func(id: String) -> void: closed.append(id))
	state.finish_dialogue("elder")
	assert_eq(closed, ["elder"])


# ---- GameState: the inn -----------------------------------------------------------

func test_the_inn_charges_only_the_hurt_and_halves_in_a_town() -> void:
	assert_eq(state.rest_at_inn(), "The innkeeper nods. You are already well rested.")
	assert_eq(state.pack.gold, 30)
	state.hero.hp = 1
	assert_eq(state.rest_at_inn(), "You rest at the inn. Fully restored. (-10g)")
	assert_eq(state.pack.gold, 20)
	assert_eq(state.hero.hp, state.hero.stats["maxHp"])
	state.settlement.town_tier = 3
	state.hero.hp = 1
	state.rest_at_inn()
	assert_eq(state.pack.gold, 15)
	state.pack.gold = 0
	state.hero.hp = 1
	assert_eq(state.rest_at_inn(), "No coin, no bed. (Rest costs 5g.)")
