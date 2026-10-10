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
			"seen":
				var stories: Array = Story._data()["elderLines"].map(func(entry: Dictionary) -> String: return entry["id"])
				stories.append(Letters.scene_id())
				# A letter's answer read where it waits (PIX-255: Hale's order book).
				stories.append_array(Letters.readings().map(func(entry: Dictionary) -> String: return entry["sceneId"]))
				assert_has(stories, when["sceneId"], "%s: one of Maren's stories, her tin, or a letter's answer" % step["id"])
			"hunted":
				var relic: Array = Relics.all().filter(func(entry: Dictionary) -> bool: return entry["named"] == when["named"])
				assert_eq(relic.size(), 1, "%s: a relic's chapter boss" % step["id"])
				# Since the letters (PIX-253) the relics come in the story's order.
				assert_false(step.get("optional", false), "%s: the relics are the story" % step["id"])
			"delivered":
				assert_true(Letters.is_letter(Quests.by_id(when["questId"])), "%s: one of Maren's letters" % step["id"])
			_:
				fail_test("%s: unknown kind %s" % [step["id"], when["kind"]])
		assert_ne(step["hint"], "")


func test_the_story_starts_with_marens_tin_and_follows_the_real_rules() -> void:
	# PIX-253: Maren's tin first, then Sela's work.
	assert_eq(_next(), "tin")
	state.questing.finish_dialogue("elder")
	assert_eq(_next(), "ask_sela")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Ask Sela the innkeeper for work")
	state.questing.resolve_quests("innkeeper")
	assert_eq(_next(), "slimes")
	state.roll = func() -> float: return 0.99
	for i in 3:
		state.spoils.defeat_monster(Bestiary.spawn("slime"), "forest", "", 1)
	state.questing.resolve_quests("innkeeper")
	assert_eq(_next(), "rebuild", "a new hero's town is ashes: a roof on the inn")
	state.settlement.town_tier = 1
	assert_eq(_next(), "first_brew")
	state.progression.quests["herbs_for_vex"] = {"progress": 1, "done": true}
	assert_eq(_next(), "letter_wenna", "Maren asked for the relics with the tin: the first letter")


func test_running_ahead_never_sends_the_hero_back() -> void:
	state.progression.unlocked_level = 3
	state.spoils.clear_floor(3)
	assert_eq(_next(), "graves", "the brew and the inn are behind now; the graves are news")
	state.mark_seen("maren_graves")
	assert_eq(_next(), "watchtower")
	state.progression.unlocked_level = 10
	state.spoils.clear_floor(10)
	assert_eq(_next(), "fountain", "Fafnyr's scale goes on the square first")
	state.progression.unlocked_level = 11
	state.spoils.clear_floor(11)
	assert_eq(_next(), "hoard")
	assert_eq(MainQuest.steps()[MainQuest.steps().map(func(s: Dictionary) -> String: return s["id"]).find("stair")]["chapter"], "Coming Home")


func test_a_grown_town_never_skips_the_mountain() -> void:
	state.settlement.town_tier = 4
	assert_eq(_next(), "tin", "the projects are done, the story isn't")
	state.progression.unlocked_level = 9
	state.spoils.clear_floor(9)
	assert_eq(_next(), "fafnyr")


func test_the_end_is_quiet() -> void:
	state.progression.unlocked_level = 15
	state.spoils.clear_floor(15)
	assert_eq(_next(), "")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "", "no line once it's done")
	assert_string_contains(MainQuest.hint(state.progression, state.settlement), "Pixelheim is safe")
