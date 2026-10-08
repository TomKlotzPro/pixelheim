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
	assert_eq(state.buy_house(), "For sale: this house. The deed costs 1500g.")
	state.pack.gold = 2000
	assert_eq(state.buy_house(), "The deed is yours. Welcome home.")
	assert_true(state.owns_house())
	assert_eq(state.pack.gold, 500)
	assert_eq(state.buy_house(), "", "once")


func test_odo_sells_the_bigger_deeds_in_order_and_gated_on_gold() -> void:
	assert_eq(Town.next_house_tier(false, 1), {}, "no house, no bigger deed")
	_own_house(20000)
	state.world.map_id = "town_smith"
	assert_eq(state.buy_house_upgrade(), "", "only Odo sells deeds")
	state.world.map_id = "town_shop"
	assert_string_contains(state.buy_house_upgrade(), "COTTAGE")
	assert_eq(int(state.settlement.house["tier"]), 2)
	assert_string_contains(state.buy_house_upgrade(), "MANOR")
	assert_eq(state.pack.gold, 20000 - 5000 - 12000)
	assert_eq(state.buy_house_upgrade(), "", "the Manor is the top")


func test_each_tier_has_its_own_interior() -> void:
	var sizes := [1, 2, 3].map(func(tier: int) -> Vector2i: return MapData.load_tiered("town_house", [], tier).size)
	assert_eq(sizes[0], Vector2i(20, 12))
	assert_eq(sizes[1], Vector2i(26, 12))
	assert_eq(sizes[2], Vector2i(30, 14))
	assert_true(MapData.load_tiered("town_house", [], 3).grid.values().has("cauldron"))


func test_storage_moves_stacks_between_pack_and_home() -> void:
	assert_false(state.store_item("potion_hp"), "no house, no barrel")
	_own_house()
	assert_true(state.store_item("potion_hp", 5))
	assert_false(state.pack.items.has("potion_hp"), "only what you carry: both potions")
	assert_eq(state.settlement.house["storage"], {"potion_hp": 2})
	assert_true(state.take_item("potion_hp"))
	assert_eq(state.pack.items["potion_hp"], 1)
	assert_eq(state.settlement.house["storage"], {"potion_hp": 1})


func test_trophies_buff_while_displayed_and_give_it_back() -> void:
	_own_house()
	var defense: int = state.hero.stats["defense"]
	var strength: int = state.hero.stats["strength"]
	state.pack.items["lich_crown"] = 1
	assert_true(state.display_trophy("lich_crown"))
	assert_eq(state.hero.stats["defense"], defense + 2)
	assert_eq(state.hero.stats["strength"], strength + 2)
	assert_false(state.pack.items.has("lich_crown"))
	assert_false(state.display_trophy("lich_crown"), "one of each on the shelf")
	assert_true(state.take_trophy("lich_crown"))
	assert_eq(state.hero.stats["defense"], defense)
	assert_eq(state.hero.stats["strength"], strength)
	state.pack.items["bread"] = 1
	assert_false(state.display_trophy("bread"), "bread is not a trophy")


func test_the_nook_distills_two_brews_into_a_better_one() -> void:
	state.pack.items = {"potion_hp": 3}
	assert_eq(state.combine_potions("potion_hp"), "The nook bubbles: 2x Health Potion became Greater Health Potion.")
	assert_eq(state.pack.items, {"potion_hp": 1, "greater_potion": 1})
	assert_eq(state.combine_potions("potion_hp"), "", "it takes two")


func test_furniture_places_on_floor_and_comes_back_with_a_touch() -> void:
	_own_house()
	state.world.map_id = "town_house"
	state.pack.items["furn_plant"] = 1
	var spot := Vector2i(5, 5)
	assert_eq(state.place_furniture("furn_plant", spot, "wall"), "It needs open floor. Face a free tile and try again.")
	assert_eq(state.place_furniture("furn_plant", spot, "floor"), "Potted Fern placed. E takes it back.")
	assert_eq(state.furniture(), [{"itemId": "furn_plant", "x": 5, "y": 5}])
	assert_false(state.pack.items.has("furn_plant"))
	state.pack.items["furn_plant"] = 1
	assert_eq(state.place_furniture("furn_plant", spot, "floor"), "Something already stands there.")
	var back: Dictionary = state.house_interact(spot, "floor")
	assert_eq(back["text"], "Potted Fern back in the pack.")
	assert_eq(state.pack.items["furn_plant"], 2)
	assert_true(state.furniture().is_empty())
	assert_true(Town.furniture_blocks("furn_plant"))
	assert_false(Town.furniture_blocks("furn_rug"))


func test_fixtures_answer_to_e() -> void:
	_own_house(1000)
	state.world.map_id = "town_house"
	state.hero.hp = 1
	assert_eq(state.house_interact(Vector2i.ZERO, "bed")["text"], "Your own bed. Fully rested, free of charge.")
	assert_eq(state.hero.hp, state.hero.stats["maxHp"])
	assert_eq(state.house_interact(Vector2i.ZERO, "barrel"), {"panel": "storage"})
	assert_eq(state.house_interact(Vector2i.ZERO, "trophy_shelf"), {"panel": "trophies"})
	assert_eq(state.house_interact(Vector2i.ZERO, "cauldron"), {"panel": "nook"})
	assert_string_contains(state.house_interact(Vector2i.ZERO, "garden")["text"], "0/6")
	assert_eq(state.house_interact(Vector2i.ZERO, "wall"), {})
	assert_eq(state.house_interact(Vector2i.ZERO, "floor"), {}, "no furniture to place")


func test_the_shelf_sells_then_hosts_the_workbench() -> void:
	_own_house(500)
	state.world.map_id = "town_house"
	assert_string_contains(state.house_interact(Vector2i.ZERO, "shelf")["text"], "800g")
	state.pack.gold = 900
	assert_string_contains(state.house_interact(Vector2i.ZERO, "shelf")["text"], "Craft at home, forever")
	assert_true(state.settlement.house["workbench"])
	assert_eq(state.pack.gold, 100)
	assert_eq(state.house_interact(Vector2i.ZERO, "shelf"), {"panel": "workbench"})


func test_the_garden_alternates_bread_and_cheese() -> void:
	assert_eq([0, 1, 2, 3].map(Town.garden_yield), ["bread", "cheese_wheel", "bread", "cheese_wheel"])


func test_house_records_round_trip_in_the_web_shape() -> void:
	_own_house(20000)
	state.world.map_id = "town_house"
	state.pack.items.merge({"furn_rug": 1, "gem": 1})
	state.place_furniture("furn_rug", Vector2i(3, 3), "floor")
	state.display_trophy("gem")
	var house: Dictionary = state.to_dict()["house"]
	assert_eq(house["furniture"], [{"itemId": "furn_rug", "x": 3, "y": 3}])
	assert_eq(house["trophies"], ["gem"])
	assert_eq(state.trophy_sell_multiplier(), 1.1)
