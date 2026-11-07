extends Node
## areas: town field
## The game's ears (PIX-128). The stingers, each place's chiptune loop and
## the ambient one-shots are WAVs in assets/audio/, rendered once from the
## classic edition's synth (assets/data/audio.json lists them); the newer
## ones (PIX-158: the dodge, a roar, a bounty, the story themes, birds,
## crickets, chatter, fire and the floors' wind) are rendered by
## tools/synth.py. Music crossfades between themes (the old and the new
## together, PIX-411) and keeps playing under the menus, a place's track
## taken up where it was left; a story theme plays once, then what it names
## (when it ends or its scene does, PIX-416) or the place's music. Ambience rolls its chances every tick like
## ambience.ts, the extras the world asks for with it, over a looping bed
## (wind). Volumes are the player's (GameSettings), on Music, SFX, UI,
## Jingle and Ambience buses, each sound at its own level first
## (audio.json's "levels", `level_of`), every bus LOUDNESS_DB over its slider
## and a limiter on Master (PIX-383).
## Every sound the game makes is a moment's event (PIX-411): audio.json's
## "events" give each its family and its takes (a rendered stinger "sfx/x"
## or a made blip "blip/x"), and the paid packs' prepared takes stand in for
## them where they're installed (assets/audio/paid/, tools/sound_prep.py).
## A family ("families") has its bus, its own voices, its level and the
## loudness the prep brings a pack's take to; a jingle or a stinger ducks
## the music and the weather under it.
## PIX-413: the whole library wired in - a foe's own voice by its kind
## ("voices"), a skill's impact by its theme, a bow's shot and a staff's
## bolt ("swings"), and each place's own bed from the packs ("places"),
## quiet under the music, where the game's own has wind or nothing.
## PIX-414: the rain, the river, the forge, a crypt's air and the ice
## cave's wind as places with beds of their own, and a cave's drips and
## stones as its sprinkle, thrown on Sound's own dice.
## PIX-416: the music from Leohpaz's RPG music bundle where it's installed
## (assets/audio/paid/music.json, tools/music_prep.py), the game's own
## chiptune without it; the places that had no track of their own (the inn,
## the crypts, the ice cave, the coast, the Frostgate, Greyhold, Fernoir, the
## mountain road, the dragon) play their "fallback"'s then: the same as before
## but for the mountain road, the Reach's now, not the rooms' tune.
## Autoload `Sound`.

const FADE_S := 0.35
## The music's crossfade, the old track and the new one together (PIX-411).
const CROSSFADE_S := 0.8
## A stinger is never quite the same twice (PIX-212): its pitch a few
## percent either way, its level a decibel and a half. The same sound twice
## within SAME_GAP_MS sounds once (an area skill's hits, a sale's coin and
## the purse's).
const VARY_PITCH := 0.06
const VARY_DB := 1.5
const SAME_GAP_MS := 40
## The whole game this much over its renders, on every bus so the balance
## holds (PIX-383). Through the mixer at the default volumes the music came
## out at -37.6 LUFS (the mono renders play on both channels: 3 LU over the
## audio pass's -40.6, which measured them as one), where a PC game sits
## near -23. +14 dB puts it at -23.6 and a busy fight at about -19.5, where
## the limiter barely works (0.3 LU) and the web, which has none, all but
## never passes 0 dBFS; at +17 a fight came to -16.3, the limiter took 0.8
## LU off it and the web clipped. The packs' takes are brought down to their
## family's loudness by the prep (PIX-411), so this holds for them too.
const LOUDNESS_DB := 14.0
## Master's limiter's ceiling: sounds stacked at once never clip past it.
const CEILING_DB := -1.0
## Under a jingle or a stinger the music and the weather step back
## (PIX-411): this far, in a blink, and back gently once it's done.
const DUCK_DB := -7.0
const DUCK_DOWN_S := 0.05
const DUCK_UP_S := 0.4
## A change of place on the web hushes the music before the map is built
## (PIX-417, `hush`): this far, this fast, and back this slowly after.
const HUSH_DB := -40.0
const HUSH_DOWN_S := 0.08
const HUSH_UP_S := 0.5
## How long a build waits on the hush: its fade, then what the web had
## mixed before it (a 2048-frame ring, audio/driver/output_latency.web's
## 50 ms, and a 512-frame mix step: some 55 ms). A dark fade's length.
const HUSH_S := 0.15
## How long the hush holds: HUSH_S and a few frames for the build to begin
## in; a first visit's long frame has passed it on by the time it ends.
const HUSH_HOLD_S := 0.25
## The longest frame the hush's return counts, as Dissolve's: the build's.
const HUSH_FRAME := 1.0 / 30.0
## Every bus Sound plays on, each in default_bus_layout.tres (PIX-412; UI
## and Jingle, PIX-411).
const BUSES: Array[String] = ["Music", "SFX", "Ambience", "UI", "Jingle"]
## The ambience's slider at this share of the bus, as it sat under the
## effects' before it had its own (PIX-411).
const AMBIENCE_SHARE := 0.55
## How long the fight's music lingers after the last hunter gives up.
const COMBAT_LINGER_S := 3.0
## Where the packs' prepared takes are installed (scripts/fetch-private-art.sh),
## with the list tools/sound_prep.py wrote of them.
const PAID := "res://assets/audio/paid/takes.json"
## The bundle's tracks installed beside them, with tools/music_prep.py's list
## (PIX-416), and the rate it wrote them at.
const PAID_MUSIC := "res://assets/audio/paid/music.json"
const PAID_MUSIC_RATE := 44100.0

