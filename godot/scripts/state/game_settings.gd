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
var scanlines := false
var fullscreen := false
## Rebound primary keys: action -> physical keycode (Controls).
var bindings := {}
## The save slot Continue resumes.
var last_slot := 1


func _init(file_path := "user://settings.cfg") -> void:
	path = file_path


func load_file() -> void:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	music_volume = clampf(config.get_value(SECTION, "music_volume", music_volume), 0.0, 1.0)
	sfx_volume = clampf(config.get_value(SECTION, "sfx_volume", sfx_volume), 0.0, 1.0)
	reduce_motion = config.get_value(SECTION, "reduce_motion", reduce_motion)
	last_slot = config.get_value(SECTION, "last_slot", last_slot)
	scanlines = config.get_value(SECTION, "scanlines", scanlines)
	fullscreen = config.get_value(SECTION, "fullscreen", fullscreen)
	var saved: Variant = config.get_value(SECTION, "bindings", {})
	bindings = {}
	if saved is Dictionary:
		for action: String in saved:
			if Controls.BINDABLE.has(action):
				bindings[action] = int(saved[action])


func save_file() -> void:
	var config := ConfigFile.new()
	config.set_value(SECTION, "music_volume", music_volume)
	config.set_value(SECTION, "sfx_volume", sfx_volume)
	config.set_value(SECTION, "reduce_motion", reduce_motion)
	config.set_value(SECTION, "last_slot", last_slot)
	config.set_value(SECTION, "scanlines", scanlines)
	config.set_value(SECTION, "fullscreen", fullscreen)
	config.set_value(SECTION, "bindings", bindings)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	config.save(path)
