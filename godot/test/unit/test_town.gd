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


func test_funding_respects_requirements_and_gold() -> void:
	assert_eq(Town.fund_blocker(1, 100, false, []), "The treasury asks 2500g.")
	assert_eq(Town.fund_blocker(1, 2500, false, []), "")
	assert_string_contains(Town.fund_blocker(2, 99999, false, []), "own your house")
	assert_eq(Town.fund_blocker(2, 7000, true, []), "")
	assert_string_contains(Town.fund_blocker(3, 99999, true, ["town_shop"]), "three businesses")
	assert_eq(Town.fund_blocker(3, 15000, true, ["town_shop", "town_smith", "town_alchemist"]), "")
	assert_eq(Town.fund_blocker(4, 99999, true, []), "Pixelheim stands at its full height.")


func test_every_town_age_is_a_whole_map_with_its_doors() -> void:
	var base := MapData.load_by_id("town")
	for tier in range(1, 5):
		var map := MapData.load_tiered("town", tier, 1)
		assert_eq(map.id, "town")
		assert_eq(map.portals.keys().size(), base.portals.keys().size(), "tier %d keeps every door" % tier)
		for cell: Vector2i in map.portals:
			assert_true(map.is_walkable(cell), "tier %d door %s blocked" % [tier, cell])
	for tier in range(1, 4):
		assert_eq(MapData.load_tiered("town_house", 1, tier).id, "town_house")
	assert_ne(MapData.load_tiered("town", 4, 1).grid, base.grid, "the city really is redrawn")


# ---- GameState: hall, deeds, bank -----------------------------------------------

func test_funding_pays_and_raises_the_tier() -> void:
	state.pack.gold = 3000
	assert_eq(state.fund_town(), "Pixelheim rises: the VILLAGE charter is signed. Walk outside.")
	assert_eq(state.town_tier(), 2)
	assert_eq(state.pack.gold, 500)
	assert_eq(state.fund_town(), "", "the town charter wants a house owner")


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

func test_an_unmet_ask_refuses_politely_and_names_the_price() -> void:
	var messages: Array[String] = []
	state.message.connect(func(text: String) -> void: messages.append(text))
	state.finish_dialogue("settler_iva")
	assert_string_starts_with(messages[0], "Iva the Healer asks: 3x Marsh Reed.")
	assert_false(state.is_settled("settler_iva"))


func test_a_met_ask_recruits_and_the_settler_moves_to_town() -> void:
	state.pack.items["marsh_reed"] = 3
	var moved := [false]
	state.settlers_changed.connect(func() -> void: moved[0] = true)
	state.finish_dialogue("settler_iva")
	assert_true(state.is_settled("settler_iva"))
	assert_false(state.pack.items.has("marsh_reed"), "the reeds were handed over")
	assert_true(moved[0])
	assert_eq(Npcs.by_id("settler_iva", state.settlement.settlers)["mapId"], "town")


func test_finer_folk_hold_out_for_a_finer_town() -> void:
	state.pack.gold = 1000
	var messages: Array[String] = []
	state.message.connect(func(text: String) -> void: messages.append(text))
	state.finish_dialogue("settler_mirelle")
	assert_string_contains(messages[0], "Fund the third charter")
	assert_false(state.is_settled("settler_mirelle"))
	assert_eq(state.pack.gold, 1000)


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
