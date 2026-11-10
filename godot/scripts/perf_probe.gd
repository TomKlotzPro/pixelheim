class_name PerfProbe
## areas: none
## The perf guard (PIX-220): how long each stage of a frame takes, from the
## engine's own signals - physics (first physics_frame to process_frame),
## process (process_frame to frame_pre_draw) and render (frame_pre_draw to
## frame_post_draw, which holds the wait for vsync too, so it's a ceiling,
## not a cost). Measured over `frames` after a warm-up; draw calls, canvas
## objects and nodes at the end. Beauty is spent against this budget.


## One line: "physics 0.74/1.57 | process 0.41/0.91 | render ... | draws 43
## objects 879 nodes 1460 particles 420" (ms average/95th percentile;
## particles: how many the emitting systems hold, PIX-225).
static func sample(node: Node, frames := 300, warmup := 30) -> String:
	var tree := node.get_tree()
	for i in warmup:
		await tree.process_frame
	var marks := {"phys": 0, "proc": 0, "pre": 0}
	var spans := {"physics": [], "process": [], "render": []}
	var on_phys := func() -> void:
		if int(marks["phys"]) == 0:
			marks["phys"] = Time.get_ticks_usec()
	var on_proc := func() -> void:
		marks["proc"] = Time.get_ticks_usec()
	var on_pre := func() -> void:
		marks["pre"] = Time.get_ticks_usec()
	var on_post := func() -> void:
		var now := Time.get_ticks_usec()
		if int(marks["proc"]) > 0 and int(marks["pre"]) > 0:
			if int(marks["phys"]) > 0:
				spans["physics"].append((int(marks["proc"]) - int(marks["phys"])) / 1000.0)
			spans["process"].append((int(marks["pre"]) - int(marks["proc"])) / 1000.0)
			spans["render"].append((now - int(marks["pre"])) / 1000.0)
		marks["phys"] = 0
	tree.physics_frame.connect(on_phys)
	tree.process_frame.connect(on_proc)
	RenderingServer.frame_pre_draw.connect(on_pre)
	RenderingServer.frame_post_draw.connect(on_post)
	for i in frames:
		await tree.process_frame
	tree.physics_frame.disconnect(on_phys)
	tree.process_frame.disconnect(on_proc)
	RenderingServer.frame_pre_draw.disconnect(on_pre)
	RenderingServer.frame_post_draw.disconnect(on_post)
	var parts: Array[String] = []
	for key: String in spans:
		parts.append("%s %s" % [key, summary(spans[key])])
	# Developer output, not the player's: no words for the translators.
	parts.append("%s %d %s %d %s %d %s %d" % [
		"draws", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects", Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"nodes", Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		"particles", particles(tree.root),
	])
	return " | ".join(parts)


## The CPU clock (PIX-355), which needs no renderer: each frame's time from
## one process_frame to the next. Stepped (--fixed-fps) and headless, the
## frames run back to back, so that is what a frame costs on one core:
## physics, process, the scripts. Read it with `cpu`, and in the machine's
## pace with `paced`: between each frame and the next the clock times a
## round of the pace (Pace), left out of the frame's time, so the two are
## read side by side through the same seconds (a runner slowed for a second
## or two by its neighbours slows both alike).
static func clock(tree: SceneTree) -> Dictionary:
	var ends := []
	var paces := []
	var starts := []
	var pace := Pace.new()
	# Its own lists, not the dictionary: a lambda holding what holds it leaks.
	var on_frame := func() -> void:
		ends.append(Time.get_ticks_usec())
		paces.append(pace.once())
		starts.append(Time.get_ticks_usec())
	tree.process_frame.connect(on_frame)
	return {"starts": starts, "ends": ends, "paces": paces, "pace": pace, "on_frame": on_frame}


## The clock stopped: "median/95th percentile" ms of its frames.
static func cpu(tree: SceneTree, clock: Dictionary) -> String:
	tree.process_frame.disconnect(clock["on_frame"])
	clock["pace"].done()
	return spread(_spans(clock))


