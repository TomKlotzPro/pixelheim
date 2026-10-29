extends Control
## areas: screen
## The hero's dock along the bottom of the screen (PIX-138): one wooden plate
## in the windows' carved frame, centred, so the rest of the screen is world.
## Experience runs as a framed strip along its top; the hero's portrait in a
## slot, name, rank, health and energy in framed bars sit at its left; the
## skills, each on its number key, in the middle; gold and the menu at its
## right (PIX-388). The menu opens a panel of every screen, an icon, a name
## and a key each, and flags points waiting to be spent.

const MARGIN := 8  # canvas pixels between the dock and the screen's bottom
## A bar's frame, the kit's or the one drawn here; its strip fills the
## frame's content rect.
const BAR := Vector2(144, 20)
const XP_HEIGHT := 10
const SLOT := 48
## A skill's key tab: a digit on dark, an art pixel of it above and below,
## standing TAG_RISE above the slot's outer edge.
const TAG := Vector2(20, 18)
const TAG_RISE := 10
const PORTRAIT := 40
const BARS := {
	"hp": [Color("d8433f"), Color("ff8a80")],
	"mp": [Color("4f7cff"), Color("9fc0ff")],
	"en": [Color("5cbf4a"), Color("a6ea8a")],
	"xp": [Color("e8b33a"), Color("ffe08a")],
}
## Below a quarter of health (PIX-210) the bar beats like a heart (held
## bright under reduced motion) and, in a fight, a quiet heartbeat sounds.
const LOW_HP := 0.25
const HEARTBEAT_S := 0.9
const SCREENS := [
	["inventory", "Pack"], ["map", "Map"], ["stats", "Stats"],
	["skills", "Skills"], ["codex", "Codex"], ["journal", "Journal"],
]
## What the menu's icons stand in (32, Shade's 16 at 2x).
const ICON := 32

var world: Node
var plate: PanelContainer
var portrait: AnimatedSprite2D
var name_label: Label
var rank_label: Label
var purse: HBoxContainer
var bars := {}
var xp_fill: ColorRect
var xp_track: ColorRect
var slots: Array[Dictionary] = []
var menu_button: Button
## The Menu's key beside it, the pad's Back, shown while a pad plays (the
## keyboard has none: its screens each have their own, listed in it); its
## room is kept either way.
var menu_key: PanelContainer
var menu: PanelContainer
var menu_rows := {}
## The menu's lines in order (the screens, then skills 4-6), and the one a
## pad or the arrows are on, -1 when the mouse opened it (PIX-215).
var menu_lines: Array[Dictionary] = []
var menu_focus := -1
## The line under the mouse (PIX-388): lit as focus is, without taking the
## keys the way a pad's focus does.
var menu_hover := -1
var _shown: Array = []
var _beat_left := 0.0
var _low := false
var _xp_share := 0.0
var _xp_ticks: Array[ColorRect] = []
## When the skills' shared turn began (PIX-388: the slots' sweep), in
## GameClock seconds; -1 while the hero may cast.
var _turn_from := -1.0
var _pad_shown := false


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


## Experience: a strip across the dock under the frame's top edge (PIX-388):
## the dark outline, a wooden trough, the gold fill lit along its top, a
## notch every tenth; its numbers under the mouse.
func _xp_line() -> Control:
	xp_track = ColorRect.new()
	xp_track.color = UiStyle.NIGHT
	xp_track.custom_minimum_size = Vector2(0, XP_HEIGHT)
	xp_track.mouse_filter = Control.MOUSE_FILTER_STOP
	xp_track.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var trough := ColorRect.new()
	trough.color = UiStyle.WOOD_DARK
	trough.set_anchors_preset(Control.PRESET_FULL_RECT)
	trough.offset_left = 2
	trough.offset_top = 2
	trough.offset_right = -2
	trough.offset_bottom = -2
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_track.add_child(trough)
	xp_fill = ColorRect.new()
	xp_fill.color = BARS["xp"][0]
	xp_fill.position = Vector2(2, 2)
	xp_fill.size = Vector2(0, XP_HEIGHT - 4)
	xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_track.add_child(xp_fill)
	var shine := ColorRect.new()
	shine.color = BARS["xp"][1]
	shine.size = Vector2(0, 2)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_fill.add_child(shine)
	for tenth in 9:
		var tick := ColorRect.new()
		tick.color = Color(UiStyle.NIGHT, 0.6)
		tick.size = Vector2(2, XP_HEIGHT - 4)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		xp_track.add_child(tick)
		_xp_ticks.append(tick)
	xp_track.resized.connect(_draw_xp)
	return xp_track


