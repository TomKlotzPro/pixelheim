extends GutTest
## Gathering (PIX-143): patches of each region's material, one on every
## dungeon floor, and the crafting quests that start a trade. Where they
## grow moves with the days (PIX-250): each day deals a few from the
## region's own open ground, the same ones for the same day and others the
## next, never more than the material's daily supply, and what's picked
## stays picked until the next morning.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## Every map with wild patches.
const WILD := ["overworld", "deepwood", "mirefen", "saltmere", "seacave", "blackiron", "shafts", "greyhold", "cellars", "frostgate", "icecave"]
const ROADS := ["path", "bridge", "dock"]
const DAY := DayNight.DAY_CYCLE_STEPS

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_every_region_grows_something_and_the_rarer_less() -> void:
	var materials: Dictionary = Bestiary._data()["regionMaterials"]
	var ground: Dictionary = Gathering.rules()["ground"]
	var daily: Dictionary = Gathering.rules()["daily"]
	for region: String in materials:
		assert_true(ground.has(region), "%s has ground to grow on" % region)
		assert_gt(Gathering.daily_in(region), 0.0, "%s grows some %s" % [region, materials[region]])
	for material: String in daily:
		assert_has(materials.values(), material, "%s grows somewhere" % material)
		# What a day grows of it across its homes is its supply, no more.
		var total := 0.0
		for region: String in materials:
			if materials[region] == material:
				total += Gathering.daily_in(region)
		assert_almost_eq(total, float(daily[material]), 0.001, "%s: %s a day" % [material, daily[material]])
		# Rarer ones rarer: a dearer material never grows more a day.
		for other: String in daily:
			if int(Catalog.item(material)["value"]) > int(Catalog.item(other)["value"]):
				assert_true(float(daily[material]) <= float(daily[other]), "%s no commoner than %s" % [material, other])
	assert_eq(Gathering.daily_in("forest"), 3.0, "the forest's herbs: three a day")
	assert_eq(Gathering.daily_in("mire"), 2.0)
	assert_eq(Gathering.daily_in("coast"), 1.0, "sea glass: two a day, one on the coast and one in its cave")
	assert_eq(Gathering.daily_in("shafts"), 0.5, "blackiron ore: one a day, the shafts' every other day")
	assert_eq(Gathering.daily_in("town"), 0.0)


func test_patches_grow_only_on_their_regions_open_ground() -> void:
	var ground: Dictionary = Gathering.rules()["ground"]
	for map_id: String in WILD:
		var raw := MapData.load_by_id(map_id)
		var map := MapData.load_by_id(map_id)
		var view := MapView.new(map, null)
		view.plan(map.spawn)
		assert_false(view.patch_decks.is_empty(), "%s has ground for patches" % map_id)
		var villagers: Array = Npcs.on_map(map_id, Town.MAX_TIER, []).map(func(npc: Dictionary) -> Vector2i: return Vector2i(int(npc["x"]), int(npc["y"])))
		for region: String in view.patch_decks:
			var deck: Array = view.patch_decks[region]
			assert_gt(deck.size(), 30, "%s: %s has room to move its patches" % [map_id, region])
			for cell: Vector2i in deck:
				var where := "%s: %s at %s" % [map_id, region, cell]
				assert_eq(raw.region_at(cell), region, where)
				assert_has(ground[region], raw.tile_at(cell), "%s is its region's ground" % where)
				assert_false(raw.tile_at(cell) in ROADS, "%s is off the road" % where)
				# Open once everything stands: no prop, camp or bush on it.
				assert_true(map.is_walkable(cell), "%s is open ground" % where)
				assert_eq(Scatter.choice(map.grid, cell), -1, "%s is bare, so the patch shows" % where)
				assert_false(map.portals.has(cell), where)
				assert_false(view.camps.has(cell), where)
				assert_false(_in_a_village(raw, cell, villagers), "%s is out of the villages" % where)
		# Today's are dealt from those decks.
		for cell: Vector2i in view.patches:
			assert_eq(Gathering.material_at(map, cell), view.patches[cell]["item"])
			assert_has(view.patch_decks[raw.region_at(cell)], cell)


## Whether `cell` is within a village's reach: a house or a door, or a
## villager's post.
func _in_a_village(map: MapData, cell: Vector2i, villagers: Array) -> bool:
	for dy in range(-Gathering.TOWN_REACH, Gathering.TOWN_REACH + 1):
		for dx in range(-Gathering.TOWN_REACH, Gathering.TOWN_REACH + 1):
			var near := map.tile_at(cell + Vector2i(dx, dy))
			if near.begins_with("roof") or near.begins_with("door") or cell + Vector2i(dx, dy) in villagers:
				return true
	return false


