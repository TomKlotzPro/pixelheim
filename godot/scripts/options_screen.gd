class_name OptionsScreen
extends Screen
## areas: screen
## Options (Options.tsx), in tabs (PIX-546): Sound (music, effects and
## ambience, PIX-411), Display, Access and Controls, the journal's tabs on
## the page's top edge. They open on the tabs: A/D turn them, W/S go down
## into a tab's rows and back up to the tabs past either end. On a row A/D
## move a slider or flip a switch, E flips a switch too and rebinds a key
## (the next key pressed takes it; Esc cancels); on a key's row A/D cross
## to the other column (PIX-484). Everything is saved at once in
## GameSettings. Esc closes. Under the rows a line says what the chosen one
## does, or what the tab holds while the keys are on the tabs (PIX-550).

## The tabs, by the names they show.
const TABS := ["Sound", "Display", "Access", "Controls"]
## The page, as every screen's (PIX-388).
const PAGE := Rect2(80, 72, 1120, 556)
## How many of the keys stand in the Controls' left column.
const KEYS_LEFT := 7
## The room over and under a row's words inside its rim: the box's own, now
## a tab holds seven rows a column at most (PIX-484 had cut it to 3 for
## seventeen rows and four headings down one).
const ROW_PAD := 6
## What each tab holds, said under its rows while the keys are on the tabs
## (PIX-550), in TABS' order.
const TAB_HELP := [
	"All the sound at once, then the music, the effects and the ambience, each on its own slider.",
	"How the picture is drawn: the window, the glow, and how the lights of the night fall.",
	"The language, larger text, calmer motion and light, and the help the game gives along the way.",
	"Every key you can change. The arrows, Enter, Space and Tab always work beside them.",
]
## Every key's line: how one is rebound, said once for them all.
const KEYS_HELP := "Choose a key and press {key:interact}, then its new key; Esc keeps the old. A key another action holds swaps with it."

## The row the next Options open on and its tab, set as a language rebuilds
## the world in it (PIX-428: the reload closed Options and every screen
## under them); the title or the pause menu opens them again there. -1: none.
static var back_at := -1
static var back_tab := 0

var world: World
## The tab shown (TABS' index), and whether the tabs themselves are chosen:
## left and right then turn them, and no row is lit.
var tab := 0
var on_tabs := true
var tabs_row: HBoxContainer
## The shown tab's rows.
var rows: Array[Dictionary] = []
var selected := 0
## The action waiting for its new key, "" when none.
var listening := ""
## A tab's rows mid-page in the left one; the keys fill both.
var columns: Array[VBoxContainer] = []
var status: Label
## The line under the rows (PIX-550): what the chosen row does, or what the
## tab holds; made again with the rows.
var help: Label
## The keys' footer, and the one shown while a key is awaited (PIX-434).
var footer: Control
var waiting_footer: Control


func _open() -> void:
	layer = 7
	dim()
	var title := UiStyle.title("Options")
	add_child(title)
	# On the page's top edge, a gap past the title, as the journal's (PIX-543).
	tabs_row = HBoxContainer.new()
	tabs_row.position = Vector2(maxf(PAGE.position.x + UiStyle.INSET, title.position.x + Layout.words_width(title) + UiStyle.GAP), PAGE.position.y - 36)
	tabs_row.custom_minimum_size.y = 36
	tabs_row.add_theme_constant_override("separation", 4)
	add_child(tabs_row)
	var card := PanelContainer.new()
	# The screens' page, inset and room above the keys (PIX-388).
	card.position = PAGE.position
	card.custom_minimum_size = PAGE.size
	card.add_theme_stylebox_override("panel", UiStyle.window(UiStyle.INSET))
	add_child(card)
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 40)
	# A tab with one column of rows holds it mid-page.
	halves.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(halves)
	for i in 2:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2((PAGE.size.x - 2 * UiStyle.INSET - 40) / 2.0, 0)
		column.add_theme_constant_override("separation", 0)
		halves.add_child(column)
		columns.append(column)
	# In the Controls' right column's free foot (PIX-434: under the card it
	# ran over the frame), two lines tall and read from the bottom.
	status = Layout.wrapped(UiStyle.label("", 14, UiStyle.LAMP, Vector2(660, 556)), 516)
	status.custom_minimum_size.y = 47
	status.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	add_child(status)
	waiting_footer = UiStyle.screen_footer(Text.t("Press the new key") + "      Esc  " + Text.t("keep the old one"))
	add_child(waiting_footer)
	if back_at >= 0:
		tab = back_tab
		selected = back_at
		on_tabs = false
		back_at = -1
	_refresh()