## The hero: the portrait in a slot, name and rank, health and energy.
func _hero() -> Control:
	var block := HBoxContainer.new()
	block.add_theme_constant_override("separation", 10)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot := PanelContainer.new()
	# The kit's wooden slot round the face (PIX-388), the paper one drawn here without it.
	slot.add_theme_stylebox_override("panel", UiStyle.slot("", UiStyle.box(UiStyle.WINDOW, UiStyle.NIGHT, 2)))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	block.add_child(slot)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(PORTRAIT, PORTRAIT)
	frame.clip_contents = true
	slot.add_child(frame)
	portrait = AnimatedSprite2D.new()
	portrait.position = Vector2(PORTRAIT / 2.0, PORTRAIT / 2.0 + 2)
	portrait.scale = Vector2(2, 2)
	frame.add_child(portrait)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(lines)
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 8)
	who.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_child(who)
	name_label = UiStyle.strong("", 12, UiStyle.CREAM)
	name_label.custom_minimum_size = Vector2(128, 0)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A name is the player's, never translated (PIX-347).
	name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	who.add_child(name_label)
	rank_label = UiStyle.label("", 12, UiStyle.GOLD)
	who.add_child(rank_label)
	for key: String in ["hp", "res"]:
		lines.add_child(_bar(key))
	return block


## A bar in a frame (PIX-388): the kit's, or a brass rim drawn here; inside
## it a dark trough and the fill with a lit top edge; its tag before it and
## its numbers after, on the wood where they read.
func _bar(key: String) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := UiStyle.strong("", 12, UiStyle.DUSK)
	tag.custom_minimum_size = Vector2(28, 0)
	line.add_child(tag)
	var style := UiStyle.bar_frame()
	if style == null:
		style = UiStyle.box(UiStyle.NIGHT, UiStyle.BRASS, 4)
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", style)
	frame.custom_minimum_size = BAR
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := Vector2(style.content_margin_left, style.content_margin_top)
	var inner := BAR - inset - Vector2(style.content_margin_right, style.content_margin_bottom)
	var trough := ColorRect.new()
	trough.color = UiStyle.WOOD_DARK
	trough.position = inset
	trough.size = inner
	frame.add_child(trough)
	var fill := ColorRect.new()
	fill.position = inset
	fill.size = inner
	frame.add_child(fill)
	var shine := ColorRect.new()
	shine.size = Vector2(inner.x, 2)
	fill.add_child(shine)
	line.add_child(frame)
	var value := UiStyle.label("", 12, UiStyle.CREAM)
	value.custom_minimum_size = Vector2(56, 0)
	line.add_child(value)
	bars[key] = {"tag": tag, "fill": fill, "shine": shine, "value": value, "inner": inner.x}
	return line


