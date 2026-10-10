extends Screen
## The ascension (RankUpOverlay.tsx, useRankUp; PIX-244 made it a moment).
## Tom asked for « une meilleure animation quand on passe d'une classe
## au-dessus ». Beat by beat (BEATS):
## - hush: the world falls dark behind letterbox bars; the hero stands in
##   the old rank's look, on its pool of light;
## - lift: a shaft of the class's light falls on them, a halo opens behind
##   them, motes of light rise, and they are lifted off the ground;
## - change: the old look flashes white and burns away pixel by pixel into
##   the new one (RankLook: the trim, the rim of light...), which comes out
##   of the white; sparks fly and the pool takes the new rank's colour;
## - named: the new rank's name;
## - unlocks: what it brings - the bonus skill point, the level's stats, a
##   step on the path (its cards, at a fork in the Path Graph), the new look;
## - settled: the hero comes back down to the ground and the light softens.
## The stage is drawn at 6x in the art's whole pixels: the light's bands,
## the motes and sparks are its pixels, and the glow pass (bloom) makes the
## light glow. At a fork the cards hold the scene until a walk is chosen (or
## put off to the skill tree); otherwise it passes a few seconds after it
## settles. E before the cards skips to them. The world holds still
## meanwhile. With Reduce motion the moment holds still: the light stands at
## once, nothing flies or rises, the old look cross-fades into the new, and
## the words simply appear.

## The beats, [name, seconds from the open], in order; with Reduce motion,
## STILL_BEATS (the light already standing, the change a cross-fade).
const BEATS := [["hush", 0.0], ["lift", 0.35], ["change", 1.35], ["named", 2.15], ["unlocks", 2.6], ["settled", 3.4]]
const STILL_BEATS := [["hush", 0.0], ["lift", 0.0], ["change", 0.45], ["named", 1.1], ["unlocks", 1.4], ["settled", 1.7]]
## The moment passes this long after it settles, unless a fork holds it.
const HOLD_AFTER := 2.8
## After a walk is taken at the fork with nothing further to choose.
const HOLD_WALKED := 2.0
const BAR := 92.0
## The stage: where the hero's feet stand on the screen and its size (one
## unit of the stage is one of the art's pixels).
const STAGE_AT := Vector2(640, 236)
const SCALE := 6.0
## The lift: how high (art px) and how long it takes.
const LIFT_PX := 4.0
const LIFT_SECONDS := 0.9
## The change: the old look's white burning away, and Reduce motion's
## cross-fade.
const BURN_SECONDS := 0.65
const FADE_SECONDS := 0.6
## The landing, as the moment settles.
const LAND_SECONDS := 0.4
## How strongly the glow pass blooms the stage's light.
const BLOOM := 0.85
## How dark the world falls behind the moment.
const HUSH := 0.86
## How bright the light stands at its height, and once the moment settles.
const BEAM_ALPHA := 0.8
const BEAM_SETTLED := 0.4

var title := ""
var choices: Array = []
var selected := 0
var closing := false
## Where the moment is (a name from BEATS; "" before it starts): the
## harness reports it and holds the scene on one.
var phase := ""
## The rank reached (HeroRules.rank_index) and the looks either side of it.
var rank := 0
var old_look := {}
var new_look := {}
## Reduce motion, as the moment opened.
var still := false

var rays: Node2D
var shade: ColorRect
## The hero's ground, at SCALE: the pool, the shaft of light, the motes.
var stage: Node2D
## What's lifted: the halo, the two looks and the sparks.
var figure: Node2D
var old_hero: AnimatedSprite2D
var new_hero: AnimatedSprite2D
var pool: Sprite2D
var beam: Sprite2D
var halo: Sprite2D
## The motes rising in the light and the sparks of the change (none with
## Reduce motion).
var motes: CPUParticles2D
var sparks: CPUParticles2D
var name_card: VBoxContainer
var unlocks: VBoxContainer
var cards: HBoxContainer
var note: Label
var _bars: Array[ColorRect] = []
var _timeline: Tween
var _offered := false
## The beat the moment stops at (`hold_at`), "" to play through.
var _hold_beat := ""


