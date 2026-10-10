extends Screen
## The dawn after the Night of Ash (PIX-197), played on the town itself
## rather than told over it. The world holds still (the hero can't wander
## off), but the town keeps living below:
## 1. the fires go out: the camera drifts from the shrine across the town
##    while each ruin's fire gutters out in turn, and the red night eases to
##    a grey dawn;
## 2. a breath of dark, and the survivors stand round the square's heart;
## 3. they speak, each line in a bubble over whoever says it (the telling in
##    a plate below); on Fafnyr's name a roar, and his shadow sweeps across;
##    last, the tagline's moment (PIX-253): the courier should have ridden
##    south by noon, and stayed;
## 4. a card - Pixelheim, day one - and the day begins.
## E (or a strike) moves the talk on; Esc skips to the day. With Reduce
## motion the camera cuts, nothing shakes and the shadow stays away.

## How long the fires take to go out, and the sky to turn.
const FIRES_SECONDS := 7.0
## The morning's grey, before the day's own sky takes over.
const DAWN_GREY := Color(0.42, 0.36, 0.4, 0.22)

var world: Node
var on_done := Callable()
var _beats: Array = []
var _index := -1
var _flow: Tween
var _phase := "fires"
## Who speaks: id -> the figure standing on the square.
var _actors := {}
var _plate: PanelContainer
var _plate_text: Label
var _bubble: PanelContainer
var _bubble_text: Label
var _bubble_name: Label
var _speaker: Node2D
var _black: ColorRect
var _shadow: AnimatedSprite2D
var _card: VBoxContainer
## The tagline's words, mid-screen (PIX-253).
var _tag: VBoxContainer
var _shake_left := 0.0


func _open() -> void:
	layer = 4
	_beats = Prologue.dawn()
	# The hero holds still; the fires, the smoke and the people don't.
	world.view.props.process_mode = Node.PROCESS_MODE_ALWAYS
	for villager in get_tree().get_nodes_in_group("npcs"):
		villager.process_mode = Node.PROCESS_MODE_ALWAYS
	world.camera_rig.follows = false
	world.camera_rig.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Sound.play_theme("dawn")
	_fires()


func _build() -> void:
	var view := Touch.view_size(self)
	_black = ColorRect.new()
	_black.color = Color(0, 0, 0, 0)
	_black.position = -offset
	_black.size = view
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	# The telling, on the HUD's plate (PIX-194) above where the dock stood.
	_plate = PanelContainer.new()
	_plate.add_theme_stylebox_override("panel", UiStyle.plate(16))
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_text = UiStyle.plate_text("")
	_plate_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_plate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_text.custom_minimum_size = Vector2(760, 0)
	_plate.add_child(_plate_text)
	_plate.visible = false
	add_child(_plate)
	# A speaker's words: a page over their head, their name in rubric.
	_bubble = PanelContainer.new()
	_bubble.add_theme_stylebox_override("panel", UiStyle.window(10))
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	_bubble.add_child(lines)
	_bubble_name = UiStyle.strong("", 16, UiStyle.LAMP)
	lines.add_child(_bubble_name)
	_bubble_text = UiStyle.label("", UiStyle.reading(16), UiStyle.INK)
	_bubble_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble_text.custom_minimum_size = Vector2(420, 0)
	lines.add_child(_bubble_text)
	_bubble.visible = false
	add_child(_bubble)
	add_child(UiStyle.footer("{key:interact}  next      Esc  skip", Vector2(1010, 40)))


## 1. The camera drifts from the shrine across the town; the fires go out in
## the order it meets them, and the night greys toward morning.
func _fires() -> void:
	_phase = "fires"
	_tell(String(_beats[0]["line"]))
	var still := GameState.settings.reduce_motion
	var path: Array[Vector2] = [
		world.camera_rig.camera.global_position,
		MapView.center(Vector2i(24, 12)),
		MapView.center(Vector2i(48, 14)),
		MapView.center(Town.square()),
	]
	_flow = create_tween()
	_flow.set_parallel()
	if still:
		world.camera_rig.camera.global_position = path[-1]
	else:
		var legs := path.size() - 1
		for i in legs:
			_flow.tween_property(world.camera_rig.camera, "global_position", path[i + 1], FIRES_SECONDS / legs) \
				.set_delay(FIRES_SECONDS / legs * i).set_trans(Tween.TRANS_SINE)
	# Each fire goes out as the camera passes it.
	var order := range(world.view.fires.size())
	var start: Vector2 = path[0]
	order.sort_custom(func(a: int, b: int) -> bool:
		return _fire_at(a).distance_to(start) < _fire_at(b).distance_to(start))
	for n in order.size():
		var index: int = order[n]
		_flow.tween_callback(func() -> void: world.view.douse(index, 0.2 if still else 1.4)) \
			.set_delay(0.4 + (FIRES_SECONDS - 1.2) * n / maxf(1.0, order.size() - 1))
	var sky: ColorRect = world.hud.sky_overlay
	_flow.tween_property(sky, "color", DAWN_GREY, FIRES_SECONDS)
	_flow.chain().tween_interval(0.6)
	_flow.chain().tween_callback(_gather)