## Six slots, one per skill key: the skill's icon (Shade's, ItemIcons) in
## the kit's slot, brass when it can be cast, dark while it can't; its key
## on a dark tab over its top edge; after a cast a veil over every icon draws
## back up as the skills' shared turn runs out (PIX-388). A click casts it
## too. Without the paid icons a slot shows the skill's initials.
func _skills() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# How far in the icon sits: the kit's thicker frame, or the card's.
	var inset := UiStyle.slot("", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 4)).content_margin_left
	for index in Controls.SKILL_KEYS.size():
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(SLOT, SLOT)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		# Its tooltip is a window that samples as its owner does: crisp (PIX-384).
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				world.player.cast(index)
		)
		var face := Control.new()
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# The icon's room: the slot grows round it in the kit's thicker frame (PIX-385).
		face.custom_minimum_size = Vector2(SLOT - 12, SLOT - 12)
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
		art.position = Vector2(2, 2)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(art)
		var veil := ColorRect.new()
		veil.color = Color(UiStyle.NIGHT, 0.6)
		veil.size = Vector2(SLOT - 12, 0)
		veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.add_child(veil)
		# The key on a dark tab over the middle of the slot's top edge, as the
		# pack's tabs count theirs: a fixed rise from the slot's outer edge,
		# so it sits on the frame, clear of the icon, in either look.
		var key := Panel.new()
		key.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.NIGHT, UiStyle.NIGHT, 2))
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		key.anchor_left = 0.5
		key.anchor_right = 0.5
		key.offset_left = -TAG.x / 2.0
		key.offset_right = TAG.x / 2.0
		key.offset_top = -inset - TAG_RISE
		key.offset_bottom = key.offset_top + TAG.y
		var number := UiStyle.strong(str(index + 1), 12, UiStyle.CREAM)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# The font's line is taller than its digits: it overhangs the tab evenly.
		number.grow_vertical = Control.GROW_DIRECTION_BOTH
		key.add_child(number)
		face.add_child(key)
		row.add_child(slot)
		slots.append({"slot": slot, "mark": mark, "art": art, "veil": veil})
	return row


## Gold, and the menu of screens with its key.
func _purse() -> Control:
	var block := VBoxContainer.new()
	block.add_theme_constant_override("separation", 6)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.alignment = BoxContainer.ALIGNMENT_CENTER
	purse = UiStyle.purse(0)
	# Over the Menu, flush right: the pad's key keeps its room to its left.
	purse.alignment = BoxContainer.ALIGNMENT_END
	block.add_child(purse)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	block.add_child(line)
	menu_key = UiStyle.keycap(Controls.PAD_NAMES["dock_menu"], true)
	menu_key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(menu_key)
	menu_button = UiStyle.button("Menu", toggle_menu)
	line.add_child(menu_button)
	return block


## The panel of screens over the dock's right end (PIX-388): an icon, a
## name and a key each, points waiting in rubric red; the line chosen or
## under the mouse lit.
func _build_menu() -> void:
	menu = PanelContainer.new()
	menu.add_theme_stylebox_override("panel", UiStyle.window(12))
	menu.visible = false
	# Over the "Next" line, which floats where the menu's foot opens.
	menu.z_index = 5
	add_child(menu)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	menu.add_child(lines)
	for screen: Array in SCREENS:
		var open := func() -> void:
			menu.visible = false
			world.open_screen(screen[0])
		var row := _menu_line(lines, open, ItemIcons.screen(screen[0]))
		row["id"] = screen[0]
		menu_rows[screen[0]] = {"cap": row["cap"], "word": row["word"], "name": screen[1], "row": row}
	# Skills 4-6, for a pad with no keys for them (PIX-215).
	for index in [3, 4, 5]:
		var cast := func() -> void:
			_close_menu()
			world.player.cast(index)
		var row := _menu_line(lines, cast, null)
		row["skill"] = index
		row["id"] = "skill%d" % (index + 1)
	menu.resized.connect(_place)
	_show_focus()


## Whether the menu lists the skill on dock key `index` + 1: for a pad,
## which has no buttons for keys 4-6, and only once a skill sits there.
static func menu_skill_shown(pad: bool, docked: Array, index: int) -> bool:
	return pad and index < docked.size() and not (docked[index] as Dictionary).is_empty()


## One line of the menu: an icon, a word and its keycap, clicked or chosen
## to `run`; the mouse over it lights it.
func _menu_line(lines: VBoxContainer, run: Callable, icon: Texture2D) -> Dictionary:
	var line := PanelContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_STOP
	line.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	line.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			run.call()
	)
	var at := menu_lines.size()
	line.mouse_entered.connect(func() -> void:
		menu_hover = at
		_show_focus()
	)
	line.mouse_exited.connect(func() -> void:
		if menu_hover == at:
			menu_hover = -1
			_show_focus()
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_child(row)
	var art := TextureRect.new()
	art.texture = icon
	art.custom_minimum_size = Vector2(ICON, ICON)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(art)
	var word := UiStyle.label("", 16, UiStyle.INK)
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(word)
	var cap := UiStyle.keycap("", true)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cap)
	lines.add_child(line)
	var entry := {"line": line, "cap": cap, "word": word, "art": art, "run": run}
	menu_lines.append(entry)
	return entry