var _doc := {}
var _streams := {}
var _music: AudioStreamPlayer
var _fading: AudioStreamPlayer
## Each family's own voices (its "voices"), so footsteps, the pages' ticks
## and a fight's blows never take one another's (PIX-411).
var _pools := {}
var _ambient_voices: Array[AudioStreamPlayer] = []
var track := ""
## The music playing for `track`: the slot itself, or the one it falls back
## on without the bundle (PIX-416: Saltmere's "coast" is the Reach's
## "world"), so a place sharing the music playing doesn't start it over.
var _heard := ""
## Where the hero's ears are (audio.json's "places": "forest_day", "coast"...).
var place := ""
## The place's one-shots, by their renders ("greenwood", "marsh"...).
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
## When each sound last played (msec), by its own take.
var _played_at := {}
## When each voice began (msec).
var _began := {}
var _foot := 0
## The packs' takes installed, by event ("paid/<name>"); {} without them.
var _paid := {}
## The bundle's tracks installed, by slot ("town", "theme_dawn"): each
## one's path and loopBegin; {} without them (PIX-416).
var _paid_music := {}
## The packs' takes held back though they're here (the harness's `cc0`, as
## the paid art is): the run hears what a build without them hears.
var withheld := false
## The take each event played last, never played twice running.
var _last := {}
## Which take plays is Sound's own throw, so the game's dice stay as they
## were, seeded so a run hears the same takes every time (verify.md).
var _dice := RandomNumberGenerator.new()
## Where each place's track was left (seconds), to take it up there again.
var _resume_at := {}
## The dB the music and the weather are stepped back by now (a duck).
var ducked := 0.0
var _duck: Tween
## Whether a change of place hushes the music first (`hush`): the web's.
var hushes_builds := OS.has_feature("web")
## The dB the music is hushed by now, and how long it stays hushed.
var hushed := 0.0
var _hush_left := 0.0
## How many sounds have been asked for, so a screen can tell whether what
## it just did made one of its own.
var asked := 0
## Let go for good (`release`): nothing plays again.
var released := false
## Buses this Sound had to make at run time, which break the web's sound
## (PIX-412): none while default_bus_layout.tres holds them all.
var buses_added := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dice.seed = 411
	_doc =SaveCodec.parse_json(FileAccess.get_file_as_string("res://assets/data/audio.json"))
	# The buses come from default_bus_layout.tres (PIX-412): made here at run
	# time, the web's sample playback wired Master's output into a loop of
	# them and nothing reached the speakers. Only a layout that lacks one
	# (an older project) still gets it here.
	for bus: String in BUSES:
		if AudioServer.get_bus_index(bus) < 0:
			buses_added += 1
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# Once: a harness batch makes Sound again on the same buses. The web's
	# sample playback runs no bus effects, so there the buses' levels alone.
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = CEILING_DB
		AudioServer.add_bus_effect(0, limiter)
	_music = _player("Music")
	_fading = _player("Music")
	for family: String in _doc["families"]:
		var pool: Array[AudioStreamPlayer] = []
		for i in int(_doc["families"][family]["voices"]):
			pool.append(_player(_doc["families"][family]["bus"]))
		_pools[family] = pool
	for i in 3:
		_ambient_voices.append(_player("Ambience"))
	_bed = _player("Ambience")
	for player in [_music, _fading]:
		player.finished.connect(_theme_over.bind(player))
		# Streamed on the web too, where a player is a sample by default: a
		# bundle's track was decoded whole on the main thread at its first
		# play (the Deepwood's froze the crossing 135 ms), kept as PCM for
		# good and looped from where it began, not its loopBegin (PIX-416
		# review, perf.md). The desktop always streams.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_paid = paid_takes(PAID)
	_paid_music = paid_music(PAID_MUSIC)
	apply_volumes()


func _exit_tree() -> void:
	release()


## Every player stopped at once, fades and all, every sound let go, and
## none played after (a screen freed at the end says "close"): at the
## engine's end, and a harness run's (PIX-379).
func release() -> void:
	released = true
	for tween: Tween in [_fade, _bed_fade, _duck]:
		if tween != null:
			tween.kill()
	for player in [_music, _fading, _bed] + _voices() + _ambient_voices:
		player.stop()
		player.stream = null
	_streams.clear()


