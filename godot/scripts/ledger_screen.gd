extends CanvasLayer
## Shared frame for the town's ledgers (town hall, bank): a title, a column of
## info text, and a list of actions to choose with W/S and take with E — every
## row clickable too. Subclasses fill `_title`, `_intro` and `_rows`. Pauses
## the world while open.

var rows: Array[Dictionary] = []
var selected := 0
var list: VBoxContainer
var info: Label
var info_card: PanelContainer
var gold_label: Label
var status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	get_tree().paused = true
	var backdrop := ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	add_child(UiStyle.heading(_title(), 20, UiStyle.INK, Vector2(80, 32)))
	add_child(UiStyle.label(_intro(), 14, UiStyle.FADED, Vector2(80, 66)))
	gold_label = UiStyle.label("", 18, UiStyle.LAMP, Vector2(1060, 36))
	add_child(gold_label)

	var card := PanelContainer.new()
	info_card = card
	card.position = Vector2(80, 110)
	card.custom_minimum_size = Vector2(520, 440)
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 16))
	add_child(card)
	info = UiStyle.label("", 14, UiStyle.INK)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(480, 0)
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_child(info)

	list = VBoxContainer.new()
	list.position = Vector2(640, 110)
	list.custom_minimum_size = Vector2(560, 0)
	list.add_theme_constant_override("separation", 6)
	add_child(list)

	status = UiStyle.label("", 14, UiStyle.LAMP, Vector2(80, 580))
	status.custom_minimum_size = Vector2(1120, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	add_child(UiStyle.label(
		"Esc  close      W/S  choose      E  do it", 14, UiStyle.FADED, Vector2(80, 660)
	))
	_refresh()


## Override: the screen's name, its one-line intro, the info column, the actions.
func _title() -> String:
	return ""


func _intro() -> String:
	return ""


func _info() -> String:
	return ""


## Each row: {label, note, enabled, action: Callable returning a status line}.
func _rows() -> Array[Dictionary]:
	return []


func _unhandled_input(event: InputEvent) -> void:
	var command := Callable()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		command = _close
	elif event.is_action_pressed("move_up"):
		command = _select.bind(selected - 1)
	elif event.is_action_pressed("move_down"):
		command = _select.bind(selected + 1)
	elif event.is_action_pressed("interact"):
		command = _act
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()


func _select(index: int) -> void:
	if rows.is_empty():
		return
	selected = wrapi(index, 0, rows.size())
	_refresh()


func _act() -> void:
	if rows.is_empty():
		return
	var row := rows[selected]
	status.text = row["action"].call() if row["enabled"] else String(row.get("why", "Not possible right now."))
	_refresh()


func _refresh() -> void:
	gold_label.text = "Gold: %d" % GameState.pack.gold
	info.text = _info()
	info_card.visible = info.text != ""
	rows = _rows()
	selected = clampi(selected, 0, maxi(0, rows.size() - 1))
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for index in rows.size():
		list.add_child(_row(index))


func _row(index: int) -> Control:
	var row: Dictionary = rows[index]
	var chosen := index == selected
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 10
	))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and index == selected:
				_act()
			else:
				_select(index)
	)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var color := UiStyle.INK if row["enabled"] else UiStyle.FADED
	var name := UiStyle.label(row["label"], 16, color)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	line.add_child(UiStyle.label(row.get("note", ""), 16, UiStyle.LAMP if row["enabled"] else UiStyle.FADED))
	return panel


func _close() -> void:
	get_tree().paused = false
	queue_free()
