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
	assert_almost_eq(float(counts["orc"]) / 1600.0, 0.667, 0.06, "orcs weigh 4 of 6 in the Ash Fields")
	assert_almost_eq(float(counts["wyvern"]) / 1600.0, 0.333, 0.06)
	assert_false(counts.has("imp"), "PIX-203: no imps in the Ash - they never could spawn there")


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


## PIX-191: a loot curve worth chasing.
func _dice(values: Array) -> Callable:
	var sequence := values.duplicate()
	return func() -> float: return sequence.pop_front() if not sequence.is_empty() else 0.5


func _best(pool: Dictionary, stat := "") -> int:
	var best := 0
	for item_id: String in pool["gearIds"]:
		var item := Catalog.item(item_id)
		if stat == "" or item.get("scaling", "") == stat:
			best = maxi(best, int(item.get("damage", 0)))
	return best


func test_each_band_of_the_mountain_is_a_step() -> void:
	var pools: Array = Bestiary._data()["floorPools"]["pools"]
	for i in range(1, pools.size()):
		assert_gte(_best(pools[i]), _best(pools[i - 1]), "floor %d's pool is no step down" % pools[i]["floor"])
	assert_gt(_best(pools[-1]), _best(pools[0]), "the deep floors beat the first")
	for stat: String in ["strength", "intelligence", "dexterity"]:
		assert_gt(_best(pools[-1], stat), _best(pools[0], stat), "a %s hero has better to find deeper" % stat)


func test_the_mountain_rolls_its_own_floors_pool() -> void:
	# Drop, gear, pick the first item, common: the floor's pool decides.
	var first := Bestiary.roll_drop(1, "normal", _dice([0.0, 0.0, 0.0, 0.0]), 2)
	assert_eq(first["gear"]["itemId"], Bestiary._data()["floorPools"]["pools"][0]["gearIds"][0])
	var deep := Bestiary.roll_drop(1, "normal", _dice([0.0, 0.0, 0.0, 0.0]), 13)
	assert_eq(deep["gear"]["itemId"], "obsidian_blade", "floor 13 rolls the deepest pool")


func test_a_boss_always_drops_gear() -> void:
	for roll in [0.0, 0.5, 0.99]:
		var drop := Bestiary.roll_drop(10, "boss", _dice([roll, roll, roll, roll, roll, roll]), 10)
		assert_eq(drop["kind"], "gear", "whatever the dice (%s)" % roll)


func test_fine_and_epic_gear_carry_affixes_that_count() -> void:
	assert_false(InventoryState.create_gear("iron_sword").has("affixes"), "common gear is plain")
	var fine := InventoryState.create_gear("iron_sword", "fine", _dice([0.0, 0.0, 0.0]))
	assert_eq(fine["affixes"].size(), 1)
	var epic := InventoryState.create_gear("iron_sword", "epic", _dice([0.0, 0.1, 0.5, 0.9, 0.5]))
	assert_eq(epic["affixes"].size(), 2)
	assert_string_contains(InventoryState.gear_name(fine), "Fine Iron Sword of ")
	var pack := InventoryState.new()
	pack.gear.append(fine)
	pack.equipped["weapon"] = fine["uid"]
	var stat: String = fine["affixes"].keys()[0]
	assert_eq(pack.granted_stat(stat), int(fine["affixes"][stat]), "worn, it grants its affix")
	assert_gt(Economy.gear_value(epic), Economy.gear_value(InventoryState.create_gear("iron_sword", "epic", _dice([0.0]))) - 1)


func test_the_deep_hunt_forges_deeper_every_five_depths() -> void:
	var top := Dungeons.floor_count()
	assert_eq(Dungeons.deep_tier(top), 0)
	assert_eq(Dungeons.deep_tier(top + 1), 1)
	assert_eq(Dungeons.deep_tier(top + 6), 2)
	var drop := Bestiary.roll_drop(1, "elite", _dice([0.0, 0.0, 0.0, 0.0]), top + 6)
	var gear: Dictionary = drop["gear"]
	assert_eq(int(gear["deep"]), 2)
	assert_string_starts_with(InventoryState.gear_name(gear), "Abyssal ")
	assert_gte(int(gear["bonus"]), 4, "two tiers of bonus")
	assert_false(gear["affixes"].is_empty())


func test_casters_and_archers_have_late_weapons_too() -> void:
	var best := {}
	for item_id: String in Catalog._data()["items"]:
		var item := Catalog.item(item_id)
		if item.has("damage"):
			var stat := String(item.get("scaling", "strength"))
			best[stat] = maxi(int(best.get(stat, 0)), int(item["damage"]))
	assert_gte(int(best["intelligence"]), 22)
	assert_gte(int(best["dexterity"]), 21)


func test_dragonbanes_hoard_is_no_step_down() -> void:
	var pools: Array = Bestiary._data()["floorPools"]["pools"]
	for pool: Dictionary in pools:
		if int(pool["floor"]) <= 9:
			assert_lte(_best(pool, "strength"), int(Catalog.item("dragonbane")["damage"]), "floor %d" % pool["floor"])


func test_packs_mix_but_never_hide_a_stronger_kind() -> void:
	var mixed := false
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		var map := MapData.load_by_id(spawn["mapId"])
		var region := map.region_at(Vector2i(spawn["x"], spawn["y"]))
		var leader := Bestiary.pack_species(spawn, region, 0, Vector2i(spawn["x"], spawn["y"]))
		assert_eq(leader, Bestiary.species_of(spawn, region), "the spawn's kind leads")
		for i in range(1, 3):
			var kind := Bestiary.pack_species(spawn, region, i, Vector2i(spawn["x"] + i, spawn["y"]))
			assert_lte(int(Bestiary.monster(kind)["level"]), int(Bestiary.monster(leader)["level"]), "%s's pack: never stronger than its leader (PIX-203)" % spawn["id"])
			mixed = mixed or kind != leader
	assert_true(mixed, "some packs mix their region's kinds")


## PIX-203: the first quest's slimes are where it says, all three.
func test_the_first_fields_hold_what_the_first_quest_asks() -> void:
	var forest := MapData.load_by_id("overworld")
	for spawn: Dictionary in Bestiary.spawns_on("overworld"):
		var region_id := forest.region_at(Vector2i(spawn["x"], spawn["y"]))
		if spawn["id"] == "forest_1":
			for i in 3:
				assert_eq(Bestiary.pack_species(spawn, region_id, i, Vector2i(spawn["x"], spawn["y"])), "slime", "forest_1 is slimes")
		if spawn["id"] in ["ash_1", "ash_2", "ash_3"]:
			for i in 3:
				assert_ne(Bestiary.pack_species(spawn, region_id, i, Vector2i(spawn["x"], spawn["y"])), "wyvern", "%s by the road hides no wyvern" % spawn["id"])
	assert_false("floor" in Quests.where(Quests.by_id("slime_trouble")), "no floor: the old mountain's left play (PIX-257)")
