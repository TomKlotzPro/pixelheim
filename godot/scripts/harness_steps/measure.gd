extends RefCounted
## areas: all
## The harness's measuring steps (PIX-357): what entering maps and rooms costs,
## the CPU's frames, the walking and turning checks, the look book, perf and
## what overflows.
##
## Each `step_<name>()` is the step a flag names in scripts/harness_flags.txt
## (`flag | takes | does | step | order`); harness.gd runs the steps of the
## flags it was given in their order, awaiting each.

## The harness (harness.gd): its tree, its key presses and what's open.
var h: Node
var world: Node
var flags: HarnessFlags
## The report line's fields; a value known only part-way through is noted
## as it's known.
var report: HarnessReport


func step_reentry() -> void:
	await _reentry()


## `rooms` (PIX-318): every room entered and counted as drawn.
func step_rooms() -> void:
	await _rooms()


func step_cpu() -> void:
	# Once the Reach is worked out ahead, early in a session: its bursts
	# aren't what a frame costs (PIX-355).
	while not world.neighbours.warmed():
		await h.get_tree().process_frame
	h.cpu = PerfProbe.clock(h.get_tree())


## After `--at` (and `seamless`), so the walk can be measured anywhere:
## over a line between two maps too (PIX-269).
func step_motion() -> void:
	# `motion` (PIX-135): what the screen shows each rendered frame while
	# the hero walks right: the hero found by its shirt's reds in the image
	# (a survivor's worker clothes since PIX-242; it was a helmet's horns)
	# (a still frame of the walk, so only motion moves it), and the
	# world's scroll from the camera. A hero who steps back on screen
	# while walking forward is the shake that blurred every step.
	# The walk's first three quarters of a second, in frames at the
	# run's pace (`--fps`, PIX-276: the flow's 144, a fast screen's,
	# draws two or three frames between the physics ticks, where the
	# camera rides the hero as the interpolation draws them). Stepped,
	# the walk is the same however fast the machine draws it; it used
	# to be timed by the wall clock, and a slow frame walked the hero
	# further. Two things aren't the camera: a cloud's shadow drifting
	# over the shirt changes its reds, so the sky is kept clear while it
	# walks; and the river stops the walk, the camera catching up as a
	# step back, so frames count only while the hero still walks.
	world.lights.clear_sky = true
	h._draw_every_frame()
	world.player.scripted_dir = Vector2.RIGHT
	world.player.sprite.speed_scale = 0.0
	var hero_x: Array[float] = []
	var scroll_x: Array[float] = []
	var walking := false
	# Over a line (`seamless`, PIX-269) the air of the map walked into
	# tints the shirt (Atmosphere's mood): its reds are matched by hue.
	var by_hue := flags.has("seamless")
	for i in roundi(45 * float(flags.value("--fps", "60")) / 60.0):
		await RenderingServer.frame_post_draw
		var moving: bool = world.player.get_real_velocity().x >= 1.0
		if walking and not moving:
			break
		walking = walking or moving
		var image := h.get_viewport().get_texture().get_image()
		var sum := 0.0
		var n := 0
		# Only near the hero (the town's grass has red flowers too).
		var around: Vector2 = (h.get_viewport().get_canvas_transform() * world.player.global_position) * (image.get_width() / h.get_viewport().get_visible_rect().size.x)
		for y in range(int(around.y) - 90, int(around.y) + 30):
			for x in range(int(around.x) - 50, int(around.x) + 50):
				var pixel := image.get_pixel(x, y)
				if by_hue:
					if pixel.r < 0.1 or pixel.g > 0.05 or pixel.b > 0.05:
						continue
					var seen := DesktopLook.shown(pixel, DesktopLook.linear)
					if seen.r > 0.4 and seen.g < 0.15 and seen.b < 0.15:
						sum += x
						n += 1
					continue
				# A pure red, in either light, before the exact test:
				# turning every pixel into its hex took most of a slow
				# frame.
				if pixel.r < 0.15 or pixel.g > 0.002 or pixel.b > 0.002:
					continue
				if DesktopLook.shown(pixel, DesktopLook.linear).to_html(false) in ["b60000", "770000"]:
					sum += x
					n += 1
		# -1: not found in this frame.
		hero_x.append(sum / n if n > 0 else -1.0)
		scroll_x.append(h.get_viewport().get_canvas_transform().origin.x)
	world.player.scripted_dir = Vector2.ZERO
	world.lights.clear_sky = false
	var hero_steps: Array = []
	var scroll_steps: Array = []
	for i in range(1, hero_x.size()):
		# A frame the hero wasn't found in is no step either way.
		if hero_x[i] >= 0.0 and hero_x[i - 1] >= 0.0:
			hero_steps.append(snappedf(hero_x[i] - hero_x[i - 1], 0.1))
		scroll_steps.append(snappedf(scroll_x[i] - scroll_x[i - 1], 0.1))
	# Which steps went back, by their place in the walk.
	var back_at: Array[int] = []
	for i in hero_steps.size():
		if hero_steps[i] < -0.05:
			back_at.append(i)
	var back := back_at.size()
	var frozen := scroll_steps.filter(func(d: float) -> bool: return absf(d) < 0.05).size()
	var found := hero_x.filter(func(x: float) -> bool: return x >= 0.0).size()
	print("MOTION fps=%d frames=%d found=%d hero_backsteps=%d at=%s scroll_frozen=%d hero=%s scroll=%s" % [
		Engine.get_frames_per_second(), hero_x.size(), found, back, str(back_at), frozen, str(hero_steps.slice(5, 17)), str(scroll_steps.slice(5, 17))])
	# The release flow reads it off the report line (PIX-135).
	# A hero found in too few frames would leave too few steps to judge:
	# say so, not pass.
	report.note("backsteps", str(back) if found >= 10 and found * 2 >= hero_x.size() else "lost")