## Its own entrance, not the screens' ease (PIX-212).
func _eases_in() -> bool:
	return false


## The beats for the moment, with or without motion.
static func beats(reduced: bool) -> Array:
	return STILL_BEATS if reduced else BEATS


## When `beat` comes, in seconds from the open (-1 if there is none).
static func beat_at(beat: String, reduced: bool) -> float:
	for entry: Array in beats(reduced):
		if entry[0] == beat:
			return float(entry[1])
	return -1.0


func _open() -> void:
	layer = 6
	still = GameState.settings.reduce_motion
	var hero := GameState.hero
	rank = HeroRules.rank_index(hero.level)
	old_look = RankLook.spec(hero.role_id, rank - 1)
	new_look = RankLook.spec(hero.role_id, rank)
	choices = Ranks.path_choices(hero)
	var view := Vector2(1280, 720)
	var light: Color = new_look["light"]
	shade = ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.04, _hush_alpha() if still else 0.0)
	shade.position = -offset
	shade.size = Touch.view_size(self)
	add_child(shade)

	rays = Node2D.new()
	rays.position = STAGE_AT + Vector2(0, -12 * SCALE)
	for i in 12:
		var ray := Polygon2D.new()
		ray.polygon = PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(0, -620)])
		ray.color = Color(light, 0.05)
		ray.rotation = TAU * i / 12.0
		rays.add_child(ray)
	add_child(rays)
	_build_stage(light)
	if not still:
		# Out of the dark with the hush.
		stage.modulate.a = 0.0
		rays.modulate.a = 0.0
	if GameState.settings.glow:
		_bloom()

	name_card = VBoxContainer.new()
	name_card.position = Vector2(0, 274)
	name_card.custom_minimum_size = Vector2(view.x, 0)
	name_card.add_theme_constant_override("separation", 2)
	name_card.visible = false
	add_child(name_card)
	name_card.add_child(_line(Text.t("Ascension: rank %d of %d") % [rank + 1, RankLook.STEPS.size()], UiStyle.CREAM))
	name_card.add_child(_line(title, UiStyle.GOLD, true))

	unlocks = VBoxContainer.new()
	unlocks.position = Vector2(0, 342)
	unlocks.custom_minimum_size = Vector2(view.x, 0)
	unlocks.add_theme_constant_override("separation", 2)
	unlocks.visible = false
	add_child(unlocks)
	for entry: Array in brings(hero):
		unlocks.add_child(_line(entry[0], entry[1]))

	cards = HBoxContainer.new()
	cards.position = Vector2(0, 446)
	cards.custom_minimum_size = Vector2(view.x, 0)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	add_child(cards)
	# Letterbox bars over everything, sliding in (standing at once with
	# Reduce motion).
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(view.x, BAR if still else 0.0)
		bar.position = Vector2(0, 0.0 if top else (view.y - BAR if still else view.y))
		add_child(bar)
		_bars.append(bar)
	# The fork's keys ride in the lower bar.
	note = UiStyle.label("", 14, UiStyle.DUSK, Vector2(0, view.y - BAR / 2 - 10))
	note.custom_minimum_size = Vector2(view.x, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)
	_play()


## What the new rank brings, as [line, colour] rows: the bonus skill point
## (what it's truly for, PIX-217), the level's stats, a step on the path when
## one is on offer, and the new look.
func brings(hero: HeroState) -> Array:
	var rows: Array = []
	var bonus := Text.t("+1 bonus skill point")
	if Skills.all_learned(hero):
		bonus = Text.t("Every skill mastered: the bonus point rests")
	elif Skills.tree_whole(hero):
		bonus = Text.t("+1 bonus skill point, to spend beyond the tree (Stats)")
	rows.append([bonus, UiStyle.GOLD])
	var growth: Dictionary = Catalog.role(hero.role_id)["growth"]
	rows.append([Text.t("Level %d: +%d stat points, +%d max HP, +%d max %s") % [
		hero.level, int(Bestiary._data()["statPointsPerLevel"]), int(growth["maxHp"]), int(growth["maxMp"]),
		Skills.resource_label(hero.role_id),
	], UiStyle.CREAM])
	if not choices.is_empty():
		rows.append([Text.t("A new step on your path: choose it below"), UiStyle.CREAM])
	var look_line := RankLook.line(rank)
	if look_line != "":
		rows.append([look_line, (new_look["light"] as Color).lerp(UiStyle.CREAM, 0.35)])
	return rows


