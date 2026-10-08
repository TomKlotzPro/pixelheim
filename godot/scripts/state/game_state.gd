extends Node
## The one game state (autoload `GameState`), replacing the web's Zustand
## store: typed sections for the hero, the pack, the settlement, progression
## and the explored world. Mutations go through methods that keep the web
## reducers' invariants; signals replace store subscriptions. Persistence is
## write-behind: changes mark the state dirty, the autosave flushes it within
## AUTOSAVE_SECONDS, and moments that matter (map change, loot) save at once.

signal loaded
signal gold_changed(gold: int)
signal inventory_changed
## A conversation ended: settlers (PIX-124) and quests (PIX-125) answer here,
## like the web game resolves them when its dialogue closes.
signal dialogue_closed(npc_id: String)
## One line of feedback for the world (the web's worldMessage).
signal message(text: String)
## Who lives where changed: a recruit left the wilds for town.
signal settlers_changed
## The hero was made whole (inn, healer): the live body refills too.
signal healed
## A monster fell (quest bounties hook here, PIX-125).
signal monster_slain(monster_id: String)
## The hero's HP changed (hits, rests, level-ups).
signal hp_changed(hp: int, max_hp: int)
## The hero crossed into a new rank (useRankUp): the ascension scene plays.
signal ranked_up(title: String)
## Levels were gained (the level-up fanfare).
signal leveled_up(level: int)

## Slot 0 never touches disk: harness runs and tests leave real saves alone.
const NO_SLOT := 0
const AUTOSAVE_SECONDS := 3.0
## Until character creation lands (PIX-127), new games start this hero.
const DEFAULT_HERO_NAME := "Wanderer"
const DEFAULT_ROLE := "warrior"
## Starting kits (CREATE_HERO in reducers/meta.ts): rangers string a bow,
## everyone else begins with the humble rusty sword.
const STARTER_WEAPONS := {"ranger": "hunting_bow"}
const STARTER_ITEMS := {"potion_hp": 2, "bread": 2, "cheese_wheel": 1}
const STARTER_GOLD := 30

var hero: HeroState
var pack: InventoryState
var settlement: SettlementState
var progression: ProgressionState
var world: WorldState
var slots := SaveSlots.new()
var settings := GameSettings.new()
var slot := NO_SLOT
var dirty := false
## Dice for chance rolls (double brews); tests swap in a loaded die.
var roll: Callable = func() -> float: return randf()
## True when boot found no save in any slot: a first visit (offer the web hero).
var first_run := false
## The title has been passed this session (it greets the first load only).
var title_seen := false
## A plain launch found no hero in its slot: a stand-in plays behind the title
## and is never written, until a hero is made or brought in.
var standing_in := false
var _booted := false
var _unsaved_seconds := 0.0


func _init() -> void:
	new_game()
	dirty = false


## Picks the save to play: `--slot N` or the last slot played, else a new game
## written straight to that slot. Harness runs (`--screenshot`) play a fresh
## throwaway hero unless a slot is named explicitly. Runs once per session:
## the world scene reloads after a slot switch and must not undo it.
func boot(args: PackedStringArray) -> void:
	if _booted:
		return
	_booted = true
	settings.load_file()
	var slot_index := args.find("--slot")
	if slot_index >= 0 and slot_index + 1 < args.size():
		slot = clampi(int(args[slot_index + 1]), 1, SaveSlots.SLOT_COUNT)
	elif args.has("--screenshot"):
		slot = NO_SLOT
		settings.read_only = true
		# `still`: the run with Reduce motion on, as a player can set it.
		if args.has("still"):
			settings.reduce_motion = true
	else:
		slot = clampi(settings.last_slot, 1, SaveSlots.SLOT_COUNT)
	var saved := slots.read(slot) if slot != NO_SLOT else {}
	first_run = slot != NO_SLOT and range(1, SaveSlots.SLOT_COUNT + 1).all(
		func(n: int) -> bool: return slots.summary(n).is_empty()
	)
	if saved.is_empty():
		new_game()
		# A plain launch waits for the title's hero; a named slot starts at once.
		standing_in = slot_index < 0
		save_now()
	else:
		apply(saved)
	if slot != NO_SLOT and settings.last_slot != slot:
		settings.last_slot = slot
		settings.save_file()


## Switches play to another slot: the current one is saved first, an empty
## one starts a new hero. The caller reloads the world scene afterwards.
func play_slot(target: int) -> void:
	save_now()
	_use_slot(target)
	var saved := slots.read(target)
	if saved.is_empty():
		new_game()
		save_now()
	else:
		apply(saved)


## Writes a brand-new hero into a slot (replacing whatever was there) and plays it.
func new_hero_in(target: int, name := DEFAULT_HERO_NAME, role_id := DEFAULT_ROLE, look := 0) -> void:
	save_now()
	_use_slot(target)
	new_game(name, role_id, look)
	save_now()
	if settings.last_slot != target:
		settings.last_slot = target
		settings.save_file()


## Where a new hero should live: the slot in hand while a stand-in holds it,
## else the first empty one; 0 when all are taken.
func free_slot() -> int:
	if standing_in:
		return slot
	for n in range(1, SaveSlots.SLOT_COUNT + 1):
		if slots.summary(n).is_empty():
			return n
	return 0


