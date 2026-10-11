extends "res://scripts/ledger_screen.gd"
## The bounty board on the square (PIX-156): the named monsters posted so far,
## the wanted first, then the slain. The card tells the chosen one's tale,
## where its lair is and what it pays; the lairs of the wanted are marked on
## the map too. A new notice goes up as the relics come home, or as the
## town grows (Grandmother Gulp, once Pixelheim is a Town: PIX-257); the old
## mountain's floors posted some too, before they left play.


func _title() -> String:
	return "Bounties"


func _intro() -> String:
	return Text.t("Kill a named monster and the bounty is yours where it falls.")


func _info() -> String:
	var chosen := _chosen()
	if chosen.is_empty():
		var first := _when(Hunts.next_notice(GameState.questing.board_floors()))
		if first == "":
			return Text.t("No notices yet. The board waits for word from the wilds.")
		return Text.t("No notices yet. The board waits for word from the wilds.\n\nThe first one goes up when %s.") % first
	var slain: bool = chosen["id"] in GameState.progression.hunted
	var lines: Array[String] = [(Text.t("Slain: %s") if slain else Text.t("Wanted: %s")) % chosen["name"], "", String(chosen["notice"]), ""]
	lines.append(Text.t("Its lair: %s.") % chosen["where"])
	lines.append("%s." % Hunts.reward_line(chosen))
	if slain:
		lines.append_array(["", String(chosen["homecoming"])])
	var next := _when(Hunts.next_notice(GameState.questing.board_floors()))
	if next != "":
		lines.append_array(["", Text.t("Another notice goes up when %s.") % next])
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
			"action": func() -> String: return Text.t("%s keeps to %s. Its lair is marked on your map.") % [entry["name"], entry["where"]],
		})
	return out


func _chosen() -> Dictionary:
	if rows.is_empty() or selected >= rows.size():
		return {}
	return Hunts.named(rows[selected]["named"])


## When a notice goes up: enough of the five relics won out in the Reach
## (PIX-170), or Pixelheim grown to a town (PIX-257: Grandmother Gulp); ""
## for one only the old mountain's floors posted, which left play: the
## board says nothing of when, rather than send the hero to a floor.
static func _when(entry: Dictionary) -> String:
	if entry.has("postedTier"):
		return Text.t("Pixelheim has grown into a town")
	if not entry.has("postedRelics"):
		return ""
	var relics := int(entry["postedRelics"])
	# Words a language can say its own way (PIX-196): the count, and is/are.
	var count: String = [Text.t("one"), Text.t("two"), Text.t("three"), Text.t("four")][relics - 1]
	return (Text.t("%s of the relics is home") if relics == 1 else Text.t("%s of the relics are home")) % count
