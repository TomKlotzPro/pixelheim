extends Node
## The game's ears (PIX-128). The stingers, each place's chiptune loop and
## the ambient one-shots are WAVs in assets/audio/, rendered once from the
## classic edition's synth (assets/data/audio.json lists them); the newer
## ones (PIX-158: the dodge, a roar, a bounty, the story themes, birds,
## crickets, chatter, fire and the floors' wind) are rendered by
## tools/synth.py. Music crossfades between themes (out, then in, as the
## web's playTrack does) and keeps playing under the menus; a story theme
## plays once, then what it names or the place's music. Ambience rolls its
## chances every tick like ambience.ts, the extras the world asks for with
## it, over a looping bed (wind). Volumes are the player's (GameSettings),
## on Music, SFX and Ambience buses.
## Autoload `Sound`.

const FADE_S := 0.35
const SFX_VOICES := 8
## How long the fight's music lingers after the last hunter gives up.
const COMBAT_LINGER_S := 3.0

var _doc := {}
var _streams := {}
var _music: AudioStreamPlayer
var _fading: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _ambient_voices: Array[AudioStreamPlayer] = []
var track := ""
var ambience := ""
var _ambience_clock := 0.0
var _fade: Tween
## The extra ambience the world asks for now ("birds", "fire"...).
var extras: Array[String] = []
## The looping bed under it ("wind", "deepwind" or "").
var bed := ""
var _bed: AudioStreamPlayer
var _bed_fade: Tween
## What a story theme hands over to when it ends ("" - the place's music).
var _after_theme := ""
## When each made sound last played (msec).
var _played_at := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_doc = SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/audio.json"))
	for bus: String in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music = _player("Music")
	_fading = _player("Music")
	for i in SFX_VOICES:
		_voices.append(_player("SFX"))
	for i in 3:
		_ambient_voices.append(_player("Ambience"))
	_bed = _player("Ambience")
	for player in [_music, _fading]:
		player.finished.connect(_theme_over.bind(player))
	apply_volumes()


func _exit_tree() -> void:
	if _fade != null:
		_fade.kill()
	if _bed_fade != null:
		_bed_fade.kill()
	for player in [_music, _fading, _bed] + _voices + _ambient_voices:
		player.stop()
		player.stream = null
	_streams.clear()


func _player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


