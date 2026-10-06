extends GutTest
## Villager rules match src/world/npcs.ts: reference values below were taken
## from the web modules themselves (npcsOn / npcPosition), so a drift in the
## port fails here, not in a playtest.


func _ids(npcs: Array[Dictionary]) -> Array:
	return npcs.map(func(npc: Dictionary) -> String: return npc["id"])


func test_town_folk_follow_the_town_tier() -> void:
	assert_eq(_ids(Npcs.on_map("town", 1, [])), ["elder", "villager_ana", "villager_bram"])
	assert_eq(
		_ids(Npcs.on_map("town", 4, [])),
		[
			"elder", "villager_ana", "villager_bram", "settler_mira", "settler_tomas",
			"settler_serra", "settler_fenn",
		]
	)


func test_recruits_wait_in_the_wilds_until_they_settle() -> void:
	var waiting := Npcs.on_map("deepwood", 1, [])
	assert_eq(_ids(waiting), ["settler_loras"])
	assert_eq(Vector2i(waiting[0]["x"], waiting[0]["y"]), Vector2i(6, 24))
	assert_eq(_ids(Npcs.on_map("deepwood", 1, ["settler_loras"])), [])
	assert_has(_ids(Npcs.on_map("town", 1, ["settler_loras"])), "settler_loras")


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
