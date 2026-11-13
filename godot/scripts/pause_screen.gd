extends Screen
## areas: screen
## The Escape menu (PauseMenu.tsx): resume, the saves (slots and codes),
## options, or back to the title. Progress saves itself. W/S choose, E or
## Enter takes it, Esc resumes. The world holds still.

const Options := preload("res://scripts/options_screen.gd")

var world: Node
var options: Array[Dictionary] = []
var selected := 0
var menu: VBoxContainer
## The line under the title (PIX-302 step 4): when the game last saved,
## "Saved 12 s ago", kept to the second while the menu is open (the
## autosave runs under it).
var saved_line: Label
## Its card and keys, put aside while a screen over it (Saves, Options)
## shows its own in their place.
var card: PanelContainer
var keys: Control


func _open() -> void:
	layer = 6
	dim(0.85)
	card = PanelContainer.new()
	card.position = Vector2(470, 170)
	card.custom_minimum_size = Vector2(340, 340)
	# Centred whatever its words (PIX-213: French ran it off-centre).
	card.resized.connect(func() -> void: card.position = ((Vector2(1280, 720) - card.size) / 2.0).round())
	card.add_theme_stylebox_override("panel", UiStyle.window(UiStyle.INSET))
	add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	var title := UiStyle.heading("Paused", 20, UiStyle.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	saved_line = UiStyle.label("", 13, UiStyle.FADED)
	saved_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(saved_line)
	_process(0.0)
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 8)
	column.add_child(menu)
	var footer := UiStyle.label("Progress is saved automatically.", 13, UiStyle.FADED)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.custom_minimum_size = Vector2(296, 0)
	column.add_child(footer)
	# Its keys along the bottom, as every screen's (PIX-388).
	_name_keys()
	options = [
		{"label": "Resume", "action": _resume},
		{"label": "Saves", "action": _saves},
		{"label": "Options", "action": _options},
		{"label": "Quit to title", "action": _quit},
	]
	# A language chosen in Options rebuilt the world in it (PIX-428):
	# Options open again over the menu, on that row.
	if Options.back_at >= 0:
		_take(2)
	_draw()


func _draw() -> void:
	Layout.clear(menu)
	for index in options.size():
		var button := UiStyle.button(options[index]["label"], _take.bind(index))
		button.custom_minimum_size = Vector2(296, UiStyle.PLANK)
		UiStyle.focus(button, index == selected)
		menu.add_child(button)


func _process(_delta: float) -> void:
	if saved_line == null:
		return
	saved_line.visible = GameState.saved_clock >= 0.0
	var text := SlotCard.saved_ago(int(GameClock.seconds() - GameState.saved_clock))
	if saved_line.text != text:
		saved_line.text = text


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = func() -> void:
			selected = wrapi(selected - 1, 0, options.size())
			Sound.play("ui_tick")
			_draw()
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = func() -> void:
			selected = wrapi(selected + 1, 0, options.size())
			Sound.play("ui_tick")
			_draw()
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		command = _take.bind(selected)
	return command


func _take(index: int) -> void:
	selected = index
	options[index]["action"].call()


func _resume() -> void:
	close()


## The saves over the pause menu, as Options (PIX-427: it closed the menu
## first, so Esc went back to play); playing the hero in hand is Resume.
func _saves() -> void:
	var screen := preload("res://scripts/saves_screen.gd").new()
	screen.on_play_current = _resume
	open_over(screen, [card, keys])


func _options() -> void:
	var screen := Options.new()
	screen.world = world
	open_over(screen, [card, keys])
	screen.tree_exited.connect(_name_keys)


## The keys along the bottom, written again as Options close: a key may
## have been rebound there (PIX-480).
func _name_keys() -> void:
	if keys != null:
		if not is_inside_tree() or is_queued_for_deletion():
			return
		remove_child(keys)
		keys.queue_free()
	keys = UiStyle.screen_footer("{key:move_up}/{key:move_down}  choose      {key:interact}  do it      Esc  close")
	add_child(keys)


## Back to the title: the hero is saved first, then the world starts over.
func _quit() -> void:
	GameState.save_now()
	GameState.title_seen = false
	reload_world()
