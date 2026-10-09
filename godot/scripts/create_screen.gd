extends Screen
## Hero creation (CharacterCreation.tsx): seven roles with their pitch, the
## chosen one walking in their colours, the stats against the whole roster,
## the skills they start toward, a name, and how the game opens: with the
## first night (the tutorial) or the morning after it. Up/Down pick a role,
## Page Up/Down a look, Tab plays or skips the first night, Enter begins, Esc
## goes back to the title. On a pad (PIX-215) the D-pad or the stick picks
## the role (up/down) and the look (left/right), Y the first night, A
## begins and B goes back. The mouse clicks any of them.

const ROLES := ["warrior", "mage", "rogue", "cleric", "ranger", "paladin", "necromancer"]
const STAT_ROWS := [
	["maxHp", "HP"], ["maxMp", "MP"], ["strength", "STR"], ["intelligence", "INT"],
	["dexterity", "DEX"], ["defense", "DEF"],
]
## The keys the name field would take for itself (PIX-207).
const FIELD_KEYS := [KEY_UP, KEY_DOWN, KEY_TAB, KEY_PAGEUP, KEY_PAGEDOWN]
## The right column, the hero's card above the first night's: as wide as
## the card's columns and its padding, as tall as the roles' page.
const RIGHT := Rect2(522, 82, 694, 520)

var world: Node
## The slot this hero goes into (Saves: an empty slot played, or one to
## replace); 0 for the first free one.
var target_slot := 0
## Begin with the Night of Ash, the first night and the tutorial (PIX-197).
var play_night := true
## The first night's two states, Play and Skip (PIX-228): side by side on
## their own card, the one in force marked.
var night_play: PanelContainer
var night_skip: PanelContainer
var role_index := 0
var look := 0
var name_field: LineEdit
var begin: Button
var roles_box: VBoxContainer
var details: PanelContainer
var status: Label


func _open() -> void:
	layer = 8
	dim(1.0)
	# The roles are written on a page beside the hero's card.
	add_child(UiStyle.page(Rect2(64, 82, 446, 520)))
	add_child(UiStyle.title("Create your hero"))
	# Top right, clear of the title (it once sat under it, PIX-228).
	var motto := UiStyle.label("The mountain is waiting", 14, UiStyle.DUSK, Vector2(RIGHT.end.x - 500, 34))
	motto.custom_minimum_size.x = 500
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(motto)
	roles_box = VBoxContainer.new()
	roles_box.position = Vector2(80, 96)
	roles_box.add_theme_constant_override("separation", 4)
	add_child(roles_box)
	var right := VBoxContainer.new()
	right.position = RIGHT.position
	right.custom_minimum_size = RIGHT.size
	right.add_theme_constant_override("separation", 12)
	add_child(right)
	details = PanelContainer.new()
	details.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 18))
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(details)
	right.add_child(_night_card())

	# The name on the left and the start on the right, the screen's one
	# lit plank (PIX-228): it reads as the way in, not as one more choice.
	var bottom := HBoxContainer.new()
	bottom.position = Vector2(80, 614)
	bottom.custom_minimum_size = Vector2(RIGHT.end.x - 80, 46)
	bottom.add_theme_constant_override("separation", 14)
	add_child(bottom)
	var name_label := UiStyle.label("Name", 16, UiStyle.CREAM)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(name_label)
	name_field = LineEdit.new()
	name_field.max_length = 16
	name_field.placeholder_text = "Dragonsbane..."
	name_field.custom_minimum_size = Vector2(320, 38)
	name_field.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_field.add_theme_font_size_override("font_size", 18)
	name_field.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 8))
	name_field.add_theme_stylebox_override("focus", UiStyle.box(UiStyle.CARD, UiStyle.LAMP, 8))
	name_field.add_theme_color_override("font_color", UiStyle.INK)
	name_field.add_theme_color_override("font_placeholder_color", UiStyle.FADED)
	name_field.add_theme_color_override("caret_color", UiStyle.INK)
	name_field.text_changed.connect(func(_text: String) -> void: _refresh())
	name_field.text_submitted.connect(func(_text: String) -> void: _begin())
	bottom.add_child(name_field)
	# Between the two, wrapping rather than running off (all the slots full
	# is a long line in French).
	status = Layout.wrapped(UiStyle.label("", 14, UiStyle.GOLD), 200)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(status)
	begin = UiStyle.button("Begin the adventure", _begin, "Enter")
	UiStyle.focus(begin)
	# Its own height: stretched, the keycap inside would stretch with it.
	begin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(begin)
	# The pad's buttons once it's in hand (PIX-215): no PgUp or Tab there.
	if Controls.pad:
		add_child(UiStyle.screen_footer("{key:move_up}/{key:move_down}  role    {key:move_left}/{key:move_right}  look    {key:inventory}  first night    Enter  begin    Esc  close"))
	else:
		add_child(UiStyle.screen_footer("Up/Down  role    PgUp/PgDn  look    Tab  first night    Enter  begin    Esc  close"))
	_refresh()
	name_field.grab_focus.call_deferred()


