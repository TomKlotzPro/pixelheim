extends GutTest
## The game's clock (PIX-276): the world's time in physics ticks, which every
## "how long since" in play reads, so a stepped harness run (tools/flows.sh,
## --fixed-fps) lives the same seconds however fast the machine draws it.
## The machine's clock is for measuring the machine alone.

## The scripts that time the machine itself, and may read its clock: what a
## frame costs, what a map's build costs, what entering a map costs, and the
## milliseconds a frame of drawing the map beside the hero may take (One
## Reach, PIX-269: Slicer's budget is the machine's work).
const MEASURES := ["perf_probe.gd", "map_view.gd", "harness.gd", "slicer.gd"]


func test_it_counts_the_physics_ticks() -> void:
	var before := GameClock.msec()
	var seconds := GameClock.seconds()
	for tick in 6:
		await get_tree().physics_frame
	assert_eq(GameClock.msec() - before, 6 * 1000 / Engine.physics_ticks_per_second, "six ticks, a tenth of a second")
	assert_almost_eq(GameClock.seconds() - seconds, 0.1, 0.0001)


func test_play_reads_the_game_clock_not_the_machines() -> void:
	var machine := RegEx.create_from_string("Time\\.get_ticks_(msec|usec)")
	var scripts := _scripts("res://scripts")
	assert_gt(scripts.size(), 50)
	for path: String in scripts:
		if path.get_file() in MEASURES:
			continue
		var found := machine.search(scripts[path])
		assert_null(found, "%s reads GameClock (%s is the machine's clock)" % [path, found.get_string() if found else ""])


func test_a_harness_run_throws_the_same_dice() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/state/game_state.gd")
	assert_string_contains(source, "seed(HARNESS_SEED)")
	seed(GameState.HARNESS_SEED)
	var first := [randf(), randi(), [1, 2, 3, 4, 5].pick_random()]
	seed(GameState.HARNESS_SEED)
	assert_eq([randf(), randi(), [1, 2, 3, 4, 5].pick_random()], first)
	randomize()


## path -> source of every script under `folder`.
func _scripts(folder: String) -> Dictionary:
	var out := {}
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			out[folder + "/" + file] = FileAccess.get_file_as_string(folder + "/" + file)
	for sub in DirAccess.get_directories_at(folder):
		out.merge(_scripts(folder + "/" + sub))
	return out
