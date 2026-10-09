extends GutTest
## Saltmere's chapter (PIX-165): its folk give their quests, the Tidecaller
## waits in the sea cave from the start (never on the bounty board) and
## leaves Tam's Ladle, a hunt quest counts it even when it fell first, and
## the jetty's fish bite, then rest.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func test_the_tidecaller_waits_in_the_cave_and_not_on_the_board() -> void:
	var living := Hunts.living_on("seacave", [], [])
	assert_eq(living.map(func(entry: Dictionary) -> String: return entry["id"]), ["tidecaller"])
	assert_false(Hunts.notices(range(1, 16), []).any(func(entry: Dictionary) -> bool: return entry["id"] == "tidecaller"))
	var cave := MapData.load_by_id("seacave")
	assert_eq(cave.style, "cave")
	assert_true(cave.is_walkable(Hunts.lair(Hunts.named("tidecaller"))))


func test_the_coast_has_its_own_creatures() -> void:
	for monster_id: String in ["crab", "pirate", "pirate_gunner", "pirate_captain", "king_slime"]:
		assert_false(Bestiary.monster(monster_id).is_empty(), monster_id)
		assert_ne(Bestiary.family_of(monster_id), "", "%s has a family" % monster_id)
		assert_true(PunyArt.MONSTERS.has(monster_id), "%s is drawn" % monster_id)
	assert_true(Bestiary._data()["eliteMoves"].has("outlaws"))


func test_wennas_chain_ends_in_tams_ladle() -> void:
	assert_eq(Quests.for_giver("saltmere_wenna").map(func(q: Dictionary) -> String: return q["id"]), ["wenna_smugglers", "wenna_tidecaller"])
	state.questing.resolve_quests("saltmere_wenna")
	for i in 3:
		state.spoils.defeat_monster(Bestiary.spawn("pirate"), "coast", "", 2)
	assert_string_contains(state.questing.resolve_quests("saltmere_wenna"), "Quest complete")
	assert_string_contains(state.questing.resolve_quests("saltmere_wenna"), "The Tidecaller")
	state.spoils.defeat_monster(Hunts.fighter("tidecaller"), "seacave", "", 4)
	assert_eq(int(state.pack.items.get("tams_ladle", 0)), 1, "the relic is the hero's")
	assert_string_contains(state.questing.resolve_quests("saltmere_wenna"), "Tam's")
	assert_eq(int(state.pack.items.get("tams_ladle", 0)), 1, "and stays the hero's")


func test_a_hunt_counts_the_quarry_that_fell_first() -> void:
	state.progression.quests["wenna_smugglers"] = {"progress": 3, "done": true}
	state.spoils.defeat_monster(Hunts.fighter("tidecaller"), "seacave", "", 4)
	state.questing.resolve_quests("saltmere_wenna")
	assert_true(Quests.is_ready(Quests.by_id("wenna_tidecaller"), state.progression.quests, state.pack.items))


func test_a_plain_crab_is_no_tidecaller() -> void:
	state.progression.quests["wenna_smugglers"] = {"progress": 3, "done": true}
	state.questing.resolve_quests("saltmere_wenna")
	state.spoils.defeat_monster(Bestiary.spawn("king_slime"), "seacave", "", 4)
	assert_false(Quests.is_ready(Quests.by_id("wenna_tidecaller"), state.progression.quests, state.pack.items))


func test_the_jetty_bites_then_rests() -> void:
	var spot := Gathering.fishing_spot_at("saltmere", Vector2i(31, 31))
	assert_eq(spot.get("id", ""), "saltmere_jetty")
	var map := MapData.load_by_id("saltmere")
	for entry: Dictionary in Bestiary._data()["fishingSpots"]:
		var at := Vector2i(int(entry["x"]), int(entry["y"]))
		assert_true(map.is_walkable(at), "%s stands on ground" % entry["id"])
	var before: int = state.pack.items.values().reduce(func(sum: int, n: int) -> int: return sum + n, 0)
	assert_string_contains(state.spoils.fish("saltmere_jetty"), "You cast")
	var after: int = state.pack.items.values().reduce(func(sum: int, n: int) -> int: return sum + n, 0)
	assert_eq(after, before + 1)
	assert_string_contains(state.spoils.fish("saltmere_jetty"), "Nothing's biting")
	for i in 20:
		assert_has(["fresh_fish", "sea_glass", "pearl", "old_boot"], Gathering.catch(func() -> float: return i / 20.0))


func test_pixelheim_sends_the_hero_to_saltmere() -> void:
	assert_eq(Quests.for_giver("kid_pip").map(func(q: Dictionary) -> String: return q["id"]), ["pip_fish"])
	assert_string_contains(Quests.by_id("pip_fish")["accepted"], "Saltmere")
