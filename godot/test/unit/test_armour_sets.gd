extends GutTest
## Armour sets (PIX-166): pieces worn together grant more, at three and at
## five; the bonus shows in the stats and on every piece, and Saltmere's
## Oilskin is crafted at Hilda's from what the coast gives.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "ranger")


func _wear(item_ids: Array) -> void:
	for item_id: String in item_ids:
		var piece := InventoryState.create_gear(item_id)
		state.pack.gear.append(piece)
		state.equip(piece["uid"])


func test_every_set_piece_is_in_its_set_and_drawn() -> void:
	for set_id: String in Catalog._data()["sets"]:
		var entry := Catalog.armour_set(set_id)
		assert_eq(entry["pieces"].size(), 5, "%s has five pieces" % set_id)
		var slots := {}
		for item_id: String in entry["pieces"]:
			var item := Catalog.item(item_id)
			assert_eq(item.get("set", ""), set_id, item_id)
			assert_ne(ItemIcons.source(item_id), "", "%s has an icon" % item_id)
			slots[item["slot"]] = true
		assert_eq(slots.size(), 5, "%s: one piece per slot" % set_id)


func test_three_and_five_pieces_grant_more() -> void:
	var dex_before := HeroRules.effective_stat(state.hero, state.pack, "dexterity")
	_wear(["oilskin_hood", "oilskin_coat"])
	var two := HeroRules.effective_stat(state.hero, state.pack, "dexterity")
	assert_eq(two, dex_before + 2, "the pieces' own grants only")
	_wear(["oilskin_gloves"])
	assert_eq(HeroRules.effective_stat(state.hero, state.pack, "dexterity"), dex_before + 3 + 2, "three pieces: +2 DEX")
	var armor_three := HeroRules.total_armor(state.pack)
	_wear(["oilskin_boots", "saltwood_buckler"])
	assert_eq(HeroRules.effective_stat(state.hero, state.pack, "dexterity"), dex_before + 3 + 2 + 3)
	assert_eq(HeroRules.total_armor(state.pack), armor_three + 2 + 4 + 3, "boots, buckler, and the set's +3")
	assert_string_contains(Catalog.set_line("oilskin", 5), "Saltmere Oilskin (5/5)")


func test_the_oilskin_is_crafted_from_the_coast() -> void:
	for item_id: String in Catalog.armour_set("oilskin")["pieces"] + ["tidecutter"]:
		var recipes: Array = Economy._data()["recipes"].filter(func(r: Dictionary) -> bool: return r["itemId"] == item_id)
		assert_eq(recipes.size(), 1, "%s has a recipe" % item_id)
		assert_true("sea_glass" in recipes[0]["needs"], "%s needs the coast's sea glass" % item_id)
		assert_eq(recipes[0]["job"]["id"], "smithing")