## The first night as a setting (PIX-228), not a button beside Begin: what
## it is, its two states with the one in force marked, the key that flips
## it, and a line on what playing or skipping it means.
func _night_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 12))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	card.add_child(lines)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	lines.add_child(row)
	var label := UiStyle.strong("The first night (tutorial):", 16, UiStyle.INK)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	night_play = _night_choice("Play", true)
	night_skip = _night_choice("Skip", false)
	row.add_child(night_play)
	row.add_child(night_skip)
	_show_night()
	var cap := UiStyle.keys("{key:inventory}" if Controls.pad else "Tab")
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	# What it is, then what skipping it means: a line each.
	lines.add_child(Layout.wrapped(UiStyle.label(
		"A guided first night in the burning village.\nSkip it to start in town by day.", 14, UiStyle.FADED
	), RIGHT.size.x - 24))
	return card


## One of the first night's states, a card the mouse can pick.
func _night_choice(text: String, value: bool) -> PanelContainer:
	var choice := PanelContainer.new()
	choice.custom_minimum_size = Vector2(96, 0)
	choice.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_set_night(value)
	)
	var word := UiStyle.strong(text, 16, UiStyle.INK)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice.add_child(word)
	return choice


func _role() -> String:
	return ROLES[role_index]


func _refresh() -> void:
	Layout.clear(roles_box)
	Layout.clear(details)
	for index in ROLES.size():
		roles_box.add_child(_role_card(index))
	_fill_details()
	# Unnamed, the plank darkens and its words fade (button_keyed).
	begin.disabled = name_field.text.strip_edges() == ""


func _role_card(index: int) -> Control:
	var role_id: String = ROLES[index]
	var role := Catalog.role(role_id)
	var chosen := index == role_index
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(404, 56)
	panel.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 6
	))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_pick_role(index)
	)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	line.add_child(_figure(role_id, 0 if not chosen else look, 1.6, "idle"))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	text.add_child(UiStyle.label(role["name"], 17, UiStyle.LAMP if chosen else UiStyle.INK))
	text.add_child(UiStyle.label(role["pitch"], 13, UiStyle.FADED))
	line.add_child(text)
	return panel


## A hero of the role in a look, as a still control holding a live sprite.
func _figure(role_id: String, look_index: int, zoom: float, anim: String) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(32, 32) * zoom
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := PunyArt.hero(role_id, look_index)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.self_modulate = art["tint"]
	sprite.scale = Vector2(zoom, zoom)
	sprite.position = Vector2(16, 18) * zoom
	sprite.play(PunyArt.pick(sprite.sprite_frames, anim, "down"))
	holder.add_child(sprite)
	return holder


func _fill_details() -> void:
	var role_id := _role()
	var role := Catalog.role(role_id)
	var columns := HBoxContainer.new()
	# 200 + 18 + 440 and the card's padding: the column's 694.
	columns.add_theme_constant_override("separation", 18)
	details.add_child(columns)
	var portrait := VBoxContainer.new()
	portrait.custom_minimum_size = Vector2(190, 0)
	portrait.add_theme_constant_override("separation", 8)
	columns.add_child(portrait)
	var big := _figure(role_id, look, 6.0, "walk")
	big.custom_minimum_size = Vector2(200, 200)
	portrait.add_child(big)
	var swatches := HBoxContainer.new()
	swatches.add_theme_constant_override("separation", 6)
	for index in PunyArt.looks(role_id):
		var swatch := PanelContainer.new()
		swatch.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP if index == look else UiStyle.RIM, 2))
		swatch.add_child(_figure(role_id, index, 1.5, "idle"))
		swatch.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				look = index
				_refresh()
		)
		swatches.add_child(swatch)
	portrait.add_child(swatches)
	var shown := name_field.text.strip_edges() if name_field != null else ""
	portrait.add_child(UiStyle.label(shown if shown != "" else "...", 20, UiStyle.LAMP))
	portrait.add_child(UiStyle.label(role["name"], 15, UiStyle.FADED))

	var sheet := VBoxContainer.new()
	sheet.custom_minimum_size = Vector2(440, 0)
	sheet.add_theme_constant_override("separation", 8)
	columns.add_child(sheet)
	var blurb := UiStyle.label(role["description"], 15, UiStyle.INK)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(440, 0)
	sheet.add_child(blurb)
	for row: Array in STAT_ROWS:
		var value := int(role["baseStats"][row[0]])
		var most := 0
		for other: String in ROLES:
			most = maxi(most, int(Catalog.role(other)["baseStats"][row[0]]))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var label := UiStyle.label(row[1], 14, UiStyle.FADED)
		label.custom_minimum_size = Vector2(44, 0)
		line.add_child(label)
		var track := ColorRect.new()
		track.color = UiStyle.RIM
		track.custom_minimum_size = Vector2(320, 10)
		var fill := ColorRect.new()
		fill.color = UiStyle.LAMP
		fill.size = Vector2(320.0 * value / maxi(1, most), 10)
		track.add_child(fill)
		line.add_child(track)
		line.add_child(UiStyle.label(str(value), 14, UiStyle.INK))
		sheet.add_child(line)
	var skills: Array = role["skills"]
	# All open from the start (PIX-188: the old "(Lv3)" was wrong).
	var names := skills.map(func(skill: Dictionary) -> String: return String(skill["name"]))
	var skill_line := UiStyle.label(Text.t("Skills: %s") % ", ".join(names), 13, UiStyle.INK)
	skill_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_line.custom_minimum_size = Vector2(440, 0)
	sheet.add_child(skill_line)
	if not skills.is_empty():
		var first := UiStyle.label(skills[0]["description"], 13, UiStyle.FADED)
		first.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		first.custom_minimum_size = Vector2(440, 0)
		sheet.add_child(first)