func _fire_at(index: int) -> Vector2:
	var rect: Rect2i = world.view.fires[index]["rect"]
	return MapView.center(rect.get_center())


## 2. A breath of dark; the survivors (and the mayor, out of his hall) stand
## round the square's heart, the hero below them facing Maren.
func _gather() -> void:
	_phase = "gather"
	_plate.visible = false
	_flow = create_tween()
	_flow.tween_property(_black, "color:a", 1.0, 0.0 if GameState.settings.reduce_motion else 0.5)
	_flow.tween_callback(_place_everyone)
	_flow.tween_interval(0.3)
	_flow.tween_property(_black, "color:a", 0.0, 0.0 if GameState.settings.reduce_motion else 0.6)
	_flow.tween_callback(_talk)


func _place_everyone() -> void:
	var places := Prologue.dawn_places()
	for villager in get_tree().get_nodes_in_group("npcs"):
		if places.has(villager.data["id"]):
			_stand(villager, places[villager.data["id"]])
	if not _actors.has("mayor"):
		var mayor: Dictionary = {}
		for npc: Dictionary in Npcs._data()["npcs"]:
			if npc["id"] == "mayor":
				mayor = npc.duplicate()
		mayor.merge({"mapId": "town", "x": places["mayor"].x, "y": places["mayor"].y, "wander": false, "lines": []}, true)
		var figure := preload("res://scripts/npc.gd").new()
		figure.world = world
		figure.data = mayor
		figure.sync_to_physics = false
		figure.process_mode = Node.PROCESS_MODE_ALWAYS
		figure.add_to_group("decor")
		world.actors.add_child(figure)
		_actors["mayor"] = figure
	var hero_cell: Vector2i = Town.square() + Vector2i(0, 2)
	world.player.position = MapView.center(hero_cell)
	world.player_cell = hero_cell
	world.player.face(Vector2.UP)
	world.camera_rig.camera.global_position = MapView.center(Town.square())
	world.hud.sky_overlay.color = DAWN_GREY


func _stand(villager: Node2D, cell: Vector2i) -> void:
	# A villager is a physics body, and the world's physics is held: moved
	# by hand, not synced from the paused server (the day respawns them).
	villager.sync_to_physics = false
	villager.home = cell
	villager.cell = cell
	villager.gather_at = cell
	villager.position = MapView.center(cell)
	villager.reset_physics_interpolation()
	_actors[villager.data["id"]] = villager


## 3. Line by line: a bubble over the speaker, or the telling below.
func _talk() -> void:
	_phase = "talk"
	_index = 0
	_next()


func _next() -> void:
	_index += 1
	if _index >= _beats.size():
		_day_card()
		return
	var beat: Dictionary = _beats[_index]
	if beat.get("tagline", false):
		_tagline(String(beat["line"]))
		return
	var who := String(beat["who"])
	if who == "" or not _actors.has(who):
		_bubble.visible = false
		_speaker = null
		_tell(String(beat["line"]))
	else:
		_plate.visible = false
		_speaker = _actors[who]
		_bubble_name.text = String(_speaker.data["name"])
		_bubble_text.text = String(beat["line"])
		_bubble.reset_size()
		_bubble.visible = true
	if beat.get("shadow", false):
		_fafnyr()


## The telling: centred above where the dock stands.
func _tell(line: String) -> void:
	_plate_text.text = line
	_plate.reset_size()
	_plate.position = Vector2(roundf((1280 - _plate.size.x) / 2.0), 560 - _plate.size.y)
	_plate.visible = true


## The tagline's moment (PIX-253), the last word before the card: the town
## dims behind it and the line stands alone mid-screen, its last sentence
## ("You stayed.") a breath after the rest, in gold.
func _tagline(line: String) -> void:
	_bubble.visible = false
	_speaker = null
	_plate.visible = false
	var cut := line.rfind(". ")
	var told := line if cut < 0 else line.left(cut + 1)
	var stayed := "" if cut < 0 else line.substr(cut + 2)
	_tag = VBoxContainer.new()
	_tag.alignment = BoxContainer.ALIGNMENT_CENTER
	_tag.add_theme_constant_override("separation", 18)
	_tag.position = Vector2(140, 250)
	_tag.size = Vector2(1000, 180)
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for part: String in [told, stayed]:
		if part == "":
			continue
		var words := UiStyle.heading(part, 18, UiStyle.CREAM if part == told else UiStyle.GOLD)
		words.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.custom_minimum_size = Vector2(1000, 0)
		_tag.add_child(words)
	add_child(_tag)
	var still := GameState.settings.reduce_motion
	_flow = create_tween()
	_flow.tween_property(_black, "color:a", 0.55, 0.0 if still else 0.8)
	if _tag.get_child_count() > 1 and not still:
		var last: Control = _tag.get_child(1)
		last.modulate.a = 0.0
		_flow.tween_interval(0.6)
		_flow.tween_property(last, "modulate:a", 1.0, 0.8)


