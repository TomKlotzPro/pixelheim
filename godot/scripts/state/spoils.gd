class_name Spoils
extends RefCounted
## What the hero wins (PIX-261, out of game_state.gd): a monster's fall
## (mastery, bounties, the garden, gold, drops, foraging), XP and the levels
## it makes, named hunts, cleared packs and the wilds waking, floors and
## depths cleared, chests, gathering and fishing, what a fall costs, and the
## boss slayer's edge. Apart from that edge, which lasts the session only, it
## holds nothing of its own: it all lives in GameState's sections, reached
## through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one. Signals are its too.
var owner: GameStateScript
## A boss or a named monster slain (PIX-232): the boss slayer's edge, this
## much more damage for this long. It lasts the session only; another hero
## loaded starts without it.
const SLAYER_SECONDS := 600.0
const SLAYER_DAMAGE := 0.10
## Seconds of the edge still to run (0 without it).
var slayer_left := 0.0


func _init(state: GameStateScript) -> void:
	owner = state


## A boss or a named monster fell to the hero: the edge begins, or starts
## over.
func slay_boss() -> void:
	slayer_left = SLAYER_SECONDS


## The world ran `delta` seconds: the edge wears down.
func tick_slayer(delta: float) -> void:
	slayer_left = maxf(0.0, slayer_left - delta)


## What the hero's blows and skills are multiplied by: more with the edge.
func damage_scale() -> float:
	return 1.0 + SLAYER_DAMAGE if slayer_left > 0.0 else 1.0


