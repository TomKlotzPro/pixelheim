extends GutTest
## Villager rules match src/world/npcs.ts: reference values below were taken
## from the web modules themselves (npcsOn / npcPosition), so a drift in the
## port fails here, not in a playtest.


func _ids(npcs: Array[Dictionary]) -> Array:
	return npcs.map(func(npc: Dictionary) -> String: return npc["id"])


func test_town_folk_follow_the_town_tier() -> void:
	assert_eq(_ids(Npcs.on_map("town", 1, [])), ["elder", "shrine_keeper", "villager_ana", "villager_bram", "town_cat", "town_dog"])
	assert_eq(
		_ids(Npcs.on_map("town", 4, [])),
		[
			"elder", "shrine_keeper", "villager_ana", "villager_bram", "settler_mira", "settler_tomas",
			"settler_serra", "settler_fenn", "town_cat", "town_dog", "kid_pip", "kid_nell",
		]
	)


func test_recruits_wait_in_the_wilds_until_they_settle() -> void:
	var waiting := Npcs.on_map("deepwood", 1, [])
	assert_eq(_ids(waiting), ["settler_loras"])
	assert_eq(Vector2i(waiting[0]["x"], waiting[0]["y"]), Vector2i(6, 24))
	assert_eq(_ids(Npcs.on_map("deepwood", 1, ["settler_loras"])), [])
	assert_has(_ids(Npcs.on_map("town", 1, ["settler_loras"])), "settler_loras")


## The town's age is Pixelheim's alone (PIX-328): the other villages never
## burned, so their people (the four hubs', the mountain's) and the
## recruits waiting in the wilds stand on their maps at every age, the
## Ashes too, with or without the buildings; Pixelheim's own still wait.
func test_the_other_places_people_are_home_at_every_age() -> void:
	var maps := {}
	for tier in range(0, Town.MAX_TIER + 1):
		for done: Variant in [null, Town.projects_through(tier)]:
			for npc: Dictionary in Npcs._data()["npcs"]:
				if Catalog.place_name(npc["mapId"]) != Catalog.place_name("town"):
					maps[npc["mapId"]] = true
					assert_has(_ids(Npcs.on_map(npc["mapId"], tier, [], done)), npc["id"], "%s on %s at age %d" % [npc["id"], npc["mapId"], tier])
			for recruit: Dictionary in Npcs._data()["recruits"]:
				assert_has(_ids(Npcs.on_map(recruit["found"]["mapId"], tier, [], done)), recruit["id"], "%s waits at age %d" % [recruit["id"], tier])
	for hub: String in ["saltmere", "blackiron", "greyhold", "frostgate", "morvax_forge"]:
		assert_true(maps.has(hub), "%s has people of its own" % hub)
	assert_does_not_have(_ids(Npcs.on_map("town", 0, [], [])), "villager_ana", "Pixelheim's own wait for its age")


func test_a_settled_recruit_speaks_their_town_lines() -> void:
	var met := Npcs.by_id("settler_loras", [])
	var settled := Npcs.by_id("settler_loras", ["settler_loras"])
	assert_eq(met["mapId"], "deepwood")
	assert_eq(settled["mapId"], "town")
	assert_ne(met["lines"], settled["lines"])
	assert_eq(Npcs.by_id("nobody", []), {})


func test_wanderers_pace_exactly_like_the_web() -> void:
	var town := MapData.load_by_id("town")
	var ana := Npcs.by_id("villager_ana", [])
	var offsets := Npcs.offsets_for(ana, town)
	# npcPosition(ana, 0..12) - home, from the web modules.
	var expected := [
		Vector2i(1, 1), Vector2i(1, 1), Vector2i(0, 1), Vector2i(0, 1), Vector2i(0, 1),
		Vector2i(0, 1), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0), Vector2i(0, 0),
		Vector2i(1, 0), Vector2i(1, 0), Vector2i(1, 0),
	]
	for beat in expected.size():
		assert_eq(Npcs.pace_offset(ana, offsets, beat), expected[beat], "beat %d" % beat)


func test_standing_villagers_never_move() -> void:
	var elder := Npcs.by_id("elder", [])
	var offsets := Npcs.offsets_for(elder, MapData.load_by_id("town"))
	for beat in 20:
		assert_eq(Npcs.pace_offset(elder, offsets, beat), Vector2i.ZERO)


func test_pacing_skips_walls_and_portals() -> void:
	for npc: Dictionary in Npcs._data()["npcs"]:
		var map := MapData.load_by_id(npc["mapId"])
		for offset in Npcs.offsets_for(npc, map):
			var cell := Vector2i(npc["x"], npc["y"]) + offset
			assert_true(map.is_walkable(cell), "%s paces into a wall" % npc["id"])
			assert_false(map.portals.has(cell), "%s paces onto a portal" % npc["id"])


