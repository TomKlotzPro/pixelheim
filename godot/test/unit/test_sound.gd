extends GutTest
## Sound (PIX-128): the web synth's renders are all present, and each place,
## floor and fight gets the theme and weather the web would give it
## (trackForState, ambienceForState).

const DOC := "res://assets/data/audio.json"


func test_every_rendered_sound_is_shipped() -> void:
	var doc: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(DOC))
	for sfx: String in doc["stingers"]:
		assert_true(ResourceLoader.exists("res://assets/audio/sfx/%s.wav" % sfx), sfx)
	for track: String in doc["tracks"]:
		assert_true(ResourceLoader.exists("res://assets/audio/music/%s.wav" % track), track)
		assert_gt(float(doc["tracks"][track]["seconds"]), 1.0)
	for place: String in doc["ambience"]:
		for index in doc["ambience"][place].size():
			for variant in int(doc["ambience"][place][index]["variants"]):
				assert_true(ResourceLoader.exists("res://assets/audio/ambience/%s_%d_%d.wav" % [place, index, variant]))
	assert_eq(doc["stingers"].size(), 17, "the web's SFX, all of them")
	assert_eq(doc["tracks"].size(), 10)


func test_places_and_fights_choose_the_webs_themes() -> void:
	assert_eq(Sound.track_for("town", 0, ""), "town")
	assert_eq(Sound.track_for("overworld", 0, ""), "world")
	assert_eq(Sound.track_for("deepwood", 0, ""), "deepwood")
	assert_eq(Sound.track_for("town_inn", 0, ""), "interior")
	assert_eq(Sound.track_for("floor_3", 3, ""), "descent", "below ground")
	assert_eq(Sound.track_for("overworld", 0, "battle"), "battle", "a hunt takes over")
	assert_eq(Sound.track_for("floor_10", 10, "boss"), "boss")


func test_the_weather_follows_the_place() -> void:
	assert_eq(Sound.ambience_for("overworld", 0), "greenwood")
	assert_eq(Sound.ambience_for("town", 0), "greenwood")
	assert_eq(Sound.ambience_for("deepwood", 0), "deepforest")
	assert_eq(Sound.ambience_for("mirefen", 0), "marsh")
	assert_eq(Sound.ambience_for("town_house", 0), "indoor")
	assert_eq(Sound.ambience_for("floor_1", 1), "indoor")


func test_music_loops_its_whole_render() -> void:
	Sound.play_track("world")
	var stream := load("res://assets/audio/music/world.wav") as AudioStreamWAV
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_gt(stream.loop_end, 0)
	Sound.stop_music()


func test_the_pages_sounds_are_short_audible_blips() -> void:
	var script := preload("res://scripts/sound.gd")
	for name: String in script.UI_SOUNDS:
		var stream: AudioStreamWAV = script._synth(script.UI_SOUNDS[name])
		var seconds := 0.0
		var samples := 0
		for blip: Array in script.UI_SOUNDS[name]:
			seconds += float(blip[0])
			samples += int(float(blip[0]) * script.UI_RATE)
		assert_eq(stream.data.size(), samples * 2, "%s: 16-bit mono, every blip in turn" % name)
		assert_lt(seconds, 0.15, "%s stays a blip" % name)
		var loud := 0
		for i in range(0, stream.data.size(), 2):
			var sample := stream.data.decode_s16(i)
			loud = maxi(loud, absi(sample))
		assert_gt(loud, 1000, "%s can be heard" % name)