## A monster falls (onMonsterDefeated): mastery, bounties, rent, the garden,
## xp and gold with level-ups, a drop, and for wild kills the slain ledger and
## foraging. The bard's song fades with the fight. Returns the battle log.
## `mountain`: the mountain's floor the kill was on (its loot pools, PIX-191), 0 in the wilds.
func defeat_monster(fighter: Dictionary, region_id: String, spawn_id: String, floor_level: int, mountain := 0) -> Array[String]:
	var log: Array[String] = []
	var mastery_line := _record_kill(fighter["id"])
	# The codex remembers the kind, and the highest level it was met at (PIX-188).
	owner.progression.met[fighter["id"]] = maxi(int(owner.progression.met.get(fighter["id"], 0)), Bestiary.level_of(fighter))
	if mastery_line != "":
		log.append(mastery_line)
	# Accepted bounties tick on every matching kill; a hunt (PIX-165) only on
	# the one named monster it names.
	for quest: Dictionary in Quests.all():
		var entry: Dictionary = owner.progression.quests.get(quest["id"], {})
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
	owner.monster_slain.emit(fighter["id"])
	if Town.house_tier(owner.household.owns_house(), int(owner.settlement.house.get("tier", 1))) >= 3:
		var wins: int = owner.settlement.house.get("gardenWins", 0) + 1
		owner.settlement.house["gardenWins"] = wins
		if wins >= int(Town._data()["gardenWinsPerYield"]):
			owner.settlement.house["gardenWins"] = 0
			var harvests: int = owner.settlement.house.get("gardenHarvests", 0)
			var crop := Town.garden_yield(harvests)
			owner.settlement.house["gardenHarvests"] = harvests + 1
			var grown := int(Town._data()["gardenCount"])
			owner.pack.add_item(crop, grown)
			log.append(Text.t("Your garden ripens: +%d %s.") % [grown, Catalog.item_name(crop)])
	var passives := HeroRules.passives(owner.hero)
	var gold := roundi(fighter["gold"] * (1 + passives["goldBonus"] + owner.holdings.commission_buff("gold") + owner.household.home_buff("gold")))
	# A night in your own bed (PIX-179): more XP for a while.
	var rested := int(owner.settlement.house.get("rested", 0))
	var rested_xp := float(Town._data()["rested"]["xp"]) if rested > 0 else 0.0
	if rested > 0:
		owner.settlement.house["rested"] = rested - 1
	var xp := roundi(Bestiary.xp_for(fighter, owner.hero.level) * (1.0 + owner.holdings.commission_buff("xp") + owner.household.home_buff("xp") + rested_xp))
	log.append(Text.t("%s is defeated! +%d XP, +%d gold.") % [fighter["name"], xp, gold])
	owner.pack.gold += gold
	if passives["killRefundMp"] > 0:
		owner.hero.mp = mini(int(owner.hero.stats["maxMp"]), owner.hero.mp + int(passives["killRefundMp"]))
	var level_line := earn_xp(xp)
	if level_line != "":
		log.append(level_line)
	# What the monster itself carries (PIX-143): a wolf's pelt, an imp's horn.
	for carried: Dictionary in Bestiary.drops_of(fighter["id"]):
		# A once-per-hero drop (PIX-180: Fafnyr's scale) is sure the first
		# time, then rare.
		var once := String(carried.get("once", ""))
		var chance := float(carried.get("after", carried["chance"])) if once != "" and once in owner.progression.firsts else float(carried["chance"])
		if owner.roll.call() < chance:
			if once != "" and once not in owner.progression.firsts:
				owner.progression.firsts.append(once)
			owner.pack.add_item(carried["itemId"])
			log.append(Text.t("%s drops: %s.") % [fighter["name"], Catalog.item_name(carried["itemId"])])
	if fighter.has("named"):
		log.append_array(hunted(fighter["named"]))
	var kind := "boss" if Bestiary.is_boss(fighter["id"]) else ("elite" if fighter["elite"] else "normal")
	# A twisted depth of the Deep Hunt drops more often (PIX-216).
	var drop := Bestiary.roll_drop(floor_level, kind, owner.roll, mountain, Dungeons.loot_luck(mountain))
	if drop.get("kind") == "gear":
		owner.pack.gear.append(drop["gear"])
		log.append(Text.t("%s drops: %s!") % [fighter["name"], InventoryState.gear_name(drop["gear"])])
	elif drop.get("kind") == "stack":
		owner.pack.add_item(drop["itemId"])
		log.append(Text.t("%s drops: %s.") % [fighter["name"], Catalog.item_name(drop["itemId"])])
	if spawn_id != "":
		clear_pack(spawn_id)
	var material: String = Bestiary._data()["regionMaterials"].get(region_id, "")
	if material != "" and owner.roll.call() < Bestiary.forage_chance(owner.hero.jobs["foraging"]["level"]):
		var count := 1 + (1 if owner.roll.call() < Bestiary.double_forage_chance(owner.hero.jobs["foraging"]["level"]) else 0)
		owner.pack.add_item(material, count)
		log.append(Text.t("You forage %d %s%s.") % [count, Catalog.item_name(material), "s" if count > 1 else ""])
		if Economy.grant_job_xp(owner.hero.jobs, "foraging", 5) > 0:
			log.append(Text.t("Foraging reached %d!") % owner.hero.jobs["foraging"]["level"])
	owner.settlement.bard_song = false
	owner.pack_changed()
	owner.hp_changed.emit(owner.hero.hp, int(owner.hero.stats["maxHp"]))
	return log


## Counts a kill toward its family's mastery; the slayer line when a tier is crossed.
func _record_kill(monster_id: String) -> String:
	var family := Bestiary.family_of(monster_id)
	if family == "":
		return ""
	if owner.hero.mastery == null:
		owner.hero.mastery = {}
	var before := Bestiary.mastery_tier(owner.hero.mastery, family)
	owner.hero.mastery[family] = owner.hero.mastery.get(family, 0) + 1
	var after := Bestiary.mastery_tier(owner.hero.mastery, family)
	if after <= before:
		return ""
	var name: String = Bestiary._data()["familyNames"][family]
	var bonus := roundi(float(Bestiary._data()["masteryTiers"][after - 1]["bonus"]) * 100)
	return Text.t("Mastery: %s Slayer %s. +%d%% damage against %s.") % [name, ["I", "II", "III"][after - 1], bonus, name.to_lower()]


