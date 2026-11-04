extends GutTest
## Sound (PIX-128): the web synth's renders are all present, and each place,
## floor and fight gets the theme and weather the web would give it
## (trackForState, ambienceForState); the sound pass's renders (PIX-158) too,
## with its themes, extras and beds. PIX-411: every moment an event of its
## own, its takes the game's or the packs', the music stepping back under a
## jingle and taken up where it was left, a step for every ground.

const DOC := "res://assets/data/audio.json"


func after_each() -> void:
	Sound.withheld = false


func test_every_rendered_sound_is_shipped() -> void:
	var doc: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(DOC))
	var stingers := {}
	for event: String in doc["events"]:
		for take: String in doc["events"][event]["takes"]:
			if take.begins_with("sfx/"):
				stingers[take] = true
				assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % take), "%s: %s" % [event, take])
	for track: String in doc["tracks"]:
		assert_true(ResourceLoader.exists("res://assets/audio/music/%s.wav" % track), track)
		assert_gt(float(doc["tracks"][track]["seconds"]), 1.0)
	for place: String in doc["ambience"]:
		for index in doc["ambience"][place].size():
			for variant in int(doc["ambience"][place][index]["variants"]):
				assert_true(ResourceLoader.exists("res://assets/audio/ambience/%s_%d_%d.wav" % [place, index, variant]))
	assert_eq(stingers.size(), 22, "the web's 17 SFX, then the dodge, the roar and the bounty (PIX-158), Teo's bell (PIX-253 step 9), and a way out rising where a boss fell (PIX-339), every one some moment's")
	assert_eq(doc["tracks"].size(), 10)


## The sound pass (PIX-158): every render tools/synth.py makes is shipped.
func test_the_newer_sounds_are_shipped() -> void:
	var doc: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(DOC))
	for name: String in doc["ambienceExtras"]:
		for variant in int(doc["ambienceExtras"][name]["variants"]):
			assert_true(ResourceLoader.exists("res://assets/audio/ambience/%s_%d.wav" % [name, variant]), name)
	for name: String in doc["beds"]:
		assert_true(ResourceLoader.exists("res://assets/audio/ambience/bed_%s.wav" % name), name)
	for name: String in doc["themes"]:
		assert_true(ResourceLoader.exists("res://assets/audio/music/theme_%s.wav" % name), name)
	for scene_id: String in ["ending_home", "ending_stay"]:
		var themes: Array = Cutscene.scenes()[scene_id].filter(func(step: Dictionary) -> bool: return step["kind"] == "theme")
		assert_eq(themes.size(), 1, "%s opens with its theme" % scene_id)
		assert_true(doc["themes"].has(themes[0]["name"]))


func test_a_theme_plays_once_then_hands_over() -> void:
	Sound.play_theme("dawn", "victory")
	assert_eq(Sound.track, "theme:dawn")
	var stream := load("res://assets/audio/music/theme_dawn.wav") as AudioStreamWAV
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_DISABLED)
	Sound._theme_over(Sound._music)
	assert_eq(Sound.track, "victory", "then what it named")
	Sound.play_theme("ending")
	Sound._theme_over(Sound._music)
	assert_eq(Sound.track, "", "or nothing, for the world to choose")
	Sound.stop_music()


func test_extras_and_beds_take_only_what_exists() -> void:
	Sound.set_extras(["birds", "thunder", "fire"] as Array[String])
	assert_eq(Sound.extras, ["birds", "fire"] as Array[String])
	Sound.set_bed("wind")
	assert_eq(Sound.bed, "wind")
	Sound.set_bed("rain")
	assert_eq(Sound.bed, "rain", "a shower's (PIX-224)")
	Sound.set_bed("thunder")
	assert_eq(Sound.bed, "", "an unknown bed is silence")
	Sound.stop_all()
	assert_eq(Sound.extras, [] as Array[String])


func test_places_and_fights_choose_the_webs_themes() -> void:
	assert_eq(Sound.track_for("town", ""), "town")
	assert_eq(Sound.track_for("overworld", ""), "world")
	assert_eq(Sound.track_for("deepwood", ""), "deepwood")
	assert_eq(Sound.track_for("town_inn", ""), "interior")
	assert_eq(Sound.track_for("seacave_galleries", ""), "descent", "below ground")
	assert_eq(Sound.track_for("vault_3", ""), "descent", "the Kings' Vault too (PIX-257)")
	assert_eq(Sound.track_for("overworld", "battle"), "battle", "a hunt takes over")
	assert_eq(Sound.track_for("vault_5", "boss"), "boss")


