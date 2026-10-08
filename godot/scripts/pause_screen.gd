extends Screen
## The Escape menu (PauseMenu.tsx): resume, the saves (slots and codes),
## options, or back to the title. Progress saves itself. W/S choose, E or
## Enter takes it, Esc resumes. The world holds still.

var world: Node
var options: Array[Dictionary] = []
var selected := 0
var menu: VBoxContainer


func _open() -> void:
	layer = 6
	dim(0.85)
	var card := PanelContainer.new()
	card.position = Vector2(470, 170)
	card.custom_minimum_size = Vector2(340, 340)
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 22))
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var title := UiStyle.heading("Paused", 20, UiStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	column.add_child(menu)
	var footer := UiStyle.label("Progress is saved automatically.", 13, UiStyle.FADED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(footer)
	options = [
		{"label": "Resume", "action": _resume},
		{"label": "Saves", "action": _saves},
		{"label": "Options", "action": _options},
		{"label": "Quit to title", "action": _quit},
	]
	_draw()


func _draw() -> void:
	for child in menu.get_children():
		child.queue_free()
	for index in options.size():
		var button := UiStyle.button(options[index]["label"], _take.bind(index))
		button.custom_minimum_size = Vector2(296, 40)
		button.add_theme_font_size_override("font_size", 17)
		UiStyle.focus(button, index == selected)
		menu.add_child(button)


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = func() -> void:
			selected = wrapi(selected - 1, 0, options.size())
			_draw()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = func() -> void:
			selected = wrapi(selected + 1, 0, options.size())
			_draw()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		command = _take.bind(selected)
	return command


func _take(index: int) -> void:
	selected = index
	options[index]["action"].call()


func _resume() -> void:
	close()


func _saves() -> void:
	_resume()
	world._open_saves()


## Options open over the pause menu and hand back to it when closed.
func _options() -> void:
	var screen := preload("res://scripts/options_screen.gd").new()
	screen.world = world
	add_child(screen)


## Back to the title: the hero is saved first, then the world starts over.
func _quit() -> void:
	GameState.save_now()
	GameState.title_seen = false
	get_tree().paused = false
	get_tree().reload_current_scene()
