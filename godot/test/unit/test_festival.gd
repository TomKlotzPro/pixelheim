extends GutTest
## A livelier town (PIX-159): the town gathers on the square at dusk, the
## shops grow with each age (stock and a signature item each), and an age
## completed brings a festival day with a ring toss and a prize.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const SHOPS := ["odo", "smith", "alchemist"]

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_dusk_comes_before_the_night_and_never_with_it() -> void:
	var cycle := float(DayNight.DAY_CYCLE_STEPS)
	assert_false(DayNight.is_dusk(0.3 * cycle), "midday")
	assert_true(DayNight.is_dusk(0.5 * cycle))
	assert_false(DayNight.is_dusk(0.7 * cycle), "night")
	for step in DayNight.DAY_CYCLE_STEPS:
		assert_false(DayNight.is_dusk(step) and DayNight.is_night(step), "step %d" % step)


func test_the_square_has_room_for_the_town() -> void:
	var map := MapData.load_tiered("town", Town.projects_through(4), 1)
	var spots := Town.gathering_spots(map)
	assert_gte(spots.size(), 8)
	for spot in spots:
		assert_true(map.is_walkable(spot))


func test_each_age_brings_stock_and_a_signature_to_each_shop() -> void:
	for shop_id: String in SHOPS:
		var before := Economy.shop_stock(shop_id, 1, 1)
		var signatures := []
		for age in [2, 3, 4]:
			var now := Economy.shop_stock(shop_id, 1, age)
			assert_gt(now.size(), before.size(), "%s grows at age %d" % [shop_id, age])
			var fresh := now.filter(func(item_id: String) -> bool: return item_id not in before)
			var own := fresh.filter(func(item_id: String) -> bool: return Catalog.item(item_id).get("signature", false))
			assert_eq(own.size(), 1, "%s: one signature at age %d" % [shop_id, age])
			assert_eq(Economy.age_of(shop_id, own[0]), age)
			assert_ne(ItemIcons.source(own[0]), "", "%s has an icon" % own[0])
			signatures.append(own[0])
			before = now
		assert_eq(signatures.size(), 3)
	assert_eq(Economy.shop_stock("smith", 1), Economy.shop_stock("smith", 1, 0), "no age, no change")


func test_a_signature_is_sold_only_from_its_age() -> void:
	state.world.map_id = "town_smith"
	state.pack.gold = 1000
	state.settlement.town_tier = 1
	assert_false(state.trade.buy_item("lamplit_blade"), "not before the Village")
	state.settlement.town_tier = 2
	assert_true(state.trade.buy_item("lamplit_blade"))


func test_an_age_completed_brings_a_festival_day() -> void:
	state.settlement.town_tier = 1
	state.progression.cleared_levels.append(5)
	state.settlement.settlers.append("settler_iva")
	state.pack.gold = 5000
	state.pack.items.merge({"marsh_reed": 8, "wolf_pelt": 2})
	state.holdings.fund_project("street_lamps")
	assert_false(state.holdings.festival_on(), "not for one project")
	state.holdings.fund_project("market_stalls")
	state.holdings.fund_project("thatch_cottage")
	assert_true(state.holdings.festival_on(), "the Village's festival")
	assert_eq(int(state.settlement.festival["age"]), 2)
	state.world.steps += DayNight.DAY_CYCLE_STEPS
	assert_false(state.holdings.festival_on(), "for one day")


func test_the_ring_toss_pays_once_a_festival() -> void:
	assert_eq(state.holdings.win_ring_toss(), "", "no festival, no prize")
	state.holdings.start_festival(3)
	var gold: int = state.pack.gold
	assert_string_contains(state.holdings.win_ring_toss(), "prize")
	assert_eq(state.pack.gold, gold + 90, "30g an age")
	assert_eq(int(state.pack.items.get("festival_pie", 0)), 3)
	assert_eq(state.holdings.win_ring_toss(), "", "once")


func test_the_festival_is_saved_only_while_there_is_one() -> void:
	var town := SettlementState.new()
	var bare := {}
	town.write_into(bare)
	assert_false(bare.has("festival"), "saves from before stay byte for byte")
	town.festival = {"until": 900, "age": 2, "won": false}
	var written := {}
	town.write_into(written)
	written["house"] = {"owned": false, "storage": {}}
	assert_eq(SettlementState.from_dict(written).festival, {"until": 900, "age": 2, "won": false})
