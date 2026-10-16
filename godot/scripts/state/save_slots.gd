class_name SaveSlots
## Save slots on disk: <dir>/slot_<n>.save, each a v5 save file (SaveCodec,
## PIX-302). On the web export user:// lives in IndexedDB.
##
## No hero is lost to a file (PIX-303). A write goes to a temp file, is read
## back and decoded, then the slot's file becomes `slot_<n>.save.bak` (the
## save before) and the temp file takes its place: a crash mid-write, or a
## bug that writes a broken state, never eats the last good save. Reading
## falls back to the temp file (a write cut off between its two renames)
## and then to the backup when the slot's file can't be read, and says so.
## A file that can't be read at all, or that a newer version wrote, is
## never an empty slot: nothing is written over it, and a write that finds
## one there keeps its bytes (`.damaged`) or refuses (newer).
##
## The saves before v5 (`slot_<n>.json`, the first edition's format) don't
## load until the beta (Tom, 2026-10-16): a slot holding one and no v5 save
## is OLDER, never free, kept as it is until it's cleared. Nothing writes
## the old file.

const SLOT_COUNT := 3
## What a slot holds (`look`): nothing, a hero this version plays, a file it
## can't read, a save a newer version wrote, or one from before v5.
const EMPTY := "empty"
const HERO := "hero"
const DAMAGED := "damaged"
const NEWER := "newer"
const OLDER := "older"

var dir := "user://saves"
## Read, never written or erased: harness runs over a folder of slots
## (`--slots`, the test fixtures).
var read_only := false
## Per slot, the hash of the slot file's text known to read (this session
## read or wrote it), so a write rotates it to the backup without decoding
## it again.
var _known := {}


func _init(directory := "user://saves", reading_only := false) -> void:
	dir = directory
	read_only = reading_only


func path_for(slot: int) -> String:
	return "%s/slot_%d.save" % [dir, slot]


## The save before the slot's file, kept by every write.
func backup_for(slot: int) -> String:
	return path_for(slot) + ".bak"


## A write on its way: decoded before it replaces anything.
func temp_for(slot: int) -> String:
	return path_for(slot) + ".tmp"


## A slot file that couldn't be read, moved aside rather than written over
## when the hero from its backup is saved again.
func aside_for(slot: int) -> String:
	return path_for(slot) + ".damaged"


## The slot's files from before v5: the first edition's save and what its
## safe writes left beside it (read never, cleared with the slot).
func older_for(slot: int) -> Array[String]:
	var old := "%s/slot_%d.json" % [dir, slot]
	return [old, old + ".bak", old + ".tmp", old + ".damaged"]


## Writes the state as the slot's save; false when nothing changed on disk
## (read-only, a temp file that didn't read back, a newer save in the slot).
func write(slot: int, state: Dictionary) -> bool:
	if read_only:
		return false
	DirAccess.make_dir_recursive_absolute(dir)
	var text := SaveCodec.serialize(SaveCodec.to_file(state, int(Time.get_unix_time_from_system())))
	var temp := temp_for(slot)
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	# Read back what landed, every byte, and decode it: a full disk cuts it
	# short, and a state a bug broke is no hero anyone could load.
	if FileAccess.get_file_as_string(temp) != text or not SaveCodec.decodes(text):
		DirAccess.remove_absolute(temp)
		return false
	var main := path_for(slot)
	if FileAccess.file_exists(main):
		var keep := backup_for(slot)
		match _main_kind(slot):
			NEWER:
				# A newer version's hero: never replaced from here.
				DirAccess.remove_absolute(temp)
				return false
			DAMAGED:
				# Unreadable, and the backup the hero came from is the good
				# one: it stays, and these bytes are moved aside, not lost.
				keep = aside_for(slot)
		if DirAccess.rename_absolute(main, keep) != OK:
			DirAccess.remove_absolute(temp)
			return false
	if DirAccess.rename_absolute(temp, main) != OK:
		return false
	_known[slot] = text.hash()
	return true


