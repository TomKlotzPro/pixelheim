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
		"actor": ["sheet", "family"], "eyes": ["at"],
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
				assert_true(String(step["stage"]) in ["village", "path", "dark"], "%s is a stage" % step["stage"])


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