## The player's levels on the buses (and the mute on the master).
func apply_volumes() -> void:
	var settings: GameSettings = GameState.settings
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(settings.music_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(settings.sfx_volume, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Ambience"), linear_to_db(maxf(settings.sfx_volume * 0.55, 0.0001)))
	AudioServer.set_bus_mute(0, settings.muted)


func _stream(path: String) -> AudioStreamWAV:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


## The pages' own sounds (PIX-138): a swish of paper as a screen opens, a
## pen's tick as a choice moves, a soft fall as it closes. Made here, in the
## rendered sounds' chiptune voice:
## [seconds, wave, from Hz, to Hz, volume] per blip, played in turn.
## The fight has three of its own (PIX-209): a swing's swish, a skill's
## rising shimmer and the thud of a killing blow.
const UI_SOUNDS := {
	"open": [[0.05, "noise", 0.0, 0.0, 0.10], [0.05, "triangle", 660.0, 880.0, 0.10]],
	"tick": [[0.025, "square", 1320.0, 1320.0, 0.05]],
	"close": [[0.07, "triangle", 620.0, 360.0, 0.10]],
	"swing": [[0.05, "noise", 0.0, 0.0, 0.05], [0.03, "triangle", 420.0, 280.0, 0.04]],
	"cast": [[0.05, "triangle", 520.0, 1040.0, 0.08], [0.06, "square", 1040.0, 1300.0, 0.03]],
	"kill": [[0.04, "square", 180.0, 90.0, 0.09], [0.08, "noise", 0.0, 0.0, 0.07]],
	# Danger (PIX-210): a foe gathering to bite, a mark drawn on the ground
	# and its strike, and the heart of a hero near the end.
	"tell": [[0.05, "square", 880.0, 1320.0, 0.04]],
	"mark": [[0.06, "square", 330.0, 330.0, 0.05], [0.07, "square", 247.0, 247.0, 0.05]],
	"slam": [[0.03, "square", 130.0, 60.0, 0.10], [0.10, "noise", 0.0, 0.0, 0.08]],
	"heart": [[0.045, "triangle", 120.0, 80.0, 0.16], [0.05, "square", 0.0, 0.0, 0.0], [0.045, "triangle", 110.0, 70.0, 0.11]],
}
const UI_RATE := 22050


## One of the made sounds (the pages' open, tick and close; the fight's).
## The same one twice at once (three marks drawn together) sounds once.
func play_ui(name: String) -> void:
	if not UI_SOUNDS.has(name):
		return
	var now := Time.get_ticks_msec()
	if now - int(_played_at.get(name, -1000)) < 40:
		return
	_played_at[name] = now
	var key := "ui:" + name
	if not _streams.has(key):
		_streams[key] = _synth(UI_SOUNDS[name])
	for voice in _voices:
		if not voice.playing:
			voice.stream = _streams[key]
			voice.play()
			return


## Blips to 16-bit mono PCM, each fading out as it ends.
static func _synth(blips: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	var noise := RandomNumberGenerator.new()
	noise.seed = 7
	for blip: Array in blips:
		var count := int(float(blip[0]) * UI_RATE)
		var phase := 0.0
		for i in count:
			var t := float(i) / count
			var freq: float = lerpf(blip[2], blip[3], t)
			phase = fmod(phase + freq / UI_RATE, 1.0)
			var wave := 0.0
			match String(blip[1]):
				"square": wave = 1.0 if phase < 0.5 else -1.0
				"triangle": wave = 4.0 * absf(phase - 0.5) - 1.0
				"noise": wave = noise.randf_range(-1.0, 1.0)
			var sample := int(clampf(wave * float(blip[4]) * (1.0 - t), -1.0, 1.0) * 32767.0)
			data.append(sample & 0xFF)
			data.append((sample >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = UI_RATE
	stream.data = data
	return stream


## While a screen holds the game (the tree is paused), moving the choice ticks.
func _input(event: InputEvent) -> void:
	if not get_tree().paused or not event.is_pressed() or event.is_echo():
		return
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		if event.is_action_pressed(action):
			play_ui("tick")
			return


## A stinger by the web's name (SFX.hit, SFX.coin...).
func play(sfx: String) -> void:
	if not _doc["stingers"].has(sfx):
		return
	for voice in _voices:
		if not voice.playing:
			voice.stream = _stream("res://assets/audio/sfx/%s.wav" % sfx)
			voice.play()
			return


## Crossfades to a theme: the old one fades out, the new one in.
func play_track(name: String) -> void:
	if name == track or not _doc["tracks"].has(name):
		return
	track = name
	var stream := _stream("res://assets/audio/music/%s.wav" % name)
	# One seamless loop, as rendered: the whole file, round and round.
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(float(_doc["tracks"][name]["seconds"]) * stream.mix_rate)
	_crossfade(stream)


## A story theme (PIX-158: a boss's intro, the dawn, an ending), once
## through; then `then` (a track), or nothing and the world's music returns.
func play_theme(name: String, then := "") -> void:
	if not _doc["themes"].has(name):
		return
	track = "theme:" + name
	_after_theme = then
	var stream := _stream("res://assets/audio/music/theme_%s.wav" % name)
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_crossfade(stream)


func _theme_over(player: AudioStreamPlayer) -> void:
	if player != _music or not track.begins_with("theme:"):
		return
	track = ""
	if _after_theme != "":
		play_track(_after_theme)
	_after_theme = ""


func _crossfade(stream: AudioStreamWAV) -> void:
	if _fade != null:
		_fade.kill()
	var outgoing := _music
	_music = _fading
	_fading = outgoing
	_fade = create_tween()
	if outgoing.playing:
		_fade.tween_property(outgoing, "volume_db", -40.0, FADE_S)
		_fade.tween_callback(outgoing.stop)
	_music.stream = stream
	_music.volume_db = -40.0
	_fade.tween_callback(_music.play)
	_fade.tween_property(_music, "volume_db", 0.0, FADE_S)


func stop_music() -> void:
	track = ""
	_music.stop()
	_fading.stop()


## Silence: music, weather and every stinger still ringing.
func stop_all() -> void:
	stop_music()
	ambience = ""
	extras.clear()
	set_bed("")
	for voice in _voices + _ambient_voices:
		voice.stop()


## The extra ambience the world asks for (PIX-158): birds or crickets,
## chatter, fire. Unknown names are ignored.
func set_extras(names: Array[String]) -> void:
	extras.assign(names.filter(func(name: String) -> bool: return _doc["ambienceExtras"].has(name)))


## A looping bed under the ambience ("wind", "deepwind", or "" for none),
## faded in and out.
func set_bed(name: String) -> void:
	if name not in _doc["beds"]:
		name = ""
	if name == bed:
		return
	bed = name
	if _bed_fade != null:
		_bed_fade.kill()
	_bed_fade = create_tween()
	if _bed.playing:
		_bed_fade.tween_property(_bed, "volume_db", -40.0, FADE_S * 2)
		_bed_fade.tween_callback(_bed.stop)
	if name == "":
		return
	var stream := _stream("res://assets/audio/ambience/bed_%s.wav" % name)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	_bed_fade.tween_callback(func() -> void:
		_bed.stream = stream
		_bed.volume_db = -40.0
		_bed.play()
	)
	_bed_fade.tween_property(_bed, "volume_db", 0.0, FADE_S * 3)


## The weather of a place: "greenwood", "deepforest", "marsh", "indoor" or "".
func set_ambience(place: String) -> void:
	ambience = place if _doc["ambience"].has(place) else ""


func _process(delta: float) -> void:
	if ambience == "" and extras.is_empty():
		return
	_ambience_clock += delta
	var tick: float = _doc["ambienceTick"]
	while _ambience_clock >= tick:
		_ambience_clock -= tick
		var events: Array = _doc["ambience"].get(ambience, [])
		for index in events.size():
			if randf() < float(events[index]["chance"]):
				_ambient(index, randi() % int(events[index]["variants"]))
		for name in extras:
			var extra: Dictionary = _doc["ambienceExtras"][name]
			if randf() < float(extra["chance"]):
				_ambient_file("res://assets/audio/ambience/%s_%d.wav" % [name, randi() % int(extra["variants"])])


func _ambient(index: int, variant: int) -> void:
	_ambient_file("res://assets/audio/ambience/%s_%d_%d.wav" % [ambience, index, variant])


func _ambient_file(path: String) -> void:
	for voice in _ambient_voices:
		if not voice.playing:
			voice.stream = _stream(path)
			voice.play()
			return


## Which theme a moment deserves (trackForState): places, then a fight on top.
## `fight` is "" (none), "battle" or "boss".
static func track_for(map_id: String, floor_level: int, fight: String) -> String:
	if fight != "":
		return fight
	if floor_level > 0:
		return "descent"
	match map_id:
		"deepwood", "mirefen", "town":
			return map_id
		"seacave", "shafts", "cellars", "icecave":
			return "descent"
		"overworld", "demo", "saltmere", "blackiron", "greyhold", "frostgate":
			return "world"
	return "interior"


## Where the hero's ears are (ambienceForState).
static func ambience_for(map_id: String, floor_level: int) -> String:
	if floor_level > 0:
		return "indoor"
	match map_id:
		"overworld", "town", "demo", "saltmere", "blackiron", "greyhold":
			return "greenwood"
		"deepwood":
			return "deepforest"
		"mirefen":
			return "marsh"
	return "indoor"
