extends GutTest
## Loot that fits the stage (PIX-183): a wild kill rolls the pool of its own
## level (capped by its region's), species follow their region's weights, a
## set's tiers add up, and the later set guards better than the earlier.


func test_no_region_rolls_loot_above_its_foes() -> void:
	for region_id: String in Bestiary._data()["regions"]:
		var cap := int(Bestiary.region(region_id)["dropFloor"])
		for entry: Dictionary in Bestiary.region(region_id)["monsters"]:
			var foe := Bestiary.spawn(entry["monsterId"])
			var level := int(Bestiary.monster(entry["monsterId"])["level"])
			var floor := Bestiary.wild_drop_floor(region_id, foe)
			assert_lte(floor, level, "%s in %s rolls at most its own level" % [entry["monsterId"], region_id])
			assert_lte(floor, cap, "and never above %s's pool" % region_id)
	var skeleton := Bestiary.spawn("skeleton")
	var mimic := Bestiary.spawn("mimic")
	assert_lt(Bestiary.wild_drop_floor("mire", skeleton), Bestiary.wild_drop_floor("mire", mimic), "the Mirefen's skeletons drop less than its mimics")


func test_species_follow_their_regions_weights() -> void:
	var counts := {}
	for x in 40:
		for y in 40:
			var kind := Bestiary.species_at("ash", Vector2i(x, y))
			counts[kind] = int(counts.get(kind, 0)) + 1
	assert_almost_eq(float(counts["orc"]) / 1600.0, 0.5, 0.06, "orcs weigh 4 of 8 in the Ash Fields")
	assert_almost_eq(float(counts["imp"]) / 1600.0, 0.25, 0.06)


func test_the_pack_by_the_hub_is_no_imp_pack() -> void:
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if spawn["id"] == "ash_1":
			assert_eq(spawn["species"], "orc")


func test_a_sets_tiers_add_up() -> void:
	var line := Catalog.set_line("oilskin", 5)
	assert_string_contains(line, "3 pieces +2 DEX")
	assert_string_contains(line, "5 pieces +5 DEX, +3 armor", "the five-piece bonus counts the three-piece one")


func test_the_later_set_guards_better() -> void:
	var total := func(set_id: String) -> int:
		var sum := 0
		for piece: String in Catalog.armour_set(set_id)["pieces"]:
			sum += int(Catalog.item(piece).get("armor", 0))
		for at: String in Catalog.armour_set(set_id)["bonuses"]:
			sum += int(Catalog.armour_set(set_id)["bonuses"][at].get("armor", 0))
		return sum
	assert_gt(total.call("warden"), total.call("blackiron"), "Greyhold comes after Blackiron")


func test_the_mirefen_maze_holds_no_endgame_blade() -> void:
	for chest: Dictionary in Interactables._data()["chests"]:
		if chest["id"] == "mire_maze":
			assert_ne(chest["loot"]["itemId"], "obsidian_blade")