## What the slot holds, as playing it would read it: `{kind}` and, for a
## HERO, its `state`, its `card` (SaveCodec.card), `savedAt`, `game` (the
## version that wrote it) and `backup` true when it came from the save
## before (the slot's file unreadable). A newer save is NEWER even with an
## older backup beside it: falling back would lose its progress. Anything on
## disk that reads as no hero is DAMAGED, never EMPTY, but for a temp file
## alone (a first write cut off: never a save); a slot with no v5 save but
## a file from before is OLDER.
func look(slot: int) -> Dictionary:
	var main := _file(path_for(slot))
	if main["kind"] == HERO:
		_known[slot] = main["hash"]
	if main["kind"] in [HERO, NEWER]:
		return main
	# The slot's file missing or unreadable: a write cut off between its two
	# renames left the newest save in the temp file; else the save before.
	var temp := _file(temp_for(slot))
	if temp["kind"] == HERO:
		return temp
	var backup := _file(backup_for(slot))
	if backup["kind"] == HERO:
		backup["backup"] = true
		return backup
	if backup["kind"] == NEWER:
		return backup
	if main["kind"] == DAMAGED or backup["kind"] == DAMAGED:
		return {"kind": DAMAGED}
	if older_for(slot).any(func(path: String) -> bool: return FileAccess.file_exists(path)):
		return {"kind": OLDER}
	return {"kind": EMPTY}


## Whether a new hero may take the slot: nothing at all is in it.
func is_free(slot: int) -> bool:
	return look(slot)["kind"] == EMPTY


## The slot's state, ready to play; {} when there's no hero to play.
func read(slot: int) -> Dictionary:
	var seen := look(slot)
	return seen["state"] if seen["kind"] == HERO else {}


## What a slot picker shows: `{kind}`, and for a HERO its card (name,
## roleId, look, worn, level, mapId, chapter, playSeconds), its gold,
## savedAt, the version that wrote it and `backup`.
func summary(slot: int) -> Dictionary:
	var seen := look(slot)
	if seen["kind"] != HERO:
		return {"kind": seen["kind"]}
	var card: Dictionary = seen["card"]
	return {
		"kind": HERO,
		"name": card["name"],
		"roleId": card["role"],
		"look": card.get("look", 0),
		# What the hero wears, so the slot shows them as they left (PIX-175).
		"worn": card.get("worn", {}),
		"level": card["level"],
		"mapId": card["place"],
		"chapter": int(card.get("chapter", 0)),
		"playSeconds": int(card.get("playSeconds", 0)),
		"gold": seen["state"]["gold"],
		"savedAt": seen["savedAt"],
		"game": seen["game"],
		"backup": seen.get("backup", false),
	}


## Empties a slot: its file, the save before, a write left over, any bytes
## moved aside, and a save from before v5.
func erase(slot: int) -> void:
	if read_only:
		return
	for path in [path_for(slot), temp_for(slot), backup_for(slot), aside_for(slot)] + older_for(slot):
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	_known.erase(slot)


## One file's kind (and for a HERO its state, card, savedAt, game and the
## text's hash).
func _file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"kind": EMPTY}
	var text := FileAccess.get_file_as_string(path)
	var raw: Variant = SaveCodec.parse_json(text)
	if SaveCodec.age(raw) == SaveCodec.NEWER:
		return {"kind": NEWER}
	var state := SaveCodec.from_file(raw)
	if state.is_empty() or not raw.get("card") is Dictionary:
		return {"kind": DAMAGED}
	return {
		"kind": HERO, "state": state, "card": raw["card"], "savedAt": int(raw.get("savedAt", 0)),
		"game": String(raw.get("game", "")), "hash": text.hash(),
	}


## The slot file's kind before a write replaces it: what this session read
## or wrote there is a HERO without decoding it again.
func _main_kind(slot: int) -> String:
	var text := FileAccess.get_file_as_string(path_for(slot))
	if _known.has(slot) and _known[slot] == text.hash():
		return HERO
	return _file(path_for(slot))["kind"]
