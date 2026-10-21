class_name Trade
extends RefCounted
## areas: trade
## The hero at the counter (PIX-261, out of game_state.gd): which shop they
## stand in and what it sells at what price, buying and selling there,
## Hilda's forge (salvage, reforge, quench, a +1) and crafting at a trade's
## station. It holds only the stall the hero trades at on the burnt square,
## never saved; the rest is GameState's sections, reached through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## The numbers the counter sets a piece against what's worn by (PIX-336),
## in the order its card lists them.
const COMPARED := ["damage", "armor", "strength", "intelligence", "dexterity", "defense", "endurance"]
## Junk is cheap (PIX-336): a material worth this much or less, never more.
const JUNK_VALUE := 25
## Junk is what's past this many crafts' worth of the most a recipe takes.
const JUNK_KEEP_CRAFTS := 3

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript


## The shop of the stall the hero is trading at on the burnt square (PIX-146),
## while its keeper's building is rubble; "" anywhere else. Not saved.
var stall_shop := ""

## This visit's sales at the counter (PIX-336), to buy back at what they
## fetched: {item_id, count, each}, and the piece itself for gear. Emptied
## as the counter closes; never saved.
var sold_here: Array[Dictionary] = []


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


## The shops' stage (PIX-176): the relics won.
func stock_stage() -> int:
	return Economy.stock_stage(Relics.found(owner.progression))


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


## Hilda's price for a +1 (PIX-206): a tenth less once her forge stands, a
## tenth less again with Old Pell at her bellows (PIX-255).
func forge_price(instance: Dictionary, smithing: int, masterwork: bool) -> int:
	var cost := Economy.masterwork_cost(instance["itemId"], instance["bonus"], smithing) if masterwork else Economy.forge_cost_for(instance["itemId"], instance["bonus"], smithing)
	if owner.holdings.project_built("hildas_forge"):
		cost = roundi(cost * (1.0 - Town.project_perk("hildas_forge", "forge") - owner.holdings.settler_share("forge")))
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
	# Gold spent is kept at once (PIX-302 step 4: buying is a moment).
	owner.save_now()
	return true


## What one of a stack fetches here: the shop's rate, the city's, the
## trophy's and Odo's store's (PIX-206).
func item_pays(item_id: String) -> int:
	var shop_id := active_shop()
	return floori(Economy.sell_price_at(shop_id, item_id, owner.town_tier()) * sale_multiplier(shop_id))


## What a gear piece fetches here, its rarity priced in.
func gear_pays(instance: Dictionary) -> int:
	var shop_id := active_shop()
	return floori(Economy.gear_sell_price_at(shop_id, instance, owner.town_tier()) * sale_multiplier(shop_id))


## SELL_ITEM: `count` of a stack (one by default; the web sold one at a time),
## at this shop's rate. Returns the gold earned (0 = refused).
func sell_item(item_id: String, count := 1) -> int:
	var shop_id := active_shop()
	var have: int = owner.pack.items.get(item_id, 0)
	# A quest's goods aren't for sale (PIX-184), whatever screen asks.
	if shop_id == "" or have <= 0 or Catalog.item(item_id).get("quest", false):
		return 0
	var sold := mini(count, have)
	var price := item_pays(item_id)
	owner.pack.gold += price * sold
	owner.pack.remove_item(item_id, sold)
	# On the buyback shelf, with what else of it went at that price.
	var shelved := sold_here.filter(func(entry: Dictionary) -> bool:
		return not entry.has("piece") and entry["item_id"] == item_id and entry["each"] == price)
	if shelved.is_empty():
		sold_here.append({"item_id": item_id, "count": sold, "each": price})
	else:
		shelved[0]["count"] += sold
	owner.pack_changed()
	return price * sold


## SELL_GEAR: never what the hero is wearing, nor Sela's cap on the Night
## of Ash (PIX-344). Returns the gold earned (0 = refused).
func sell_gear(uid: String) -> int:
	var shop_id := active_shop()
	var instance := owner.pack.gear_by_uid(uid)
	if shop_id == "" or instance.is_empty() or owner.pack.is_equipped(uid) or Prologue.keeps(owner.progression.prologue, instance["itemId"]):
		return 0
	var price := gear_pays(instance)
	owner.pack.gold += price
	owner.pack.gear.erase(instance)
	sold_here.append({"item_id": instance["itemId"], "count": 1, "each": price, "piece": instance})
	owner.pack_changed()
	return price


## Buys back one of this visit's sales (PIX-336), all of it at what it
## fetched, the very piece for gear. false when the gold falls short.
func buy_back(index: int) -> bool:
	if index < 0 or index >= sold_here.size():
		return false
	var entry := sold_here[index]
	var price := int(entry["each"]) * int(entry["count"])
	if owner.pack.gold < price:
		return false
	owner.pack.gold -= price
	if entry.has("piece"):
		owner.pack.gear.append(entry["piece"])
	else:
		owner.pack.add_item(entry["item_id"], int(entry["count"]))
	sold_here.remove_at(index)
	owner.pack_changed()
	owner.save_now()
	return true


## How many of a stack the counter asks to sell (PIX-336): one at least,
## never more than is carried.
static func stack_amount(asked: int, have: int) -> int:
	return clampi(asked, 1, maxi(1, have))


