extends Screen
## areas: title
## Hero creation (CharacterCreation.tsx): seven roles with their pitch, the
## hero as they will start (every role in the same plain clothes, their
## first weapon in hand: PIX-391), their stats against the whole roster,
## the skills they start with, a name, and how the game opens: with the
## first night (the tutorial) or the morning after it. Up/Down pick a role,
## Page Up/Down a skill to read, Tab plays or skips the first night, Enter
## begins, Esc goes back to the title. On a pad (PIX-215) the D-pad or the
## stick picks the role (up/down) and the skill (left/right), Y the first
## night, A begins and B goes back. The mouse clicks any of them.

const ROLES := ["warrior", "mage", "rogue", "cleric", "ranger", "paladin", "necromancer"]
## The stats on the sheet, each with its icon (icons.json's "stats"), its
## name spelled out in its tooltip, and its short name where the icon is
## missing (the CC0 build). The second is the role's pool: mana or energy.
const STATS := ["maxHp", "maxMp", "strength", "intelligence", "dexterity", "defense"]
const STAT_NAMES := {
	"maxHp": "Health", "mana": "Mana", "energy": "Energy", "strength": "Strength",
	"intelligence": "Intelligence", "dexterity": "Dexterity", "defense": "Defense",
}
const STAT_TAGS := {"maxHp": "HP", "strength": "STR", "intelligence": "INT", "dexterity": "DEX", "defense": "DEF"}
## Pips a stat fills against the roster's best.
const PIPS := 10
const PIP := Vector2(12, 10)
## The hero's figure at six times Shade's art, in a slot that holds the
## figure rather than its whole 32 px cell.
const HERO_ZOOM := 6.0
const FIGURE := Vector2(24, 26)
## The stats' and the role's words beside the figure.
const SHEET_WIDTH := 440.0
## The keys the name field would take for itself (PIX-207).
const FIELD_KEYS := [KEY_UP, KEY_DOWN, KEY_TAB, KEY_PAGEUP, KEY_PAGEDOWN]
## The right column, the hero's card above the first night's: as wide as
## the card's columns and its padding, as tall as the roles' page.
const RIGHT := Rect2(522, 82, 694, 520)

var world: Node
## Begin with the Night of Ash, the first night and the tutorial (PIX-197).
var play_night := true
## The first night's two states, Play and Skip (PIX-228): side by side on
## their own card, the one in force marked.
var night_play: PanelContainer
var night_skip: PanelContainer
var role_index := 0
## The starting skill whose words show under the skills (PIX-391).
var skill_index := 0
var name_field: LineEdit
var begin: Button
var roles_box: VBoxContainer
var details: PanelContainer
## The skills' chips, the one read lit.
var skill_chips: Array[PanelContainer] = []
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
	roles_box.position = Vector2(80, 98)
	# The seven down the whole page, now their cards hold no look to pick.
	roles_box.add_theme_constant_override("separation", 6)
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
		add_child(UiStyle.screen_footer("{key:move_up}/{key:move_down}  role    {key:move_left}/{key:move_right}  skill    {key:inventory}  first night    Enter  begin    Esc  close"))
	else:
		add_child(UiStyle.screen_footer("Up/Down  role    PgUp/PgDn  skill    Tab  first night    Enter  begin    Esc  close"))
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
	# What it is, then what skipping it means: a line each, as wide as the
	# column less the card's frame (14 a side: 24 ran the card 4 px past
	# the column, PIX-298).
	lines.add_child(Layout.wrapped(UiStyle.label(
		"A guided first night in the burning village.\nSkip it to start in town by day.", 14, UiStyle.FADED
	), RIGHT.size.x - card.get_theme_stylebox("panel").get_minimum_size().x))
	return card


## One of the first night's states, a card the mouse can pick.
func _night_choice(text: String, value: bool) -> PanelContainer:
	var choice := PanelContainer.new()
	choice.custom_minimum_size = Vector2(96, 0)
	choice.gui_input.connect(func(event: InputEvent) -> void:
		if _clicked(event):
			_set_night(value)
	)
	var word := UiStyle.strong(text, 16, UiStyle.INK)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice.add_child(word)
	return choice


static func _clicked(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT


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


## A role's card: its first skill's icon (no figure: every hero starts in
## the same clothes, PIX-391), its name and its pitch.
func _role_card(index: int) -> Control:
	var role_id: String = ROLES[index]
	var role := Catalog.role(role_id)
	var chosen := index == role_index
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(404, 64)
	panel.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 6
	))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if _clicked(event):
			_pick_role(index)
	)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 12)
	panel.add_child(line)
	line.add_child(_icon(ItemIcons.skill(role["skills"][0]["name"])))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	text.add_child(UiStyle.label(role["name"], 17, UiStyle.LAMP if chosen else UiStyle.INK))
	text.add_child(UiStyle.label(role["pitch"], 13, UiStyle.FADED))
	line.add_child(text)
	return panel


