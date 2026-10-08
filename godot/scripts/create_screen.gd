extends Screen
## Hero creation (CharacterCreation.tsx): seven roles with their pitch, the
## chosen one walking in their colours, the stats against the whole roster,
## the skills they start toward, and a name. Up/Down pick a role, Page
## Up/Down a look, Enter begins the climb, Esc goes back to the title.

const ROLES := ["warrior", "mage", "rogue", "cleric", "ranger", "paladin", "necromancer"]
const STAT_ROWS := [
	["maxHp", "HP"], ["maxMp", "MP"], ["strength", "STR"], ["intelligence", "INT"],
	["dexterity", "DEX"], ["defense", "DEF"],
]

var world: Node
var role_index := 0
var look := 0
var name_field: LineEdit
var begin: Button
var roles_box: VBoxContainer
var details: Control
var status: Label


func _open() -> void:
	layer = 8
	dim(1.0)
	# The roles are written on a page beside the hero's card.
	add_child(UiStyle.page(Rect2(64, 82, 374, 520)))
	add_child(UiStyle.label("The mountain is waiting", 14, UiStyle.DUSK, Vector2(80, 24)))
	add_child(UiStyle.heading("Create your hero", 20, UiStyle.CREAM, Vector2(80, 42)))
	roles_box = VBoxContainer.new()
	roles_box.position = Vector2(80, 96)
	roles_box.add_theme_constant_override("separation", 4)
	add_child(roles_box)
	details = Control.new()
	details.position = Vector2(445, 96)
	details.size = Vector2(760, 500)
	add_child(details)

	var footer := HBoxContainer.new()
	footer.position = Vector2(80, 620)
	footer.add_theme_constant_override("separation", 14)
	add_child(footer)
	footer.add_child(UiStyle.label("Name", 16, UiStyle.CREAM))
	name_field = LineEdit.new()
	name_field.max_length = 16
	name_field.placeholder_text = "Dragonsbane..."
	name_field.custom_minimum_size = Vector2(320, 38)
	name_field.add_theme_font_size_override("font_size", 18)
	name_field.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 8))
	name_field.add_theme_stylebox_override("focus", UiStyle.box(UiStyle.CARD, UiStyle.LAMP, 8))
	name_field.add_theme_color_override("font_color", UiStyle.INK)
	name_field.add_theme_color_override("font_placeholder_color", UiStyle.FADED)
	name_field.add_theme_color_override("caret_color", UiStyle.INK)
	name_field.text_changed.connect(func(_text: String) -> void: _refresh())
	name_field.text_submitted.connect(func(_text: String) -> void: _begin())
	footer.add_child(name_field)
	begin = UiStyle.button("Begin the climb", _begin)
	begin.custom_minimum_size = Vector2(220, 38)
	begin.add_theme_font_size_override("font_size", 18)
	footer.add_child(begin)
	status = UiStyle.label("", 14, UiStyle.GOLD, Vector2(80, 664))
	add_child(status)
	add_child(UiStyle.footer("Up/Down  role    PgUp/PgDn  look    Enter  begin    Esc  back", Vector2(700, 690)))
	_refresh()
	name_field.grab_focus.call_deferred()


func _role() -> String:
	return ROLES[role_index]


func _refresh() -> void:
	for child in roles_box.get_children() + details.get_children():
		child.queue_free()
	for index in ROLES.size():
		roles_box.add_child(_role_card(index))
	_fill_details()
	var named := name_field.text.strip_edges() != ""
	begin.disabled = not named
	begin.modulate.a = 1.0 if named else 0.5


func _role_card(index: int) -> Control:
	var role_id: String = ROLES[index]
	var role := Catalog.role(role_id)
	var chosen := index == role_index
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(345, 56)
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
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(755, 500)
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 18))
	details.add_child(card)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 28)
	card.add_child(columns)
	var portrait := VBoxContainer.new()
	portrait.custom_minimum_size = Vector2(220, 0)
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
	sheet.custom_minimum_size = Vector2(470, 0)
	sheet.add_theme_constant_override("separation", 8)
	columns.add_child(sheet)
	var blurb := UiStyle.label(role["description"], 15, UiStyle.INK)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(460, 0)
	sheet.add_child(blurb)
	for row: Array in STAT_ROWS:
		var value := int(role["baseStats"][row[0]])
		var most := 0
		for other: String in ROLES:
			most = maxi(most, int(Catalog.role(other)["baseStats"][row[0]]))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var label := UiStyle.label(row[1], 14, UiStyle.FADED)
		label.custom_minimum_size = Vector2(40, 0)
		line.add_child(label)
		var track := ColorRect.new()
		track.color = UiStyle.RIM
		track.custom_minimum_size = Vector2(340, 10)
		var fill := ColorRect.new()
		fill.color = UiStyle.LAMP
		fill.size = Vector2(340.0 * value / maxi(1, most), 10)
		track.add_child(fill)
		line.add_child(track)
		line.add_child(UiStyle.label(str(value), 14, UiStyle.INK))
		sheet.add_child(line)
	var skills: Array = role["skills"]
	var names := skills.map(func(skill: Dictionary) -> String: return "%s (Lv%d)" % [skill["name"], skill["unlockLevel"]])
	var skill_line := UiStyle.label("Skills: %s" % ", ".join(names), 13, UiStyle.INK)
	skill_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_line.custom_minimum_size = Vector2(460, 0)
	sheet.add_child(skill_line)
	if not skills.is_empty():
		sheet.add_child(UiStyle.label(skills[0]["description"], 13, UiStyle.FADED))


func _pick_role(index: int) -> void:
	role_index = wrapi(index, 0, ROLES.size())
	look = 0
	_refresh()


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP:
				command = _pick_role.bind(role_index - 1)
			KEY_DOWN:
				command = _pick_role.bind(role_index + 1)
			KEY_PAGEUP, KEY_PAGEDOWN:
				var step := -1 if event.keycode == KEY_PAGEUP else 1
				command = func() -> void:
					look = wrapi(look + step, 0, PunyArt.looks(_role()))
					_refresh()
	return command


## The hero takes the slot in hand on a first visit, else the first empty
## one, and the world starts over around them in the village.
func _begin() -> void:
	var name := name_field.text.strip_edges()
	if name == "":
		status.text = "A hero needs a name."
		return
	var target := GameState.free_slot()
	if target == 0:
		status.text = "Every slot holds a hero. Clear one in Saves first."
		return
	GameState.new_hero_in(target, name, _role(), look)
	GameState.title_seen = true
	get_tree().paused = false
	get_tree().reload_current_scene()
