extends GutTest
## Shops that follow the story (PIX-176): before the mountain the shops'
## stock grows with the relics won, mana and cures are on sale from the
## start, and every region's hub has a trader with its own pack.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const TRADERS := {"chandler": "saltmere", "quartermaster": "blackiron", "sutler": "greyhold", "caravan": "frostgate"}

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_stock_grows_with_the_relics_then_the_floors() -> void:
	assert_eq(Economy.stock_stage(1, 0), 3, "a new hero's shops are no longer floor one's")
	var last := 0
	var stocked := 0
	for relics in 5:
		var stage := Economy.stock_stage(1, relics)
		assert_gt(stage, last, "each relic brings more")
		var count := 0
		for shop_id: String in ["odo", "smith", "alchemist"]:
			count += Economy.shop_stock(shop_id, stage).size()
		assert_gt(count, stocked, "relic %d puts something new on the shelves" % relics)
		stocked = count
		last = stage
	assert_eq(Economy.stock_stage(13, 4), 13, "on the mountain the floors lead")
	state.progression.hunted.append("tidecaller")
	assert_eq(state.stock_stage(), Economy.stock_stage(1, 1))


func test_mana_and_cures_from_the_first_day() -> void:
	var stock := Economy.shop_stock("alchemist", state.stock_stage())
	assert_has(stock, "potion_mp")
	assert_has(stock, "antidote")


func test_every_region_has_a_trader() -> void:
	for shop_id: String in TRADERS:
		var shop := Economy.shop(shop_id)
		assert_false(shop.is_empty(), shop_id)
		var keepers: Array = Npcs._data()["npcs"].filter(func(npc: Dictionary) -> bool: return npc.get("shop", "") == shop_id)
		assert_eq(keepers.size(), 1, "%s has a keeper" % shop_id)
		var keeper: Dictionary = keepers[0]
		assert_eq(keeper["mapId"], TRADERS[shop_id])
		assert_true(MapData.load_by_id(keeper["mapId"]).is_walkable(Vector2i(int(keeper["x"]), int(keeper["y"]))), "%s stands on open ground" % keeper["id"])
		var stock := Economy.shop_stock(shop_id, 1)
		assert_gt(stock.size(), 5, "%s has a full pack" % shop_id)
		for item_id: String in stock:
			assert_false(Catalog.item(item_id).is_empty(), item_id)


func test_buying_from_a_trader() -> void:
	state.stall_shop = "chandler"
	state.pack.gold = 500
	var gold: int = state.pack.gold
	assert_true(state.buy_item("longbow"))
	assert_eq(state.pack.gold, gold - Economy.buy_price("longbow"))
	state.stall_shop = ""
