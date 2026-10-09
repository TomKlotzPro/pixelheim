extends GutTest
## Early stakes and rewards (PIX-206): a fall is no cheaper than a bed and
## wakes nothing, health trickles back at rest, deliveries say how they
## stand and are asked before they're spent, the Hamlet's projects each
## bring a perk, and no two people on a map share a face.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.settlement.town_tier = 1


func test_a_fall_costs_at_least_a_night_at_the_inn() -> void:
	var bed := Town.rest_cost_for(1)
	state.pack.gold = 50
	assert_eq(state.spoils.death_toll(), bed, "a tenth of 50 is less than a bed")
	state.pack.gold = 500
	assert_eq(state.spoils.death_toll(), 50, "a tenth when that's more")
	state.pack.gold = 4
	assert_eq(state.spoils.death_toll(), 4, "no more than the purse")
	state.progression.prologue = Prologue.SCAVENGER
	assert_eq(state.spoils.death_toll(), 0, "the night of the fire is free")


func test_health_trickles_back_at_rest() -> void:
	state.hero.hp = 10
	state.upkeep.regen_resting()
	assert_eq(state.hero.hp, 10 + state.upkeep.rest_mend())
	assert_lt(state.upkeep.rest_mend(), 3, "slowly: a bed or a potion is quicker")
	state.hero.hp = 0
	state.upkeep.regen_resting()
	assert_eq(state.hero.hp, 0, "the fallen don't mend")


func test_a_delivery_says_how_it_stands_as_items_come() -> void:
	state.progression.quests["iva_reeds"] = {"progress": 0, "done": false}
	state.questing.note_deliveries(false)
	var heard: Array = []
	state.noted.connect(func(lines: Array) -> void: heard.append_array(lines))
	state.pack.add_item("marsh_reed", 1)
	state.pack_changed()
	assert_eq(heard.size(), 1)
	assert_string_ends_with(heard[0], ": 1/3.")
	state.pack.add_item("marsh_reed", 2)
	state.pack_changed()
	assert_string_contains(heard[1], "ready to hand in to")
	state.pack_changed()
	assert_eq(heard.size(), 2, "nothing new, nothing said")


func test_spending_what_a_delivery_needs_asks_first() -> void:
	state.progression.quests["iva_reeds"] = {"progress": 0, "done": false}
	state.pack.add_item("marsh_reed", 3)
	assert_false(state.questing.delivery_dip({"marsh_reed": 2}).is_empty(), "it would set the reeds back")
	assert_true(state.questing.delivery_dip({"wolf_pelt": 2}).is_empty(), "other goods are free to spend")
	var asked: String = state.questing.ask_before_dip("project:odos_store", {"marsh_reed": 2})
	assert_string_contains(asked, "again")
	assert_eq(state.questing.ask_before_dip("project:odos_store", {"marsh_reed": 2}), "", "asked twice, it goes ahead")
	state.pack.add_item("marsh_reed", 3)
	assert_true(state.questing.delivery_dip({"marsh_reed": 2}).is_empty(), "with reeds to spare, no question")


func test_each_hamlet_project_brings_a_perk() -> void:
	for entry: Dictionary in Town.age(1)["projects"]:
		assert_true(entry.has("perk"), "%s says what it brings" % entry["id"])
	# In the Ashes, before anything is rebuilt.
	state.settlement.town_tier = 0
	assert_eq(state.trade.sale_multiplier("odo"), 1.0)
	state.settlement.projects.assign(["odos_store", "hildas_forge", "vexs_brewery", "the_inn"])
	assert_almost_eq(state.trade.sale_multiplier("odo"), 1.1, 0.0001, "Odo pays a tenth more")
	assert_eq(state.trade.sale_multiplier("smith"), 1.0, "only Odo")
	var sword := InventoryState.create_gear("rusty_sword")
	var full := Economy.forge_cost_for("rusty_sword", 0, 1)
	assert_eq(state.trade.forge_price(sword, 1, false), roundi(full * 0.9), "Hilda forges a tenth cheaper")


func test_a_night_at_the_rebuilt_inn_leaves_you_rested() -> void:
	state.settlement.town_tier = 0
	state.pack.gold = 100
	state.hero.hp = 1
	state.upkeep.rest_at_inn()
	assert_eq(int(state.settlement.house.get("rested", 0)), 0, "no inn, no rest worth the name")
	state.settlement.projects.assign(["the_inn"])
	state.hero.hp = 1
	state.upkeep.rest_at_inn()
	assert_eq(int(state.settlement.house.get("rested", 0)), int(Town._data()["rested"]["innFights"]))


func test_no_two_people_on_a_map_share_a_face() -> void:
	var faces := Npcs.face_indexes()
	var seen := {}
	for person: Dictionary in Npcs.people():
		var index: int = faces[person["id"]]
		assert_lt(index, Npcs.FACE_TINTS.size(), "%s has a tint of its own" % person["id"])
		for map_id: String in person["maps"]:
			var key := "%s|%s|%d" % [map_id, person["look"], index]
			assert_false(seen.has(key), "%s and %s look alike on %s" % [person["id"], seen.get(key, ""), map_id])
			seen[key] = person["id"]
	assert_ne(Npcs.tint_of("villager_ana"), Npcs.tint_of("settler_iva"), "Ana and Iva, both in purple, side by side in town")