func test_the_weather_follows_the_place() -> void:
	assert_eq(Sound.ambience_for("overworld"), "greenwood")
	assert_eq(Sound.ambience_for("town"), "greenwood")
	assert_eq(Sound.ambience_for("deepwood"), "deepforest")
	assert_eq(Sound.ambience_for("mirefen"), "marsh")
	assert_eq(Sound.ambience_for("town_house"), "indoor")
	assert_eq(Sound.ambience_for("vault_1"), "indoor")
	# The Kings' Vault breathes the deeper wind (PIX-257); the caves their own.
	assert_eq(Depths.wind("vault_2"), "deepwind")
	assert_eq(Depths.wind("seacave"), "wind")


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


## PIX-411: every event belongs to a family the game has, on a bus it has,
## and every take it names is there: a rendered stinger, a blip made in
## sound.gd; the tables that choose one (a weapon's blow, a skill's theme, a
## foe's family, the ground) name events that are.
func test_every_event_resolves() -> void:
	var doc: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(DOC))
	for family: String in doc["families"]:
		assert_gt(AudioServer.get_bus_index(doc["families"][family]["bus"]), 0, family)
		assert_gt(int(doc["families"][family]["voices"]), 0, family)
	for event: String in doc["events"]:
		var entry: Dictionary = doc["events"][event]
		assert_true(doc["families"].has(entry["family"]), "%s: its family" % event)
		for take: String in entry["takes"]:
			if take.begins_with("blip/"):
				assert_true(Sound.UI_SOUNDS.has(take.trim_prefix("blip/")), "%s: %s" % [event, take])
			else:
				assert_true(take.begins_with("sfx/") and ResourceLoader.exists("res://assets/audio/%s.wav" % take), "%s: %s" % [event, take])
	for table: String in ["blows", "casts", "steps"]:
		for key: String in doc[table]:
			assert_true(doc["events"].has(doc[table][key]), "%s: %s" % [table, key])
	for family: String in Bestiary.family_names():
		assert_true(doc["events"].has("kill_" + family), "a fall for %s" % family)
	assert_eq(Sound.kill_for("skeleton"), "kill_undead")
	assert_eq(Sound.kill_for("no_such_foe"), "kill", "a foe of no family falls plainly")
	assert_eq(Sound.blow_for(""), "hit_blade", "bare hands, a blade's blow")
	assert_eq(Sound.blow_for("hunting_bow"), "hit_arrow")
	assert_eq(Sound.blow_for("war_hammer"), "hit_blunt")
	assert_eq(Sound.blow_for("apprentice_staff"), "hit_spell")
	assert_eq(Sound.cast_for("Fireball"), "cast_fire")
	assert_eq(Sound.cast_for("No Such Skill"), "cast")


## PIX-411: a take is never the one its event played last, and every one
## of them comes up.
func test_no_take_plays_twice_running() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 411
	var last := -1
	var seen := {}
	for i in 300:
		var index := Sound.pick(4, last, dice)
		assert_ne(index, last)
		assert_between(index, 0, 3)
		seen[index] = true
		last = index
	assert_eq(seen.size(), 4, "every take comes up")
	assert_eq(Sound.pick(1, 0, dice), 0, "a lone take plays every time")
	# Through play: three takes standing in for a hit's.
	var saved: Dictionary = Sound._paid
	Sound._paid = {"hit_blade": ["sfx/hit", "sfx/hurt", "sfx/coin"]}
	var before := -1
	for i in 20:
		Sound._played_at.clear()
		Sound.play("hit_blade")
		assert_ne(int(Sound._last["hit_blade"]), before)
		before = int(Sound._last["hit_blade"])
	Sound._paid = saved
	Sound._last.clear()


## PIX-411: without the packs' takes (a fork's build, `cc0`), every event
## plays its own; a list naming takes that aren't here gives none.
func test_without_the_packs_every_event_plays_its_own() -> void:
	assert_eq(Sound.paid_takes("user://no_such_takes.json"), {})
	var list := "user://pix411_takes.json"
	var file := FileAccess.open(list, FileAccess.WRITE)
	file.store_string(JSON.stringify({"events": {"hit_blade": ["not_here_1"]}}))
	file.close()
	assert_eq(Sound.paid_takes(list), {}, "listed but not installed")
	DirAccess.remove_absolute(list)
	var saved: Dictionary = Sound._paid
	Sound._paid = {"hit_blade": ["paid/hit_blade_1"]}
	assert_eq(Sound.takes_of("hit_blade"), ["paid/hit_blade_1"], "the pack's where it's here")
	Sound.withheld = true
	assert_eq(Sound.takes_of("hit_blade"), ["sfx/hit"], "held back: the game's own")
	assert_eq(Sound.takes_of("ui_tick"), ["blip/tick"])
	Sound.withheld = false
	assert_eq(Sound.takes_of("ui_tick"), ["blip/tick"], "an event the packs don't fill keeps its own")
	Sound._paid = saved
	# Where the packs are installed, every take they list is a file here.
	for event: String in Sound._paid:
		for take: String in Sound._paid[event]:
			assert_true(ResourceLoader.exists("res://assets/audio/%s.wav" % take), take)


