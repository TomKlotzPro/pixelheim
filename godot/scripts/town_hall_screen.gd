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
		Text.t("Pixelheim today: %s (age %d of %d)") % [now["name"], now["tier"], Town.MAX_TIER],
		String(now["blurb"]),
	]
	var building := Town.current_age(GameState.settlement)
	if building == 0:
		lines.append_array(["", Text.t("Every project is built. Pixelheim stands at its full height."), "",
			Text.t("Commissions: costly works the town would build in your honour, each a lasting edge.")])
		for entry: Dictionary in Town.commissions():
			lines.append(Text.t("- %s: %s") % [entry["name"], entry["blurb"]])
		return "\n".join(lines)
	lines.append_array(["", Text.t("Building the %s") % Town.tier(building)["name"]])
	var blockers := Town.age_blockers(building, GameState.progression, GameState.settlement)
	for need: Dictionary in Town.age(building)["requires"]:
		lines.append("%s %s" % [Text.t("Needed:") if need["line"] in blockers else Text.t("Done:"), need["line"]])
	lines.append(Text.t("When it's done: %s.") % "; ".join(Town.tier(building)["perks"]).to_lower())
	var chosen := _chosen_project()
	if not chosen.is_empty():
		lines.append_array(["", Text.t("%s: %s") % [chosen["name"], chosen["blurb"]]])
	return "\n".join(lines)


## Who has come to live here, and what each brings (PIX-148), and what
## the hero owns (PIX-178): on the page, under the projects.
func _refresh() -> void:
	super._refresh()
	_holdings()
	var perks := Town.settler_perks(GameState.settlement.settlers, GameState.progression.quests)
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


## Holdings (PIX-178): each property, what it has earned, what waits in
## its till and what a day brings.
func _holdings() -> void:
	if GameState.settlement.properties.is_empty():
		return
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	list.add_child(spacer)
	list.add_child(UiStyle.strong("Holdings", 16, UiStyle.LAMP))
	for map_id: String in GameState.settlement.properties:
		var entry := GameState.till(map_id)
		var expanded: bool = map_id in GameState.investments()["expansions"]
		var line := UiStyle.label(Text.t("- %s: %dg earned, %dg in the till (%dg a day)") % [
			Town.deeds()[map_id]["name"], entry["earned"], entry["gold"], Town.daily_rent(map_id, expanded, GameState.town_tier()),
		], 14, UiStyle.INK)
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
		# Every age built: the commissions, for a lasting edge (PIX-180).
		var works: Array[Dictionary] = []
		for entry: Dictionary in Town.commissions():
			var commission_id: String = entry["id"]
			var funded: bool = commission_id in GameState.settlement.projects
			works.append({
				"label": entry["name"], "note": Text.t("COMMISSIONED") if funded else Text.coins(int(entry["cost"])),
				"enabled": not funded and GameState.pack.gold >= int(entry["cost"]),
				"why": "Already commissioned." if funded else "Not enough gold.",
				"action": func() -> String:
					var line := GameState.fund_commission(commission_id)
					if line != "":
						Sound.play("coin")
					return line,
			})
		return works
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
			"note": Text.t("BUILT") if built else Town.cost_line(project_id),
			"enabled": blocker == "",
			"why": blocker,
			"action": func() -> String:
				var line := GameState.fund_project(project_id)
				if line != "":
					Sound.play("coin")
				return line,
		})
	return out