## Brings a migrated save (the web game's, a pasted code) into a slot and plays it.
func import_into(target: int, state: Dictionary) -> void:
	save_now()
	_use_slot(target)
	apply(state)
	save_now()


## Empties a slot. The slot being played cannot be cleared from under the hero.
func clear_slot(target: int) -> bool:
	if target == slot:
		return false
	slots.erase(target)
	return true


## This hero as a PXH1 code: loads in the web game's Import too.
func save_code() -> String:
	return SaveCodec.encode_code(to_dict())


func _use_slot(target: int) -> void:
	slot = target
	first_run = false
	standing_in = false
	if settings.last_slot != target:
		settings.last_slot = target
		settings.save_file()


## A fresh level-1 hero waking in the village (CREATE_HERO).
func new_game(name := DEFAULT_HERO_NAME, role_id := DEFAULT_ROLE, look := 0) -> void:
	var state := SaveCodec.initial_state()
	state.merge(SaveCodec.RESUME_INTO, true)
	var weapon := InventoryState.create_gear(STARTER_WEAPONS.get(role_id, "rusty_sword"))
	state["hero"] = HeroState.create(name, role_id, look).to_dict()
	state["gold"] = STARTER_GOLD
	state["inventory"] = STARTER_ITEMS.duplicate()
	state["gear"] = [weapon]
	state["equipped"] = {"weapon": weapon["uid"]}
	state["introSeen"] = false
	state["world"] = SaveCodec.fresh_world()
	apply(state)


## Replaces the whole state with a normalized web-shaped save.
func apply(state: Dictionary) -> void:
	hero = HeroState.from_dict(state["hero"])
	pack = InventoryState.from_dict(state)
	settlement = SettlementState.from_dict(state)
	progression = ProgressionState.from_dict(state)
	world = WorldState.from_dict(state)
	mark_dirty()
	loaded.emit()
	gold_changed.emit(pack.gold)
	inventory_changed.emit()


## The full web GameState: what a slot file, a save code, or the web game reads.
func to_dict() -> Dictionary:
	var state := SaveCodec.initial_state()
	state.merge(SaveCodec.RESUME_INTO, true)
	state["hero"] = hero.to_dict()
	pack.write_into(state)
	settlement.write_into(state)
	progression.write_into(state)
	world.write_into(state)
	return state


func mark_dirty() -> void:
	dirty = true


func save_now() -> void:
	dirty = false
	_unsaved_seconds = 0.0
	# The title's stand-in hero is never written; a made or brought hero is.
	if slot != NO_SLOT and not standing_in:
		slots.write(slot, to_dict())


func _process(delta: float) -> void:
	if not dirty:
		return
	_unsaved_seconds += delta
	if _unsaved_seconds >= AUTOSAVE_SECONDS:
		save_now()


func _notification(what: int) -> void:
	# Window closed, tab hidden, app backgrounded, or the tree shutting down.
	var leaving := (
		what == NOTIFICATION_WM_CLOSE_REQUEST
		or what == NOTIFICATION_APPLICATION_FOCUS_OUT
		or what == NOTIFICATION_APPLICATION_PAUSED
		or what == NOTIFICATION_EXIT_TREE
	)
	if leaving and dirty:
		save_now()


## The hero stands on a new cell: remember it, see around it. Changing maps
## clears the slain ledger (it only ever describes the current map).
func move_to(map: MapData, cell: Vector2i, facing: Vector2) -> void:
	if map.id != world.map_id:
		world.slain.clear()
	world.map_id = map.id
	world.cell = cell
	world.facing = WorldState.facing_name(facing)
	Discovery.discover_around(world.discovered, map, cell)
	mark_dirty()


func walk(tiles: float) -> void:
	if tiles <= 0.0:
		return
	world.steps += tiles
	mark_dirty()


func owns_house() -> bool:
	return settlement.house.get("owned", false)


func is_opened(chest: Dictionary) -> bool:
	return chest["id"] in world.opened_chests


## 60 + 3 per point of strength (worn grants included) + carry passives.
func carry_capacity() -> int:
	var strength: int = hero.stats.get("strength", 0) + pack.granted_stat("strength")
	return 60 + strength * 3 + int(HeroRules.passives(hero)["carryBonus"])


## The shop the hero stands in (activeShopId); "" outside shops.
func active_shop() -> String:
	return Economy.shop_at(world.map_id)


func town_tier() -> int:
	return clampi(settlement.town_tier, 1, 4)


## A gem on the trophy shelf sweetens every sale by 10% (trophySellMultiplier).
func trophy_sell_multiplier() -> float:
	return 1.1 if "gem" in settlement.house.get("trophies", []) else 1.0


## BUY_ITEM: in stock here at this progress, and affordable. Shops sell honest
## common gear; the exciting rolls come from monsters.
func buy_item(item_id: String) -> bool:
	var shop_id := active_shop()
	if shop_id == "" or item_id not in Economy.shop_stock(shop_id, progression.unlocked_level):
		return false
	var price := Economy.buy_price(item_id)
	if pack.gold < price:
		return false
	pack.gold -= price
	if Catalog.item(item_id).has("slot"):
		pack.gear.append(InventoryState.create_gear(item_id))
	else:
		pack.add_item(item_id)
	_pack_changed()
	return true


