extends Screen
## The ascension (RankUpOverlay.tsx, useRankUp): letterbox bars close in,
## rays turn behind the marching hero, and the title card names the new rank
## and its bonus skill point. At a fork in the Path Graph the cards hold the
## scene until a walk is chosen (or put off to the skill tree); otherwise it
## passes after a few seconds. The world holds still meanwhile.

const HOLD_SECONDS := 4.2
const BAR := 92.0

var title := ""
var choices: Array = []
var selected := 0
var rays: Node2D
var cards: HBoxContainer
var note: Label
var closing := false


## Its own entrance, not the screens' ease (PIX-212).
func _eases_in() -> bool:
	return false


func _open() -> void:
	layer = 6
	var view := Vector2(1280, 720)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, 0.86)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	rays = Node2D.new()
	rays.position = Vector2(view.x / 2, 250)
	for i in 12:
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(0, -620)])
		ray.color = Color(UiStyle.LAMP, 0.10)
		ray.rotation = TAU * i / 12.0
		rays.add_child(ray)
	add_child(rays)

	# The hero marches in from the left and stops beneath the title.
	var hero := AnimatedSprite2D.new()
	var art := GameState.hero_art()
	hero.sprite_frames = PunyArt.frames(art)
	hero.self_modulate = art["tint"]
	hero.scale = Vector2(6, 6)
	hero.position = Vector2(view.x / 2 - 300, 236)
	hero.play(PunyArt.pick(hero.sprite_frames, "walk", "right"))
	add_child(hero)
	var march := create_tween()
	march.tween_property(hero, "position:x", view.x / 2, 1.4).set_ease(Tween.EASE_OUT)
	march.tween_callback(func() -> void: hero.play(PunyArt.pick(hero.sprite_frames, "idle", "down")))

	var card := VBoxContainer.new()
	card.position = Vector2(0, 330)
	card.custom_minimum_size = Vector2(view.x, 0)
	card.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(card)
	# What the rank's bonus point is for, truly (PIX-217).
	var bonus := "+1 bonus skill point"
	if Skills.all_learned(GameState.hero):
		bonus = "Every skill mastered: the bonus point rests"
	elif Skills.tree_whole(GameState.hero):
		bonus = "+1 bonus skill point, to spend beyond the tree (Stats)"
	for line: Array in [["Ascension", 15, UiStyle.DUSK], [title, 30, UiStyle.GOLD], [bonus, 15, UiStyle.CREAM]]:
		var label := UiStyle.heading(line[0], line[1], line[2]) if line[0] == title else UiStyle.label(line[0], line[1], line[2])
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
		label.add_theme_constant_override("outline_size", 6)
		card.add_child(label)

	cards = HBoxContainer.new()
	cards.position = Vector2(0, 470)
	cards.custom_minimum_size = Vector2(view.x, 0)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	add_child(cards)
	# Letterbox bars slide in over everything.
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(view.x, 0)
		bar.position = Vector2(0, 0 if top else view.y)
		add_child(bar)
		var slide := create_tween().set_parallel()
		slide.tween_property(bar, "size:y", BAR, 0.5)
		if not top:
			slide.tween_property(bar, "position:y", view.y - BAR, 0.5)
	# The fork's keys ride in the lower bar.
	note = UiStyle.label("", 14, UiStyle.DUSK, Vector2(0, view.y - BAR / 2 - 10))
	note.custom_minimum_size = Vector2(view.x, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	_offer()


func _process(delta: float) -> void:
	if not GameState.settings.reduce_motion:
		rays.rotation += delta * 0.25


## The fork's cards, or the timer that lets the moment pass.
func _offer() -> void:
	choices = Ranks.path_choices(GameState.hero)
	selected = clampi(selected, 0, maxi(0, choices.size() - 1))
	Layout.clear(cards)
	if choices.is_empty():
		note.text = ""
		get_tree().create_timer(HOLD_SECONDS, true, false, true).timeout.connect(_close)
		return
	for index in choices.size():
		cards.add_child(_card(choices[index], index == selected))
	note.text = "The path forks      A/D  choose      E  walk this path      Esc  choose later, in Skills"


func _card(node: Dictionary, chosen: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 150)
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP if chosen else UiStyle.RIM, 14))
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	panel.add_child(lines)
	lines.add_child(UiStyle.label(node["name"], 20, UiStyle.LAMP if chosen else UiStyle.INK))
	var blurb := UiStyle.label(node["blurb"], 14, UiStyle.INK)
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(300, 0)
	lines.add_child(blurb)
	lines.add_child(UiStyle.label(Text.t("Signature: %s") % node["signature"]["name"], 13, UiStyle.FADED))
	return panel


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		command = _close
	elif choices.is_empty():
		if event.is_action_pressed("interact"):
			command = _close
	elif event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
		command = _pick.bind(selected - 1)
	elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
		command = _pick.bind(selected + 1)
	elif event.is_action_pressed("interact"):
		command = _walk
	return command


func _pick(index: int) -> void:
	selected = wrapi(index, 0, choices.size())
	_offer()


## The walk is taken; a further tier the rank already allows opens at once.
func _walk() -> void:
	if GameState.choose_path(choices[selected]["id"]):
		Sound.play("learn")
	selected = 0
	_offer()


func _close() -> void:
	if closing:
		return
	closing = true
	close()
