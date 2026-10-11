extends GutTest
## Different monsters by day and by night (PIX-252): every wild region under
## the sky keeps hours - packs that come out only after dark, day packs that
## sleep by their camp's fire, Greyhold's bowmen gone in - decided by the
## clock alone (nothing new is saved). The caves keep none. A night pack is
## all of its kind, keeps no camp, and is a little stronger and better paid.
## No quest's quarry and no bounty goes missing at any hour.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const Enemy := preload("res://scripts/enemy.gd")
const NOON := 12 * 60
const MIDNIGHT := 0
## The wild maps under the sky, and those under the ground.
const OUTDOOR := ["overworld", "deepwood", "mirefen", "saltmere", "blackiron", "greyhold", "frostgate"]
const CAVES := ["seacave", "shafts", "cellars", "icecave"]

var _maps := {}


func _map(map_id: String) -> MapData:
	if not _maps.has(map_id):
		_maps[map_id] = MapData.load_by_id(map_id)
	return _maps[map_id]


func _ids(spawns: Array) -> Array:
	return spawns.map(func(spawn: Dictionary) -> String: return spawn["id"])


func _spawn(spawn_id: String) -> Dictionary:
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if spawn["id"] == spawn_id:
			return spawn
	return {}


func _region_of(spawn: Dictionary) -> String:
	return _map(spawn["mapId"]).region_at(Vector2i(int(spawn["x"]), int(spawn["y"])))


func _kind_of(spawn: Dictionary) -> String:
	return Bestiary.species_of(spawn, _region_of(spawn))


## Every map with a wild pack, in the spawns' order.
func _wild_maps() -> Array:
	var out := []
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if spawn["mapId"] not in out:
			out.append(spawn["mapId"])
	return out


func test_the_clock_reads_its_minute_and_its_night() -> void:
	assert_eq(DayNight.minute_of(0.0), 6 * 60, "the cycle starts at six in the morning")
	assert_eq(DayNight.minute_of(1008.0), 22 * 60 + 48)
	assert_true(DayNight.night_at(DayNight.minute_of(0.7 * DayNight.DAY_CYCLE_STEPS)), "the harness's night is a night")
	assert_eq(DayNight.minute_of(DayNight.DAY_CYCLE_STEPS - 1.0), 5 * 60 + 59)
	assert_false(DayNight.night_at(NOON))
	assert_true(DayNight.night_at(MIDNIGHT))
	# The packs' night is the lamps' night, step for step.
	for steps in DayNight.DAY_CYCLE_STEPS:
		assert_eq(DayNight.night_at(DayNight.minute_of(steps)), DayNight.is_night(steps), "step %d" % steps)


func test_the_same_field_holds_other_packs_at_night() -> void:
	var day := _ids(Packs.out_at("overworld", NOON))
	var night := _ids(Packs.out_at("overworld", MIDNIGHT))
	for spawn_id in ["forest_1", "forest_2", "forest_3"]:
		assert_has(day, spawn_id, "%s is out by day" % spawn_id)
		assert_has(night, spawn_id, "%s is still there at night" % spawn_id)
	for spawn_id in ["forest_night_1", "forest_night_2"]:
		assert_does_not_have(day, spawn_id, "%s stays in the dark by day" % spawn_id)
		assert_has(night, spawn_id, "%s comes out after dark" % spawn_id)
	assert_eq(_kind_of(_spawn("forest_night_1")), "wolf")
	assert_eq(_kind_of(_spawn("forest_night_2")), "skeleton")
	# The goblins sleep by their camp's fire at night, and only at night.
	var goblins := _spawn("forest_2")
	assert_false(Packs.asleep(goblins, NOON), "the goblins roam by day")
	assert_true(Packs.asleep(goblins, MIDNIGHT), "and sleep by their fire at night")
	assert_false(Packs.asleep(_spawn("forest_1"), MIDNIGHT), "the slimes never sleep")
	# Greyhold's bowmen go in at dusk: no shooting in the dark.
	assert_has(_ids(Packs.out_at("greyhold", NOON)), "greyhold_2")
	assert_does_not_have(_ids(Packs.out_at("greyhold", MIDNIGHT)), "greyhold_2")