## The keys' footer, written again with the keys as they are now (PIX-480:
## it kept "W S choose" after Move up went to Q, till Options were
## reopened), and only the keys that act on what is chosen (PIX-484): on
## the tabs left and right turn them; a slider moves by left and right
## alone, a switch by those or E, and on a key's row left and right cross
## to the other column and E rebinds.
func _name_keys() -> void:
	var row: Dictionary = rows[selected]
	var acts := "{key:move_left}/{key:move_right} / {key:interact}  change      "
	if on_tabs:
		acts = "{key:move_left}/{key:move_right}  tabs      "
	elif _slides(row):
		acts = "{key:move_left}/{key:move_right}  adjust      "
	elif row.has("rebind") or row.has("act"):
		acts = "{key:move_left}/{key:move_right}  other column      " + ("{key:interact}  rebind      " if row.has("rebind") else "{key:interact}  reset      ")
	footer = UiStyle.refooted(self, footer, "{key:move_up}/{key:move_down}  choose      " + acts + "Esc  close")
	# The page keeps off its keys (Layout.crowded: a seventeenth row had
	# grown it under them).
	footer.set_meta(Layout.CLEAR, true)
	footer.visible = listening == ""


## The keys' line under the rows names them too, so all of it again.
func _hands_changed() -> void:
	_refresh()


## Whether `row` is a slider (a volume), which only left and right move.
func _slides(row: Dictionary) -> bool:
	return row.has("adjust") and (row["adjust"] as Callable).get_method() == &"_volume"


## A switch's row on tab `at`, for the setting named `setting`.
func _switch_row(at: int, label: String, setting: String, says: String) -> Dictionary:
	return {"tab": at, "label": label, "value": "On" if GameState.settings.get(setting) else "Off", "adjust": _flip.bind(setting), "help": says}


## Every tab's rows, each with its `tab` (TABS' index), a control and its
## `help`: what it does and when to turn it off, written from what the
## setting's readers do (PIX-550).
func _build() -> Array[Dictionary]:
	var settings := GameState.settings
	var out: Array[Dictionary] = []
	out.append({"tab": 0, "label": "Sound", "value": "Muted" if settings.muted else "On", "adjust": _flip.bind("muted"), "help": "Everything the game plays, at once. Muted silences it and keeps your three volumes."})
	out.append({"tab": 0, "label": "Music volume", "value": Text.percent(roundi(settings.music_volume * 100)), "adjust": _volume.bind("music"), "help": "The music alone. At its lowest the world is left to its own sounds."})
	out.append({"tab": 0, "label": "Effects volume", "value": Text.percent(roundi(settings.sfx_volume * 100)), "adjust": _volume.bind("sfx"), "help": "Fights, spells, the menus and the short jingles. The slider ticks at the level it sets."})
	out.append({"tab": 0, "label": "Ambience volume", "value": Text.percent(roundi(settings.ambience_volume * 100)), "adjust": _volume.bind("ambience"), "help": "The weather, the birds and the fires. Lower it when a long rain wears on you."})
	out.append(_switch_row(1, "Fullscreen", "fullscreen", "The game takes the whole screen. Off, it stays in a window."))
	out.append(_switch_row(1, "CRT scanlines", "scanlines", "A dark line every third row and darker corners, like an old television. For the look alone."))
	out.append(_switch_row(1, "Glow", "glow", "Flames, lamps and other bright things bloom softly. Off, the picture is crisper."))
	out.append(_switch_row(1, "Shadows", "shadows", "In the dark, lamps, torches and fires cast long shadows, and lightning under the open sky. Off, the ground stays plain to read."))
	# The lamps and the lantern shaping the art (PIX-528).
	out.append(_switch_row(1, "Light relief", "relief", "Lamps and your lantern shape what they light: the side facing the flame catches it. Off, light falls flat."))
	# Every light's rim on what stands (PIX-531, PIX-546).
	out.append(_switch_row(1, "Rim light", "rim", "Lamps, fires, the moon and lightning outline what stands near them at night. Off, nothing is outlined."))
	# Accessibility (PIX-160).
	out.append({"tab": 2, "label": "Language", "value": _language_name(settings.language), "adjust": _language, "help": "The language the game speaks. The world reloads in it at once, right where you stand."})
	out.append(_switch_row(2, "Large reading text", "large_text", "Dialogue, story, hints and the log in bigger type, and messages stay on screen half as long again."))
	out.append(_switch_row(2, "Reduce motion", "reduce_motion", "No screen shake, pops or rushing camera; the wind drops, the water lies still and lightning turns soft."))
	# Lightning as a soft brightening instead (PIX-491).
	out.append(_switch_row(2, "Flashes", "flashes", "Lightning flashes across the whole sky. Off, a strike is one slow, soft brightening."))
	out.append(_switch_row(2, "Clear warnings", "clear_warnings", "Attack marks wear hazard stripes and a dark outline, and bites and shots show their path: read by pattern, not by red."))
	out.append(_switch_row(2, "Hints", "hints", "A tip the first time something new comes up, each said once. Turn them off once you know your way."))
	out.append(_switch_row(2, "Quest markers", "quest_marks", "Marks over people with something to ask or tell, and the arrow to your next step, on the map too. Off, you find your own way."))
	var keys := 0
	for action: String in Controls.BINDABLE:
		var waiting := listening == action
		out.append({
			"tab": 3, "label": Controls.BINDABLE[action][0],
			"value": "Press a key..." if waiting else Controls.key_label(Controls.key_for(action, settings.bindings)),
			"rebind": action, "column": 0 if keys < KEYS_LEFT else 1, "help": KEYS_HELP,
		})
		keys += 1
	out.append({"tab": 3, "label": "Reset keys to defaults", "value": "", "act": _reset_keys, "column": 1, "help": "Every key back to the one the game came with."})
	return out


