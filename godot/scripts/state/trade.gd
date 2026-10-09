class_name Trade
extends RefCounted
## The hero at the counter (PIX-261, out of game_state.gd): which shop they
## stand in and what it sells at what price, buying and selling there,
## Hilda's forge (salvage, reforge, quench, a +1) and crafting at a trade's
## station. It holds only the stall the hero trades at on the burnt square,
## never saved; the rest is GameState's sections, reached through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript


## The shop of the stall the hero is trading at on the burnt square (PIX-146),
## while its keeper's building is rubble; "" anywhere else. Not saved.
var stall_shop := ""


func _init(state: GameStateScript) -> void:
	owner = state


## The shop the hero stands in (activeShopId); "" outside shops.
func active_shop() -> String:
	return stall_shop if stall_shop != "" else Economy.shop_at(owner.world.map_id)


## Whether the hero can craft a trade here: at its station, at the house's
## workbench, or at its keeper's stall while the station is rubble.
func at_station(job: String) -> bool:
	if Economy.at_job_station(job, owner.world.map_id, owner.settlement.house.get("workbench", false)):
		return true
	return stall_shop != "" and stall_shop == Economy.station_shop(job)


## The shops' stage (PIX-176): floors climbed or relics won.
func stock_stage() -> int:
	return Economy.stock_stage(owner.progression.unlocked_level, Relics.found(owner.progression))


## What an item costs here: an owner pays a tenth less in their own shop.
func price_of(item_id: String) -> int:
	var price := Economy.buy_price(item_id)
	if owned_shop_map(active_shop()) != "":
		price = roundi(price * (1.0 - float(Town._data()["rent"]["ownerDiscount"])))
	# Vex brews cheaper in a brewery of her own (PIX-206).
	if active_shop() == "alchemist" and owner.holdings.project_built("vexs_brewery"):
		price = roundi(price * (1.0 - Town.project_perk("vexs_brewery", "buy")))
	return price


## What a shop sells now, with the owner's pick of the day in a shop you own.
func shop_wares(shop_id: String) -> Array:
	var wares: Array = Economy.shop_stock(shop_id, stock_stage(), owner.town_tier()).duplicate()
	if owned_shop_map(shop_id) != "":
		var pick := Town.owner_pick(shop_id, owner.holdings.steps_now() / int(Town.bank("daySteps")))
		if pick != "" and pick not in wares:
			wares.append(pick)
	return wares


## The property a shop is, if the hero owns it ("" otherwise).
func owned_shop_map(shop_id: String) -> String:
	for map_id: String in owner.settlement.properties:
		if Town.shop_of(map_id) == shop_id:
			return map_id
	return ""


## What a shop pays for what the hero sells, over its listed rate: a gem on
## the trophy shelf, and Odo's rebuilt store (PIX-206).
func sale_multiplier(shop_id: String) -> float:
	return trophy_sell_multiplier() * (1.0 + Town.project_perk("odos_store", "sell") if shop_id == "odo" and owner.holdings.project_built("odos_store") else 1.0)


## A gem on the trophy shelf sweetens every sale by 10% (trophySellMultiplier).
func trophy_sell_multiplier() -> float:
	return 1.1 if "gem" in owner.settlement.house.get("trophies", []) else 1.0


## Hilda's price for a +1 (PIX-206): a tenth less once her forge stands.
func forge_price(instance: Dictionary, smithing: int, masterwork: bool) -> int:
	var cost := Economy.masterwork_cost(instance["itemId"], instance["bonus"], smithing) if masterwork else Economy.forge_cost_for(instance["itemId"], instance["bonus"], smithing)
	if owner.holdings.project_built("hildas_forge"):
		cost = roundi(cost * (1.0 - Town.project_perk("hildas_forge", "forge")))
	return cost


## BUY_ITEM: in stock here at this progress, and affordable. Shops sell honest
## common gear; the exciting rolls come from monsters.
func buy_item(item_id: String) -> bool:
	var shop_id := active_shop()
	if shop_id == "" or item_id not in shop_wares(shop_id):
		return false
	var price := price_of(item_id)
	if owner.pack.gold < price:
		return false
	owner.pack.gold -= price
	if Catalog.item(item_id).has("slot"):
		owner.pack.gear.append(InventoryState.create_gear(item_id))
	else:
		owner.pack.add_item(item_id)
	owner.pack_changed()
	return true