## How much of a stack is junk (PIX-336): only a cheap material (misc,
## worth JUNK_VALUE or less; never a quest's, never a trophy for the
## shelf), and of that what's past JUNK_KEEP_CRAFTS crafts' worth of the
## most one recipe takes; all of one no recipe takes (an old boot).
static func junk_count(item_id: String, have: int) -> int:
	var item := Catalog.item(item_id)
	if item.get("category", "") != "misc" or item.get("quest", false) or int(item.get("value", 0)) > JUNK_VALUE or Town.trophy_buffs().has(item_id):
		return 0
	var most := 0
	for entry: Dictionary in Economy.recipes():
		most = maxi(most, int(entry["needs"].get(item_id, 0)))
	return maxi(0, have - JUNK_KEEP_CRAFTS * most)


## A piece's numbers as the counter compares them (PIX-336): its damage
## and armour with the forge's and the deep's bonus, and what it adds to
## each stat. {} for nothing.
static func numbers(piece: Dictionary) -> Dictionary:
	if piece.is_empty():
		return {}
	var item := Catalog.item(piece["itemId"])
	var out := {}
	if item.has("damage"):
		out["damage"] = HeroRules.gear_damage(piece)
	if item.has("armor"):
		out["armor"] = HeroRules.gear_armor(piece)
	var adds: Dictionary = item.get("grants", {}).duplicate()
	var extra := InventoryState.shown_affixes(piece)
	for stat: String in extra:
		adds[stat] = int(adds.get(stat, 0)) + int(extra[stat])
	for stat: String in adds:
		out[stat] = int(adds[stat])
	return out


## Each of `piece`'s numbers against `worn`'s, in COMPARED's order: how far
## up (more than zero) or down. Nothing worn is all up.
static func compare(piece: Dictionary, worn: Dictionary) -> Dictionary:
	var mine := numbers(piece)
	var theirs := numbers(worn)
	var out := {}
	for key: String in COMPARED:
		if mine.has(key) or theirs.has(key):
			out[key] = int(mine.get(key, 0)) - int(theirs.get(key, 0))
	return out


## Worse than `worn`: nothing up and something down. Never worse than nothing.
static func worse(piece: Dictionary, worn: Dictionary) -> bool:
	if worn.is_empty():
		return false
	var steps := compare(piece, worn).values()
	return steps.all(func(step: int) -> bool: return step <= 0) and steps.any(func(step: int) -> bool: return step < 0)


## What wearing `item_id` would take off (PIX-336): what fills its slot,
## and for a ring the first ring once both fingers are full (as equip
## does), nothing while one is free. {} when nothing.
func worn_against(item_id: String) -> Dictionary:
	var slot: String = Catalog.item(item_id).get("slot", "")
	if slot == "ring":
		if not owner.pack.equipped.has("ring1") or not owner.pack.equipped.has("ring2"):
			return {}
		slot = "ring1"
	return owner.pack.gear_by_uid(owner.pack.equipped.get(slot, ""))


## A piece the counter calls junk (PIX-336): not worn, no set's, and worse
## than what's worn in its slot (than both rings, for a ring).
func junk_piece(instance: Dictionary) -> bool:
	var item := Catalog.item(instance["itemId"])
	if owner.pack.is_equipped(instance["uid"]) or item.has("set") or item.get("quest", false):
		return false
	var slots: Array = ["ring1", "ring2"] if item.get("slot", "") == "ring" else [item.get("slot", "")]
	return slots.all(func(slot: String) -> bool: return worse(instance, owner.pack.gear_by_uid(owner.pack.equipped.get(slot, ""))))


## Everything "Sell all junk" sells here (PIX-336): {items: {id: count},
## gear: [uid], gold}. Never what a taken delivery needs.
func junk() -> Dictionary:
	var out := {"items": {}, "gear": [], "gold": 0}
	for item_id: String in owner.pack.items:
		var count := junk_count(item_id, int(owner.pack.items[item_id]))
		if count > 0 and owner.questing.delivery_dip({item_id: count}).is_empty():
			out["items"][item_id] = count
			out["gold"] += count * item_pays(item_id)
	for instance in owner.pack.gear:
		if junk_piece(instance):
			out["gear"].append(instance["uid"])
			out["gold"] += gear_pays(instance)
	return out


## Sells all the junk (PIX-336), each onto the buyback shelf. The gold earned.
func sell_junk() -> int:
	var lot := junk()
	var gold := 0
	for item_id: String in lot["items"]:
		gold += sell_item(item_id, int(lot["items"][item_id]))
	for uid: String in lot["gear"]:
		gold += sell_gear(uid)
	return gold


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
		parts.append(Text.count(int(back[item_id]), Catalog.item_name(item_id)))
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
	# What the hero has made is remembered, so a crafting quest taken later
	# counts it (PIX-231).
	owner.progression.crafted[entry["itemId"]] = int(owner.progression.crafted.get(entry["itemId"], 0)) + count
	# Accepted crafting quests count what the hero makes (PIX-143), and say
	# so in the log as deliveries do (PIX-231): how far, or ready and to whom.
	var lines: Array[String] = []
	for quest: Dictionary in Quests.all():
		var taken: Dictionary = owner.progression.quests.get(quest["id"], {})
		var objective: Dictionary = quest["objective"]
		if not taken.is_empty() and not taken["done"] and objective["kind"] == "craft" and objective["itemId"] == entry["itemId"]:
			var before := int(taken["progress"])
			taken["progress"] = mini(int(objective["count"]), before + count)
			if int(taken["progress"]) > before:
				lines.append(owner.questing.progress_line(quest, int(taken["progress"])))
	owner.pack_changed()
	if not lines.is_empty():
		owner.noted.emit(lines)
	var level_line := Text.t("%s reached %d!") % [Economy.job_name(job), owner.hero.jobs[job]["level"]] if gained > 0 else ""
	return {"made": true, "count": count, "level_line": level_line}