## A line of the card, centred and outlined against the dark.
func _line(text: String, color: Color, big := false) -> Label:
	var label := UiStyle.heading(text, 30, color) if big else UiStyle.label(text, 15, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(1280, 0)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.06))
	label.add_theme_constant_override("outline_size", 6)
	return label


## The hero's ground at SCALE, in the art's pixels: the pool of light under
## the feet, the shaft falling on them, the motes rising in it; over it the
## figure that is lifted: the halo behind, the new look behind the old one,
## and the sparks the change throws.
func _build_stage(light: Color) -> void:
	stage = Node2D.new()
	stage.position = STAGE_AT
	stage.scale = Vector2.ONE * SCALE
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(stage)
	pool = Sprite2D.new()
	pool.texture = preload("res://scripts/player.gd")._glow()
	pool.position = Vector2(0, 5)
	# A little narrower than the world's, so the name below reads clear of it.
	pool.scale = Vector2.ONE * 0.7
	pool.modulate = _pool_color(old_look)
	stage.add_child(pool)
	beam = Sprite2D.new()
	beam.texture = RankLook.beam()
	beam.material = Lights.glow()
	# Its foot on the ground the hero stands on.
	beam.position = Vector2(0, 3 - RankLook.beam().get_height() / 2.0)
	beam.modulate = Color(light, BEAM_SETTLED if still else 0.0)
	stage.add_child(beam)
	if not still:
		motes = CPUParticles2D.new()
		motes.amount = 22
		motes.lifetime = 1.8
		motes.emitting = false
		motes.local_coords = true
		motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		motes.emission_rect_extents = Vector2(10, 2)
		motes.position = Vector2(0, 2)
		motes.direction = Vector2.UP
		motes.spread = 12.0
		motes.initial_velocity_min = 6.0
		motes.initial_velocity_max = 14.0
		motes.gravity = Vector2(0, -3)
		motes.color_ramp = Motes.fading(Color(light, 0.95))
		motes.material = Lights.glow()
		stage.add_child(motes)
	figure = Node2D.new()
	# The figure's origin at its feet, so the landing squashes onto them.
	figure.position = Vector2(0, 3)
	stage.add_child(figure)
	halo = Sprite2D.new()
	halo.texture = RankLook.halo()
	halo.material = Lights.glow()
	halo.position = Vector2(0, -8)
	halo.modulate = Color(light, 0.45 if still else 0.0)
	figure.add_child(halo)
	new_hero = _hero(new_look)
	old_hero = _hero(old_look)
	if still:
		new_hero.modulate.a = 0.0
	else:
		new_hero.visible = false
		sparks = Motes.burst(28, 0.8, 180.0, Vector2(26, 52), Vector2(0, 24))
		sparks.emission_sphere_radius = 4.0
		sparks.damping_min = 30.0
		sparks.damping_max = 60.0
		sparks.local_coords = true
		var ramp := Gradient.new()
		ramp.set_color(0, Color.WHITE)
		ramp.set_color(1, Color(light, 0.0))
		ramp.add_point(0.3, Color(light, 1.0))
		sparks.color_ramp = ramp
		sparks.material = Lights.glow()
		sparks.position = Vector2(0, -8)
		figure.add_child(sparks)