## Whether the menu has the pad's (or the arrows') attention now.
func steering() -> bool:
	return menu.visible and menu_focus >= 0


func _close_menu() -> void:
	menu.visible = false
	menu_focus = -1
	menu_hover = -1


## The chosen line (or, with none, the one under the mouse) on a rubric
## card, its word in rubric red; the rest plain on the page; points waiting
## in rubric red too.
func _show_focus() -> void:
	var lit := menu_focus if menu_focus >= 0 else menu_hover
	for index in menu_lines.size():
		var row: Dictionary = menu_lines[index]
		var on := index == lit
		var rim := UiStyle.LAMP if on and menu_focus >= 0 else UiStyle.RIM if on else Color(0, 0, 0, 0)
		row["line"].add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.CARD, 1.0 if on else 0.0), rim, 4))
		var waiting: bool = row.get("waiting", false)
		row["word"].add_theme_color_override("font_color", UiStyle.LAMP if on or waiting else UiStyle.INK)


func toggle_menu() -> void:
	if not menu.visible:
		refresh()
	menu.visible = not menu.visible
	menu_focus = -1
	menu_hover = -1
	_show_focus()
	_place()


func _process(delta: float) -> void:
	_warn_low_hp(delta)
	# The keys a pad or a keyboard shows follow the hands (PIX-388: the Menu's cap).
	if Controls.pad != _pad_shown:
		refresh()
	# The skills change state on their own (a cast spent, energy back), so the
	# slots follow every frame, redrawn only when something changed.
	var hero := GameState.hero
	# What the hero put on each key (PIX-190), an empty key where there's none.
	var skills := Skills.docked(hero).slice(0, slots.size())
	_sweep(skills)
	var states := skills.map(func(skill: Dictionary) -> bool:
		return not skill.is_empty() and Skills.cast_block(hero, skill) == "" and world.player.skill_ready
	)
	# The turn too: its end dims what still can't be cast (slot alpha below).
	var shown := [skills.map(func(skill: Dictionary) -> String: return skill.get("name", "")), states, _turn_from >= 0.0]
	if shown == _shown:
		return
	_shown = shown
	for index in slots.size():
		var slot: PanelContainer = slots[index]["slot"]
		var mark: Label = slots[index]["mark"]
		var has: bool = index < skills.size() and not skills[index].is_empty()
		var ready: bool = has and states[index]
		# Ready to cast: a brass rim; spent, too dear or not yet reached: dim.
		slot.add_theme_stylebox_override("panel", UiStyle.slot(
			"ready" if ready else "spent" if has else "",
			UiStyle.box(UiStyle.WINDOW if has else UiStyle.CARD, UiStyle.BRASS if ready else UiStyle.RIM, 4)
		))
		# The turn's veil says it while it runs; dimmed, a skill can't be cast for itself.
		slot.modulate.a = 1.0 if ready or not has or _turn_from >= 0.0 else 0.55
		var icon := ItemIcons.skill(skills[index]["name"]) if has else null
		var art: TextureRect = slots[index]["art"]
		art.texture = icon
		mark.text = _initials(skills[index]["name"]) if has and icon == null else ""
		slot.tooltip_text = _describe(skills[index]) if has else ""


## The skills' shared turn after a cast (Player.SKILL_TURN): a veil over
## each skill's icon, drawing back up as the turn runs out.
func _sweep(skills: Array) -> void:
	if world.player.skill_ready:
		_turn_from = -1.0
	elif _turn_from < 0.0:
		_turn_from = GameClock.seconds()
	var high := veil_height(SLOT - 12, GameClock.seconds() - _turn_from, world.player.SKILL_TURN) if _turn_from >= 0.0 else 0.0
	for index in slots.size():
		var veil: ColorRect = slots[index]["veil"]
		var has: bool = index < skills.size() and not (skills[index] as Dictionary).is_empty()
		veil.size.y = high if has else 0.0


