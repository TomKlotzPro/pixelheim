extends GutTest
## The mountain last (PIX-170): the gate is barred after the Night of Ash
## until Maren has the four relics, in any order; a hero who climbed before
## keeps the gate open; each relic brings Maren's story of its owner, a
## bounty notice and, two at a time, the town's next age.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _next() -> String:
	return MainQuest.next_step(state.progression, state.settlement).get("id", "")


func _win(named_id: String) -> void:
	state.defeat_monster(Hunts.fighter(named_id), Hunts.named(named_id)["mapId"], "", 10)


func test_every_relic_is_its_chapter_bosss_drop() -> void:
	assert_eq(Relics.all().size(), 4)
	for relic: Dictionary in Relics.all():
		assert_eq(Hunts.named(relic["named"])["drop"], relic["itemId"], relic["itemId"])
		assert_true(Catalog.item(relic["itemId"]).get("quest", false), "%s is a quest item" % relic["itemId"])
	assert_true(Catalog.item("marens_promise").get("quest", false))


func test_the_gate_is_barred_until_the_relics_are_home() -> void:
	assert_false(Relics.gate_open(state.progression), "a new hero finds it barred")
	assert_string_contains(Relics.barred_line(), "Maren")
	state.resolve_quests("elder")
	# Any order: the iron first, then the lantern, the shield, the ladle.
	for named_id: String in ["seam_warden", "rimefang", "hollow_captain"]:
		_win(named_id)
	assert_eq(Relics.found(state.progression), 3)
	assert_string_contains(state.resolve_quests("elder"), "3/4")
	assert_false(Relics.gate_open(state.progression))
	_win("tidecaller")
	assert_string_contains(state.resolve_quests("elder"), "Quest complete: The Five Relics")
	assert_true(Relics.gate_open(state.progression))
	assert_eq(Relics.found(state.progression), 4)
	for relic: Dictionary in Relics.all():
		assert_eq(int(state.pack.items.get(relic["itemId"], 0)), 0, "%s is set in the gate" % relic["itemId"])
	assert_eq(int(state.pack.items.get("marens_promise", 0)), 1)
	assert_eq(_next(), "cellar", "then the climb")


func test_a_hero_who_climbed_before_keeps_the_gate_open() -> void:
	state.progression.unlocked_level = 2
	state.clear_floor(1)
	assert_true(Relics.gate_open(state.progression))
	assert_eq(_next(), "crypt", "and the relics never block the way they already went")
	assert_string_contains(state.resolve_quests("elder"), "The Troll Toll", "Maren goes on to her next ask")


func test_the_relic_steps_point_at_the_first_one_missing() -> void:
	state.progression.quests["slime_trouble"] = {"progress": 3, "done": true}
	state.progression.quests["innkeeper"] = {"progress": 0, "done": true}
	state.resolve_quests("elder")
	state.settlement.town_tier = 1
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	_win("seam_warden")
	assert_eq(_next(), "ladle", "the ingot is won; the ladle is still out there")
	_win("tidecaller")
	assert_eq(_next(), "settler")


func test_maren_tells_of_each_relic_once() -> void:
	assert_eq(Story.elder_story([], [], []), {})
	assert_eq(Story.elder_story([], [], ["hollow_captain"])["id"], "maren_oskar")
	assert_eq(Story.elder_story([], ["maren_oskar"], ["hollow_captain"]), {})
	# A relic's story comes before the floors' news.
	assert_eq(Story.elder_story([3], [], ["rimefang"])["id"], "maren_liane")
	assert_eq(Story.elder_story([3], ["maren_liane"], ["rimefang"])["id"], "maren_graves")


func test_the_relics_post_bounties_and_grow_the_town() -> void:
	assert_eq(Hunts.notices(state.board_floors(), []), [] as Array[Dictionary])
	_win("tidecaller")
	assert_eq(Hunts.notices(state.board_floors(), []).map(func(entry: Dictionary) -> String: return entry["id"]), ["greymaw"])
	state.settlement.settlers.append("settler_iva")
	assert_eq(Town.age_blockers(2, state.progression, state.settlement).size(), 1, "one relic is not enough for the Village")
	_win("seam_warden")
	assert_eq(Town.age_blockers(2, state.progression, state.settlement), [] as Array[String])
	assert_eq(Town.age_blockers(3, state.progression, state.settlement).size(), 1)


func test_the_old_way_still_grows_the_town() -> void:
	state.settlement.settlers.append("settler_iva")
	state.progression.cleared_levels.append(5)
	assert_eq(Town.age_blockers(2, state.progression, state.settlement), [] as Array[String], "a hero who cleared the Watchtower first")