## SELL_ITEM: `count` of a stack (one by default; the web sold one at a time),
## at this shop's rate. Returns the gold earned (0 = refused).
func sell_item(item_id: String, count := 1) -> int:
	var shop_id := active_shop()
	var have: int = pack.items.get(item_id, 0)
	if shop_id == "" or have <= 0:
		return 0
	var sold := mini(count, have)
	var price := floori(Economy.sell_price_at(shop_id, item_id, town_tier()) * trophy_sell_multiplier())
	pack.gold += price * sold
	pack.remove_item(item_id, sold)
	_pack_changed()
	return price * sold


## SELL_GEAR: never what the hero is wearing. Returns the gold earned (0 = refused).
func sell_gear(uid: String) -> int:
	var shop_id := active_shop()
	var instance := pack.gear_by_uid(uid)
	if shop_id == "" or instance.is_empty() or pack.is_equipped(uid):
		return 0
	var price := floori(
		Economy.gear_sell_price_at(shop_id, instance, town_tier()) * trophy_sell_multiplier()
	)
	pack.gold += price
	pack.gear.erase(instance)
	_pack_changed()
	return price


## UPGRADE_GEAR at the forge: +1 bonus for gold, up to the smithing cap; pays smithing xp.
func upgrade_gear(uid: String) -> bool:
	var shop_id := active_shop()
	var instance := pack.gear_by_uid(uid)
	if shop_id == "" or not Economy.shop(shop_id).get("forge", false) or instance.is_empty():
		return false
	var smithing: int = hero.jobs["smithing"]["level"]
	if instance["bonus"] >= Economy.forge_cap_for(smithing):
		return false
	var cost := Economy.forge_cost_for(instance["itemId"], instance["bonus"], smithing)
	if pack.gold < cost:
		return false
	pack.gold -= cost
	instance["bonus"] += 1
	Economy.grant_job_xp(hero.jobs, "smithing", 10)
	_pack_changed()
	return true


## CRAFT at the trade's station: materials in, the item out. Forged pieces are
## gear instances; skilled alchemists sometimes brew two. Returns {made, count}.
func craft(recipe_id: String) -> Dictionary:
	var entry := Economy.recipe(recipe_id)
	if entry.is_empty() or not Economy.can_craft(entry, pack.items, hero.jobs):
		return {"made": false, "count": 0}
	var job: String = entry["job"]["id"]
	if not Economy.at_job_station(job, world.map_id, settlement.house.get("workbench", false)):
		return {"made": false, "count": 0}
	for item_id: String in entry["needs"]:
		pack.remove_item(item_id, entry["needs"][item_id])
	var count := 1
	if Catalog.item(entry["itemId"]).has("slot"):
		pack.gear.append(InventoryState.create_gear(entry["itemId"]))
		Economy.grant_job_xp(hero.jobs, "smithing", 10)
	else:
		if roll.call() < Economy.double_brew_chance(hero.jobs["alchemy"]["level"]):
			count = 2
		pack.add_item(entry["itemId"], count)
		Economy.grant_job_xp(hero.jobs, "alchemy", 8)
	_pack_changed()
	return {"made": true, "count": count}


## The inn: a bed for coin, half price in a town (restAtInn). Returns the
## innkeeper's line.
func rest_at_inn() -> String:
	var cost := Town.rest_cost_for(town_tier())
	var whole: bool = hero.hp == hero.stats.get("maxHp", hero.hp) and hero.mp == hero.stats.get("maxMp", hero.mp)
	if whole:
		return "The innkeeper nods. You are already well rested."
	if pack.gold < cost:
		return "No coin, no bed. (Rest costs %dg.)" % cost
	pack.gold -= cost
	_make_whole()
	_pack_changed()
	return "You rest at the inn. Fully restored. (-%dg)" % cost


## FUND_TOWN at the hall: requirements checked, treasury paid, tier raised.
## The town redraws itself the moment the hero walks out.
func fund_town() -> String:
	if Town.fund_blocker(town_tier(), pack.gold, owns_house(), settlement.properties) != "":
		return ""
	var next := Town.next_tier(town_tier())
	pack.gold -= int(next.get("cost", 0))
	settlement.town_tier = next["tier"]
	_pack_changed()
	settlers_changed.emit()
	return "Pixelheim rises: the %s charter is signed. Walk outside." % String(next["name"]).to_upper()


## BUY_PROPERTY: the business you stand in, from its keeper.
func buy_property(map_id: String) -> bool:
	var deed: Dictionary = Town.deeds().get(map_id, {})
	if deed.is_empty() or map_id in settlement.properties or world.map_id != map_id:
		return false
	if pack.gold < int(deed["cost"]):
		return false
	pack.gold -= int(deed["cost"])
	settlement.properties.append(map_id)
	_pack_changed()
	return true


func steps_now() -> int:
	return int(world.steps)


func investments() -> Dictionary:
	if settlement.investments == null:
		settlement.investments = {"expansions": []}
	return settlement.investments


## BANK_DEPOSIT: any accrued interest folds into the new principal.
func bank_deposit(amount: int) -> bool:
	if amount <= 0 or pack.gold < amount:
		return false
	var inv := investments()
	var savings: Dictionary = inv.get("savings", {})
	var carried := 0 if savings.is_empty() else Town.savings_value(savings["principal"], savings["at"], steps_now())
	pack.gold -= amount
	inv["savings"] = {"principal": carried + amount, "at": steps_now()}
	_pack_changed()
	return true


