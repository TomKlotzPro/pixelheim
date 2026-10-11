class_name Cutscene
extends Screen
## A story moment (PIX-31): a scene from assets/data/story.json played as
## ordered steps over a letterboxed stage, so writing one is editing data.
## Steps that hold the scene (a caption, a fade, the logo, a wait) play in
## turn; the rest (a tint, falling ash, a shake, an actor crossing, a story
## theme starting) start and run alongside. E, Space or Enter moves on to the next line; Esc skips to
## the end. With Reduce motion nothing moves or shakes and fades are cuts,
## but every line still holds long enough to read.

const VIEW := Vector2(1280, 720)
## The letterbox: black bars top and bottom; the captions read in the lower.
const BAR := 76
## Seconds per letter as a caption types itself out.
const TYPE_S := 0.035
## What a step can be.
const KINDS := ["stage", "fade", "caption", "card", "tint", "ash", "shake", "actor", "eyes", "logo", "credits", "wait", "theme"]
## The stages a scene can set: a painted backdrop, or the world itself
## (PIX-253 step 9: the square at dawn after the Night of Bells, held still
## under the letterbox), where an actor stands on a cell (`cell`) and
## crosses to one (`to_cell`) at the world's own scale.
const STAGES := ["village", "path", "lair", "dark", "world"]

## Which scene to play, and what to do after (skipped or not).
var scene_id := "opening"
var on_done: Callable
var steps: Array = []
var still := false
var finished := false
var advance := false
var shaker: Control
var stage: Control
var actors: Node2D
var tint: ColorRect
var ash: CPUParticles2D
var caption: Label
var front: Control
var black: ColorRect
## The actors on stage that a scene named (`name`), so a later step can
## move them on or change what they do.
var cast := {}


## Every scene, by id: its steps (see KINDS).
static func scenes() -> Dictionary:
	return _story()["scenes"]


## The scene a moment of play calls for ("boss:dragon", "cleared:10",
## "victory"), or "" (PIX-32).
static func moment(key: String) -> String:
	return String(_story()["moments"].get(key, ""))


## The story's words in the player's language (PIX-208): translated as they
## load, so a title card upper-cases and a caption names the hero after.
static func _story() -> Dictionary:
	return Text.localize(SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/story.json")))


func _open() -> void:
	layer = 9
	still = GameState.settings.reduce_motion
	steps = scenes().get(scene_id, [])
	shaker = Control.new()
	shaker.size = VIEW
	shaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shaker)
	stage = Control.new()
	stage.size = VIEW
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shaker.add_child(stage)
	actors = Node2D.new()
	shaker.add_child(actors)
	tint = _sheet(Color(0, 0, 0, 0))
	add_child(tint)
	ash = _ash()
	add_child(ash)
	for top in [true, false]:
		var bar := _sheet(Color("050308"))
		bar.size = Vector2(VIEW.x, BAR)
		bar.position.y = 0 if top else VIEW.y - BAR
		add_child(bar)
	caption = UiStyle.label("", UiStyle.reading(18), UiStyle.CREAM, Vector2(90, VIEW.y - BAR + 26))
	caption.custom_minimum_size = Vector2(VIEW.x - 180, 0)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	var skip := UiStyle.hints(["{key:interact}", "next", "Esc", "skip"], true)
	skip.position = Vector2(VIEW.x - 280, 22)
	add_child(skip)
	front = Control.new()
	front.size = VIEW
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(front)
	black = _sheet(Color.BLACK)
	add_child(black)
	_play.call_deferred()


func _sheet(color: Color) -> ColorRect:
	var sheet := ColorRect.new()
	sheet.color = color
	sheet.size = VIEW
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return sheet


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		return finish
	for action: String in ["interact", "ui_accept", "attack"]:
		if event.is_action_pressed(action):
			return func() -> void: advance = true
	return Callable()


## Esc belongs to skipping (finish), not to closing without what comes next.
func _closes_on(_event: InputEvent) -> bool:
	return false


func _play() -> void:
	for step: Dictionary in steps:
		if finished:
			return
		await _run(step)
	finish()


## Ends the scene (played out or skipped), then whatever comes next.
func finish() -> void:
	if finished:
		return
	finished = true
	close()
	if on_done.is_valid():
		on_done.call()