## The veil over a `full`-pixel icon `since` seconds into a `turn`: as tall
## as the share of the turn left, in whole art pixels (two canvas pixels).
static func veil_height(full: float, since: float, turn: float) -> float:
	return floorf(full * clampf(1.0 - since / turn, 0.0, 1.0) / 2.0) * 2.0


static func low_hp(hp: int, most: int) -> bool:
	return hp > 0 and hp < most * LOW_HP


func _warn_low_hp(delta: float) -> void:
	var hero := GameState.hero
	var fill: ColorRect = bars["hp"]["fill"]
	var value: Label = bars["hp"]["value"]
	var low := low_hp(hero.hp, int(hero.stats["maxHp"]))
	if low != _low:
		_low = low
		value.add_theme_color_override("font_color", BARS["hp"][1] if low else UiStyle.CREAM)
	if not low:
		fill.modulate = Color.WHITE
		_beat_left = 0.0
		return
	var bright := Color(1.6, 1.5, 1.5)
	if GameState.settings.reduce_motion:
		fill.modulate = bright
	else:
		var beat := 0.5 + 0.5 * sin(GameClock.seconds() * TAU / HEARTBEAT_S)
		fill.modulate = Color.WHITE.lerp(bright, beat)
	if world != null and world.foes.in_fight():
		_beat_left -= delta
		if _beat_left <= 0.0:
			_beat_left = HEARTBEAT_S
			Sound.play_ui("heart")


## "Power Strike" -> "PS": what a slot shows until the skills have icons.
static func _initials(name: String) -> String:
	var letters := ""
	for word: String in name.split(" ", false):
		letters += word.left(1)
	return letters.left(2).to_upper()


func _describe(skill: Dictionary) -> String:
	var cost := "%d %s" % [skill["mpCost"], Skills.resource_label(GameState.hero.role_id)]
	if int(skill.get("hpCost", 0)) > 0:
		cost += Text.t(" +%d HP") % skill["hpCost"]
	return "%s  -  %s" % [skill["name"], cost]


## Everything again from the hero: called on any change GameState reports.
func refresh() -> void:
	var hero := GameState.hero
	var pack := GameState.pack
	var art := GameState.upkeep.hero_art()
	portrait.sprite_frames = PunyArt.frames(art)
	portrait.self_modulate = art["tint"]
	portrait.play(PunyArt.pick(portrait.sprite_frames, "idle", "down"))
	name_label.text = hero.hero_name
	rank_label.text = Text.t("Lv %d %s") % [hero.level, Ranks.title(hero.role_id, hero.level)]
	UiStyle.purse_set(purse, pack.gold)
	var resource := Skills.resource_label(hero.role_id)
	_set_bar("hp", Text.t("HP"), hero.hp, int(hero.stats["maxHp"]), BARS["hp"])
	var stamina: bool = Catalog.role(hero.role_id)["resource"] == "endurance"
	_set_bar("res", resource, hero.mp, int(hero.stats["maxMp"]), BARS["en"] if stamina else BARS["mp"])
	_set_xp(hero.xp, hero.xp_to_next)
	var keys := GameState.settings.bindings
	var waiting_any := false
	for screen: String in menu_rows:
		var line: Dictionary = menu_rows[screen]
		UiStyle.keycap_text(line["cap"], Controls.key_label(Controls.key_for(screen, keys)))
		# A whole tree's spare points are spent in Stats (PIX-217).
		var waiting := hero.stat_points + (hero.skill_points if Skills.beyond_open(hero) else 0) if screen == "stats" else (hero.skill_points if screen == "skills" and Skills.tree_open(hero) else 0)
		waiting_any = waiting_any or waiting > 0
		line["word"].text = Text.t(line["name"]) + ("  +%d" % waiting if waiting > 0 else "")
		line["row"]["waiting"] = waiting > 0
	# Skills 4-6 by name (PIX-215), only for a pad (it has no buttons for
	# them) and only once learned: on a keyboard 4-6 are keys, and a menu of
	# screens listing attacks reads oddly.
	var docked := Skills.docked(hero)
	for row: Dictionary in menu_lines:
		if not row.has("skill"):
			continue
		var index: int = row["skill"]
		var has: bool = index < docked.size() and not (docked[index] as Dictionary).is_empty()
		row["line"].visible = menu_skill_shown(Controls.pad, docked, index)
		UiStyle.keycap_text(row["cap"], str(index + 1))
		row["word"].text = String(docked[index].get("name", "")) if has else ""
		row["art"].texture = ItemIcons.skill(docked[index]["name"]) if has else null
	_show_focus()
	_pad_shown = Controls.pad
	# Its room stays kept, so the dock's width (and every slot) holds when the hands change.
	menu_key.modulate.a = 1.0 if _pad_shown else 0.0
	# Points to spend light the menu, so they're never missed.
	UiStyle.focus(menu_button, waiting_any)
	# Back to the size its words need now (a shorter rank, less gold).
	plate.reset_size()


