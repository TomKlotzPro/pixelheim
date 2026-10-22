extends RefCounted
## areas: all
## The harness's steps that move the hero or the camera (PIX-357): a cell
## stood on, the zoom and the overview, scripted walks, the maps beside the hero
## settled, the map screen, doorways.
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


## Terrain review: `--at x,y` stands the hero on a cell (before `--walk`,
## so a walk can test what stops them), `--zoom Z` changes the camera
## (`--zoom play`: the play zoom, CameraRig.ZOOM, which a headless run's
## window doesn't fit); `overview` (below) frames the whole map.
func step_at() -> void:
	var at := flags.list("--at")
	world.player_cell = Vector2i(int(at[0]), int(at[1]))
	world.player.position = MapView.center(world.player_cell)
	world.camera_rig.cut()
	world.camera_rig.camera.reset_smoothing()


func step_zoom() -> void:
	var zoom: String = flags.value("--zoom")
	world.camera_rig.camera.zoom = Vector2.ONE * (CameraRig.ZOOM if zoom == "play" else float(zoom))


func step_seamless() -> void:
	# The maps beside the hero drawn and stitched first (One Reach,
	# PIX-269), so a road out is walked over, not a door.
	await _settled()


func step_walk() -> void:
	var clock := _frame_clock() if flags.has("crossing") else {}
	await _walk(flags.list("--walk"))
	if not clock.is_empty():
		report.note("frames", _read_clock(clock))


func step_overview() -> void:
	var view := h.get_viewport().get_visible_rect().size
	var fit := minf(view.x / (world.map.size.x * world.TILE), view.y / (world.map.size.y * world.TILE))
	world.camera_rig.follows = false
	world.camera_rig.camera.zoom = Vector2(fit, fit)
	world.camera_rig.camera.limit_right = 1 << 20
	world.camera_rig.camera.limit_bottom = 1 << 20
	world.camera_rig.camera.limit_left = -(1 << 20)
	world.camera_rig.camera.limit_top = -(1 << 20)
	world.camera_rig.camera.global_position = Vector2(world.map.size * world.TILE) / 2.0
	world.camera_rig.camera.reset_smoothing()
	await h.get_tree().create_timer(0.2).timeout


func step_waypoints() -> void:
	# Every waypoint found (Solid Ground): the map's list at its longest.
	# The waystations built too (PIX-322).
	for waypoint: Dictionary in Routes.every_waypoint(GameState.settlement):
		var at := Vector2i(int(waypoint["at"]["x"]), int(waypoint["at"]["y"]))
		Discovery.discover_around(GameState.world.discovered, MapData.load_by_id(waypoint["mapId"]), at)


func step_charted() -> void:
	# A hero who has walked the whole Reach (PIX-266): every page of the
	# map drawn whole.
	Atlas.walk_all(GameState.world.discovered)


func step_worldmap() -> void:
	# The map over the world: the lairs the board posts on it (`--hunted`).
	var screen := preload("res://scripts/map_screen.gd").new()
	screen.world = world
	world.add_child(screen)
	await h.get_tree().create_timer(0.3).timeout
	# `--choose waystation_saltmere` (PIX-322): that waypoint chosen, as
	# pointing at its card would.
	if flags.has("--choose"):
		screen.show_waypoint(flags.value("--choose"))
		await h.get_tree().create_timer(0.3).timeout


func step_portal() -> void:
	# Walk into the map's nearest doorway from a free side, as a player would.
	var doors: Array = world.map.portals.keys()
	doors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.distance_squared_to(world.player_cell) < b.distance_squared_to(world.player_cell)
	)
	for door: Vector2i in doors:
		var sides := [Vector2i.DOWN, Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT].filter(
			func(side: Vector2i) -> bool:
				return world.map.is_walkable(door + side) and not world.map.portals.has(door + side)
		)
		if sides.is_empty():
			continue
		var side: Vector2i = sides[0]
		world.player.position = MapView.center(door + side)
		world.camera_rig.cut()
		world.player_cell = door + side
		world.player.scripted_dir = Vector2(-side)
		await h.get_tree().create_timer(0.4).timeout
		world.player.scripted_dir = Vector2.ZERO
		break
	await h.get_tree().create_timer(0.3).timeout


## `--then-walk r,u`: steps taken once all that is done (PIX-292: a boss
## down, straight out by its way out, once it has risen: PIX-339).
func step_then_walk() -> void:
	while world.delve.stair() in ["waiting", "cracking", "sinking"]:
		await h.get_tree().create_timer(0.1).timeout
	await _walk(flags.list("--then-walk"))