func step_turning() -> void:
	await _turning()


## `lookbook [perf] [film] [--only NAME] [--out DIR] [--looks a,b]`: the
## look book (PIX-220), every staged scene saved and on one sheet, in each
## of the app's looks named (PIX-227); tools/lookbook.sh runs it.
func step_lookbook() -> void:
	var book: Node = preload("res://scripts/lookbook.gd").new()
	book.world = world
	book.with_perf = flags.has("perf")
	# `film`, not `motion`: that's the walking-scroll check above, which
	# would stop the hero's animations for the whole book.
	book.with_motion = flags.has("film")
	book.only = flags.list("--only")
	book.looks = book.looks_from(flags)
	book.out_dir = flags.value("--out", book.out_dir)
	world.add_child(book)
	await book.run()


## With `lookbook`, the book measures each shot instead.
func step_perf() -> void:
	if flags.has("lookbook"):
		return
	# `perf`: what this scene's frames cost (PerfProbe, the perf guard).
	h.perf = await PerfProbe.sample(world)
	print("PERF " + h.perf)


## `overflow` (Solid Ground): every visible piece of an open screen that
## runs past the canvas, as OVERFLOW lines; text that grows (French is
## longer) mustn't push a panel off the screen; and every word of one on
## the HUD's dock, clock or quill left showing (PIX-346). Works headless.
func step_overflow() -> void:
	await h.get_tree().process_frame
	var overflows := Layout.overflows(h.get_tree().root, Touch.view_size(world))
	overflows.append_array(Layout.over(h.get_tree().root, world.hud.shown()))
	for line in overflows:
		print("%s %s" % ["OVERFLOW", line])
	report.note("overflow", str(overflows.size()))


## The turning walk's legs (PIX-293), as a player holds the keys: a way and
## how long, two keys at once being a diagonal; a leg with a second way
## swaps between the two every tick (a stick wobbling either side of the
## line between down and down-right, 20 and 25 degrees off down).
const TURNING := [
	[Vector2.DOWN, 0.4], [Vector2(1, 1), 0.2], [Vector2.RIGHT, 0.4],
	[Vector2.UP, 0.4], [Vector2(-1, -1), 0.2], [Vector2.LEFT, 0.4],
	[Vector2.DOWN, 0.4], [Vector2.RIGHT, 0.4],
	[Vector2(1, -1), 0.4], [Vector2.UP, 0.4], [Vector2.RIGHT, 0.3],
	[Vector2(0.342, 0.94), 0.5, Vector2(0.423, 0.906)],
]


## The turning walk (PIX-293): TURNING's legs, the way the hero is drawn
## read off the sprite every tick. turns= is the most times it changed in
## any one second (a flicker between two ways shows as many), jumps= the
## changes of more than an eighth of a turn at once (a snap round a corner,
## where Shade drew the way between).
func _turning() -> void:
	var ways: PackedStringArray = []
	for leg: Array in TURNING:
		for tick in roundi(float(leg[1]) * Engine.physics_ticks_per_second):
			var way: Vector2 = leg[2] if leg.size() > 2 and tick % 2 == 1 else leg[0]
			world.player.scripted_dir = way.normalized()
			await h.get_tree().physics_frame
			ways.append(String(world.player.sprite.animation).trim_prefix("walk_").trim_prefix("idle_"))
	world.player.scripted_dir = Vector2.ZERO
	var changed: Array[int] = []
	var jumps := 0
	var drawn: PackedStringArray = [ways[0]]
	for i in range(1, ways.size()):
		if ways[i] == ways[i - 1]:
			continue
		changed.append(i)
		drawn.append(ways[i])
		var apart := absi(Gait.EIGHT.find(ways[i]) - Gait.EIGHT.find(ways[i - 1]))
		if mini(apart, 8 - apart) > 1:
			jumps += 1
	var most := 0
	for at in changed.size():
		var within := changed.filter(func(i: int) -> bool: return i >= changed[at] and i < changed[at] + Engine.physics_ticks_per_second)
		most = maxi(most, within.size())
	print("TURNING %s" % " ".join(drawn))
	report.note("turns", str(most))
	report.note("jumps", str(jumps))


