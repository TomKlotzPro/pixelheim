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
## The letter is in Maren's hands: the world plays the dawn (PIX-152).
signal prologue_dawn
## One line of feedback for the world (the web's worldMessage).
signal message(text: String)
## Lines for the battle log from outside a fight (PIX-206: a delivery's progress).
signal noted(lines: Array)
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
## A skill the hero can now use (PIX-160: its first-time hint).
## `key`: the dock key (1-6) it took, 0 when all six were taken (PIX-190).
signal skill_learned(entry: Dictionary, key: int)

## Slot 0 never touches disk: harness runs and tests leave real saves alone.
const NO_SLOT := 0
const AUTOSAVE_SECONDS := 3.0
## Until character creation lands (PIX-127), new games start this hero.
const DEFAULT_HERO_NAME := "Wanderer"
const DEFAULT_ROLE := "warrior"
## Starting kits (CREATE_HERO in reducers/meta.ts): rangers string a bow,
## casters carry a staff (PIX-172: the weapon you hold is the one you swing),
## everyone else begins with the humble rusty sword.
## Each class starts with a blade or a staff for its own best stat (PIX-205:
## the rogue's dagger is DEX, not a strength sword).
const STARTER_WEAPONS := {"ranger": "hunting_bow", "mage": "apprentice_staff", "cleric": "apprentice_staff", "necromancer": "apprentice_staff", "rogue": "worn_dagger"}
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


func _ready() -> void:
	# The autosave runs under open screens too (PIX-200): a shop or the pack
	# holds the world still, not the saving.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watch_the_page()


## Every key pressed teaches the labels what this keyboard calls it (PIX-201).
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		Controls.learn(event)


## The web page going away or out of sight saves what's unsaved (PIX-200):
## the web runtime tells the game nothing when a tab closes.
var _page_hidden: Variant


func _watch_the_page() -> void:
	if not OS.has_feature("web"):
		return
	_page_hidden = JavaScriptBridge.create_callback(func(_args: Array) -> void:
		if dirty:
			save_now())
	JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _page_hidden)
	JavaScriptBridge.get_interface("window").addEventListener("pagehide", _page_hidden)


## Whether this browser keeps saves at all (a private window doesn't).
static func saves_kept() -> bool:
	return not OS.has_feature("web") or OS.is_userfs_persistent()


## Picks the save to play: `--slot N` or the last slot played, else a new game
## written straight to that slot. Harness runs (`--screenshot`) play a fresh
## throwaway hero unless a slot is named explicitly. Runs once per session:
## the world scene reloads after a slot switch and must not undo it.
func boot(args: PackedStringArray) -> void:
	if _booted:
		return
	_booted = true
	settings.load_file()
	# The game speaks the player's language from the first screen (PIX-195);
	# `--lang xx` (harness) picks one for the run.
	var lang_index := args.find("--lang")
	Text.apply(args[lang_index + 1] if lang_index >= 0 and lang_index + 1 < args.size() else settings.language)
	# `--pseudo` (harness): every string stretched a third longer and
	# accented, to see where a longer language would overflow (PIX-195).
	if args.has("--pseudo"):
		ProjectSettings.set_setting("internationalization/pseudolocalization/expansion_ratio", 0.35)
		TranslationServer.pseudolocalization_enabled = true
		TranslationServer.set_locale("fr")
		Text.forget()
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


## Switches play to another slot's hero (the current one is saved first) and
## says whether there was one. The caller reloads the world scene afterwards.
func play_slot(target: int) -> bool:
	# An empty slot holds no one to play (Tom: playing one skipped the hero's
	# making and the Night of Ash): a new hero is made, in creation.
	var saved := slots.read(target)
	if saved.is_empty():
		return false
	save_now()
	_use_slot(target)
	apply(saved)
	return true


## Writes a brand-new hero into a slot (replacing whatever was there) and plays it.
## `night`: begin with the Night of Ash (a returning player may skip it).
func new_hero_in(target: int, name := DEFAULT_HERO_NAME, role_id := DEFAULT_ROLE, look := 0, night := true) -> void:
	save_now()
	_use_slot(target)
	new_game(name, role_id, look, night)
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


## Empties a slot; false when it already was.
func clear_slot(target: int) -> bool:
	if slots.summary(target).is_empty():
		return false
	slots.erase(target)
	# The hero in play goes too: what's left is the title's unsaved stand-in,
	# so no autosave can write them back.
	if target == slot:
		new_game()
		standing_in = true
		dirty = false
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
## `prologue`: a hero made at the title begins with the Night of Ash
## (PIX-152); the stand-ins (no save yet, tests, harness runs) start in town.
func new_game(name := DEFAULT_HERO_NAME, role_id := DEFAULT_ROLE, look := 0, prologue := false) -> void:
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
	# A new hero finds Pixelheim in ashes (PIX-146); heroes from before keep
	# the town they had.
	state["townTier"] = 0
	# ... and arrives on the road the night it burns, with the letter they
	# were paid to carry (the Night of Ash, PIX-152).
	if prologue:
		state["prologue"] = Prologue.SCAVENGER
		var start := Prologue.start()
		state["world"]["position"] = {"mapId": start["mapId"], "x": start["x"], "y": start["y"], "facing": start["facing"]}
		state["worldSteps"] = int(Prologue.night_steps())
		state["inventory"]["chancellors_letter"] = 1
	apply(state)


## Replaces the whole state with a normalized web-shaped save.
func apply(state: Dictionary) -> void:
	hero = HeroState.from_dict(state["hero"])
	pack = InventoryState.from_dict(state)
	settlement = SettlementState.from_dict(state)
	progression = ProgressionState.from_dict(state)
	world = WorldState.from_dict(state)
	mark_dirty()
	_delivered.clear()
	_note_deliveries(false)
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


## The hero stands on a new cell: remember it, see around it. The slain
## ledger outlives the door (PIX-142): packs come back on their own time.
func move_to(map: MapData, cell: Vector2i, facing: Vector2) -> void:
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
## The shops' stage (PIX-176): floors climbed or relics won.
func stock_stage() -> int:
	return Economy.stock_stage(progression.unlocked_level, Relics.found(progression))


func active_shop() -> String:
	return stall_shop if stall_shop != "" else Economy.shop_at(world.map_id)


## The hero's latest deed, for the town's gossip (PIX-149): {kind: cleared |
## boss | project | settler, and the name to say}. Not saved.
var last_deed := {}


## What the town has to show the hero next time they're in it (PIX-147):
## "project:<id>" built, "age:<tier>" reached, "home:<floor>" a boss's floor
## cleared. Not saved: a reload simply skips the tour.
var reveals: Array[String] = []


## The shop of the stall the hero is trading at on the burnt square (PIX-146),
## while its keeper's building is rubble; "" anywhere else.
var stall_shop := ""


## Whether the hero can craft a trade here: at its station, at the house's
## workbench, or at its keeper's stall while the station is rubble.
func at_station(job: String) -> bool:
	if Economy.at_job_station(job, world.map_id, settlement.house.get("workbench", false)):
		return true
	return stall_shop != "" and stall_shop == Economy.station_shop(job)


func town_tier() -> int:
	return clampi(settlement.town_tier, 0, Town.MAX_TIER)


## A gem on the trophy shelf sweetens every sale by 10% (trophySellMultiplier).
func trophy_sell_multiplier() -> float:
	return 1.1 if "gem" in settlement.house.get("trophies", []) else 1.0


## BUY_ITEM: in stock here at this progress, and affordable. Shops sell honest
## common gear; the exciting rolls come from monsters.
func buy_item(item_id: String) -> bool:
	var shop_id := active_shop()
	if shop_id == "" or item_id not in shop_wares(shop_id):
		return false
	var price := price_of(item_id)
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
	# A quest's goods aren't for sale (PIX-184), whatever screen asks.
	if shop_id == "" or have <= 0 or Catalog.item(item_id).get("quest", false):
		return 0
	var sold := mini(count, have)
	var price := floori(Economy.sell_price_at(shop_id, item_id, town_tier()) * sale_multiplier(shop_id))
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
		Economy.gear_sell_price_at(shop_id, instance, town_tier()) * sale_multiplier(shop_id)
	)
	pack.gold += price
	pack.gear.erase(instance)
	_pack_changed()
	return price