## PIX-444: Bram paced behind the well's roof, only his head and his "!"
## showing. No wanderer paces onto a cell a prop's art stands over (drawn
## in front of them), the town at every age, the Ashes too.
func test_no_wanderer_paces_behind_a_prop() -> void:
	var everyone: Array[Dictionary] = []
	everyone.assign(Npcs._data()["npcs"])
	for recruit: Dictionary in Npcs._data()["recruits"]:
		everyone.append(Npcs.as_npc(recruit, true))
	for npc in everyone.filter(func(npc: Dictionary) -> bool: return npc["wander"]):
		var maps: Array[MapData] = [MapData.load_by_id(npc["mapId"])]
		if npc["mapId"] == "town":
			for tier in range(-1, Town.MAX_TIER + 1):
				maps.append(MapData.load_tiered("town", Town.projects_through(tier), 1))
		for map in maps:
			var over := {}
			for prop: Dictionary in PunyProps.plan(map.grid)["props"]:
				for tile: Array in prop["tiles"]:
					if tile[0].y < 0:
						over[prop["cell"] + tile[0]] = true
			for offset in Npcs.offsets_for(npc, map):
				var cell := Vector2i(npc["x"], npc["y"]) + offset
				assert_false(over.has(cell), "%s paces behind a prop at %s" % [npc["id"], cell])


func test_every_villager_stands_on_walkable_ground_with_a_sprite() -> void:
	var everyone: Array[Dictionary] = []
	everyone.assign(Npcs._data()["npcs"])
	for recruit: Dictionary in Npcs._data()["recruits"]:
		everyone.append(Npcs.as_npc(recruit, false))
		everyone.append(Npcs.as_npc(recruit, true))
	for npc in everyone:
		var map := MapData.load_by_id(npc["mapId"])
		assert_true(map.is_walkable(Vector2i(npc["x"], npc["y"])), "%s stands in a wall" % npc["id"])
		assert_true(PunyArt.VILLAGERS.has(npc["sprite"]), "%s has no Puny sheet" % npc["sprite"])
		assert_gt(npc["lines"].size(), 0, "%s has nothing to say" % npc["id"])


## Dry feet (PIX-342: Ola stood and paced half in the water at Saltmere):
## on every map, and on the village at every age, everyone who stands there
## - at home, at a stall, waiting in the wilds or settled - stands on open
## ground, and a wanderer's whole pacing square is open too, so no step is
## skipped and none cuts a corner over the sea or through a wall.
func test_every_villager_stands_and_paces_on_dry_ground() -> void:
	var settled: Array = Npcs._data()["recruits"].map(func(recruit: Dictionary) -> String: return recruit["id"])
	var maps := {"town": true}
	for npc: Dictionary in Npcs._data()["npcs"]:
		maps[npc["mapId"]] = true
	for recruit: Dictionary in Npcs._data()["recruits"]:
		maps[recruit["found"]["mapId"]] = true
		maps[String(recruit["home"].get("mapId", "town"))] = true
	for map_id: String in maps:
		for tier in range(0, Town.MAX_TIER + 1) if map_id == "town" else [1]:
			var done := Town.projects_through(tier)
			var map := MapData.load_tiered(map_id, done, 1)
			for npc: Dictionary in Npcs.on_map(map_id, tier, [], done) + Npcs.on_map(map_id, tier, settled, done):
				var home := Vector2i(npc["x"], npc["y"])
				for offset: Vector2i in Npcs.LOOP if npc["wander"] else [Vector2i.ZERO]:
					var cell := home + offset
					var where := "%s at %s on %s (age %d)" % [npc["id"], cell, map_id, tier]
					assert_true(map.is_walkable(cell), "%s: %s, not open ground" % [where, map.tile_at(cell)])
					assert_does_not_have(PunyTerrain.WATERS, map.tile_at(cell), "%s stands in the water" % where)
					assert_false(npc["wander"] and map.portals.has(cell), "%s paces onto a doorway" % where)


func test_the_first_beat_met_speaks_else_their_own_lines() -> void:
	var entries := [{"when": "late", "lines": ["late"]}, {"when": "early", "lines": ["early"]}]
	assert_eq(Npcs.lines_when(entries, ["own"], func(_when: Variant) -> bool: return false), ["own"], "none met: their own lines")
	assert_eq(Npcs.lines_when(entries, ["own"], func(when: Variant) -> bool: return when == "early"), ["early"], "the one met")
	assert_eq(Npcs.lines_when(entries, ["own"], func(_when: Variant) -> bool: return true), ["late"], "both met: the first written wins")


