class_name Household
extends RefCounted
## The hero's house (PIX-261, out of game_state.gd): the deed and its
## upgrades, the storage barrel, the trophy shelf, the furniture and what it
## adds, the manor's nook, and what E does to each fixture. It holds nothing
## of its own: the house lives in GameState's settlement, reached through
## `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript


func _init(state: GameStateScript) -> void:
	owner = state


func owns_house() -> bool:
	return owner.settlement.house.get("owned", false)


## The shut door in town: E buys the deed, or names the price (BUY_HOUSE).
func buy_house() -> String:
	if owns_house():
		return ""
	var cost := int(Town._data()["houseDeedCost"])
	if owner.pack.gold < cost:
		return Text.t("For sale: this house. The deed costs %d gold.") % cost
	owner.pack.gold -= cost
	owner.settlement.house["owned"] = true
	owner.pack_changed()
	owner.save_now()
	return Text.t("The deed is yours. Welcome home.")


## BUY_HOUSE_UPGRADE at Odo's counter: Cottage, then Manor. The new interior
## is served the next time the hero walks in.
func buy_house_upgrade() -> String:
	var next := Town.next_house_tier(owns_house(), int(owner.settlement.house.get("tier", 1)))
	if next.is_empty() or owner.trade.active_shop() != "odo" or owner.pack.gold < int(next["cost"]):
		return ""
	owner.pack.gold -= int(next["cost"])
	owner.settlement.house["tier"] = next["tier"]
	# What stood where the new house puts a fixture (or the doorway) comes
	# back to the pack (PIX-179), and so does what stood where a fixture
	# reaches beyond its own tile: the hearth's top, a bed's foot (PIX-237).
	var rooms := MapData.load_by_id("town_house" if int(next["tier"]) <= 1 else "town_house@%d" % int(next["tier"]))
	var reach: Dictionary = PunyInterior.plan(rooms.id, rooms.grid)["over"]
	var stays := func(piece: Dictionary) -> bool:
		var cell := Vector2i(int(piece["x"]), int(piece["y"]))
		return rooms.tile_at(cell) == "floor" and not reach.has(cell) and cell != Vector2i(8, 8)
	var moved := 0
	for piece: Dictionary in furniture():
		if not stays.call(piece):
			owner.pack.add_item(piece["itemId"])
			moved += 1
	owner.settlement.house["furniture"] = furniture().filter(stays)
	owner.pack_changed()
	var line := Text.t("The %s deed is signed. Your house grew while you were out.") % String(next["name"])
	if moved > 0:
		line += Text.t(" %d piece%s of furniture had to move: it's back in your pack.") % [moved, "" if moved == 1 else "s"]
	return line


## The storage barrel (STORE_ITEM / TAKE_ITEM): stacks move between pack and home.
func store_item(item_id: String, count := 1) -> bool:
	var moved := mini(count, owner.pack.items.get(item_id, 0))
	if not owns_house() or moved <= 0:
		return false
	owner.pack.remove_item(item_id, moved)
	var storage: Dictionary = owner.settlement.house["storage"]
	storage[item_id] = storage.get(item_id, 0) + moved
	owner.pack_changed()
	return true


func take_item(item_id: String, count := 1) -> bool:
	var storage: Dictionary = owner.settlement.house["storage"]
	var moved := mini(count, storage.get(item_id, 0))
	if not owns_house() or moved <= 0:
		return false
	if storage[item_id] - moved > 0:
		storage[item_id] -= moved
	else:
		storage.erase(item_id)
	owner.pack.add_item(item_id, moved)
	owner.pack_changed()
	return true


func trophies() -> Array:
	return owner.settlement.house.get("trophies", [])


## DISPLAY_TROPHY: on the shelf for power; its stats join the hero's at once.
func display_trophy(item_id: String) -> bool:
	if not Town.trophy_buffs().has(item_id) or item_id in trophies() or owner.pack.items.get(item_id, 0) <= 0:
		return false
	owner.pack.remove_item(item_id)
	owner.settlement.house["trophies"] = trophies() + [item_id]
	_shift_stats(Town.trophy_stat_delta(item_id), 1)
	owner.pack_changed()
	return true


## TAKE_TROPHY: back in the pack, and its stats leave with it.
func take_trophy(item_id: String) -> bool:
	if item_id not in trophies():
		return false
	owner.settlement.house["trophies"] = trophies().filter(func(id: String) -> bool: return id != item_id)
	owner.pack.add_item(item_id)
	_shift_stats(Town.trophy_stat_delta(item_id), -1)
	owner.pack_changed()
	return true


func _shift_stats(delta: Dictionary, direction: int) -> void:
	for stat: String in delta:
		owner.hero.stats[stat] = int(owner.hero.stats.get(stat, 0)) + direction * int(delta[stat])