## Breaks a piece down at Hilda's (PIX-182): half of what it's made of back,
## a little forge practice. "" when it can't be done here.
func salvage_gear(uid: String) -> String:
	var instance := pack.gear_by_uid(uid)
	var shop_id := active_shop()
	if instance.is_empty() or pack.is_equipped(uid) or shop_id == "" or not Economy.shop(shop_id).get("forge", false):
		return ""
	var back := Economy.salvage_yield(instance)
	var parts: Array[String] = []
	for item_id: String in back:
		pack.add_item(item_id, int(back[item_id]))
		parts.append("%d %s" % [int(back[item_id]), Catalog.item_name(item_id)])
	pack.gear.erase(instance)
	Economy.grant_job_xp(hero.jobs, "smithing", int(Economy._data()["salvage"]["xp"]))
	_pack_changed()
	return Text.t("Hilda breaks it down: %s.") % ", ".join(parts)


## Reforges a piece at Hilda's from Smithing 8 (PIX-182): its rarity rolled
## again, never down, and new affixes. "" when it can't be done.
func reforge_gear(uid: String) -> String:
	var instance := pack.gear_by_uid(uid)
	var shop_id := active_shop()
	var rules: Dictionary = Economy._data()["reforge"]
	if instance.is_empty() or shop_id == "" or not Economy.shop(shop_id).get("forge", false):
		return ""
	if int(hero.jobs["smithing"]["level"]) < int(rules["smithing"]):
		return ""
	var cost := Economy.reforge_cost(instance)
	if pack.gold < cost:
		return ""
	pack.gold -= cost
	var ranks := ["common", "fine", "epic"]
	var rolled := Bestiary._roll_rarity(rules["weights"], roll)
	var rarity: String = rolled if ranks.find(rolled) > ranks.find(instance["rarity"]) else instance["rarity"]
	var fresh := InventoryState.create_gear(instance["itemId"], rarity, roll)
	instance["rarity"] = rarity
	instance.erase("affixes")
	if fresh.has("affixes"):
		instance["affixes"] = fresh["affixes"]
	if int(instance.get("deep", 0)) > 0:
		InventoryState.deep_affixes(instance, int(instance["deep"]), roll)
	Economy.grant_job_xp(hero.jobs, "smithing", 10)
	_pack_changed()
	return Text.t("Hilda reforges it: %s.") % InventoryState.gear_name(instance)


## UPGRADE_GEAR at the forge: +1 bonus for gold, up to the smithing cap; pays smithing xp.
func upgrade_gear(uid: String) -> bool:
	var shop_id := active_shop()
	var instance := pack.gear_by_uid(uid)
	if shop_id == "" or not Economy.shop(shop_id).get("forge", false) or instance.is_empty():
		return false
	var smithing: int = hero.jobs["smithing"]["level"]
	# Past the cap, masterwork (PIX-180): Smithing 8, a gem a step, a rising price.
	var masterwork: bool = instance["bonus"] >= Economy.forge_cap_for(smithing)
	if masterwork and not Economy.masterwork_open(smithing, instance["bonus"]):
		return false
	var cost := forge_price(instance, smithing, masterwork)
	var gem := String(Economy._data()["masterwork"]["gem"])
	if pack.gold < cost or (masterwork and int(pack.items.get(gem, 0)) < 1):
		return false
	pack.gold -= cost
	if masterwork:
		pack.remove_item(gem)
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
	if not at_station(job):
		return {"made": false, "count": 0}
	for item_id: String in entry["needs"]:
		pack.remove_item(item_id, entry["needs"][item_id])
	var count := 1
	if Catalog.item(entry["itemId"]).has("slot"):
		# Mastery shows in the work (PIX-182): Fine or Epic the more levels
		# above the recipe, a level more at the home workbench.
		var bench := 1 if world.map_id.begins_with("town_house") and settlement.house.get("workbench", false) else 0
		var rarity := Economy.craft_rarity(int(hero.jobs[job]["level"]), int(entry["job"]["level"]), roll, bench)
		if rarity == "common" and job == "smithing" and Economy.forges_fine(hero.jobs["smithing"]["level"]):
			rarity = "fine"
		pack.gear.append(InventoryState.create_gear(entry["itemId"], rarity, roll))
	else:
		# Steeping two potions into one better never doubles (PIX-181).
		if not entry.get("steep", false) and roll.call() < Economy.double_brew_chance(hero.jobs["alchemy"]["level"]):
			count = 2
		pack.add_item(entry["itemId"], count)
	# The trade that made it learns from it (PIX-143: an amulet brewed at
	# the cauldron is alchemy, not smithing).
	var gained := Economy.grant_job_xp(hero.jobs, job, Economy.craft_xp(entry))
	# Accepted crafting quests count what the hero makes (PIX-143).
	for quest: Dictionary in Quests.all():
		var taken: Dictionary = progression.quests.get(quest["id"], {})
		var objective: Dictionary = quest["objective"]
		if not taken.is_empty() and not taken["done"] and objective["kind"] == "craft" and objective["itemId"] == entry["itemId"]:
			taken["progress"] = mini(int(objective["count"]), int(taken["progress"]) + count)
	_pack_changed()
	var level_line := Text.t("%s reached %d!") % [Economy.job_name(job), hero.jobs[job]["level"]] if gained > 0 else ""
	return {"made": true, "count": count, "level_line": level_line}


## The inn: a bed for coin, half price in a town (restAtInn). Returns the
## innkeeper's line.
func rest_at_inn() -> String:
	var cost := Town.rest_cost_for(town_tier())
	var whole: bool = hero.hp == hero.stats.get("maxHp", hero.hp) and hero.mp == hero.stats.get("maxMp", hero.mp)
	if whole:
		return Text.t("The innkeeper nods. You are already well rested.")
	if pack.gold < cost:
		return Text.t("No coin, no bed: a night costs %d gold.") % cost
	pack.gold -= cost
	_make_whole()
	wake_the_wilds()
	# The inn rebuilt (PIX-206): a real bed leaves the hero rested a while.
	var line := Text.t("You rest at the inn and wake fully restored. -%d gold.") % cost
	if project_built("the_inn"):
		var fights := int(Town._data()["rested"]["innFights"])
		settlement.house["rested"] = maxi(int(settlement.house.get("rested", 0)), fights)
		line += " " + Text.t("Well rested, too: more XP for your next %d fights.") % fights
	_pack_changed()
	return line


## Funds a village project (PIX-145): gold and materials paid, the project
## built (the town redraws as the hero next sees it), and the last of an age
## raises the town to that age. Returns the ledger's line, "" if it can't.
## A commission (PIX-180): once every age is built, a costly work for a
## lasting edge. "" when it can't be funded.
func fund_commission(commission_id: String) -> String:
	var entry := Town.commission(commission_id)
	if entry.is_empty() or Town.current_age(settlement) != 0 or commission_id in settlement.projects or pack.gold < int(entry["cost"]):
		return ""
	pack.gold -= int(entry["cost"])
	settlement.projects.append(commission_id)
	_pack_changed()
	save_now()
	return Text.t("%s: commissioned. %s") % [entry["name"], entry["blurb"]]


## What the funded commissions add to `kind` ("xp", "gold", "potion").
func commission_buff(kind: String) -> float:
	var total := 0.0
	for entry: Dictionary in Town.commissions():
		if entry["id"] in settlement.projects:
			total += float(entry["buff"].get(kind, 0.0))
	return total


func fund_project(project_id: String) -> String:
	if Town.project_blocker(project_id, progression, settlement, pack.gold, pack.items) != "":
		return ""
	var entry := Town.project(project_id)
	pack.gold -= int(entry["cost"]["gold"])
	for item_id: String in entry["cost"]["items"]:
		pack.remove_item(item_id, int(entry["cost"]["items"][item_id]))
	var tier_number := Town.age_of(project_id)
	settlement.projects.assign(Town.done_projects(settlement) + [project_id])
	var line := Text.t("%s: built. Walk outside and see.") % entry["name"]
	reveals.append("project:%s" % project_id)
	last_deed = {"kind": "project", "project": String(entry["name"]).to_lower().trim_prefix("the ").trim_prefix("a ")}
	if Town.age(tier_number)["projects"].all(func(candidate: Dictionary) -> bool: return candidate["id"] in settlement.projects):
		settlement.town_tier = tier_number
		reveals.append("age:%d" % tier_number)
		line = Text.t("%s: built - and Pixelheim is a %s now.") % [entry["name"], String(Town.tier(tier_number)["name"]).to_lower()]
		_start_festival(tier_number)
	_pack_changed()
	settlers_changed.emit()
	save_now()
	return line


