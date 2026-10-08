extends GutTest
## Act 0, the Ashes (PIX-146): a new hero finds Pixelheim burnt - ruins where
## the store, the forge, the brewery and the inn stood, their doors shut, the
## keepers trading from stalls on the square and Sela keeping a tent - and
## rebuilds it as the Hamlet's projects. Heroes from before keep their town.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const RUINED_DOORS := [Vector2i(30, 10), Vector2i(50, 10), Vector2i(55, 18), Vector2i(23, 19)]

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _town() -> MapData:
	var map := MapData.load_tiered("town", Town.done_projects(state.settlement), 1)
	MapView.new(map, null).plan(map.spawn)
	return map


func test_a_new_hero_finds_the_town_in_ashes() -> void:
	assert_eq(state.town_tier(), 0)
	assert_eq(Town.tier(0)["name"], "Ashes")
	assert_eq(Town.current_age(state.settlement), 1, "the Hamlet is the first thing to rebuild")
	var map := _town()
	for door: Vector2i in RUINED_DOORS:
		assert_false(map.portals.has(door), "the door at %s is cinders" % door)
	assert_true(map.portals.has(Vector2i(40, 19)), "the hall stood")
	assert_eq(map.tile_at(Vector2i(26, 5)), "fence", "a burnt frame")


func test_the_ashes_can_be_walked_from_the_spawn_to_the_gate_and_the_hall() -> void:
	var map := _town()
	var seen := {map.spawn: true}
	var queue: Array[Vector2i] = [map.spawn]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := cell + step
			if not seen.has(next) and (map.is_walkable(next) or map.portals.has(next)):
				seen[next] = true
				if map.is_walkable(next):
					queue.append(next)
	assert_true(seen.has(Vector2i(40, 0)), "the gate")
	assert_true(seen.has(Vector2i(40, 19)), "the hall")
	assert_true(seen.has(Town.project_board() + Vector2i.DOWN), "the board")


func test_the_keepers_trade_from_stalls_and_sela_keeps_a_tent() -> void:
	var on_square := Npcs.on_map("town", 0, [], [])
	var ids := on_square.map(func(npc: Dictionary) -> String: return npc["id"])
	for keeper: String in ["shopkeeper", "smith", "alchemist_vex", "innkeeper"]:
		assert_has(ids, keeper)
	assert_does_not_have(ids, "villager_ana", "only the survivors stayed")
	assert_has(ids, "elder")
	assert_has(ids, "villager_bram")
	assert_true(Npcs.on_map("town_smith", 0, [], []).is_empty(), "the forge is rubble")
	var elder: Dictionary = on_square[ids.find("elder")]
	assert_string_contains(elder["lines"][0], "burned")
	var map := _town()
	assert_eq(map.tile_at(Vector2i(33, 25)), "crate", "Odo's stall")
	assert_ne(Town.ashes_tent([]), Vector2i(-1, -1))


func test_hilda_crafts_at_her_stall() -> void:
	state.world.map_id = "town"
	assert_false(state.at_station("smithing"))
	state.stall_shop = Economy.station_shop("smithing")
	assert_true(state.at_station("smithing"))
	assert_false(state.at_station("alchemy"), "Hilda doesn't brew")
	state.pack.items["marsh_reed"] = 3
	assert_true(state.craft("craft_reed_buckler")["made"])


func test_rebuilding_the_hamlet_opens_the_doors() -> void:
	state.pack.gold = 1000
	state.pack.items.merge({"marsh_reed": 6, "wolf_pelt": 2, "forest_herb": 3})
	for project_id: String in ["odos_store", "hildas_forge", "vexs_brewery"]:
		assert_eq(state.fund_project(project_id).get_slice(":", 1), " built. Walk outside and see.")
	assert_eq(state.fund_project("the_inn"), "The inn and the homes: built - and Pixelheim is a hamlet now.")
	assert_eq(state.town_tier(), 1)
	var map := _town()
	for door: Vector2i in RUINED_DOORS:
		assert_true(map.portals.has(door), "the door at %s is back" % door)
	assert_eq(Town.ashes_tent(Town.done_projects(state.settlement)), Vector2i(-1, -1), "the tent is struck")
	assert_eq(Npcs.on_map("town_smith", 1, [], Town.done_projects(state.settlement)).size(), 1, "Hilda is back at her anvil")


func test_a_hero_from_before_keeps_the_village() -> void:
	var town := SettlementState.new()
	town.town_tier = 1
	assert_true(Town.ruins(Town.done_projects(town)).is_empty())
