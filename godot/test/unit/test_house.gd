extends GutTest
## The growing house, ported from src/game/economy/house.ts, its tests and the
## web's house interactions (BUY_HOUSE, storage, workbench, trophies, nook,
## furniture, bed).

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())


func _own_house(gold := 0) -> void:
	state.settlement.house["owned"] = true
	state.pack.gold = gold


func test_the_shut_door_sells_the_deed_or_names_the_price() -> void:
	assert_eq(state.household.buy_house(), "For sale: this house. The deed costs 1500 gold.")
	state.pack.gold = 2000
	assert_eq(state.household.buy_house(), "The deed is yours. Welcome home.")
	assert_true(state.household.owns_house())
	assert_eq(state.pack.gold, 500)
	assert_eq(state.household.buy_house(), "", "once")


func test_odo_sells_the_bigger_deeds_in_order_and_gated_on_gold() -> void:
	assert_eq(Town.next_house_tier(false, 1), {}, "no house, no bigger deed")
	_own_house(20000)
	state.world.map_id = "town_smith"
	assert_eq(state.household.buy_house_upgrade(), "", "only Odo sells deeds")
	state.world.map_id = "town_shop"
	assert_string_contains(state.household.buy_house_upgrade(), "Cottage")
	assert_eq(int(state.settlement.house["tier"]), 2)
	assert_string_contains(state.household.buy_house_upgrade(), "Manor")
	assert_eq(state.pack.gold, 20000 - 5000 - 12000)
	assert_eq(state.household.buy_house_upgrade(), "", "the Manor is the top")


func test_each_tier_has_its_own_interior() -> void:
	var sizes := [1, 2, 3].map(func(tier: int) -> Vector2i: return MapData.load_tiered("town_house", [], tier).size)
	assert_eq(sizes[0], Vector2i(20, 12))
	assert_eq(sizes[1], Vector2i(26, 12))
	assert_eq(sizes[2], Vector2i(30, 14))
	assert_true(MapData.load_tiered("town_house", [], 3).grid.values().has("cauldron"))


func test_storage_moves_stacks_between_pack_and_home() -> void:
	assert_false(state.household.store_item("potion_hp"), "no house, no barrel")
	_own_house()
	assert_true(state.household.store_item("potion_hp", 5))
	assert_false(state.pack.items.has("potion_hp"), "only what you carry: both potions")
	assert_eq(state.settlement.house["storage"], {"potion_hp": 2})
	assert_true(state.household.take_item("potion_hp"))
	assert_eq(state.pack.items["potion_hp"], 1)
	assert_eq(state.settlement.house["storage"], {"potion_hp": 1})


func test_trophies_buff_while_displayed_and_give_it_back() -> void:
	_own_house()
	var defense: int = state.hero.stats["defense"]
	var strength: int = state.hero.stats["strength"]
	state.pack.items["lich_crown"] = 1
	assert_true(state.household.display_trophy("lich_crown"))
	assert_eq(state.hero.stats["defense"], defense + 2)
	assert_eq(state.hero.stats["strength"], strength + 2)
	assert_false(state.pack.items.has("lich_crown"))
	assert_false(state.household.display_trophy("lich_crown"), "one of each on the shelf")
	assert_true(state.household.take_trophy("lich_crown"))
	assert_eq(state.hero.stats["defense"], defense)
	assert_eq(state.hero.stats["strength"], strength)
	state.pack.items["bread"] = 1
	assert_false(state.household.display_trophy("bread"), "bread is not a trophy")


func test_the_nook_distills_two_brews_into_a_better_one() -> void:
	state.pack.items = {"potion_hp": 3}
	assert_eq(state.household.combine_potions("potion_hp"), "The nook bubbles: 2x Health Potion became Greater Health Potion.")
	assert_eq(state.pack.items, {"potion_hp": 1, "greater_potion": 1})
	assert_eq(state.household.combine_potions("potion_hp"), "", "it takes two")