## BANK_WITHDRAW: the whole pot, interest included. Returns the gold paid out.
func bank_withdraw() -> int:
	var inv := investments()
	var savings: Dictionary = inv.get("savings", {})
	if savings.is_empty():
		return 0
	var value := Town.savings_value(savings["principal"], savings["at"], steps_now())
	pack.gold += value
	inv.erase("savings")
	_pack_changed()
	return value


## FUND_VENTURE: one caravan on the road at a time.
func fund_venture() -> bool:
	var inv := investments()
	var cost := int(Town.bank("ventureCost"))
	if inv.has("venture") or pack.gold < cost:
		return false
	pack.gold -= cost
	inv["venture"] = {"stake": cost, "at": steps_now()}
	_pack_changed()
	return true


## COLLECT_VENTURE once it's back: {won, payout} or {} if not ready.
func collect_venture() -> Dictionary:
	var inv := investments()
	var venture: Dictionary = inv.get("venture", {})
	if venture.is_empty() or not Town.venture_ready(venture["at"], steps_now()):
		return {}
	var outcome := Town.venture_outcome(venture["stake"], venture["at"])
	pack.gold += outcome["payout"]
	inv.erase("venture")
	_pack_changed()
	return outcome


## EXPAND_PROPERTY: an owned business, once, for richer rent.
func expand_property(map_id: String) -> bool:
	var inv := investments()
	var cost := int(Town.bank("expansionCost"))
	if map_id not in settlement.properties or map_id in inv["expansions"] or pack.gold < cost:
		return false
	pack.gold -= cost
	inv["expansions"].append(map_id)
	_pack_changed()
	return true


func is_settled(id: String) -> bool:
	return id in settlement.settlers


## A conversation closed: recruits answer (resolveSettler), then the quest
## hooks (PIX-125) get their turn through dialogue_closed.
func finish_dialogue(npc_id: String) -> void:
	# Settlers first (recruiting and services ride the close), then quests.
	var text := _resolve_settler(npc_id)
	if text == "":
		text = resolve_quests(npc_id)
	dialogue_closed.emit(npc_id)
	if text != "":
		message.emit(text)


## Closing a conversation with a giver (resolveQuests): accept their first
## untaken quest, or turn in a finished one (deliveries leave the pack), or
## say how far along it stands. "" when they give no open quest.
func resolve_quests(giver_id: String) -> String:
	var entries := progression.quests
	for quest: Dictionary in Quests.for_giver(giver_id):
		var entry: Dictionary = entries.get(quest["id"], {})
		if entry.get("done", false):
			continue
		if entry.is_empty():
			entries[quest["id"]] = {"progress": 0, "done": false}
			save_now()
			return "Quest accepted - %s: %s" % [quest["name"], quest["accepted"]]
		var objective: Dictionary = quest["objective"]
		if Quests.is_ready(quest, entries, pack.items):
			if objective["kind"] == "deliver":
				pack.remove_item(objective["itemId"], int(objective["count"]))
			entry["done"] = true
			var reward: Dictionary = quest["reward"]
			pack.gold += int(reward["gold"])
			hero.xp += int(reward["xp"])
			_grant_levels()
			if reward.has("itemId"):
				pack.add_item(reward["itemId"])
			_pack_changed()
			save_now()
			return "Quest complete - %s! +%dg, +%d xp. %s" % [quest["name"], reward["gold"], reward["xp"], quest["completed"]]
		return "%s: %d/%d %s." % [
			quest["name"], Quests.progress(quest, entries, pack.items), objective["count"],
			String(objective["label"]).to_lower(),
		]
	return ""


## Recruiting where they wait; services once they live in town.
func _resolve_settler(npc_id: String) -> String:
	var recruit := Town.recruit(npc_id)
	if recruit.is_empty():
		return ""
	if not is_settled(npc_id):
		match Town.recruit_blocker(recruit, town_tier(), pack.gold, pack.items):
			"tier":
				return "%s: %s" % [recruit["name"], recruit.get("tierLine", "The town is not ready for me yet.")]
			"ask":
				var ask: Dictionary = recruit["ask"]
				var price: String = (
					"%dg" % ask["amount"] if ask["kind"] == "gold"
					else "%dx %s" % [ask["count"], Catalog.item_name(ask["itemId"])]
				)
				return "%s asks: %s. (%s)" % [recruit["name"], price, recruit["askLine"]]
		var ask: Dictionary = recruit["ask"]
		if ask["kind"] == "gold":
			pack.gold -= int(ask["amount"])
		else:
			pack.remove_item(ask["itemId"], ask["count"])
		settlement.settlers.append(npc_id)
		_pack_changed()
		settlers_changed.emit()
		save_now()
		return "%s joins Pixelheim! %s" % [recruit["name"], recruit["joinedLine"]]
	if world.map_id == "town":
		if npc_id == "settler_iva":
			_make_whole()
			return "Iva's hands glow warm. Fully healed, free of charge."
		if npc_id == "settler_loras":
			settlement.bard_song = true
			mark_dirty()
			return "Loras plays you a marching song. Your next hunt strikes truer. (+12% crit)"
	return ""


## The shut door in town: E buys the deed, or names the price (BUY_HOUSE).
func buy_house() -> String:
	if owns_house():
		return ""
	var cost := int(Town._data()["houseDeedCost"])
	if pack.gold < cost:
		return "For sale: this house. The deed costs %dg." % cost
	pack.gold -= cost
	settlement.house["owned"] = true
	_pack_changed()
	save_now()
	return "The deed is yours. Welcome home."


