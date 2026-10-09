extends Screen
## A conversation: the speaker in a portrait slot and a gold name tab on the
## window's edge, one line at a time in the body type, and the keys that
## move it on (ADVANCE_DIALOGUE). The world holds still while it is open, like
## the web game's modal dialogue; closing tells GameState so settlers and
## quests can answer (PIX-124/125 hook dialogue_closed).

const AT := Vector2(150, 516)
const SIZE := Vector2(980, 188)
const PORTRAIT := 112

var npc: Dictionary
## A question at the end (PIX-192): the answers' labels, and what picks one.
var choices: Array = []
var on_choice := Callable()
var page := 0
var text: Label
var counter: Label
var hints: HBoxContainer
var more: TextureRect
var panel: PanelContainer
var tab: PanelContainer


func _open() -> void:
	layer = 4

	panel = PanelContainer.new()
	panel.position = AT
	panel.custom_minimum_size = SIZE
	panel.add_theme_stylebox_override("panel", UiStyle.window(18))
	add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	# A narrator (the victory) has no face; everyone else speaks from a slot.
	if npc.has("sprite"):
		row.add_child(_portrait(npc["sprite"], Npcs.tint_of(String(npc.get("id", "")))))
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	row.add_child(column)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	column.add_child(spacer)
	text = UiStyle.label("", UiStyle.reading(16), UiStyle.INK)
	text.add_theme_constant_override("line_spacing", 6)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(text)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	column.add_child(footer)
	counter = UiStyle.label("", 12, UiStyle.FADED)
	counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(counter)
	hints = HBoxContainer.new()
	footer.add_child(hints)
	more = UiStyle.arrow()
	footer.add_child(more)
	if not GameState.settings.reduce_motion:
		var blink := create_tween().set_loops()
		blink.tween_property(more, "modulate:a", 0.2, 0.45)
		blink.tween_property(more, "modulate:a", 1.0, 0.45)

	# The name tab sits on the window's top edge, over the frame.
	tab = PanelContainer.new()
	tab.add_theme_stylebox_override("panel", UiStyle.plank(true, 8))
	tab.position = AT + Vector2(PORTRAIT + 36 if npc.has("sprite") else 24, -22)
	tab.add_child(UiStyle.strong(npc["name"], 16, UiStyle.GOLD))
	add_child(tab)
	_show()


## The speaker standing in a framed slot, a few times life size, idling.
func _portrait(sprite: String, tint := Color.WHITE) -> Control:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 4))
	var stage := Control.new()
	stage.clip_contents = true
	stage.custom_minimum_size = Vector2(PORTRAIT - 12, PORTRAIT - 12)
	slot.add_child(stage)
	var art := PunyArt.villager(sprite)
	var figure := AnimatedSprite2D.new()
	figure.sprite_frames = PunyArt.frames(art)
	figure.self_modulate = tint
	figure.play(PunyArt.pick(figure.sprite_frames, "idle", "down"))
	# Whole-number zoom: small sheets x6, Shade's 32px cells x4 (the figure
	# stands in the lower half of its cell, so it sits a little higher).
	var zoom := 6 if PunyArt.frame_size(art) <= 16 else 4
	figure.scale = Vector2(zoom, zoom)
	figure.position = Vector2((PORTRAIT - 12) / 2.0, (PORTRAIT - 12) / 2.0 + PunyArt.lift(art) * zoom * 0.5)
	stage.add_child(figure)
	return slot


## E, Enter, Space or a click turns the page (and closes after the last);
## Esc or a step in any direction leaves at any line. At a question, 1, 2...
## answer it (or a click on the answer); E waits for one.
func _command(event: InputEvent) -> Callable:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var leave: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")
	for move: String in ["move_up", "move_down", "move_left", "move_right"]:
		leave = leave or event.is_action_pressed(move)
	if _asking():
		for index in choices.size():
			if event.is_action_pressed("skill_%d" % (index + 1)):
				return _pick.bind(index)
		# Up and down choose an answer, A or E gives it (PIX-215: a pad
		# had no number keys).
		for step: Array in [["move_up", -1], ["move_left", -1], ["move_down", 1], ["move_right", 1]]:
			if event.is_action_pressed(step[0]):
				return _choose.bind(int(step[1]))
		# E or A gives the answer chosen; with none chosen yet it waits, so
		# a page-turning thumb never answers by accident.
		if choice_focus >= 0 and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
			return _pick.bind(choice_focus)
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
			return _close
		return Callable()
	if click or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		return _advance
	if leave:
		return _close
	return Callable()


func _advance() -> void:
	if page >= npc["lines"].size() - 1:
		_close()
		return
	page += 1
	Sound.play_ui("page")
	_show()


## The answer chosen with up and down (PIX-215), lit among the rest.
var choice_focus := -1
var choice_buttons: Array[Button] = []


func _choose(step: int) -> void:
	if choice_focus < 0:
		choice_focus = 0 if step > 0 else choices.size() - 1
	else:
		choice_focus = posmod(choice_focus + step, choices.size())
	Sound.play_ui("tick")
	for index in choice_buttons.size():
		UiStyle.focus(choice_buttons[index], index == choice_focus)


func _asking() -> bool:
	return not choices.is_empty() and page >= npc["lines"].size() - 1


func _pick(index: int) -> void:
	close()
	on_choice.call(index)
	GameState.finish_dialogue(npc["id"])


func _show() -> void:
	text.text = npc["lines"][page]
	var last: bool = page >= npc["lines"].size() - 1
	counter.text = "" if npc["lines"].size() == 1 else "%d / %d" % [page + 1, npc["lines"].size()]
	for child in hints.get_children():
		child.queue_free()
	if _asking():
		# The answers, a key and a click each, and leaving without one.
		choice_buttons.clear()
		for index in choices.size():
			var answer := UiStyle.button(Text.t("%d  %s") % [index + 1, choices[index]], _pick.bind(index))
			UiStyle.focus(answer, index == choice_focus)
			choice_buttons.append(answer)
			hints.add_child(answer)
		hints.add_child(UiStyle.hints(["Esc", "not yet"]))
	else:
		hints.add_child(UiStyle.hints(["{key:interact}", "close"] if last else ["{key:interact}", "next", "Esc", "leave"]))
	more.visible = not last
	_fit.call_deferred()


## A long line in the large type grows the window upward, never off screen.
func _fit() -> void:
	panel.reset_size()
	panel.position.y = minf(AT.y, AT.y + SIZE.y - panel.size.y)
	tab.position.y = panel.position.y - 22


func _close() -> void:
	close()
	GameState.finish_dialogue(npc["id"])