## The rows of tab `at`.
func rows_of(at: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.assign(_build().filter(func(row: Dictionary) -> bool: return row["tab"] == at))
	return out


func _refresh() -> void:
	rows = rows_of(tab)
	selected = clampi(selected, 0, rows.size() - 1)
	_name_keys()
	footer.visible = listening == ""
	waiting_footer.visible = listening != ""
	Layout.clear(tabs_row)
	for at in TABS.size():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.tab(at == tab))
		chip.set_meta("chosen", at == tab)  # what play.py's `focus` reads (PlayBridge.chosen)
		chip.add_child(UiStyle.label(TABS[at], 16, UiStyle.plank_ink(at == tab)))
		chip.gui_input.connect(_on_tab_click.bind(at))
		if at == tab and on_tabs:
			# The keys stand on the tabs: the chosen one framed as a chosen row
			# is (PIX-546 review: nothing on screen said where they stood).
			chip.set_meta("lit", true)
			chip.draw.connect(func() -> void: chip.draw_style_box(UiStyle.box(Color(0, 0, 0, 0), UiStyle.LAMP, 0), Rect2(Vector2.ZERO, chip.size)))
		tabs_row.add_child(chip)
	# The keys alone fill both columns, and only they have a line to say.
	columns[1].visible = tab == TABS.find("Controls")
	status.visible = columns[1].visible
	for column in columns:
		for child in column.get_children():
			column.remove_child(child)
			child.queue_free()
	var edge := MarginContainer.new()
	for index in rows.size():
		var row: Dictionary = rows[index]
		var list: VBoxContainer = columns[row.get("column", 0)]
		var chosen := index == selected and not on_tabs
		var line := PanelContainer.new()
		var rim := UiStyle.box(Color(UiStyle.CARD, 0.9) if chosen else Color(0, 0, 0, 0), UiStyle.LAMP if chosen else Color(0, 0, 0, 0), 4)
		rim.content_margin_top = ROW_PAD
		rim.content_margin_bottom = ROW_PAD
		# The value stood 2 px off the lit rim on the right, the label 3 on
		# the left (PIX-535); on every row, so no value steps as it's chosen.
		rim.content_margin_right += 2
		line.add_theme_stylebox_override("panel", rim)
		edge.add_theme_constant_override("margin_left", roundi(rim.content_margin_left))
		edge.add_theme_constant_override("margin_right", roundi(rim.content_margin_right))
		var inner := HBoxContainer.new()
		line.add_child(inner)
		var label := UiStyle.label(row["label"], 15, UiStyle.INK)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inner.add_child(label)
		inner.add_child(UiStyle.label(row["value"], 15, UiStyle.LAMP if chosen else UiStyle.FADED))
		line.gui_input.connect(_on_row_click.bind(index))
		list.add_child(line)
	# Under the rows, in the reading type (Large reading text grows it as it
	# is switched on), flush with the rows' words inside their rims; the keys'
	# line names them as they are bound now.
	var gap := Control.new()
	gap.custom_minimum_size.y = UiStyle.GAP
	columns[0].add_child(gap)
	help = Layout.wrapped(UiStyle.label(Controls.say(Text.t(TAB_HELP[tab] if on_tabs else String(rows[selected]["help"]))), UiStyle.reading(UiStyle.TEXT), UiStyle.INK), columns[0].custom_minimum_size.x - edge.get_theme_constant("margin_left") - edge.get_theme_constant("margin_right"))
	edge.add_child(help)
	columns[0].add_child(edge)