func test_the_same_day_grows_the_same_patches() -> void:
	for map_id: String in WILD:
		var once := Gathering.decks(MapData.load_by_id(map_id))
		var again := Gathering.decks(MapData.load_by_id(map_id))
		assert_eq_deep(once, again)
		for day in [0, 1, 7, 52, 400]:
			assert_eq_deep(Gathering.patches_on(once, day), Gathering.patches_on(again, day))


func test_another_day_grows_them_elsewhere() -> void:
	for map_id: String in WILD:
		var decks := Gathering.decks(MapData.load_by_id(map_id))
		var seen := {}
		var grown := 0
		for day in 60:
			var today := Gathering.patches_on(decks, day)
			var tomorrow := Gathering.patches_on(decks, day + 1)
			for cell: Vector2i in today:
				assert_false(tomorrow.has(cell), "%s: %s again the next day (%d)" % [map_id, cell, day])
				seen[cell] = true
				grown += 1
			# A day's patches never sit side by side.
			for cell: Vector2i in today:
				for other: Vector2i in today:
					if other != cell:
						assert_true(maxi(absi(other.x - cell.x), absi(other.y - cell.y)) >= Gathering.APART, "%s, day %d: %s and %s apart" % [map_id, day, cell, other])
		assert_gt(grown, 0, "%s grows patches" % map_id)
		assert_true(seen.size() >= grown * 0.9, "%s: two months, hardly a cell twice (%d of %d)" % [map_id, seen.size(), grown])
	var decks := Gathering.decks(MapData.load_by_id("overworld"))
	assert_ne(Gathering.patches_on(decks, 3).keys(), Gathering.patches_on(decks, 4).keys())


func test_every_day_grows_each_materials_supply_exactly() -> void:
	var daily: Dictionary = Gathering.rules()["daily"]
	var decks := {}
	for map_id: String in WILD:
		decks[map_id] = Gathering.decks(MapData.load_by_id(map_id))
	for day in 40:
		var grown := {}
		for map_id: String in WILD:
			var today := Gathering.patches_on(decks[map_id], day)
			for cell: Vector2i in today:
				grown[today[cell]["item"]] = int(grown.get(today[cell]["item"], 0)) + 1
		for material: String in daily:
			assert_eq(grown.get(material, 0), int(daily[material]), "day %d: %s %s" % [day, daily[material], material])
	# The rare ones' two homes take turns.
	for day in 6:
		var shafts := Gathering.patches_on(decks["shafts"], day).size()
		var mines := Gathering.patches_on(decks["blackiron"], day).size()
		assert_eq(shafts + mines, 1, "day %d: the shafts or the mines" % day)
		assert_ne(shafts, Gathering.patches_on(decks["shafts"], day + 1).size(), "the shafts every other day")


func test_a_day_grows_no_more_than_its_cap() -> void:
	for map_id: String in WILD:
		var decks := Gathering.decks(MapData.load_by_id(map_id))
		var cap := 0
		var expected := 0.0
		for region: String in decks:
			cap += Gathering.cap_in(region)
			expected += Gathering.daily_in(region)
		var total := 0
		for day in 200:
			var today := Gathering.patches_on(decks, day)
			assert_true(today.size() <= cap, "%s: %d patches on day %d, at most %d" % [map_id, today.size(), day, cap])
			var by_region := {}
			for cell: Vector2i in today:
				var id: String = today[cell]["id"]
				by_region[id.get_slice("_patch", 0)] = by_region.get(id.get_slice("_patch", 0), 0) + 1
			for region: String in by_region:
				assert_true(by_region[region] <= Gathering.cap_in(region), "%s: %s on day %d" % [map_id, region, day])
			total += today.size()
		# Over the days, the supply exactly (a card more or less per region).
		assert_almost_eq(float(total), expected * 200, float(decks.size()), "%s: %d grown in 200 days" % [map_id, total])
	# The whole overworld: three herbs, three reeds and two ember shards a
	# day, where twelve fixed patches grew back every 300 steps.
	var overworld := Gathering.decks(MapData.load_by_id("overworld"))
	assert_eq(Gathering.patches_on(overworld, 10).size(), 8)


