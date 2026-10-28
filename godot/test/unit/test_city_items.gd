extends GutTest
## The City's three showpieces, each with a rule of its own (PIX-376): the
## Aegis of the Ash takes a fight's first blow whole, the Everflask fills
## itself again overnight, the King's Signet adds a tenth to the gold earned.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.world.map_id = "town_shop"


func _wear(item_id: String) -> void:
	var piece := InventoryState.create_gear(item_id)
	state.pack.gear.append(piece)
	state.upkeep.equip(piece["uid"])


func test_the_aegis_blocks_only_a_fights_first_blow() -> void:
	assert_false(state.upkeep.wards(100.0), "nothing worn, nothing warded")
	_wear("aegis_of_the_ash")
	assert_false(state.upkeep.wards(105.0), "mid-fight: the blow lands")
	assert_true(state.upkeep.wards(115.0), "ten quiet seconds: a new fight's first, warded")
	assert_false(state.upkeep.wards(116.0), "its second lands")
	assert_false(state.upkeep.wards(125.5), "a blow every 9.5 s is still one fight")
	assert_true(state.upkeep.wards(135.5), "after a calm, warded again")


func test_the_everflask_empties_and_fills_again_at_the_inn() -> void:
	state.pack.add_item("everflask")
	state.hero.hp = 1
	assert_true(state.upkeep.use_item("everflask")["used"])
	assert_eq(int(state.hero.hp), int(state.hero.stats["maxHp"]), "everything back")
	assert_false(state.pack.items.has("everflask"), "drunk")
	assert_eq(int(state.pack.items.get("everflask_empty", 0)), 1, "kept, empty")
	assert_false(state.upkeep.use_item("everflask_empty")["used"], "nothing in it to drink")
	state.pack.gold = 1000
	state.upkeep.rest_at_inn()
	assert_eq(int(state.pack.items.get("everflask", 0)), 1, "full again by morning")
	assert_false(state.pack.items.has("everflask_empty"))


func test_the_signet_adds_a_tenth_to_a_kills_gold_and_a_sale() -> void:
	var foe := Bestiary.spawn("frost_wolf")
	assert_eq(int(state.spoils.defeat_monster(foe, "frost", "", 14)["gains"]["gold"]), int(foe["gold"]), "bare-handed")
	var rate := Economy.sell_price_at(state.trade.active_shop(), "wolf_pelt", state.town_tier())
	_wear("kings_signet")
	assert_eq(int(state.spoils.defeat_monster(foe, "frost", "", 14)["gains"]["gold"]), roundi(int(foe["gold"]) * 1.1))
	state.pack.add_item("wolf_pelt")
	assert_eq(state.trade.sell_item("wolf_pelt"), floori(rate * 1.1), "a sale too")
	assert_eq(state.pack.earn(100), 110, "and a quest's purse, a tip, a chest")
