extends PanelContainer
## The hero plate over the world (WorldHud.tsx): who they are in a portrait
## slot, their rank, gold, pixel bars for health, mana or stamina and
## experience, and the screens a click away as keycap chips, each showing the
## stat or skill points waiting to be spent.

const BAR := Vector2(176, 12)
const BARS := {
	"hp": [Color("e0474c"), Color("ff8a80")],
	"mp": [Color("4f7cff"), Color("9fc0ff")],
	"en": [Color("5cbf4a"), Color("a6ea8a")],
	"xp": [Color("e8b33a"), Color("ffe08a")],
}
const SCREENS := [
	["inventory", "Pack"], ["map", "Map"], ["stats", "Stats"],
	["skills", "Skills"], ["codex", "Codex"], ["journal", "Journal"],
]

var world: Node
var portrait: AnimatedSprite2D
var name_label: Label
var rank_label: Label
var gold_label: Label
var bars := {}
var chips := {}


func _ready() -> void:
	position = Vector2(12, 12)
	custom_minimum_size = Vector2(312, 0)
	add_theme_stylebox_override("panel", UiStyle.window(12))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	column.add_child(top)
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 2))
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(slot)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(40, 40)
	frame.clip_contents = true
	slot.add_child(frame)
	portrait = AnimatedSprite2D.new()
	portrait.position = Vector2(20, 22)
	portrait.scale = Vector2(2, 2)
	frame.add_child(portrait)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 2)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(who)
	name_label = UiStyle.strong("", 16, UiStyle.INK)
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	who.add_child(name_label)
	rank_label = UiStyle.label("", 12, UiStyle.FADED)
	who.add_child(rank_label)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 4)
	purse.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var coin := TextureRect.new()
	coin.texture = load("res://assets/sprites/gold.png")
	coin.custom_minimum_size = Vector2(16, 16)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	purse.add_child(coin)
	gold_label = UiStyle.strong("", 16, UiStyle.LAMP)
	purse.add_child(gold_label)
	top.add_child(purse)

	for key: String in ["hp", "res", "xp"]:
		column.add_child(_bar(key))

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 4)
	column.add_child(actions)
	for screen: Array in SCREENS:
		actions.add_child(_chip(screen[0], screen[1]))
	refresh()


## A pixel bar: a dark outline, the track, the fill with a lit top edge.
func _bar(key: String) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := UiStyle.strong("", 12, UiStyle.FADED)
	tag.custom_minimum_size = Vector2(22, 0)
	line.add_child(tag)
	var outline := ColorRect.new()
	outline.color = UiStyle.NIGHT
	outline.custom_minimum_size = BAR
	outline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := ColorRect.new()
	track.color = Color("181b38")
	track.position = Vector2(2, 2)
	track.size = BAR - Vector2(4, 4)
	outline.add_child(track)
	var fill := ColorRect.new()
	fill.position = Vector2(2, 2)
	fill.size = BAR - Vector2(4, 4)
	outline.add_child(fill)
	var shine := ColorRect.new()
	shine.size = Vector2(fill.size.x, 2)
	fill.add_child(shine)
	line.add_child(outline)
	var value := UiStyle.label("", 12, UiStyle.INK)
	line.add_child(value)
	bars[key] = {"tag": tag, "fill": fill, "shine": shine, "value": value}
	return line


## A screen a click away: its key as a keycap and its name.
func _chip(screen: String, word: String) -> Control:
	var chip := PanelContainer.new()
	var calm := UiStyle.box(UiStyle.CARD, UiStyle.RIM, 4)
	var lit := UiStyle.box(UiStyle.CARD, UiStyle.LAMP, 4)
	chip.add_theme_stylebox_override("panel", calm)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.mouse_entered.connect(func() -> void: chip.add_theme_stylebox_override("panel", lit))
	chip.mouse_exited.connect(func() -> void: chip.add_theme_stylebox_override("panel", calm))
	chip.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			world.open_screen(screen)
	)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(row)
	var cap := UiStyle.keycap("", true)
	row.add_child(cap)
	var name := UiStyle.label(word, 12, UiStyle.INK)
	row.add_child(name)
	chips[screen] = {"cap": cap, "name": name, "word": word}
	return chip


## Everything again from the hero: called on any change GameState reports.
func refresh() -> void:
	var hero := GameState.hero
	var pack := GameState.pack
	var art := PunyArt.hero(hero.role_id, hero.look)
	portrait.sprite_frames = PunyArt.frames(art)
	portrait.self_modulate = art["tint"]
	portrait.play(PunyArt.pick(portrait.sprite_frames, "idle", "down"))
	name_label.text = hero.hero_name
	rank_label.text = "Lv %d %s   DEF %d" % [hero.level, Ranks.title(hero.role_id, hero.level), HeroRules.total_defense(hero, pack)]
	gold_label.text = str(pack.gold)
	var resource := Skills.resource_label(hero.role_id)
	_set_bar("hp", "HP", hero.hp, int(hero.stats["maxHp"]), BARS["hp"])
	_set_bar("res", resource, hero.mp, int(hero.stats["maxMp"]), BARS["en"] if resource == "EN" else BARS["mp"])
	_set_bar("xp", "XP", hero.xp, hero.xp_to_next, BARS["xp"])
	var keys := GameState.settings.bindings
	for screen: String in chips:
		var chip: Dictionary = chips[screen]
		UiStyle.keycap_text(chip["cap"], Controls.key_label(Controls.key_for(screen, keys)))
		var waiting := 0
		if screen == "stats":
			waiting = hero.stat_points
		elif screen == "skills":
			waiting = hero.skill_points
		chip["name"].text = chip["word"] + ("  +%d" % waiting if waiting > 0 else "")
		chip["name"].add_theme_color_override("font_color", UiStyle.LAMP if waiting > 0 else UiStyle.INK)


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