## A named monster down for good (PIX-156): the bounty paid on the spot, the
## drop nothing else gives, and the town told - the villagers' talk, and the
## board's notice shown slain when the hero next walks into Pixelheim.
func hunted(named_id: String) -> Array[String]:
	if named_id in owner.progression.hunted:
		return []
	var entry := Hunts.named(named_id)
	owner.progression.hunted.append(named_id)
	var lines: Array[String] = []
	if int(entry["bounty"]) > 0:
		owner.pack.gold += int(entry["bounty"])
		lines.append(Text.t("The bounty on %s is yours: +%d gold.") % [entry["name"], int(entry["bounty"])])
	# Gear comes as a fresh piece; anything else (a relic) into the pack. A
	# Deep Hunt named one's is epic and forged as deep as its lair (PIX-219).
	var prize_name := Catalog.item_name(entry["drop"])
	if Catalog.item(entry["drop"]).has("slot"):
		var prize := InventoryState.create_gear(entry["drop"], String(entry.get("dropRarity", "common")), owner.roll)
		if entry.has("deepDepth"):
			InventoryState.deepen(prize, Dungeons.deep_tier(Dungeons.floor_count() + int(entry["deepDepth"])), owner.roll)
		owner.pack.gear.append(prize)
		prize_name = InventoryState.gear_name(prize)
	else:
		owner.pack.add_item(entry["drop"])
	lines.append(Text.t("%s leaves you %s!") % [entry["name"], prize_name])
	owner.last_deed = {"kind": "hunt", "beast": entry["name"]}
	if entry.has("homecoming"):
		owner.reveals.append("hunt:%s" % named_id)
	return lines


## XP earned, and the levels it makes: the level-up line with what there is
## to spend now, or "" when no level came of it.
func earn_xp(amount: int) -> String:
	owner.hero.xp += amount
	var stat_before := owner.hero.stat_points
	var skill_before := owner.hero.skill_points
	if grant_levels() == 0:
		return ""
	var skills_won := owner.hero.skill_points - skill_before
	return Text.t("Level up: you are now level %d. +%d stat points and +%d skill point%s to spend.") % [
		owner.hero.level, owner.hero.stat_points - stat_before, skills_won, "s" if skills_won > 1 else "",
	]


## Banked XP becomes levels: the hero is lifted (HeroRules.apply_level_ups),
## and crossing into a new rank sends the ascension. Returns levels gained.
func grant_levels() -> int:
	var rank_before := HeroRules.rank_index(owner.hero.level)
	var gained := HeroRules.apply_level_ups(owner.hero)
	if gained > 0:
		owner.leveled_up.emit(owner.hero.level)
		owner.healed.emit()
		if HeroRules.rank_index(owner.hero.level) > rank_before:
			owner.ranked_up.emit(Ranks.title(owner.hero.role_id, owner.hero.level))
	return gained


## A spawn's pack is cleared: it stays down for Packs' respawnSteps (PIX-142).
func clear_pack(spawn_id: String) -> void:
	if spawn_id not in owner.world.slain:
		owner.world.slain.append(spawn_id)
	owner.world.slain_at[spawn_id] = int(owner.world.steps)
	owner.mark_dirty()


## A cleared pack is back at its home.
func revive_pack(spawn_id: String) -> void:
	owner.world.slain.erase(spawn_id)
	owner.world.slain_at.erase(spawn_id)
	owner.mark_dirty()


## A night at the inn: every cleared pack is home again by morning.
func wake_the_wilds() -> void:
	owner.world.slain.clear()
	owner.world.slain_at.clear()
	owner.mark_dirty()