## "" follows the system's language: shown as what that is.
func _language_name(code: String) -> String:
	if Text.LANGUAGES.has(code):
		return Text.LANGUAGES[code]
	return tr("System (%s)") % Text.LANGUAGES[Text.language_for("")]


## The next language (or the system's), spoken at once: the town reloads in
## it, Options open again on this row over what they were over.
func _language(step: int) -> void:
	var choices: Array = [""] + Text.LANGUAGES.keys()
	var settings := GameState.settings
	settings.language = choices[wrapi(choices.find(settings.language) + step, 0, choices.size())]
	settings.save_file()
	Text.apply(settings.language)
	GameState.save_now()
	back_at = selected
	back_tab = tab
	reload_world()


func _on_row_click(event: InputEvent, index: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		selected = index
		on_tabs = false
		_act(1)


## A click on a tab opens it.
func _on_tab_click(event: InputEvent, at: int) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		turn(at - tab)


func _input(event: InputEvent) -> void:
	# While a rebind is armed the next key is the binding, before anything
	# else can take it (Escape cancels).
	var pressed := event as InputEventKey
	if listening == "" or pressed == null or not pressed.pressed or pressed.echo:
		return
	get_viewport().set_input_as_handled()
	var key: int = pressed.physical_keycode if pressed.physical_keycode != 0 else pressed.keycode
	# A key with a fixed job keeps it (PIX-201): one key, one thing.
	var taken := Controls.fixed_use(key, listening)
	if key != KEY_ESCAPE and taken != "":
		status.text = Text.t("%s already does %s. Choose another key.") % [Controls.key_label(key), taken]
	elif key != KEY_ESCAPE:
		var settings := GameState.settings
		var named := Text.t(Controls.BINDABLE[listening][0])
		var swapped := Controls.taken_from(settings.bindings, listening, key)
		var old_key := Controls.key_for(listening, settings.bindings)
		settings.bindings = Controls.rebind(settings.bindings, listening, key)
		settings.save_file()
		Controls.apply(settings.bindings)
		status.text = Text.t("%s is now %s.") % [named, Controls.key_label(key)]
		if swapped != "":
			status.text = Text.t("%s is now %s, and %s takes %s.") % [named, Controls.key_label(key), Text.t(Controls.BINDABLE[swapped][0]), Controls.key_label(old_key)]
	listening = ""
	_refresh()


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = _move.bind(-1)
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = _move.bind(1)
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		var by := -1 if event.is_action_pressed("move_left") else 1
		# A key's row has nothing to adjust (PIX-484: left and right armed a
		# rebind, as E does): they cross to the other column.
		command = turn.bind(by) if on_tabs else (_cross if rows[selected].has("column") else _act.bind(by))
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		# On the tabs E goes down into the rows, as down does.
		command = _move.bind(1) if on_tabs else _press
	return command


## The tab `by` on from the one shown, the tabs chosen.
func turn(by: int) -> void:
	tab = wrapi(tab + by, 0, TABS.size())
	on_tabs = true
	selected = 0
	status.text = ""
	_refresh()


## E on the chosen row: a switch flips, a key waits for its new one. On a
## slider it does nothing (PIX-484: it raised the volume a tenth, which
## left and right are for).
func _press() -> void:
	if not _slides(rows[selected]):
		_act(1)


## From a key's row to the row level with it in the other column.
func _cross() -> void:
	selected = mini(selected + KEYS_LEFT, rows.size() - 1) if selected < KEYS_LEFT else selected - KEYS_LEFT
	_refresh()


## Down from the tabs to the first row (up, to the last), along the rows,
## and past either end back up to the tabs.
func _move(step: int) -> void:
	if on_tabs:
		on_tabs = false
		selected = 0 if step > 0 else rows.size() - 1
	elif selected + step < 0 or selected + step >= rows.size():
		on_tabs = true
	else:
		selected += step
	_refresh()


func _act(direction: int) -> void:
	var row: Dictionary = rows[selected]
	if row.has("adjust"):
		row["adjust"].call(direction)
	elif row.has("rebind"):
		listening = row["rebind"]
		status.text = ""
	elif row.has("act"):
		row["act"].call()
	_refresh()


## A slider ("music", "sfx" or "ambience") a tenth up or down.
func _volume(direction: int, bus: String) -> void:
	var settings := GameState.settings
	var key := bus + "_volume"
	settings.set(key, clampf(snappedf(float(settings.get(key)) + direction * 0.1, 0.1), 0.0, 1.0))
	settings.save_file()
	Sound.apply_volumes()
	if bus == "sfx":
		Sound.play("ui_volume")


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
	_name_keys()
	status.text = "Keys are back to the defaults."
