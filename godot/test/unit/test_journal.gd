extends GutTest
## The journal's quest page as rows (PIX-239): every open thread grouped -
## the main story and the quests that carry it, the town and its people, the
## bounty board - each in the words of the line above the dock, and the one
## followed: chosen in the journal, let go once it's done.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _rows() -> Array[Dictionary]:
	return Journal.rows(state.progression, state.settlement, state.pack.items)


func _followed() -> String:
	return Journal.followed(state.progression, state.settlement, state.pack.items)


func _ids(rows: Array[Dictionary]) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row["id"])


## A few threads in hand, as the harness's `journal` stages them: the slimes
## part done, the cheese ready (a new hero carries a wheel), the rum, Maren's
## relics and the Black Seam carrying the story, the troll kept.
func _stage() -> void:
	state.progression.quests.merge({
		"slime_trouble": {"progress": 2, "done": false},
		"cheese_run": {"progress": 0, "done": false},
		"troll_toll": {"progress": 1, "done": true},
		"maren_relics": {"progress": 0, "done": false},
		"garrick_seam": {"progress": 0, "done": false},
		"sela_rum": {"progress": 0, "done": false},
	})


func test_a_new_hero_has_the_main_story_alone_and_follows_it() -> void:
	var rows := _rows()
	assert_eq(_ids(rows), [Journal.STORY], "one thread: the story")
	assert_eq(rows[0]["group"], "story")
	assert_string_starts_with(rows[0]["title"], "Chapter 1")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_eq(rows[0]["line"], Bearing.line(lead), "its line is the line above the dock")
	assert_eq(_followed(), Journal.STORY)


func test_threads_are_grouped_story_town_bounties_and_the_kept_are_gone() -> void:
	_stage()
	# Floor 2 cleared: Old Greymaw's notice goes up.
	state.progression.cleared_levels.append(2)
	var rows := _rows()
	var groups := rows.map(func(row: Dictionary) -> String: return row["group"])
	assert_eq(groups, ["story", "story", "story", "people", "people", "people", "bounties"], "in the page's order")
	assert_eq(_ids(rows).slice(0, 3), [Journal.STORY, "maren_relics", "garrick_seam"], "the story, then what carries it")
	assert_true("slime_trouble" in _ids(rows) and "sela_rum" in _ids(rows) and "cheese_run" in _ids(rows))
	assert_false("troll_toll" in _ids(rows), "a quest kept isn't a thread any more")
	assert_eq(rows[-1]["id"], "greymaw", "the board's notice")
	assert_gt(int(rows[-1]["bounty"]), 0, "with its gold")
	assert_eq(Journal.kept(state.progression).map(func(quest: Dictionary) -> String: return quest["id"]), ["troll_toll"])


func test_a_row_says_its_step_its_count_and_when_it_is_ready() -> void:
	_stage()
	var by_id := {}
	for row in _rows():
		by_id[row["id"]] = row
	var slimes: Dictionary = by_id["slime_trouble"]
	assert_eq(slimes["progress"], "2/3", "the count, apart")
	assert_false("(2/3)" in slimes["line"], "not said twice")
	var lead := Bearing.of_quest(Quests.by_id("slime_trouble"), state.progression, state.settlement, state.pack.items)
	assert_eq(Bearing.line(lead), "%s (2/3)" % slimes["line"], "the line above the dock, less its count")
	assert_false(slimes["ready"])
	var cheese: Dictionary = by_id["cheese_run"]
	assert_true(cheese["ready"], "the wheel is in the pack")
	assert_string_starts_with(cheese["line"], "Hand it in to Bram", "and to whom")
	assert_ne(slimes["detail"], "", "what was asked, for the strip under the list")


func test_following_a_quest_and_the_story_again() -> void:
	_stage()
	assert_true(Journal.follow(state.progression, "slime_trouble"))
	assert_eq(state.progression.tracked, "slime_trouble")
	assert_eq(_followed(), "slime_trouble", "the row followed")
	assert_eq(Bearing.active(state.progression, state.settlement, state.pack.items)["quest_id"], "slime_trouble", "and where the hero is headed")
	assert_false(Journal.follow(state.progression, "slime_trouble"), "followed already: nothing changes")
	assert_true(Journal.follow(state.progression, Journal.STORY))
	assert_eq(state.progression.tracked, "", "the main story follows nothing else")
	assert_eq(_followed(), Journal.STORY)
	var saved := {}
	state.progression.write_into(saved)
	assert_false(saved.has("tracked"), "and the save says nothing of it")


func test_a_bounty_followed_leads_to_its_lair() -> void:
	state.progression.cleared_levels.append(2)
	Journal.follow(state.progression, "greymaw")
	var lead := Bearing.active(state.progression, state.settlement, state.pack.items)
	assert_false(lead["main"])
	assert_eq(lead["named"], "greymaw")
	var greymaw := Hunts.named("greymaw")
	assert_eq(lead["map_id"], greymaw["mapId"])
	assert_eq(lead["cell"], Hunts.lair(greymaw), "to its lair")
	assert_string_contains(lead["step"], greymaw["name"], "the line above the dock names it")
	assert_eq(_followed(), "greymaw")


func test_a_bounty_not_on_the_board_is_not_followed() -> void:
	Journal.follow(state.progression, "greymaw")
	assert_true(Bearing.active(state.progression, state.settlement, state.pack.items)["main"], "not posted yet: the story leads")
	assert_eq(_followed(), Journal.STORY)


func test_a_quest_handed_in_is_let_go() -> void:
	state.progression.quests["cheese_run"] = {"progress": 0, "done": false}
	Journal.follow(state.progression, "cheese_run")
	state.questing.resolve_quests("villager_bram")
	assert_true(state.progression.quests["cheese_run"]["done"], "handed in")
	assert_eq(state.progression.tracked, "", "and no longer followed")
	assert_eq(_followed(), Journal.STORY)


func test_a_bounty_slain_is_let_go() -> void:
	state.progression.cleared_levels.append(2)
	Journal.follow(state.progression, "greymaw")
	state.spoils.hunted("greymaw")
	assert_eq(state.progression.tracked, "", "its quarry is dead")
	assert_false("greymaw" in _ids(_rows()), "and its notice is no thread")


func test_another_quest_done_leaves_the_one_followed() -> void:
	state.progression.quests["slime_trouble"] = {"progress": 1, "done": false}
	state.progression.quests["cheese_run"] = {"progress": 0, "done": false}
	Journal.follow(state.progression, "slime_trouble")
	state.questing.resolve_quests("villager_bram")
	assert_eq(state.progression.tracked, "slime_trouble")


func test_a_step_that_is_a_sentence_drops_its_stop_before_the_place() -> void:
	var lead := {"step": "Hand it in to Bram.", "place": "Pixelheim", "progress": ""}
	assert_eq(Bearing.line(lead), "Hand it in to Bram - Pixelheim")
	lead["progress"] = "3/3"
	assert_eq(Bearing.line(lead), "Hand it in to Bram - Pixelheim (3/3)")
	lead["place"] = ""
	lead["progress"] = ""
	assert_eq(Bearing.line(lead), "Hand it in to Bram.", "alone, it keeps it")
