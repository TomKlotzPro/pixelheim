extends "res://scripts/ledger_screen.gd"
## The village's projects (PIX-145), across the mayor's counter or at the
## board on the square: where Pixelheim stands, what the age it is building
## asks, and each of that age's projects to fund - gold and a region's
## material, and the town changes at once. The last project of an age raises
## the town to it, with that age's perks.


func _title() -> String:
	return "Village projects"


func _intro() -> String:
	return "Fund a project and Pixelheim changes the moment you walk outside."


func _info() -> String:
	var now := Town.tier(GameState.town_tier())
	var lines: Array[String] = [
		"Pixelheim today: %s (age %d of %d)" % [now["name"], now["tier"], Town.MAX_TIER],
		String(now["blurb"]),
	]
	var building := Town.current_age(GameState.settlement)
	if building == 0:
		lines.append_array(["", "Every project is built. Pixelheim stands at its full height."])
		return "\n".join(lines)
	lines.append_array(["", "Building the %s" % Town.tier(building)["name"]])
	var blockers := Town.age_blockers(building, GameState.progression, GameState.settlement)
	for need: Dictionary in Town.age(building)["requires"]:
		lines.append("%s %s" % ["Needed:" if need["line"] in blockers else "Done:", need["line"]])
	lines.append("When it's done: %s." % "; ".join(Town.tier(building)["perks"]).to_lower())
	var chosen := _chosen_project()
	if not chosen.is_empty():
		lines.append_array(["", "%s: %s" % [chosen["name"], chosen["blurb"]]])
	return "\n".join(lines)


## Who has come to live here, and what each brings (PIX-148): on the page,
## under the projects.
func _refresh() -> void:
	super._refresh()
	var perks := Town.settler_perks(GameState.settlement.settlers)
	if perks.is_empty():
		return
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	list.add_child(spacer)
	list.add_child(UiStyle.strong("Townsfolk", 16, UiStyle.LAMP))
	for perk: String in perks:
		var line := UiStyle.label("- " + perk, 14, UiStyle.INK)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.custom_minimum_size = Vector2(540, 0)
		list.add_child(line)


func _chosen_project() -> Dictionary:
	if rows.is_empty() or selected >= rows.size():
		return {}
	return Town.project(rows[selected].get("project", ""))


func _rows() -> Array[Dictionary]:
	var building := Town.current_age(GameState.settlement)
	if building == 0:
		return [{
			"label": "Pixelheim stands at its full height.", "note": "", "enabled": false,
			"why": "There is nothing left to build.", "action": func() -> String: return "",
		}]
	var done := Town.done_projects(GameState.settlement)
	var out: Array[Dictionary] = []
	for entry: Dictionary in Town.age(building)["projects"]:
		var project_id: String = entry["id"]
		var built: bool = project_id in done
		var blocker := Town.project_blocker(
			project_id, GameState.progression, GameState.settlement, GameState.pack.gold, GameState.pack.items
		)
		out.append({
			"project": project_id,
			"label": entry["name"],
			"note": "BUILT" if built else Town.cost_line(project_id),
			"enabled": blocker == "",
			"why": blocker,
			"action": func() -> String:
				var line := GameState.fund_project(project_id)
				if line != "":
					Sound.play("coin")
				return line,
		})
	return out

