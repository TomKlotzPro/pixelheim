extends "res://scripts/ledger_screen.gd"
## The bounty board on the square (PIX-156): the named monsters posted so far,
## the wanted first, then the slain. The card tells the chosen one's tale,
## where its lair is and what it pays; the lairs of the wanted are marked on
## the map too. A new notice goes up as the hero clears deeper floors.


func _title() -> String:
	return "Bounties"


func _intro() -> String:
	return "Kill a named monster and the bounty is yours where it falls."


func _info() -> String:
	var chosen := _chosen()
	if chosen.is_empty():
		var first := Hunts.next_notice(GameState.progression.cleared_levels)
		return "No notices yet. The board waits for word from the wilds.\n\nClear %s and the first one goes up." % _floor_name(int(first["postedAfter"]))
	var slain: bool = chosen["id"] in GameState.progression.hunted
	var lines: Array[String] = ["%s: %s" % ["Slain" if slain else "Wanted", chosen["name"]], "", String(chosen["notice"]), ""]
	lines.append("Its lair: %s." % chosen["where"])
	lines.append("%s." % Hunts.reward_line(chosen))
	if slain:
		lines.append_array(["", String(chosen["homecoming"])])
	var next := Hunts.next_notice(GameState.progression.cleared_levels)
	if not next.is_empty():
		lines.append_array(["", "Another notice goes up when %s is cleared." % _floor_name(int(next["postedAfter"]))])
	return "\n".join(lines)


func _verb() -> String:
	return "where"


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in Hunts.notices(GameState.progression.cleared_levels, GameState.progression.hunted):
		var slain: bool = entry["id"] in GameState.progression.hunted
		out.append({
			"named": entry["id"],
			"label": entry["name"],
			"note": "SLAIN" if slain else "%dg" % int(entry["bounty"]),
			"enabled": not slain,
			"why": "Slain. Pixelheim still talks about it.",
			"action": func() -> String: return "%s keeps to %s. Its lair is marked on your map." % [entry["name"], entry["where"]],
		})
	return out


func _chosen() -> Dictionary:
	if rows.is_empty() or selected >= rows.size():
		return {}
	return Hunts.named(rows[selected]["named"])


## "the Barrow Crypt (floor 3)".
static func _floor_name(level: int) -> String:
	var floor_def: Dictionary = Bestiary._data()["levels"][level - 1]
	return "the %s (floor %d)" % [String(floor_def["name"]).trim_prefix("The "), level]