func test_furniture_places_on_floor_and_comes_back_with_a_touch() -> void:
	_own_house()
	state.world.map_id = "town_house"
	state.pack.items["furn_plant"] = 1
	var spot := Vector2i(5, 5)
	assert_eq(state.household.place_furniture("furn_plant", spot, "wall"), "It needs open floor. Face a free tile and try again.")
	assert_eq(state.household.place_furniture("furn_plant", spot, "floor"), "Potted Fern placed. E takes it back.")
	assert_eq(state.household.furniture(), [{"itemId": "furn_plant", "x": 5, "y": 5}])
	assert_false(state.pack.items.has("furn_plant"))
	state.pack.items["furn_plant"] = 1
	assert_eq(state.household.place_furniture("furn_plant", spot, "floor"), "Something already stands there.")
	var back: Dictionary = state.household.house_interact(spot, "floor")
	assert_eq(back["text"], "Potted Fern back in the pack.")
	assert_eq(state.pack.items["furn_plant"], 2)
	assert_true(state.household.furniture().is_empty())
	assert_true(Town.furniture_blocks("furn_plant"))
	assert_false(Town.furniture_blocks("furn_rug"))


func test_fixtures_answer_to_e() -> void:
	_own_house(1000)
	state.world.map_id = "town_house"
	state.hero.hp = 1
	state.world.steps = 0.8 * DayNight.DAY_CYCLE_STEPS
	var slept: Dictionary = state.household.house_interact(Vector2i.ZERO, "bed")
	assert_eq(slept["text"], "You sleep in your own bed till dawn. Fully restored, and well rested: +10% XP for your next 30 fights.")
	assert_true(slept["slept"])
	assert_eq(state.world.steps, float(DayNight.DAY_CYCLE_STEPS), "till the next morning (PIX-246)")
	assert_eq(state.hero.hp, state.hero.stats["maxHp"])
	assert_eq(state.household.house_interact(Vector2i.ZERO, "barrel"), {"panel": "storage"})
	assert_eq(state.household.house_interact(Vector2i.ZERO, "trophy_shelf"), {"panel": "trophies"})
	assert_eq(state.household.house_interact(Vector2i.ZERO, "cauldron"), {"panel": "nook"})
	assert_string_contains(state.household.house_interact(Vector2i.ZERO, "garden")["text"], "0/6")
	assert_eq(state.household.house_interact(Vector2i.ZERO, "wall"), {})
	assert_eq(state.household.house_interact(Vector2i.ZERO, "floor"), {}, "no furniture to place")


func test_the_shelf_sells_then_hosts_the_workbench() -> void:
	_own_house(500)
	state.world.map_id = "town_house"
	assert_string_contains(state.household.house_interact(Vector2i.ZERO, "shelf")["text"], "800 gold")
	state.pack.gold = 900
	assert_string_contains(state.household.house_interact(Vector2i.ZERO, "shelf")["text"], "Craft at home, forever")
	assert_true(state.settlement.house["workbench"])
	assert_eq(state.pack.gold, 100)
	assert_eq(state.household.house_interact(Vector2i.ZERO, "shelf"), {"panel": "workbench"})


func test_the_garden_alternates_bread_and_cheese() -> void:
	assert_eq([0, 1, 2, 3].map(Town.garden_yield), ["forest_herb", "marsh_reed", "forest_herb", "marsh_reed"])


func test_house_records_round_trip_in_the_web_shape() -> void:
	_own_house(20000)
	state.world.map_id = "town_house"
	state.pack.items.merge({"furn_rug": 1, "gem": 1})
	state.household.place_furniture("furn_rug", Vector2i(3, 3), "floor")
	state.household.display_trophy("gem")
	var house: Dictionary = state.to_dict()["house"]
	assert_eq(house["furniture"], [{"itemId": "furn_rug", "x": 3, "y": 3}])
	assert_eq(house["trophies"], ["gem"])
	assert_eq(state.trade.trophy_sell_multiplier(), 1.1)


## PIX-179: a home worth having.
func test_furniture_at_home_helps_each_kind_once() -> void:
	state.new_game("Robin", "warrior")
	_own_house()
	assert_eq(state.household.home_buff("xp"), 0.0)
	state.settlement.house["furniture"] = [
		{"itemId": "furn_bookshelf", "x": 3, "y": 3}, {"itemId": "furn_bookshelf", "x": 4, "y": 3},
		{"itemId": "furn_banner", "x": 5, "y": 3}, {"itemId": "furn_rug", "x": 6, "y": 3},
	]
	assert_almost_eq(state.household.home_buff("xp"), 0.05, 0.0001, "two bookshelves count once")
	assert_almost_eq(state.household.home_buff("crit"), 0.03, 0.0001)
	assert_almost_eq(state.household.home_buff("gold"), 0.05, 0.0001)
	state.roll = func() -> float: return 0.99
	var before: int = state.pack.gold
	state.spoils.defeat_monster(Bestiary.wild(Bestiary.spawn("wolf")), "forest", "", 1)
	assert_eq(state.pack.gold - before, roundi(int(Bestiary.wild(Bestiary.spawn("wolf"))["gold"]) * 1.05), "the rug: +5% gold")