## PIX-411: every ground the hero can walk on has its step, one of the
## eight surfaces.
func test_every_ground_has_its_step() -> void:
	var surfaces := {}
	for tile: String in WorldTiles.TILE_INFO:
		if WorldTiles.TILE_INFO[tile]:
			var event := Sound.step_for(tile)
			assert_true(Sound._doc["steps"].has(tile), "%s has its own step" % tile)
			assert_eq(Sound._doc["events"][event]["family"], "step", tile)
			surfaces[event] = true
	assert_eq(surfaces.keys().size(), 8, "grass, dirt, sand, stone, wood, snow, ice and shallow water")
	assert_eq(Sound.step_for("grass"), "step_grass")
	assert_eq(Sound.step_for("marsh"), "step_water")
	assert_eq(Sound.step_for("floor"), "step_wood", "a house's boards")
	# A cave's "floor" is its rock: every dungeon's floors, drawn by hand or
	# laid from a seed, walked on wood before the review.
	for dungeon_id: String in Depths.dungeons():
		for floor_def: Dictionary in Depths.floors(dungeon_id):
			var map := MapData.load_by_id(String(floor_def["mapId"]))
			assert_eq(Sound.step_for("floor", map.style), "step_stone", map.id)
	# A paved street is stone; gravel, packed in the dirt, stays the dirt's.
	for look: String in Streets.LOOKS:
		assert_eq(Sound.step_for("path", look), "step_dirt" if look == "gravel" else "step_stone", look)


## PIX-411: a jingle steps the music and the weather back, in a blink, and
## lets them back to where the player set them once it's done.
func test_a_jingle_ducks_the_music_and_lets_it_back() -> void:
	var level := func(bus: String) -> float: return AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus))
	Sound.apply_volumes()
	var music: float = level.call("Music")
	var weather: float = level.call("Ambience")
	var effects: float = level.call("SFX")
	Sound._played_at.clear()
	Sound.play("level_up")
	Sound._duck.custom_step(Sound.DUCK_DOWN_S + 0.01)
	assert_almost_eq(level.call("Music"), music + Sound.DUCK_DB, 0.05, "the music steps back")
	assert_almost_eq(level.call("Ambience"), weather + Sound.DUCK_DB, 0.05, "and the weather")
	assert_almost_eq(level.call("SFX"), effects, 0.01, "the effects don't")
	Sound._duck.custom_step(60.0)
	assert_almost_eq(level.call("Music"), music, 0.01, "back where the player set it")
	assert_almost_eq(level.call("Ambience"), weather, 0.01)
	assert_eq(Sound.ducked, 0.0)
	Sound._played_at.clear()
	Sound.play("hit_blade")
	assert_false(Sound._duck.is_running(), "a blow doesn't duck")


## PIX-411: a place's music is taken up where it was left; a fight's starts
## from its top.
func test_a_place_takes_its_music_up_where_it_left_it() -> void:
	Sound.stop_music()
	Sound._resume_at.clear()
	Sound.play_track("town")
	Sound._music.seek(5.0)
	Sound.play_track("battle")
	assert_almost_eq(float(Sound._resume_at.get("town", 0.0)), 5.0, 0.5, "where the town's music was")
	assert_almost_eq(Sound._music.get_playback_position(), 0.0, 0.5, "the fight from its top")
	Sound._fade.custom_step(Sound.CROSSFADE_S + 0.1)
	assert_almost_eq(Sound._music.volume_db, Sound.level_of("music/battle"), 0.01, "the fight in at its level")
	Sound.play_track("town")
	assert_false(Sound._resume_at.has("battle"), "a fight isn't taken up again")
	assert_almost_eq(Sound._music.get_playback_position(), 5.0, 0.5, "the town's again from there")
	assert_true(Sound._fading.playing, "the fight fading as the town comes in, together")
	# Halfway, the two together at the music's full power: no dip.
	Sound._fade.custom_step(Sound.CROSSFADE_S / 2.0)
	var rising := db_to_linear(Sound._music.volume_db - Sound.level_of("music/town"))
	var falling := db_to_linear(Sound._fading.volume_db - Sound.level_of("music/battle"))
	assert_almost_eq(rising * rising + falling * falling, 1.0, 0.02, "the crossfade holds its power halfway")
	Sound._fade.custom_step(Sound.CROSSFADE_S)
	assert_false(Sound._fading.playing, "the fight gone once the town is in")
	Sound.stop_music()
	Sound._resume_at.clear()