## The hero as drawn now (plain clothes and gear), wearing `look`, facing
## down; held on one frame with Reduce motion.
func _hero(look: Dictionary) -> AnimatedSprite2D:
	var art := GameState.upkeep.hero_art()
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.self_modulate = art["tint"]
	sprite.position = Vector2(0, PunyArt.lift(art) - 3)
	sprite.material = Juice.fighter_material()
	figure.add_child(sprite)
	RankLook.wear(sprite, look)
	sprite.animation = PunyArt.pick(sprite.sprite_frames, "idle", "down")
	if not still:
		sprite.play()
	return sprite


static func _pool_color(look: Dictionary) -> Color:
	var aura: Color = look["aura"]
	return Color(aura, 0.5) if aura.a > 0.0 else Color(1, 1, 1, 0.12)


## The glow pass (PIX-222) on the moment's own layer: over the stage, under
## the words, so the light blooms and the names stay crisp.
func _bloom() -> void:
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	var glow := ColorRect.new()
	glow.position = -offset
	glow.size = Touch.view_size(self)
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/bloom.gdshader")
	material.set_shader_parameter("strength", BLOOM)
	glow.material = material
	add_child(glow)


## The moment's timeline: each beat on its time.
func _play() -> void:
	_timeline = create_tween()
	var at := 0.0
	for entry: Array in beats(still):
		var wait := float(entry[1]) - at
		if wait > 0.0:
			_timeline.tween_interval(wait)
		_timeline.tween_callback(_beat.bind(String(entry[0])))
		at = float(entry[1])


func _beat(beat: String) -> void:
	phase = beat
	if beat == _hold_beat:
		# No later beat comes; this one's own motion plays on.
		_timeline.pause()
	match beat:
		"hush":
			_hush()
		"lift":
			_lift()
		"change":
			_change()
		"named":
			_named()
		"unlocks":
			_unlocks()
		"settled":
			_settle()
			# Without a fork to choose at, the moment passes.
			if choices.is_empty():
				_pass_after(HOLD_AFTER)


## The world falls dark and the bars close in; the hero on their pool, and
## the rays, come up out of the dark (the world's own hero goes under it).
func _hush() -> void:
	if still:
		return
	var dark := create_tween().set_parallel()
	dark.tween_property(shade, "color:a", _hush_alpha(), 0.35)
	dark.tween_property(stage, "modulate:a", 1.0, 0.35)
	dark.tween_property(rays, "modulate:a", 1.0, 0.6)
	var slide := create_tween().set_parallel()
	for bar in _bars:
		slide.tween_property(bar, "size:y", BAR, 0.5)
	slide.tween_property(_bars[1], "position:y", 720 - BAR, 0.5)


## The world's dark behind the moment, as dark on the desktop app's linear
## canvas as in the browser.
static func _hush_alpha() -> float:
	return DesktopLook.veil(HUSH, DesktopLook.linear)


