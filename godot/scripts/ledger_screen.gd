extends Screen
## Shared frame for the town's ledgers (town hall, bank): a title, a column of
## info text, and a list of actions to choose with W/S and take with E — every
## row clickable too. Subclasses fill `_title`, `_intro` and `_rows`. Pauses
## the world while open.

## The list's window on the page: what runs past its foot scrolls (PIX-298:
## the workbench's every recipe stood 2250 px tall, off the canvas), and a
## row is never wider than it, its name giving way to an ellipsis.
const LIST := Rect2(640, 110, 560, 438)
## The most of a row its note takes before it wraps, so the name keeps room.
const NOTE_SHARE := 0.45

var rows: Array[Dictionary] = []
var selected := 0
var list: VBoxContainer
var scroll: ScrollContainer
var info: Label
var info_card: PanelContainer
var purse: HBoxContainer
var status: Label
var page: Panel


func _open() -> void:
	layer = 5
	dim()
	# The choices are written on a page beside the card.
	page = UiStyle.page(Rect2(624, 94, 592, 470))
	add_child(page)
	add_child(UiStyle.title(_title()))
	add_child(UiStyle.label(_intro(), 14, UiStyle.DUSK, Vector2(80, 66)))
	purse = UiStyle.purse(0, 18)
	purse.position = Vector2(1060, 20)
	add_child(purse)

	var card := PanelContainer.new()
	info_card = card
	card.position = Vector2(80, 110)
	card.custom_minimum_size = Vector2(520, 440)
	card.add_theme_stylebox_override("panel", UiStyle.window(18))
	add_child(card)
	# Large text reaches the page's words too (PIX-214).
	info = UiStyle.label("", UiStyle.reading(14), UiStyle.INK)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(480, 0)
	info.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	card.add_child(info)

	scroll = ScrollContainer.new()
	scroll.position = LIST.position
	scroll.custom_minimum_size = LIST.size
	scroll.size = LIST.size
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	status = UiStyle.label("", 14, UiStyle.GOLD, Vector2(80, 604))
	status.custom_minimum_size = Vector2(1120, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	add_child(UiStyle.screen_footer(_footer()))
	_refresh()


## Override: the screen's name, its one-line intro, the info column, the actions.
func _title() -> String:
	return ""


func _intro() -> String:
	return ""


func _info() -> String:
	return ""


## What E does, for the footer.
func _verb() -> String:
	return Text.t("do it")


## The keys along the bottom.
func _footer() -> String:
	return Text.t("{key:move_up}/{key:move_down}  choose      {key:interact}  %s      Esc  close") % _verb()


## Each row: {label, note, enabled, action: Callable returning a status line}.
func _rows() -> Array[Dictionary]:
	return []


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_up"):
		command = _select.bind(selected - 1)
	elif event.is_action_pressed("move_down"):
		command = _select.bind(selected + 1)
	elif event.is_action_pressed("interact"):
		command = _act
	return command


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
	if not row["enabled"]:
		Sound.play_ui("deny")
	_refresh()


func _refresh() -> void:
	UiStyle.purse_set(purse, GameState.pack.gold)
	# The rows first: the info may speak of the chosen one.
	rows = _rows()
	selected = clampi(selected, 0, maxi(0, rows.size() - 1))
	info.text = _info()
	info_card.visible = info.text != ""
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for index in rows.size():
		list.add_child(_row(index))
	# The chosen row in the window, by the rows' heights (a wrapped note
	# makes one taller).
	if not rows.is_empty():
		var top := 0
		for index in selected:
			top += int(list.get_child(index).get_combined_minimum_size().y) + list.get_theme_constant("separation")
		var tall := int(list.get_child(selected).get_combined_minimum_size().y)
		scroll.scroll_vertical = clampi(scroll.scroll_vertical, top + tall - int(LIST.size.y), top)


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
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var color := UiStyle.INK if row["enabled"] else UiStyle.FADED
	var name := UiStyle.label(row["label"], 16, color)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(Layout.ellipsis(name))
	var note := Layout.narrowed(UiStyle.label(row.get("note", ""), 16, UiStyle.LAMP if row["enabled"] else UiStyle.FADED), NOTE_SHARE * LIST.size.x)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	line.add_child(note)
	return panel
