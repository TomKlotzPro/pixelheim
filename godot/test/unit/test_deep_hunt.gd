extends GutTest
## The Deep Hunt (PIX-161): below Morvax's throne, depths without end - the
## same every visit, harder each depth, foes from every family, an elite
## guardian every third depth - and the deepest depth kept in the save.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _guardian_level(level: int) -> int:
	var guardian := Dungeons.boss_of(level)
	return int(Bestiary.spawn(guardian["monsterId"], guardian.get("elite", false), int(guardian["lift"]))["level"])


func test_a_depth_is_the_same_every_visit_and_harder_than_the_last() -> void:
	var first := Dungeons.floor_def(16)
	assert_true(Dungeons.is_deep(16))
	assert_eq(Dungeons.depth_of(16), 1)
	assert_eq(Dungeons.floor_def(16), first, "generated once, the same after")
	assert_between(first["encounters"].size(), 3, 6)
	assert_lt(_guardian_level(16), _guardian_level(20), "deeper is harder")
	assert_eq(_guardian_level(16), int(Bestiary._data()["deepHunt"]["startLevel"]))
	assert_eq(Dungeons.floor_def(40)["encounters"].size(), 6, "never more than six")


func test_foes_come_from_every_family_and_never_the_bosses() -> void:
	var families := {}
	for depth in range(1, 7):
		for encounter: Dictionary in Dungeons.deep_def(depth)["encounters"]:
			assert_false(Bestiary.is_boss(encounter["monsterId"]), "%s is no boss" % encounter["monsterId"])
			families[Bestiary.family_of(encounter["monsterId"])] = true
	assert_gte(families.size(), 5, "mixed foes: %s" % [families.keys()])


func test_an_elite_guards_every_third_depth() -> void:
	for depth in range(1, 10):
		var guardian: Dictionary = Dungeons.boss_of(Dungeons.floor_count() + depth)
		assert_eq(guardian.get("elite", false), depth % 3 == 0, "depth %d" % depth)


func test_every_depth_can_be_walked_to_its_guardian() -> void:
	for level in range(16, 22):
		var plan := DungeonFloor.plan(level)
		var map: MapData = plan["map"]
		assert_eq(plan["foes"].size(), Dungeons.floor_def(level)["encounters"].size())
		assert_true(map.is_walkable(plan["foes"][-1]["cell"]), "depth %d's guardian stands on floor" % (level - 15))
		assert_gt(int(plan["foes"][-1]["lift"]), 0)


func test_the_deepest_depth_is_kept_and_its_hoard_paid_once() -> void:
	var gold: int = state.pack.gold
	var result: Dictionary = state.clear_deep(17)
	assert_true(result["first"])
	assert_eq(state.progression.deepest, 2)
	assert_eq(state.pack.gold, gold + int(Dungeons.floor_def(17)["rewardGold"]))
	var again: Dictionary = state.clear_deep(16)
	assert_false(again["first"], "depth 1 is shallower than the record")
	assert_eq(state.progression.deepest, 2)
	var saved := {}
	state.progression.write_into(saved)
	assert_eq(saved["deepHunt"], 2)
	assert_eq(ProgressionState.from_dict(saved).deepest, 2)
	var fresh := {}
	ProgressionState.new().write_into(fresh)
	assert_false(fresh.has("deepHunt"), "a save from before stays as it was")


func test_morvax_falls_and_the_stair_goes_on() -> void:
	state.progression.unlocked_level = 15
	var lines: Array = state.clear_floor(15)["lines"]
	assert_true(lines.any(func(line: String) -> bool: return line.contains("Deep Hunt")))