func _player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


## Every family's voices.
func _voices() -> Array[AudioStreamPlayer]:
	var out: Array[AudioStreamPlayer] = []
	for pool: Array[AudioStreamPlayer] in _pools.values():
		out.append_array(pool)
	return out


## The player's levels on the buses (and the mute on the master), the music
## and the weather stepped back while a duck lasts.
func apply_volumes() -> void:
	var settings: GameSettings = GameState.settings
	_bus_db("Music", bus_db(settings.music_volume) + ducked + hushed)
	_bus_db("Ambience", bus_db(settings.ambience_volume * AMBIENCE_SHARE) + ducked)
	for bus: String in ["SFX", "UI", "Jingle"]:
		_bus_db(bus, bus_db(settings.sfx_volume))
	AudioServer.set_bus_mute(0, settings.muted)


static func _bus_db(bus: String, db: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), db)


## A slider's 0..1 as its bus's dB, LOUDNESS_DB over the renders; nought
## stays as silent as it was (-80 dB).
static func bus_db(volume: float) -> float:
	return linear_to_db(maxf(volume * db_to_linear(LOUDNESS_DB), 0.0001))


## A sound's own level in dB, by its file under assets/audio/ without a
## variant's number ("sfx/hurt", "music/theme_dawn", "ambience/greenwood_1",
## "ambience/birds"): the renders came out at whatever loudness their synth
## gave, so the audio pass measured each and evened them out here, the
## music to one loudness and each family of effects to itself. A blip and a
## pack's take have none: the prep brought the take to its family's.
func level_of(key: String) -> float:
	return float(_doc["levels"].get(key, 0.0))


func _stream(path: String) -> AudioStreamWAV:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


## The pages' own sounds (PIX-138): a swish of paper as a screen opens, a
## pen's tick as a choice moves, a soft fall as it closes. Made here, in the
## rendered sounds' chiptune voice:
## [seconds, wave, from Hz, to Hz, volume] per blip, played in turn.
## The fight has three of its own (PIX-209): a swing's swish, a skill's
## rising shimmer and the thud of a killing blow. An event's take "blip/tick"
## is one of these.
const UI_SOUNDS := {
	# The open at the close's level (the audio pass): it came 4 dB over every
	# other page sound and most stingers, on the game's most common moment.
	"open": [[0.05, "noise", 0.0, 0.0, 0.065], [0.05, "triangle", 660.0, 880.0, 0.065]],
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
	# The quiet answers (PIX-212): yes, no, a page turned, an ailment taking hold.
	"confirm": [[0.04, "square", 660.0, 660.0, 0.05], [0.06, "square", 990.0, 990.0, 0.05]],
	"deny": [[0.05, "square", 220.0, 220.0, 0.06], [0.07, "square", 165.0, 165.0, 0.06]],
	"page": [[0.035, "noise", 0.0, 0.0, 0.06], [0.03, "triangle", 1200.0, 900.0, 0.03]],
	"ail": [[0.05, "triangle", 300.0, 520.0, 0.06], [0.06, "triangle", 520.0, 260.0, 0.06]],
	# A foe far below the hero takes fright and runs (PIX-251): a yelp that
	# jumps up and falls away.
	"fright": [[0.03, "square", 990.0, 1480.0, 0.04], [0.07, "triangle", 1480.0, 620.0, 0.06]],
	# The light flaring on the hero at an ascension (PIX-244): a climb of
	# three bright steps.
	"ascend": [[0.04, "triangle", 660.0, 990.0, 0.07], [0.04, "triangle", 990.0, 1320.0, 0.07], [0.06, "square", 1320.0, 1760.0, 0.03]],
	# A way out opening once a boss is down (PIX-292): a quick run up a
	# chord to its octave, like a door's bell.
	"wayout": [[0.03, "triangle", 523.0, 523.0, 0.08], [0.03, "triangle", 659.0, 659.0, 0.08], [0.03, "triangle", 784.0, 784.0, 0.08], [0.05, "triangle", 1046.0, 1046.0, 0.08]],
	# A volley off the walls on the Night of Bells, loosed (PIX-253 step 9).
	"loose": [[0.03, "noise", 0.0, 0.0, 0.05], [0.06, "triangle", 900.0, 520.0, 0.04]],
}
const UI_RATE := 22050


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


## While a screen holds the game (the tree is paused), moving the choice
## ticks, unless what the move did made a sound of its own (PIX-383: a page
## turned, a refusal): the screen takes the key after this, so the tick
## waits to the frame's end to hear.
func _input(event: InputEvent) -> void:
	if not get_tree().paused or not event.is_pressed() or event.is_echo():
		return
	for action: String in ["move_up", "move_down", "move_left", "move_right"]:
		if event.is_action_pressed(action):
			_tick_unless_heard.call_deferred(asked)
			return