## A dungeon floor's last foe falls (COLLECT_AND_RETURN): the first clear
## pays the floor's gold and items (gear arrives as fresh pieces, whatever the
## pack weighs) and opens the next floor; later clears pay only their kills.
## The bard's song fades with the outing. Returns {first, lines, victory}.
func clear_floor(level: int) -> Dictionary:
	owner.settlement.bard_song = false
	var floor_def := Dungeons.floor_def(level)
	var lines: Array[String] = [Text.t("%s is cleared!") % floor_def["name"]]
	var first: bool = level not in owner.progression.cleared_levels
	if first:
		owner.progression.cleared_levels.append(level)
		owner.pack.gold += int(floor_def["rewardGold"])
		var found: Array[String] = [Text.t("%d gold") % floor_def["rewardGold"]]
		for item_id: String in floor_def["rewardItemIds"]:
			if Catalog.item(item_id).has("slot"):
				var piece := InventoryState.create_gear(item_id)
				owner.pack.gear.append(piece)
				found.append(InventoryState.gear_name(piece))
			else:
				owner.pack.add_item(item_id)
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
			owner.reveals.append("home:%d" % level)
		var boss_id: String = Dungeons.boss_of(level)["monsterId"]
		if Bestiary.is_boss(boss_id):
			owner.last_deed = {"kind": "boss", "boss": Bestiary.monster(boss_id)["name"]}
		else:
			owner.last_deed = {"kind": "cleared", "floor": Text.t("the %s") % String(floor_def["name"]).trim_prefix("The ")}
		# Below the throne the stair goes on (PIX-161).
		if Dungeons.is_final(level):
			lines.append(Text.t("Behind the throne, a stair goes on down into the dark: the Deep Hunt."))
		var before := owner.progression.unlocked_level
		owner.progression.unlocked_level = Dungeons.unlocked_after(level, before)
		if owner.progression.unlocked_level > before:
			lines.append(Text.t("A deeper way opens: %s.") % Dungeons.floor_def(owner.progression.unlocked_level)["name"])
		owner.pack_changed()
	owner.save_now()
	return {"first": first, "lines": lines, "victory": first and Dungeons.is_final(level)}


## A depth of the Deep Hunt cleared (PIX-161): a new deepest depth is
## recorded and pays its hoard and the way down; a depth already beaten pays
## only its fights.
func clear_deep(level: int) -> Dictionary:
	owner.settlement.bard_song = false
	var depth := Dungeons.depth_of(level)
	var floor_def := Dungeons.floor_def(level)
	var lines: Array[String] = [Text.t("Depth %d of the Deep Hunt is cleared!") % depth]
	var record := depth > owner.progression.deepest
	if record:
		owner.progression.deepest = depth
		owner.pack.gold += int(floor_def["rewardGold"])
		var found: Array[String] = [Text.t("%d gold") % floor_def["rewardGold"]]
		for item_id: String in floor_def["rewardItemIds"]:
			owner.pack.add_item(item_id)
			found.append(Catalog.item_name(item_id))
		lines.append(Text.t("The deepest yet. Its hoard: %s.") % ", ".join(found))
		var clear_xp := Dungeons.clear_xp(level)
		lines.append(Text.t("+%d XP for the way down.") % clear_xp)
		var level_line := earn_xp(clear_xp)
		if level_line != "":
			lines.append(level_line)
		owner.last_deed = {"kind": "cleared", "floor": Text.t("depth %d of the Deep Hunt") % depth}
		# A milestone (PIX-216): its crystal came with the hoard; the town hears.
		var mark := Dungeons.milestone(depth)
		if not mark.is_empty():
			lines.append(Text.t("A milestone: %d depths below the throne. The %s is yours, a trophy for the shelf at home.") % [depth, Catalog.item_name(mark["itemId"])])
			owner.reveals.append("deep:%d" % depth)
		owner.pack_changed()
	lines.append(Text.t("A hole into the dark opens beside the way up: depth %d waits below.") % (depth + 1))
	owner.save_now()
	return {"first": record, "lines": lines, "victory": false}