func _run(step: Dictionary) -> void:
	match String(step["kind"]):
		"stage":
			_stage(step["stage"])
		"fade":
			await _fade(1.0 if step["to"] == "black" else 0.0, float(step.get("seconds", 0.6)))
		"caption":
			await _caption(String(step["text"]).replace("{hero}", GameState.hero.hero_name), float(step.get("hold", 3.0)))
		"card":
			_card(step["text"], String(step.get("sub", "")))
		"credits":
			await _credits(step)
		"tint":
			var color := Color(step["color"])
			color.a = float(step.get("alpha", 0.3))
			if still:
				tint.color = color
			else:
				create_tween().tween_property(tint, "color", color, float(step.get("seconds", 1.0))).from(Color(color, 0.0))
		"ash":
			ash.emitting = true
			ash.visible = true
		"shake":
			_shake(float(step.get("strength", 5)), float(step.get("seconds", 1.0)))
		"actor":
			_actor(step)
		"eyes":
			_eyes(step)
		"logo":
			await _logo(float(step.get("hold", 2.0)))
		"wait":
			await _linger(float(step.get("seconds", 1.0)))
		"theme":
			# A story theme (PIX-158), once through, then `then` if named.
			Sound.play_theme(step["name"], String(step.get("then", "")))


## Waits `seconds`, or less when the player moves on (or skips).
func _linger(seconds: float) -> void:
	advance = false
	var left := seconds
	while left > 0.0 and not advance and not finished:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _fade(alpha: float, seconds: float) -> void:
	if still or seconds <= 0.0:
		black.color.a = alpha
		return
	var fade := create_tween()
	fade.tween_property(black, "color:a", alpha, seconds)
	await fade.finished


## A line typing itself into the lower bar, then held while it's read.
func _caption(text: String, hold: float) -> void:
	caption.text = text
	# A long line (the large type above all, PIX-160) wraps and rises from
	# the bottom edge.
	caption.size = Vector2(VIEW.x - 180, 0)
	caption.position.y = VIEW.y - 14 - caption.get_minimum_size().y
	caption.visible_ratio = 1.0 if still else 0.0
	var typing: Tween
	if not still:
		typing = create_tween()
		typing.tween_property(caption, "visible_ratio", 1.0, text.length() * TYPE_S)
	await _linger(hold)
	if typing != null:
		typing.kill()
	caption.visible_ratio = 1.0


## A new backdrop: what was on stage goes, with its actors, tint and ash.
func _stage(name: String) -> void:
	for node: Node in stage.get_children() + actors.get_children():
		node.queue_free()
	cast.clear()
	tint.color = Color(0, 0, 0, 0)
	ash.emitting = false
	ash.visible = false
	caption.text = ""
	match name:
		"village":
			var village := TitleScene.new()
			village.dragon_rounds = false
			stage.add_child(village)
		"path":
			stage.add_child(_path())
		"lair":
			stage.add_child(_lair())
		"world":
			# Nothing drawn: the world shows through, held where it stands.
			pass
		_:
			stage.add_child(_sheet(Color("07060c")))


## The mountain path at night: a dark slope, the road up it, dead pines.
func _path() -> Control:
	var root := Control.new()
	root.size = VIEW
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky := Gradient.new()
	sky.set_color(0, Color("07060f"))
	sky.set_color(1, Color("2a1a32"))
	var fill := GradientTexture2D.new()
	fill.gradient = sky
	fill.fill_to = Vector2(0, 1)
	var back := TextureRect.new()
	back.texture = fill
	back.size = VIEW
	root.add_child(back)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var star := ColorRect.new()
		star.size = Vector2.ONE * (2 if rng.randf() < 0.8 else 4)
		star.position = Vector2(rng.randf_range(0, VIEW.x), rng.randf_range(BAR, 300))
		star.color = Color(1, 0.95, 0.85, rng.randf_range(0.25, 0.8))
		root.add_child(star)
	# Fafnyr's fire on the peak the road climbs to.
	var fire := Sprite2D.new()
	fire.texture = TitleScene.glow_texture(90, Color("ff5a20"), 0.45, 6)
	fire.material = TitleScene.additive()
	fire.position = Vector2(520, 246)
	root.add_child(fire)
	var slope := Polygon2D.new()
	slope.polygon = PackedVector2Array([Vector2(0, 470), Vector2(380, 300), Vector2(520, 240), Vector2(760, 330), Vector2(1280, 420), Vector2(1280, 720), Vector2(0, 720)])
	slope.color = Color("0d0a18")
	root.add_child(slope)
	var ground := TileMapLayer.new()
	ground.tile_set = PunyTerrain.tileset()
	ground.scale = Vector2(3, 3)
	ground.position = Vector2(0, 480)
	ground.modulate = Color(0.32, 0.3, 0.5)
	for x in 28:
		for y in 5:
			var tile: int = [1, 2, 28, 29][absi(x * 7 + y * 3) % 4]
			if y == 1:
				tile = 5
			elif y in [2, 3]:
				tile = [13, 14][absi(x + y) % 2]
			PunyTerrain.place(ground, Vector2i(x, y), tile)
	root.add_child(ground)
	for x in [60, 240, 1080, 1210]:
		var pine := Sprite2D.new()
		var region := AtlasTexture.new()
		region.atlas = load(PunyTerrain.SHEET)
		region.region = PunyTerrain.region(197)
		pine.texture = region
		pine.scale = Vector2(3, 3)
		pine.position = Vector2(x, 470)
		pine.modulate = Color(0.12, 0.1, 0.2)
		root.add_child(pine)
	return root