## SELL_ITEM: `count` of a stack (one by default; the web sold one at a time),
## at this shop's rate. Returns the gold earned (0 = refused).
func sell_item(item_id: String, count := 1) -> int:
	var shop_id := active_shop()
	var have: int = owner.pack.items.get(item_id, 0)
	# A quest's goods aren't for sale (PIX-184), whatever screen asks.
	if shop_id == "" or have <= 0 or Catalog.item(item_id).get("quest", false):
		return 0
	var sold := mini(count, have)
	var price := floori(Economy.sell_price_at(shop_id, item_id, owner.town_tier()) * sale_multiplier(shop_id))
	owner.pack.gold += price * sold
	owner.pack.remove_item(item_id, sold)
	owner.pack_changed()
	return price * sold


## SELL_GEAR: never what the hero is wearing. Returns the gold earned (0 = refused).
func sell_gear(uid: String) -> int:
	var shop_id := active_shop()
	var instance := owner.pack.gear_by_uid(uid)
	if shop_id == "" or instance.is_empty() or owner.pack.is_equipped(uid):
		return 0
	var price := floori(
		Economy.gear_sell_price_at(shop_id, instance, owner.town_tier()) * sale_multiplier(shop_id)
	)
	owner.pack.gold += price
	owner.pack.gear.erase(instance)
	owner.pack_changed()
	return price


## Breaks a piece down at Hilda's (PIX-182): half of what it's made of back,
## a little forge practice. "" when it can't be done here.
func salvage_gear(uid: String) -> String:
	var instance := owner.pack.gear_by_uid(uid)
	var shop_id := active_shop()
	if instance.is_empty() or owner.pack.is_equipped(uid) or shop_id == "" or not Economy.shop(shop_id).get("forge", false):
		return ""
	var back := Economy.salvage_yield(instance)
	var parts: Array[String] = []
	for item_id: String in back:
		owner.pack.add_item(item_id, int(back[item_id]))
		parts.append("%d %s" % [int(back[item_id]), Catalog.item_name(item_id)])
	owner.pack.gear.erase(instance)
	Economy.grant_job_xp(owner.hero.jobs, "smithing", int(Economy._data()["salvage"]["xp"]))
	owner.pack_changed()
	return Text.t("Hilda breaks it down: %s.") % ", ".join(parts)


## Reforges a piece at Hilda's from Smithing 8 (PIX-182): its rarity rolled
## again, never down, and new affixes. "" when it can't be done.
func reforge_gear(uid: String) -> String:
	var instance := owner.pack.gear_by_uid(uid)
	var shop_id := active_shop()
	var rules: Dictionary = Economy._data()["reforge"]
	if instance.is_empty() or shop_id == "" or not Economy.shop(shop_id).get("forge", false):
		return ""
	if int(owner.hero.jobs["smithing"]["level"]) < int(rules["smithing"]):
		return ""
	var cost := Economy.reforge_cost(instance)
	if owner.pack.gold < cost:
		return ""
	owner.pack.gold -= cost
	var ranks := ["common", "fine", "epic"]
	var rolled := Bestiary._roll_rarity(rules["weights"], owner.roll)
	var rarity: String = rolled if ranks.find(rolled) > ranks.find(instance["rarity"]) else instance["rarity"]
	var fresh := InventoryState.create_gear(instance["itemId"], rarity, owner.roll)
	instance["rarity"] = rarity
	instance.erase("affixes")
	if fresh.has("affixes"):
		instance["affixes"] = fresh["affixes"]
	if int(instance.get("deep", 0)) > 0:
		InventoryState.deep_affixes(instance, int(instance["deep"]), owner.roll)
	Economy.grant_job_xp(owner.hero.jobs, "smithing", 10)
	owner.pack_changed()
	return Text.t("Hilda reforges it: %s.") % InventoryState.gear_name(instance)


