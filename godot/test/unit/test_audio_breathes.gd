extends GutTest
## Audio that breathes (PIX-212): a stinger is never the same twice, the
## same one within a breath sounds once, steps alternate at their own
## level, every family keeps voices of its own (PIX-411) so a busy fight
## never silences a step or a page, and the quiet answers (yes, no, a page,
## an ailment) are there to be played.
## PIX-383: the game at a normal loudness, a limiter on Master.
## The game's own takes throughout, the packs' held back as `cc0` holds them.


func before_each() -> void:
	Sound.withheld = true
	_hush()


func after_each() -> void:
	_hush()
	Sound.withheld = false


func _hush() -> void:
	for voice in Sound._voices():
		voice.stop()
	Sound._played_at.clear()
	Sound._began.clear()
	Sound._last.clear()
	if Sound._duck != null:
		Sound._duck.kill()
	Sound._set_ducked(0.0)


func _playing(sfx: String) -> Array:
	return Sound._voices().filter(func(voice: AudioStreamPlayer) -> bool:
		return voice.playing and voice.stream != null and voice.stream.resource_path.ends_with("/%s.wav" % sfx))


func test_a_stinger_varies_and_sounds_once_in_a_breath() -> void:
	Sound.play("hit_blade")
	Sound.play("hit_crit")
	var heard := _playing("hit")
	assert_eq(heard.size(), 1, "two hits in one frame sound once, whatever moments asked")
	assert_between(heard[0].pitch_scale, 1.0 - Sound.VARY_PITCH, 1.0 + Sound.VARY_PITCH)
	assert_between(heard[0].volume_db, -Sound.VARY_DB, Sound.VARY_DB)
	Sound._played_at.clear()
	Sound.play("hit_blade", false)
	assert_eq(_playing("hit").filter(func(voice: AudioStreamPlayer) -> bool: return voice.pitch_scale == 1.0).size(), 1, "unvaried when asked")


## The audio pass: each sound at its measured level, the hero's hurt lifted
## to sit beside their hit.
func test_a_stinger_plays_at_its_own_level() -> void:
	var level := Sound.level_of("sfx/hurt")
	assert_gt(level, 0.0)
	Sound.play("hurt")
	assert_between(_playing("hurt")[0].volume_db, level - Sound.VARY_DB, level + Sound.VARY_DB)


func test_steps_alternate_at_their_own_level() -> void:
	var family: Dictionary = Sound._doc["families"]["step"]
	Sound.play("step_grass")
	var first: AudioStreamPlayer = _playing("step")[0]
	var first_pitch := first.pitch_scale
	assert_eq(first.volume_db, float(family["db"]), "the step family's level, unvaried")
	Sound._played_at.clear()
	Sound.play("step_stone")
	# The first step is short and may have finished on a slow runner, so look only for the new voice.
	var others: Array = _playing("step").filter(func(voice: AudioStreamPlayer) -> bool: return voice != first)
	assert_eq(others.size(), 1, "a second voice")
	if not others.is_empty():
		assert_ne(others[0].pitch_scale, first_pitch, "left foot, right foot")
	assert_true(family["feet"].any(func(pitch: float) -> bool: return is_equal_approx(pitch, first_pitch)), "one of the two feet")