## One of Shade's 16 px icons at twice its size; an empty square of the same
## room without the paid art.
static func _icon(texture: Texture2D) -> TextureRect:
	var art := TextureRect.new()
	art.texture = texture
	art.custom_minimum_size = Vector2(32, 32)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return art


## The hero as they will start (PIX-391): what `GameState.upkeep.hero_art()`
## draws for a new hero of the role, plain clothes and first weapon.
static func starting_look(role_id: String) -> Dictionary:
	return PunyArt.dressed(role_id, {"weapon": GameState.starter_weapon(role_id)})


## The new hero walking toward us, in a slot of their own.
func _portrait(role_id: String) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UiStyle.slot("", UiStyle.box(UiStyle.WINDOW, UiStyle.RIM, 8)))
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var holder := Control.new()
	holder.custom_minimum_size = FIGURE * HERO_ZOOM
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := starting_look(role_id)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.self_modulate = art["tint"]
	sprite.scale = Vector2(HERO_ZOOM, HERO_ZOOM)
	# Shade's figures stand low in their cells: the cell's middle a pixel up.
	sprite.position = (FIGURE / 2.0 - Vector2(0, 1)) * HERO_ZOOM
	sprite.play(PunyArt.pick(sprite.sprite_frames, "walk", "down"))
	holder.add_child(sprite)
	frame.add_child(holder)
	return frame


func _fill_details() -> void:
	var role_id := _role()
	var role := Catalog.role(role_id)
	var card := VBoxContainer.new()
	card.add_theme_constant_override("separation", 8)
	details.add_child(card)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	card.add_child(top)
	var portrait := VBoxContainer.new()
	portrait.add_theme_constant_override("separation", 4)
	top.add_child(portrait)
	portrait.add_child(_portrait(role_id))
	# The name once there is one: no stand-in (PIX-391: a red "..." stood
	# over the role while the field was empty).
	var named := UiStyle.label(name_field.text.strip_edges(), 18, UiStyle.LAMP)
	named.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait.add_child(named)

	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", 7)
	top.add_child(sheet)
	sheet.add_child(UiStyle.strong(role["name"], 18, UiStyle.INK))
	sheet.add_child(Layout.wrapped(UiStyle.label(role["description"], 14, UiStyle.INK), SHEET_WIDTH))
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 18)
	stats.add_theme_constant_override("v_separation", 4)
	for stat: String in STATS:
		stats.add_child(_stat(role_id, stat))
	sheet.add_child(stats)

	# The skills they start with, the one read lit and its words under them.
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_child(spacer)
	var skills: Array = role["skills"]
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	card.add_child(chips)
	skill_chips.clear()
	for index in skills.size():
		var chip := _skill_chip(skills[index], index)
		chips.add_child(chip)
		skill_chips.append(chip)
	var words := Layout.wrapped(UiStyle.label(skills[skill_index]["description"], 14, UiStyle.FADED), SHEET_WIDTH)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_child(words)


## A stat's icon, its pips against the best of the roster and its number;
## its name in the tooltip (PIX-391).
func _stat(role_id: String, stat: String) -> Control:
	var role := Catalog.role(role_id)
	var value := int(role["baseStats"][stat])
	var most := 0
	for other: String in ROLES:
		# A pool against its own kind's best: energy against energy, not the mage's mana.
		if stat != "maxMp" or Catalog.role(other)["resource"] == role["resource"]:
			most = maxi(most, int(Catalog.role(other)["baseStats"][stat]))
	var key := stat
	if stat == "maxMp":
		key = "mana" if role["resource"] == "mana" else "energy"
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 6)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	# Its tooltip is a window that samples as its owner does: crisp (PIX-384).
	cell.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tip := Text.t(STAT_NAMES[key])
	if Skills.BLURBS.has(stat):
		tip += "\n" + Text.t(Skills.BLURBS[stat])
	cell.tooltip_text = tip
	var icon := ItemIcons.stat(key)
	if icon != null:
		cell.add_child(_icon(icon))
	else:
		var tag := UiStyle.strong(Skills.resource_label(role_id) if stat == "maxMp" else Text.t(STAT_TAGS[stat]), 12, UiStyle.FADED)
		tag.custom_minimum_size = Vector2(32, 0)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_child(tag)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 2)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lit := lit_pips(value, most)
	for index in PIPS:
		pips.add_child(_pip(index < lit))
	cell.add_child(pips)
	var number := UiStyle.strong(str(value), 16, UiStyle.INK)
	number.custom_minimum_size = Vector2(26, 0)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	number.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.add_child(number)
	return cell


