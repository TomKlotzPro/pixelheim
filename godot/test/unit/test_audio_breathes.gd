extends GutTest
## Audio that breathes (PIX-212): a stinger is never the same twice, the
## same one within a breath sounds once, steps alternate at their own
## level, a sound that matters takes a voice when all are busy, and the
## quiet answers (yes, no, a page, an ailment) are there to be played.
## PIX-383: the game at a normal loudness, a limiter on Master.


func before_each() -> void:
	_hush()


func after_each() -> void:
	_hush()


func _hush() -> void:
	for voice in Sound._voices:
		voice.stop()
	Sound._sfx_at.clear()
	Sound._played_at.clear()
	Sound._began.clear()


func _playing(sfx: String) -> Array:
	return Sound._voices.filter(func(voice: AudioStreamPlayer) -> bool:
		return voice.playing and voice.stream != null and voice.stream.resource_path.ends_with("/%s.wav" % sfx))


func test_a_stinger_varies_and_sounds_once_in_a_breath() -> void:
	Sound.play("hit")
	Sound.play("hit")
	var heard := _playing("hit")
	assert_eq(heard.size(), 1, "two hits in one frame sound once")
	assert_between(heard[0].pitch_scale, 1.0 - Sound.VARY_PITCH, 1.0 + Sound.VARY_PITCH)
	assert_between(heard[0].volume_db, -Sound.VARY_DB, Sound.VARY_DB)
	Sound._sfx_at.clear()
	Sound.play("hit", false)
	assert_eq(_playing("hit").filter(func(voice: AudioStreamPlayer) -> bool: return voice.pitch_scale == 1.0).size(), 1, "unvaried when asked")


## The audio pass: each sound at its measured level, the hero's hurt lifted
## to sit beside their hit.
func test_a_stinger_plays_at_its_own_level() -> void:
	var level := Sound.level_of("sfx/hurt")
	assert_gt(level, 0.0)
	Sound.play("hurt")
	assert_between(_playing("hurt")[0].volume_db, level - Sound.VARY_DB, level + Sound.VARY_DB)


func test_steps_alternate_at_their_own_level() -> void:
	Sound.play("step")
	var first: AudioStreamPlayer = _playing("step")[0]
	var first_pitch := first.pitch_scale
	assert_eq(first.volume_db, Sound.STEP_DB)
	Sound._sfx_at.clear()
	Sound.play("step")
	# The first step is short and may have finished on a slow runner, so look only for the new voice.
	var others: Array = _playing("step").filter(func(voice: AudioStreamPlayer) -> bool: return voice != first)
	assert_eq(others.size(), 1, "a second voice")
	if not others.is_empty():
		assert_ne(others[0].pitch_scale, first_pitch, "left foot, right foot")
	assert_true(Sound.STEP_PITCHES.any(func(pitch: float) -> bool: return is_equal_approx(pitch, first_pitch)), "one of the two feet")


func test_a_sound_that_matters_takes_a_voice_when_all_are_busy() -> void:
	for i in Sound.SFX_VOICES:
		Sound._sfx_at.clear()
		Sound.play("coin")
	assert_eq(_playing("coin").size(), Sound.SFX_VOICES, "every voice busy")
	Sound._sfx_at.clear()
	Sound.play("drop")
	assert_eq(_playing("drop").size(), 0, "a small sound waits its turn")
	Sound.play("hurt")
	assert_eq(_playing("hurt").size(), 1, "the hero's hurt is always heard")


func test_the_quiet_answers_are_there() -> void:
	for name: String in ["confirm", "deny", "page", "ail"]:
		assert_true(Sound.UI_SOUNDS.has(name), name)
	assert_false(autofree(preload("res://scripts/title_screen.gd").new())._eases_in(), "the title makes its own entrance")


## PIX-383: every bus LOUDNESS_DB over the player's slider, so the mix keeps
## its balance and the options' sliders work as before; nought is silent.
func test_every_bus_is_as_loud_over_its_slider() -> void:
	var settings: GameSettings = GameState.settings
	Sound.apply_volumes()
	var music := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	var sfx := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	assert_almost_eq(music, linear_to_db(maxf(settings.music_volume, 0.0001)) + Sound.LOUDNESS_DB, 0.01)
	assert_almost_eq(sfx, linear_to_db(maxf(settings.sfx_volume, 0.0001)) + Sound.LOUDNESS_DB, 0.01)
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
	Sound.play_ui("page")
	Sound._tick_unless_heard(before)
	assert_eq(Sound.asked, before + 1, "the page alone")