## BUY_HOUSE_UPGRADE at Odo's counter: Cottage, then Manor. The new interior
## is served the next time the hero walks in.
func buy_house_upgrade() -> String:
	var next := Town.next_house_tier(owns_house(), int(settlement.house.get("tier", 1)))
	if next.is_empty() or active_shop() != "odo" or pack.gold < int(next["cost"]):
		return ""
	pack.gold -= int(next["cost"])
	settlement.house["tier"] = next["tier"]
	_pack_changed()
	return "The %s deed is signed. Your house grew while you were out." % String(next["name"]).to_upper()


## The storage barrel (STORE_ITEM / TAKE_ITEM): stacks move between pack and home.
func store_item(item_id: String, count := 1) -> bool:
	var moved := mini(count, pack.items.get(item_id, 0))
	if not owns_house() or moved <= 0:
		return false
	pack.remove_item(item_id, moved)
	var storage: Dictionary = settlement.house["storage"]
	storage[item_id] = storage.get(item_id, 0) + moved
	_pack_changed()
	return true


func take_item(item_id: String, count := 1) -> bool:
	var storage: Dictionary = settlement.house["storage"]
	var moved := mini(count, storage.get(item_id, 0))
	if not owns_house() or moved <= 0:
		return false
	if storage[item_id] - moved > 0:
		storage[item_id] -= moved
	else:
		storage.erase(item_id)
	pack.add_item(item_id, moved)
	_pack_changed()
	return true


func trophies() -> Array:
	return settlement.house.get("trophies", [])


## DISPLAY_TROPHY: on the shelf for power; its stats join the hero's at once.
func display_trophy(item_id: String) -> bool:
	if not Town.trophy_buffs().has(item_id) or item_id in trophies() or pack.items.get(item_id, 0) <= 0:
		return false
	pack.remove_item(item_id)
	settlement.house["trophies"] = trophies() + [item_id]
	_shift_stats(Town.trophy_stat_delta(item_id), 1)
	_pack_changed()
	return true


## TAKE_TROPHY: back in the pack, and its stats leave with it.
func take_trophy(item_id: String) -> bool:
	if item_id not in trophies():
		return false
	settlement.house["trophies"] = trophies().filter(func(id: String) -> bool: return id != item_id)
	pack.add_item(item_id)
	_shift_stats(Town.trophy_stat_delta(item_id), -1)
	_pack_changed()
	return true


func _shift_stats(delta: Dictionary, direction: int) -> void:
	for stat: String in delta:
		hero.stats[stat] = int(hero.stats.get(stat, 0)) + direction * int(delta[stat])


## COMBINE_POTIONS at the manor's nook: two of a brew become one better.
func combine_potions(item_id: String) -> String:
	for combine: Dictionary in Town.nook_combines():
		if combine["from"] == item_id and pack.items.get(item_id, 0) >= 2:
			pack.remove_item(item_id, 2)
			pack.add_item(combine["to"])
			_pack_changed()
			return "The nook bubbles: 2x %s became %s." % [Catalog.item_name(item_id), Catalog.item_name(combine["to"])]
	return ""


func furniture() -> Array:
	return settlement.house.get("furniture", [])


func furniture_at(cell: Vector2i) -> Dictionary:
	for piece: Dictionary in furniture():
		if piece["x"] == cell.x and piece["y"] == cell.y:
			return piece
	return {}


## PLACE_FURNITURE on open floor in the house, one piece per tile.
func place_furniture(item_id: String, cell: Vector2i, tile: String) -> String:
	if world.map_id != "town_house" or pack.items.get(item_id, 0) <= 0:
		return ""
	if Catalog.item(item_id).get("category", "") != "furniture":
		return ""
	if tile != "floor":
		return "It needs open floor. Face a free tile and try again."
	if not furniture_at(cell).is_empty():
		return "Something already stands there."
	pack.remove_item(item_id)
	settlement.house["furniture"] = furniture() + [{"itemId": item_id, "x": cell.x, "y": cell.y}]
	_pack_changed()
	return "%s placed. E takes it back." % Catalog.item_name(item_id)


## What E does to a home tile (handleHouseInteract): returns {text, panel}.
## Placed furniture comes back with a touch; every fixture answers.
func house_interact(cell: Vector2i, tile: String) -> Dictionary:
	if world.map_id != "town_house":
		return {}
	var placed := furniture_at(cell)
	if not placed.is_empty():
		settlement.house["furniture"] = furniture().filter(func(piece: Dictionary) -> bool: return piece != placed)
		pack.add_item(placed["itemId"])
		_pack_changed()
		return {"text": "%s back in the pack." % Catalog.item_name(placed["itemId"])}
	match tile:
		"bed":
			_make_whole()
			return {"text": "Your own bed. Fully rested, free of charge."}
		"barrel":
			return {"panel": "storage"}
		"shelf":
			var cost := int(Town._data()["workbenchCost"])
			if settlement.house.get("workbench", false):
				return {"panel": "workbench"}
			if pack.gold >= cost:
				pack.gold -= cost
				settlement.house["workbench"] = true
				_pack_changed()
				return {"text": "A workbench and a small cauldron, fitted to the shelf. Craft at home, forever."}
			return {"text": "A proper workbench would fit this shelf. Tools and parts cost %dg." % cost}
		"hearth":
			return {"text": (
				"The hearth roars beside your workbench. Home industry." if settlement.house.get("workbench", false)
				else "The hearth crackles, warm and idle. A workbench would fit by the shelf..."
			)}
		"counter":
			return {"text": "Your kitchen counter. Clean, empty, hopeful."}
		"trophy_shelf":
			return {"panel": "trophies"}
		"garden":
			return {"text": "The garden drinks your victories: %d/%d until the next harvest." % [
				settlement.house.get("gardenWins", 0), Town._data()["gardenWinsPerYield"],
			]}
		"cauldron":
			return {"panel": "nook"}
		"floor":
			for item_id: String in pack.items:
				if Catalog.item(item_id).get("category", "") == "furniture":
					return {"panel": "furniture"}
	return {}