func _tick_unless_heard(asked_then: int) -> void:
	if asked == asked_then:
		play("ui_tick")


## A moment's sound by its event (audio.json's "events": "hit_blade",
## "coin_gain", "ui_tick"...): one of its takes, never the one it played
## last, at its family's level on its family's voices; a rendered stinger a
## little different each time unless `vary` is false, a family with "feet"
## left foot then right. An event with no take here is silent.
func play(event: String, vary := true) -> void:
	var entry: Dictionary = _doc["events"].get(event, {})
	if entry.is_empty():
		return
	var own: Array = entry["takes"]
	# The same sound within a breath sounds once, whichever moment asked:
	# known by the take the game made it with.
	var heard: String = own[0] if not own.is_empty() else event
	var now := GameClock.msec()
	if now - int(_played_at.get(heard, -1000)) < SAME_GAP_MS:
		return
	var takes := takes_of(event)
	if takes.is_empty():
		return
	_played_at[heard] = now
	var family: Dictionary = _doc["families"][entry["family"]]
	var pitch := 1.0
	var level := float(family.get("db", 0.0))
	if family.has("feet"):
		_foot = 1 - _foot
		pitch = float(family["feet"][_foot])
	elif vary and heard.begins_with("sfx/"):
		# On the game's dice, as the stingers always threw them (PIX-212), and
		# only where they did: the dice the game throws next stay the same
		# with the packs or without.
		pitch = randf_range(1.0 - VARY_PITCH, 1.0 + VARY_PITCH)
		level += randf_range(-VARY_DB, VARY_DB)
	var index := pick(takes.size(), int(_last.get(event, -1)), _dice)
	_last[event] = index
	var stream := _take(takes[index])
	_voice_for(stream, pitch, level + level_of(takes[index]), entry["family"])
	if family.get("duck", false):
		duck(stream.get_length() / pitch)


## An event's takes: the packs' where they're installed and not held back,
## else its own (none for a moment the game has no sound for yet).
func takes_of(event: String) -> Array:
	if not withheld and _paid.has(event):
		return _paid[event]
	return _doc["events"].get(event, {}).get("takes", [])


## Which of `count` takes plays, never `last` again while there's another.
static func pick(count: int, last: int, dice: RandomNumberGenerator) -> int:
	if count < 2:
		return 0
	if last < 0 or last >= count:
		return dice.randi() % count
	return (last + 1 + dice.randi() % (count - 1)) % count


## A take's sound: a blip made here, else its file under assets/audio/.
func _take(take: String) -> AudioStreamWAV:
	if take.begins_with("blip/"):
		if not _streams.has(take):
			_streams[take] = _synth(UI_SOUNDS[take.trim_prefix("blip/")])
		return _streams[take]
	return _stream("res://assets/audio/%s.wav" % take)


## The packs' takes a prepared list names (tools/sound_prep.py's
## takes.json, {"events": {event: [name, ...]}}), as "paid/<name>" by event:
## only those whose file is here, {} without the list.
static func paid_takes(list: String) -> Dictionary:
	if not FileAccess.file_exists(list):
		return {}
	var out := {}
	var events: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(list)).get("events", {})
	for event: String in events:
		var here: Array = []
		for name: String in events[event]:
			if ResourceLoader.exists("res://assets/audio/paid/%s.wav" % name):
				here.append("paid/" + name)
		if not here.is_empty():
			out[event] = here
	return out


## The bundle's tracks a prepared list names (tools/music_prep.py's
## music.json, {"tracks": {slot: {"file", "loopBegin", ...}}}), by slot: only
## those whose file is here and whose slot this build has (PIX-416: the
## private repo is pushed before the PR naming a new slot merges), {}
## without the list.
func paid_music(list: String) -> Dictionary:
	if not FileAccess.file_exists(list):
		return {}
	var out := {}
	var tracks: Dictionary = SaveCodec.parse_json(FileAccess.get_file_as_string(list)).get("tracks", {})
	for slot: String in tracks:
		var path := "res://assets/audio/paid/%s" % tracks[slot]["file"]
		var known: bool = _doc["tracks"].has(slot) or (slot.begins_with("theme_") and _doc["themes"].has(slot.trim_prefix("theme_")))
		if known and ResourceLoader.exists(path):
			out[slot] = {"path": path, "loopBegin": float(tracks[slot].get("loopBegin", 0.0))}
	return out


## The blow a weapon lands (audio.json's "blows" by its drawing): a blade's
## for a sword, an axe, a dagger or none.
func blow_for(weapon_id: String) -> String:
	return _by_weapon("blows", weapon_id, "hit_blade")


## The swing a weapon makes (PIX-413, "swings"): a bow's shot, a staff's
## bolt, a blade's swish for the rest.
func swing_for(weapon_id: String) -> String:
	return _by_weapon("swings", weapon_id, "swing")