## Hour by hour, each map holds its day roster or its night roster, changing
## only twice a day: when the night falls (with the lamps) and at dawn.
func test_each_hour_has_its_roster_and_it_changes_twice_a_day() -> void:
	for map_id: String in _wild_maps():
		var day := _ids(Packs.out_at(map_id, NOON))
		var night := _ids(Packs.out_at(map_id, MIDNIGHT))
		for hour in 24:
			var roster := _ids(Packs.out_at(map_id, hour * 60))
			assert_eq(roster, night if DayNight.night_at(hour * 60) else day, "%s at %02d:00" % [map_id, hour])
		var changes := 0
		for minute in 1440:
			if _ids(Packs.out_at(map_id, minute)) != _ids(Packs.out_at(map_id, (minute + 1) % 1440)):
				changes += 1
		assert_eq(changes, 2 if map_id in OUTDOOR else 0, "%s changes at dusk and dawn" % map_id)
	# Night falls at about eight in the evening and lifts at about four.
	assert_true(DayNight.night_at(20 * 60) and DayNight.night_at(3 * 60))
	assert_false(DayNight.night_at(19 * 60) or DayNight.night_at(5 * 60))


func test_every_wild_region_under_the_sky_feels_different_at_night() -> void:
	var regions := {}
	for map_id: String in OUTDOOR:
		for spawn: Dictionary in Bestiary.spawns_on(map_id):
			regions[_region_of(spawn)] = map_id
	assert_eq(regions.size(), 9, "the Reach's nine wild regions under the sky")
	for region_id: String in regions:
		var map_id: String = regions[region_id]
		var night_packs := Packs.out_at(map_id, MIDNIGHT).filter(func(spawn: Dictionary) -> bool:
			return _region_of(spawn) == region_id and Packs.of_the_night(spawn))
		assert_false(night_packs.is_empty(), "%s has a pack of its own after dark" % region_id)
		var by_day := Packs.out_at(map_id, NOON).filter(func(spawn: Dictionary) -> bool: return _region_of(spawn) == region_id)
		assert_false(by_day.is_empty(), "%s has packs by day" % region_id)
		for spawn: Dictionary in night_packs:
			assert_true(Bestiary.region(region_id).has("name"))
			assert_true(PunyArt.MONSTERS.has(_kind_of(spawn)), "%s's %s is drawn" % [spawn["id"], _kind_of(spawn)])
			assert_false(Bestiary.is_boss(_kind_of(spawn)), "%s is no boss" % spawn["id"])
	# Under the ground there is no night: the caves keep no hours.
	for map_id: String in CAVES:
		assert_false(Bestiary.spawns_on(map_id).is_empty(), "%s has packs" % map_id)
		assert_eq(_ids(Packs.out_at(map_id, MIDNIGHT)), _ids(Packs.out_at(map_id, NOON)), "%s keeps no hours" % map_id)
		for spawn: Dictionary in Bestiary.spawns_on(map_id):
			assert_false(spawn.has("hours") or spawn.has("sleeps"), "%s keeps no hours" % spawn["id"])
			assert_false(Packs.asleep(spawn, MIDNIGHT))


## The night's packs keep to their region's band: never a kind stronger
## than the strongest it already holds, by day or in its mix (the
## Deepwood's shades, the Mirefen's mimics), so the Whispering Forest grows
## no wyverns after dark.
func test_the_night_keeps_to_its_regions_band() -> void:
	for map_id: String in OUTDOOR:
		var strongest := {}
		for spawn: Dictionary in Bestiary.spawns_on(map_id):
			var region_id := _region_of(spawn)
			if not strongest.has(region_id):
				strongest[region_id] = 0
				for entry: Dictionary in Bestiary.region(region_id)["monsters"]:
					strongest[region_id] = maxi(int(strongest[region_id]), int(Bestiary.monster(entry["monsterId"])["level"]))
			if not Packs.of_the_night(spawn):
				strongest[region_id] = maxi(int(strongest[region_id]), int(Bestiary.monster(_kind_of(spawn))["level"]))
		for spawn: Dictionary in Bestiary.spawns_on(map_id):
			if Packs.of_the_night(spawn):
				var level := int(Bestiary.monster(_kind_of(spawn))["level"])
				assert_lte(level, int(strongest[_region_of(spawn)]), "%s fits %s" % [spawn["id"], _region_of(spawn)])


func test_a_spawns_hours_are_known_words() -> void:
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		assert_has(["", "day", "night"], String(spawn.get("hours", "")), "%s's hours" % spawn["id"])
		assert_has(["", "night"], String(spawn.get("sleeps", "")), "%s sleeps at night or not at all" % spawn["id"])
		assert_false(spawn.has("sleeps") and spawn.has("hours"), "%s: a pack that sleeps is out at every hour" % spawn["id"])