func test_brin_answers_the_lighthouse() -> void:
	var progression := ProgressionState.new()
	var settlement := SettlementState.new()
	var post := PostState.new()
	var brin := func() -> Array:
		var met := Npcs.beat_met.bind(progression, settlement, post)
		return Npcs.on_map("saltmere", 1, [], null, true, false, met).filter(func(npc: Dictionary) -> bool: return npc["id"] == "saltmere_brin")[0]["lines"]
	var own: Array = Npcs.by_id("saltmere_brin", [])["lines"]
	var said: Array = Npcs.by_id("saltmere_brin", [])["linesWhen"]
	assert_eq(brin.call(), own, "the lighthouse dark: what he always said")
	Routes.tally(post, "saltmere", "bram", int(Hubs.marks()[0]))
	assert_eq(brin.call(), said[1]["lines"], "mended: only a tower")
	Routes.tally(post, "saltmere", "bram", int(Hubs.marks()[2]))
	assert_eq(brin.call(), said[0]["lines"], "lit")
	assert_eq(Npcs.on_map("saltmere", 1, []).filter(func(npc: Dictionary) -> bool: return npc["id"] == "saltmere_brin")[0]["lines"], own, "no one to ask: their own lines")


## PIX-443: a beat names something the game has, and a line stays short.
func test_every_beat_is_real_and_every_line_short() -> void:
	var count := 0
	for npc: Dictionary in Npcs.townsfolk():
		for entry: Dictionary in npc.get("linesWhen", []):
			count += 1
			var when: Dictionary = entry["when"]
			match String(when["kind"]):
				"hub":
					assert_between(int(when["step"]), 1, Hubs.steps(String(when["place"])).size(), "%s: a hub's step" % npc["id"])
				"hunted":
					assert_false(Hunts.named(String(when["named"])).is_empty(), "%s: %s" % [npc["id"], when["named"]])
				"delivered", "questDone":
					assert_false(Quests.by_id(String(when["questId"])).is_empty(), "%s: %s" % [npc["id"], when["questId"]])
				"project":
					assert_true(Routes.places().any(func(place: String) -> bool: return Routes.station(place).get("work", "") == when["projectId"]), "%s: a waystation" % npc["id"])
				"seen":
					assert_eq(String(when["sceneId"]), Bells.collar_id(), "%s: the dragon freed" % npc["id"])
				"chosen":
					pass
				_:
					fail_test("%s: a beat of no kind we know: %s" % [npc["id"], when["kind"]])
			assert_false(entry["lines"].is_empty(), "%s says something" % npc["id"])
			for line: String in entry["lines"]:
				assert_lte(line.length(), 125, "short: %s" % line)
	assert_gte(count, 11, "the Reach's people each answer something")


func test_the_faced_villager_wins_then_any_neighbor() -> void:
	var occupied := {Vector2i(5, 4): {"id": "north"}, Vector2i(6, 5): {"id": "east"}}
	var hero := Vector2i(5, 5)
	assert_eq(Npcs.beside(occupied, hero, Vector2i.RIGHT)["npc"]["id"], "east")
	assert_eq(Npcs.beside(occupied, hero, Vector2i.UP)["npc"]["id"], "north")
	# Facing nobody: up is tried first, like the web's order.
	var found := Npcs.beside(occupied, hero, Vector2i.LEFT)
	assert_eq(found["npc"]["id"], "north")
	assert_eq(found["side"], Vector2i.UP)
	assert_eq(Npcs.beside({}, hero, Vector2i.UP), {})


## A living village (PIX-149): the town's own folk talk about the hero's
## latest deed first, each in their own words; keepers, builders, animals,
## the elder and the mayor keep to their business.
func test_the_town_talks_about_the_last_deed() -> void:
	var bram := Npcs.by_id("villager_bram", [])
	assert_eq(Npcs.reaction(bram, {}), "")
	var line := Npcs.reaction(bram, {"kind": "project", "project": "well"})
	assert_string_contains(line, "well")
	assert_eq(Npcs.reaction(Npcs.by_id("elder", []), {"kind": "hunt", "beast": "Old Greymaw"}), "")
	assert_eq(Npcs.reaction(Npcs.by_id("town_cat", []), {"kind": "hunt", "beast": "Old Greymaw"}), "", "the cat doesn't care")


func test_the_hours_turn_from_day_to_night() -> void:
	assert_false(DayNight.is_night(0.0), "the day starts bright")
	assert_true(DayNight.is_night(0.7 * DayNight.DAY_CYCLE_STEPS))
	assert_false(DayNight.is_night(0.95 * DayNight.DAY_CYCLE_STEPS), "morning")
