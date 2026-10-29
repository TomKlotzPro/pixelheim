class_name TitleEntrance
extends Node
## areas: title
## The title's entrance on a launch (PIX-392): down from the stars, the
## dragon's pass, the name forged in fire, the menu last. The camera comes
## down past the moon and the mountain to the village, Fafnyr makes his pass
## close by and breathes on the valley, the mountain wakes and lights it, then
## a flame writes PIXELHEIM in white heat, the name is struck with a flash, a
## shake and a burst of sparks and cools to gold, and the menu's planks rise
## in. About seven seconds, once a launch (not back from the saves), and
## never with Reduce motion; any key, button or click goes straight to the
## settled title.
## What it shows is a function of its time alone (`pose`), so the harness can
## hold it at any moment (`--title-at`) and a skip is its last pose; what
## happens once (the roar, the strike's flash and sparks, the eruption) fires
## as its time passes that moment (`_cross`), never on a skip.

## When each beat begins and ends, in seconds from the launch: the loading
## picture lifts as the camera, among the stars, comes down (DESCENT); the
## dragon passes (DRAGON); the mountain wakes (ERUPT_S) and burns down over
## FLARE_S; the flame writes the name (FORGE), struck at its end and cooling
## (COOL); then the planks one by one (MENU), the version.
const VEIL_S := 0.8
## A frame never moves it on further than this (s): the scene's build or a
## shader's first compile on the web would skip part of a beat.
const STEP_S := 0.05
const DESCENT := Vector2(0.0, 4.8)
const DRAGON := Vector2(1.6, 4.6)
const ERUPT_S := 3.3
const FLARE_S := 2.4
const FORGE := Vector2(4.6, 5.5)
const STRIKE_S := 5.5
const COOL := Vector2(5.5, 6.7)
const MENU := Vector2(6.1, 7.2)
const END_S := 7.6
## The beats by name, as the report says them: the last one begun.
const BEATS := [[0.0, "descent"], [DRAGON.x, "dragon"], [ERUPT_S, "eruption"], [FORGE.x, "forge"], [MENU.x, "menu"], [END_S, "settled"]]
## Where the flame writes, on the canvas: from just before PIXELHEIM's first
## letter to just past its last (its face spans 336..944).
const NAME := Vector2(320, 960)
## The strike: the name shaken this many px at first and the scene sideways, for
## SHAKE_S (the sky reaches past the view's sides, TitleScene.BLEED); a
## white-hot burst of light on the name at FLASH_PEAK, gone over FLASH_S,
## FLASH_SIZE across.
const SHAKE := 3.0
const SHAKE_S := 0.35
const FLASH := Color(1.0, 0.94, 0.78)
const FLASH_PEAK := 0.9
const FLASH_S := 0.16
const FLASH_SIZE := Vector2(820, 260)
## A plank rises in from this far below over PLANK_S.
const RISE := 18.0
const PLANK_S := 0.45
## The flame that writes: FireArt's tall post flame, this many canvas pixels
## an art pixel (the name's own pixels are 8).
const FRONT_SCALE := 4.0
## Shade's fire colours, hottest first (FireArt.COLOURS), then gone.
const HEAT := [Color("ffffff"), Color("fbf236"), Color("df7126"), Color(0.67, 0.2, 0.2, 0.0)]

## The title (title_screen.gd) and its scene.
var screen: Variant
var scene: TitleScene
## The loading picture it rises out of, if any (TitleScreen._veil).
var veil: CanvasItem
var t := 0.0
## Held at a moment (`hold`): the harness's shot.
var held := false
var done := false
## Called once it has settled, played out or skipped.
var on_done := Callable()
var front: AnimatedSprite2D
var sparks: CPUParticles2D
var burst: CPUParticles2D
var flash: Sprite2D
## Over everything while it plays: a click skips it, and never takes a plank.
var catcher: Control
## Where the name hangs, for the shake to come back to.
var _logo_home := Vector2.ZERO


