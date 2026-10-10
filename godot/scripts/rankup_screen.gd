extends Screen
## The ascension (RankUpOverlay.tsx, useRankUp; PIX-244 made it a moment).
## Tom asked for « une meilleure animation quand on passe d'une classe
## au-dessus ». The hero looks the same at every rank (Tom found the rank's
## aura ugly: gear is what shows), so the moment is the light, the rank's
## name and what it unlocks. Beat by beat (BEATS):
## - hush: the world falls dark behind letterbox bars; the hero stands in
##   the dark on a faint pool of light;
## - lift: a shaft of the class's light falls on them, a halo opens behind
##   them, motes of light rise, and they are lifted off the ground;
## - flare: the light peaks - the hero flashes white in it and comes back
##   out of the white, sparks fly, the halo swells and the pool under them
##   takes the class's light;
## - named: the new rank's name;
## - unlocks: what it brings - the bonus skill point, the level's stats, a
##   step on the path (its cards, at a fork in the Path Graph);
## - settled: the hero comes back down to the ground and the light softens.
## The stage is drawn at 6x in the art's whole pixels: the light's bands,
## the motes and sparks are its pixels, and the glow pass (bloom) makes the
## light glow. At a fork the cards hold the scene until a walk is chosen (or
## put off to the skill tree); otherwise it passes a few seconds after it
## settles. E before the cards skips to them. The world holds still
## meanwhile. With Reduce motion the moment holds still: the light stands at
## once and brightens, nothing flies, rises or flashes, and the words simply
## appear.

## The beats, [name, seconds from the open], in order; with Reduce motion,
## STILL_BEATS (the light already standing, the flare a brightening).
const BEATS := [["hush", 0.0], ["lift", 0.35], ["flare", 1.35], ["named", 2.15], ["unlocks", 2.6], ["settled", 3.4]]
const STILL_BEATS := [["hush", 0.0], ["lift", 0.0], ["flare", 0.45], ["named", 1.1], ["unlocks", 1.4], ["settled", 1.7]]
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
## The flare: the hero's white fading back to them, and Reduce motion's
## brightening.
const FLARE_SECONDS := 0.65
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
## The halo at its height, and once the moment settles.
const HALO_ALPHA := 0.6
const HALO_SETTLED := 0.4
## The pool under the feet: faint in the dark, then in the class's light.
const POOL_DARK := Color(1, 1, 1, 0.12)
const POOL_LIT := 0.5
## Each class's light - the shaft, the halo, the motes and the sparks of its
## moment: one a class, bright enough to bloom (bloom.gdshader's threshold).
const LIGHTS := {
	"warrior": "ff8a5c",
	"paladin": "ffe07a",
	"rogue": "6dffc8",
	"cleric": "fff4c4",
	"mage": "7cc4ff",
	"necromancer": "c9a2ff",
	"ranger": "bdf06a",
}

var title := ""
var choices: Array = []
var selected := 0
var closing := false
## Where the moment is (a name from BEATS; "" before it starts): the
## harness reports it and holds the scene on one.
var phase := ""
## The rank reached (HeroRules.rank_index) and the class's light.
var rank := 0
var light := Color.WHITE
## Reduce motion, as the moment opened.
var still := false

var rays: Node2D
var shade: ColorRect
## The hero's ground, at SCALE: the pool, the shaft of light, the motes.
var stage: Node2D
## What's lifted: the halo, the hero and the sparks.
var figure: Node2D
var hero_sprite: AnimatedSprite2D
var pool: Sprite2D
var beam: Sprite2D
var halo: Sprite2D
## The motes rising in the light and the sparks of the flare (none with
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

static var _beam: Texture2D
static var _halo: Texture2D


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


## The class's light (LIGHTS; a warrior's for a role without one).
static func light_of(role_id: String) -> Color:
	return Color(String(LIGHTS.get(role_id, LIGHTS["warrior"])))


func _open() -> void:
	layer = 6
	still = GameState.settings.reduce_motion
	var hero := GameState.hero
	rank = HeroRules.rank_index(hero.level)
	light = light_of(hero.role_id)
	choices = Ranks.path_choices(hero)
	var view := Vector2(1280, 720)
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
	_build_stage()
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
	name_card.add_child(_line(Text.t("Ascension: rank %d of %d") % [rank + 1, Ranks.COUNT], UiStyle.CREAM))
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
## (what it's truly for, PIX-217), the level's stats, and a step on the path
## when one is on offer.
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
## figure that is lifted: the halo behind, the hero, and the sparks the
## flare throws.
func _build_stage() -> void:
	stage = Node2D.new()
	stage.position = STAGE_AT
	stage.scale = Vector2.ONE * SCALE
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(stage)
	pool = Sprite2D.new()
	pool.texture = preload("res://scripts/player.gd")._glow()
	pool.position = Vector2(0, 5)
	# Short of its full size, so the name below reads clear of it.
	pool.scale = Vector2.ONE * 0.7
	pool.modulate = POOL_DARK
	stage.add_child(pool)
	beam = Sprite2D.new()
	beam.texture = beam_texture()
	beam.material = Lights.glow()
	# Its foot on the ground the hero stands on.
	beam.position = Vector2(0, 3 - beam_texture().get_height() / 2.0)
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
	halo.texture = halo_texture()
	halo.material = Lights.glow()
	halo.position = Vector2(0, -8)
	halo.modulate = Color(light, HALO_SETTLED if still else 0.0)
	figure.add_child(halo)
	hero_sprite = _hero()
	if not still:
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


