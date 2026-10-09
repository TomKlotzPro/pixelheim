class_name PerfProbe
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