func test_a_patch_picked_stays_picked_till_the_morning() -> void:
	state.roll = func() -> float: return 0.99
	state.world.steps = 3 * DAY + 50.0
	assert_eq(state.spoils.gather("forest_patch_1", "forest_herb"), ["You gather 1 Forest Herb."] as Array[String])
	assert_eq(state.pack.items["forest_herb"], 1)
	assert_eq(state.hero.jobs["foraging"]["xp"], 5)
	assert_true(state.spoils.gather("forest_patch_1", "forest_herb").is_empty(), "picked bare")
	assert_true(Gathering.is_ready(state.world, "forest_patch_2"), "the day's other patch is still there")
	state.world.steps = 4 * DAY - 0.5
	assert_false(Gathering.is_ready(state.world, "forest_patch_1"), "all day, however far you walk")
	assert_true(state.spoils.gather("forest_patch_1", "forest_herb").is_empty())
	state.world.steps = 4 * DAY
	assert_true(Gathering.is_ready(state.world, "forest_patch_1"), "the next morning, a new one")
	# The save keeps what it always kept: the step each patch was picked on.
	var saved := {}
	state.world.write_into(saved)
	assert_eq(saved["world"]["gatheredAt"], {"forest_patch_1": 3 * DAY + 50})
	assert_eq(WorldState.from_dict(saved).gathered_at, {"forest_patch_1": 3 * DAY + 50})


func test_an_older_saves_picked_patches_still_load() -> void:
	# A save from before PIX-250: four forest patches, the last two no
	# longer dealt. They load and save as they were, and wait out their day.
	var saved := {}
	state.world.gathered_at = {"forest_patch_1": 100, "forest_patch_4": 130}
	state.world.steps = 140.0
	state.world.write_into(saved)
	var loaded := WorldState.from_dict(saved)
	assert_eq(loaded.gathered_at, {"forest_patch_1": 100, "forest_patch_4": 130})
	assert_false(Gathering.is_ready(loaded, "forest_patch_1"))
	loaded.steps = DAY
	assert_true(Gathering.is_ready(loaded, "forest_patch_1"))


func test_the_map_grows_a_new_days_patches_while_the_hero_is_there() -> void:
	var map := MapData.load_by_id("deepwood")
	var view := MapView.new(map, null)
	var steps := GameState.world.steps
	GameState.world.steps = 5 * DAY + 10.0
	view.plan(map.spawn)
	var first := view.patches.duplicate()
	assert_eq_deep(first, Gathering.patches_on(view.patch_decks, 5))
	assert_false(view.deal_patches(5), "dealt already")
	GameState.world.steps = 6 * DAY + 1.0
	assert_true(view.deal_patches(Gathering.day_of(GameState.world.steps)), "a new day")
	assert_eq(view.patch_day, 6)
	assert_eq_deep(view.patches, Gathering.patches_on(view.patch_decks, 6))
	for cell: Vector2i in first:
		assert_false(view.patches.has(cell), "yesterday's %s is gone" % cell)
	GameState.world.steps = steps


func test_every_floor_has_a_patch_that_deepens_and_moves() -> void:
	for level in range(1, Dungeons.floor_count() + 1):
		var plan := DungeonFloor.plan(level)
		var map: MapData = plan["map"]
		var ground: Array = plan["patch_ground"]
		assert_gt(ground.size(), 1, "floor %d's patch has room to move" % level)
		for cell: Vector2i in ground:
			assert_eq(map.grid[cell], "floor", "floor %d's patch is on the floor" % level)
			assert_ne(cell, plan["foes"][0]["cell"])
		for day in 10:
			var today := Gathering.floor_patch(ground, level, day)
			assert_has(ground, today)
			assert_eq(today, Gathering.floor_patch(ground, level, day), "the same for the same day")
			assert_ne(today, Gathering.floor_patch(ground, level, day + 1), "floor %d: elsewhere the next day" % level)
	assert_eq(Gathering.floor_material(1), "forest_herb")
	assert_eq(Gathering.floor_material(5), "marsh_reed")
	assert_eq(Gathering.floor_material(15), "grave_moss")


func test_a_first_brew_for_vex_and_a_buckler_for_hilda() -> void:
	assert_eq(Quests.by_id("herbs_for_vex")["objective"]["kind"], "craft")
	assert_eq(Quests.by_id("hildas_buckler")["giver"], "smith")
	state.questing.resolve_quests("alchemist_vex")
	state.world.map_id = "town_alchemist"
	state.pack.items.merge({"forest_herb": 1, "marsh_reed": 1})
	assert_false(Quests.is_ready(Quests.by_id("herbs_for_vex"), state.progression.quests, state.pack.items))
	state.roll = func() -> float: return 0.99
	assert_true(state.trade.craft("brew_potion_hp")["made"])
	assert_true(Quests.is_ready(Quests.by_id("herbs_for_vex"), state.progression.quests, state.pack.items), "one brewed")
	assert_string_starts_with(state.questing.resolve_quests("alchemist_vex"), "Quest complete: A First Brew.")