## The stopped clock's median frame in paces (PIX-445), "1.97": what a frame
## costs whatever the machine's speed. CI's runners are four kinds of
## machine, 1.8 times apart in speed (cpu-night 0.78 to 1.43 ms on one
## build, steady on each), so a budget in ms failed the slow ones with no
## change to the game and let the fast ones hide a real slowdown; in paces,
## the frame reads within 9 % on all four.
static func paced(clock: Dictionary) -> String:
	var spans := _spans(clock)
	var paces: Array = clock["paces"].duplicate()
	if spans.is_empty() or paces.is_empty():
		return "-"
	spans.sort()
	paces.sort()
	return "%.2f" % (float(spans[spans.size() / 2]) / maxf(float(paces[paces.size() / 2]), 0.001))


## The clock's frames, ms each, from the end of one round of the pace to the
## start of the next.
static func _spans(clock: Dictionary) -> Array:
	var starts: Array = clock["starts"]
	var ends: Array = clock["ends"]
	var spans: Array = []
	for i in range(1, ends.size()):
		spans.append((int(ends[i]) - int(starts[i - 1])) / 1000.0)
	return spans


## The machine's pace (PIX-445): a fixed piece of work, the same in every
## build of the game, a round of which `once` times in ms. A frame's own mix,
## in three parts about as long as each other on CI: GDScript's loops and
## maths with calls into the engine, a crowd of script objects each ticked
## in turn (the foes and the folk), and reads scattered over 4 MB (a frame's
## nodes lie all over memory). Each part alone followed the frame on some of
## CI's machines and not others (the Intel ran tight loops 25 % faster than
## the AMDs, and the game's frames no faster); the three together held on all.
class Pace:
	var _node := Node2D.new()
	var _kept := {}
	var _crowd: Array[Walker] = []
	var _table := {&"foe": 3}
	var _far := PackedInt32Array()
	var _sink := 0.0

	func _init() -> void:
		for i in 140:
			_crowd.append(Walker.new(Vector2(i % 9, i % 7)))
		_far.resize(1 << 20)

	## One round, in ms.
	func once() -> float:
		var start := Time.get_ticks_usec()
		for i in 200:
			var at := Vector2(i % 31, i % 17) * 0.5
			_node.position = at.rotated(i * 0.01)
			_kept[i % 64] = _node.position.length() + float(_kept.get(i % 64, 0.0))
		for walker in _crowd:
			_sink += walker.tick(0.016, _table)
		var hop := 1
		for i in 1300:
			hop = (hop * 1103515245 + 12345) & 0xFFFFF
			_sink += _far[hop]
		return (Time.get_ticks_usec() - start) / 1000.0

	func done() -> void:
		_node.free()


## One of the pace's crowd: a foe's tick, more or less.
class Walker:
	var at: Vector2
	var heading := Vector2.RIGHT
	var hp := 10
	var tag := &"foe"

	func _init(from: Vector2) -> void:
		at = from

	func tick(dt: float, table: Dictionary) -> float:
		at += heading * dt
		if at.x > 8.0:
			heading = -heading
			hp -= 1
		return float(table.get(tag, 0)) + at.length_squared()


## How many particles the emitting systems under `node` hold.
static func particles(node: Node) -> int:
	var count := 0
	if node is CPUParticles2D and (node as CPUParticles2D).emitting:
		count += (node as CPUParticles2D).amount
	for child in node.get_children():
		count += particles(child)
	return count


## "average/95th percentile" of a list of milliseconds, "-" for none.
static func summary(values: Array) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	return "%.2f/%.2f" % [total / sorted.size(), float(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))])]


## "median/95th percentile" of a list of milliseconds, "-" for none: the
## median, which a frame the machine took for something else doesn't move.
static func spread(values: Array) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	return "%.2f/%.2f" % [float(sorted[sorted.size() / 2]), float(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))])]
