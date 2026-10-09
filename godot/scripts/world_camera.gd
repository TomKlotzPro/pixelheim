class_name CameraRig
extends Node
## The world's camera (Solid Ground, PIX-260: moved out of world.gd as it
## was). It rides the hero where they are drawn this frame, between physics
## ticks, and stands on a whole screen pixel so the world scrolls crisp; it
## takes a punch on a crit or a killing blow (PIX-226); it shakes (PIX-155)
## and holds the world's breath on a blow (hit_stop). It doesn't lean ahead
## of the hero: to get ahead it must outrun them, and the hero slips back on
## screen as they set off (the motion check's back-steps, PIX-135). It frames the world above the dock (PIX-142) and
## keeps an art pixel a whole number of screen pixels at any window size.
## world.gd calls update() each frame, in the order it always did.

var world: Node
var camera: Camera2D
## False while something else frames the shot (the harness overview, the
## dawn and reveal tours).
var follows := true
## Shade's figures are 16px: about 4x shows ~20x11 tiles, close to the web
## game's view. The exact zoom keeps an art pixel a whole number of screen
## pixels at any window size (fit_zoom).
const ZOOM := 4.0
## How fast the camera catches up with the hero (per second, eased).
const CAMERA_EASE := 8.0
## A crit or a killing blow punches it (PIX-226); not with reduced motion.
const PUNCH := 3.0
const PUNCH_EASE := 16.0
## The hero's position after the last two physics ticks (recorded after the
## hero has moved, see _physics_process), so the camera can stand exactly
## where the hero is drawn this frame.
var _hero_tick_from := Vector2.ZERO
var _hero_tick_to := Vector2.ZERO
## Where the camera eases to stand, before it settles on a whole pixel.
var _camera_at := Vector2.ZERO
var _punch := Vector2.ZERO
## The screen shakes (PIX-155): `strength` pixels at first, easing out over
## `seconds`. Reduce motion keeps it still.
var _shake_left := 0.0
var _shake_total := 0.0
var _shake_strength := 0.0
## A blow lands: the world holds its breath for a few hundredths of a second
## (PIX-155), counted in real time so the stop can end itself.
var _stopped := false


func _ready() -> void:
	# The hero's ticks are noted after the actors have moved (as the world's
	# own physics step was, before this moved out of it).
	process_physics_priority = 10


## The camera on `player`, fitted to the window, cut to where they stand.
func attach(player: Node2D) -> void:
	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	# The camera follows where the hero is drawn (between physics ticks), not
	# where physics last put them: attached to the hero it would lag the drawn
	# sprite by up to a tick and snap back, a shake that blurs every step.
	camera.top_level = true
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	player.add_child(camera)
	fit_zoom()
	get_tree().root.size_changed.connect(fit_zoom)
	cut()


## Holds the camera inside a map `size_px` pixels across.
func set_limits(size_px: Vector2) -> void:
	camera.limit_right = int(size_px.x)
	camera.limit_bottom = int(size_px.y)
	camera.reset_smoothing()


func _physics_process(_delta: float) -> void:
	if world.player == null:
		return
	_hero_tick_from = _hero_tick_to
	_hero_tick_to = world.player.position


## The frame's camera: following the hero, then the shake on top.
func update(delta: float) -> void:
	_follow_hero(delta)
	_apply_shake(delta)


## The hero was placed, not walked: no interpolating from the old spot, and
## the camera cuts there.
func cut() -> void:
	var player: Node2D = world.player
	player.reset_physics_interpolation()
	_hero_tick_from = player.position
	_hero_tick_to = player.position
	_punch = Vector2.ZERO
	if camera != null:
		_camera_at = player.position + Vector2(0, frame_lift())
		camera.global_position = _camera_at
		camera.reset_smoothing()