## The maps `reentry` times: the open air, where the ground is worked out.
const REENTRY_MAPS := ["overworld", "town", "saltmere", "blackiron", "mirefen", "greyhold", "deepwood", "frostgate"]


## `reentry` (One Reach, PIX-269): what entering each outdoor map costs, in
## milliseconds of the frame it happens in - its first visit this session,
## then coming back to it - and the memory the session keeps between. A
## change of scene is that long a hitch, and a map streamed in beside the
## hero has to fit its building into a few milliseconds a frame.
func _reentry() -> void:
	var took := {}
	var before := Performance.get_monitor(Performance.MEMORY_STATIC)
	for visit in 2:
		for id: String in REENTRY_MAPS:
			var started := Time.get_ticks_usec()
			world.map = world.load_map(id)
			var loaded := Time.get_ticks_usec()
			world.enter_map(world.map, world.map.spawn)
			var done := Time.get_ticks_usec()
			took[id] = took.get(id, []) + [(loaded - started) / 1000.0, (done - loaded) / 1000.0]
			# The old map's nodes go at the end of the frame.
			await h.get_tree().process_frame
			await h.get_tree().process_frame
	for id: String in REENTRY_MAPS:
		var times: Array = took[id]
		print("REENTRY %-10s load %5.1f  first %6.1f  again %6.1f ms" % [id, times[0], times[1], times[3]])
	print("REENTRY memory %+.1f MB after both rounds (static), kept ground %.2f MB" % [
		(Performance.get_monitor(Performance.MEMORY_STATIC) - before) / 1048576.0, KeptGround.bytes() / 1048576.0])
	await _beside()


## `rooms` (PIX-318): every room entered in turn as a door enters it, the
## room the run began in last (its shot), and counted as drawn: a ROOM line
## each, with what it's drawn from (MapView.room_drawn: paid, free or none)
## and its walls, floor and stairs down; the report's rooms= sums them up:
## free walled 9/9 stairs keep,observatory.
func _rooms() -> void:
	var start: String = world.map.id
	var order: Array = PunyInterior.ROOMS.filter(func(id: String) -> bool: return id != start)
	if start in PunyInterior.ROOMS:
		order.append(start)
	var arts := {}
	var walled := 0
	var stairs: Array[String] = []
	for id: String in order:
		world.map = world.load_map(id)
		world.enter_map(world.map, world.map.spawn)
		# The room before's nodes go at the end of the frame.
		await h.get_tree().process_frame
		await h.get_tree().process_frame
		var drawn: Dictionary = world.view.room_drawn()
		print("ROOM %-14s %-4s walls %3d floor %3d stairs %d" % [id, drawn["art"], drawn["walls"], drawn["floor"], drawn["stairs"]])
		arts[drawn["art"]] = true
		if int(drawn["walls"]) > 0 and int(drawn["floor"]) > 0:
			walled += 1
		if int(drawn["stairs"]) > 0:
			stairs.append(id)
	stairs.sort()
	var kinds: Array = arts.keys()
	kinds.sort()
	report.note("rooms", "%s walled %d/%d stairs %s" % [",".join(kinds), walled, order.size(), ",".join(stairs) if not stairs.is_empty() else "none"])


## What drawing each map beside the one the hero stands on takes, its ground
## kept from the rounds before (One Reach, PIX-269, step 8): what the step
## that streams the neighbour in has to cut into slices a frame. Drawn
## only, as that step draws it - no folk, foes or music - and taken down
## again: BESIDE lines with its plan, each part of its build (MapView.took)
## and the nodes it adds.
func _beside() -> void:
	for id: String in REENTRY_MAPS:
		var data: MapData = world.load_map(id)
		var drawn := Node2D.new()
		var standing := Node2D.new()
		drawn.add_child(standing)
		world.add_child(drawn)
		var nodes := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		var view := MapView.new(data, standing)
		view.timed = true
		var started := Time.get_ticks_usec()
		view.plan(data.spawn)
		var planned := (Time.get_ticks_usec() - started) / 1000.0
		view.build(drawn)
		var parts: Array[String] = []
		var total := planned
		for part: String in view.took:
			parts.append("%s %.1f" % [part, view.took[part]])
			total += float(view.took[part])
		var added := Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes
		# Dropped again once the hero is far from it: what that takes too.
		started = Time.get_ticks_usec()
		drawn.free()
		print("BESIDE %-10s plan %5.1f  %s  = %6.1f ms, %d nodes, taken down in %.1f ms" % [
			id, planned, "  ".join(parts), total, added, (Time.get_ticks_usec() - started) / 1000.0])
		await h.get_tree().process_frame
		await h.get_tree().process_frame