func _by_weapon(table: String, weapon_id: String, plain: String) -> String:
	var sprite := String(Catalog.item(weapon_id).get("sprite", "")) if weapon_id != "" else ""
	return String(_doc[table].get(sprite, plain))


## A skill's sound by its theme in the skills pack ("casts": Fire, Light...).
func cast_for(skill_name: String) -> String:
	return String(_doc["casts"].get(ItemIcons.skill_theme(skill_name), "cast"))


## Where a skill lands (PIX-413): its theme's impact ("impact_fire" for
## "cast_fire"), a spell's plain hit without one.
func impact_for(skill_name: String) -> String:
	var event := "impact_" + cast_for(skill_name).trim_prefix("cast_")
	return event if _doc["events"].has(event) else "hit_spell"


## A foe's moment by its family (`event` "kill" gives "kill_undead": its
## fall; "foe_noticed" its growl, PIX-413), the plain one without.
func of_family(event: String, monster_id: String) -> String:
	var own := "%s_%s" % [event, Bestiary.family_of(monster_id)]
	return own if _doc["events"].has(own) else event


## A foe's own voice (PIX-413: audio.json's "voices" by its kind, a frost
## wolf a wolf's): `what` is "attack", "hurt" or "death"; `plain` for a
## kind without one.
func voice_for(monster_id: String, what: String, plain := "") -> String:
	var event := "%s_%s" % [_doc["voices"].get(monster_id, ""), what]
	return event if _doc["events"].has(event) else plain


## What picking a patch sounds like (PIX-413, "gathers"): ore and glass
## struck loose, the herbs and reeds pulled.
func gather_for(item_id: String) -> String:
	return String(_doc["gathers"].get(item_id, "gather"))


## A step by the ground under it ("steps": grass, dirt, sand, stone, wood,
## snow, ice or shallow water), and by what's laid over that ground (`over`:
## a street's paving, or the map's style): "over:tile" first, so a cave's
## "floor" is rock where a house's is boards, and a cobbled path is stone.
func step_for(tile: String, over := "") -> String:
	var steps: Dictionary = _doc["steps"]
	return String(steps.get("%s:%s" % [over, tile], steps.get(tile, "step_dirt")))


## Plays `stream` on a free voice of `family`'s at `pitch` and `level` dB;
## with all of them busy, it takes the one that began longest ago.
func _voice_for(stream: AudioStream, pitch: float, level: float, family: String) -> void:
	asked += 1
	if released:
		return
	var pool: Array[AudioStreamPlayer] = _pools[family]
	var chosen: AudioStreamPlayer = null
	for voice in pool:
		if not voice.playing:
			chosen = voice
			break
	if chosen == null:
		chosen = pool[0]
		for voice in pool:
			if int(_began.get(voice, 0)) < int(_began.get(chosen, 0)):
				chosen = voice
	chosen.stream = stream
	chosen.pitch_scale = pitch
	chosen.volume_db = level
	chosen.play()
	_began[chosen] = GameClock.msec()


## Steps the music and the weather back DUCK_DB for `hold` seconds (a
## jingle or a stinger playing over them), then lets them back.
func duck(hold: float) -> void:
	if released:
		return
	if _duck != null:
		_duck.kill()
	_duck = create_tween()
	_duck.tween_method(_set_ducked, ducked, DUCK_DB, DUCK_DOWN_S)
	_duck.tween_interval(maxf(hold - DUCK_DOWN_S, 0.0))
	_duck.tween_method(_set_ducked, DUCK_DB, 0.0, DUCK_UP_S)


func _set_ducked(db: float) -> void:
	ducked = db
	apply_volumes()


## The music hushed for a map about to be built, on the web (PIX-417):
## there the single-threaded build mixes the streamed music on the main
## thread 50 ms ahead, so a build's long frame held it mid-phrase at full
## level (a gate's first visit about 290 ms, a room's door 75) and then let
## it go on where it stopped. The world builds HUSH_S after asking, the
## hold then silence under the change of place; the music comes back up on
## its own once HUSH_HOLD_S has passed, a first visit's long frame passing
## it at once (so a change of place cut short never leaves it hushed).
## The desktop mixes on its own thread: nothing to hush there.
func hush() -> void:
	if hushes_builds and not released:
		_hush_left = HUSH_HOLD_S


## The music hushed and waited on before a long frame (a map's build, the
## whole world's reload; PIX-417, PIX-420): HUSH_S, then the next frame's
## start, as a step onto a door builds, so the camera follows into the new
## map before it is drawn (after the frame's nodes, the old place's view of
## the new map was drawn too, 50-70 ms more). At once off the web.
func hush_first() -> void:
	if not hushes_builds:
		return
	hush()
	await get_tree().create_timer(HUSH_S).timeout
	await get_tree().process_frame


