extends "res://scripts/ledger_screen.gd"
## The floor select at a dungeon gate (DungeonSelect.tsx): every floor with
## its name and story once open, CLEARED once beaten, ??? until the floor
## before it falls; a seal on the Undermountain until the dragon does, and no
## way in while the pack is over its weight. The hero waits at the door.

## The world, to send the hero down; the dungeon behind this gate.
var world: Node
var dungeon_id := ""


func _ready() -> void:
	super()
	# Start on the deepest open floor: where the hero is headed.
	var floors: Array = Dungeons.dungeon(dungeon_id)["floors"]
	for index in floors.size():
		if Dungeons.is_open(floors[index], GameState.progression.unlocked_level):
			selected = index
	_refresh()


func _title() -> String:
	return Dungeons.dungeon(dungeon_id)["name"]


func _intro() -> String:
	if _over_encumbered():
		return "Over-encumbered! Drop something before venturing in."
	var sealed: String = Dungeons.dungeon(dungeon_id).get("sealed", "")
	if sealed != "" and not Dungeons.any_open(dungeon_id, GameState.progression.unlocked_level):
		return sealed
	return "Choose a floor. Beat its guardian and the stairs lead back to this gate."


func _info() -> String:
	var floors: Array = Dungeons.dungeon(dungeon_id)["floors"]
	if selected >= floors.size():
		return ""
	var level: int = floors[selected]
	if not Dungeons.is_open(level, GameState.progression.unlocked_level):
		return "Floor %d\n\nClear the previous floor to unlock." % level
	var floor_def := Dungeons.floor_def(level)
	var guardian := Dungeons.boss_of(level)
	var guardian_name: String = Bestiary.monster(guardian["monsterId"])["name"]
	var lines: Array[String] = [
		"Floor %d: %s" % [level, floor_def["name"]],
		String(floor_def["description"]),
		"",
		"Guardian: %s%s" % ["Elite " if guardian.get("elite", false) else "", guardian_name],
	]
	if level in GameState.progression.cleared_levels:
		lines.append("Cleared. Its hoard is already yours.")
	else:
		var hoard: Array[String] = ["%dg" % floor_def["rewardGold"]]
		for item_id: String in floor_def["rewardItemIds"]:
			hoard.append(Catalog.item_name(item_id))
		lines.append("First clear: %s" % ", ".join(hoard))
	return "\n".join(lines)


func _rows() -> Array[Dictionary]:
	var rows_out: Array[Dictionary] = []
	var unlocked := GameState.progression.unlocked_level
	var heavy := _over_encumbered()
	for level: int in Dungeons.dungeon(dungeon_id)["floors"]:
		var open := Dungeons.is_open(level, unlocked)
		rows_out.append({
			"label": "%2d  %s" % [level, Dungeons.floor_def(level)["name"] if open else "???"],
			"note": "CLEARED" if level in GameState.progression.cleared_levels else "",
			"enabled": open and not heavy,
			"why": "Over-encumbered! Drop something before venturing in." if open else "Clear the previous floor to unlock.",
			"action": _descend.bind(level),
		})
	rows_out.append({"label": "Step away", "note": "", "enabled": true, "action": _step_away})
	return rows_out


func _step_away() -> String:
	_close()
	return ""


func _descend(level: int) -> String:
	_close()
	world.enter_floor(level)
	return ""


func _over_encumbered() -> bool:
	return GameState.pack.carried_weight() > GameState.carry_capacity()
