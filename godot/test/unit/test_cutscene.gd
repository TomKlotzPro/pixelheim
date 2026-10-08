extends GutTest
## Cutscenes (PIX-31): scenes are data (assets/data/story.json) that the
## Cutscene screen plays; Esc always skips to what comes next, once.


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_every_step_is_a_kind_the_player_knows_with_what_it_needs() -> void:
	var needs := {
		"stage": ["stage"], "fade": ["to"], "caption": ["text"], "tint": ["color"],
		"actor": ["sheet", "family"], "eyes": ["at"], "card": ["text"], "credits": ["seconds"],
	}
	for scene_id: String in Cutscene.scenes():
		var steps: Array = Cutscene.scenes()[scene_id]
		assert_gt(steps.size(), 0, "%s has steps" % scene_id)
		for step: Dictionary in steps:
			assert_true(String(step["kind"]) in Cutscene.KINDS, "%s: %s is a step" % [scene_id, step["kind"]])
			for field: String in needs.get(step["kind"], []):
				assert_true(step.has(field), "%s: a %s step needs %s" % [scene_id, step["kind"], field])
			if step["kind"] == "actor":
				assert_true(ResourceLoader.exists(PunyArt.path(step["sheet"])), "%s is one of Shade's sheets" % step["sheet"])
				assert_true(step.has("at") or (step.has("from") and step.has("to")), "an actor stands or crosses")
			if step["kind"] == "stage":
				assert_true(String(step["stage"]) in Cutscene.STAGES, "%s is a stage" % step["stage"])


func test_the_opening_ends_on_black_before_hero_creation() -> void:
	var opening: Array = Cutscene.scenes()["opening"]
	assert_eq(opening[0]["kind"], "stage", "it sets its stage first")
	var last: Dictionary = opening[-1]
	assert_eq([last["kind"], last.get("to")], ["fade", "black"])


func test_esc_skips_to_what_comes_next_once() -> void:
	var scene := Cutscene.new()
	var calls := [0]
	scene.on_done = func() -> void: calls[0] += 1
	var skip := scene._command(_press(&"ui_cancel"))
	assert_true(skip.is_valid(), "Esc is the cutscene's own")
	skip.call()
	skip.call()
	assert_eq(calls[0], 1, "what comes next comes once")
	assert_true(scene.finished)
	assert_false(scene._closes_on(_press(&"ui_cancel")), "Esc never just closes it")


func test_e_moves_on_without_ending() -> void:
	var scene: Cutscene = autofree(Cutscene.new())
	var next := scene._command(_press(&"interact"))
	next.call()
	assert_true(scene.advance)
	assert_false(scene.finished)


## The story's big moments (PIX-32): each names a scene that exists, and the
## floors' bosses have theirs.
func test_every_moment_plays_a_scene_that_exists() -> void:
	for key: String in ["boss:dragon", "boss:lich", "cleared:10", "victory"]:
		var scene_id := Cutscene.moment(key)
		assert_ne(scene_id, "", "%s has a moment" % key)
		assert_true(Cutscene.scenes().has(scene_id), "%s plays %s" % [key, scene_id])
	assert_eq(Cutscene.moment("boss:%s" % Dungeons.boss_of(10)["monsterId"]), "fafnyr")
	assert_eq(Cutscene.moment("boss:%s" % Dungeons.boss_of(15)["monsterId"]), "morvax")
	assert_eq(Cutscene.moment("boss:slime"), "", "an ordinary floor has none")


func test_a_seen_moment_is_kept_in_the_save_and_only_once() -> void:
	var state := ProgressionState.new()
	var bare := {}
	state.write_into(bare)
	assert_false(bare.has("storySeen"), "saves from before stay byte for byte")
	state.story_seen.append("fafnyr")
	var written := {}
	state.write_into(written)
	assert_eq(written["storySeen"], ["fafnyr"])
	written["unlockedLevel"] = 1
	written["clearedLevels"] = []
	written["quests"] = {}
	written["introSeen"] = true
	var back := ProgressionState.from_dict(written)
	assert_eq(back.story_seen, ["fafnyr"] as Array[String])

