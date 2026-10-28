extends Node
## areas: all
## The agent verification harness, loaded only for `--screenshot` runs
## (world.gd adds it; it never ships in play): headless Godot cannot render,
## so it drives a real window briefly - warps, keys, screens, fights - saves
## screenshot.png, prints a report line (HarnessReport: every field in its
## table, PIX-273), and quits:
## `godot --path godot -- --screenshot [fight] [kill] [saves] [--map <id>]
## [--walk l,d,r,u,...] [--slots <dir>] ...`. Every flag is declared once
## in HarnessFlags.TABLE (scripts/harness_flags.gd, PIX-262), which
## `-- --help` prints; the release flows (tools/flows.sh) drive it. A flag's
## step is its row's (PIX-357): a function of scripts/harness_steps/, run at
## its order; what's set before the first map is HarnessBoot's.

## The device id the harness stamps on the keys it presses (`--keys`).
const DEVICE := 77

var world: Node
## `--draw-every N` (PIX-276): a windowed run draws one frame in N, and
## every frame where it reads the screen (the motion check's walk, the
## picture at the end). Stepped (tools/flows.sh), the game is the same
## drawn or not: nothing it decides reads what was drawn, a frame's time
## is a sixtieth of a second either way, and its particles and shaders run
## on the game's own clock (only the water's tile frames count drawn
## frames, so they ripple slower). Software rendering (CI's windows) takes
## most of a second a frame, and drawing all sixty of each second made a
## flow several times slower than headless.
var _draw_every := 0
var _draw_all := false


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		_draw_every = int(HarnessFlags.given().value("--draw-every", "0"))
	_run_test_harness()


func _process(_delta: float) -> void:
	if _draw_every > 1:
		RenderingServer.render_loop_enabled = _draw_all or Engine.get_process_frames() % _draw_every == 0


## Every frame drawn from now on (`--draw-every`), this one too.
func _draw_every_frame() -> void:
	_draw_all = true
	RenderingServer.render_loop_enabled = true


## Keys from anyone but the harness are dropped, paused or not: the window
## opens on the desktop of someone who may be typing elsewhere, and a stray D
## would walk the hero or close a conversation mid-shot. (The world used to
## filter, but a paused world hears nothing, so a conversation took them.)
## The Input singleton has already counted the key, so its actions are let
## go too, or movement, which reads them, would still walk.
func _input(event: InputEvent) -> void:
	if event.device == DEVICE:
		return
	get_viewport().set_input_as_handled()
	for action: StringName in InputMap.get_actions():
		if event.is_action(action, true):
			Input.action_release(action)


## `--keys e,e,esc,...` presses real keys, one at a time, as a player would.
func _keys(flags: HarnessFlags) -> void:
	if not flags.has("--keys"):
		return
	var codes := {
		"e": KEY_E, "esc": KEY_ESCAPE, "space": KEY_SPACE, "enter": KEY_ENTER, "s": KEY_S, "w": KEY_W,
		"i": KEY_I, "q": KEY_Q, "k": KEY_K, "c": KEY_C, "m": KEY_M, "b": KEY_B, "shift": KEY_SHIFT,
		"r": KEY_R, "a": KEY_A, "d": KEY_D, "z": KEY_Z, "x": KEY_X, "f": KEY_F, "tab": KEY_TAB,
		"n": KEY_N,
	}
	# A pad's buttons by name (PIX-388: Back opens the dock's menu, the D-pad steers it).
	var pad := {"back": JOY_BUTTON_BACK, "pad_up": JOY_BUTTON_DPAD_UP, "pad_down": JOY_BUTTON_DPAD_DOWN}
	for key: String in flags.list("--keys"):
		await _tap(KEY_NONE if pad.has(key) else codes[key], pad.get(key, JOY_BUTTON_INVALID))
	await get_tree().create_timer(0.2).timeout


## One key (or a pad's `button`) pressed and let go, as a hand would.
func _tap(keycode: Key, button := JOY_BUTTON_INVALID) -> void:
	for pressed: bool in [true, false]:
		_press(keycode, pressed, button)
		# Held through two physics ticks too: walking and facing are read
		# there, and a run stepped faster than its ticks (`--fps`) draws
		# frames between them.
		await get_tree().process_frame
		await get_tree().physics_frame
		await get_tree().physics_frame
		await get_tree().process_frame
	# Paced in the game's time as well as frames, as a hand is: a
	# screen that ignores the press that opened it would miss the next.
	await get_tree().create_timer(0.08).timeout


## The villager `id` standing on this map, or null when they aren't here.
func _villager(id: String) -> Node:
	for villager in get_tree().get_nodes_in_group("npcs"):
		if not villager.away and String(villager.data.get("id", "")) == id:
			return villager
	return null


