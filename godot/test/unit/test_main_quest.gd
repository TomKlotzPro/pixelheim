extends GutTest
## The main quest (PIX-144): every step is something the real rules can
## record, the next step follows the hero's real progress, and a hero who
## runs ahead is never sent back for an errand.

const GameStateScript := preload("res://scripts/state/game_state.gd")

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _next() -> String:
	return MainQuest.next_step(state.progression, state.settlement).get("id", "")


func test_every_step_names_a_real_quest_or_floor() -> void:
	var ids := {}
	for step: Dictionary in MainQuest.steps():
		assert_false(ids.has(step["id"]), "%s once" % step["id"])
		ids[step["id"]] = true
		var when: Dictionary = step["when"]
		match String(when["kind"]):
			"questTaken", "questDone":
				assert_false(Quests.by_id(when["questId"]).is_empty(), "%s: a real quest" % step["id"])
			"cleared":
				assert_between(int(when["level"]), 1, Dungeons.floor_count())
				assert_string_contains(step["text"], Dungeons.floor_def(int(when["level"]))["name"].trim_prefix("The "))
			"project":
				assert_false(Town.project(when["projectId"]).is_empty(), "%s: a real project" % step["id"])
			"settlers":
				assert_gt(int(when["count"]), 0)
			_:
				fail_test("%s: unknown kind %s" % [step["id"], when["kind"]])
		assert_ne(step["hint"], "")


func test_the_story_starts_at_the_inn_and_follows_the_real_rules() -> void:
	assert_eq(_next(), "ask_sela")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Ask Sela the innkeeper for work")
	state.resolve_quests("innkeeper")
	assert_eq(_next(), "slimes")
	state.roll = func() -> float: return 0.99
	for i in 3:
		state.defeat_monster(Bestiary.spawn("slime"), "forest", "", 1)
	state.resolve_quests("innkeeper")
	assert_eq(_next(), "cellar")
	state.clear_floor(1)
	assert_eq(_next(), "rebuild", "a new hero's town is ashes: rebuild the inn")
	state.settlement.town_tier = 1
	assert_eq(_next(), "first_brew")


func test_running_ahead_never_sends_the_hero_back() -> void:
	state.progression.unlocked_level = 3
	state.clear_floor(3)
	assert_eq(_next(), "watchtower", "the brew and the inn are behind now")
	state.progression.unlocked_level = 10
	state.clear_floor(10)
	assert_eq(_next(), "fountain", "Fafnyr's scale goes on the square first")
	state.progression.unlocked_level = 11
	state.clear_floor(11)
	assert_eq(_next(), "hoard")
	assert_eq(MainQuest.steps()[MainQuest.steps().map(func(s: Dictionary) -> String: return s["id"]).find("stair")]["chapter"], "The Deathless")


func test_a_grown_town_never_skips_the_mountain() -> void:
	state.settlement.town_tier = 4
	assert_eq(_next(), "ask_sela", "the projects are done, the floors aren't")
	state.progression.unlocked_level = 9
	state.clear_floor(9)
	assert_eq(_next(), "fafnyr")


func test_the_end_is_quiet() -> void:
	state.progression.unlocked_level = 15
	state.clear_floor(15)
	assert_eq(_next(), "")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "", "no line once it's done")
	assert_string_contains(MainQuest.hint(state.progression, state.settlement), "Pixelheim is safe")
