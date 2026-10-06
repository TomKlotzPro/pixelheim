extends CanvasLayer
## The saves screen (Esc): three slots to play, start fresh or clear, and the
## way across from the web game — its save found in this browser, or a pasted
## save code. Keyboard first (letters drive every action, the same key twice
## confirms anything destructive), every action also clickable. Pauses the
## world while open; switching heroes reloads the world scene.

## The map screen's night backdrop and its waypoint gold, so the two menus
## read as one family until the UI suite (PIX-127) themes everything.
const BACKDROP := Color(0.043, 0.047, 0.063, 0.97)
const LAMP := Color(1, 0.85, 0.3)
const CARD := Color(0.12, 0.1, 0.085)
const RIM := Color(0.32, 0.26, 0.2)
const INK := Color(0.95, 0.91, 0.83)
const FADED := Color(0.95, 0.91, 0.83, 0.55)
const PORTRAIT := Rect2(20, 16, 24, 34)  # hero body within the 64px idle frame

## A save found in this browser's web game (or passed in by the harness).
var web_save := {}
## Opened by the first-visit offer: bringing the web hero needs no confirm,
## the slot only holds the throwaway hero boot just created.
var welcome := false
var selected := 0
var cards: Array[PanelContainer] = []
var status: Label
var code_field: LineEdit
var bring_button: Button
var load_button: Button
var pending := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	get_tree().paused = true
	selected = clampi(GameState.slot - 1, 0, SaveSlots.SLOT_COUNT - 1)

	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	add_child(_label("Saves", 24, INK, Vector2(80, 32)))
	for index in SaveSlots.SLOT_COUNT:
		var card := PanelContainer.new()
		card.position = Vector2(80, 88 + index * 112)
		card.custom_minimum_size = Vector2(600, 100)
		card.gui_input.connect(_on_card_input.bind(index))
		add_child(card)
		cards.append(card)

	var actions := HBoxContainer.new()
	actions.position = Vector2(80, 432)
	actions.add_theme_constant_override("separation", 12)
	actions.add_child(_button("E  Play", _play))
	actions.add_child(_button("N  New hero", _new_hero))
	actions.add_child(_button("X  Clear slot", _clear))
	add_child(actions)

	add_child(_label("From the web game", 18, INK, Vector2(760, 88)))
	if web_save.is_empty():
		var hint := (
			"No web game save in this browser." if OS.has_feature("web")
			else "Copy your save code from Options in the web game, then paste it below."
		)
		var none := _label(hint, 14, FADED, Vector2(760, 122))
		none.custom_minimum_size = Vector2(440, 0)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add_child(none)
	else:
		var found := _label(
			"%s, %d gold" % [WebImport.describe(web_save), web_save["gold"]], 14, INK, Vector2(760, 122)
		)
		add_child(found)
		bring_button = _button("", _bring)
		bring_button.position = Vector2(760, 150)
		if welcome:
			# The one thing a first visit is for: make it the brightest control.
			bring_button.add_theme_stylebox_override("normal", _box(CARD, LAMP))
			bring_button.add_theme_color_override("font_color", LAMP)
		add_child(bring_button)

	add_child(_label("Save code", 18, INK, Vector2(760, 240)))
	code_field = LineEdit.new()
	code_field.placeholder_text = "Paste a save code"
	code_field.position = Vector2(760, 274)
	code_field.custom_minimum_size = Vector2(440, 0)
	code_field.add_theme_color_override("font_color", INK)
	code_field.add_theme_stylebox_override("normal", _box(CARD, RIM))
	code_field.add_theme_stylebox_override("focus", _box(CARD, LAMP))
	code_field.text_submitted.connect(func(_text: String) -> void: _load_code())
	add_child(code_field)
	load_button = _button("", _load_code)
	load_button.position = Vector2(760, 318)
	add_child(load_button)
	var copy := _button("C  Copy this hero's code", _copy)
	copy.position = Vector2(760, 372)
	add_child(copy)

	status = _label("", 14, LAMP, Vector2(80, 496))
	status.custom_minimum_size = Vector2(1120, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var keys := _label(
		"Esc  close      W/S  choose      E  play      N  new hero      X  clear      P  paste      C  copy",
		14, FADED, Vector2(80, 660)
	)
	add_child(keys)

	if welcome:
		status.text = (
			"Found %s, in this browser's web game. Press B to bring them here, or Esc to start a new hero."
			% WebImport.describe(web_save)
		)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if code_field.has_focus():
		if event.is_action_pressed("ui_cancel"):
			code_field.release_focus()
			get_viewport().set_input_as_handled()
		return
	var command := _command_for(event)
	if not command.is_valid():
		return
	# Handled first: playing or importing reloads the scene and frees this screen.
	get_viewport().set_input_as_handled()
	command.call()

func _command_for(event: InputEvent) -> Callable:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		return _close
	if event.is_action_pressed("move_up"):
		return _select.bind(selected - 1)
	if event.is_action_pressed("move_down"):
		return _select.bind(selected + 1)
	if event.is_action_pressed("interact"):
		return _play
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_N:
				return _new_hero
			KEY_X:
				return _clear
			KEY_B:
				return _bring
			KEY_C:
				return _copy
			KEY_P:
				return code_field.grab_focus
	return Callable()

func _select(index: int) -> void:
	selected = wrapi(index, 0, SaveSlots.SLOT_COUNT)
	pending = ""
	status.text = ""
	_refresh()

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click and index == selected:
			_play()
		else:
			_select(index)

## Slot number shown to players: 1-based.
func _target() -> int:
	return selected + 1

func _play() -> void:
	if _target() == GameState.slot:
		_close()
		return
	GameState.play_slot(_target())
	_reload()

func _new_hero() -> void:
	var summary := GameState.slots.summary(_target())
	if not summary.is_empty() and not _confirm("new", "Replace %s with a new hero?" % summary["name"], "N"):
		return
	GameState.new_hero_in(_target())
	_reload()

func _clear() -> void:
	var summary := GameState.slots.summary(_target())
	if summary.is_empty():
		_say("Slot %d is already empty." % _target())
	elif _target() == GameState.slot:
		_say("You are playing this slot. Switch to another hero before clearing it.")
	elif _confirm("clear", "Clear %s from slot %d for good?" % [summary["name"], _target()], "X"):
		GameState.clear_slot(_target())
		_say("Slot %d is empty now." % _target())
		_refresh()

func _bring() -> void:
	if web_save.is_empty():
		return
	if welcome or _may_replace("bring", "B", web_save, "from the web game"):
		GameState.import_into(_target(), web_save)
		_reload()

func _load_code() -> void:
	var state := WebImport.parse_any(code_field.text)
	if state.is_empty():
		_say("That is not a save code. In the web game, open Options and use Copy save code, then paste it here.")
		return
	if _may_replace("code", "Enter", state, "from the code"):
		GameState.import_into(_target(), state)
		_reload()

func _copy() -> void:
	DisplayServer.clipboard_set(GameState.save_code())
	_say("Save code copied. Paste it into Import save code in the web game's Options.")

## Importing over an occupied slot asks first, naming both heroes and where
## each comes from (re-importing the same hero would undo progress made here).
func _may_replace(action: String, key: String, incoming: Dictionary, source: String) -> bool:
	var summary := GameState.slots.summary(_target())
	if summary.is_empty():
		return true
	var question := "Replace %s in slot %d with %s %s? Their progress here would be lost." % [
		summary["name"], _target(), WebImport.describe(incoming), source,
	]
	return _confirm(action, question, key)

## Destructive actions take the same key twice: the first press asks.
func _confirm(action: String, question: String, key: String) -> bool:
	if pending == action:
		pending = ""
		return true
	pending = action
	status.text = "%s Press %s again to confirm." % [question, key]
	return false

func _say(text: String) -> void:
	pending = ""
	status.text = text

func _refresh() -> void:
	for index in cards.size():
		_fill_card(cards[index], index)
	if bring_button != null:
		bring_button.text = "B  Bring %s to slot %d" % [web_save["hero"]["name"], _target()]
	load_button.text = "Load into slot %d" % _target()

func _fill_card(card: PanelContainer, index: int) -> void:
	for child in card.get_children():
		card.remove_child(child)
		child.queue_free()
	var summary := GameState.slots.summary(index + 1)
	var chosen := index == selected
	card.add_theme_stylebox_override("panel", _box(
		CARD if not summary.is_empty() else Color(CARD, 0.4), LAMP if chosen else RIM, 14
	))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT.size * 2
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not summary.is_empty():
		var frame := AtlasTexture.new()
		frame.atlas = load("res://assets/crawler/hero_idle_down.png")
		frame.region = PORTRAIT
		portrait.texture = frame
	row.add_child(portrait)

	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	if summary.is_empty():
		lines.add_child(_label("Empty slot", 20, FADED))
		lines.add_child(_label("N starts a new hero here.", 14, FADED))
	else:
		var role: String = Catalog.role(summary["roleId"]).get("name", "").to_lower()
		lines.add_child(_label(summary["name"], 20, INK))
		lines.add_child(_label(
			"Level %d %s in %s" % [summary["level"], role, Catalog.place_name(summary["mapId"])], 14, FADED
		))
		lines.add_child(_label("%d gold, saved %s" % [summary["gold"], _ago(summary["savedAt"])], 14, FADED))

	var tag := _label("Playing" if index + 1 == GameState.slot else "Slot %d" % (index + 1), 14,
		LAMP if index + 1 == GameState.slot else FADED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tag)

static func _ago(saved_at: int) -> String:
	var seconds := int(Time.get_unix_time_from_system()) - saved_at
	if saved_at <= 0 or seconds < 60:
		return "just now"
	if seconds < 3600:
		return "%d min ago" % (seconds / 60)
	if seconds < 86400:
		var hours := seconds / 3600
		return "1 hour ago" if hours == 1 else "%d hours ago" % hours
	var days := seconds / 86400
	return "yesterday" if days == 1 else "%d days ago" % days

func _label(text: String, font_size: int, color: Color, at := Vector2.ZERO) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

## Square-cornered pixel panels: a flat fill and a 2px rim.
func _box(fill: Color, rim: Color, padding := 8) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = rim
	box.set_border_width_all(2)
	box.set_content_margin_all(padding)
	return box

## Clickable twins of the key commands; keyboard focus stays with the screen.
func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", LAMP)
	button.add_theme_stylebox_override("normal", _box(Color(0, 0, 0, 0), RIM))
	button.add_theme_stylebox_override("hover", _box(Color(0, 0, 0, 0), LAMP))
	button.add_theme_stylebox_override("pressed", _box(CARD, LAMP))
	button.pressed.connect(action)
	return button

func _reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _close() -> void:
	get_tree().paused = false
	queue_free()
