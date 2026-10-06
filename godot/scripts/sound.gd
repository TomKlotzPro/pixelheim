extends Node
## The game's ears (src/audio, PIX-128). Every sound is the web synth's own,
## rendered to WAVs by scripts/render-audio.ts: the stingers, each place's
## chiptune loop and the ambient one-shots. Music crossfades between themes
## (out, then in, as the web's playTrack does) and keeps playing under the
## menus; ambience rolls its chances every tick like ambience.ts. Volumes are
## the player's (GameSettings), on Music, SFX and Ambience buses.
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
	apply_volumes()


func _exit_tree() -> void:
	if _fade != null:
		_fade.kill()
	for player in [_music, _fading] + _voices + _ambient_voices:
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
	for voice in _voices + _ambient_voices:
		voice.stop()


## The weather of a place: "greenwood", "deepforest", "marsh", "indoor" or "".
func set_ambience(place: String) -> void:
	ambience = place if _doc["ambience"].has(place) else ""


func _process(delta: float) -> void:
	if ambience == "":
		return
	_ambience_clock += delta
	var tick: float = _doc["ambienceTick"]
	while _ambience_clock >= tick:
		_ambience_clock -= tick
		var events: Array = _doc["ambience"][ambience]
		for index in events.size():
			if randf() < float(events[index]["chance"]):
				_ambient(index, randi() % int(events[index]["variants"]))


func _ambient(index: int, variant: int) -> void:
	for voice in _ambient_voices:
		if not voice.playing:
			voice.stream = _stream("res://assets/audio/ambience/%s_%d_%d.wav" % [ambience, index, variant])
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
		"overworld", "demo":
			return "world"
	return "interior"


## Where the hero's ears are (ambienceForState).
static func ambience_for(map_id: String, floor_level: int) -> String:
	if floor_level > 0:
		return "indoor"
	match map_id:
		"overworld", "town", "demo":
			return "greenwood"
		"deepwood":
			return "deepforest"
		"mirefen":
			return "marsh"
	return "indoor"
