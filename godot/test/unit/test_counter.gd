extends GutTest
## The counter's rules (PIX-336): what's junk, how many of a stack go, the
## buyback shelf at the price a sale fetched, the numbers a piece is set
## against what's worn by, and the owner's and the trophy's prices, as
## they were.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const ShopScreen := preload("res://scripts/shop_screen.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.world.map_id = "town_shop"


## A piece put on, as the pack's E does.
func _wear(item_id: String) -> Dictionary:
	var piece := InventoryState.create_gear(item_id)
	state.pack.gear.append(piece)
	state.upkeep.equip(piece["uid"])
	return piece


func _carry(item_id: String) -> Dictionary:
	var piece := InventoryState.create_gear(item_id)
	state.pack.gear.append(piece)
	return piece


# ---- junk ------------------------------------------------------------------------

func test_cheap_materials_past_three_crafts_are_junk() -> void:
	# The most a recipe takes of herbs is 2: six are kept.
	assert_eq(Trade.junk_count("forest_herb", 10), 4)
	assert_eq(Trade.junk_count("forest_herb", 6), 0, "three crafts' worth stays")
	assert_eq(Trade.junk_count("old_boot", 2), 2, "nothing needs an old boot: all of it")
	assert_eq(Trade.junk_count("wolf_pelt", 30), 0, "worth more than junk")
	assert_eq(Trade.junk_count("gem", 9), 0, "a trophy for the shelf")
	assert_eq(Trade.junk_count("letter_wenna", 1), 0, "a quest's")
	assert_eq(Trade.junk_count("potion_hp", 40), 0, "only materials")


func test_gear_worse_than_whats_worn_is_junk() -> void:
	_wear("iron_sword")
	var rusty: Dictionary = state.pack.gear[0]
	assert_false(state.pack.is_equipped(rusty["uid"]), "the starter's sword came off")
	assert_true(state.trade.junk_piece(rusty), "4 damage under 8")
	var fine := _carry("rusty_sword")
	fine["affixes"] = {"strength": 2}
	assert_false(state.trade.junk_piece(fine), "less damage, but a stat up: a choice, not junk")
	assert_false(state.trade.junk_piece(_carry("iron_sword")), "as good is not worse")
	assert_false(state.trade.junk_piece(_carry("leather_cap")), "nothing worn there: better than nothing")
	var worn: Dictionary = HeroRules.weapon(state.pack)
	assert_false(state.trade.junk_piece(worn), "never what's worn")
	_wear("scaled_greaves")
	assert_true(state.trade.junk_piece(_carry("worn_boots")), "armour 1 under 5")
	assert_false(state.trade.junk_piece(_carry("oilskin_boots")), "never a set's piece: it may make a set")


func test_a_ring_is_junk_only_under_both_worn() -> void:
	_wear("garnet_ring")
	var grit := _carry("band_of_grit")
	assert_false(state.trade.junk_piece(grit), "a finger is free")
	_wear("drowned_signet")
	assert_true(state.trade.junk_piece(grit), "under the garnet and the signet both")
	# Both fingers full, a ring goes on the first: the garnet comes off.
	_wear("ring_of_clarity")
	assert_false(state.trade.junk_piece(grit), "+1 STR against the clarity ring's none: not worse than both")


func test_sell_all_junk_sells_the_lot_for_its_sum() -> void:
	state.pack.items = {"forest_herb": 10, "old_boot": 2, "wolf_pelt": 3, "potion_hp": 2}
	_wear("iron_sword")
	var lot: Dictionary = state.trade.junk()
	assert_eq(lot["items"], {"forest_herb": 4, "old_boot": 2})
	assert_eq(lot["gear"].size(), 1, "the rusty sword")
	var sum: int = 4 * state.trade.item_pays("forest_herb") + 2 * state.trade.item_pays("old_boot") + state.trade.gear_pays(state.pack.gear[0])
	assert_eq(lot["gold"], sum)
	state.pack.gold = 0
	assert_eq(state.trade.sell_junk(), sum)
	assert_eq(state.pack.gold, sum)
	assert_eq(state.pack.items, {"forest_herb": 6, "wolf_pelt": 3, "potion_hp": 2}, "the rest stays")
	assert_true(state.trade.junk()["items"].is_empty() and state.trade.junk()["gear"].is_empty(), "no junk left")


# ---- a stack, how many ----------------------------------------------------------

func test_a_stack_sells_as_many_as_asked() -> void:
	assert_eq(Trade.stack_amount(0, 10), 1, "one at least")
	assert_eq(Trade.stack_amount(4, 10), 4)
	assert_eq(Trade.stack_amount(99, 10), 10, "never more than carried")
	assert_eq(Trade.stack_amount(3, 0), 1, "a stack gone asks for one")
	state.pack.items = {"wolf_pelt": 10}
	state.pack.gold = 0
	var each: int = state.trade.item_pays("wolf_pelt")
	assert_eq(state.trade.sell_item("wolf_pelt", Trade.stack_amount(4, 10)), 4 * each)
	assert_eq(state.pack.items["wolf_pelt"], 6)


# ---- buyback -----------------------------------------------------------------------