## The camera eases toward where the hero is drawn this frame (between the
## last two ticks, as the physics interpolation draws them) and stands on a
## whole screen pixel, so the world scrolls crisp, all of a piece.
func _follow_hero(delta: float) -> void:
	if camera == null or not follows:
		return
	var drawn := _hero_tick_from.lerp(_hero_tick_to, Engine.get_physics_interpolation_fraction())
	drawn.y += frame_lift()
	_punch = _punch.lerp(Vector2.ZERO, 1.0 - exp(-PUNCH_EASE * delta))
	_camera_at = _camera_at.lerp(drawn, 1.0 - exp(-CAMERA_EASE * delta))
	var pixels_per_unit := camera.zoom.x * stretch()
	camera.global_position = ((_camera_at + _punch) * pixels_per_unit).round() / pixels_per_unit


## A crit or a killing blow nudges the camera along the blow's `direction`
## for an instant (PIX-226); not with reduced motion.
func punch(direction: Vector2) -> void:
	if GameState.settings.reduce_motion or direction == Vector2.ZERO:
		return
	_punch = direction.normalized() * PUNCH


func shake(strength: float, seconds: float) -> void:
	if GameState.settings.reduce_motion or camera == null:
		return
	if strength * seconds < _shake_strength * _shake_left:
		return
	_shake_strength = strength
	_shake_total = seconds
	_shake_left = seconds


func _apply_shake(delta: float) -> void:
	if camera == null:
		return
	if _shake_left <= 0.0:
		# Only once: writing the offset every frame re-settles the camera.
		if camera.offset != Vector2.ZERO:
			camera.offset = Vector2.ZERO
		return
	_shake_left = maxf(0.0, _shake_left - delta)
	var power := _shake_strength * _shake_left / _shake_total / camera.zoom.x
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * power


func hit_stop(seconds: float, scale := 0.08) -> void:
	if _stopped or GameState.settings.reduce_motion:
		return
	_stopped = true
	Engine.time_scale = scale
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_stopped = false
	)


## The world the player can see: the screen above the dock, widened by
## `margin` world pixels on every side.
func view_rect(margin := 0.0) -> Rect2:
	if camera == null:
		return Rect2()
	var view := Touch.view_size(world)
	var half := view / 2.0 / camera.zoom.x
	# Where the camera stands, held inside the map as its limits hold it.
	var center := camera.global_position
	center.x = clampf(center.x, camera.limit_left + half.x, maxf(camera.limit_left + half.x, camera.limit_right - half.x))
	center.y = clampf(center.y, camera.limit_top + half.y, maxf(camera.limit_top + half.y, camera.limit_bottom - half.y))
	return Rect2(center - half, Vector2(view.x, view.y - (720.0 - dock_top())) / camera.zoom.x).grow(margin)


func in_view(at: Vector2, margin := 0.0) -> bool:
	return view_rect(margin).has_point(at)


## Where the dock begins on the 1280x720 canvas (the bottom, before it is built).
func dock_top() -> float:
	var dock: Node = world.hud.dock if world.hud != null else null
	return dock.top() if dock != null and dock.top() > 0 else 720.0


## How far below the hero the camera stands, so the hero is centred in the
## world above the dock rather than on the whole screen (PIX-142).
func frame_lift() -> float:
	if camera == null:
		return 0.0
	return roundf((720.0 - dock_top()) / 2.0 / camera.zoom.y)


## Screen pixels per pixel of the 1280x720 canvas (the window's stretch).
func stretch() -> float:
	return get_tree().root.get_final_transform().get_scale().x


## The zoom nearest ZOOM at which an art pixel covers a whole number of
## screen pixels: no uneven 4-and-5-pixel columns shimmering as the world
## scrolls.
func fit_zoom() -> void:
	if camera == null or not follows:
		return
	var scale := stretch()
	# A phone's small screen still gets art pixels two screen pixels big
	# (PIX-162): a hero you can see.
	var least := 2.0 if Touch.enabled() else 1.0
	camera.zoom = Vector2.ONE * maxf(least, roundf(ZOOM * scale)) / scale
