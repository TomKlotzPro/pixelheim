extends Control
## The hero's dock along the bottom of the screen (PIX-138): one wooden plate
## in the windows' carved frame, centred, so the rest of the screen is world.
## Experience runs as a thin line along its top; the hero's portrait, name,
## rank, health and energy sit at its left; the skills, by their number keys,
## in the middle; gold and the menu at its right. The menu opens a short list
## of every screen with its key, and flags points waiting to be spent.

const MARGIN := 8  # canvas pixels between the dock and the screen's bottom
const BAR := Vector2(132, 10)
const XP_HEIGHT := 4
const SLOT := 48
const BARS := {
	"hp": [Color("d8433f"), Color("ff8a80")],
	"mp": [Color("4f7cff"), Color("9fc0ff")],
	"en": [Color("5cbf4a"), Color("a6ea8a")],
	"xp": [Color("e8b33a"), Color("ffe08a")],
}
const SCREENS := [
	["inventory", "Pack"], ["map", "Map"], ["stats", "Stats"],
	["skills", "Skills"], ["codex", "Codex"], ["journal", "Journal"],
]

var world: Node
var plate: PanelContainer
var portrait: AnimatedSprite2D
var name_label: Label
var rank_label: Label
var gold_label: Label
var bars := {}
var xp_fill: ColorRect
var xp_track: ColorRect
var slots: Array[Dictionary] = []
var menu_button: Button
var menu: PanelContainer
var menu_rows := {}
var _shown: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	plate = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiStyle.window(8, UiStyle.WOOD))
	plate.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(plate)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(column)
	column.add_child(_xp_line())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(row)
	row.add_child(_hero())
	row.add_child(_skills())
	row.add_child(_purse())
	_build_menu()
	refresh()
	plate.resized.connect(_place)
	_place.call_deferred()


## Centred on the bottom edge; the menu opens above its right end.
func _place() -> void:
	plate.position = Vector2(roundf((1280 - plate.size.x) / 2.0), 720 - MARGIN - plate.size.y)
	menu.position = Vector2(plate.position.x + plate.size.x - menu.size.x, plate.position.y - menu.size.y - 4)


## Where the dock begins, for what floats above it (the battle log, messages).
func top() -> float:
	return plate.position.y


## Experience: a thin gold line across the dock, under the frame's top edge.
func _xp_line() -> Control:
	xp_track = ColorRect.new()
	xp_track.color = UiStyle.NIGHT
	xp_track.custom_minimum_size = Vector2(0, XP_HEIGHT)
	xp_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_fill = ColorRect.new()
	xp_fill.color = BARS["xp"][0]
	xp_fill.size = Vector2(0, XP_HEIGHT)
	xp_track.add_child(xp_fill)
	return xp_track


## The hero: portrait in a paper slot, name and rank, health and energy.
func _hero() -> Control:
	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", 8)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.WINDOW, UiStyle.NIGHT, 2))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	block.add_child(slot)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(40, 40)
	frame.clip_contents = true
	slot.add_child(frame)
	portrait = AnimatedSprite2D.new()
	portrait.position = Vector2(20, 22)
	portrait.scale = Vector2(2, 2)
	frame.add_child(portrait)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 3)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(lines)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 6)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(who)
	name_label = UiStyle.strong("", 12, UiStyle.CREAM)
	name_label.custom_minimum_size = Vector2(128, 0)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(name_label)
	rank_label = UiStyle.label("", 12, UiStyle.DUSK)
	who.add_child(rank_label)
	for key: String in ["hp", "res"]:
		lines.add_child(_bar(key))
	return block


## A pixel bar: dark outline and track, the fill with a lit top edge, and its
## numbers beside it.
func _bar(key: String) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := UiStyle.strong("", 12, UiStyle.DUSK)
	tag.custom_minimum_size = Vector2(18, 0)
	line.add_child(tag)
	var outline := ColorRect.new()
	outline.color = UiStyle.NIGHT
	outline.custom_minimum_size = BAR
	outline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = BAR - Vector2(4, 4)
	outline.add_child(fill)
	var shine := ColorRect.new()
	shine.size = Vector2(fill.size.x, 2)
	fill.add_child(shine)
	line.add_child(outline)
	var value := UiStyle.label("", 12, UiStyle.CREAM)
	value.custom_minimum_size = Vector2(44, 0)
	line.add_child(value)
	bars[key] = {"tag": tag, "fill": fill, "shine": shine, "value": value}
	return line


## Six square slots, one per skill key: the skill's icon (Shade's, ItemIcons),
## lit brass when it can be cast, dim while it can't; a click casts it too.
## Without the paid icons a slot shows the skill's initials.
func _skills() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for index in Controls.SKILL_KEYS.size():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT, SLOT)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				world.player.cast(index)
		)
		var face := Control.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(face)
		var mark := UiStyle.strong("", 16, UiStyle.INK)
		mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		mark.offset_top = 6
		face.add_child(mark)
		var art := TextureRect.new()
		art.custom_minimum_size = Vector2(32, 32)
		art.size = Vector2(32, 32)
		art.position = Vector2(4, 4)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(art)
		# The key in the slot's corner, as action bars number theirs.
		var key := UiStyle.strong(str(index + 1), 12, UiStyle.FADED)
		key.position = Vector2(0, -4)
		face.add_child(key)
		row.add_child(slot)
		slots.append({"slot": slot, "mark": mark, "art": art})
	return row