## A boss's lair: black going to embers at the floor, sparks rising.
func _lair() -> Control:
	var root := Control.new()
	root.size = VIEW
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var heat := Gradient.new()
	heat.set_color(0, Color("050204"))
	heat.set_color(1, Color("4a1206"))
	var fill := GradientTexture2D.new()
	fill.gradient = heat
	fill.fill_to = Vector2(0, 1)
	var back := TextureRect.new()
	back.texture = fill
	back.size = VIEW
	root.add_child(back)
	var glow := Sprite2D.new()
	glow.texture = TitleScene.glow_texture(220, Color("ff5a20"), 0.35, 6)
	glow.material = TitleScene.additive()
	glow.position = Vector2(VIEW.x / 2, VIEW.y - 60)
	root.add_child(glow)
	var sparks := CPUParticles2D.new()
	sparks.position = Vector2(VIEW.x / 2, VIEW.y - BAR)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparks.emission_rect_extents = Vector2(VIEW.x / 2, 4)
	sparks.amount = 40
	sparks.lifetime = 4.0
	sparks.preprocess = 4.0
	sparks.direction = Vector2.UP
	sparks.spread = 25.0
	sparks.gravity = Vector2(0, -12)
	sparks.initial_velocity_min = 30.0
	sparks.initial_velocity_max = 70.0
	sparks.scale_amount_min = 2.0
	sparks.scale_amount_max = 3.0
	sparks.color = Color("ff9a40")
	sparks.material = TitleScene.additive()
	if still:
		sparks.speed_scale = 0.0
	root.add_child(sparks)
	return root


## A name to remember, in the logo's capitals over the scene, a line beneath.
func _card(text: String, sub: String) -> void:
	var card := VBoxContainer.new()
	card.position = Vector2(0, BAR + 40)
	card.custom_minimum_size = Vector2(VIEW.x, 0)
	card.add_theme_constant_override("separation", 14)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name := Label.new()
	name.text = text.to_upper()
	name.add_theme_font_override("font", UiStyle.logo_font())
	name.add_theme_font_size_override("font_size", 32)
	name.add_theme_color_override("font_color", UiStyle.GOLD)
	name.add_theme_color_override("font_outline_color", Color("140a03"))
	name.add_theme_constant_override("outline_size", 10)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(name)
	if sub != "":
		var line := UiStyle.label(sub, 18, UiStyle.CREAM)
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(line)
	actors.add_child(card)
	if not still:
		card.modulate.a = 0.0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.5)


## The roll: lines, then the cast (every creature of the bestiary in its
## own sprite and name), then more lines, rising over `seconds`.
func _credits(step: Dictionary) -> void:
	var roll := VBoxContainer.new()
	roll.custom_minimum_size = Vector2(VIEW.x, 0)
	roll.add_theme_constant_override("separation", 18)
	roll.position = Vector2(0, VIEW.y - BAR)
	for line: String in step.get("before", []):
		roll.add_child(_credit_line(line))
	for monster_id: String in Bestiary._data()["monsters"]:
		roll.add_child(_cast_member(monster_id))
	for line: String in step.get("after", []):
		roll.add_child(_credit_line(line))
	front.add_child(roll)
	var seconds := float(step.get("seconds", 30.0))
	if still:
		# Page by page instead of a crawl.
		roll.position.y = BAR + 20
	else:
		var crawl := roll.create_tween()
		crawl.tween_property(roll, "position:y", float(BAR) - roll.get_combined_minimum_size().y, seconds)
	await _linger(seconds)