## BUY_PROPERTY: the business you stand in, from its keeper.
func buy_property(map_id: String) -> bool:
	var deed: Dictionary = Town.deeds().get(map_id, {})
	if deed.is_empty() or map_id in settlement.properties or world.map_id != map_id:
		return false
	if pack.gold < int(deed["cost"]):
		return false
	pack.gold -= int(deed["cost"])
	settlement.properties.append(map_id)
	investments()["tills"] = investments().get("tills", {})
	investments()["tills"][map_id] = {"gold": 0, "earned": 0, "at": steps_now()}
	_pack_changed()
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
		entry["gold"] = mini(Town.till_cap(map_id, expanded, town_tier()), before + days * Town.daily_rent(map_id, expanded, town_tier()))
		entry["earned"] = int(entry["earned"]) + int(entry["gold"]) - before
		entry["at"] = int(entry["at"]) + days * day_steps
	return entry


## Empties a property's till into the purse; what it held.
func collect_till(map_id: String) -> int:
	if map_id not in settlement.properties:
		return 0
	var entry := till(map_id)
	var gold := int(entry["gold"])
	if gold > 0:
		pack.gold += gold
		entry["gold"] = 0
		_pack_changed()
	return gold


## The property a shop is, if the hero owns it ("" otherwise).
func owned_shop_map(shop_id: String) -> String:
	for map_id: String in settlement.properties:
		if Town.shop_of(map_id) == shop_id:
			return map_id
	return ""


## What an item costs here: an owner pays a tenth less in their own shop.
func price_of(item_id: String) -> int:
	var price := Economy.buy_price(item_id)
	if owned_shop_map(active_shop()) != "":
		price = roundi(price * (1.0 - float(Town._data()["rent"]["ownerDiscount"])))
	# Vex brews cheaper in a brewery of her own (PIX-206).
	if active_shop() == "alchemist" and project_built("vexs_brewery"):
		price = roundi(price * (1.0 - Town.project_perk("vexs_brewery", "buy")))
	return price


## What a shop sells now, with the owner's pick of the day in a shop you own.
func shop_wares(shop_id: String) -> Array:
	var wares: Array = Economy.shop_stock(shop_id, stock_stage(), town_tier()).duplicate()
	if owned_shop_map(shop_id) != "":
		var pick := Town.owner_pick(shop_id, steps_now() / int(Town.bank("daySteps")))
		if pick != "" and pick not in wares:
			wares.append(pick)
	return wares


func steps_now() -> int:
	return int(world.steps)


func investments() -> Dictionary:
	if settlement.investments == null:
		settlement.investments = {"expansions": []}
	return settlement.investments


## BANK_DEPOSIT (PIX-177): the interest so far is counted and kept apart,
## the new gold joins what was put in, and the day's clock runs on.
func bank_deposit(amount: int) -> bool:
	if amount <= 0 or pack.gold < amount:
		return false
	var inv := investments()
	var savings: Dictionary = inv.get("savings", {})
	var now := {"principal": 0, "earned": 0, "at": steps_now()} if savings.is_empty() else Town.savings_accrued(savings, steps_now(), perk_grown("settler_mirelle"))
	pack.gold -= amount
	inv["savings"] = {"principal": int(now["principal"]) + amount, "earned": int(now["earned"]), "at": int(now["at"])}
	_pack_changed()
	return true


## BANK_WITHDRAW: the whole pot, interest included. Returns the gold paid out.
func bank_withdraw() -> int:
	var inv := investments()
	var savings: Dictionary = inv.get("savings", {})
	if savings.is_empty():
		return 0
	var value := _savings_now(savings)
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


## The festival day (PIX-159): an age complete, the town celebrates for a
## day - stalls and confetti on the square, everyone out, and a ring toss
## with a prize for the best throw (once per festival).
func _start_festival(age: int) -> void:
	settlement.festival = {
		"until": int(world.steps) + int(Town.festival("days")) * DayNight.DAY_CYCLE_STEPS,
		"age": age,
		"won": false,
	}


func festival_on() -> bool:
	return not settlement.festival.is_empty() and world.steps < float(settlement.festival["until"])


## The ring toss's prize, the first win of a festival: gold by the age and
## festival pies. Returns the line, or "" when this festival's is already won.
func win_ring_toss() -> String:
	if not festival_on() or settlement.festival.get("won", false):
		return ""
	settlement.festival["won"] = true
	var gold := int(Town.festival("prizeGold")) * int(settlement.festival["age"])
	var pies := int(Town.festival("prizeCount"))
	pack.gold += gold
	pack.add_item(Town.festival("prizeItem"), pies)
	_pack_changed()
	save_now()
	return Text.t("The prize is yours: +%d gold and %d %ss!") % [gold, pies, Catalog.item_name(Town.festival("prizeItem"))]


## Whether a quest may be offered yet (PIX-171): its "opensAfter" is met,
## and Maren's relics aren't asked of a hero who climbed before the gate
## was barred.
## The quest a giver is about to offer (PIX-202): their next one not done,
## if it's untaken and open; {} otherwise. Its "accepted" line is their ask.
func quest_on_offer(giver_id: String) -> Dictionary:
	# A recruit waiting on a grown town asks nothing yet.
	var recruit := Town.recruit(giver_id)
	if not recruit.is_empty() and not is_settled(giver_id) and Town.recruit_blocker(recruit, town_tier()) == "tier":
		return {}
	for quest: Dictionary in Quests.for_giver(giver_id):
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		if entry.get("done", false):
			continue
		if entry.is_empty() and quest.get("unlessGateOpen", false) and Relics.gate_open(progression):
			continue
		return quest if entry.is_empty() and quest_open(quest) else {}
	return {}


## Whether the hero's first skill mends rather than strikes (a cleric's Mend):
## the night's lines say so (PIX-205).
func first_skill_heals() -> bool:
	var skills := Skills.hero_skills(hero)
	return not skills.is_empty() and skills[0]["kind"] == "heal"


func quest_open(quest: Dictionary) -> bool:
	if quest.get("unlessGateOpen", false) and Relics.gate_open(progression) and not progression.quests.has(quest["id"]):
		return false
	return Quests.is_open(quest, progression, settlement)


