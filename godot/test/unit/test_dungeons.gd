extends GutTest
## Dungeons (PIX-126): the floor table and floor select's rules from
## levels.ts / DungeonSelect.tsx, a first clear's hoard (grantFloorRewards),
## the generated floors the hero walks, and Shade's dungeon walls.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_floor_table_is_the_webs() -> void:
	assert_eq(Dungeons.floor_count(), 15)
	assert_eq(Dungeons.dungeon("mountain")["floors"], [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	assert_eq(Dungeons.dungeon("undermountain")["floors"], [11, 12, 13, 14, 15])
	assert_eq(Dungeons.floor_def(1)["name"], "Mossy Cellar")
	assert_eq(Dungeons.boss_of(1), {"monsterId": "slime", "elite": true})
	assert_eq(Dungeons.boss_of(10)["monsterId"], "dragon")
	assert_eq(Dungeons.boss_of(15)["monsterId"], "lich")


func test_floors_open_one_after_another() -> void:
	assert_true(Dungeons.is_open(1, 1))
	assert_false(Dungeons.is_open(2, 1))
	assert_false(Dungeons.any_open("undermountain", 10), "sealed until the dragon falls")
	assert_true(Dungeons.any_open("undermountain", 11))
	assert_eq(Dungeons.unlocked_after(1, 1), 2)
	assert_eq(Dungeons.unlocked_after(1, 6), 6, "replaying an old floor never closes a deeper one")
	assert_eq(Dungeons.unlocked_after(15, 15), 15, "nothing lies below the last floor")


func test_a_first_clear_pays_the_hoard_and_opens_the_next_floor() -> void:
	var gold: int = state.pack.gold
	var gear_before: int = state.pack.gear.size()
	# The Ruined Watchtower's hoard (retuned for the mountain last, PIX-170).
	var result: Dictionary = state.clear_floor(5)
	assert_true(result["first"])
	assert_false(result["victory"])
	assert_eq(state.pack.gold, gold + int(Dungeons.floor_def(5)["rewardGold"]))
	assert_eq(state.pack.gear.size(), gear_before + 1, "the wyrm visor arrives as a piece")
	assert_eq(state.pack.gear[-1]["itemId"], "wyrm_visor")
	assert_eq(state.pack.items.get("elixir", 0), 1 + _starting("elixir"))
	assert_eq(state.progression.cleared_levels, [5])
	assert_eq(state.progression.unlocked_level, 6)


func test_a_floor_pays_its_hoard_once() -> void:
	state.clear_floor(1)
	var gold: int = state.pack.gold
	var result: Dictionary = state.clear_floor(1)
	assert_false(result["first"])
	assert_eq(state.pack.gold, gold)
	assert_eq(state.progression.cleared_levels, [1])


func test_the_last_floors_first_clear_is_victory() -> void:
	state.progression.unlocked_level = 15
	assert_true(state.clear_floor(15)["victory"])
	assert_false(state.clear_floor(15)["victory"])
	assert_eq(state.progression.unlocked_level, 15)


func test_the_bards_song_fades_with_the_outing() -> void:
	state.settlement.bard_song = true
	state.clear_floor(1)
	assert_false(state.settlement.bard_song)


func _starting(item_id: String) -> int:
	var fresh: Node = autofree(GameStateScript.new())
	fresh.new_game("Robin", "warrior")
	return fresh.pack.items.get(item_id, 0)


func test_floors_are_the_same_every_visit() -> void:
	var first: MapData = DungeonFloor.plan(4)["map"]
	var again: MapData = DungeonFloor.plan(4)["map"]
	assert_eq(first.grid, again.grid)
	assert_ne(first.grid, DungeonFloor.plan(5)["map"].grid, "each floor its own")


func test_every_floor_holds_its_encounters_one_per_room() -> void:
	for level in range(1, Dungeons.floor_count() + 1):
		var plan := DungeonFloor.plan(level)
		var encounters: Array = Dungeons.floor_def(level)["encounters"]
		var foes: Array = plan["foes"]
		assert_eq(foes.size(), encounters.size(), "floor %d" % level)
		var guardian: Dictionary = foes[-1]
		assert_eq(guardian["id"], Dungeons.boss_of(level)["monsterId"])
		assert_true(plan["rooms"][-1].has_point(guardian["cell"]), "the guardian waits in the last room")
		assert_eq(plan["rooms"][-1].size, DungeonFloor.GUARDIAN_ROOM)


func test_every_floor_can_be_walked_from_the_stairs_to_its_guardian() -> void:
	for level in range(1, Dungeons.floor_count() + 1):
		var plan := DungeonFloor.plan(level)
		var map: MapData = plan["map"]
		assert_eq(map.floor_level, level)
		assert_eq(map.portals[plan["stairs"]], {"kind": "gate"}, "the stairs lead back to the gate")
		var reached := _walkable_from(map, map.spawn)
		assert_true(reached.has(plan["stairs"]), "floor %d: the way out" % level)
		for foe: Dictionary in plan["foes"]:
			assert_true(reached.has(foe["cell"]), "floor %d: %s reachable" % [level, foe["id"]])
		for cell: Vector2i in reached:
			assert_true(
				cell.x > 0 and cell.y > 0 and cell.x < map.size.x - 1 and cell.y < map.size.y - 1,
				"floor %d: walls hold the floor in" % level
			)


func _walkable_from(map: MapData, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := cell + step
			if not seen.has(next) and map.is_walkable(next):
				seen[next] = true
				queue.append(next)
	return seen


func _room(rows: Array) -> Dictionary:
	var legend := {"#": "wall", ".": "floor", "o": "lamp"}
	var grid := {}
	for y in rows.size():
		for x in (rows[y] as String).length():
			grid[Vector2i(x, y)] = legend[rows[y][x]]
	return grid


func test_walls_follow_shades_grammar() -> void:
	var grid := _room([
		"#######",
		"#######",
		"##...##",
		"##...##",
		"#######",
		"#######",
	])
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(3, 1)), PunyDungeon.FACE[2], "north wall faces the room")
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(1, 1)), PunyDungeon.TOP_END[1], "north-west corner")
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(5, 1)), PunyDungeon.TOP_END[3], "north-east corner")
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(1, 2)), PunyDungeon.TOP_RUN[0], "west wall runs north")
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(3, 4)), PunyDungeon.TOP_END[2], "south wall")
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(1, 4)), PunyDungeon.TOP_RUN[1], "south-west corner")
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(0, 0)), PunyDungeon.VOID, "rock nobody sees is the dark")
	assert_eq(PunyDungeon.wall_tile(grid, Vector2i(3, 5)), PunyDungeon.VOID)


func test_torches_stay_lit_and_uneven_loops_hold_still() -> void:
	var sheet := PunyDungeon.sheet()
	assert_eq(sheet.animation(PunyDungeon.TORCH).size(), 8)
	var slot := sheet.slot(PunyDungeon.TORCH)
	var source := sheet.tileset.get_source(slot[0]) as TileSetAtlasSource
	assert_eq(source.get_tile_animation_frames_count(slot[1]), 8)
	assert_gt(sheet.animation(68).size(), 8, "a spike trap that pauses and loops back")
	var trap := sheet.slot(68)
	var trap_source := sheet.tileset.get_source(trap[0]) as TileSetAtlasSource
	assert_eq(trap_source.get_tile_animation_frames_count(trap[1]), 1, "held on its first frame")
