extends GutTest
## Cutscenes (PIX-31): scenes are data (assets/data/story.json) that the
## Cutscene screen plays; Esc always skips to what comes next, once.


## The world as a screen finds it (Screen._put_hud_aside): its HUD.
## The scene a cutscene finds the HUD on: Screen reads it off a `World`.
class FakeWorld extends "res://test/bare_world.gd":
	pass


func _press(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


func test_every_step_is_a_kind_the_player_knows_with_what_it_needs() -> void:
	var needs := {
		"stage": ["stage"], "fade": ["to"], "caption": ["text"], "tint": ["color"],
		"actor": ["sheet", "family"], "card": ["text"], "credits": ["seconds"],
	}
	for scene_id: String in Cutscene.scenes():
		var steps: Array = Cutscene.scenes()[scene_id]
		assert_gt(steps.size(), 0, "%s has steps" % scene_id)
		# The actors a scene has named so far, and whether its stage is the world.
		var cast := {}
		var on_world := false
		for step: Dictionary in steps:
			assert_true(String(step["kind"]) in Cutscene.KINDS, "%s: %s is a step" % [scene_id, step["kind"]])
			if step["kind"] == "stage":
				assert_true(String(step["stage"]) in Cutscene.STAGES, "%s is a stage" % step["stage"])
				on_world = step["stage"] == "world"
				cast.clear()
			# A step naming an actor on stage moves it on or changes what it does
			# (PIX-253 step 9: Fafnyr takes off).
			if step["kind"] == "actor" and cast.has(String(step.get("name", ""))):
				assert_true(step.has("to") or step.has("to_cell") or step.has("anim") or step.has("dir"), "%s: %s does something" % [scene_id, step["name"]])
				continue
			# A villager (PIX-405: Maren) comes dressed as they are in the world.
			var dressed := step.has("villager")
			if dressed:
				assert_true(PunyArt.VILLAGERS.has(step["villager"]), "%s: %s is a villager" % [scene_id, step["villager"]])
			for field: String in [] if dressed else needs.get(step["kind"], []):
				assert_true(step.has(field), "%s: a %s step needs %s" % [scene_id, step["kind"], field])
			if step["kind"] == "actor":
				var sheet: String = PunyArt.villager(step["villager"])["sheet"] if dressed else step["sheet"]
				assert_true(ResourceLoader.exists(PunyArt.path(sheet)), "%s is one of Shade's sheets" % sheet)
				assert_true(step.has("at") or step.has("cell") or (step.has("from") and step.has("to")), "an actor stands or crosses")
				# On the world's stage an actor stands on a cell of it.
				assert_eq(step.has("cell"), on_world, "%s: %s stands where its stage is" % [scene_id, sheet])
				if step.has("name"):
					cast[String(step["name"])] = true


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


func test_a_seen_moment_is_kept_in_the_save_and_only_once() -> void:
	var state := ProgressionState.new()
	var bare := {}
	state.write_into(bare)
	assert_false(bare.has("storySeen"), "none written while there is none")
	state.story_seen.append("fafnyr")
	var written := {}
	state.write_into(written)
	assert_eq(written["storySeen"], ["fafnyr"])
	written["quests"] = {}
	var back := ProgressionState.from_dict(written)
	assert_eq(back.story_seen, ["fafnyr"] as Array[String])



## PIX-368: Lantern Night's pass opened with the Saltmere waystation's sign
## near the top of the screen, and the letterbox's top bar cut it in half.
## Every cutscene puts the HUD aside while it plays, and it's back after.
func test_nothing_of_the_hud_stands_under_a_cutscene_bar() -> void:
	var tree := get_tree()
	var kept := tree.current_scene
	var world := FakeWorld.new()
	world.hud = Hud.new()
	world.hud.root = CanvasLayer.new()
	world.add_child(world.hud.root)
	tree.root.add_child(world)
	tree.current_scene = world
	# The sign's plate where the shot had it, over the hut at the top.
	var plate := PanelContainer.new()
	plate.position = Vector2(498, 52)
	plate.size = Vector2(284, 66)
	world.hud.root.add_child(plate)
	var scene := Cutscene.new()
	tree.root.add_child(scene)
	var bar := Rect2(0, 0, Cutscene.VIEW.x, Cutscene.BAR)
	var under := world.hud.root.visible and plate.get_global_rect().intersects(bar)
	scene.finish()
	await tree.process_frame
	await tree.process_frame
	var back := world.hud.root.visible
	tree.current_scene = kept
	world.hud.free()
	world.free()
	tree.paused = false
	assert_false(under, "the sign's plate under the top bar")
	assert_true(back, "the HUD back once the scene ends")


## A click on the opening went through to the title's planks under it (crash
## hunt, 2026-11-16): the scene takes it and moves on.
func test_a_click_moves_the_scene_on_and_reaches_nothing_under_it() -> void:
	var scene := Cutscene.new()
	get_tree().root.add_child(scene)
	var catchers := scene.get_children().filter(func(node: Node) -> bool:
		return node is Control and (node as Control).mouse_filter == Control.MOUSE_FILTER_STOP and (node as Control).size == Cutscene.VIEW)
	assert_eq(catchers.size(), 1, "one control over the whole view takes the mouse")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	scene.advance = false
	(catchers[0] as Control).gui_input.emit(click)
	assert_true(scene.advance, "and a click moves the scene on")
	scene.finish()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().paused = false