## The shaft of light falls, the halo opens, motes rise and the hero is
## lifted off the ground.
func _lift() -> void:
	if still:
		return
	var light := create_tween().set_parallel()
	light.tween_property(beam, "modulate:a", BEAM_ALPHA, 0.5)
	light.tween_property(halo, "modulate:a", 0.6, 0.7)
	halo.scale = Vector2.ONE * 0.5
	light.tween_property(halo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	light.tween_property(figure, "position:y", 3.0 - LIFT_PX, LIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motes.emitting = true


## The old look gives way to the new: a flash, burnt away pixel by pixel in
## the class's light (or, with Reduce motion, a plain cross-fade).
func _change() -> void:
	Sound.play_ui("ascend")
	var pool_turn := pool.create_tween()
	pool_turn.tween_property(pool, "modulate", _pool_color(new_look), FADE_SECONDS if still else BURN_SECONDS)
	var old_rim := RankLook.rim_of(old_hero)
	if still:
		var fade := create_tween().set_parallel()
		fade.tween_property(old_hero, "modulate:a", 0.0, FADE_SECONDS)
		fade.tween_property(new_hero, "modulate:a", 1.0, FADE_SECONDS)
		return
	new_hero.visible = true
	Juice.flash(new_hero, BURN_SECONDS + 0.2)
	(old_hero.material as ShaderMaterial).set_shader_parameter("flash", 1.0)
	Juice.dissolve(old_hero, new_look["light"], BURN_SECONDS)
	if old_rim != null:
		old_rim.create_tween().tween_property(old_rim, "modulate:a", 0.0, BURN_SECONDS * 0.5)
	sparks.restart()
	var swell := halo.create_tween()
	swell.tween_property(halo, "scale", Vector2.ONE * 1.35, 0.18).set_ease(Tween.EASE_OUT)
	swell.tween_property(halo, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_SINE)


## The new rank's name, popping in (appearing, with Reduce motion).
func _named() -> void:
	name_card.visible = true
	if still:
		return
	name_card.modulate.a = 0.0
	var title_label := name_card.get_child(1) as Label
	title_label.pivot_offset = Vector2(640, 18)
	title_label.scale = Vector2.ONE * 1.6
	var pop := create_tween().set_parallel()
	pop.tween_property(name_card, "modulate:a", 1.0, 0.2)
	pop.tween_property(title_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## What it brings, a line after another; then the fork's cards.
func _unlocks() -> void:
	unlocks.visible = true
	if not still:
		for index in unlocks.get_child_count():
			var line := unlocks.get_child(index) as Control
			line.modulate.a = 0.0
			create_tween().tween_property(line, "modulate:a", 1.0, 0.25).set_delay(index * 0.15)
	_offered = true
	_offer()


## Down to the ground, landing on the feet; the light softens.
func _settle() -> void:
	if still:
		return
	motes.emitting = false
	var down := create_tween()
	down.tween_property(figure, "position:y", 3.0, LAND_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.tween_callback(func() -> void: figure.scale = Juice.LAND)
	down.tween_property(figure, "scale", Vector2.ONE, Juice.SPRING_SECONDS * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var soften := create_tween().set_parallel()
	soften.tween_property(beam, "modulate:a", BEAM_SETTLED, 0.8)
	soften.tween_property(halo, "modulate:a", 0.4, 0.8)


## Stops the moment at `beat` when it comes, its own motion playing on (the
## harness's `--rank-beat`, for a picture of one beat).
func hold_at(beat: String) -> void:
	_hold_beat = beat


## Holds the scene where it stands: tweens, motes and sprites stop.
func hold_still() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED


## The rotating rays, unless motion is reduced.
func _process(delta: float) -> void:
	if not still:
		rays.rotation += delta * 0.25


## The fork's cards, once the moment has reached them.
func _offer() -> void:
	choices = Ranks.path_choices(GameState.hero)
	selected = clampi(selected, 0, maxi(0, choices.size() - 1))
	if not _offered:
		return
	Layout.clear(cards)
	if choices.is_empty():
		note.text = ""
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
	elif not _offered:
		# Before the cards: E skips the show to them.
		if event.is_action_pressed("interact"):
			command = skip
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


## On to the unlocks at once (E during the show).
func skip() -> void:
	# A breath past the beat, so its own callback has run.
	var to := beat_at("unlocks", still) - _timeline.get_total_elapsed_time() + 0.001
	if to > 0.0:
		_timeline.custom_step(to)


func _pick(index: int) -> void:
	selected = wrapi(index, 0, choices.size())
	_offer()


## The walk is taken; a further tier the rank already allows opens at once.
## With nothing further to choose, the moment passes a little after.
func _walk() -> void:
	if GameState.training.choose_path(choices[selected]["id"]):
		Sound.play("learn")
	selected = 0
	_offer()
	if choices.is_empty() and phase == "settled":
		_pass_after(HOLD_WALKED)


## Closes `seconds` from now (on the screen's clock, which `hold_still` stops).
func _pass_after(seconds: float) -> void:
	var after := create_tween()
	after.tween_interval(seconds)
	after.tween_callback(_close)


func _close() -> void:
	if closing:
		return
	closing = true
	close()