## The hero as the world draws them (plain clothes and gear), facing down;
## held on one frame with Reduce motion.
func _hero() -> AnimatedSprite2D:
	var art := GameState.upkeep.hero_art()
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.self_modulate = art["tint"]
	sprite.position = Vector2(0, PunyArt.lift(art) - 3)
	# For the flare's white (Juice.flash).
	sprite.material = Juice.fighter_material()
	figure.add_child(sprite)
	sprite.animation = PunyArt.pick(sprite.sprite_frames, "idle", "down")
	if not still:
		sprite.play()
	return sprite


## A shaft of light falling on the hero: brightest in its middle columns and
## nearest the ground, in steps, not a smooth ramp, so at the stage's size it
## stands in the art's whole pixels.
static func beam_texture() -> Texture2D:
	if _beam == null:
		var size := Vector2i(15, 64)
		var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		var middle := size.x / 2
		for y in size.y:
			# Six steps from faint at the top to full at the feet.
			var down := floorf(float(y) / size.y * 6.0) / 5.0
			for x in size.x:
				var across := absi(x - middle)
				var band := 1.0 if across <= 1 else (0.6 if across <= 3 else (0.32 if across <= 5 else 0.14))
				image.set_pixel(x, y, Color(1, 1, 1, band * lerpf(0.15, 1.0, down)))
		_beam = ImageTexture.create_from_image(image)
	return _beam


## The halo behind the lifted hero: rings of light in steps, a Bayer
## dither between them (the ground's own 2px blocks, PIX-264, at one pixel).
static func halo_texture() -> Texture2D:
	if _halo == null:
		var size := 41
		var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var middle := Vector2(size / 2.0, size / 2.0)
		var bayer := [[0.0, 0.5], [0.75, 0.25]]
		var rings := [[7.0, 0.8], [12.0, 0.5], [16.5, 0.28], [20.5, 0.12]]
		for y in size:
			for x in size:
				var reach := (Vector2(x + 0.5, y + 0.5) - middle).length()
				var alpha := 0.0
				for ring: Array in rings:
					# Within a pixel and a half of the ring's edge, alternate
					# pixels take the next ring's light.
					var edge: float = ring[0]
					if reach < edge - 1.5 or (reach < edge and float(bayer[y % 2][x % 2]) < (edge - reach) / 1.5):
						alpha = ring[1]
						break
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
		_halo = ImageTexture.create_from_image(image)
	return _halo


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
		"flare":
			_flare()
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
	var rise := create_tween().set_parallel()
	rise.tween_property(beam, "modulate:a", BEAM_ALPHA, 0.5)
	rise.tween_property(halo, "modulate:a", HALO_ALPHA, 0.7)
	halo.scale = Vector2.ONE * 0.5
	rise.tween_property(halo, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	rise.tween_property(figure, "position:y", 3.0 - LIFT_PX, LIFT_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	motes.emitting = true


## The light peaks: the hero flashes white in it and comes back out of the
## white, sparks fly, the halo swells and the pool takes the class's light.
## With Reduce motion the light only brightens.
func _flare() -> void:
	Sound.play_ui("ascend")
	var lit := Color(light, POOL_LIT)
	if still:
		var brighten := create_tween().set_parallel()
		brighten.tween_property(pool, "modulate", lit, FADE_SECONDS)
		brighten.tween_property(beam, "modulate:a", BEAM_ALPHA, FADE_SECONDS)
		brighten.tween_property(halo, "modulate:a", HALO_ALPHA, FADE_SECONDS)
		return
	pool.create_tween().tween_property(pool, "modulate", lit, FLARE_SECONDS)
	Juice.flash(hero_sprite, FLARE_SECONDS)
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


## Down to the ground, landing on the feet, and the light softens (with
## Reduce motion it only softens).
func _settle() -> void:
	var soften := create_tween().set_parallel()
	soften.tween_property(beam, "modulate:a", BEAM_SETTLED, 0.8)
	soften.tween_property(halo, "modulate:a", HALO_SETTLED, 0.8)
	if still:
		return
	motes.emitting = false
	var down := create_tween()
	down.tween_property(figure, "position:y", 3.0, LAND_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	down.tween_callback(func() -> void: figure.scale = Juice.LAND)
	down.tween_property(figure, "scale", Vector2.ONE, Juice.SPRING_SECONDS * 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


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