## Hilda quenches a deep piece (PIX-218): gold and a gem for +1 to its
## strongest stat, kept apart from its affixes so a reforge keeps it.
## Returns the line, "" when it can't.
func quench_gear(uid: String) -> String:
	var instance := owner.pack.gear_by_uid(uid)
	var shop_id := active_shop()
	var rules: Dictionary = Economy._data()["quench"]
	if instance.is_empty() or int(instance.get("deep", 0)) <= 0 or shop_id == "" or not Economy.shop(shop_id).get("forge", false):
		return ""
	var cost := Economy.quench_cost(instance)
	var gem := String(rules["gem"])
	if owner.pack.gold < cost or int(owner.pack.items.get(gem, 0)) < 1:
		return ""
	owner.pack.gold -= cost
	owner.pack.remove_item(gem, 1)
	var stat := Economy.quench_stat(instance)
	var quenched: Dictionary = instance.get("quenched", {})
	quenched[stat] = int(quenched.get(stat, 0)) + 1
	instance["quenched"] = quenched
	Economy.grant_job_xp(owner.hero.jobs, "smithing", int(rules["smithingXp"]))
	owner.pack_changed()
	return Text.t("Hilda quenches it in the deep's black water: +1 %s.") % Text.t(Skills.ABBR[stat])


## UPGRADE_GEAR at the forge: +1 bonus for gold, up to the smithing cap; pays smithing xp.
func upgrade_gear(uid: String) -> bool:
	var shop_id := active_shop()
	var instance := owner.pack.gear_by_uid(uid)
	if shop_id == "" or not Economy.shop(shop_id).get("forge", false) or instance.is_empty():
		return false
	var smithing: int = owner.hero.jobs["smithing"]["level"]
	# Past the cap, masterwork (PIX-180): Smithing 8, a gem a step, a rising price.
	var masterwork: bool = instance["bonus"] >= Economy.forge_cap_for(smithing)
	if masterwork and not Economy.masterwork_open(smithing, instance["bonus"]):
		return false
	var cost := forge_price(instance, smithing, masterwork)
	var gem := String(Economy._data()["masterwork"]["gem"])
	if owner.pack.gold < cost or (masterwork and int(owner.pack.items.get(gem, 0)) < 1):
		return false
	owner.pack.gold -= cost
	if masterwork:
		owner.pack.remove_item(gem)
	instance["bonus"] += 1
	Economy.grant_job_xp(owner.hero.jobs, "smithing", 10)
	owner.pack_changed()
	return true


## CRAFT at the trade's station: materials in, the item out. Forged pieces are
## gear instances; skilled alchemists sometimes brew two. Returns {made, count}.
func craft(recipe_id: String) -> Dictionary:
	var entry := Economy.recipe(recipe_id)
	if entry.is_empty() or not Economy.can_craft(entry, owner.pack.items, owner.hero.jobs):
		return {"made": false, "count": 0}
	var job: String = entry["job"]["id"]
	if not at_station(job):
		return {"made": false, "count": 0}
	for item_id: String in entry["needs"]:
		owner.pack.remove_item(item_id, entry["needs"][item_id])
	var count := 1
	if Catalog.item(entry["itemId"]).has("slot"):
		# Mastery shows in the work (PIX-182): Fine or Epic the more levels
		# above the recipe, a level more at the home workbench.
		var bench := 1 if owner.world.map_id.begins_with("town_house") and owner.settlement.house.get("workbench", false) else 0
		var rarity := Economy.craft_rarity(int(owner.hero.jobs[job]["level"]), int(entry["job"]["level"]), owner.roll, bench)
		if rarity == "common" and job == "smithing" and Economy.forges_fine(owner.hero.jobs["smithing"]["level"]):
			rarity = "fine"
		owner.pack.gear.append(InventoryState.create_gear(entry["itemId"], rarity, owner.roll))
	else:
		# Steeping two potions into one better never doubles (PIX-181).
		if not entry.get("steep", false) and owner.roll.call() < Economy.double_brew_chance(owner.hero.jobs["alchemy"]["level"]):
			count = 2
		owner.pack.add_item(entry["itemId"], count)
	# The trade that made it learns from it (PIX-143: an amulet brewed at
	# the cauldron is alchemy, not smithing).
	var gained := Economy.grant_job_xp(owner.hero.jobs, job, Economy.craft_xp(entry))
	# Accepted crafting quests count what the hero makes (PIX-143).
	for quest: Dictionary in Quests.all():
		var taken: Dictionary = owner.progression.quests.get(quest["id"], {})
		var objective: Dictionary = quest["objective"]
		if not taken.is_empty() and not taken["done"] and objective["kind"] == "craft" and objective["itemId"] == entry["itemId"]:
			taken["progress"] = mini(int(objective["count"]), int(taken["progress"]) + count)
	owner.pack_changed()
	var level_line := Text.t("%s reached %d!") % [Economy.job_name(job), owner.hero.jobs[job]["level"]] if gained > 0 else ""
	return {"made": true, "count": count, "level_line": level_line}