## The hush eased toward where it's going, a build's long frame counted as
## one ordinary frame so the music comes back gently after it.
func _ease_hush(delta: float) -> void:
	_hush_left = maxf(_hush_left - delta, 0.0)
	var to := HUSH_DB if _hush_left > 0.0 else 0.0
	if hushed == to:
		return
	var rate := -HUSH_DB / (HUSH_DOWN_S if to < hushed else HUSH_UP_S)
	hushed = move_toward(hushed, to, rate * minf(delta, HUSH_FRAME))
	apply_volumes()


## A track loaded ahead, not yet played (One Reach, PIX-269: the theme of a
## map the hero may walk into over a line, so the walk doesn't load it in
## the frame the line is crossed in).
func ready_track(name: String) -> void:
	if _doc.has("tracks") and _doc["tracks"].has(name):
		_music_of(heard_as(name), true)


## The music a slot plays (PIX-416): its own, the bundle's where it's
## installed and not held back, else the game's file; a slot the game has
## no file for (the inn, the coast...) its "fallback"'s.
func heard_as(name: String) -> String:
	if _bundled(name):
		return name
	return String(_doc["tracks"][name].get("fallback", name))


## Whether `key` ("town", "theme_dawn") plays the bundle's track.
func _bundled(key: String) -> bool:
	return not withheld and _paid_music.has(key)


## Crossfades to a place's or a fight's theme, a place's taken up where it
## was left ("resume"), round and round from its "loopBegin" (after an
## intro) to its end. A slot whose music is already playing (a place sharing
## its fallback's, PIX-416) carries on.
func play_track(name: String) -> void:
	if name == track or not _doc["tracks"].has(name):
		return
	_keep_place()
	track = name
	var heard := heard_as(name)
	if heard == _heard and _music.playing:
		return
	_heard = heard
	_crossfade(_music_of(heard, true), _music_level(heard), float(_resume_at.get(heard, 0.0)))


## A track's or a story theme's music (`key`: "town", "theme_dawn"): the
## bundle's where it's installed (PIX-416), looping from its loopBegin when
## `loop`; else the game's WAV, looping from its "loopBegin" to its
## "seconds".
func _music_of(key: String, loop: bool) -> AudioStream:
	if _bundled(key):
		var path: String = _paid_music[key]["path"]
		if not _streams.has(path):
			_streams[path] = load(path)
		var ogg: AudioStreamOggVorbis = _streams[path]
		ogg.loop = loop
		# Godot lands a loop on the sample its offset falls in, rounding down:
		# half a sample on, it lands on the one the prep meant.
		ogg.loop_offset = float(_paid_music[key]["loopBegin"]) + 0.5 / PAID_MUSIC_RATE
		return ogg
	var stream := _stream("res://assets/audio/music/%s.wav" % key)
	if not loop:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		return stream
	var info: Dictionary = _doc["tracks"][key]
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = roundi(float(info.get("loopBegin", 0.0)) * stream.mix_rate)
	stream.loop_end = roundi(float(info["seconds"]) * stream.mix_rate)
	return stream


## The dB a track or a theme plays at: the game's file's own level, the
## bundle's none (the prep brought it to the music's loudness, PIX-416).
func _music_level(key: String) -> float:
	return 0.0 if _bundled(key) else level_of("music/" + key)


## Notes where a place's track is, before it gives way.
func _keep_place() -> void:
	if _music.playing and _doc["tracks"].get(_heard, {}).get("resume", false):
		_resume_at[_heard] = _music.get_playback_position()


## A story theme (PIX-158: a boss's intro, the dawn, an ending), once
## through; then `then` (a track), or nothing and the world's music returns.
func play_theme(name: String, then := "") -> void:
	if not _doc["themes"].has(name):
		return
	_keep_place()
	track = "theme:" + name
	_heard = track
	_after_theme = then
	_crossfade(_music_of("theme_" + name, false), _music_level("theme_" + name))


func _theme_over(player: AudioStreamPlayer) -> void:
	if player != _music or not track.begins_with("theme:"):
		return
	track = ""
	_heard = ""
	if _after_theme != "":
		play_track(_after_theme)
	_after_theme = ""


## Hands a story theme still playing over to its `then`, as if it had ended:
## the bundle's themes outlast the scenes that play them (PIX-416: the
## ending's 157 s against its 46 s scene), so the scene's close hands over.
## A theme with no `then` plays on for the world to replace.
func end_theme() -> void:
	if track.begins_with("theme:") and _after_theme != "":
		_theme_over(_music)


