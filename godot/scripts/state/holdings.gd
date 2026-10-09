class_name Holdings
extends RefCounted
## The hero's stake in Pixelheim (PIX-261, out of game_state.gd): village
## projects and commissions, the businesses they own and their tills, the
## bank's savings and the caravan venture, the settlers and the perks their
## arcs grow, and the festival an age brings. It holds nothing of its own:
## it all lives in GameState's settlement and purse, reached through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript


func _init(state: GameStateScript) -> void:
	owner = state


## A commission (PIX-180): once every age is built, a costly work for a
## lasting edge. "" when it can't be funded.
func fund_commission(commission_id: String) -> String:
	var entry := Town.commission(commission_id)
	if entry.is_empty() or Town.current_age(owner.settlement) != 0 or commission_id in owner.settlement.projects or owner.pack.gold < int(entry["cost"]):
		return ""
	owner.pack.gold -= int(entry["cost"])
	owner.settlement.projects.append(commission_id)
	owner.pack_changed()
	owner.save_now()
	return Text.t("%s: commissioned. %s") % [entry["name"], entry["blurb"]]


## What the funded commissions add to `kind` ("xp", "gold", "potion").
func commission_buff(kind: String) -> float:
	var total := 0.0
	for entry: Dictionary in Town.commissions():
		if entry["id"] in owner.settlement.projects:
			total += float(entry["buff"].get(kind, 0.0))
	return total


## Funds a village project (PIX-145): gold and materials paid, the project
## built (the town redraws as the hero next sees it), and the last of an age
## raises the town to that age. Returns the ledger's line, "" if it can't.
func fund_project(project_id: String) -> String:
	if Town.project_blocker(project_id, owner.progression, owner.settlement, owner.pack.gold, owner.pack.items) != "":
		return ""
	var entry := Town.project(project_id)
	owner.pack.gold -= int(entry["cost"]["gold"])
	for item_id: String in entry["cost"]["items"]:
		owner.pack.remove_item(item_id, int(entry["cost"]["items"][item_id]))
	var tier_number := Town.age_of(project_id)
	owner.settlement.projects.assign(Town.done_projects(owner.settlement) + [project_id])
	var line := Text.t("%s: built. Walk outside and see.") % entry["name"]
	owner.reveals.append("project:%s" % project_id)
	owner.last_deed = {"kind": "project", "project": String(entry["name"]).to_lower().trim_prefix("the ").trim_prefix("a ")}
	if Town.age(tier_number)["projects"].all(func(candidate: Dictionary) -> bool: return candidate["id"] in owner.settlement.projects):
		owner.settlement.town_tier = tier_number
		owner.reveals.append("age:%d" % tier_number)
		line = Text.t("%s: built - and Pixelheim is a %s now.") % [entry["name"], String(Town.tier(tier_number)["name"]).to_lower()]
		start_festival(tier_number)
	owner.pack_changed()
	owner.settlers_changed.emit()
	owner.save_now()
	return line


## Whether a village project stands (PIX-206: the Hamlet's each bring a perk).
func project_built(project_id: String) -> bool:
	return project_id in Town.done_projects(owner.settlement)


## BUY_PROPERTY: the business you stand in, from its keeper.
func buy_property(map_id: String) -> bool:
	var deed: Dictionary = Town.deeds().get(map_id, {})
	if deed.is_empty() or map_id in owner.settlement.properties or owner.world.map_id != map_id:
		return false
	if owner.pack.gold < int(deed["cost"]):
		return false
	owner.pack.gold -= int(deed["cost"])
	owner.settlement.properties.append(map_id)
	investments()["tills"] = investments().get("tills", {})
	investments()["tills"][map_id] = {"gold": 0, "earned": 0, "at": steps_now()}
	owner.pack_changed()
	return true


## A property's till brought up to now (PIX-178): a day's rent for each
## whole day since it was last counted, up to what it holds. {gold, earned, at}.
func till(map_id: String) -> Dictionary:
	var tills: Dictionary = investments().get("tills", {})
	if not tills.has(map_id):
		# A deed bought before tills: its rent starts counting now.
		tills[map_id] = {"gold": 0, "earned": 0, "at": steps_now()}
		investments()["tills"] = tills
	var entry: Dictionary = tills[map_id]
	var day_steps := int(Town.bank("daySteps"))
	var days := maxi(0, floori((steps_now() - int(entry["at"])) / float(day_steps)))
	if days > 0:
		var expanded: bool = map_id in investments()["expansions"]
		var before := int(entry["gold"])
		entry["gold"] = mini(Town.till_cap(map_id, expanded, owner.town_tier()), before + days * Town.daily_rent(map_id, expanded, owner.town_tier()))
		entry["earned"] = int(entry["earned"]) + int(entry["gold"]) - before
		entry["at"] = int(entry["at"]) + days * day_steps
	return entry


## Empties a property's till into the purse; what it held.
func collect_till(map_id: String) -> int:
	if map_id not in owner.settlement.properties:
		return 0
	var entry := till(map_id)
	var gold := int(entry["gold"])
	if gold > 0:
		owner.pack.gold += gold
		entry["gold"] = 0
		owner.pack_changed()
	return gold


## EXPAND_PROPERTY: an owned business, once, for richer rent.
func expand_property(map_id: String) -> bool:
	var inv := investments()
	var cost := int(Town.bank("expansionCost"))
	if map_id not in owner.settlement.properties or map_id in inv["expansions"] or owner.pack.gold < cost:
		return false
	owner.pack.gold -= cost
	inv["expansions"].append(map_id)
	owner.pack_changed()
	return true


func steps_now() -> int:
	return int(owner.world.steps)


func investments() -> Dictionary:
	if owner.settlement.investments == null:
		owner.settlement.investments = {"expansions": []}
	return owner.settlement.investments