func test_a_night_pack_is_all_of_its_kind_and_keeps_no_camp() -> void:
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if not Packs.of_the_night(spawn):
			continue
		var leader := _kind_of(spawn)
		for i in 3:
			var at := Vector2i(int(spawn["x"]) + i, int(spawn["y"]))
			assert_eq(Bestiary.pack_species(spawn, _region_of(spawn), i, at), leader, "%s is all %s" % [spawn["id"], leader])
	for map_id: String in OUTDOOR:
		var map := MapData.load_by_id(map_id)
		var view := MapView.new(map, null)
		view.plan(map.spawn)
		var tents: int = view.camps.values().filter(func(piece: Dictionary) -> bool: return piece["kind"] == "tent").size()
		var camping: int = Bestiary.spawns_on(map_id).filter(func(spawn: Dictionary) -> bool: return not Packs.of_the_night(spawn)).size()
		assert_eq(tents, camping, "%s: a tent for each pack but the night's" % map_id)


func test_a_night_pack_is_a_little_stronger_and_better_paid() -> void:
	var night := Packs.night_numbers()
	assert_eq([float(night["hp"]), float(night["attack"]), float(night["xp"]), float(night["gold"]), float(night["loot"])], [1.15, 1.1, 1.15, 1.25, 0.08], "the numbers live with the packs' rules")
	var by_day := Bestiary.wild(Bestiary.spawn("wolf"), "forest")
	var after_dark := Packs.by_night(Bestiary.wild(Bestiary.spawn("wolf"), "forest"))
	assert_eq(int(after_dark["maxHp"]), roundi(int(by_day["maxHp"]) * 1.15))
	assert_eq(after_dark["hp"], after_dark["maxHp"], "whole")
	assert_eq(int(after_dark["attack"]), roundi(int(by_day["attack"]) * 1.1))
	assert_eq(int(after_dark["xp"]), roundi(int(by_day["xp"]) * 1.15))
	assert_eq(int(after_dark["gold"]), roundi(int(by_day["gold"]) * 1.25))
	assert_eq(int(after_dark["defense"]), int(by_day["defense"]))
	# A little: stronger, never a third stronger.
	assert_gt(int(after_dark["attack"]), int(by_day["attack"]))
	assert_lt(float(after_dark["maxHp"]), float(by_day["maxHp"]) * 1.34)
	# Its level stays its kind's: the tag and whether it runs read as by day.
	assert_eq(Bestiary.level_of(after_dark), Bestiary.level_of(by_day))
	assert_eq(Enemy.flees_from(after_dark, 10), Enemy.flees_from(by_day, 10))
	# And its drop comes a little more often: 22% by day, 30% by night.
	assert_almost_eq(Packs.night_luck(after_dark), 0.08, 0.0001)
	assert_eq(Packs.night_luck(by_day), 0.0)
	var roll := func() -> float: return 0.25
	assert_eq(Bestiary.roll_drop(1, "normal", roll, 0, Packs.night_luck(by_day)), {}, "no drop by day at 0.25")
	assert_false(Bestiary.roll_drop(1, "normal", roll, 0, Packs.night_luck(after_dark)).is_empty(), "a drop by night")


func test_a_night_kill_drops_more_often() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.roll = func() -> float: return 0.25
	# What a kill won floats up (PIX-245): its items are in its gains. The same
	# roll by night carries all the day's (the pelt, what was foraged) and the
	# loot the day's luck missed.
	var ids_of := func(won: Dictionary) -> Array:
		return won["gains"]["items"].map(func(item: Dictionary) -> String: return item["id"])
	var by_day: Array = ids_of.call(state.spoils.defeat_monster(Bestiary.wild(Bestiary.spawn("wolf"), "forest"), "forest", "", 1))
	var by_night: Array = ids_of.call(state.spoils.defeat_monster(Packs.by_night(Bestiary.wild(Bestiary.spawn("wolf"), "forest")), "forest", "", 1))
	for id: String in by_day:
		assert_has(by_night, id)
	assert_eq(by_night.size(), by_day.size() + 1, "by night, loot at 0.25: %s by day, %s by night" % [by_day, by_night])


