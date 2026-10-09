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
	var result: Dictionary = state.spoils.clear_deep(17)
	assert_true(result["first"])
	assert_eq(state.progression.deepest, 2)
	assert_eq(state.pack.gold, gold + int(Dungeons.floor_def(17)["rewardGold"]))
	var again: Dictionary = state.spoils.clear_deep(16)
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
	var lines: Array = state.spoils.clear_floor(15)["lines"]
	assert_true(lines.any(func(line: String) -> bool: return line.contains("Deep Hunt")))


## PIX-216: a warden every tenth depth, a boss with its own name and attacks.
func test_a_warden_guards_every_tenth_depth() -> void:
	var tenth := Dungeons.boss_of(Dungeons.floor_count() + 10)
	assert_true(Bestiary.is_boss(tenth["monsterId"]), "a boss, with its patterns")
	assert_eq(tenth["name"], "The Deep Warden")
	assert_eq(Dungeons.boss_of(Dungeons.floor_count() + 20)["name"], "The Hollow King")
	assert_gt(_guardian_level(Dungeons.floor_count() + 20), _guardian_level(Dungeons.floor_count() + 10), "deeper wardens stand taller")
	var plan := DungeonFloor.plan(Dungeons.floor_count() + 10)
	assert_eq(plan["foes"][-1]["name"], "The Deep Warden", "the floor knows its name")


func test_a_depth_has_one_twist_and_the_gate_says_which() -> void:
	assert_true(Dungeons.modifier_at(1).is_empty(), "the first depth is plain")
	assert_true(Dungeons.modifier_at(10).is_empty(), "a warden's depth needs no twist")
	assert_eq(Dungeons.modifier_at(7), Dungeons.modifier_at(7), "the same every visit")
	var seen := {}
	for depth in range(2, 40):
		var twist := Dungeons.modifier_at(depth)
		if not twist.is_empty():
			seen[twist["id"]] = true
			assert_gt(Dungeons.loot_luck(Dungeons.floor_count() + depth), 0.0, "a twisted depth drops more")
	assert_eq(seen.size(), Bestiary._data()["deepHunt"]["modifiers"].size(), "every twist turns up: %s" % [seen.keys()])
	assert_eq(Dungeons.loot_luck(3), 0.0, "not on the mountain's own floors")
	for depth in range(2, 40):
		if Dungeons.modifier_at(depth).get("id", "") == "proud":
			var encounters: Array = Dungeons.deep_def(depth)["encounters"]
			assert_true(encounters[0].get("elite", false) and encounters[1].get("elite", false), "depth %d is proud" % depth)


func test_the_gate_opens_the_first_depth_of_every_tier_reached() -> void:
	assert_eq(Dungeons.deep_entries(0), [1] as Array[int])
	assert_eq(Dungeons.deep_entries(4), [1, 5] as Array[int])
	var every := int(Economy._data()["deepTiers"]["every"])
	assert_eq(Dungeons.deep_entries(12), [1, 1 + every, 1 + 2 * every, 13] as Array[int])


func test_a_milestone_brings_a_crystal_home_and_the_town_hears() -> void:
	state.progression.deepest = 4
	var result: Dictionary = state.spoils.clear_deep(Dungeons.floor_count() + 5)
	assert_true(result["first"])
	assert_eq(int(state.pack.items.get("deep_crystal_5", 0)), 1)
	assert_has(state.reveals, "deep:5")
	assert_true(result["lines"].any(func(line: String) -> bool: return line.contains("milestone")))
	var elder: Dictionary = Npcs.on_map("town", 1, [], null, true, 5).filter(func(npc: Dictionary) -> bool: return npc["id"] == "elder")[0]
	assert_eq(elder["lines"][0], Dungeons.milestone(5)["elder"], "Maren has heard")
	assert_eq(Dungeons.next_milestone(5)["depth"], 10)


func test_every_milestone_crystal_is_a_trophy_with_an_icon() -> void:
	var icons: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/puny/icons.json"))["items"]
	for mark: Dictionary in Bestiary._data()["deepHunt"]["milestones"]:
		var item_id: String = mark["itemId"]
		assert_false(Catalog.item(item_id).is_empty(), item_id)
		assert_true(icons.has(item_id), "%s has Shade's art" % item_id)
		assert_false(Town.trophy_stat_delta(item_id).is_empty(), "%s lends stats on the shelf" % item_id)
		assert_ne(String(mark["homecoming"]), "")
		assert_has(Dungeons.deep_def(int(mark["depth"]))["rewardItemIds"], item_id, "its depth's hoard holds it")


## PIX-219: the Deep Hunt's own named monsters, posted as the depths above
## them are cleared, standing as their depth's guardian.
func test_the_deeps_named_are_posted_as_the_depths_above_are_cleared() -> void:
	var grimshade := Hunts.named("grimshade")
	assert_eq(int(grimshade["deepDepth"]) % int(Economy._data()["deepTiers"]["every"]), 1, "it waits on a depth the gate opens")
	assert_eq(Hunts.status(grimshade, Hunts.board_floors(range(1, 16), 5, 4), []), "", "not before depth 5 is cleared")
	var floors := Hunts.board_floors(range(1, 16), 5, 5)
	assert_eq(Hunts.status(grimshade, floors, []), "wanted")
	assert_eq(Hunts.deep_guardian(6, floors, [])["id"], "grimshade")
	assert_true(Hunts.deep_guardian(6, floors, ["grimshade"]).is_empty(), "slain stays slain")
	var elite := Bestiary.spawn("shade", true, Dungeons.deep_level(6) - int(Bestiary.monster("shade")["level"]))
	assert_gt(int(grimshade["maxHp"]), int(elite["maxHp"]) * 2, "bigger than an elite of its depth")
	assert_gte(int(grimshade["level"]), Dungeons.deep_level(6))


func test_a_deep_named_kill_pays_an_epic_deep_piece() -> void:
	state.progression.deepest = 5
	var gear_before: int = state.pack.gear.size()
	state.spoils.defeat_monster(Hunts.fighter("grimshade"), "", "", 1, Dungeons.floor_count() + 6)
	assert_has(state.progression.hunted, "grimshade")
	var prize: Dictionary = state.pack.gear[gear_before]
	assert_eq(prize["itemId"], "shadow_cloak")
	assert_eq(prize["rarity"], "epic")
	assert_eq(int(prize["deep"]), Dungeons.deep_tier(Dungeons.floor_count() + 6))