## A monster's blow lands on the hero; returns true when it was the last.
func hurt(amount: int) -> bool:
	hero.hp = maxi(0, hero.hp - amount)
	mark_dirty()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return hero.hp == 0


## Defeat is forgiving (RETURN_TO_WORLD after a loss): wake at the village
## inn, healed, purse intact. Returns where to wake.
func wake_at_inn() -> Dictionary:
	settlement.bard_song = false
	var inn: Dictionary = Catalog._data()["innRest"]
	_make_whole()
	save_now()
	message.emit("You wake at the inn. The innkeeper says nothing. Kind of her.")
	return inn


## A monster falls (onMonsterDefeated): mastery, bounties, rent, the garden,
## xp and gold with level-ups, a drop, and for wild kills the slain ledger and
## foraging. The bard's song fades with the fight. Returns the battle log.
func defeat_monster(fighter: Dictionary, region_id: String, spawn_id: String, floor_level: int) -> Array[String]:
	var log: Array[String] = []
	var mastery_line := _record_kill(fighter["id"])
	if mastery_line != "":
		log.append(mastery_line)
	# Accepted bounties tick on every matching kill.
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		var objective: Dictionary = quest["objective"]
		if entry.is_empty() or entry["done"] or objective["kind"] != "kill" or objective["monsterId"] != fighter["id"]:
			continue
		if entry["progress"] < objective["count"]:
			entry["progress"] += 1
			log.append("%s: %d/%d." % [quest["name"], entry["progress"], objective["count"]])
	monster_slain.emit(fighter["id"])
	if not settlement.properties.is_empty():
		var inv := investments()
		var expanded := 0
		for map_id: String in inv["expansions"]:
			if map_id in settlement.properties:
				expanded += int(Town.bank("expansionRent"))
		var rent := settlement.properties.size() * Town.rent_per_property(town_tier()) + expanded
		pack.gold += rent
		log.append("Rent from your properties: +%dg." % rent)
	if Town.house_tier(owns_house(), int(settlement.house.get("tier", 1))) >= 3:
		var wins: int = settlement.house.get("gardenWins", 0) + 1
		settlement.house["gardenWins"] = wins
		if wins >= int(Town._data()["gardenWinsPerYield"]):
			settlement.house["gardenWins"] = 0
			var harvests: int = settlement.house.get("gardenHarvests", 0)
			var crop := Town.garden_yield(harvests)
			settlement.house["gardenHarvests"] = harvests + 1
			pack.add_item(crop)
			log.append("Your garden ripens: +1 %s." % Catalog.item_name(crop))
	var passives := HeroRules.passives(hero)
	var gold := roundi(fighter["gold"] * (1 + passives["goldBonus"]))
	log.append("%s is defeated! +%d XP, +%d gold." % [fighter["name"], fighter["xp"], gold])
	hero.xp += int(fighter["xp"])
	pack.gold += gold
	if passives["killRefundMp"] > 0:
		hero.mp = mini(int(hero.stats["maxMp"]), hero.mp + int(passives["killRefundMp"]))
	var gained := _grant_levels()
	if gained > 0:
		log.append("LEVEL UP! You are now level %d. Fully restored. +%d stat points and +%d skill point%s to spend." % [
			hero.level, gained * int(Bestiary._data()["statPointsPerLevel"]), gained, "s" if gained > 1 else "",
		])
	var kind := "boss" if Bestiary.is_boss(fighter["id"]) else ("elite" if fighter["elite"] else "normal")
	var drop := Bestiary.roll_drop(floor_level, kind, roll)
	if drop.get("kind") == "gear":
		pack.gear.append(drop["gear"])
		log.append("%s drops: %s!" % [fighter["name"], InventoryState.gear_name(drop["gear"])])
	elif drop.get("kind") == "stack":
		pack.add_item(drop["itemId"])
		log.append("%s drops: %s." % [fighter["name"], Catalog.item_name(drop["itemId"])])
	if spawn_id != "":
		world.slain.append(spawn_id)
	var material: String = Bestiary._data()["regionMaterials"].get(region_id, "")
	if material != "" and roll.call() < Bestiary.forage_chance(hero.jobs["foraging"]["level"]):
		var count := 1 + (1 if roll.call() < Bestiary.double_forage_chance(hero.jobs["foraging"]["level"]) else 0)
		pack.add_item(material, count)
		log.append("You forage %d %s%s." % [count, Catalog.item_name(material), "s" if count > 1 else ""])
		if Economy.grant_job_xp(hero.jobs, "foraging", 5) > 0:
			log.append("Foraging reached %d!" % hero.jobs["foraging"]["level"])
	settlement.bard_song = false
	_pack_changed()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return log


