extends "res://scripts/ledger_screen.gd"
## The house's fixtures, one screen per `mode` (HouseStorage, Trophies, Nook
## and the pack's Craft/Place in the web game): the storage barrel, the
## fitted workbench (both trades), the trophy shelf, the manor's alchemy
## nook, and placing furniture on the faced floor tile (`cell`).

## "storage" | "workbench" | "trophies" | "nook" | "furniture"
var mode := "storage"
## The faced floor tile furniture goes on.
var cell := Vector2i.ZERO
## Called after a placement so the world can draw the new piece.
var on_placed: Callable


func _title() -> String:
	return {
		"storage": "Storage barrel", "workbench": "Workbench", "trophies": "Trophy shelf",
		"nook": "Alchemy nook", "furniture": "Furnish",
	}[mode]


func _intro() -> String:
	return {
		"storage": "What the house keeps, safe and weightless.",
		"workbench": "Both trades, at home: forge and brew without walking to town.",
		"trophies": "Shelve a trophy for power; take it back down any time.",
		"nook": "Two of a brew distill into one better one.",
		"furniture": "Pick a piece for this spot. E on it later takes it back.",
	}[mode]


func _info() -> String:
	var house := GameState.settlement.house
	match mode:
		"storage":
			var stored: Dictionary = house["storage"]
			return Text.t("Stored:\n") + ("\n".join(stored.keys().map(func(id: String) -> String: return "%s x%d" % [Catalog.item_name(id), stored[id]])) if not stored.is_empty() else Text.t("Nothing yet."))
		"trophies":
			var lines: Array[String] = [Text.t("On the shelf:")]
			for id: String in GameState.trophies():
				lines.append(Text.t("%s: %s") % [Catalog.item_name(id), Town.trophy_buffs()[id]["label"]])
			if GameState.trophies().is_empty():
				lines.append(Text.t("Nothing yet. Trophies come from the toughest foes."))
			return "\n".join(lines)
		"workbench":
			return Text.t("Smithing %d, Alchemy %d") % [GameState.hero.jobs["smithing"]["level"], GameState.hero.jobs["alchemy"]["level"]]
	return ""


func _rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pack := GameState.pack
	match mode:
		"storage":
			for id: String in pack.items.keys():
				out.append(_row_for(Text.t("Store %s") % Catalog.item_name(id), "x%d" % pack.items[id], true,
					func() -> String: return "Stored." if GameState.store_item(id) else ""))
			for id: String in GameState.settlement.house["storage"].keys():
				out.append(_row_for(Text.t("Take %s") % Catalog.item_name(id), "x%d" % GameState.settlement.house["storage"][id], true,
					func() -> String: return "Taken." if GameState.take_item(id) else ""))
		"workbench":
			for entry: Dictionary in Economy.recipes():
				var recipe_id: String = entry["id"]
				out.append(_row_for(
					Text.t("Craft %s") % Catalog.item_name(entry["itemId"]),
					"%s %d" % [Economy.job_name(entry["job"]["id"]), entry["job"]["level"]],
					Economy.can_craft(entry, pack.items, GameState.hero.jobs),
					func() -> String:
						# Not with what a taken delivery needs, unless asked twice (PIX-206).
						var ask := GameState.ask_before_dip("craft:" + recipe_id, entry["needs"])
						if ask != "":
							return ask
						var result := GameState.craft(recipe_id)
						return "" if not result["made"] else Text.t("Made %dx %s.") % [result["count"], Catalog.item_name(entry["itemId"])],
					"Missing materials or skill.",
				))
		"trophies":
			for id: String in Town.trophy_buffs():
				if id in GameState.trophies():
					out.append(_row_for(Text.t("Take down %s") % Catalog.item_name(id), "", true,
						func() -> String: return "Back in the pack." if GameState.take_trophy(id) else ""))
				elif pack.items.get(id, 0) > 0:
					out.append(_row_for(Text.t("Display %s") % Catalog.item_name(id), Town.trophy_buffs()[id]["label"], true,
						func() -> String: return "On the shelf." if GameState.display_trophy(id) else ""))
		"nook":
			for combine: Dictionary in Town.nook_combines():
				var from: String = combine["from"]
				out.append(_row_for(
					Text.t("2x %s into %s") % [Catalog.item_name(from), Catalog.item_name(combine["to"])],
					Text.t("have %d") % pack.items.get(from, 0), pack.items.get(from, 0) >= 2,
					func() -> String: return GameState.combine_potions(from), "It takes two.",
				))
		"furniture":
			for id: String in pack.items.keys():
				if Catalog.item(id).get("category", "") != "furniture":
					continue
				out.append(_row_for(Text.t("Place %s here") % Catalog.item_name(id), "x%d" % pack.items[id], true,
					func() -> String:
						var text := GameState.place_furniture(id, cell, "floor")
						if on_placed.is_valid():
							on_placed.call()
						close.call_deferred()
						return text))
	if out.is_empty():
		out.append(_row_for("Nothing to do here yet.", "", false, func() -> String: return "", "Nothing to do here yet."))
	return out


func _row_for(label: String, note: String, enabled: bool, action: Callable, why := "Not possible right now.") -> Dictionary:
	return {"label": label, "note": note, "enabled": enabled, "action": action, "why": why}