func _set_bar(key: String, tag: String, value: int, most: int, colors: Array) -> void:
	var bar: Dictionary = bars[key]
	bar["tag"].text = tag
	bar["fill"].color = colors[0]
	bar["shine"].color = colors[1]
	# Whole art pixels: the fill grows two canvas pixels at a time.
	bar["fill"].size.x = floorf(float(bar["inner"]) * clampf(float(value) / maxi(1, most), 0.0, 1.0) / 2.0) * 2.0
	bar["shine"].size.x = bar["fill"].size.x
	bar["value"].text = "%d/%d" % [value, most]


## A level gained (PIX-211): the experience strip flashes bright and settles.
func flash_xp() -> void:
	var flash := xp_fill.create_tween()
	xp_track.modulate = Color(1.8, 1.7, 1.2)
	flash.tween_property(xp_track, "modulate", Color.WHITE, 0.9).set_ease(Tween.EASE_IN)


func _set_xp(xp: int, to_next: int) -> void:
	_xp_share = clampf(float(xp) / maxi(1, to_next), 0.0, 1.0)
	xp_track.tooltip_text = Text.t("XP %d/%d") % [xp, to_next]
	_draw_xp()


## The strip's fill and notches at its width now (it's known once laid out).
func _draw_xp() -> void:
	var inner := maxf(0.0, xp_track.size.x - 4.0)
	xp_fill.size.x = floorf(inner * _xp_share / 2.0) * 2.0
	(xp_fill.get_child(0) as Control).size.x = xp_fill.size.x
	for tenth in _xp_ticks.size():
		_xp_ticks[tenth].position = Vector2(2.0 + floorf(inner * (tenth + 1) / 10.0 / 2.0) * 2.0, 2.0)


func _unhandled_input(event: InputEvent) -> void:
	# The pad's Back opens the menu with its first line chosen (PIX-215).
	if event.is_action_pressed("dock_menu"):
		get_viewport().set_input_as_handled()
		if menu.visible:
			_close_menu()
		else:
			refresh()
			menu.visible = true
			menu_focus = 0
			_place()
		_show_focus()
		return
	# The menu closes on Esc before the pause menu would open.
	if menu.visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu")):
		get_viewport().set_input_as_handled()
		_close_menu()
		_show_focus()
		return
	if not steering():
		return
	for step: Array in [["move_up", -1], ["move_down", 1]]:
		if event.is_action_pressed(step[0]):
			get_viewport().set_input_as_handled()
			# Past the lines hidden (a keyboard's skills), to the next one shown.
			for _tries in menu_lines.size():
				menu_focus = posmod(menu_focus + int(step[1]), menu_lines.size())
				if (menu_lines[menu_focus]["line"] as Control).visible:
					break
			_show_focus()
			Sound.play_ui("tick")
			return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		var run: Callable = menu_lines[menu_focus]["run"]
		menu_focus = -1
		run.call()
		return
	# Nothing else reaches the world while the pad is in the menu.
	if event.is_action_pressed("attack") or event.is_action_pressed("dodge") or event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		get_viewport().set_input_as_handled()