func _ready() -> void:
	# The scene's own dragon comes round long after this pass.
	scene.dragon_at = TitleScene.DRAGON_EVERY_S
	var logo: Control = screen.logo
	_logo_home = logo.position
	front = AnimatedSprite2D.new()
	front.sprite_frames = FireArt.frames("post", 0)
	front.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	front.centered = false
	front.offset = -Vector2(FireArt.KINDS["post"].x / 2.0, FireArt.KINDS["post"].y)
	front.scale = Vector2.ONE * FRONT_SCALE
	front.play()
	screen.add_child(front)
	sparks = _sparks(50, 0.8, Vector2(6, 30))
	sparks.direction = Vector2(0.4, -1.0)
	sparks.spread = 55.0
	sparks.initial_velocity_min = 90.0
	sparks.initial_velocity_max = 240.0
	screen.add_child(sparks)
	burst = _sparks(140, 1.3, Vector2(300, 26))
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.spread = 180.0
	burst.initial_velocity_min = 120.0
	burst.initial_velocity_max = 420.0
	burst.position = Vector2(640, logo.position.y + 36)
	screen.add_child(burst)
	flash = Sprite2D.new()
	flash.texture = TitleScene.glow_texture(64, FLASH, 1.0, 12, true)
	flash.scale = FLASH_SIZE / 128.0
	flash.position = burst.position
	flash.modulate.a = 0.0
	# A flash of light: it brightens what's there rather than paling it.
	flash.material = TitleScene.additive()
	screen.add_child(flash)
	catcher = Control.new()
	catcher.size = TitleScene.ART * TitleScene.PIXEL
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
			skip()
	)
	screen.add_child(catcher)
	pose(0.0)


## Sparks in Shade's fire colours, whole squares, falling as they cool.
func _sparks(amount: int, life: float, extents: Vector2) -> CPUParticles2D:
	var node := CPUParticles2D.new()
	node.amount = amount
	node.lifetime = life
	node.emitting = false
	node.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	node.emission_rect_extents = extents
	node.direction = Vector2.UP
	node.gravity = Vector2(0, 520)
	node.damping_min = 20.0
	node.damping_max = 50.0
	node.scale_amount_min = 4.0
	node.scale_amount_max = 4.0
	var cooling := Curve.new()
	cooling.add_point(Vector2(0, 1.0))
	cooling.add_point(Vector2(1, 0.5))
	node.scale_amount_curve = cooling
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.25, 0.6, 1.0])
	ramp.colors = PackedColorArray(HEAT)
	node.color_ramp = ramp
	node.material = TitleScene.additive()
	return node


func _process(delta: float) -> void:
	if held or done:
		return
	var from := t
	t = minf(t + minf(delta, STEP_S), END_S)
	_cross(from, t)
	pose(t)
	if t >= END_S:
		_finish()


## What happens once, as the time passes it.
func _cross(from: float, to: float) -> void:
	if _passes(from, to, DRAGON.x + 0.5):
		Sound.play("roar")
	if _passes(from, to, ERUPT_S):
		scene.erupt()
	if _passes(from, to, FORGE.x):
		Sound.play_ui("cast")
	if _passes(from, to, STRIKE_S):
		burst.restart()
		Sound.play_ui("slam")
		Sound.play("bell")


static func _passes(from: float, to: float, at: float) -> bool:
	return from < at and to >= at