## Banked XP becomes levels: the hero is made whole, and crossing into a new
## rank sends the ascension. Returns levels gained.
func _grant_levels() -> int:
	var rank_before := HeroRules.rank_index(hero.level)
	var gained := HeroRules.apply_level_ups(hero)
	if gained > 0:
		leveled_up.emit(hero.level)
		healed.emit()
		if HeroRules.rank_index(hero.level) > rank_before:
			ranked_up.emit(Ranks.title(hero.role_id, hero.level))
	return gained


## The hero as drawn: the role's look in whatever is worn (PunyArt.dressed).
func hero_art() -> Dictionary:
	return PunyArt.dressed(hero.role_id, hero.look, pack.worn_items())


## Puts on a gear piece (EQUIP): into its slot, a ring onto the empty finger
## (else the first). Whatever was there goes back to the pack.
func equip(uid: String) -> bool:
	var instance := pack.gear_by_uid(uid)
	if instance.is_empty() or pack.is_equipped(uid):
		return false
	var slot: String = Catalog.item(instance["itemId"]).get("slot", "")
	if slot == "":
		return false
	if slot == "ring":
		slot = "ring1" if not pack.equipped.has("ring1") else ("ring2" if not pack.equipped.has("ring2") else "ring1")
	pack.equipped[slot] = uid
	_pack_changed()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return true


## Takes off whatever fills a slot (UNEQUIP).
func unequip(slot: String) -> bool:
	if not pack.equipped.has(slot):
		return false
	pack.equipped.erase(slot)
	_pack_changed()
	return true


## Leaves items on the road (DROP): one, or `count` of them.
func drop_item(item_id: String, count := 1) -> bool:
	if pack.items.get(item_id, 0) <= 0:
		return false
	pack.remove_item(item_id, count)
	_pack_changed()
	return true


## Leaves a gear piece behind (DROP_GEAR); never one being worn.
func drop_gear(uid: String) -> bool:
	if pack.is_equipped(uid) or pack.gear_by_uid(uid).is_empty():
		return false
	pack.gear.assign(pack.gear.filter(func(piece: Dictionary) -> bool: return piece["uid"] != uid))
	_pack_changed()
	return true


## Drinks or eats something (USE_ITEM): health and mana up to their caps.
## The cure, if any, is for the world to apply to the hero's live ailments.
## Returns {used, text, cures}.
func use_item(item_id: String) -> Dictionary:
	var item := Catalog.item(item_id)
	if pack.items.get(item_id, 0) <= 0 or not (item.has("restoreHp") or item.has("restoreMp") or item.has("cures")):
		return {"used": false, "text": "", "cures": ""}
	pack.remove_item(item_id)
	var parts: Array[String] = []
	if item.has("restoreHp"):
		var healed := mini(int(hero.stats["maxHp"]), hero.hp + int(item["restoreHp"])) - hero.hp
		hero.hp += healed
		parts.append("%d HP" % healed)
	if item.has("restoreMp"):
		var restored := mini(int(hero.stats["maxMp"]), hero.mp + int(item["restoreMp"])) - hero.mp
		hero.mp += restored
		parts.append("%d %s" % [restored, Skills.resource_label(hero.role_id)])
	_pack_changed()
	healed.emit()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	var text := "You use %s." % item["name"]
	if not parts.is_empty():
		text += " Restored %s." % ", ".join(parts)
	return {"used": true, "text": text, "cures": item.get("cures", "")}


## A skill's price, paid (heroSkill): its mana or stamina, and its health
## price if it has one. False when it can't be paid.
func pay_for_skill(skill: Dictionary) -> bool:
	if Skills.cast_block(hero, skill) != "":
		return false
	hero.mp -= int(skill["mpCost"])
	hero.hp -= int(skill.get("hpCost", 0))
	mark_dirty()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return true


## A heal that lands, up to the cap; returns how much took.
func heal_hero(amount: int) -> int:
	var healed_by := mini(int(hero.stats["maxHp"]), hero.hp + amount) - hero.hp
	hero.hp += healed_by
	mark_dirty()
	healed.emit()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return healed_by


## A fighter's stamina comes back each turn of a fight (staminaRegen, from
## monsterTurn); casters' mana does not. Returns what came back.
func regen_stamina() -> int:
	var back := mini(int(hero.stats["maxMp"]), hero.mp + Skills.stamina_regen(hero)) - hero.mp
	if back > 0:
		hero.mp += back
		mark_dirty()
		hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return back


## A stat point, spent (SPEND_STAT_POINT).
func spend_stat_point(stat: String) -> bool:
	if hero.stat_points <= 0 or stat not in Skills.STATS:
		return false
	Skills.apply_stat_point(hero, stat)
	hero.stat_points -= 1
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	mark_dirty()
	return true


## A skill node learned for a point (BUY_SKILL_NODE): permanent, and some
## grow the hero's pools for good.
func buy_skill_node(node_id: String) -> bool:
	var entry := Skills.node(hero.role_id, node_id)
	if entry.is_empty() or not Skills.can_buy(hero, entry):
		return false
	hero.skill_nodes.append(node_id)
	hero.skill_points -= 1
	var grants: Dictionary = entry.get("grantStats", {})
	if grants.has("maxHp"):
		hero.stats["maxHp"] = int(hero.stats["maxHp"]) + int(grants["maxHp"])
		hero.hp += int(grants["maxHp"])
	if grants.has("maxMp"):
		hero.stats["maxMp"] = int(hero.stats["maxMp"]) + int(grants["maxMp"])
		hero.mp += int(grants["maxMp"])
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	save_now()
	return true