## COMBINE_POTIONS at the manor's nook: two of a brew become one better.
func combine_potions(item_id: String) -> String:
	for combine: Dictionary in Town.nook_combines():
		if combine["from"] == item_id and owner.pack.items.get(item_id, 0) >= 2:
			owner.pack.remove_item(item_id, 2)
			owner.pack.add_item(combine["to"])
			owner.pack_changed()
			return Text.t("The nook bubbles: 2x %s became %s.") % [Catalog.item_name(item_id), Catalog.item_name(combine["to"])]
	return ""


func furniture() -> Array:
	return owner.settlement.house.get("furniture", [])


## What the furniture placed at home adds to `kind` (PIX-179): each kind of
## piece counts once, wherever it stands.
func home_buff(kind: String) -> float:
	if not owns_house():
		return 0.0
	var seen := {}
	var total := 0.0
	for piece: Dictionary in furniture():
		if seen.has(piece["itemId"]):
			continue
		seen[piece["itemId"]] = true
		total += float(Catalog.item(piece["itemId"]).get("homeBuff", {}).get(kind, 0.0))
	return total


func furniture_at(cell: Vector2i) -> Dictionary:
	for piece: Dictionary in furniture():
		if piece["x"] == cell.x and piece["y"] == cell.y:
			return piece
	return {}


## PLACE_FURNITURE on open floor in the house, one piece per tile.
func place_furniture(item_id: String, cell: Vector2i, tile: String) -> String:
	if owner.world.map_id != "town_house" or owner.pack.items.get(item_id, 0) <= 0:
		return ""
	if Catalog.item(item_id).get("category", "") != "furniture":
		return ""
	if tile != "floor":
		return Text.t("It needs open floor. Face a free tile and try again.")
	if not furniture_at(cell).is_empty():
		return Text.t("Something already stands there.")
	if cell == Vector2i(8, 8):
		return Text.t("Not in the doorway: you'd trip over it coming home.")
	owner.pack.remove_item(item_id)
	owner.settlement.house["furniture"] = furniture() + [{"itemId": item_id, "x": cell.x, "y": cell.y}]
	owner.pack_changed()
	return Controls.say(Text.t("%s placed. {key:interact} takes it back.") % Catalog.item_name(item_id))


## What E does to a home tile (handleHouseInteract): returns {text, panel}.
## Placed furniture comes back with a touch; every fixture answers.
func house_interact(cell: Vector2i, tile: String) -> Dictionary:
	if owner.world.map_id != "town_house":
		return {}
	var placed := furniture_at(cell)
	if not placed.is_empty():
		owner.settlement.house["furniture"] = furniture().filter(func(piece: Dictionary) -> bool: return piece != placed)
		owner.pack.add_item(placed["itemId"])
		owner.pack_changed()
		return {"text": Text.t("%s back in the pack.") % Catalog.item_name(placed["itemId"])}
	match tile:
		"bed":
			owner.make_whole()
			# Well rested (PIX-179): more XP for the next fights, longer with the bench.
			var fights := int(Town._data()["rested"]["fights"]) + roundi(home_buff("rested"))
			owner.settlement.house["rested"] = fights
			owner.pack_changed()
			# A night in your own bed, till morning (PIX-246).
			owner.upkeep.sleep_till_morning()
			return {"text": Text.t("You sleep in your own bed till dawn. Fully restored, and well rested: +%d%% XP for your next %d fights.") % [
				roundi(float(Town._data()["rested"]["xp"]) * 100), fights], "slept": true}
		"barrel":
			return {"panel": "storage"}
		"shelf":
			var cost := int(Town._data()["workbenchCost"])
			if owner.settlement.house.get("workbench", false):
				return {"panel": "workbench"}
			if owner.pack.gold >= cost:
				owner.pack.gold -= cost
				owner.settlement.house["workbench"] = true
				owner.pack_changed()
				return {"text": Text.t("A workbench and a small cauldron, fitted to the shelf. Craft at home, forever.")}
			return {"text": Text.t("A proper workbench would fit this shelf. Tools and parts cost %d gold.") % cost}
		"hearth":
			return {"text": (
				Text.t("The hearth roars beside your workbench. Home industry.") if owner.settlement.house.get("workbench", false)
				else Text.t("The hearth crackles, warm and idle. A workbench would fit by the shelf...")
			)}
		"counter":
			return {"text": Text.t("Your kitchen counter. Clean, empty, hopeful.")}
		"trophy_shelf":
			return {"panel": "trophies"}
		"garden":
			return {"text": Text.t("The garden drinks your victories: %d/%d until the next harvest.") % [
				owner.settlement.house.get("gardenWins", 0), Town._data()["gardenWinsPerYield"],
			]}
		"cauldron":
			return {"panel": "nook"}
		"floor":
			for item_id: String in owner.pack.items:
				if Catalog.item(item_id).get("category", "") == "furniture":
					return {"panel": "furniture"}
	return {}