## Grants a chest's payout (openChest in reducers/world.ts): gold, a stack, a
## gear piece, or a mimic's teeth. Loot that would overload the pack leaves the
## chest closed. Returns {opened, message, mimic}.
func open_chest(chest: Dictionary) -> Dictionary:
	if is_opened(chest):
		return {"opened": false, "message": "", "mimic": false}
	if chest.get("mimic", false):
		owner.world.opened_chests.append(chest["id"])
		owner.save_now()
		return {"opened": true, "message": Text.t("The chest bares its teeth — a mimic!"), "mimic": true}
	var loot: Dictionary = chest["loot"]
	var message := ""
	if loot["kind"] == "gold":
		owner.pack.gold += loot["amount"]
		message = (
			Text.t("Something glitters on the road: %d gold.") % loot["amount"] if chest["look"] == "glint"
			else Text.t("The chest holds %d gold.") % loot["amount"]
		)
		owner.gold_changed.emit(owner.pack.gold)
	else:
		var qty: int = loot["qty"] if loot["kind"] == "item" else 1
		var weight := int(Catalog.item(loot["itemId"]).get("weight", 0)) * qty
		if owner.pack.carried_weight() + weight > owner.upkeep.carry_capacity():
			return {
				"opened": false,
				"message": Text.t("Too heavy to carry. Lighten the pack and come back."),
				"mimic": false,
			}
		if loot["kind"] == "gear":
			var instance := InventoryState.create_gear(loot["itemId"])
			owner.pack.gear.append(instance)
			message = Text.t("The chest holds %s!") % InventoryState.gear_name(instance)
		else:
			owner.pack.add_item(loot["itemId"], qty)
			var name := Catalog.item_name(loot["itemId"])
			message = (
				Text.t("You gather %dx %s.") % [qty, name] if chest["look"] == "herb"
				else Text.t("The chest holds %dx %s.") % [qty, name]
			)
		owner.inventory_changed.emit()
	owner.world.opened_chests.append(chest["id"])
	owner.save_now()
	return {"opened": true, "message": message, "mimic": false}


func is_opened(chest: Dictionary) -> bool:
	return chest["id"] in owner.world.opened_chests


## Picks a gathering spot (PIX-143): its material, a second one as often as
## foraging allows, foraging XP; the patch grows back after regrowSteps.
## Returns the log lines, none when there was nothing to pick.
func gather(spot_id: String, item_id: String) -> Array[String]:
	var lines: Array[String] = []
	if item_id == "" or not Gathering.is_ready(owner.world, spot_id):
		return lines
	var count := 1 + (1 if owner.roll.call() < Bestiary.double_forage_chance(owner.hero.jobs["foraging"]["level"]) else 0)
	owner.pack.add_item(item_id, count)
	owner.world.gathered_at[spot_id] = int(owner.world.steps)
	lines.append(Text.t("You gather %d %s%s.") % [count, Catalog.item_name(item_id), "s" if count > 1 else ""])
	if Economy.grant_job_xp(owner.hero.jobs, "foraging", int(Gathering.rules()["jobXp"])) > 0:
		lines.append(Text.t("Foraging reached %d!") % owner.hero.jobs["foraging"]["level"])
	owner.pack_changed()
	return lines


## A cast from a fishing spot (PIX-165): a catch if they're biting there,
## foraging's job xp with it. "" when the spot is resting.
func fish(spot_id: String) -> String:
	if not Gathering.fish_ready(owner.world, spot_id):
		return Text.t("Nothing's biting here yet. Try again in a while, or somewhere else.")
	var caught := Gathering.catch(owner.roll, Gathering.fishing_spot(spot_id))
	owner.pack.add_item(caught)
	owner.world.gathered_at[spot_id] = int(owner.world.steps)
	var line := Text.t("You cast, wait... and land %s!") % Catalog.item_name(caught).to_lower() if caught != "old_boot" else Text.t("You cast, wait... and haul up an old boot.")
	if Economy.grant_job_xp(owner.hero.jobs, "foraging", int(Gathering.rules()["jobXp"])) > 0:
		line += Text.t(" Foraging reached %d!") % owner.hero.jobs["foraging"]["level"]
	owner.pack_changed()
	return line


## The gold a fall costs now: a tenth of what's carried (economy.json
## deathGoldShare), but never less than a night at the inn (PIX-206: a fall
## is no cheaper heal than a bed), as far as the purse goes; nothing on the
## night of the fire.
func death_toll() -> int:
	if owner.progression.prologue != Prologue.DONE:
		return 0
	var share := floori(owner.pack.gold * float(Economy._data()["deathGoldShare"]))
	return mini(owner.pack.gold, maxi(Town.rest_cost_for(owner.town_tier()), share))