## A quest's quarry, a recruit's and the way to it are out at every hour, or
## the hint says it comes out only at night.
func test_no_quarry_goes_missing_at_any_hour() -> void:
	var asks := []
	for quest: Dictionary in Quests.all():
		if quest["objective"]["kind"] == "kill":
			asks.append([quest["id"], quest["objective"]["monsterId"], Quests.where(quest)])
	for recruit: Dictionary in Npcs._data()["recruits"]:
		if recruit.get("ask", {}).get("kind", "") == "kill":
			asks.append([recruit["id"], recruit["ask"]["monsterId"], ""])
	assert_gt(asks.size(), 15)
	for ask: Array in asks:
		var kind: String = ask[1]
		var wild: Array = Bestiary._data()["spawns"].filter(func(spawn: Dictionary) -> bool: return _kind_of(spawn) == kind)
		if wild.is_empty():
			# Met on the mountain's floors only (Bram's imps).
			assert_false(Bestiary.where_found(kind).is_empty(), "%s's %s lives somewhere" % [ask[0], kind])
			continue
		var every_hour := true
		for hour in 24:
			var out := false
			for map_id: String in _wild_maps():
				for spawn: Dictionary in Packs.out_at(map_id, hour * 60):
					out = out or _kind_of(spawn) == kind
			every_hour = every_hour and out
		if every_hour:
			# The way leads to a pack out at every hour, never an empty camp.
			var home := Bestiary.home_of(kind)
			var led: Array = wild.filter(func(spawn: Dictionary) -> bool:
				return spawn["mapId"] == home["mapId"] and int(spawn["x"]) == int(home["x"]) and int(spawn["y"]) == int(home["y"]))
			assert_false(led.is_empty() or led[0].has("hours"), "%s: the way to the %s leads to a pack out at every hour" % [ask[0], kind])
			assert_false(Bestiary.where_found(kind)[0].ends_with("by night"), "%s's hint names where the %s are at any hour first" % [ask[0], kind])
		else:
			assert_string_contains(String(ask[2]), "by night", "%s's %s come out only at night, and the hint says so" % [ask[0], kind])


## The bounties' quarries are named monsters in their lairs: no pack, no
## hours, there at every hour - and no night pack camps on their doorstep.
func test_every_bounty_keeps_its_lair_at_every_hour() -> void:
	var homes := {}
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		homes[spawn["id"]] = spawn
	for entry: Dictionary in Hunts.all():
		if entry.has("deepDepth"):
			continue
		assert_false(homes.has(entry["id"]), "%s is no pack" % entry["id"])
		assert_false(entry.has("hours") or entry.has("sleeps"), "%s keeps no hours" % entry["id"])
		for spawn: Dictionary in Bestiary.spawns_on(entry["mapId"]):
			if Packs.of_the_night(spawn):
				var home := Vector2i(int(spawn["x"]), int(spawn["y"]))
				assert_gt(Vector2(Hunts.lair(entry)).distance_to(Vector2(home)), 10.0, "%s's lair clear of %s" % [entry["id"], spawn["id"]])


func test_where_a_kind_comes_out_only_at_night_says_so() -> void:
	var wolves := Bestiary.where_found("wolf")
	assert_eq(wolves.slice(0, 2), ["the Whispering Forest", "the Sunken Marsh"], "where wolves are at any hour, first")
	assert_has(wolves, "the Ash Fields by night")
	assert_does_not_have(wolves, "the Whispering Forest by night", "the forest has wolves by day too")
	# Bone knights keep the Kings' Vault at every hour (PIX-257), and come
	# out in the Mirefen only by night.
	assert_eq(Bestiary.where_found("boneknight"), ["the Kings' Vault", "the Mirefen by night"])
	# The way to a kind leads to a pack out at every hour when there is one.
	var home := Bestiary.home_of("wolf")
	assert_eq([home["mapId"], int(home["x"]), int(home["y"])], ["overworld", 72, 52], "forest_3's wolves")
	# The Deepwood's shades come out only at night; the Kings' Vault's keep it
	# at every hour (PIX-257), so the way leads there.
	home = Bestiary.home_of("shade")
	assert_eq(home["mapId"], "vault_1", "a pack out at every hour before a night one")


## The night's homes stand where any pack's may (test_packs checks every
## home against the arrivals): open ground of their region, a pack's room
## around them, clear of the patches.
func test_the_nights_homes_stand_on_open_ground() -> void:
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if not Packs.of_the_night(spawn):
			continue
		var map := _map(spawn["mapId"])
		var home := Vector2i(int(spawn["x"]), int(spawn["y"]))
		assert_true(map.is_walkable(home), "%s's home is open ground" % spawn["id"])
		assert_ne(map.region_at(home), "", "%s's home is in a region" % spawn["id"])
		var room := 0
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1)]:
			if map.is_walkable(home + step) and map.region_at(home + step) == map.region_at(home):
				room += 1
		assert_gte(room, 2, "%s has room for its pack" % spawn["id"])
		for other: Dictionary in Bestiary.spawns_on(spawn["mapId"]):
			if other["id"] != spawn["id"]:
				var gap := maxi(absi(int(other["x"]) - home.x), absi(int(other["y"]) - home.y))
				assert_gte(gap, 6, "%s keeps apart from %s" % [spawn["id"], other["id"]])
