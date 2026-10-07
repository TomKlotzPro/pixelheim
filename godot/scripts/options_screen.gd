extends CanvasLayer
## Options (Options.tsx): sound, the CRT scanlines, fullscreen, reduced
## motion, and the keys. W/S choose a row, A/D move a slider or flip a
## switch, E rebinds a key (the next key pressed takes it; Esc cancels).
## Everything is saved at once in GameSettings. Esc closes.

var world: Node
var rows: Array[Dictionary] = []
var selected := 0
## The action waiting for its new key, "" when none.
var listening := ""
## Sound and video on the left, the keys on the right.
var columns: Array[VBoxContainer] = []
var status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 7
	get_tree().paused = true
	var backdrop := ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	add_child(UiStyle.heading("Options", 20, UiStyle.INK, Vector2(80, 24)))
	var card := PanelContainer.new()
	card.position = Vector2(80, 70)
	card.custom_minimum_size = Vector2(1120, 560)
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 16))
	add_child(card)
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 40)
	card.add_child(halves)
	for i in 2:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(520, 0)
		column.add_theme_constant_override("separation", 3)
		halves.add_child(column)
		columns.append(column)
	status = UiStyle.label("", 14, UiStyle.LAMP, Vector2(80, 640))
	add_child(status)
	add_child(UiStyle.footer("W/S  choose      A/D  adjust      E  rebind / toggle      Esc  close", Vector2(80, 680)))
	_refresh()


## The rows: section headings, then a control each.
func _build() -> Array[Dictionary]:
	var settings := GameState.settings
	var out: Array[Dictionary] = []
	out.append({"heading": "Sound"})
	out.append({"label": "Sound", "value": "Muted" if settings.muted else "On", "adjust": _flip.bind("muted")})
	out.append({"label": "Music volume", "value": "%d%%" % roundi(settings.music_volume * 100), "adjust": _volume.bind("music")})
	out.append({"label": "Effects volume", "value": "%d%%" % roundi(settings.sfx_volume * 100), "adjust": _volume.bind("sfx")})
	out.append({"heading": "Video"})
	out.append({"label": "CRT scanlines", "value": "On" if settings.scanlines else "Off", "adjust": _flip.bind("scanlines")})
	out.append({"label": "Fullscreen", "value": "On" if settings.fullscreen else "Off", "adjust": _flip.bind("fullscreen")})
	out.append({"label": "Reduce motion", "value": "On" if settings.reduce_motion else "Off", "adjust": _flip.bind("reduce_motion")})
	out.append({"heading": "Controls", "column": 1})
	for action: String in Controls.BINDABLE:
		var waiting := listening == action
		out.append({
			"label": Controls.BINDABLE[action][0],
			"value": "Press a key..." if waiting else Controls.key_label(Controls.key_for(action, settings.bindings)),
			"rebind": action, "column": 1,
		})
	out.append({"label": "Reset keys to defaults", "value": "", "act": _reset_keys, "column": 1})
	return out


func _refresh() -> void:
	rows = _build()
	var choosable := _choosable()
	selected = clampi(selected, 0, choosable.size() - 1)
	for column in columns:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	for index in rows.size():
		var row: Dictionary = rows[index]
		var list: VBoxContainer = columns[row.get("column", 0)]
		if row.has("heading"):
			list.add_child(UiStyle.label(row["heading"], 15, UiStyle.LAMP))
			continue
		if row.has("note"):
			var note := UiStyle.label(row["note"], 12, UiStyle.FADED)
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			note.custom_minimum_size = Vector2(500, 0)
			list.add_child(note)
			continue
		var chosen := index == choosable[selected]
		var line := PanelContainer.new()
		line.add_theme_stylebox_override("panel", UiStyle.box(
			Color(UiStyle.CARD, 0.9) if chosen else Color(0, 0, 0, 0), UiStyle.LAMP if chosen else Color(0, 0, 0, 0), 4
		))
		var inner := HBoxContainer.new()
		line.add_child(inner)
		var label := UiStyle.label(row["label"], 15, UiStyle.INK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(label)
		inner.add_child(UiStyle.label(row["value"], 15, UiStyle.LAMP if chosen else UiStyle.FADED))
		line.gui_input.connect(_on_row_click.bind(index))
		list.add_child(line)


## Row indices that can be chosen (not the headings).
func _choosable() -> Array[int]:
	var out: Array[int] = []
	for index in rows.size():
		if not rows[index].has("heading") and not rows[index].has("note"):
			out.append(index)
	return out


func _on_row_click(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		selected = _choosable().find(index)
		_act(1)


func _input(event: InputEvent) -> void:
	# While a rebind is armed the next key is the binding, before anything
	# else can take it (Escape cancels).
	if listening == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key != KEY_ESCAPE:
		var settings := GameState.settings
		settings.bindings = Controls.rebind(settings.bindings, listening, key)
		settings.save_file()
		Controls.apply(settings.bindings)
		status.text = "%s is now %s." % [Controls.BINDABLE[listening][0], Controls.key_label(key)]
	listening = ""
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var command := Callable()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		command = _close
	elif event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = _move.bind(-1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = _move.bind(1)
	elif event.is_action_pressed("move_left"):
		command = _act.bind(-1)
	elif event.is_action_pressed("move_right"):
		command = _act.bind(1)
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		command = _act.bind(1)
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()


func _move(step: int) -> void:
	selected = wrapi(selected + step, 0, _choosable().size())
	_refresh()


func _act(direction: int) -> void:
	var row: Dictionary = rows[_choosable()[selected]]
	if row.has("adjust"):
		row["adjust"].call(direction)
	elif row.has("rebind"):
		listening = row["rebind"]
		status.text = "Press the new key for %s (Esc keeps the old one)." % row["label"]
	elif row.has("act"):
		row["act"].call()
	_refresh()


func _volume(direction: int, bus: String) -> void:
	var settings := GameState.settings
	if bus == "music":
		settings.music_volume = clampf(snappedf(settings.music_volume + direction * 0.1, 0.1), 0.0, 1.0)
	else:
		settings.sfx_volume = clampf(snappedf(settings.sfx_volume + direction * 0.1, 0.1), 0.0, 1.0)
	settings.save_file()
	Sound.apply_volumes()
	if bus == "sfx":
		Sound.play("coin")


func _flip(_direction: int, setting: String) -> void:
	var settings := GameState.settings
	settings.set(setting, not settings.get(setting))
	settings.save_file()
	Sound.apply_volumes()
	if world != null:
		world.apply_video()


func _reset_keys() -> void:
	GameState.settings.bindings = {}
	GameState.settings.save_file()
	Controls.apply({})
	status.text = "Keys are back to the defaults."


func _close() -> void:
	queue_free()
	# Over the pause menu the world stays paused; on its own it resumes.
	if not (get_parent() is CanvasLayer):
		get_tree().paused = false