## PIX-411: each family its own voices. A fight using every one of its
## blows' still lets a step, a tick and the hero's hurt be heard, and a new
## blow takes the oldest of its own.
func test_every_family_keeps_voices_of_its_own() -> void:
	var blows: Array = Sound._pools["blow"]
	for i in blows.size():
		Sound._played_at.clear()
		Sound.play("hit_blade")
	assert_eq(_playing("hit").size(), blows.size(), "every blow's voice busy")
	Sound.play("hurt")
	Sound.play("step_grass")
	Sound.play("ui_tick")
	assert_eq(_playing("hurt").size(), 1, "the hero's hurt is heard")
	assert_eq(_playing("step").size(), 1, "and their step")
	assert_true(Sound._pools["ui"].any(func(voice: AudioStreamPlayer) -> bool: return voice.playing), "and the page's tick")
	Sound._played_at.clear()
	var oldest: AudioStreamPlayer = blows[0]
	Sound._began[oldest] = -1
	Sound.play("hit_blunt")
	assert_eq(_playing("hit").size(), blows.size(), "a new blow takes the oldest of its own")
	assert_ne(Sound._began[oldest], -1, "the one that began first")
	for family: String in Sound._doc["families"]:
		var bus: String = Sound._doc["families"][family]["bus"]
		assert_true(Sound._pools[family].all(func(voice: AudioStreamPlayer) -> bool: return voice.bus == bus), "%s on %s" % [family, bus])


func test_the_quiet_answers_are_there() -> void:
	for name: String in ["confirm", "deny", "page", "ail"]:
		assert_true(Sound.UI_SOUNDS.has(name), name)
	assert_false(autofree(preload("res://scripts/title_screen.gd").new())._eases_in(), "the title makes its own entrance")


## PIX-383: every bus LOUDNESS_DB over the player's slider, so the mix keeps
## its balance and the options' sliders work as before; nought is silent.
## PIX-411: the pages and the jingles on the effects' slider, the ambience
## on its own, where it sat under the effects'.
func test_every_bus_is_as_loud_over_its_slider() -> void:
	var settings: GameSettings = GameState.settings
	Sound.apply_volumes()
	var level := func(bus: String) -> float: return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	assert_almost_eq(level.call("Music"), linear_to_db(maxf(settings.music_volume, 0.0001)) + Sound.LOUDNESS_DB, 0.01)
	for bus: String in ["SFX", "UI", "Jingle"]:
		assert_almost_eq(level.call(bus), linear_to_db(maxf(settings.sfx_volume, 0.0001)) + Sound.LOUDNESS_DB, 0.01, bus)
	assert_almost_eq(level.call("Ambience"), Sound.bus_db(settings.ambience_volume * Sound.AMBIENCE_SHARE), 0.01)
	assert_almost_eq(Sound.bus_db(0.7), -3.1 + Sound.LOUDNESS_DB, 0.01, "the default 70%")
	assert_almost_eq(Sound.bus_db(0.0), -80.0, 0.01, "nought as silent as it was")


## PIX-383: Master carries one hard limiter, its ceiling under 0 dBFS, so
## sounds stacked at once never clip.
func test_master_carries_a_limiter() -> void:
	var limiters := range(AudioServer.get_bus_effect_count(0)).filter(func(index: int) -> bool:
		return AudioServer.get_bus_effect(0, index) is AudioEffectHardLimiter)
	assert_eq(limiters.size(), 1, "one limiter on Master")
	var limiter := AudioServer.get_bus_effect(0, limiters[0]) as AudioEffectHardLimiter
	assert_true(AudioServer.is_bus_effect_enabled(0, limiters[0]))
	assert_eq(limiter.ceiling_db, Sound.CEILING_DB)
	assert_lt(limiter.ceiling_db, 0.0)


## PIX-383: a move on a screen ticks, unless what it did made a sound of
## its own (a page turned): never both.
func test_a_move_ticks_unless_it_made_its_own_sound() -> void:
	var before := Sound.asked
	Sound._tick_unless_heard(before)
	assert_eq(Sound.asked, before + 1, "a plain move ticks")
	_hush()
	before = Sound.asked
	Sound.play("ui_page")
	Sound._tick_unless_heard(before)
	assert_eq(Sound.asked, before + 1, "the page alone")


## PIX-411: a moment the game has no sound for yet is silent, and asks for none.
func test_a_moment_without_a_take_is_silent() -> void:
	assert_eq(Sound.takes_of("foe_bite"), [], "no take of the game's own")
	var before := Sound.asked
	Sound.play("foe_bite")
	assert_eq(Sound.asked, before, "nothing played")