## BANK_DEPOSIT (PIX-177): the interest so far is counted and kept apart,
## the new gold joins what was put in, and the day's clock runs on.
func bank_deposit(amount: int) -> bool:
	if amount <= 0 or owner.pack.gold < amount:
		return false
	var inv := investments()
	var savings: Dictionary = inv.get("savings", {})
	var now := {"principal": 0, "earned": 0, "at": steps_now()} if savings.is_empty() else Town.savings_accrued(savings, steps_now(), perk_grown("settler_mirelle"))
	owner.pack.gold -= amount
	inv["savings"] = {"principal": int(now["principal"]) + amount, "earned": int(now["earned"]), "at": int(now["at"])}
	owner.pack_changed()
	return true


## BANK_WITHDRAW: the whole pot, interest included. Returns the gold paid out.
func bank_withdraw() -> int:
	var inv := investments()
	var savings: Dictionary = inv.get("savings", {})
	if savings.is_empty():
		return 0
	var value := _savings_now(savings)
	owner.pack.gold += value
	inv.erase("savings")
	owner.pack_changed()
	return value


## FUND_VENTURE: one caravan on the road at a time.
func fund_venture() -> bool:
	var inv := investments()
	var cost := int(Town.bank("ventureCost"))
	if inv.has("venture") or owner.pack.gold < cost:
		return false
	owner.pack.gold -= cost
	inv["venture"] = {"stake": cost, "at": steps_now()}
	owner.pack_changed()
	return true


## COLLECT_VENTURE once it's back: {won, payout} or {} if not ready.
func collect_venture() -> Dictionary:
	var inv := investments()
	var venture: Dictionary = inv.get("venture", {})
	if venture.is_empty() or not Town.venture_ready(venture["at"], steps_now()):
		return {}
	var outcome := Town.venture_outcome(venture["stake"], venture["at"])
	owner.pack.gold += outcome["payout"]
	inv.erase("venture")
	owner.pack_changed()
	return outcome


func _savings_now(savings: Dictionary) -> int:
	return Town.savings_value(savings, steps_now(), perk_grown("settler_mirelle"))


## A settler living here whose arc is done (PIX-157): their perk has grown.
func perk_grown(id: String) -> bool:
	return is_settled(id) and Town.perk_upgraded(id, owner.progression.quests)


## What Loras's song adds to the crit chance: more once he has his horn.
func song_crit() -> float:
	return float(Town.arc("lorasCrit")) if perk_grown("settler_loras") else 0.12


## How much faster the hero walks above ground: Wren's riders taught them.
func walk_bonus() -> float:
	return float(Town.arc("wrenWalk")) if perk_grown("settler_wren") else 0.0


func is_settled(id: String) -> bool:
	return id in owner.settlement.settlers


## Recruiting where they wait; services once they live in town.
func resolve_settler(npc_id: String) -> String:
	var recruit := Town.recruit(npc_id)
	if recruit.is_empty():
		return ""
	if not is_settled(npc_id):
		# A recruit's help is their quest (PIX-148, resolve_quests), once the
		# town is grown enough for them.
		if Town.recruit_blocker(recruit, owner.town_tier()) == "tier":
			return Text.t("%s: %s") % [recruit["name"], recruit.get("tierLine", Text.t("The town is not ready for me yet."))]
		return ""
	if owner.world.map_id == "town":
		if npc_id == "settler_iva":
			owner.make_whole()
			var line := Text.t("Iva's hands glow warm. Fully healed, free of charge.")
			var topped := _top_up_potions()
			if topped > 0:
				line += Text.t(" She tucks %d healing potion%s in your pack.") % [topped, "s" if topped > 1 else ""]
			return line
		if npc_id == "settler_loras":
			owner.settlement.bard_song = true
			owner.mark_dirty()
			return Text.t("Loras plays you a marching song%s. Your next hunt strikes truer. (+%d%% crit)") % [
				Text.t(" on his war-horn") if perk_grown("settler_loras") else "", roundi(song_crit() * 100),
			]
	return ""


## Iva's grown perk: healing potions up to three. Returns how many she gave.
func _top_up_potions() -> int:
	if not perk_grown("settler_iva"):
		return 0
	var short := int(Town.arc("ivaPotions")) - int(owner.pack.items.get("potion_hp", 0))
	if short <= 0:
		return 0
	owner.pack.add_item("potion_hp", short)
	owner.pack_changed()
	return short


## The festival day (PIX-159): an age complete, the town celebrates for a
## day - stalls and confetti on the square, everyone out, and a ring toss
## with a prize for the best throw (once per festival).
func start_festival(age: int) -> void:
	owner.settlement.festival = {
		"until": int(owner.world.steps) + int(Town.festival("days")) * DayNight.DAY_CYCLE_STEPS,
		"age": age,
		"won": false,
	}


func festival_on() -> bool:
	return not owner.settlement.festival.is_empty() and owner.world.steps < float(owner.settlement.festival["until"])


## The ring toss's prize, the first win of a festival: gold by the age and
## festival pies. Returns the line, or "" when this festival's is already won.
func win_ring_toss() -> String:
	if not festival_on() or owner.settlement.festival.get("won", false):
		return ""
	owner.settlement.festival["won"] = true
	var gold := int(Town.festival("prizeGold")) * int(owner.settlement.festival["age"])
	var pies := int(Town.festival("prizeCount"))
	owner.pack.gold += gold
	owner.pack.add_item(Town.festival("prizeItem"), pies)
	owner.pack_changed()
	owner.save_now()
	return Text.t("The prize is yours: +%d gold and %d %ss!") % [gold, pies, Catalog.item_name(Town.festival("prizeItem"))]