## The givers on a map with a word for the hero (PIX-171): a quest to offer
## or one to turn in. The map marks them.
func givers_waiting(npcs: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for npc: Dictionary in npcs:
		if Quests.awaits_word(npc["id"], progression.quests, pack.items, quest_open):
			out.append(npc)
	return out


## The floors the bounty board counts (PIX-170): the hero's own, and the
## notices the relics won have earned out in the Reach.
func board_floors() -> Array:
	return Hunts.board_floors(progression.cleared_levels, Relics.found(progression))


## A settler living here whose arc is done (PIX-157): their perk has grown.
func perk_grown(id: String) -> bool:
	return is_settled(id) and Town.perk_upgraded(id, progression.quests)


## What Loras's song adds to the crit chance: more once he has his horn.
func song_crit() -> float:
	return float(Town.arc("lorasCrit")) if perk_grown("settler_loras") else 0.12


## How much faster the hero walks above ground: Wren's riders taught them.
func walk_bonus() -> float:
	return float(Town.arc("wrenWalk")) if perk_grown("settler_wren") else 0.0


func _savings_now(savings: Dictionary) -> int:
	return Town.savings_value(savings, steps_now(), perk_grown("settler_mirelle"))


## A conversation closed: recruits answer (resolveSettler), then the quest
## hooks (PIX-125) get their turn through dialogue_closed.
func finish_dialogue(npc_id: String) -> void:
	# On the night of the fire, talking is the night's next step (PIX-152).
	if progression.prologue != Prologue.DONE:
		_prologue_talk(npc_id)
		dialogue_closed.emit(npc_id)
		return
	# Settlers first (recruiting and services ride the close), then quests;
	# a settler with an ask of their arc to make or take back (PIX-157) says
	# it after their service.
	var text := _resolve_settler(npc_id)
	if text == "":
		text = resolve_quests(npc_id)
	elif is_settled(npc_id) and Quests.awaits_word(npc_id, progression.quests, pack.items, quest_open):
		text += " " + resolve_quests(npc_id)
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
		# Maren's relics are no errand for a hero who climbed before the gate
		# was barred (PIX-170): she goes on to her next ask.
		if entry.is_empty() and quest.get("unlessGateOpen", false) and Relics.gate_open(progression):
			continue
		# A side quest waits for the story to reach it (PIX-171).
		if entry.is_empty() and not quest_open(quest):
			return ""
		if entry.is_empty():
			# A hunt whose quarry already fell counts at once (PIX-165).
			var already: bool = quest["objective"]["kind"] == "hunt" and quest["objective"]["named"] in progression.hunted
			entries[quest["id"]] = {"progress": int(quest["objective"]["count"]) if already else 0, "done": false}
			_note_deliveries(false)
			save_now()
			# The giver's words were just said; the line names the task (PIX-194).
			return Text.t("Quest accepted: %s. %s") % [quest["name"], quest["brief"]] + " " + Controls.say(Text.t("It's in your journal ({key:journal})."))
		var objective: Dictionary = quest["objective"]
		# A quest that ends in a choice waits for the hero's answer (PIX-192).
		if quest.has("choice") and Quests.is_ready(quest, entries, pack.items):
			return Text.t("%s: they wait on your answer.") % quest["name"]
		if Quests.is_ready(quest, entries, pack.items):
			if objective["kind"] == "deliver":
				pack.remove_item(objective["itemId"], int(objective["count"]))
			elif objective["kind"] == "relics":
				# They go into the mountain's gate (PIX-170).
				for item_id: String in objective["items"]:
					pack.remove_item(item_id)
			entry["done"] = true
			var reward: Dictionary = quest["reward"]
			pack.gold += int(reward["gold"])
			var level_line := earn_xp(int(reward["xp"]))
			if reward.has("itemId"):
				pack.add_item(reward["itemId"])
			# A recruit's story ends with them moving to town (PIX-148).
			if quest.has("settles") and quest["settles"] not in settlement.settlers:
				settlement.settlers.append(quest["settles"])
				last_deed = {"kind": "settler", "settler": String(Town.recruit(quest["settles"])["name"]).get_slice(" the ", 0)}
				settlers_changed.emit()
			_pack_changed()
			save_now()
			var paid: Array[String] = []
			if int(reward["gold"]) > 0:
				paid.append(Text.t("+%d gold") % reward["gold"])
			paid.append(Text.t("+%d XP") % reward["xp"])
			var done := Text.t("Quest complete: %s. %s. \u201c%s\u201d") % [quest["name"], ", ".join(paid), quest["completed"]]
			return done + ("\n" + level_line if level_line != "" else "")
		return Text.t("%s: %d/%d %s.") % [
			quest["name"], Quests.progress(quest, entries, pack.items), objective["count"],
			String(objective["label"]).to_lower(),
		]
	return ""


## The hero's answer to a quest that ends in a choice (PIX-192): the
## option's reward instead of the quest's, its words, and the choice kept
## (the giver remembers it). Returns the line to show, "" if not ready.
func choose(quest_id: String, option_id: String) -> String:
	var quest := Quests.by_id(quest_id)
	var entry: Dictionary = progression.quests.get(quest_id, {})
	if not quest.has("choice") or entry.is_empty() or entry["done"] or not Quests.is_ready(quest, progression.quests, pack.items):
		return ""
	var option: Dictionary = {}
	for each: Dictionary in quest["choice"]["options"]:
		if each["id"] == option_id:
			option = each
	if option.is_empty():
		return ""
	if quest["objective"]["kind"] == "deliver":
		pack.remove_item(quest["objective"]["itemId"], int(quest["objective"]["count"]))
	entry["done"] = true
	entry["choice"] = option_id
	var reward: Dictionary = option["reward"]
	pack.gold += int(reward.get("gold", 0))
	var level_line := earn_xp(int(reward.get("xp", 0)))
	if reward.has("itemId"):
		pack.add_item(reward["itemId"])
	_pack_changed()
	save_now()
	var paid: Array[String] = []
	if int(reward.get("gold", 0)) > 0:
		paid.append(Text.t("+%d gold") % reward["gold"])
	paid.append(Text.t("+%d XP") % reward.get("xp", 0))
	if reward.has("itemId"):
		paid.append(Catalog.item_name(reward["itemId"]))
	var done := Text.t("Quest complete: %s. %s. \u201c%s\u201d") % [quest["name"], ", ".join(paid), option["line"]]
	return done + ("\n" + level_line if level_line != "" else "")


## Recruiting where they wait; services once they live in town.
func _resolve_settler(npc_id: String) -> String:
	var recruit := Town.recruit(npc_id)
	if recruit.is_empty():
		return ""
	if not is_settled(npc_id):
		# A recruit's help is their quest (PIX-148, resolve_quests), once the
		# town is grown enough for them.
		if Town.recruit_blocker(recruit, town_tier()) == "tier":
			return Text.t("%s: %s") % [recruit["name"], recruit.get("tierLine", Text.t("The town is not ready for me yet."))]
		return ""
	if world.map_id == "town":
		if npc_id == "settler_iva":
			_make_whole()
			var line := Text.t("Iva's hands glow warm. Fully healed, free of charge.")
			var topped := _top_up_potions()
			if topped > 0:
				line += Text.t(" She tucks %d healing potion%s in your pack.") % [topped, "s" if topped > 1 else ""]
			return line
		if npc_id == "settler_loras":
			settlement.bard_song = true
			mark_dirty()
			return Text.t("Loras plays you a marching song%s. Your next hunt strikes truer. (+%d%% crit)") % [
				Text.t(" on his war-horn") if perk_grown("settler_loras") else "", roundi(song_crit() * 100),
			]
	return ""


## Iva's grown perk: healing potions up to three. Returns how many she gave.
func _top_up_potions() -> int:
	if not perk_grown("settler_iva"):
		return 0
	var short := int(Town.arc("ivaPotions")) - int(pack.items.get("potion_hp", 0))
	if short <= 0:
		return 0
	pack.add_item("potion_hp", short)
	_pack_changed()
	return short


## The shut door in town: E buys the deed, or names the price (BUY_HOUSE).
func buy_house() -> String:
	if owns_house():
		return ""
	var cost := int(Town._data()["houseDeedCost"])
	if pack.gold < cost:
		return Text.t("For sale: this house. The deed costs %d gold.") % cost
	pack.gold -= cost
	settlement.house["owned"] = true
	_pack_changed()
	save_now()
	return Text.t("The deed is yours. Welcome home.")


## BUY_HOUSE_UPGRADE at Odo's counter: Cottage, then Manor. The new interior
## is served the next time the hero walks in.
func buy_house_upgrade() -> String:
	var next := Town.next_house_tier(owns_house(), int(settlement.house.get("tier", 1)))
	if next.is_empty() or active_shop() != "odo" or pack.gold < int(next["cost"]):
		return ""
	pack.gold -= int(next["cost"])
	settlement.house["tier"] = next["tier"]
	# What stood where the new house puts a fixture (or the doorway) comes
	# back to the pack (PIX-179).
	var rooms := MapData.load_by_id("town_house" if int(next["tier"]) <= 1 else "town_house@%d" % int(next["tier"]))
	var moved := 0
	for piece: Dictionary in furniture():
		var cell := Vector2i(int(piece["x"]), int(piece["y"]))
		if rooms.tile_at(cell) != "floor" or cell == Vector2i(8, 8):
			pack.add_item(piece["itemId"])
			moved += 1
	settlement.house["furniture"] = furniture().filter(func(piece: Dictionary) -> bool:
		var cell := Vector2i(int(piece["x"]), int(piece["y"]))
		return rooms.tile_at(cell) == "floor" and cell != Vector2i(8, 8))
	_pack_changed()
	var line := Text.t("The %s deed is signed. Your house grew while you were out.") % String(next["name"])
	if moved > 0:
		line += Text.t(" %d piece%s of furniture had to move: it's back in your pack.") % [moved, "" if moved == 1 else "s"]
	return line


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
			return Text.t("The nook bubbles: 2x %s became %s.") % [Catalog.item_name(item_id), Catalog.item_name(combine["to"])]
	return ""


func furniture() -> Array:
	return settlement.house.get("furniture", [])


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
	if world.map_id != "town_house" or pack.items.get(item_id, 0) <= 0:
		return ""
	if Catalog.item(item_id).get("category", "") != "furniture":
		return ""
	if tile != "floor":
		return Text.t("It needs open floor. Face a free tile and try again.")
	if not furniture_at(cell).is_empty():
		return Text.t("Something already stands there.")
	if cell == Vector2i(8, 8):
		return Text.t("Not in the doorway: you'd trip over it coming home.")
	pack.remove_item(item_id)
	settlement.house["furniture"] = furniture() + [{"itemId": item_id, "x": cell.x, "y": cell.y}]
	_pack_changed()
	return Controls.say(Text.t("%s placed. {key:interact} takes it back.") % Catalog.item_name(item_id))


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
		return {"text": Text.t("%s back in the pack.") % Catalog.item_name(placed["itemId"])}
	match tile:
		"bed":
			_make_whole()
			# Well rested (PIX-179): more XP for the next fights, longer with the bench.
			var fights := int(Town._data()["rested"]["fights"]) + roundi(home_buff("rested"))
			settlement.house["rested"] = fights
			_pack_changed()
			return {"text": Text.t("Your own bed. Fully restored, and well rested: +%d%% XP for your next %d fights.") % [
				roundi(float(Town._data()["rested"]["xp"]) * 100), fights]}
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
				return {"text": Text.t("A workbench and a small cauldron, fitted to the shelf. Craft at home, forever.")}
			return {"text": Text.t("A proper workbench would fit this shelf. Tools and parts cost %d gold.") % cost}
		"hearth":
			return {"text": (
				Text.t("The hearth roars beside your workbench. Home industry.") if settlement.house.get("workbench", false)
				else Text.t("The hearth crackles, warm and idle. A workbench would fit by the shelf...")
			)}
		"counter":
			return {"text": Text.t("Your kitchen counter. Clean, empty, hopeful.")}
		"trophy_shelf":
			return {"panel": "trophies"}
		"garden":
			return {"text": Text.t("The garden drinks your victories: %d/%d until the next harvest.") % [
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
	# With the inn still rubble, Sela's tent on the square takes them in.
	var tent := Town.ashes_tent(Town.done_projects(settlement))
	if tent.x >= 0:
		inn = {"mapId": "town", "x": tent.x, "y": tent.y + 1, "facing": "down"}
	_make_whole()
	# A fall doesn't wake the wilds (PIX-206): what was cleared stays cleared,
	# and what was not is still out there. A night's rest wakes them.
	# It costs a tenth of the gold carried (PIX-192), never what's banked;
	# the night of the fire is a lesson, not a toll.
	var lost := death_toll()
	pack.gold -= lost
	_pack_changed()
	save_now()
	if lost > 0:
		message.emit(Text.t("You wake at the inn, %d gold lighter. What isn't banked is a fallen hero's to lose.") % lost)
	else:
		message.emit(Text.t("You wake at the inn. The innkeeper says nothing. Kind of her."))
	return inn


## An escort under way (PIX-192): {quest, def} for a taken escort quest
## whose wagon hasn't come down yet, {} otherwise.
func escort_due() -> Dictionary:
	for quest: Dictionary in Quests.all():
		var objective: Dictionary = quest["objective"]
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		if objective["kind"] == "escort" and not entry.is_empty() and not entry["done"] and int(entry["progress"]) < int(objective["count"]):
			return {"quest": quest, "def": Bestiary._data()["escorts"][objective["escort"]]}
	return {}


## The wagon is down: the escort's goal is met, the giver waits.
func escort_arrived(quest_id: String) -> void:
	var entry: Dictionary = progression.quests.get(quest_id, {})
	if entry.is_empty():
		return
	entry["progress"] = int(Quests.by_id(quest_id)["objective"]["count"])
	save_now()


## A quest against the clock (PIX-192): {quest, left} while one runs, {}.
func timed_run() -> Dictionary:
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		if quest.has("timed") and entry.has("left") and not entry["done"]:
			return {"quest": quest, "left": float(entry["left"])}
	return {}


## The clocks run while the world does (PIX-192): a timed quest's clock
## starts once its goods are in the pack and it's taken, stops when they
## leave it, and at nought the goods go back where they were found (their
## chest closes again). Returns {message, rearmed: chest ids}.
func tick_runs(delta: float) -> Dictionary:
	for quest: Dictionary in Quests.all():
		if not quest.has("timed"):
			continue
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		if entry.is_empty() or entry["done"]:
			continue
		var item: String = quest["objective"]["itemId"]
		var carried := int(pack.items.get(item, 0)) > 0
		if not entry.has("left"):
			if carried:
				entry["left"] = float(quest["timed"]["seconds"])
				return {"message": String(quest["timed"]["start"]) % quest["timed"]["seconds"], "rearmed": []}
			continue
		if not carried:
			entry.erase("left")
			continue
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) > 0.0:
			continue
		entry.erase("left")
		pack.remove_item(item, int(pack.items.get(item, 0)))
		var rearmed: Array[String] = []
		for chest: Dictionary in Interactables._data()["chests"]:
			if chest.get("loot", {}).get("itemId", "") == item and chest["id"] in world.opened_chests:
				world.opened_chests.erase(chest["id"])
				rearmed.append(chest["id"])
		_pack_changed()
		save_now()
		return {"message": quest["timed"]["lapse"], "rearmed": rearmed}
	return {"message": "", "rearmed": []}


## The gold a fall costs now: a tenth of what's carried (economy.json
## deathGoldShare), but never less than a night at the inn (PIX-206: a fall
## is no cheaper heal than a bed), as far as the purse goes; nothing on the
## night of the fire.
func death_toll() -> int:
	if progression.prologue != Prologue.DONE:
		return 0
	var share := floori(pack.gold * float(Economy._data()["deathGoldShare"]))
	return mini(pack.gold, maxi(Town.rest_cost_for(town_tier()), share))


## A monster falls (onMonsterDefeated): mastery, bounties, rent, the garden,
## xp and gold with level-ups, a drop, and for wild kills the slain ledger and
## foraging. The bard's song fades with the fight. Returns the battle log.
## `mountain`: the mountain's floor the kill was on (its loot pools, PIX-191), 0 in the wilds.
func defeat_monster(fighter: Dictionary, region_id: String, spawn_id: String, floor_level: int, mountain := 0) -> Array[String]:
	var log: Array[String] = []
	var mastery_line := _record_kill(fighter["id"])
	# The codex remembers the kind, and the highest level it was met at (PIX-188).
	progression.met[fighter["id"]] = maxi(int(progression.met.get(fighter["id"], 0)), Bestiary.level_of(fighter))
	if mastery_line != "":
		log.append(mastery_line)
	# Accepted bounties tick on every matching kill; a hunt (PIX-165) only on
	# the one named monster it names.
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		var objective: Dictionary = quest["objective"]
		if entry.is_empty() or entry["done"]:
			continue
		var counts: bool = (objective["kind"] == "kill" and objective["monsterId"] == fighter["id"] and not fighter.has("named")) \
			or (objective["kind"] == "hunt" and objective["named"] == fighter.get("named", ""))
		if not counts:
			continue
		if entry["progress"] < objective["count"]:
			entry["progress"] += 1
			log.append("%s: %d/%d." % [quest["name"], entry["progress"], objective["count"]])
	monster_slain.emit(fighter["id"])
	if Town.house_tier(owns_house(), int(settlement.house.get("tier", 1))) >= 3:
		var wins: int = settlement.house.get("gardenWins", 0) + 1
		settlement.house["gardenWins"] = wins
		if wins >= int(Town._data()["gardenWinsPerYield"]):
			settlement.house["gardenWins"] = 0
			var harvests: int = settlement.house.get("gardenHarvests", 0)
			var crop := Town.garden_yield(harvests)
			settlement.house["gardenHarvests"] = harvests + 1
			var grown := int(Town._data()["gardenCount"])
			pack.add_item(crop, grown)
			log.append(Text.t("Your garden ripens: +%d %s.") % [grown, Catalog.item_name(crop)])
	var passives := HeroRules.passives(hero)
	var gold := roundi(fighter["gold"] * (1 + passives["goldBonus"] + commission_buff("gold") + home_buff("gold")))
	# A night in your own bed (PIX-179): more XP for a while.
	var rested := int(settlement.house.get("rested", 0))
	var rested_xp := float(Town._data()["rested"]["xp"]) if rested > 0 else 0.0
	if rested > 0:
		settlement.house["rested"] = rested - 1
	var xp := roundi(Bestiary.xp_for(fighter, hero.level) * (1.0 + commission_buff("xp") + home_buff("xp") + rested_xp))
	log.append(Text.t("%s is defeated! +%d XP, +%d gold.") % [fighter["name"], xp, gold])
	pack.gold += gold
	if passives["killRefundMp"] > 0:
		hero.mp = mini(int(hero.stats["maxMp"]), hero.mp + int(passives["killRefundMp"]))
	var level_line := earn_xp(xp)
	if level_line != "":
		log.append(level_line)
	# What the monster itself carries (PIX-143): a wolf's pelt, an imp's horn.
	for carried: Dictionary in Bestiary.drops_of(fighter["id"]):
		# A once-per-hero drop (PIX-180: Fafnyr's scale) is sure the first
		# time, then rare.
		var once := String(carried.get("once", ""))
		var chance := float(carried.get("after", carried["chance"])) if once != "" and once in progression.firsts else float(carried["chance"])
		if roll.call() < chance:
			if once != "" and once not in progression.firsts:
				progression.firsts.append(once)
			pack.add_item(carried["itemId"])
			log.append(Text.t("%s drops: %s.") % [fighter["name"], Catalog.item_name(carried["itemId"])])
	if fighter.has("named"):
		log.append_array(_hunted(fighter["named"]))
	var kind := "boss" if Bestiary.is_boss(fighter["id"]) else ("elite" if fighter["elite"] else "normal")
	var drop := Bestiary.roll_drop(floor_level, kind, roll, mountain)
	if drop.get("kind") == "gear":
		pack.gear.append(drop["gear"])
		log.append(Text.t("%s drops: %s!") % [fighter["name"], InventoryState.gear_name(drop["gear"])])
	elif drop.get("kind") == "stack":
		pack.add_item(drop["itemId"])
		log.append(Text.t("%s drops: %s.") % [fighter["name"], Catalog.item_name(drop["itemId"])])
	if spawn_id != "":
		clear_pack(spawn_id)
	var material: String = Bestiary._data()["regionMaterials"].get(region_id, "")
	if material != "" and roll.call() < Bestiary.forage_chance(hero.jobs["foraging"]["level"]):
		var count := 1 + (1 if roll.call() < Bestiary.double_forage_chance(hero.jobs["foraging"]["level"]) else 0)
		pack.add_item(material, count)
		log.append(Text.t("You forage %d %s%s.") % [count, Catalog.item_name(material), "s" if count > 1 else ""])
		if Economy.grant_job_xp(hero.jobs, "foraging", 5) > 0:
			log.append(Text.t("Foraging reached %d!") % hero.jobs["foraging"]["level"])
	settlement.bard_song = false
	_pack_changed()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return log


## XP earned, and the levels it makes: the level-up line with what there is
## to spend now, or "" when no level came of it.
func earn_xp(amount: int) -> String:
	hero.xp += amount
	var stat_before := hero.stat_points
	var skill_before := hero.skill_points
	if _grant_levels() == 0:
		return ""
	var skills_won := hero.skill_points - skill_before
	return Text.t("Level up: you are now level %d. +%d stat points and +%d skill point%s to spend.") % [
		hero.level, hero.stat_points - stat_before, skills_won, "s" if skills_won > 1 else "",
	]


## Banked XP becomes levels: the hero is lifted (HeroRules.apply_level_ups),
## and crossing into a new rank sends the ascension. Returns levels gained.
func _grant_levels() -> int:
	var rank_before := HeroRules.rank_index(hero.level)
	var gained := HeroRules.apply_level_ups(hero)
	if gained > 0:
		leveled_up.emit(hero.level)
		healed.emit()
		if HeroRules.rank_index(hero.level) > rank_before:
			ranked_up.emit(Ranks.title(hero.role_id, hero.level))
	return gained


## Picks a gathering spot (PIX-143): its material, a second one as often as
## foraging allows, foraging XP; the patch grows back after regrowSteps.
## Returns the log lines, none when there was nothing to pick.
func gather(spot_id: String, item_id: String) -> Array[String]:
	var lines: Array[String] = []
	if item_id == "" or not Gathering.is_ready(world, spot_id):
		return lines
	var count := 1 + (1 if roll.call() < Bestiary.double_forage_chance(hero.jobs["foraging"]["level"]) else 0)
	pack.add_item(item_id, count)
	world.gathered_at[spot_id] = int(world.steps)
	lines.append(Text.t("You gather %d %s%s.") % [count, Catalog.item_name(item_id), "s" if count > 1 else ""])
	if Economy.grant_job_xp(hero.jobs, "foraging", int(Gathering.rules()["jobXp"])) > 0:
		lines.append(Text.t("Foraging reached %d!") % hero.jobs["foraging"]["level"])
	_pack_changed()
	return lines


## A cast from a fishing spot (PIX-165): a catch if they're biting there,
## foraging's job xp with it. "" when the spot is resting.
func fish(spot_id: String) -> String:
	if not Gathering.fish_ready(world, spot_id):
		return Text.t("Nothing's biting here yet. Try again in a while, or somewhere else.")
	var caught := Gathering.catch(roll, Gathering.fishing_spot(spot_id))
	pack.add_item(caught)
	world.gathered_at[spot_id] = int(world.steps)
	var line := Text.t("You cast, wait... and land %s!") % Catalog.item_name(caught).to_lower() if caught != "old_boot" else Text.t("You cast, wait... and haul up an old boot.")
	if Economy.grant_job_xp(hero.jobs, "foraging", int(Gathering.rules()["jobXp"])) > 0:
		line += Text.t(" Foraging reached %d!") % hero.jobs["foraging"]["level"]
	_pack_changed()
	return line


## The Night of Ash moves on when the survivor whose turn it is has spoken:
## Bram freed, Sela's bandages (she heals), the letter in Maren's hands, and
## then the dawn (the world plays it, then calls finish_prologue).
func _prologue_talk(npc_id: String) -> void:
	if Prologue.step_of(npc_id) != progression.prologue:
		return
	match progression.prologue:
		Prologue.SELA:
			_make_whole()
			# And a cap to wear (PIX-197: the pack and worn gear, taught).
			var cap := InventoryState.create_gear(String(Prologue.data()["cap"]["itemId"]))
			pack.gear.append(cap)
			_pack_changed()
			message.emit(String(Prologue.data()["cap"]["given"]))
		Prologue.MAREN:
			pack.remove_item("chancellors_letter")
			_pack_changed()
			prologue_dawn.emit()
			return
	_prologue_on()


## The scavenger at the gate fell: its pouch, and on to the village.
func prologue_pouch() -> String:
	if progression.prologue != Prologue.SCAVENGER:
		return ""
	pack.add_item("potion_hp")
	progression.prologue = Prologue.GATE
	_pack_changed()
	save_now()
	return Controls.say(String(Prologue.data()["pouch"]))


## Through the gate into the burning village.
func prologue_reached_town() -> void:
	if progression.prologue == Prologue.GATE:
		_prologue_on()


## The night's next beat (Prologue.ORDER), saved.
func _prologue_on() -> void:
	progression.prologue = Prologue.next(progression.prologue)
	save_now()


## A wave of the night's foes is down (the hounds, the embers): on, with
## the line that says where to next.
func prologue_wave_cleared() -> String:
	var wave := Prologue.wave(progression.prologue)
	if wave.is_empty():
		return ""
	_prologue_on()
	return String(wave["cleared"])


## A burning home put out with the well's water (PIX-197); the line to say.
func prologue_douse(ruin: int) -> String:
	if progression.prologue != Prologue.FIRES or ruin in progression.prologue_doused:
		return ""
	progression.prologue_doused.append(ruin)
	var fires: Dictionary = Prologue.data()["fires"]
	if progression.prologue_doused.size() >= Prologue.fires_needed():
		_prologue_on()
		return String(fires["done"])
	save_now()
	return "%s (%d/%d)" % [fires["doused"], progression.prologue_doused.size(), Prologue.fires_needed()]


## Dawn: the night is over and the game proper begins.
func finish_prologue() -> void:
	progression.prologue = Prologue.DONE
	progression.prologue_doused.clear()
	world.steps = Prologue.dawn_steps()
	pack.remove_item("chancellors_letter")
	_pack_changed()
	save_now()


## A spawn's pack is cleared: it stays down for Packs' respawnSteps (PIX-142).
func clear_pack(spawn_id: String) -> void:
	if spawn_id not in world.slain:
		world.slain.append(spawn_id)
	world.slain_at[spawn_id] = int(world.steps)
	mark_dirty()


## A named monster down for good (PIX-156): the bounty paid on the spot, the
## drop nothing else gives, and the town told - the villagers' talk, and the
## board's notice shown slain when the hero next walks into Pixelheim.
func _hunted(named_id: String) -> Array[String]:
	if named_id in progression.hunted:
		return []
	var entry := Hunts.named(named_id)
	progression.hunted.append(named_id)
	var lines: Array[String] = []
	if int(entry["bounty"]) > 0:
		pack.gold += int(entry["bounty"])
		lines.append(Text.t("The bounty on %s is yours: +%d gold.") % [entry["name"], int(entry["bounty"])])
	# Gear comes as a fresh piece; anything else (a relic) into the pack.
	var prize_name := Catalog.item_name(entry["drop"])
	if Catalog.item(entry["drop"]).has("slot"):
		var prize := InventoryState.create_gear(entry["drop"])
		pack.gear.append(prize)
		prize_name = InventoryState.gear_name(prize)
	else:
		pack.add_item(entry["drop"])
	lines.append(Text.t("%s leaves you %s!") % [entry["name"], prize_name])
	last_deed = {"kind": "hunt", "beast": entry["name"]}
	if entry.has("homecoming"):
		reveals.append("hunt:%s" % named_id)
	return lines


## A cleared pack is back at its home.
func revive_pack(spawn_id: String) -> void:
	world.slain.erase(spawn_id)
	world.slain_at.erase(spawn_id)
	mark_dirty()


## A night at the inn: every cleared pack is home again by morning.
func wake_the_wilds() -> void:
	world.slain.clear()
	world.slain_at.clear()
	mark_dirty()


## Whether this hero has seen a story moment (Cutscene scenes, PIX-32).
func has_seen(scene_id: String) -> bool:
	return scene_id in progression.story_seen


## Marks a story moment seen, for good.
func mark_seen(scene_id: String) -> void:
	if not has_seen(scene_id):
		progression.story_seen.append(scene_id)
		mark_dirty()


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
	# Sela's cap on (PIX-197): the night moves on to the fires.
	if progression.prologue == Prologue.CAP and slot == "head":
		_prologue_on()
		message.emit(Prologue.objective(progression.prologue, 0, first_skill_heals()))
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
	# The Healers' Hall makes every potion stronger (PIX-180).
	var potency := 1.0 + commission_buff("potion") + home_buff("potion")
	if item.has("restoreHp"):
		var healed := mini(int(hero.stats["maxHp"]), hero.hp + roundi(int(item["restoreHp"]) * potency)) - hero.hp
		hero.hp += healed
		parts.append(Text.t("%d HP") % healed)
	if item.has("restoreMp"):
		var restored := mini(int(hero.stats["maxMp"]), hero.mp + roundi(int(item["restoreMp"]) * potency)) - hero.mp
		hero.mp += restored
		parts.append("%d %s" % [restored, Skills.resource_label(hero.role_id)])
	_pack_changed()
	healed.emit()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	var text := Text.t("You use %s.") % item["name"]
	if not parts.is_empty():
		text += Text.t(" Restored %s.") % ", ".join(parts)
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


## Out of a fight every hero's mana or stamina trickles back (PIX-187): a
## twentieth of it each rest tick, at least one. Returns what came back.
func regen_resting() -> int:
	# Candles at home bring it back a point faster (PIX-179).
	var step := maxi(1, ceili(int(hero.stats["maxMp"]) * 0.05)) + roundi(home_buff("regen"))
	var back := mini(int(hero.stats["maxMp"]), hero.mp + step) - hero.mp
	# Health trickles back too (PIX-206), slowly: a bed or a potion is quicker.
	var mended := 0
	if hero.hp > 0:
		mended = mini(int(hero.stats["maxHp"]), hero.hp + rest_mend()) - hero.hp
	if back > 0 or mended > 0:
		hero.mp += back
		hero.hp += mended
		mark_dirty()
		hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	return back


## The health a quiet moment gives back (PIX-206): a hundredth, at least one.
func rest_mend() -> int:
	return maxi(1, floori(int(hero.stats["maxHp"]) * 0.01))


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


## Every bought skill forgotten for its point back (PIX-86): in the village,
## for Skills.forget_cost gold. What a skill grew (max HP or MP) shrinks back.
func forget_skills() -> bool:
	var forgotten := Skills.forgettable(hero)
	var cost := Skills.forget_cost(hero)
	if forgotten.is_empty() or not Skills.can_forget_at(world.map_id) or pack.gold < cost:
		return false
	for node_id: String in forgotten:
		var grants: Dictionary = Skills.node(hero.role_id, node_id).get("grantStats", {})
		for stat: String in ["maxHp", "maxMp"]:
			if grants.has(stat):
				hero.stats[stat] = int(hero.stats[stat]) - int(grants[stat])
		hero.skill_nodes.erase(node_id)
		if node_id in hero.skill_dock:
			hero.skill_dock[hero.skill_dock.find(node_id)] = ""
	hero.hp = mini(hero.hp, int(hero.stats["maxHp"]))
	hero.mp = mini(hero.mp, int(hero.stats["maxMp"]))
	hero.skill_points += forgotten.size()
	pack.gold -= cost
	_pack_changed()
	hp_changed.emit(hero.hp, int(hero.stats["maxHp"]))
	save_now()
	return true


## A skill node learned for a point (BUY_SKILL_NODE): kept until forgotten
## (forget_skills), and some grow the hero's pools while they're known.
func buy_skill_node(node_id: String) -> bool:
	var entry := Skills.node(hero.role_id, node_id)
	if entry.is_empty() or not Skills.can_buy(hero, entry):
		return false
	var active: bool = entry.get("kind", "") == "active"
	if active:
		Skills.pin_dock(hero)
	hero.skill_nodes.append(node_id)
	hero.skill_points -= 1
	if active:
		skill_learned.emit(entry, Skills.place_on_dock(hero, node_id))
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
	Skills.pin_dock(hero)
	var path := HeroRules.walked(hero).duplicate()
	path.append(node_id)
	hero.path = path
	hero.spec = path[0]
	# The first step brings a signature skill; later steps change it in place.
	Skills.place_on_dock(hero, "path")
	save_now()
	return true


## A known skill onto dock key `index` (0-5), from the skill tree (PIX-190).
func dock_skill(key: String, index: int) -> bool:
	if not Skills.bind(hero, key, index):
		return false
	save_now()
	return true


## A dungeon floor's last foe falls (COLLECT_AND_RETURN): the first clear
## pays the floor's gold and items (gear arrives as fresh pieces, whatever the
## pack weighs) and opens the next floor; later clears pay only their kills.
## The bard's song fades with the outing. Returns {first, lines, victory}.
func clear_floor(level: int) -> Dictionary:
	settlement.bard_song = false
	var floor_def := Dungeons.floor_def(level)
	var lines: Array[String] = [Text.t("%s is cleared!") % floor_def["name"]]
	var first: bool = level not in progression.cleared_levels
	if first:
		progression.cleared_levels.append(level)
		pack.gold += int(floor_def["rewardGold"])
		var found: Array[String] = [Text.t("%d gold") % floor_def["rewardGold"]]
		for item_id: String in floor_def["rewardItemIds"]:
			if Catalog.item(item_id).has("slot"):
				var piece := InventoryState.create_gear(item_id)
				pack.gear.append(piece)
				found.append(InventoryState.gear_name(piece))
			else:
				pack.add_item(item_id)
				found.append(Catalog.item_name(item_id))
		lines.append(Text.t("The floor's hoard: %s.") % ", ".join(found))
		# A page of Liane's journal, dropped on the way down (PIX-153).
		var page := Story.page_for(level)
		if not page.is_empty():
			lines.append(Controls.say(Text.t("Among the bones: a page of an old journal (%s). {key:journal} reads it.") % page["title"]))
		# A first clear is worth more than its fights (PIX-141): going deeper
		# levels the hero, farming what's beaten doesn't.
		var clear_xp := Dungeons.clear_xp(level)
		lines.append(Text.t("+%d XP for the way down.") % clear_xp)
		var level_line := earn_xp(clear_xp)
		if level_line != "":
			lines.append(level_line)
		if Town.homecoming(level) != "":
			reveals.append("home:%d" % level)
		var boss_id: String = Dungeons.boss_of(level)["monsterId"]
		if Bestiary.is_boss(boss_id):
			last_deed = {"kind": "boss", "boss": Bestiary.monster(boss_id)["name"]}
		else:
			last_deed = {"kind": "cleared", "floor": Text.t("the %s") % String(floor_def["name"]).trim_prefix("The ")}
		# Below the throne the stair goes on (PIX-161).
		if Dungeons.is_final(level):
			lines.append(Text.t("Behind the throne, a stair goes on down into the dark: the Deep Hunt."))
		var before := progression.unlocked_level
		progression.unlocked_level = Dungeons.unlocked_after(level, before)
		if progression.unlocked_level > before:
			lines.append(Text.t("A deeper way opens: %s.") % Dungeons.floor_def(progression.unlocked_level)["name"])
		_pack_changed()
	save_now()
	return {"first": first, "lines": lines, "victory": first and Dungeons.is_final(level)}


## A depth of the Deep Hunt cleared (PIX-161): a new deepest depth is
## recorded and pays its hoard and the way down; a depth already beaten pays
## only its fights.
func clear_deep(level: int) -> Dictionary:
	settlement.bard_song = false
	var depth := Dungeons.depth_of(level)
	var floor_def := Dungeons.floor_def(level)
	var lines: Array[String] = [Text.t("Depth %d of the Deep Hunt is cleared!") % depth]
	var record := depth > progression.deepest
	if record:
		progression.deepest = depth
		pack.gold += int(floor_def["rewardGold"])
		var found: Array[String] = [Text.t("%d gold") % floor_def["rewardGold"]]
		for item_id: String in floor_def["rewardItemIds"]:
			pack.add_item(item_id)
			found.append(Catalog.item_name(item_id))
		lines.append(Text.t("The deepest yet. Its hoard: %s.") % ", ".join(found))
		var clear_xp := Dungeons.clear_xp(level)
		lines.append(Text.t("+%d XP for the way down.") % clear_xp)
		var level_line := earn_xp(clear_xp)
		if level_line != "":
			lines.append(level_line)
		last_deed = {"kind": "cleared", "floor": Text.t("depth %d of the Deep Hunt") % depth}
		_pack_changed()
	lines.append(Text.t("A hole into the dark opens beside the way up: depth %d waits below.") % (depth + 1))
	save_now()
	return {"first": record, "lines": lines, "victory": false}


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
	return Text.t("Mastery: %s Slayer %s. +%d%% damage against %s.") % [name, ["I", "II", "III"][after - 1], bonus, name.to_lower()]


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
	_note_deliveries()


## What each accepted delivery had at the last look (PIX-206), so a pickup
## that brings one closer can say so.
var _delivered := {}


## Deliveries' progress as their items come and go: "Reeds: 2/3." in the
## battle log, and "ready" once all are there. `announce` false only takes
## the measure (after a load, or as a quest is taken).
func _note_deliveries(announce := true) -> void:
	var lines: Array[String] = []
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		if quest["objective"]["kind"] != "deliver" or entry.is_empty() or entry["done"]:
			_delivered.erase(quest["id"])
			continue
		var have := Quests.progress(quest, progression.quests, pack.items)
		var had := int(_delivered.get(quest["id"], have))
		_delivered[quest["id"]] = have
		if not announce or have <= had:
			continue
		var count := int(quest["objective"]["count"])
		if have >= count:
			lines.append(Text.t("%s: ready to hand in to %s.") % [quest["name"], String(Npcs.by_id(quest["giver"], settlement.settlers).get("name", quest["giver"]))])
		else:
			lines.append("%s: %d/%d." % [quest["name"], have, count])
	if not lines.is_empty():
		noted.emit(lines)


## The accepted delivery that spending `costs` (item id -> count) would set
## back (PIX-206): {quest, item}, or {} when none is touched.
func delivery_dip(costs: Dictionary) -> Dictionary:
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = progression.quests.get(quest["id"], {})
		var objective: Dictionary = quest["objective"]
		if objective["kind"] != "deliver" or entry.is_empty() or entry["done"] or not costs.has(objective["itemId"]):
			continue
		var have := int(pack.items.get(objective["itemId"], 0))
		var count := int(objective["count"])
		if mini(count, have - int(costs[objective["itemId"]])) < mini(count, have):
			return {"quest": quest["name"], "item": Catalog.item_name(objective["itemId"])}
	return {}


var _dip_asked := ""
var _dip_asked_at := -10.0
const DIP_CONFIRM_SECONDS := 4.0


## Before the board or a workbench takes what an accepted delivery needs
## (PIX-206), it asks: the first try returns the question, the same again
## within a few seconds goes ahead (""). `what` names the spend.
func ask_before_dip(what: String, costs: Dictionary) -> String:
	var dip := delivery_dip(costs)
	if dip.is_empty():
		return ""
	var now := Time.get_ticks_msec() / 1000.0
	if _dip_asked == what and now - _dip_asked_at <= DIP_CONFIRM_SECONDS:
		_dip_asked = ""
		return ""
	_dip_asked = what
	_dip_asked_at = now
	return Text.t("That uses what %s needs (%s). Do it again to go ahead.") % [dip["quest"], dip["item"]]


## Whether a village project stands (PIX-206: the Hamlet's each bring a perk).
func project_built(project_id: String) -> bool:
	return project_id in Town.done_projects(settlement)


## What a shop pays for what the hero sells, over its listed rate: a gem on
## the trophy shelf, and Odo's rebuilt store (PIX-206).
func sale_multiplier(shop_id: String) -> float:
	return trophy_sell_multiplier() * (1.0 + Town.project_perk("odos_store", "sell") if shop_id == "odo" and project_built("odos_store") else 1.0)


## Hilda's price for a +1 (PIX-206): a tenth less once her forge stands.
func forge_price(instance: Dictionary, smithing: int, masterwork: bool) -> int:
	var cost := Economy.masterwork_cost(instance["itemId"], instance["bonus"], smithing) if masterwork else Economy.forge_cost_for(instance["itemId"], instance["bonus"], smithing)
	if project_built("hildas_forge"):
		cost = roundi(cost * (1.0 - Town.project_perk("hildas_forge", "forge")))
	return cost


## Grants a chest's payout (openChest in reducers/world.ts): gold, a stack, a
## gear piece, or a mimic's teeth. Loot that would overload the pack leaves the
## chest closed. Returns {opened, message, mimic}.
func open_chest(chest: Dictionary) -> Dictionary:
	if is_opened(chest):
		return {"opened": false, "message": "", "mimic": false}
	if chest.get("mimic", false):
		world.opened_chests.append(chest["id"])
		save_now()
		return {"opened": true, "message": Text.t("The chest bares its teeth — a mimic!"), "mimic": true}
	var loot: Dictionary = chest["loot"]
	var message := ""
	if loot["kind"] == "gold":
		pack.gold += loot["amount"]
		message = (
			Text.t("Something glitters on the road: %d gold.") % loot["amount"] if chest["look"] == "glint"
			else Text.t("The chest holds %d gold.") % loot["amount"]
		)
		gold_changed.emit(pack.gold)
	else:
		var qty: int = loot["qty"] if loot["kind"] == "item" else 1
		var weight := int(Catalog.item(loot["itemId"]).get("weight", 0)) * qty
		if pack.carried_weight() + weight > carry_capacity():
			return {
				"opened": false,
				"message": Text.t("Too heavy to carry. Lighten the pack and come back."),
				"mimic": false,
			}
		if loot["kind"] == "gear":
			var instance := InventoryState.create_gear(loot["itemId"])
			pack.gear.append(instance)
			message = Text.t("The chest holds %s!") % InventoryState.gear_name(instance)
		else:
			pack.add_item(loot["itemId"], qty)
			var name := Catalog.item_name(loot["itemId"])
			message = (
				Text.t("You gather %dx %s.") % [qty, name] if chest["look"] == "herb"
				else Text.t("The chest holds %dx %s.") % [qty, name]
			)
		inventory_changed.emit()
	world.opened_chests.append(chest["id"])
	save_now()
	return {"opened": true, "message": message, "mimic": false}
