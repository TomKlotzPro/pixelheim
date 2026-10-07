extends CanvasLayer
## A conversation: the speaker's name, one line at a time, and what E does
## next (ADVANCE_DIALOGUE). The world holds still while it is open, like the
## web game's modal dialogue; closing tells GameState so settlers and quests
## can answer (PIX-124/125 hook dialogue_closed).

var npc: Dictionary
var page := 0
var text: Label
var hint: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 4
	get_tree().paused = true

	var panel := PanelContainer.new()
	panel.position = Vector2(160, 540)
	panel.custom_minimum_size = Vector2(960, 140)
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 18))
	add_child(panel)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 8)
	panel.add_child(lines)
	lines.add_child(UiStyle.label(npc["name"], 16, UiStyle.LAMP))
	text = UiStyle.label("", 18, UiStyle.INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(920, 0)
	lines.add_child(text)
	hint = UiStyle.label("", 14, UiStyle.FADED)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	lines.add_child(hint)
	_show()


## E, Enter, Space or a click turns the page (and closes after the last);
## Esc or a step in any direction leaves at any line.
func _unhandled_input(event: InputEvent) -> void:
	var click: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var leave: bool = event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")
	for move: String in ["move_up", "move_down", "move_left", "move_right"]:
		leave = leave or event.is_action_pressed(move)
	if click or event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()
	elif leave:
		get_viewport().set_input_as_handled()
		_close()


func _advance() -> void:
	if page >= npc["lines"].size() - 1:
		_close()
		return
	page += 1
	_show()


func _show() -> void:
	text.text = npc["lines"][page]
	var last: bool = page >= npc["lines"].size() - 1
	hint.text = "E  close" if last else "%d/%d     E  next     Esc  leave" % [page + 1, npc["lines"].size()]


func _close() -> void:
	get_tree().paused = false
	queue_free()
	GameState.finish_dialogue(npc["id"])