func test_your_own_bed_leaves_you_well_rested() -> void:
	state.new_game("Robin", "warrior")
	_own_house()
	state.world.map_id = "town_house"
	state.household.house_interact(Vector2i.ZERO, "bed")
	assert_eq(state.settlement.house["rested"], 30)
	state.roll = func() -> float: return 0.99
	var plain := Bestiary.xp_for(Bestiary.wild(Bestiary.spawn("wolf")), 1)
	var xp_before: int = state.hero.xp
	state.spoils.defeat_monster(Bestiary.wild(Bestiary.spawn("wolf")), "forest", "", 1)
	assert_eq(state.hero.xp - xp_before, roundi(plain * 1.1), "+10% XP while rested")
	assert_eq(state.settlement.house["rested"], 29, "a fight used")
	state.settlement.house["furniture"] = [{"itemId": "furn_bench", "x": 3, "y": 3}]
	state.household.house_interact(Vector2i.ZERO, "bed")
	assert_eq(state.settlement.house["rested"], 40, "the bench rests you for ten more")


func test_no_furniture_in_the_doorway_and_an_upgrade_moves_whats_in_the_way() -> void:
	state.new_game("Robin", "warrior")
	_own_house()
	state.world.map_id = "town_house"
	state.pack.items["furn_plant"] = 1
	assert_string_contains(state.household.place_furniture("furn_plant", Vector2i(8, 8), "floor"), "doorway")
	assert_eq(state.pack.items.get("furn_plant", 0), 1, "still in the pack")
	# A piece where the cottage puts a wall comes home to the pack.
	var cottage := MapData.load_by_id("town_house@2")
	var blocked := Vector2i(-1, -1)
	for y in cottage.size.y:
		for x in cottage.size.x:
			if blocked.x < 0 and cottage.tile_at(Vector2i(x, y)) != "floor" and MapData.load_by_id("town_house").tile_at(Vector2i(x, y)) == "floor":
				blocked = Vector2i(x, y)
	if blocked.x < 0:
		pass_test("the cottage keeps every floor tile of the hut")
		return
	state.settlement.house["furniture"] = [{"itemId": "furn_rug", "x": blocked.x, "y": blocked.y}]
	state.world.map_id = "town_shop"
	state.pack.gold = 100000
	var line: String = state.household.buy_house_upgrade()
	assert_string_contains(line, "back in your pack")
	assert_true(state.household.furniture().is_empty())
	assert_eq(state.pack.items.get("furn_rug", 0), 1)


func test_an_upgrade_moves_whats_where_a_fixture_reaches() -> void:
	# The cottage's hearth stands two tiles tall on the hut's open floor
	# (PIX-237): a piece there would be drawn over it.
	state.new_game("Robin", "warrior")
	_own_house()
	var hut := MapData.load_by_id("town_house")
	var cottage := MapData.load_by_id("town_house@2")
	var under := Vector2i(-1, -1)
	var over: Dictionary = PunyInterior.plan(cottage.id, cottage.grid)["over"]
	for cell: Vector2i in over:
		if over[cell] == "hearth" and cottage.tile_at(cell) == "floor" and hut.tile_at(cell) == "floor":
			under = cell
	assert_gt(under.x, -1, "the hearth reaches onto the hut's floor")
	state.settlement.house["furniture"] = [
		{"itemId": "furn_plant", "x": under.x, "y": under.y}, {"itemId": "furn_rug", "x": 10, "y": 8},
	]
	state.world.map_id = "town_shop"
	state.pack.gold = 100000
	assert_string_contains(state.household.buy_house_upgrade(), "1 piece of furniture had to move")
	assert_eq(state.household.furniture(), [{"itemId": "furn_rug", "x": 10, "y": 8}], "the rug in the open stays")
	assert_eq(state.pack.items.get("furn_plant", 0), 1, "the plant by the hearth comes home")


func test_the_manor_garden_grows_for_the_cauldron() -> void:
	assert_eq(Town.garden_yield(0), "forest_herb")
	assert_eq(Town.garden_yield(1), "marsh_reed")
	assert_eq(int(Town._data()["gardenCount"]), 2)
