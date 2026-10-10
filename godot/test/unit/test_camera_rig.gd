extends GutTest
## The camera at 3 screen pixels an art pixel (PIX-244: Tom found the hero
## too big at 4). Every art pixel stays whole on the screen, the words over
## the world stay crisp, and following a walk the camera keeps the hero and
## the world from stepping a pixel back (the motion check's back-steps, which
## doubled at 3 when the hero and the camera were rounded each on its own).


## One number to go back (CameraRig.ZOOM): the words and the gains over the
## world follow it.
func test_the_zoom_is_one_number() -> void:
	assert_almost_eq(CameraRig.LABEL_SCALE * CameraRig.ZOOM, 1.0, 0.0001, "a label's pixel a screen pixel")
	assert_almost_eq(WorldFx.GAIN_ICON * CameraRig.ZOOM, 2.0, 0.0001, "an icon's pixel two screen pixels")


## A walk followed frame by frame (`fps`, the hero `speed` art px a second,
## `zoom` screen px an art pixel): the hero's pixel on the screen and the
## camera's, as _follow_hero stands them, and the camera as it was eased.
func _walk(fps: float, speed: float, zoom: float, frames: int) -> Dictionary:
	var hero_on_screen: Array[float] = []
	var camera_px: Array[float] = []
	var eased := 0.0
	var shown := INF
	var last_hero := 0.0
	for frame in frames:
		var hero := frame * speed / fps
		eased = lerpf(eased, hero, 1.0 - exp(-CameraRig.CAMERA_EASE / fps))
		var hero_px := roundf(hero * zoom)
		var lag := roundf((hero - eased) * zoom)
		if shown != INF:
			lag = CameraRig.lag_step(lag, shown, hero_px - last_hero)
		shown = lag
		last_hero = hero_px
		hero_on_screen.append(lag)
		camera_px.append(hero_px - lag)
	return {"hero": hero_on_screen, "camera": camera_px}


func _back_steps(values: Array[float]) -> int:
	var back := 0
	for i in range(1, values.size()):
		if values[i] < values[i - 1]:
			back += 1
	return back


func test_neither_the_hero_nor_the_world_steps_back_on_a_walk() -> void:
	for fps: float in [60.0, 120.0, 144.0]:
		for zoom: float in [3.0, 4.0]:
			var walk := _walk(fps, 95.0, zoom, int(fps))
			assert_eq(_back_steps(walk["hero"]), 0, "the hero at %d fps, %dx" % [fps, zoom])
			assert_eq(_back_steps(walk["camera"]), 0, "the world at %d fps, %dx" % [fps, zoom])
			assert_gt(walk["hero"][-1], 0.0, "the hero ahead of the camera, as it lags")


## Standing still the camera only closes in; walking, the lag grows by no
## more than the hero moved, and shrinks as the camera catches up.
func test_the_lag_follows_the_hero() -> void:
	assert_eq(CameraRig.lag_step(9.0, 4.0, 3.0), 7.0, "grows by what the hero moved, no more")
	assert_eq(CameraRig.lag_step(5.0, 4.0, 3.0), 5.0, "or less")
	assert_eq(CameraRig.lag_step(2.0, 4.0, 3.0), 2.0, "shrinks as the camera catches up")
	assert_eq(CameraRig.lag_step(-9.0, -4.0, -3.0), -7.0, "the same walking the other way")
	assert_eq(CameraRig.lag_step(3.0, 4.0, 0.0), 3.0, "standing, the camera closes in")
	assert_eq(CameraRig.lag_step(5.0, 4.0, 0.0), 4.0, "and never backs away")


## A room smaller than the view (every room at 3) stands in its middle, as
## Camera2D shows it; a map bigger than the view holds the camera inside it.
func test_a_map_smaller_than_the_view_stands_in_its_middle() -> void:
	assert_eq(CameraRig.held(40.0, 0.0, 320.0, 213.0), 160.0, "a room 320 px across, the view 426")
	assert_eq(CameraRig.held(40.0, 0.0, 1344.0, 213.0), 213.0, "held off the left edge")
	assert_eq(CameraRig.held(1300.0, 0.0, 1344.0, 213.0), 1131.0, "and the right")
	assert_eq(CameraRig.held(600.0, 0.0, 1344.0, 213.0), 600.0, "free between")