## How many of a stat's pips light: its share of the roster's best, one at
## least for anything above nothing.
static func lit_pips(value: int, most: int) -> int:
	if value <= 0:
		return 0
	return clampi(roundi(float(PIPS) * value / maxi(1, most)), 1, PIPS)


## A pip in whole art pixels: brass with a lit top in a dark rim when lit,
## a faint inked hollow when not, so the lit ones read at a glance.
static func _pip(lit: bool) -> ColorRect:
	var pip := ColorRect.new()
	pip.custom_minimum_size = PIP
	pip.color = UiStyle.WOOD_DARK if lit else Color(UiStyle.RIM, 0.55)
	pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face := ColorRect.new()
	face.position = Vector2(2, 2)
	face.size = PIP - Vector2(4, 4)
	face.color = UiStyle.BRASS if lit else UiStyle.CARD
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pip.add_child(face)
	if lit:
		var shine := ColorRect.new()
		shine.size = Vector2(face.size.x, 2)
		shine.color = UiStyle.BRASS_LIGHT
		shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(shine)
	return pip


## A starting skill as a chip: its icon (Shade's Puny Skills, as the dock
## shows it) and its name, lit when it's the one read; a click reads it.
func _skill_chip(skill: Dictionary, index: int) -> PanelContainer:
	var chosen := index == skill_index
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 6
	))
	chip.gui_input.connect(func(event: InputEvent) -> void:
		if _clicked(event):
			_pick_skill(index)
	)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 6)
	chip.add_child(line)
	line.add_child(_icon(ItemIcons.skill(skill["name"])))
	# Two lines at most: "Imposition des mains" is the longest.
	var label := Layout.wrapped(UiStyle.label(skill["name"], 14, UiStyle.LAMP if chosen else UiStyle.INK), 150)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	return chip


func _pick_role(index: int) -> void:
	role_index = wrapi(index, 0, ROLES.size())
	skill_index = 0
	_refresh()


func _pick_skill(index: int) -> void:
	skill_index = wrapi(index, 0, skill_chips.size())
	_refresh()


## The first night on or off: on for a first hero, a choice after that.
func _toggle_night() -> void:
	_set_night(not play_night)


func _set_night(on: bool) -> void:
	play_night = on
	_show_night()


## The state in force in rubric red inside a rubric rim, the other faded,
## as the roles and skills mark theirs.
func _show_night() -> void:
	for choice: PanelContainer in [night_play, night_skip]:
		var chosen := (choice == night_play) == play_night
		choice.add_theme_stylebox_override("panel", UiStyle.box(
			UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 6
		))
		(choice.get_child(0) as Label).add_theme_color_override("font_color", UiStyle.LAMP if chosen else UiStyle.FADED)


## The name field would swallow these (PIX-207): role, skill and the first
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
			return _pick_skill.bind(skill_index - 1)
		KEY_PAGEDOWN:
			return _pick_skill.bind(skill_index + 1)
		KEY_TAB:
			return _toggle_night
		KEY_ENTER, KEY_KP_ENTER:
			return _begin
	return Callable()


## The pad (PIX-215): up/down a role, left/right a skill to read, Y the
## first night, A begins; B is left to go back.
func _pad_command(event: InputEvent) -> Callable:
	if event.is_action_pressed("move_up"):
		return _pick_role.bind(role_index - 1)
	if event.is_action_pressed("move_down"):
		return _pick_role.bind(role_index + 1)
	if event.is_action_pressed("move_left"):
		return _pick_skill.bind(skill_index - 1)
	if event.is_action_pressed("move_right"):
		return _pick_skill.bind(skill_index + 1)
	if event.is_action_pressed("inventory"):
		return _toggle_night
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		return _begin
	return Callable()


## The hero takes the slot in hand on a first visit, else the first empty
## one, and the world starts over around them in the village. New Game on
## the title is the one way here (PIX-316), and it never writes over a hero
## or a save the game can't read (PIX-303).
func _begin() -> void:
	var name := name_field.text.strip_edges()
	if name == "":
		status.text = "A hero needs a name."
		return
	var target := GameState.free_slot()
	if target == 0:
		status.text = "Every slot holds a hero. Delete one in Saves first."
		return
	GameState.new_hero_in(target, name, _role(), play_night)
	GameState.title_seen = true
	get_tree().paused = false
	get_tree().reload_current_scene()