func test_buyback_pays_what_the_sale_fetched() -> void:
	state.pack.items = {"wolf_pelt": 5}
	state.pack.gold = 0
	var each: int = state.trade.item_pays("wolf_pelt")
	assert_eq(state.trade.sell_item("wolf_pelt", 3), 3 * each)
	assert_eq(state.trade.sold_here.size(), 1)
	assert_eq(state.trade.sold_here[0], {"item_id": "wolf_pelt", "count": 3, "each": each})
	state.trade.sell_item("wolf_pelt", 1)
	assert_eq(state.trade.sold_here.size(), 1, "the same at the same price shelves together")
	assert_eq(state.trade.sold_here[0]["count"], 4)
	# Prices move (a gem on the shelf): the shelf keeps what it fetched.
	state.settlement.house["trophies"] = ["gem"]
	assert_gt(state.trade.item_pays("wolf_pelt"), each)
	assert_eq(state.pack.gold, 4 * each)
	assert_true(state.trade.buy_back(0))
	assert_eq(state.pack.gold, 0, "bought back for exactly what it fetched")
	assert_eq(state.pack.items["wolf_pelt"], 5)
	assert_true(state.trade.sold_here.is_empty())


func test_buyback_returns_the_very_piece_and_needs_the_gold() -> void:
	_wear("iron_sword")
	var rusty: Dictionary = state.pack.gear[0]
	rusty["bonus"] = 2
	state.pack.gold = 0
	var got: int = state.trade.sell_gear(rusty["uid"])
	assert_true(state.pack.gear_by_uid(rusty["uid"]).is_empty())
	state.pack.gold = got - 1
	assert_false(state.trade.buy_back(0), "a coin short")
	assert_false(state.trade.buy_back(3), "nothing on that shelf")
	state.pack.gold = got
	assert_true(state.trade.buy_back(0))
	assert_eq(state.pack.gear_by_uid(rusty["uid"])["bonus"], 2, "the same piece, its +2 kept")
	assert_eq(state.pack.gold, 0)


func test_leaving_the_counter_empties_the_shelf() -> void:
	var kept_stall: String = GameState.trade.stall_shop
	GameState.trade.stall_shop = Economy.shop_at("town_shop")
	var counter: Screen = ShopScreen.new()
	add_child(counter)
	await wait_process_frames(2)
	GameState.trade.sold_here.append({"item_id": "wolf_pelt", "count": 1, "each": 20})
	counter.close()
	await wait_process_frames(2)
	assert_true(GameState.trade.sold_here.is_empty(), "this visit's sales only")
	GameState.trade.stall_shop = kept_stall
	get_tree().paused = false


# ---- what's worn, compared ---------------------------------------------------------

func test_the_numbers_go_up_and_down_against_whats_worn() -> void:
	var rusty: Dictionary = HeroRules.weapon(state.pack)
	assert_eq(rusty["itemId"], "rusty_sword")
	var iron := InventoryState.create_gear("iron_sword")
	assert_eq(Trade.compare(iron, rusty), {"damage": 4}, "8 against 4: up 4")
	assert_eq(Trade.compare(rusty, iron), {"damage": -4})
	var fine := InventoryState.create_gear("iron_sword")
	fine["bonus"] = 1
	fine["affixes"] = {"dexterity": 2}
	assert_eq(Trade.compare(fine, rusty), {"damage": 5, "dexterity": 2}, "the forge's +1 and an affix count")
	assert_eq(Trade.compare(InventoryState.create_gear("garnet_ring"), InventoryState.create_gear("band_of_grit")), {"strength": 1})
	assert_eq(Trade.compare(InventoryState.create_gear("leather_cap"), {}), {"armor": 2}, "nothing worn: all up")
	assert_true(Trade.worse(rusty, iron))
	assert_false(Trade.worse(iron, rusty))
	assert_false(Trade.worse(rusty, rusty), "the same is not worse")
	assert_false(Trade.worse(rusty, {}), "never worse than nothing")


func test_a_piece_is_set_against_what_wearing_it_takes_off() -> void:
	assert_eq(state.trade.worn_against("iron_sword"), HeroRules.weapon(state.pack))
	assert_true(state.trade.worn_against("leather_cap").is_empty(), "a bare head")
	var first := _wear("garnet_ring")
	assert_true(state.trade.worn_against("band_of_grit").is_empty(), "a finger is free")
	_wear("ring_of_clarity")
	assert_eq(state.trade.worn_against("band_of_grit"), first, "both full: the first ring comes off, as equip does")


# ---- prices, unchanged -------------------------------------------------------------

func test_the_owner_still_pays_a_tenth_less() -> void:
	var full: int = state.trade.price_of("bread")
	assert_eq(full, Economy.buy_price("bread"))
	state.pack.gold = 100000
	state.holdings.buy_property("town_shop")
	assert_eq(state.trade.price_of("cheese_wheel"), roundi(Economy.buy_price("cheese_wheel") * 0.9))


func test_the_trophy_still_sweetens_every_sale_by_a_tenth() -> void:
	var base := Economy.sell_price_at("odo", "wolf_pelt", state.town_tier())
	assert_eq(state.trade.item_pays("wolf_pelt"), base)
	var rusty: Dictionary = HeroRules.weapon(state.pack)
	var gear_base := Economy.gear_sell_price_at("odo", rusty, state.town_tier())
	state.settlement.house["trophies"] = ["gem"]
	assert_eq(state.trade.item_pays("wolf_pelt"), floori(base * 1.1))
	assert_eq(state.trade.gear_pays(rusty), floori(gear_base * 1.1))
