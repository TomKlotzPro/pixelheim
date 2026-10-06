extends PanelContainer
## The hero panel floating over the world (WorldHud.tsx): who they are,
## their rank and defense, gold, the health, mana or stamina and experience
## bars, and the screens a click away, each button showing its key and the
## stat or skill points waiting to be spent. Big enough to tap on the web.

const BAR_WIDTH := 190.0
const BARS := {
	"hp": Color(0.82, 0.22, 0.24), "mp": Color(0.3, 0.5, 0.95), "en": Color(0.35, 0.75, 0.4),
	"xp": Color(1, 0.8, 0.3),
}

var world: Node
var portrait: AnimatedSprite2D
var name_label: Label
var rank_label: Label
var gold_label: Label
var bars := {}
var buttons := {}


func _ready() -> void:
	position = Vector2(14, 14)
	custom_minimum_size = Vector2(316, 0)
	add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.CARD, 0.88), UiStyle.RIM, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	column.add_child(top)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(36, 36)
	frame.clip_contents = true
	top.add_child(frame)
	portrait = AnimatedSprite2D.new()
	portrait.position = Vector2(18, 16)
	portrait.scale = Vector2(1.25, 1.25)
	frame.add_child(portrait)
	var who := VBoxContainer.new()
	who.add_theme_constant_override("separation", 0)
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(who)
	name_label = UiStyle.label("", 15, UiStyle.INK)
	who.add_child(name_label)
	rank_label = UiStyle.label("", 12, UiStyle.FADED)
	who.add_child(rank_label)
	var purse := HBoxContainer.new()
	purse.add_theme_constant_override("separation", 4)
	var coin := TextureRect.new()
	coin.texture = load("res://assets/sprites/gold.png")
	coin.custom_minimum_size = Vector2(16, 16)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	purse.add_child(coin)
	gold_label = UiStyle.label("", 15, UiStyle.LAMP)
	purse.add_child(gold_label)
	top.add_child(purse)

	for key: String in ["hp", "res", "xp"]:
		column.add_child(_bar(key))

	var actions := HFlowContainer.new()
	actions.add_theme_constant_override("h_separation", 4)
	actions.add_theme_constant_override("v_separation", 4)
	column.add_child(actions)
	for action: String in ["inventory", "map", "stats", "skills", "codex", "journal"]:
		var button := UiStyle.button("", world.open_screen.bind(action))
		button.add_theme_font_size_override("font_size", 12)
		button.custom_minimum_size = Vector2(0, 26)
		buttons[action] = button
		actions.add_child(button)
	refresh()


func _bar(key: String) -> Control:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	var label := UiStyle.label("", 12, UiStyle.FADED)
	label.custom_minimum_size = Vector2(24, 0)
	line.add_child(label)
	var track := ColorRect.new()
	track.color = Color(0.06, 0.05, 0.06, 0.9)
	track.custom_minimum_size = Vector2(BAR_WIDTH, 9)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.size = Vector2(BAR_WIDTH, 9)
	track.add_child(fill)
	line.add_child(track)
	var value := UiStyle.label("", 12, UiStyle.INK)
	line.add_child(value)
	bars[key] = {"label": label, "fill": fill, "value": value}
	return line


## Everything again from the hero: called on any change GameState reports.
func refresh() -> void:
	var hero := GameState.hero
	var pack := GameState.pack
	var art := PunyArt.hero(hero.role_id, hero.look)
	portrait.sprite_frames = PunyArt.frames(art)
	portrait.self_modulate = art["tint"]
	portrait.play(PunyArt.pick(portrait.sprite_frames, "idle", "down"))
	name_label.text = hero.hero_name
	rank_label.text = "Lv %d %s · DEF %d" % [hero.level, Ranks.title(hero.role_id, hero.level), HeroRules.total_defense(hero, pack)]
	gold_label.text = str(pack.gold)
	var resource := Skills.resource_label(hero.role_id)
	_set_bar("hp", "HP", hero.hp, int(hero.stats["maxHp"]), BARS["hp"])
	_set_bar("res", resource, hero.mp, int(hero.stats["maxMp"]), BARS["en"] if resource == "EN" else BARS["mp"])
	_set_bar("xp", "XP", hero.xp, hero.xp_to_next, BARS["xp"])
	var keys := GameState.settings.bindings
	var names := {"inventory": "Pack", "map": "Map", "stats": "Stats", "skills": "Skills", "codex": "Codex", "journal": "Journal"}
	for action: String in buttons:
		var text := "%s %s" % [names[action], Controls.key_label(Controls.key_for(action, keys))]
		if action == "stats" and hero.stat_points > 0:
			text += "  +%d" % hero.stat_points
		elif action == "skills" and hero.skill_points > 0:
			text += "  +%d" % hero.skill_points
		var button: Button = buttons[action]
		button.text = text
		var waiting := text.contains("+")
		button.add_theme_color_override("font_color", UiStyle.LAMP if waiting else UiStyle.INK)


func _set_bar(key: String, label: String, value: int, most: int, color: Color) -> void:
	var bar: Dictionary = bars[key]
	bar["label"].text = label
	bar["fill"].color = color
	bar["fill"].size.x = BAR_WIDTH * clampf(float(value) / maxi(1, most), 0.0, 1.0)
	bar["value"].text = "%d/%d" % [value, most]