## The new theme comes in from `from` seconds as the old one goes, together,
## each on an equal-power curve: faded in dB, the two sat near -20 dB
## halfway, a dip of some 17 dB in every change of place.
func _crossfade(stream: AudioStream, level: float, from := 0.0) -> void:
	if _fade != null:
		_fade.kill()
	var outgoing := _music
	var incoming := _fading
	_music = incoming
	_fading = outgoing
	var leaving := db_to_linear(outgoing.volume_db) if outgoing.playing else 0.0
	var coming := db_to_linear(level)
	var mix := func(t: float) -> void:
		outgoing.volume_db = linear_to_db(maxf(leaving * cos(t * PI / 2.0), 0.0001))
		incoming.volume_db = linear_to_db(maxf(coming * sin(t * PI / 2.0), 0.0001))
	mix.call(0.0)
	incoming.stream = stream
	incoming.play(from)
	_fade = create_tween()
	_fade.tween_method(mix, 0.0, 1.0, CROSSFADE_S)
	_fade.tween_callback(outgoing.stop)


func stop_music() -> void:
	_keep_place()
	track = ""
	_heard = ""
	_music.stop()
	_fading.stop()


## Silence: music, weather and every stinger still ringing.
func stop_all() -> void:
	stop_music()
	set_ambience("")
	extras.clear()
	set_bed("")
	for voice in _voices() + _ambient_voices:
		voice.stop()


## The extra ambience the world asks for (PIX-158): birds or crickets,
## chatter, fire. Unknown names are ignored.
func set_extras(names: Array[String]) -> void:
	extras.assign(names.filter(func(name: String) -> bool: return _doc["ambienceExtras"].has(name)))


## A looping bed under the ambience, faded in and out: the place's own from
## the packs where they're installed (PIX-413: its "bed", an event of the
## "ambience" family, quiet under the music), else `name`, the game's own
## ("wind", "deepwind", or "" for none). The rain is always the rain's: the
## packs' only where a shower is the place (PIX-414, RAIN_PLACES); `hushed`
## keeps the place's quiet (a town burning, a night of bells).
func set_bed(name: String, hushed := false) -> void:
	var own := String(_doc["places"].get(place, {}).get("bed", ""))
	if (name != "rain" or place in RAIN_PLACES) and not hushed and not takes_of(own).is_empty():
		name = own
	elif name not in _doc["beds"]:
		name = ""
	if name == bed:
		return
	bed = name
	if _bed_fade != null:
		_bed_fade.kill()
	# Nothing to fade out or in: a tween with nothing to do is an error.
	if name == "" and not _bed.playing:
		return
	_bed_fade = create_tween()
	if _bed.playing:
		_bed_fade.tween_property(_bed, "volume_db", -40.0, FADE_S * 2)
		_bed_fade.tween_callback(_bed.stop)
	if name == "":
		return
	var take := String(takes_of(name)[0]) if name == own else ""
	var stream := _take(take) if take != "" else _stream("res://assets/audio/ambience/bed_%s.wav" % name)
	var level := float(_doc["families"]["ambience"]["db"]) if take != "" else level_of("ambience/bed_" + name)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	_bed_fade.tween_callback(func() -> void:
		_bed.stream = stream
		_bed.volume_db = -40.0
		_bed.play()
	)
	_bed_fade.tween_property(_bed, "volume_db", level, FADE_S * 3)


## Where the hero's ears are (audio.json's "places": "forest_day", "coast",
## or "" for nowhere): its one-shots ("sprinkle", one of "ambience"'s
## renders) start at once, its bed with the next `set_bed`.
func set_ambience(name: String) -> void:
	place = name if _doc["places"].has(name) else ""
	ambience = String(_doc["places"].get(place, {}).get("sprinkle", ""))


func _process(delta: float) -> void:
	_ease_hush(delta)
	if ambience == "" and extras.is_empty():
		return
	_ambience_clock += delta
	var tick: float = _doc["ambienceTick"]
	while _ambience_clock >= tick:
		_ambience_clock -= tick
		_sprinkle()
		# PIX-415: on Sound's dice, as the sprinkle is: on the game's they moved
		# what a fight rolled, and the chatter (only without the packs' crowd)
		# moved it one way with the packs and another without.
		for name in extras:
			var extra: Dictionary = _doc["ambienceExtras"][name]
			if _dice.randf() < float(extra["chance"]):
				_ambient_file("res://assets/audio/ambience/%s_%d.wav" % [name, _dice.randi() % int(extra["variants"])], level_of("ambience/" + name))


## One tick of the place's one-shots, each by its chance: a render of the
## game's ("indoor"'s pops), or an event the packs fill (PIX-414: a cave's
## drips and stones, silent without them). On Sound's own dice, so what a
## place sprinkles never moves the game's: on the game's, a new sprinkle
## moved where the Tidecaller fell and what the Mirefen dropped.
func _sprinkle() -> void:
	var events: Array = _doc["ambience"].get(ambience, [])
	for index in events.size():
		if _dice.randf() < float(events[index]["chance"]):
			if events[index].has("event"):
				play(String(events[index]["event"]), false)
			else:
				_ambient(index, _dice.randi() % int(events[index]["variants"]))