func _pick_role(index: int) -> void:
	role_index = wrapi(index, 0, ROLES.size())
	look = 0
	_refresh()


func _pick_look(step: int) -> void:
	look = wrapi(look + step, 0, PunyArt.looks(_role()))
	_refresh()


## The first night on or off: on for a first hero, a choice after that.
func _toggle_night() -> void:
	_set_night(not play_night)


func _set_night(on: bool) -> void:
	play_night = on
	_show_night()


## The state in force in rubric red inside a rubric rim, the other faded,
## as the roles and looks mark theirs.
func _show_night() -> void:
	for choice: PanelContainer in [night_play, night_skip]:
		var chosen := (choice == night_play) == play_night
		choice.add_theme_stylebox_override("panel", UiStyle.box(
			UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 6
		))
		(choice.get_child(0) as Label).add_theme_color_override("font_color", UiStyle.LAMP if chosen else UiStyle.FADED)


## The name field would swallow these (PIX-207): role, look and the first
## night answer them before it does, and so does the pad.
func _input(event: InputEvent) -> void:
	if not on_top():
		return
	var key := event as InputEventKey
	var field_key := key != null and key.pressed and not key.echo and key.keycode in FIELD_KEYS
	if field_key or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		var command := _command(event)
		if command.is_valid():
			get_viewport().set_input_as_handled()
			command.call()


func _command(event: InputEvent) -> Callable:
	if event is InputEventKey:
		return _key_command(event as InputEventKey)
	return _pad_command(event)


## The keyboard's keys: the letters are the name's, so moves are the arrows
## and pages. Enter reaches here only when the name field has let go of it.
func _key_command(event: InputEventKey) -> Callable:
	if not event.pressed or event.echo:
		return Callable()
	match event.keycode:
		KEY_UP:
			return _pick_role.bind(role_index - 1)
		KEY_DOWN:
			return _pick_role.bind(role_index + 1)
		KEY_PAGEUP:
			return _pick_look.bind(-1)
		KEY_PAGEDOWN:
			return _pick_look.bind(1)
		KEY_TAB:
			return _toggle_night
		KEY_ENTER, KEY_KP_ENTER:
			return _begin
	return Callable()


## The pad (PIX-215): up/down a role, left/right a look, Y the first night,
## A begins; B is left to go back.
func _pad_command(event: InputEvent) -> Callable:
	if event.is_action_pressed("move_up"):
		return _pick_role.bind(role_index - 1)
	if event.is_action_pressed("move_down"):
		return _pick_role.bind(role_index + 1)
	if event.is_action_pressed("move_left"):
		return _pick_look.bind(-1)
	if event.is_action_pressed("move_right"):
		return _pick_look.bind(1)
	if event.is_action_pressed("inventory"):
		return _toggle_night
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		return _begin
	return Callable()


## The hero takes the slot in hand on a first visit, else the first empty
## one, and the world starts over around them in the village.
func _begin() -> void:
	var name := name_field.text.strip_edges()
	if name == "":
		status.text = "A hero needs a name."
		return
	var target := target_slot if target_slot > 0 else GameState.free_slot()
	if target == 0:
		status.text = "Every slot holds a hero. Clear one in Saves first."
		return
	GameState.new_hero_in(target, name, _role(), look, play_night)
	GameState.title_seen = true
	get_tree().paused = false
	get_tree().reload_current_scene()
