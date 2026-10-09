extends "res://scripts/ledger_screen.gd"
## The floor select at a dungeon gate (DungeonSelect.tsx): every floor with
## its name and story once open, CLEARED once beaten, ??? until the floor
## before it falls; a seal on the Undermountain until the dragon does, and no
## way in while the pack is over its weight. The hero waits at the door.

## The world, to send the hero down; the dungeon behind this gate.
var world: Node
var dungeon_id := ""


func _open() -> void:
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


## The floors behind this gate, then - below Morvax's throne, once he is
## down (PIX-161) - the Deep Hunt: its first depth, the first of every tier
## reached (PIX-216), and the next one past the deepest the hero has cleared.
func _levels() -> Array:
	var levels: Array = Dungeons.dungeon(dungeon_id)["floors"].duplicate()
	if Dungeons.floor_count() in levels and Dungeons.floor_count() in GameState.progression.cleared_levels:
		for depth: int in Dungeons.deep_entries(GameState.progression.deepest):
			levels.append(Dungeons.floor_count() + depth)
	return levels


func _is_open(level: int) -> bool:
	return Dungeons.is_deep(level) or Dungeons.is_open(level, GameState.progression.unlocked_level)


func _info() -> String:
	var floors := _levels()
	if selected >= floors.size():
		return ""
	var level: int = floors[selected]
	if not _is_open(level):
		return Text.t("Floor %d\n\nClear the previous floor to unlock.") % level
	var floor_def := Dungeons.floor_def(level)
	var guardian := Dungeons.boss_of(level)
	# A warden goes by its own name (PIX-216).
	var guardian_name: String = Text.t(guardian["name"]) if guardian.has("name") else Bestiary.monster(guardian["monsterId"])["name"]
	var lines: Array[String] = [
		floor_def["name"] if Dungeons.is_deep(level) else Text.t("Floor %d: %s") % [level, floor_def["name"]],
		String(floor_def["description"]),
		"",
		Text.t("Guardian: %s, level %d") % [Text.t("Elite %s") % guardian_name if guardian.get("elite", false) else guardian_name, int(Bestiary.monster(guardian["monsterId"])["level"]) + int(guardian.get("lift", Dungeons.lift(level)))],
	]
	if Dungeons.is_deep(level):
		var twist := Dungeons.modifier(level)
		if not twist.is_empty():
			lines.append(Text.t("Twist: %s. %s Its foes drop more.") % [Text.t(twist["name"]), Text.t(twist["line"])])
		lines.append(Text.t("Deepest cleared so far: depth %d.") % GameState.progression.deepest if GameState.progression.deepest > 0 else Text.t("No one has gone this deep and come back."))
		var mark := Dungeons.next_milestone(GameState.progression.deepest)
		if not mark.is_empty():
			lines.append(Text.t("Next milestone: depth %d, for the %s.") % [int(mark["depth"]), Catalog.item_name(mark["itemId"])])
		if Dungeons.depth_of(level) <= GameState.progression.deepest:
			lines.append(Text.t("Beaten before: only its fights pay now."))
		else:
			var deep_hoard: Array[String] = [Text.t("%d XP") % Dungeons.clear_xp(level), Text.coins(int(floor_def["rewardGold"]))]
			for item_id: String in floor_def["rewardItemIds"]:
				deep_hoard.append(Catalog.item_name(item_id))
			lines.append(Text.t("A new deepest: %s") % ", ".join(deep_hoard))
	elif level in GameState.progression.cleared_levels:
		lines.append(Text.t("Cleared. Its hoard is already yours."))
	else:
		var hoard: Array[String] = [Text.t("%d XP") % Dungeons.clear_xp(level), Text.coins(int(floor_def["rewardGold"]))]
		for item_id: String in floor_def["rewardItemIds"]:
			hoard.append(Catalog.item_name(item_id))
		lines.append(Text.t("First clear: %s") % ", ".join(hoard))
	return "\n".join(lines)


func _rows() -> Array[Dictionary]:
	var rows_out: Array[Dictionary] = []
	var heavy := _over_encumbered()
	for level: int in _levels():
		var open := _is_open(level)
		var deep := Dungeons.is_deep(level)
		rows_out.append({
			"label": ("    %s" if deep else "%2d  %s") % ([Dungeons.floor_def(level)["name"]] if deep else [level, Dungeons.floor_def(level)["name"] if open else "???"]),
			"note": (Text.t("DEEPEST %d") % GameState.progression.deepest if GameState.progression.deepest > 0 and level == Dungeons.floor_count() + 1 else "") if deep else (Text.t("CLEARED") if level in GameState.progression.cleared_levels else ""),
			"enabled": open and not heavy,
			"why": "Over-encumbered! Drop something before venturing in." if open else "Clear the previous floor to unlock.",
			"action": _descend.bind(level),
		})
	rows_out.append({"label": "Step away", "note": "", "enabled": true, "action": _step_away})
	return rows_out


func _step_away() -> String:
	close()
	return ""


func _descend(level: int) -> String:
	close()
	world.delve.enter_floor(level)
	return ""


func _over_encumbered() -> bool:
	return GameState.pack.carried_weight() > GameState.carry_capacity()
