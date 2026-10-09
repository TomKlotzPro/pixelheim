extends "res://scripts/ledger_screen.gd"
## The bounty board on the square (PIX-156): the named monsters posted so far,
## the wanted first, then the slain. The card tells the chosen one's tale,
## where its lair is and what it pays; the lairs of the wanted are marked on
## the map too. A new notice goes up as the hero clears deeper floors.


func _title() -> String:
	return "Bounties"


func _intro() -> String:
	var deepest := GameState.progression.deepest
	var record := Text.t("   Deepest Hunt: depth %d.") % deepest if deepest > 0 else ""
	return Text.t("Kill a named monster and the bounty is yours where it falls.%s") % record


func _info() -> String:
	var chosen := _chosen()
	if chosen.is_empty():
		var first := Hunts.next_notice(GameState.questing.board_floors())
		return Text.t("No notices yet. The board waits for word from the wilds.\n\nThe first one goes up when %s.") % _when(first)
	var slain: bool = chosen["id"] in GameState.progression.hunted
	var lines: Array[String] = [(Text.t("Slain: %s") if slain else Text.t("Wanted: %s")) % chosen["name"], "", String(chosen["notice"]), ""]
	lines.append(Text.t("Its lair: %s.") % chosen["where"])
	lines.append("%s." % Hunts.reward_line(chosen))
	if slain:
		lines.append_array(["", String(chosen["homecoming"])])
	var next := Hunts.next_notice(GameState.questing.board_floors())
	if not next.is_empty():
		lines.append_array(["", Text.t("Another notice goes up when %s.") % _when(next)])
	return "\n".join(lines)


func _verb() -> String:
	return Text.t("where")


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in Hunts.notices(GameState.questing.board_floors(), GameState.progression.hunted):
		var slain: bool = entry["id"] in GameState.progression.hunted
		out.append({
			"named": entry["id"],
			"label": entry["name"],
			"note": Text.t("SLAIN") if slain else Text.coins(int(entry["bounty"])),
			"enabled": not slain,
			"why": "Slain. Pixelheim still talks about it.",
			# A Deep Hunt one guards its depth's stair (PIX-219), not a lair on the map.
			"action": func() -> String: return Text.t("%s keeps to %s.") % [entry["name"], entry["where"]] if entry.has("deepDepth") else Text.t("%s keeps to %s. Its lair is marked on your map.") % [entry["name"], entry["where"]],
		})
	return out


func _chosen() -> Dictionary:
	if rows.is_empty() or selected >= rows.size():
		return {}
	return Hunts.named(rows[selected]["named"])


## "the Barrow Crypt (floor 3)".
## When a notice goes up: its floor cleared, or enough of the five relics
## won out in the Reach (PIX-170).
static func _when(entry: Dictionary) -> String:
	if entry.has("deepDepth"):
		return Text.t("depth %d of the Deep Hunt is cleared") % (int(entry["deepDepth"]) - 1)
	var cleared := Text.t("%s is cleared") % _floor_name(int(entry["postedAfter"]))
	if not entry.has("postedRelics"):
		return cleared
	var relics := int(entry["postedRelics"])
	# Words a language can say its own way (PIX-196): the count, and is/are.
	var count: String = [Text.t("one"), Text.t("two"), Text.t("three"), Text.t("four")][relics - 1]
	# Floors are no alternative while the gate is barred (PIX-204).
	if not Relics.gate_open(GameState.progression):
		return (Text.t("%s of the relics is home") if relics == 1 else Text.t("%s of the relics are home")) % count
	var said := Text.t("%s of the relics is home, or %s") if relics == 1 else Text.t("%s of the relics are home, or %s")
	return said % [count, cleared]


static func _floor_name(level: int) -> String:
	var floor_def: Dictionary = Bestiary._data()["levels"][level - 1]
	return Text.t("the %s (floor %d)") % [Text.mid(String(floor_def["name"]).trim_prefix("The ")), level]
