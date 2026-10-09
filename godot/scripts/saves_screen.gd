extends Screen
## The saves screen (Esc): three slots to play, start fresh or clear, and the
## way across from the web game — its save found in this browser, or a pasted
## save code. Keyboard first (letters drive every action, the same key twice
## confirms anything destructive), every action also clickable. Pauses the
## world while open; switching heroes reloads the world scene.

const PORTRAIT := Rect2(8, 6, 16, 20)  # hero body within a 32px Puny idle frame
const WINDOW := Vector2(1080, 0)

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
## What playing the hero already in hand means here: just closing (over the
## world), or the title's Continue (over the title).
var on_play_current: Callable

func _open() -> void:
	layer = 5
	selected = clampi(GameState.slot - 1, 0, SaveSlots.SLOT_COUNT - 1)

	dim()

	# One window in the middle of the screen: the slots on the left, the way
	# across from the web game on the right, what just happened underneath.
	# Placed, not centred by a container: a wrapping line measures itself tall
	# before it knows its width, and a centring container would grow with it.
	var stack := VBoxContainer.new()
	stack.position = Vector2((1280 - WINDOW.x) / 2, 56)
	stack.add_theme_constant_override("separation", 18)
	add_child(stack)
	var title := UiStyle.heading("Saves", 20, UiStyle.CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(WINDOW.x, 0)
	window.add_theme_stylebox_override("panel", UiStyle.window(22))
	stack.add_child(window)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	window.add_child(body)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 32)
	body.add_child(columns)

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(560, 0)
	columns.add_child(left)
	for index in SaveSlots.SLOT_COUNT:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(560, 96)
		card.gui_input.connect(_on_card_input.bind(index))
		left.add_child(card)
		cards.append(card)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.add_child(UiStyle.button("E  Play", _play))
	actions.add_child(UiStyle.button("N  New hero", _new_hero))
	actions.add_child(UiStyle.button("X  Clear slot", _clear))
	left.add_child(actions)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)
	var web := PanelContainer.new()
	web.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP if welcome else UiStyle.RIM, 10))
	right.add_child(web)
	var web_lines := VBoxContainer.new()
	web_lines.add_theme_constant_override("separation", 8)
	web.add_child(web_lines)
	web_lines.add_child(UiStyle.strong(
		"Welcome back" if welcome else "From the old web edition", 16, UiStyle.LAMP if welcome else UiStyle.INK
	))
	if web_save.is_empty():
		var hint := (
			"No hero from the old web edition in this browser. One you saved as a code comes across below."
			if OS.has_feature("web")
			else "A hero from the old web edition comes across by their save code: paste it below."
		)
		var none := UiStyle.label(hint, 14, UiStyle.FADED)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		web_lines.add_child(none)
	else:
		var found := UiStyle.label(
			Text.t("Your web game hero %s, %d gold.") % [WebImport.describe(web_save), web_save["gold"]], 14, UiStyle.INK
		)
		found.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		web_lines.add_child(found)
		bring_button = UiStyle.button("", _bring)
		if welcome:
			# The one thing a first visit is for: make it the brightest control.
			UiStyle.focus(bring_button)
		web_lines.add_child(bring_button)

	var code := PanelContainer.new()
	code.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 10))
	right.add_child(code)
	var code_lines := VBoxContainer.new()
	code_lines.add_theme_constant_override("separation", 8)
	code.add_child(code_lines)
	code_lines.add_child(UiStyle.strong("Save code", 16, UiStyle.INK))
	code_field = LineEdit.new()
	code_field.placeholder_text = "Paste a save code"
	code_field.add_theme_color_override("font_color", UiStyle.INK)
	code_field.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.WINDOW, UiStyle.RIM, 6))
	code_field.add_theme_stylebox_override("focus", UiStyle.box(UiStyle.WINDOW, UiStyle.LAMP, 6))
	code_field.text_submitted.connect(func(_text: String) -> void: _load_code())
	code_lines.add_child(code_field)
	var code_actions := HBoxContainer.new()
	code_actions.add_theme_constant_override("separation", 10)
	load_button = UiStyle.button("", _load_code)
	code_actions.add_child(load_button)
	code_actions.add_child(UiStyle.button("C  Copy mine", _copy))
	code_lines.add_child(code_actions)

	status = UiStyle.label("", 14, UiStyle.LAMP)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(WINDOW.x - 44, 0)
	body.add_child(status)
	add_child(UiStyle.footer("Esc  close      W/S  choose      E  play      N  new hero      X  clear      P  paste      C  copy", Vector2(0, 664), true))

	if welcome:
		status.text = (
			Text.t("Found %s in this browser's web game. Press B to bring them here, or Esc for the title and a new hero.")
			% WebImport.describe(web_save)
		)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if code_field.has_focus():
		if event.is_action_pressed("ui_cancel"):
			code_field.release_focus()
			get_viewport().set_input_as_handled()
		return
	# Screen marks the key handled before it runs: playing or importing
	# reloads the scene and frees this screen.
	super(event)

func _command(event: InputEvent) -> Callable:
	# Turning down the web hero (PIX-200) goes to the title, where a new one
	# is made and kept - not on as a stand-in nobody saves.
	if welcome and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		return _decline
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
	# An empty slot has no one to play: a hero is made for it, from the
	# start (creation, then the Night of Ash).
	if GameState.slots.summary(_target()).is_empty():
		_create_in(_target())
		return
	if _target() == GameState.slot:
		close()
		if on_play_current.is_valid():
			on_play_current.call()
		return
	if GameState.play_slot(_target()):
		_reload()

