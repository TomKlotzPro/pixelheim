extends GutTest
## The pack (reducers/inventory.ts EQUIP/UNEQUIP/DROP/DROP_GEAR, USE_ITEM)
## and the row's stat line (economy/itemStats.ts, printed from the web).

const GameStateScript := preload("res://scripts/state/game_state.gd")
const InventoryScreen := preload("res://scripts/inventory_screen.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _piece(item_id: String, rarity := "common") -> Dictionary:
	var piece := InventoryState.create_gear(item_id, rarity)
	state.pack.gear.append(piece)
	return piece


func test_gear_goes_on_in_its_slot_and_comes_off() -> void:
	var armor := _piece("leather_armor")
	assert_true(state.equip(armor["uid"]))
	assert_eq(state.pack.equipped["body"], armor["uid"])
	assert_false(state.equip(armor["uid"]), "already worn")
	var sword := _piece("iron_sword")
	var old_weapon: String = state.pack.equipped["weapon"]
	assert_true(state.equip(sword["uid"]))
	assert_eq(state.pack.equipped["weapon"], sword["uid"], "the old blade goes back to the pack")
	assert_false(state.pack.is_equipped(old_weapon))
	assert_true(state.unequip("body"))
	assert_false(state.pack.equipped.has("body"))
	assert_false(state.unequip("body"), "nothing left to take off")


func test_rings_fill_the_empty_finger_first() -> void:
	var first := _piece("band_of_grit")
	var second := _piece("ring_of_clarity")
	var third := _piece("quickstep_ring")
	state.equip(first["uid"])
	state.equip(second["uid"])
	assert_eq([state.pack.equipped["ring1"], state.pack.equipped["ring2"]], [first["uid"], second["uid"]])
	state.equip(third["uid"])
	assert_eq(state.pack.equipped["ring1"], third["uid"], "both full: the first finger trades")


func test_dropping_never_takes_what_is_worn() -> void:
	var worn: String = state.pack.equipped["weapon"]
	assert_false(state.drop_gear(worn))
	var spare := _piece("iron_sword")
	assert_true(state.drop_gear(spare["uid"]))
	assert_true(state.pack.gear_by_uid(spare["uid"]).is_empty())
	state.pack.items["wolf_pelt"] = 3
	assert_true(state.drop_item("wolf_pelt"))
	assert_eq(state.pack.items["wolf_pelt"], 2)
	assert_true(state.drop_item("wolf_pelt", 2))
	assert_false(state.pack.items.has("wolf_pelt"))
	assert_false(state.drop_item("wolf_pelt"))


func test_potions_heal_up_to_the_cap() -> void:
	state.pack.items["potion_hp"] = 1
	state.hero.hp = int(state.hero.stats["maxHp"]) - 10
	var result: Dictionary = state.use_item("potion_hp")
	assert_true(result["used"])
	assert_eq(state.hero.hp, int(state.hero.stats["maxHp"]), "+25 tops out at the max")
	assert_eq(result["text"], "You use Health Potion. Restored 10 HP.")
	assert_false(state.pack.items.has("potion_hp"))
	assert_false(state.use_item("potion_hp")["used"], "none left")
	state.pack.items["wolf_pelt"] = 1
	assert_false(state.use_item("wolf_pelt")["used"], "pelts aren't for eating")


func test_remedies_name_the_ailment_they_cure() -> void:
	state.pack.items["antidote"] = 1
	assert_eq(state.use_item("antidote")["cures"], "poison")
	var ailments := Ailments.new()
	ailments.inflict({"kind": "poison", "chance": 1.0, "turns": 3, "power": 4}, func() -> float: return 0.0)
	assert_true(ailments.cure("poison"))
	assert_eq(ailments.kinds(), [])
	assert_false(ailments.cure("poison"))


func test_rows_print_the_webs_stat_line() -> void:
	var expected := {
		"iron_sword": [2, 120, "DMG 10 (8+2) STR  9 wt  120g"],
		"leather_armor": [0, 45, "ARMOR 3  10 wt  45g"],
		"band_of_grit": [0, 55, "+1 STR  0 wt  55g"],
		"antidote": [0, 30, "+5 HP  cures poison  1 wt  30g"],
		"potion_hp": [0, 25, "+25 HP  1 wt  25g"],
		"mage_robe": [1, 99, "ARMOR 5 (4+1)  4 wt  99g"],
		"apprentice_staff": [0, 40, "DMG 7 INT  5 wt  40g"],
	}
	for item_id: String in expected:
		var row: Array = expected[item_id]
		assert_eq(InventoryScreen.stat_line(Catalog.item(item_id), row[0], row[1]), row[2], item_id)


## The pack's listing (PIX-89): a tab's rows in the chosen order.
func test_the_pack_lists_by_kind_value_weight_or_name() -> void:
	state.pack.gear.clear()
	state.pack.equipped.clear()
	_piece("rusty_sword")
	_piece("iron_armor")
	state.pack.items = {"potion_hp": 2, "wolf_pelt": 1, "bread": 3}
	var names := func(rows: Array) -> Array:
		return rows.map(func(row: Dictionary) -> String: return String(row["item_id"]))
	var by_kind: Array = names.call(state.pack.listing("all", "kind"))
	assert_eq(by_kind.slice(0, 2), ["iron_armor", "rusty_sword"], "gear first, by category then name")
	var by_value: Array = state.pack.listing("all", "value")
	for i in by_value.size() - 1:
		assert_true(_value(by_value[i]) >= _value(by_value[i + 1]), "dearest first")
	var by_weight: Array = state.pack.listing("all", "weight")
	for i in by_weight.size() - 1:
		assert_true(int(Catalog.item(by_weight[i]["item_id"])["weight"]) >= int(Catalog.item(by_weight[i + 1]["item_id"])["weight"]), "heaviest first")
	var by_name: Array = names.call(state.pack.listing("all", "name"))
	var labels := by_name.map(func(id: String) -> String: return Catalog.item_name(id))
	var sorted := labels.duplicate()
	sorted.sort()
	assert_eq(labels, sorted)
	assert_eq(names.call(state.pack.listing("potions", "value")), ["potion_hp"], "a tab keeps to its category")


func _value(row: Dictionary) -> int:
	return Economy.gear_value(row["piece"]) if row["kind"] == "gear" else int(Catalog.item(row["item_id"])["value"])