## Everything as it stands `time` seconds in.
func pose(time: float) -> void:
	t = time
	if is_instance_valid(veil):
		# Into the night's colour, then gone: the picture's moon and village
		# never show over the scene's, whose camera is still among the stars.
		var gone := span(Vector2(0.0, VEIL_S), t) * 2.0
		veil.modulate = Color.WHITE.lerp(TitleScene.SKY[0], minf(gone, 1.0))
		veil.modulate.a = clampf(2.0 - gone, 0.0, 1.0)
	scene.descent = 1.0 - ease(span(DESCENT, t), -2.2)
	scene.flare = flare(t)
	scene.fly_wyrm(span(DRAGON, t) if t > DRAGON.x and t < DRAGON.y else -1.0)
	scene.place()
	# The name, written by the flame from its left, white hot, cooling to gold.
	var logo: Control = screen.logo
	logo.visible = t >= FORGE.x
	logo.clip_contents = true
	logo.size = Vector2(lerpf(NAME.x, NAME.y, span(FORGE, t)), 160)
	front.visible = t >= FORGE.x and t < FORGE.y
	front.position = Vector2(roundf(logo.size.x), _logo_home.y + 72)
	sparks.emitting = front.visible
	sparks.position = front.position - Vector2(0, 40)
	var heat := 1.0 - span(COOL, t)
	(screen.heat as CanvasItem).modulate.a = heat
	(screen.ember as CanvasItem).modulate.a = heat
	var since := t - STRIKE_S
	flash.modulate.a = FLASH_PEAK * pow(1.0 - since / FLASH_S, 2.0) if since >= 0.0 and since < FLASH_S else 0.0
	var shake := SHAKE * (1.0 - since / SHAKE_S) if since >= 0.0 and since < SHAKE_S else 0.0
	# The scene and the name, not the canvas. The scene only sideways, where
	# its sky bleeds past the view: up or down bared a black sliver (PIX-394).
	var jolt := (Vector2(sin(t * 91.0), cos(t * 73.0)) * shake).round()
	scene.position = Vector2(jolt.x, 0.0)
	logo.position = _logo_home + jolt
	var planks: Array = screen.planks
	for i in planks.size():
		var start := MENU.x + i * (MENU.y - MENU.x - PLANK_S) / maxf(1.0, planks.size() - 1.0)
		var shown := span(Vector2(start, start + PLANK_S), t)
		(planks[i] as CanvasItem).modulate.a = shown
		screen.rises[i] = RISE * (1.0 - ease(shown, 0.4))
	screen._follow(0.0)
	# Last, what stands under the menu: the line about the slot in hand, the
	# browser's warning and the version.
	var after := span(Vector2(MENU.y - 0.3, END_S), t)
	for node: CanvasItem in [screen.footer, screen.chosen_fire, screen.note, screen.warning]:
		if node != null:
			node.modulate.a = after


## How far through `beat` (from, to) `time` is: 0 before, 1 after.
static func span(beat: Vector2, time: float) -> float:
	return clampf((time - beat.x) / (beat.y - beat.x), 0.0, 1.0)


## How hard the mountain burns at `time`: roaring up as the dragon's fire
## reaches it, then burning down to its smoulder.
static func flare(time: float) -> float:
	var up := span(Vector2(ERUPT_S - 0.3, ERUPT_S), time)
	var down := 1.0 - span(Vector2(ERUPT_S, ERUPT_S + FLARE_S), time)
	return up * down * down


## The beat `time` is in, by name.
static func beat_at(time: float) -> String:
	var name := ""
	for beat: Array in BEATS:
		if time >= float(beat[0]):
			name = beat[1]
	return name


## The entrance held at `time` (the harness's shot): posed there and still.
func hold(time: float) -> void:
	held = true
	pose(time)


## Straight to the settled title (a key, a button, a click).
func skip() -> void:
	if not done:
		pose(END_S)
		_finish()


func _finish() -> void:
	done = true
	scene.descent = 0.0
	scene.flare = 0.0
	scene.fly_wyrm(-1.0)
	scene.place()
	scene.position = Vector2.ZERO
	(screen.logo as Control).position = _logo_home
	(screen.logo as Control).clip_contents = false
	for node: Node in [front, sparks, burst, flash, catcher, veil]:
		if is_instance_valid(node):
			node.queue_free()
	queue_free()
	if on_done.is_valid():
		on_done.call()