## Gold, and the menu of screens.
func _purse() -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 4)
	purse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var coin := TextureRect.new()
	coin.texture = UiStyle.coin()
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	purse.add_child(coin)
	gold_label = UiStyle.strong("", 16, UiStyle.GOLD)
	purse.add_child(gold_label)
	block.add_child(purse)
	menu_button = UiStyle.button("Menu", _toggle_menu)
	block.add_child(menu_button)
	return block


## The list of screens over the dock's right end: a key and a name each,
## points waiting in rubric red.
func _build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", UiStyle.window(12))
	menu.visible = false
	add_child(menu)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 4)
	menu.add_child(lines)
	for screen: Array in SCREENS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		line.mouse_filter = Control.MOUSE_FILTER_STOP
		line.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				menu.visible = false
				world.open_screen(screen[0])
		)
		var cap := UiStyle.keycap("", true)
		line.add_child(cap)
		var word := UiStyle.label(screen[1], 16, UiStyle.INK)
		line.add_child(word)
		lines.add_child(line)
		menu_rows[screen[0]] = {"cap": cap, "word": word, "name": screen[1]}
	menu.resized.connect(_place)


func _toggle_menu() -> void:
	menu.visible = not menu.visible
	_place()


func _process(_delta: float) -> void:
	# The skills change state on their own (a cast spent, energy back), so the
	# slots follow every frame, redrawn only when something changed.
	var hero := GameState.hero
	var skills := Skills.hero_skills(hero).slice(0, slots.size())
	var states := skills.map(func(skill: Dictionary) -> bool:
		return Skills.cast_block(hero, skill) == "" and world.player.skill_ready
	)
	var shown := [skills.map(func(skill: Dictionary) -> String: return skill["name"]), states]
	if shown == _shown:
		return
	_shown = shown
	for index in slots.size():
		var slot: PanelContainer = slots[index]["slot"]
		var mark: Label = slots[index]["mark"]
		var has := index < skills.size()
		var ready: bool = has and states[index]
		# Ready to cast: a brass rim; spent, too dear or not yet reached: dim.
		slot.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.WINDOW if has else UiStyle.CARD, UiStyle.BRASS if ready else UiStyle.RIM, 4))
		slot.modulate.a = 1.0 if ready or not has else 0.55
		var icon := ItemIcons.skill(skills[index]["name"]) if has else null
		var art: TextureRect = slots[index]["art"]
		art.texture = icon
		mark.text = _initials(skills[index]["name"]) if has and icon == null else ""
		slot.tooltip_text = _describe(skills[index]) if has else ""


## "Power Strike" -> "PS": what a slot shows until the skills have icons.
static func _initials(name: String) -> String:
	var letters := ""
	for word: String in name.split(" ", false):
		letters += word.left(1)
	return letters.left(2).to_upper()


func _describe(skill: Dictionary) -> String:
	var cost := "%d %s" % [skill["mpCost"], Skills.resource_label(GameState.hero.role_id)]
	if int(skill.get("hpCost", 0)) > 0:
		cost += " +%d HP" % skill["hpCost"]
	return "%s  -  %s" % [skill["name"], cost]


## Everything again from the hero: called on any change GameState reports.
func refresh() -> void:
	var hero := GameState.hero
	var pack := GameState.pack
	var art := GameState.hero_art()
	portrait.sprite_frames = PunyArt.frames(art)
	portrait.self_modulate = art["tint"]
	portrait.play(PunyArt.pick(portrait.sprite_frames, "idle", "down"))
	name_label.text = hero.hero_name
	rank_label.text = "Lv %d %s" % [hero.level, Ranks.title(hero.role_id, hero.level)]
	gold_label.text = str(pack.gold)
	var resource := Skills.resource_label(hero.role_id)
	_set_bar("hp", "HP", hero.hp, int(hero.stats["maxHp"]), BARS["hp"])
	_set_bar("res", resource, hero.mp, int(hero.stats["maxMp"]), BARS["en"] if resource == "EN" else BARS["mp"])
	_set_xp.call_deferred(hero.xp, hero.xp_to_next)
	var keys := GameState.settings.bindings
	var waiting_any := false
	for screen: String in menu_rows:
		var line: Dictionary = menu_rows[screen]
		UiStyle.keycap_text(line["cap"], Controls.key_label(Controls.key_for(screen, keys)))
		var waiting := hero.stat_points if screen == "stats" else (hero.skill_points if screen == "skills" else 0)
		waiting_any = waiting_any or waiting > 0
		line["word"].text = line["name"] + ("  +%d" % waiting if waiting > 0 else "")
		line["word"].add_theme_color_override("font_color", UiStyle.LAMP if waiting > 0 else UiStyle.INK)
	# Points to spend light the menu, so they're never missed.
	UiStyle.focus(menu_button, waiting_any)


func _set_bar(key: String, tag: String, value: int, most: int, colors: Array) -> void:
	var bar: Dictionary = bars[key]
	bar["tag"].text = tag
	bar["fill"].color = colors[0]
	bar["shine"].color = colors[1]
	var inner := BAR.x - 4
	# Whole art pixels: the fill grows two canvas pixels at a time.
	bar["fill"].size.x = floorf(inner * clampf(float(value) / maxi(1, most), 0.0, 1.0) / 2.0) * 2.0
	bar["shine"].size.x = bar["fill"].size.x
	bar["value"].text = "%d/%d" % [value, most]


func _set_xp(xp: int, to_next: int) -> void:
	xp_fill.size.x = floorf(xp_track.size.x * clampf(float(xp) / maxi(1, to_next), 0.0, 1.0) / 2.0) * 2.0


func _unhandled_input(event: InputEvent) -> void:
	# The menu closes on Esc before the pause menu would open.
	if menu.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		get_viewport().set_input_as_handled()
		menu.visible = false