## A harness key press, as a player's would land: the Input singleton's
## actions (what polling reads) and the event itself, straight to the
## viewport, which needs no window focus (an unfocused window's keys are
## dropped by the display server).
func _press(keycode: Key, pressed: bool, button := JOY_BUTTON_INVALID) -> void:
	var event: InputEvent
	if button != JOY_BUTTON_INVALID:
		var held := InputEventJoypadButton.new()
		held.button_index = button
		held.pressed = pressed
		event = held
	else:
		var key := InputEventKey.new()
		key.physical_keycode = keycode
		key.keycode = keycode
		key.pressed = pressed
		event = key
	event.device = DEVICE
	for action: StringName in InputMap.get_actions():
		if InputMap.event_is_action(event, action, true):
			if pressed:
				Input.action_press(action)
			else:
				Input.action_release(action)
	get_viewport().push_input(event)


## How far the building rising on the town's tour had got when last seen
## (`--rise`, PIX-264): it goes once its confetti has fallen, built.
var _rise_phase := "none"


## The building rising on the town's tour, while it's there.
func _rise() -> RebuildRise:
	var rise := get_tree().get_first_node_in_group(RebuildRise.GROUP) as RebuildRise
	if rise != null:
		_rise_phase = rise.phase
	return rise


## The ascension (PIX-244), while it's open.
func _ascension() -> Node:
	for node in world.get_children():
		if node.get_script() == preload("res://scripts/rankup_screen.gd"):
			return node
	return null


## The steps' scripts, an area each (PIX-357): the step a flag names in
## harness_flags.txt is its `step_<name>()` in one of them; a feature's
## (PIX-369) is its feature.gd's `step_<name>(h)`.
const STEPS := [
	preload("res://scripts/harness_steps/world.gd"),
	preload("res://scripts/harness_steps/travel.gd"),
	preload("res://scripts/harness_steps/combat.gd"),
	preload("res://scripts/harness_steps/story.gd"),
	preload("res://scripts/harness_steps/screens.gd"),
	preload("res://scripts/harness_steps/measure.gd"),
]

## The run's flags, parsed once (HarnessFlags.given()).
var flags: HarnessFlags
## The report line's fields (HarnessReport.TABLE); a value known only
## part-way through is noted as it's known.
var report: HarnessReport
## `cpu`'s clock (PerfProbe.clock), read into the report at the end.
var cpu := {}
## `perf`'s line (PerfProbe.sample), for the web page's numbers.
var perf := ""


## Runs the steps of the flags it was given, in the table's order (each
## row's `order`, PIX-357), whatever the command line's, then shoots and
## quits. Every flag is declared in HarnessFlags.TABLE (PIX-262) and read
## from its one parse of the command line; `-- --help` prints the table.
func _run_test_harness() -> void:
	flags = HarnessFlags.given()
	if not flags.has("--screenshot"):
		return
	if HarnessBoot.failed_to_load(get_tree(), STEPS):
		return
	for problem in flags.problems:
		push_warning("harness: %s (-- --help lists the flags)" % problem)
	# `--dissolve-at S`: a door's dissolve held S seconds in (PIX-269).
	if flags.has("--dissolve-at"):
		Dissolve.held_at = float(flags.value("--dissolve-at"))
	await get_tree().create_timer(0.4).timeout
	report = HarnessReport.new(self, flags)
	var areas: Array = STEPS.map(func(script: GDScript) -> Object:
		var area: Object = script.new()
		area.h = self
		area.world = world
		area.flags = flags
		area.report = report
		return area)
	for row: Dictionary in flags.steps():
		var step := "step_" + String(row["step"])
		# A feature's flag is its own feature.gd's step, given the harness (PIX-369).
		if row.has("feature"):
			await row["feature"].call(step, self)
		else:
			await areas.filter(func(area: Object) -> bool: return area.has_method(step))[0].call(step)
	# What the run left: every field the report has (HarnessReport.TABLE),
	# read at the same step whether the run has a window or not (PIX-276):
	# a windowed run read it after its picture, which takes frames of its
	# own, so its report was a few steps later than a quiet run's.
	await get_tree().process_frame
	if not cpu.is_empty():
		report.note("cpu", PerfProbe.cpu(get_tree(), cpu))
	var line := report.line()
	# A quiet run (--headless: no window, nothing drawn) has no picture.
	if DisplayServer.get_name() != "headless":
		_draw_every_frame()
		await RenderingServer.frame_post_draw
		# As the screen shows it (the desktop app's canvas is linear light),
		# where `--shot` says (PIX-270): the flows run side by side, and one
		# shared screenshot.png would be whichever run saved last.
		(await DesktopLook.snapshot(self)).save_png(flags.value("--shot", "res://screenshot.png"))
	print(line)
	# The web build's numbers on its page (PIX-361), where tools/web_perf.py
	# reads them: a page's console is no file to grep.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.pixelheimPerf = " + JSON.stringify({
			"map": world.map.id, "cpu": report.noted("cpu"), "frames": report.noted("frames"), "perf": perf, "report": line}))
	# `--batch` (PIX-360): the batch's next flow, from a boot's state.
	if HarnessBoot.next_flow(get_tree()):
		return
	# Let the audio server let go of every sound before the engine shuts down
	# (PIX-379: one still playing leaked at exit, its AudioStreamWAV and
	# playback). Its mixer retires a stopped sound on its own thread, in the
	# machine's time, which a stepped run's frames outrun; the frame after
	# frees it.
	get_tree().paused = true  # nothing may start a track again
	Sound.stop_all()
	Sound.release()
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit()
