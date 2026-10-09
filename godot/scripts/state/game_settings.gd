class_name GameSettings
## Device preferences (src/app/settings.ts), deliberately NOT part of the save
## so they never travel inside a save code: volumes (applied once audio lands,
## PIX-128), the CRT scanlines, fullscreen, reduced motion and key bindings.
## The web's renderer choice did not survive the port.

const SECTION := "settings"

var path := "user://settings.cfg"
## 0..1
var music_volume := 0.7
## 0..1
var sfx_volume := 0.7
var reduce_motion := false
var muted := false
var scanlines := false
var fullscreen := false
## Rebound primary keys: action -> physical keycode (Controls).
var bindings := {}
## The save slot Continue resumes.
var last_slot := 1
## The newest version whose notes were read (What's new), so the title can
## flag a new one (hasUnseenChanges); "" before any.
var seen_version := ""
## How the pack lists what it holds (InventoryState.SORTS).
var pack_sort := "kind"
## Accessibility (PIX-160): what's read in the big type, attack marks in
## hazard stripes, and the first-time hints (with the ones already given).
var large_text := false
var clear_warnings := false
var hints := true
var hints_seen: Array[String] = []
## The language the game speaks (PIX-195): a Text.LANGUAGES code, or ""
## to follow the system's.
var language := ""
## Harness runs read the player's settings but never write them.
var read_only := false


func _init(file_path := "user://settings.cfg") -> void:
	path = file_path


func load_file() -> void:
	# A phone reads at arm's length (PIX-214): large text unless told otherwise.
	large_text = Touch.enabled()
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	music_volume = clampf(config.get_value(SECTION, "music_volume", music_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value(SECTION, "sfx_volume", sfx_volume), 0.0, 1.0)
	reduce_motion = config.get_value(SECTION, "reduce_motion", reduce_motion)
	last_slot = config.get_value(SECTION, "last_slot", last_slot)
	scanlines = config.get_value(SECTION, "scanlines", scanlines)
	muted = config.get_value(SECTION, "muted", muted)
	fullscreen = config.get_value(SECTION, "fullscreen", fullscreen)
	seen_version = str(config.get_value(SECTION, "seen_version", seen_version))
	pack_sort = str(config.get_value(SECTION, "pack_sort", pack_sort))
	large_text = config.get_value(SECTION, "large_text", large_text)
	clear_warnings = config.get_value(SECTION, "clear_warnings", clear_warnings)
	hints = config.get_value(SECTION, "hints", hints)
	language = str(config.get_value(SECTION, "language", language))
	hints_seen.assign(config.get_value(SECTION, "hints_seen", []))
	var saved: Variant = config.get_value(SECTION, "bindings", {})
	bindings = {}
	if saved is Dictionary:
		for action: String in saved:
			if Controls.BINDABLE.has(action):
				bindings[action] = int(saved[action])


func save_file() -> void:
	if read_only:
		return
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "reduce_motion", reduce_motion)
	config.set_value(SECTION, "last_slot", last_slot)
	config.set_value(SECTION, "scanlines", scanlines)
	config.set_value(SECTION, "muted", muted)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "seen_version", seen_version)
	config.set_value(SECTION, "pack_sort", pack_sort)
	config.set_value(SECTION, "large_text", large_text)
	config.set_value(SECTION, "clear_warnings", clear_warnings)
	config.set_value(SECTION, "language", language)
	config.set_value(SECTION, "hints", hints)
	config.set_value(SECTION, "hints_seen", hints_seen)
	config.set_value(SECTION, "bindings", bindings)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	config.save(path)
