extends GutTest
## Endgame gear and gold (PIX-218): deep-forged pieces for every slot, their
## bonus kept apart so the forge still works on one, the tiers counting on
## past the last name, and Hilda's quench a sink that grows. The Deep Hunt
## forged them; since PIX-257 the Kings' Vault does, floor by floor, and an
## old save's deep pieces keep working.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_vaults_band_covers_every_slot() -> void:
	var slots := {}
	for item_id: String in Bestiary._data()["dropPools"][-1]["gearIds"]:
		slots[Catalog.item(item_id)["slot"]] = true
	for slot: String in ["weapon", "body", "offhand", "head", "hands", "feet", "neck", "ring"]:
		assert_true(slots.has(slot), "deep %s" % slot)


func test_a_vault_drop_comes_forged_from_the_vaults_band() -> void:
	var deep_ids: Array = Bestiary._data()["dropPools"][-1]["gearIds"]
	var seen := 0
	for seed in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var drop := Bestiary.roll_drop(int(Bestiary.region("vault")["dropFloor"]), "elite", func() -> float: return rng.randf(), Depths.forged("vault_5"))
		if drop.get("kind", "") == "gear":
			assert_has(deep_ids, drop["gear"]["itemId"])
			assert_eq(int(drop["gear"]["deep"]), Depths.forged("vault_5"))
			seen += 1
	assert_gt(seen, 0, "some gear fell")


func test_the_deep_bonus_stands_apart_so_the_forge_still_works() -> void:
	var piece := InventoryState.create_gear("city_plate", "epic")
	var forged := int(piece["bonus"])
	InventoryState.deepen(piece, 6)
	assert_eq(int(piece["bonus"]), forged, "the forge's bonus stays the forge's")
	assert_eq(int(piece["deepBonus"]), int(Economy._data()["deepTiers"]["bonus"]) * 6)
	assert_eq(HeroRules.gear_armor(piece), int(Catalog.item("city_plate")["armor"]) + forged + int(piece["deepBonus"]), "and still counts")
	assert_lt(int(piece["bonus"]), Economy.forge_cap_for(1), "Hilda can forge it")


func test_a_deep_piece_from_before_is_mended_once() -> void:
	var old := InventoryState.create_gear("city_plate", "epic")
	old["deep"] = 4
	old["bonus"] = 3 + int(Economy._data()["deepTiers"]["bonus"]) * 4
	var pack := InventoryState.from_dict({"gold": 0, "inventory": {}, "gear": [old], "equipped": {}})
	assert_eq(int(pack.gear[0]["bonus"]), 3, "the forge's three, back")
	assert_eq(int(pack.gear[0]["deepBonus"]), int(Economy._data()["deepTiers"]["bonus"]) * 4)
	var again := InventoryState.new()
	pack.write_into({})
	var saved := {}
	pack.write_into(saved)
	again = InventoryState.from_dict(saved)
	assert_eq(int(again.gear[0]["bonus"]), 3, "and never twice")


func test_tiers_count_on_past_the_last_name() -> void:
	var names: Array = Economy._data()["deepTiers"]["names"]
	assert_eq(InventoryState.deep_name(names.size()), names[-1])
	assert_eq(InventoryState.deep_name(names.size() + 1), "%s II" % names[-1])
	assert_eq(InventoryState.deep_name(names.size() + 5), "%s VI" % names[-1])
	assert_eq(float(Economy._data()["deepTiers"]["valuePerTier"]), 0.25)


func test_quenching_is_a_sink_that_grows() -> void:
	var piece := InventoryState.deepen(InventoryState.create_gear("obsidian_blade", "fine"), 3)
	state.pack.gear.append(piece)
	state.world.map_id = "town_smith"
	state.pack.gold = 100000
	var first := Economy.quench_cost(piece)
	assert_eq(state.trade.quench_gear(piece["uid"]), "", "no gem, no quench")
	state.pack.add_item("gem", 3)
	var stat := Economy.quench_stat(piece)
	var before := int(InventoryState.shown_affixes(piece).get(stat, 0))
	assert_ne(state.trade.quench_gear(piece["uid"]), "")
	assert_eq(int(InventoryState.shown_affixes(piece)[stat]), before + 1)
	assert_eq(Economy.quench_cost(piece), roundi(first * 1.5), "each time half again")
	assert_eq(state.pack.gold, 100000 - first)
	assert_eq(int(state.pack.items["gem"]), 2)
	var plain := InventoryState.create_gear("obsidian_blade")
	state.pack.gear.append(plain)
	assert_eq(state.trade.quench_gear(plain["uid"]), "", "only what came from the deep")
