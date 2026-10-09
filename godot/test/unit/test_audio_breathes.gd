extends GutTest
## Audio that breathes (PIX-212): a stinger is never the same twice, the
## same one within a breath sounds once, steps go soft and alternate, a
## sound that matters takes a voice when all are busy, and the quiet
## answers (yes, no, a page, an ailment) are there to be played.


func before_each() -> void:
	_hush()


func after_each() -> void:
	_hush()


func _hush() -> void:
	for voice in Sound._voices:
		voice.stop()
	Sound._sfx_at.clear()
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


func test_steps_are_soft_and_alternate() -> void:
	Sound.play("step")
	var first: AudioStreamPlayer = _playing("step")[0]
	var first_pitch := first.pitch_scale
	assert_eq(first.volume_db, Sound.STEP_DB)
	Sound._sfx_at.clear()
	Sound.play("step")
	var pitches: Array = _playing("step").map(func(voice: AudioStreamPlayer) -> float: return voice.pitch_scale)
	assert_eq(pitches.size(), 2)
	assert_ne(pitches[0], pitches[1], "left foot, right foot")
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