## One step deeper into the Path Graph (CHOOSE_PATH): only a node on offer,
## and for good; `spec` mirrors the first step for older code and saves.
func choose_path(node_id: String) -> bool:
	var offered := Ranks.path_choices(hero).any(func(node: Dictionary) -> bool: return node["id"] == node_id)
	if not offered:
		return false
	var path := HeroRules.walked(hero).duplicate()
	path.append(node_id)
	hero.path = path
	hero.spec = path[0]
	save_now()
	return true


## A dungeon floor's last foe falls (COLLECT_AND_RETURN): the first clear
## pays the floor's gold and items (gear arrives as fresh pieces, whatever the
## pack weighs) and opens the next floor; later clears pay only their kills.
## The bard's song fades with the outing. Returns {first, lines, victory}.
func clear_floor(level: int) -> Dictionary:
	settlement.bard_song = false
	var floor_def := Dungeons.floor_def(level)
	var lines: Array[String] = ["%s is cleared!" % floor_def["name"]]
	var first: bool = level not in progression.cleared_levels
	if first:
		progression.cleared_levels.append(level)
		pack.gold += int(floor_def["rewardGold"])
		var found: Array[String] = ["%dg" % floor_def["rewardGold"]]
		for item_id: String in floor_def["rewardItemIds"]:
			if Catalog.item(item_id).has("slot"):
				var piece := InventoryState.create_gear(item_id)
				pack.gear.append(piece)
				found.append(InventoryState.gear_name(piece))
			else:
				pack.add_item(item_id)
				found.append(Catalog.item_name(item_id))
		lines.append("The floor's hoard: %s." % ", ".join(found))
		var before := progression.unlocked_level
		progression.unlocked_level = Dungeons.unlocked_after(level, before)
		if progression.unlocked_level > before:
			lines.append("A deeper way opens: %s." % Dungeons.floor_def(progression.unlocked_level)["name"])
		_pack_changed()
	save_now()
	return {"first": first, "lines": lines, "victory": first and Dungeons.is_final(level)}


## Counts a kill toward its family's mastery; the slayer line when a tier is crossed.
func _record_kill(monster_id: String) -> String:
	var family := Bestiary.family_of(monster_id)
	if family == "":
		return ""
	if hero.mastery == null:
		hero.mastery = {}
	var before := Bestiary.mastery_tier(hero.mastery, family)
	hero.mastery[family] = hero.mastery.get(family, 0) + 1
	var after := Bestiary.mastery_tier(hero.mastery, family)
	if after <= before:
		return ""
	var name: String = Bestiary._data()["familyNames"][family]
	var bonus := roundi(float(Bestiary._data()["masteryTiers"][after - 1]["bonus"]) * 100)
	return "Mastery: %s Slayer %s - +%d%% damage against %s!" % [name, ["I", "II", "III"][after - 1], bonus, name.to_lower()]


func _make_whole() -> void:
	hero.hp = hero.stats.get("maxHp", hero.hp)
	hero.mp = hero.stats.get("maxMp", hero.mp)
	mark_dirty()
	healed.emit()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))


func _pack_changed() -> void:
	mark_dirty()
	gold_changed.emit(pack.gold)
	inventory_changed.emit()


## Grants a chest's payout (openChest in reducers/world.ts): gold, a stack, a
## gear piece, or a mimic's teeth. Loot that would overload the pack leaves the
## chest closed. Returns {opened, message, mimic}.
func open_chest(chest: Dictionary) -> Dictionary:
	if is_opened(chest):
		return {"opened": false, "message": "", "mimic": false}
	if chest.get("mimic", false):
		world.opened_chests.append(chest["id"])
		save_now()
		return {"opened": true, "message": "The chest bares its teeth — a mimic!", "mimic": true}
	var loot: Dictionary = chest["loot"]
	var message := ""
	if loot["kind"] == "gold":
		pack.gold += loot["amount"]
		message = (
			"Something glitters on the road: %dg." % loot["amount"] if chest["look"] == "glint"
			else "The chest holds %dg." % loot["amount"]
		)
		gold_changed.emit(pack.gold)
	else:
		var qty: int = loot["qty"] if loot["kind"] == "item" else 1
		var weight := int(Catalog.item(loot["itemId"]).get("weight", 0)) * qty
		if pack.carried_weight() + weight > carry_capacity():
			return {
				"opened": false,
				"message": "Too heavy to carry. Lighten the pack and come back.",
				"mimic": false,
			}
		if loot["kind"] == "gear":
			var instance := InventoryState.create_gear(loot["itemId"])
			pack.gear.append(instance)
			message = "The chest holds %s!" % InventoryState.gear_name(instance)
		else:
			pack.add_item(loot["itemId"], qty)
			var name := Catalog.item_name(loot["itemId"])
			message = (
				"You gather %dx %s." % [qty, name] if chest["look"] == "herb"
				else "The chest holds %dx %s." % [qty, name]
			)
		inventory_changed.emit()
	world.opened_chests.append(chest["id"])
	save_now()
	return {"opened": true, "message": message, "mimic": false}