func _decline() -> void:
	close()
	get_tree().current_scene._open_title()


func _new_hero() -> void:
	var summary := GameState.slots.summary(_target())
	if not summary.is_empty() and not _confirm("new", Text.t("Replace %s with a new hero?") % summary["name"], "N"):
		return
	_create_in(_target())

## Hero creation over this screen, for one slot; Esc there comes back here.
func _create_in(target: int) -> void:
	var creation := preload("res://scripts/create_screen.gd").new()
	creation.world = get_tree().current_scene
	creation.target_slot = target
	add_child(creation)
	creation.layer = layer + 1

func _clear() -> void:
	var summary := GameState.slots.summary(_target())
	if summary.is_empty():
		_say(Text.t("Slot %d is already empty.") % _target())
	elif _target() == GameState.slot:
		# The hero in hand goes too: back to the title with no one loaded.
		if _confirm("clear", Text.t("Clear %s, the hero in hand, for good? You'll go back to the title.") % summary["name"], "X"):
			GameState.clear_slot(_target())
			GameState.title_seen = false
			_reload()
	elif _confirm("clear", Text.t("Clear %s from slot %d for good?") % [summary["name"], _target()], "X"):
		GameState.clear_slot(_target())
		_say(Text.t("Slot %d is empty now.") % _target())
		_refresh()

func _bring() -> void:
	if web_save.is_empty():
		return
	if welcome or _may_replace("bring", "B", web_save, Text.t("from the web game")):
		GameState.import_into(_target(), web_save)
		_reload()

func _load_code() -> void:
	var state := WebImport.parse_any(code_field.text)
	if state.is_empty():
		_say("That is not a save code. In the web game, open Options and use Copy save code, then paste it here.")
		return
	if _may_replace("code", "Enter", state, Text.t("from the code")):
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
	var question := Text.t("Replace %s in slot %d with %s %s? Their progress here would be lost.") % [
		summary["name"], _target(), WebImport.describe(incoming), source,
	]
	return _confirm(action, question, key)

## Destructive actions take the same key twice: the first press asks.
func _confirm(action: String, question: String, key: String) -> bool:
	if pending == action:
		pending = ""
		return true
	pending = action
	status.text = Text.t("%s Press %s again to confirm.") % [question, key]
	return false

func _say(text: String) -> void:
	pending = ""
	status.text = text

func _refresh() -> void:
	for index in cards.size():
		_fill_card(cards[index], index)
	if bring_button != null:
		bring_button.text = Text.t("B  Bring %s to slot %d") % [web_save["hero"]["name"], _target()]
	load_button.text = Text.t("Load into slot %d") % _target()

func _fill_card(card: PanelContainer, index: int) -> void:
	for child in card.get_children():
		card.remove_child(child)
		child.queue_free()
	var summary := GameState.slots.summary(index + 1)
	var chosen := index == selected
	card.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if not summary.is_empty() else Color(UiStyle.CARD, 0.4), UiStyle.LAMP if chosen else UiStyle.RIM, 14
	))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = PORTRAIT.size * 3
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not summary.is_empty():
		var frame := AtlasTexture.new()
		# The slot's own hero as they left, dressed and coloured as the
		# dock and the doll show them (PIX-175), facing down.
		var spec := PunyArt.dressed(summary["roleId"], summary.get("look", 0), summary.get("worn", {}))
		frame.atlas = PunyArt.sheet_texture(spec)
		frame.region = PORTRAIT
		portrait.texture = frame
		portrait.self_modulate = spec["tint"]
	row.add_child(portrait)

	var lines := VBoxContainer.new()
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lines)
	if summary.is_empty():
		lines.add_child(UiStyle.label("Empty slot", 20, UiStyle.FADED))
		lines.add_child(UiStyle.label("N starts a new hero here.", 14, UiStyle.FADED))
	else:
		var role: String = Catalog.role(summary["roleId"]).get("name", "").to_lower()
		lines.add_child(UiStyle.label(summary["name"], 20, UiStyle.INK))
		lines.add_child(UiStyle.label(
			Text.t("Level %d %s in %s") % [summary["level"], role, Catalog.place_name(summary["mapId"])], 14, UiStyle.FADED
		))
		lines.add_child(UiStyle.label(Text.t("%d gold, saved %s") % [summary["gold"], _ago(summary["savedAt"])], 14, UiStyle.FADED))

	var tag := UiStyle.label("Playing" if index + 1 == GameState.slot else Text.t("Slot %d") % (index + 1), 12,
		UiStyle.LAMP if index + 1 == GameState.slot else UiStyle.FADED)
	tag.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(tag)

static func _ago(saved_at: int) -> String:
	var seconds := int(Time.get_unix_time_from_system()) - saved_at
	if saved_at <= 0 or seconds < 60:
		return Text.t("just now")
	if seconds < 3600:
		return Text.t("%d min ago") % (seconds / 60)
	if seconds < 86400:
		var hours := seconds / 3600
		return Text.t("1 hour ago") if hours == 1 else Text.t("%d hours ago") % hours
	var days := seconds / 86400
	return Text.t("yesterday") if days == 1 else Text.t("%d days ago") % days

func _reload() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