## Scripted steps, a fifth of a second each (l, r, u, d).
func _walk(moves: PackedStringArray) -> void:
	var dirs := {
		"l": Vector2i.LEFT, "r": Vector2i.RIGHT, "u": Vector2i.UP, "d": Vector2i.DOWN,
	}
	for move in moves:
		world.player.scripted_dir = Vector2(dirs[move])
		await h.get_tree().create_timer(0.2).timeout
	world.player.scripted_dir = Vector2.ZERO


## Waits (up to ten seconds) until the maps wanted beside the hero's are
## drawn and stitched (Neighbours) and the camera may look over them, and a
## few frames more.
func _settled() -> void:
	for i in 600:
		if not world.neighbours.drawn.is_empty() and world.neighbours.settled() and world.camera_rig.settled():
			break
		await h.get_tree().process_frame
	for i in 3:
		await h.get_tree().process_frame


## `crossing` (PIX-269): each frame timed while the hero walks, its work
## (from its first physics tick to the drawing, as PerfProbe reads it) and
## its length (from one drawing to the next), and what the maps beside the
## hero were doing; stopped by _read_clock.
func _frame_clock() -> Dictionary:
	var clock := {"phys": 0, "last": 0, "work": [], "length": [], "streaming": [], "doing": [], "was": ""}
	clock["on_phys"] = func() -> void:
		if int(clock["phys"]) == 0:
			clock["phys"] = Time.get_ticks_usec()
	clock["on_proc"] = func() -> void:
		if int(clock["phys"]) == 0:
			clock["phys"] = Time.get_ticks_usec()
	clock["on_pre"] = func() -> void:
		var now := Time.get_ticks_usec()
		if int(clock["phys"]) > 0:
			(clock["work"] as Array).append((now - int(clock["phys"])) / 1000.0)
		clock["phys"] = 0
		if int(clock["last"]) > 0:
			(clock["length"] as Array).append((now - int(clock["last"])) / 1000.0)
		clock["last"] = now
		(clock["streaming"] as Array).append(world.neighbours.spent)
		# What changed beside the hero this frame: a map drawn, stitched,
		# ready, let go; the hand-over.
		var doing: Array = world.neighbours.drawn.keys().map(func(id: String) -> String: return "%s %s" % [id, world.neighbours.drawn[id]["state"]])
		var now_doing := "%s, %d handed over" % [", ".join(doing), world.neighbours.handovers]
		(clock["doing"] as Array).append(now_doing if now_doing != clock["was"] else "")
		clock["was"] = now_doing
	h.get_tree().physics_frame.connect(clock["on_phys"])
	h.get_tree().process_frame.connect(clock["on_proc"])
	RenderingServer.frame_pre_draw.connect(clock["on_pre"])
	return clock


## The walk's frames: a CROSSING line with the work's and the length's most,
## 99th percentile and middle, ms; the report's frames= text.
func _read_clock(clock: Dictionary) -> String:
	h.get_tree().physics_frame.disconnect(clock["on_phys"])
	h.get_tree().process_frame.disconnect(clock["on_proc"])
	RenderingServer.frame_pre_draw.disconnect(clock["on_pre"])
	var said := {}
	for part: String in ["work", "length", "streaming"]:
		var times: Array = (clock[part] as Array).duplicate()
		times.sort()
		if times.is_empty():
			times = [0.0]
		said[part] = [times[-1], times[mini(times.size() - 1, int(times.size() * 0.99))], times[times.size() / 2]]
	print("CROSSING frames %d  work: max %.2f p99 %.2f median %.2f ms  length: max %.2f p99 %.2f median %.2f ms  streaming: max %.2f p99 %.2f ms  handovers %d" % [
		(clock["work"] as Array).size(), said["work"][0], said["work"][1], said["work"][2], said["length"][0], said["length"][1], said["length"][2],
		said["streaming"][0], said["streaming"][1], world.neighbours.handovers])
	# The longest frames, and what changed beside the hero when.
	var lengths: Array = clock["length"]
	var order := range(lengths.size())
	order.sort_custom(func(a: int, b: int) -> bool: return lengths[a] > lengths[b])
	for i: int in order.slice(0, 3):
		print("CROSSING long frame %d: %.1f ms long" % [i + 1, lengths[i]])
	var doing: Array = clock["doing"]
	for i in doing.size():
		if doing[i] != "":
			print("CROSSING at frame %d: %s" % [i, doing[i]])
	return "%d max %.1f p99 %.1f" % [(clock["work"] as Array).size(), said["work"][0], said["work"][1]]
