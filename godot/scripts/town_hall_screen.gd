extends "res://scripts/ledger_screen.gd"
## The town ledger across the mayor's counter (TownHall.tsx): where Pixelheim
## stands, what the next charter brings, and funding it. The town redraws
## itself when the hero walks back out.


func _title() -> String:
	return "Town ledger"


func _intro() -> String:
	return "Mayor Aldric keeps the books. Fund a charter and Pixelheim grows."


func _info() -> String:
	var now := Town.tier(GameState.town_tier())
	var lines: Array[String] = [
		"Pixelheim today: %s (age %d of %d)" % [now["name"], now["tier"], Town.MAX_TIER],
		String(now["blurb"]),
		"",
	]
	for perk: String in now["perks"]:
		lines.append("- " + perk)
	var next := Town.next_tier(GameState.town_tier())
	if not next.is_empty():
		lines.append_array(["", "Next: %s, %dg" % [next["name"], next["cost"]], String(next["blurb"])])
		for perk: String in next["perks"]:
			lines.append("- " + perk)
		var requires: Dictionary = next.get("requires", {})
		if not requires.is_empty():
			var met := Town.requirement_met(requires["key"], GameState.owns_house(), GameState.settlement.properties)
			lines.append("%s %s" % ["Done:" if met else "Needed:", requires["line"]])
	return "\n".join(lines)


func _rows() -> Array[Dictionary]:
	var next := Town.next_tier(GameState.town_tier())
	if next.is_empty():
		return [{
			"label": "Pixelheim stands at its full height.", "note": "", "enabled": false,
			"why": "There is no higher charter.", "action": func() -> String: return "",
		}]
	var blocker := Town.fund_blocker(
		GameState.town_tier(), GameState.pack.gold, GameState.owns_house(), GameState.settlement.properties
	)
	return [{
		"label": "Fund the %s charter" % next["name"], "note": "%dg" % next["cost"],
		"enabled": blocker == "", "why": blocker,
		"action": func() -> String: return GameState.fund_town(),
	}]
