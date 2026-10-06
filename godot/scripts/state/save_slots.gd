class_name SaveSlots
## Save slots on disk: <dir>/slot_<n>.json, each file a web-format envelope
## (version + state) plus savedAt, so any slot also loads in the web game.
## Writes go to a temp file renamed over the slot: a crash mid-write never
## eats the previous save. On the web export user:// lives in IndexedDB.

const SLOT_COUNT := 3

var dir := "user://saves"


func _init(directory := "user://saves") -> void:
	dir = directory


func path_for(slot: int) -> String:
	return "%s/slot_%d.json" % [dir, slot]


func write(slot: int, state: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)
	var envelope := {
		"version": SaveCodec.SAVE_VERSION,
		"state": state,
		"savedAt": int(Time.get_unix_time_from_system()),
	}
	var temp := path_for(slot) + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(envelope))
	file.close()
	return DirAccess.rename_absolute(temp, path_for(slot)) == OK


## The slot's state, migrated and normalized; {} when empty or unreadable.
func read(slot: int) -> Dictionary:
	return SaveCodec.migrate(_raw(slot))


## What a slot picker shows; {} for an empty slot.
func summary(slot: int) -> Dictionary:
	var raw: Variant = _raw(slot)
	var state := SaveCodec.migrate(raw)
	if state.is_empty():
		return {}
	return {
		"name": state["hero"]["name"],
		"roleId": state["hero"]["roleId"],
		"level": state["hero"]["level"],
		"gold": state["gold"],
		"mapId": state["world"]["position"]["mapId"],
		"savedAt": raw.get("savedAt", 0),
	}


func _raw(slot: int) -> Variant:
	if not FileAccess.file_exists(path_for(slot)):
		return null
	return SaveCodec.parse_json(FileAccess.get_file_as_string(path_for(slot)))


func erase(slot: int) -> void:
	if FileAccess.file_exists(path_for(slot)):
		DirAccess.remove_absolute(path_for(slot))