func _credit_line(text: String) -> Label:
	var line := UiStyle.heading(text, 18 if text == "PIXELHEIM" else 16, UiStyle.GOLD if text == "PIXELHEIM" else UiStyle.CREAM)
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.custom_minimum_size = Vector2(VIEW.x, 24)
	return line


## One of the cast: the creature walking in place, its name beside it.
func _cast_member(monster_id: String) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	var spec := PunyArt.monster(monster_id)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(64, 64)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(spec)
	sprite.play(PunyArt.pick(sprite.sprite_frames, "walk", "down"))
	sprite.scale = Vector2.ONE * 2.0 * float(spec.get("scale", 1.0)) * (32.0 / PunyArt.frame_size(spec) if PunyArt.frame_size(spec) < 32 else 1.0)
	sprite.self_modulate = spec.get("tint", Color.WHITE)
	sprite.position = Vector2(32, 36)
	holder.add_child(sprite)
	row.add_child(holder)
	var name := UiStyle.label(String(Bestiary._data()["monsters"][monster_id]["name"]), 18, UiStyle.CREAM)
	name.custom_minimum_size = Vector2(320, 0)
	row.add_child(name)
	return row


## One of Shade's sprites on stage: still at `at` (its last frame with
## `last`, a fallen hero), or crossing from `from` to `to`. On the world's
## stage it stands on a world cell (`cell`) at the world's scale, and may
## cross to another (`to_cell`). A step naming an actor (`name`) already
## on stage moves it on (`to`, `to_cell`) or changes what it does (`anim`,
## `dir`) instead: Fafnyr, lying on the square, takes off. `tint` colours
## it (Morvax beside Maren: Shade drew one old man).
func _actor(step: Dictionary) -> void:
	var named := String(step.get("name", ""))
	if named != "" and cast.has(named) and is_instance_valid(cast[named]):
		_direct(cast[named], step)
		return
	var on_cell := step.has("cell")
	var moving := step.has("to") or step.has("to_cell")
	if moving and still and not on_cell:
		return
	var spec := {"sheet": step["sheet"], "family": step["family"]}
	if step.has("frame"):
		spec["frame"] = int(step["frame"])
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(spec)
	sprite.set_meta("spec", spec)
	sprite.set_meta("art_scale", float(step.get("scale", 1.0 if on_cell else 3.0)))
	sprite.scale = Vector2.ONE * float(sprite.get_meta("art_scale")) * (world_zoom() if on_cell else 1.0)
	_animate(sprite, step)
	if step.get("silhouette", false):
		sprite.modulate = Color(0.04, 0.02, 0.06)
	if step.has("tint"):
		sprite.self_modulate = Color(step["tint"])
	if on_cell:
		sprite.position = _on_screen(sprite, step["cell"])
		# In the world's light, as the folk around it are.
		sprite.modulate *= _world_light()
	else:
		var points: Array = step["from"] if moving else step["at"]
		sprite.position = Vector2(points[0], points[1])
	actors.add_child(sprite)
	if named != "":
		cast[named] = sprite
	if moving:
		_move(sprite, step)


## A named actor's next step: what it does now, and where it goes.
func _direct(sprite: AnimatedSprite2D, step: Dictionary) -> void:
	if step.has("anim") or step.has("dir"):
		_animate(sprite, step)
	if step.has("to") or step.has("to_cell"):
		_move(sprite, step)


func _animate(sprite: AnimatedSprite2D, step: Dictionary) -> void:
	var anim := PunyArt.pick(sprite.sprite_frames, step.get("anim", "idle"), step.get("dir", "down"))
	if step.get("last", false):
		sprite.animation = anim
		sprite.frame = sprite.sprite_frames.get_frame_count(anim) - 1
	else:
		sprite.play(anim)


## Crosses to `to` (the screen's pixels) or `to_cell` (the world's) over
## `seconds`; with Reduce motion it is simply there.
func _move(sprite: AnimatedSprite2D, step: Dictionary) -> void:
	var goal: Vector2
	if step.has("to_cell"):
		goal = _on_screen(sprite, step["to_cell"])
	else:
		var to: Array = step["to"]
		goal = Vector2(to[0], to[1])
	if still:
		sprite.position = goal
		return
	# Its own tween, gone with it when the stage changes mid-crossing.
	sprite.create_tween().tween_property(sprite, "position", goal, float(step.get("seconds", 4.0)))