## On Fafnyr's name: a roar, the ground shaking, his shadow across the town.
func _fafnyr() -> void:
	Sound.play("roar")
	if GameState.settings.reduce_motion:
		return
	_shake_left = 0.8
	var frames := PunyArt.frames(PunyArt.monster("dragon"))
	_shadow = AnimatedSprite2D.new()
	_shadow.sprite_frames = frames
	_shadow.play(PunyArt.pick(frames, "walk", "left"))
	_shadow.modulate = Color(0, 0, 0, 0.42)
	_shadow.scale = Vector2.ONE * 9.0
	_shadow.position = Vector2(1500, 160)
	add_child(_shadow)
	move_child(_shadow, 1)
	var sweep := create_tween()
	sweep.tween_property(_shadow, "position", Vector2(-260, 300), 2.4).set_trans(Tween.TRANS_SINE)
	sweep.tween_callback(_shadow.queue_free)


## 4. The card, and the day.
func _day_card() -> void:
	_phase = "card"
	_bubble.visible = false
	_plate.visible = false
	if _tag != null:
		_tag.visible = false
	if _flow != null:
		_flow.kill()
	var card: Dictionary = Prologue.data()["dayCard"]
	_card = VBoxContainer.new()
	_card.alignment = BoxContainer.ALIGNMENT_CENTER
	_card.position = Vector2(0, 250)
	_card.size = Vector2(1280, 160)
	var title := UiStyle.heading(String(card["title"]), 54, UiStyle.CREAM)
	title.add_theme_font_override("font", UiStyle.logo_font())
	title.add_theme_font_size_override("font_size", UiStyle.LOGO_PX * 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(title)
	var day := UiStyle.heading(String(card["subtitle"]), 27, UiStyle.GOLD)
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(day)
	_card.modulate.a = 0.0
	add_child(_card)
	_flow = create_tween()
	_flow.tween_property(_card, "modulate:a", 1.0, 0.6)
	_flow.tween_interval(1.8)
	_flow.tween_property(_card, "modulate:a", 0.0, 0.6)
	_flow.tween_callback(close)


## The harness's way in (`--dawn-beat N`): the fires out, everyone in
## place, beat N said (past the last, the card).
func jump_to(beat: int) -> void:
	if _flow != null:
		_flow.kill()
	for i in world.view.fires.size():
		world.view.douse(i, 0.01)
	_black.color.a = 0.0
	_place_everyone()
	_phase = "talk"
	_index = beat - 1
	_next()


func _process(delta: float) -> void:
	# The speaker's bubble rides above their head as the camera settles.
	if _bubble.visible and is_instance_valid(_speaker):
		var head: Vector2 = world.get_viewport().get_canvas_transform() * (_speaker.global_position + Vector2(0, -26))
		_bubble.position = (head - offset - Vector2(_bubble.size.x / 2.0, _bubble.size.y)).round()
		_bubble.position.x = clampf(_bubble.position.x, 16, 1264 - _bubble.size.x)
	if _shake_left > 0.0:
		_shake_left -= delta
		world.camera_rig.camera.offset = Vector2(randf_range(-3, 3), randf_range(-3, 3)) if _shake_left > 0.0 else Vector2.ZERO


func _command(event: InputEvent) -> Callable:
	if _phase == "talk" and (event.is_action_pressed("interact") or event.is_action_pressed("attack")):
		return _next
	return Callable()


## Esc, or the card done: the day begins (on_done loads it).
func close() -> void:
	if _flow != null:
		_flow.kill()
	world.camera_rig.camera.offset = Vector2.ZERO
	world.camera_rig.camera.process_mode = Node.PROCESS_MODE_INHERIT
	world.camera_rig.follows = true
	if is_instance_valid(world.view.props):
		world.view.props.process_mode = Node.PROCESS_MODE_INHERIT
	if _actors.has("mayor") and is_instance_valid(_actors["mayor"]):
		_actors["mayor"].queue_free()
	world.camera_rig.cut()
	super.close()
	if on_done.is_valid():
		on_done.call()