func _ambient(index: int, variant: int) -> void:
	_ambient_file("res://assets/audio/ambience/%s_%d_%d.wav" % [ambience, index, variant], level_of("ambience/%s_%d" % [ambience, index]))


func _ambient_file(path: String, level: float) -> void:
	for voice in _ambient_voices:
		if not voice.playing:
			voice.stream = _stream(path)
			voice.volume_db = level
			voice.play()
			return


## Which theme a moment deserves (trackForState): places, then a fight on top.
## `fight` is "" (none), "battle" or "boss".
static func track_for(map_id: String, fight: String) -> String:
	# The one boss the square ever holds is the Night of Bells' dragon (PIX-416).
	if fight == "boss" and map_id == "town":
		return "dragon"
	if fight != "":
		return fight
	# Every dungeon's floors play the way down (PIX-255; the Kings' Vault's
	# too, PIX-257), the crypts and the ice cave their own (PIX-416).
	var dungeon := String(Depths.floor_of(map_id).get("dungeon", ""))
	if dungeon != "":
		return String(DUNGEON_TRACKS.get(dungeon, "descent"))
	return String(PLACE_TRACKS.get(map_id, "interior"))


## Each place's track (track_for), "interior" for the rest: PIX-416 gave the
## coast, the Frostgate, Greyhold, Fernoir, the mountain road and the inn
## their own, each its "fallback"'s (the Reach's, the rooms') without the
## bundle: the road's the Reach's, no longer the rooms' tune it fell to.
const PLACE_TRACKS := {
	"town": "town", "deepwood": "deepwood", "mirefen": "mirefen", "overworld": "world", "demo": "world",
	"saltmere": "coast", "frostgate": "frost", "greyhold": "greyhold", "blackiron": "fernoir",
	"mountain_road": "mountain", "town_inn": "inn",
}
## A dungeon's floors' track where it isn't the way down's (PIX-416).
const DUNGEON_TRACKS := {"cellars": "crypt", "vault": "crypt", "icecave": "icecave"}


## Where the hero's ears are (ambienceForState): a key of audio.json's
## "places". PIX-413: the sea at Saltmere and the ash at Fernoir, never
## birdsong; the wind at the Frostgate and on the mountain road, never a
## hearth; the Reach by the ground underfoot (`region`: its ash, its marsh);
## the woods, the marsh and the town by day or `night`; the mines' shafts
## and the caves their own. PIX-414: the smith's forge; a shower heard
## (`rain`) in the open, through a wood's leaves or on a village house's
## roof; running water `river` (near_river) in the village and on the
## Reach's open land; under the ground by the dungeon: the cellars and the
## Kings' Vault a crypt's, the ice cave its own.
static func ambience_for(map_id: String, region := "", night := false, rain := false, river := false) -> String:
	if map_id == "town_smith":
		return "smithy"
	if rain:
		if map_id.begins_with("town_"):
			return "rain_inside"
		return "rain_forest" if map_id == "deepwood" or region == "forest" else "rain"
	match map_id:
		"saltmere":
			return "coast"
		"blackiron", "mountain_road":
			return "ash"
		"frostgate":
			return "frost"
		"deepwood":
			return "deepforest_night" if night else "deepforest"
		"mirefen":
			return "marsh_night" if night else "marsh"
		"town":
			if river:
				return "river"
			return "forest_night" if night else "town"
		"overworld", "demo", "greyhold":
			# The ash and the marsh keep theirs by the river: no songbird there.
			match region:
				"ash":
					return "ash"
				"marsh":
					return "marsh_night" if night else "marsh"
			if river:
				return "river"
			return "forest_night" if night else "forest_day"
	match String(Depths.floor_of(map_id).get("dungeon", "")):
		"":
			return "indoor"
		"shafts":
			return "mines"
		"cellars", "vault":
			return "crypt"
		"icecave":
			return "ice_cave"
	return "cave"


## Places a shower is (ambience_for): their bed is the rain's.
const RAIN_PLACES: Array[String] = ["rain", "rain_forest", "rain_inside"]
## How near running water is heard, in cells either way (PIX-414): on a
## river's bank or its bridge, or a few steps off it.
const RIVER_NEAR := 3


## Whether running water lies within RIVER_NEAR cells of `cell` (PIX-414):
## a river's water or its bridge, on a map whose inland water runs
## (PunyTerrain's tones: not the Mirefen's pools, the Deepwood's lake or
## the Frostgate's ice, which lie still).
static func near_river(map: MapData, cell: Vector2i) -> bool:
	if PunyTerrain.WATER_TONES.get(map.id, PunyTerrain.WATER_CLEAR) in PunyTerrain.STILL_WATERS:
		return false
	for dy in range(-RIVER_NEAR, RIVER_NEAR + 1):
		for dx in range(-RIVER_NEAR, RIVER_NEAR + 1):
			if map.tile_at(cell + Vector2i(dx, dy)) in ["water", "bridge"]:
				return true
	return false