## The light the world stands in now (the LightRig's darkness), white
## where there is none.
func _world_light() -> Color:
	var shade := get_tree().get_first_node_in_group(&"world_light") as CanvasModulate
	return shade.color if shade != null else Color.WHITE


## How many screen pixels the world draws an art pixel at: the camera's zoom.
func world_zoom() -> float:
	return get_viewport().get_canvas_transform().get_scale().x


## Where a world cell is on the screen, for an actor standing on it as the
## world stands its folk: its feet on the cell, lifted as PunyArt lifts it.
func _on_screen(sprite: AnimatedSprite2D, at: Array) -> Vector2:
	var feet := MapView.center(Vector2i(int(at[0]), int(at[1])))
	feet.y += PunyArt.lift(sprite.get_meta("spec")) * float(sprite.get_meta("art_scale"))
	return get_viewport().get_canvas_transform() * feet


## Two eyes in the dark, breathing light.
func _eyes(step: Dictionary) -> void:
	var at: Array = step["at"]
	var color := Color(step.get("color", "#b46cff"))
	var haze := Sprite2D.new()
	haze.texture = TitleScene.glow_texture(110, color, 0.12, 5)
	haze.material = TitleScene.additive()
	haze.position = Vector2(at[0], at[1])
	actors.add_child(haze)
	for side in [-1, 1]:
		var eye := Sprite2D.new()
		eye.texture = TitleScene.glow_texture(14, color, 1.0, 4)
		eye.material = TitleScene.additive()
		eye.position = Vector2(at[0] + side * 22, at[1])
		actors.add_child(eye)
		if not still:
			# Bound to the eye: a looping tween that outlives what it animates
			# spins forever in a release build (the web froze here).
			var breathe := eye.create_tween().set_loops()
			breathe.tween_property(eye, "modulate:a", 0.35, 1.2).from(1.0)
			breathe.tween_property(eye, "modulate:a", 1.0, 1.2)


func _shake(strength: float, seconds: float) -> void:
	if still:
		return
	var shake := create_tween()
	var steps_count := maxi(1, int(seconds / 0.05))
	for i in steps_count:
		var fade := 1.0 - float(i) / steps_count
		shake.tween_property(shaker, "position", Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade, 0.05)
	shake.tween_property(shaker, "position", Vector2.ZERO, 0.05)


## Ash falling over everything once the mountain wakes.
func _ash() -> CPUParticles2D:
	var flakes := CPUParticles2D.new()
	flakes.position = Vector2(VIEW.x / 2, -10)
	flakes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	flakes.emission_rect_extents = Vector2(VIEW.x / 2, 4)
	flakes.amount = 70
	flakes.lifetime = 7.0
	flakes.preprocess = 7.0
	flakes.direction = Vector2(-0.3, 1)
	flakes.spread = 20.0
	flakes.gravity = Vector2(-6, 18)
	flakes.initial_velocity_min = 20.0
	flakes.initial_velocity_max = 50.0
	flakes.scale_amount_min = 2.0
	flakes.scale_amount_max = 4.0
	flakes.color = Color(0.72, 0.68, 0.7, 0.75)
	flakes.emitting = false
	flakes.visible = false
	if GameState.settings.reduce_motion:
		flakes.speed_scale = 0.0
	return flakes


## PIXELHEIM slammed onto the dark with a flash.
func _logo(hold: float) -> void:
	var word := Label.new()
	word.text = "PIXELHEIM"
	word.add_theme_font_override("font", UiStyle.logo_font())
	word.add_theme_font_size_override("font_size", 64)
	word.add_theme_color_override("font_color", UiStyle.GOLD)
	word.add_theme_color_override("font_outline_color", Color("140a03"))
	word.add_theme_constant_override("outline_size", 14)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.size = Vector2(VIEW.x, 80)
	word.position = Vector2(0, VIEW.y / 2 - 50)
	word.pivot_offset = word.size / 2
	front.add_child(word)
	if not still:
		var flash := _sheet(Color(1, 0.95, 0.85, 0.85))
		front.add_child(flash)
		create_tween().tween_property(flash, "color:a", 0.0, 0.45)
		word.scale = Vector2(2.4, 2.4)
		create_tween().tween_property(word, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_shake(8, 0.4)
	await _linger(hold)
