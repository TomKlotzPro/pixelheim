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
		_names_something_real(step)
		# An old save's other way to meet it (PIX-257): the old mountain's
		# floors, cleared before they left play.
		var other: Dictionary = step["when"].get("or", {})
		if not other.is_empty():
			assert_has(["cleared", "climbed"], other["kind"], "%s: its `or` is an old save's floors" % step["id"])
			if other["kind"] == "cleared":
				assert_between(int(other["level"]), 1, Dungeons.floor_count())
		assert_ne(step["hint"], "")
	# The old mountain's floors left play (PIX-257): no step asks for one.
	for step: Dictionary in MainQuest.steps():
		assert_ne(step["when"]["kind"], "cleared", "%s asks for a floor that left play" % step["id"])


func _names_something_real(step: Dictionary) -> void:
	var when: Dictionary = step["when"]
	match String(when["kind"]):
		"questTaken", "questDone":
			assert_false(Quests.by_id(when["questId"]).is_empty(), "%s: a real quest" % step["id"])
		"unbuilt":
			# A step a later part of the story writes (PIX-253 step 9):
			# its chapter says so, and it leads somewhere meanwhile.
			var chapter: Dictionary = MainQuest.chapters()[int(step["chapter_number"]) - 1]
			assert_string_contains(String(chapter.get("about", "")), "builds it", "%s: its chapter says what builds it" % step["id"])
			assert_true(step.has("mapId"), "%s leads somewhere meanwhile" % step["id"])
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


## The old mountain's floors left play (PIX-257): a save that cleared any
## of them is past its gate, and the story asks for Maren's confession next
## (PIX-253 step 8), never for the letters or the floors behind it.
func test_running_ahead_never_sends_the_hero_back() -> void:
	state.progression.unlocked_level = 3
	state.spoils.clear_floor(3)
	assert_eq(_next(), "confession", "past the mountain's gate: the brew, the inn and the letters are behind now")
	state.mark_seen("maren_confession")
	assert_eq(_next(), "letter_morvax")
	state.progression.unlocked_level = 10
	state.spoils.clear_floor(10)
	state.progression.quests["letter_morvax"] = {"progress": 1, "done": true}
	assert_eq(_next(), "", "Fafnyr slain on the old mountain: no Night of Bells, and home isn't written yet")


func test_a_grown_town_never_skips_the_mountain() -> void:
	state.settlement.town_tier = 4
	assert_eq(_next(), "tin", "the projects are done, the story isn't")
	state.progression.unlocked_level = 9
	state.spoils.clear_floor(9)
	assert_eq(_next(), "confession")


## Until PIX-253 step 9 writes the Night of Bells, its first step is never
## met: the story waits there, and the run home is honest about it.
func test_the_night_of_bells_waits_unwritten() -> void:
	state.mark_seen("maren_confession")
	state.progression.quests["letter_morvax"] = {"progress": 1, "done": true}
	var step := MainQuest.next_step(state.progression, state.settlement)
	assert_eq(step["id"], "run_home")
	assert_eq(step["chapter"], "The Night of Bells")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "Next: Run home: the dragon is awake")
	assert_eq(MainQuest.continued(state.progression, state.settlement), "The Night of Bells")


func test_the_end_is_quiet() -> void:
	state.progression.unlocked_level = 15
	state.spoils.clear_floor(15)
	assert_eq(_next(), "")
	assert_eq(MainQuest.objective(state.progression, state.settlement), "", "no line once it's done")
	assert_string_contains(MainQuest.hint(state.progression, state.settlement), "Pixelheim is safe")
