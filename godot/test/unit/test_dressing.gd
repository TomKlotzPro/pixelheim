extends GutTest
## Getting dressed is part of the game (PIX-294, Tom: « quand tu joues
## magicien t'as peu d'articles à acheter, etc. Pareil quand t'es guerrier.
## J'aimerais bien qu'avec la montée de niveau ça soit plus dur et que le
## joueur doive un peu s'habiller »). At each chapter, with the level the
## pacing model gives (test_pacing) and the shops a hero has reached by then
## (Hilda's stock at the stage the relics bring, and the traders of the
## regions walked), every class finds a weapon, armour and a trinket it
## couldn't buy at the chapter before; and the Reach's later foes and its
## bosses need that gear: in the starter kit a hero falls, in what the
## shops sell they stand.
##
## A fight is measured as the hero's plain swing (every 0.45 s) against the
## foe's armour and the foe's bite (every 0.9 s) against the hero's: the
## margin is how many such foes the hero fells from full health, 2 x bites
## to fall / swings to kill. A caster casts their first skill every other
## blow, while their mana lasts.

const PacingTest := preload("res://test/unit/test_pacing.gd")
## Each chapter: the relics home (Hilda's stock stage), the town's age, the
## traders a hero has met there, the region's hardest foe (and how far its
## floor lifts it) and the chapter's boss.
const MARKS := {
	"coast": {"relics": 0, "tier": 1, "shops": ["chandler"], "foe": ["pirate_gunner", 0], "boss": "tidecaller"},
	"mines": {"relics": 1, "tier": 1, "shops": ["chandler", "quartermaster"], "foe": ["goblin_spear", 1], "boss": "seam_warden"},
	"castle": {"relics": 2, "tier": 2, "shops": ["chandler", "quartermaster", "sutler"], "foe": ["hollow_guard", 1], "boss": "hollow_captain"},
	"frost": {"relics": 3, "tier": 2, "shops": ["chandler", "quartermaster", "sutler", "caravan"], "foe": ["frost_mammoth", 1], "boss": "rimefang"},
	"gate": {"relics": 4, "tier": 3, "shops": ["chandler", "quartermaster", "sutler", "caravan"], "foe": ["mimic", 0], "boss": "gulp"},
	# The Kings' Vault (PIX-257): its first floor and its last, in what the
	# shops sell (its own finds and forged drops come on top).
	"vault_1": {"relics": 4, "tier": 3, "shops": ["chandler", "quartermaster", "sutler", "caravan"], "foe": ["boneknight", 4], "boss": "hollowmother"},
	"vault_5": {"relics": 4, "tier": 3, "shops": ["chandler", "quartermaster", "sutler", "caravan"], "foe": ["imp", 7], "boss": "hollow_king"},
}
## The Reach's chapters, where the shops grow a tier each.
const ORDER := ["coast", "mines", "castle", "frost", "gate"]
const MAIN := {"warrior": "strength", "paladin": "strength", "mage": "intelligence", "cleric": "intelligence", "necromancer": "intelligence", "rogue": "dexterity", "ranger": "dexterity"}
const STARTER := {"ranger": "hunting_bow", "mage": "apprentice_staff", "cleric": "apprentice_staff", "necromancer": "apprentice_staff", "rogue": "worn_dagger", "warrior": "rusty_sword", "paladin": "rusty_sword"}
const CASTERS := ["mage", "cleric", "necromancer"]

var levels := {}
var earned := {}


func before_all() -> void:
	var pacing: Node = autofree(PacingTest.new())
	var run: Dictionary = pacing.model()
	levels = run["arrived"]
	earned = run["earned"]


## What a hero at `mark` can buy: Hilda's shelves at the relics' stage and
## the town's age, and the traders met by then.
func stock_at(mark: String) -> Array:
	var spec: Dictionary = MARKS[mark]
	var stock := {}
	for item_id: String in Economy.shop_stock("smith", Economy.stock_stage(0, int(spec["relics"])), int(spec["tier"])):
		stock[item_id] = true
	for shop_id: String in spec["shops"]:
		for item_id: String in Economy.shop_stock(shop_id, 99, 0):
			stock[item_id] = true
	return stock.keys()


## What `role` would wear of `stock`: the weapon of its stat, armour, and
## trinkets granting its stat, by kind ({weapons, armour, trinkets} ids),
## and the best of each slot as a kit with its price.
func offer(role: String, stock: Array) -> Dictionary:
	var main: String = MAIN[role]
	var kinds := {"weapons": [], "armour": [], "trinkets": []}
	var best := {}
	for item_id: String in stock:
		var item := Catalog.item(item_id)
		if not item.has("slot"):
			continue
		var slot: String = item["slot"]
		var score := 0.0
		if slot == "weapon":
			if String(item.get("scaling", "strength")) != main:
				continue
			kinds["weapons"].append(item_id)
			score = float(item.get("damage", 0))
		elif slot in ["neck", "ring"]:
			if not item.get("grants", {}).has(main):
				continue
			kinds["trinkets"].append(item_id)
			score = float(item["grants"][main])
		else:
			# A caster leaves the heaviest shields to the fighters.
			if role in CASTERS and slot == "offhand" and int(item.get("weight", 0)) > 12:
				continue
			kinds["armour"].append(item_id)
			score = float(item.get("armor", 0)) + 2.0 * float(item.get("grants", {}).get(main, 0))
		if slot == "ring":
			var two: Array = best.get("ring", [])
			two.append([score, item_id])
			two.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			best["ring"] = two.slice(0, 2)
		elif not best.has(slot) or float(best[slot][0]) < score:
			best[slot] = [score, item_id]
	var kit: Array = []
	var cost := 0
	for slot: String in best:
		for pick: Array in (best[slot] if slot == "ring" else [best[slot]]):
			kit.append(pick[1])
			cost += int(Catalog.item(pick[1])["value"])
	if not best.has("weapon"):
		kit.append(STARTER[role])
	return {"kinds": kinds, "kit": kit, "cost": cost}


## A hero of `role` at `level`, points spent (fighters a point a level in
## DEF, the rest in what they hit with), wearing `items`: ids, or [id,
## forged] for a piece forged deep (the Kings' Vault's).
func dressed(role: String, level: int, items: Array) -> Array:
	var hero := HeroState.create("Model", role)
	while hero.level < level:
		hero.xp = hero.xp_to_next
		HeroRules.apply_level_ups(hero)
	for i in level - 1:
		if role in ["warrior", "paladin"]:
			Skills.apply_stat_point(hero, "defense")
			Skills.apply_stat_point(hero, MAIN[role])
			Skills.apply_stat_point(hero, MAIN[role])
		else:
			for j in 3:
				Skills.apply_stat_point(hero, MAIN[role])
	var pack := InventoryState.new()
	var ring := 1
	for worn: Variant in items:
		var item_id: String = worn[0] if worn is Array else worn
		var piece := InventoryState.create_gear(item_id)
		if worn is Array:
			piece["deep"] = int(worn[1])
			piece["deepBonus"] = int(Economy._data()["deepTiers"]["bonus"]) * int(worn[1])
		pack.gear.append(piece)
		var slot: String = Catalog.item(item_id)["slot"]
		if slot == "ring":
			slot = "ring%d" % ring
			ring += 1
		pack.equipped[slot] = piece["uid"]
	return [hero, pack]


## The shops' kit with what the Kings' Vault's first four floors hold for
## the class (PIX-257): its weapon find in place of the bought one, and the
## kings' mail on the third floor, each forged as deep as its floor.
func vault_kit(role: String, kit: Array) -> Array:
	var finds := {"strength": ["obsidian_blade", 1], "dexterity": ["gale_longbow", 1], "intelligence": ["starfall_staff", 2]}
	var out: Array = kit.filter(func(item_id: String) -> bool: return Catalog.item(item_id)["slot"] not in ["weapon", "body"])
	out.append(finds[MAIN[role]])
	out.append(["runic_armor", 2])
	return out


## {swings, bites, margin}: swings to kill `foe`, bites to fall, and how
## many such foes the hero fells from full health.
func fight(kit: Array, foe: Dictionary) -> Dictionary:
	var hero: HeroState = kit[0]
	var pack: InventoryState = kit[1]
	var held := HeroRules.weapon(pack)
	var scaling: String = Catalog.item(held["itemId"]).get("scaling", "strength")
	var hit := Bestiary.through_armor(HeroRules.effective_stat(hero, pack, scaling) + HeroRules.gear_damage(held), int(foe["defense"]))
	if hero.role_id in CASTERS:
		# Every other blow a spell, while the mana lasts.
		var skill: Dictionary = Skills.tree(hero.role_id)[0]["skill"]
		if skill.get("kind", "") == "damage":
			hit = roundi((hit + Bestiary.through_armor(Skills.skill_power(hero, pack, skill), int(foe["defense"]) / 2.0)) / 2.0)
	var bite := Bestiary.through_armor(int(foe["attack"]), HeroRules.total_defense(hero, pack))
	var swings := ceili(float(foe["maxHp"]) / hit)
	var bites := ceili(float(hero.stats["maxHp"]) / bite)
	return {"swings": swings, "bites": bites, "margin": 2.0 * bites / swings}


func _foe(mark: String) -> Dictionary:
	var spec: Array = MARKS[mark]["foe"]
	return Bestiary.spawn(spec[0], false, int(spec[1]))


func test_every_class_has_something_new_to_buy_at_every_chapter() -> void:
	for role: String in MAIN:
		var before := {}
		for mark: String in ORDER:
			var on_sale := offer(role, stock_at(mark))
			for kind: String in ["weapons", "armour", "trinkets"]:
				var fresh: Array = on_sale["kinds"][kind].filter(func(item_id: String) -> bool: return not before.has(item_id))
				assert_false(fresh.is_empty(), "a %s finds new %s at %s" % [role, kind, mark])
			for kind: String in on_sale["kinds"]:
				for item_id: String in on_sale["kinds"][kind]:
					before[item_id] = true


func _line(mark: String, level: int, role: String, on_sale: Dictionary, foe: Dictionary, plain: Array, boss: Dictionary, big: Array) -> String:
	var parts := []
	for pair: Array in [[foe, plain], [boss, big]]:
		var said: Array = []
		for i in pair[1].size():
			said.append("%s %d/%d (%.1f)" % [["starter", "bought", "vault"][i], pair[1][i]["swings"], pair[1][i]["bites"], pair[1][i]["margin"]])
		parts.append("%s: %s" % [pair[0]["name"], " ".join(said)])
	var kinds: Dictionary = on_sale["kinds"]
	return "DRESS %-7s L%-2d %-11s for sale %d/%d/%d, kit %4dg of %5dg earned | %s" % [
		mark, level, role, kinds["weapons"].size(), kinds["armour"].size(), kinds["trinkets"].size(), on_sale["cost"], int(earned.get(mark, 0)), " | ".join(parts)]


## In the Reach: the shops' kit always beats the starter's; from Greyhold on
## a hero in the starter kit can't take a pack of three (margin under 3)
## and one dressed from the shops can; every chapter's boss asks for care
## even then (a margin from 0.6 to 2: dodge its moves, drink a potion), and
## is a wall in the starter kit.
func test_the_reachs_later_foes_and_its_bosses_ask_for_gear() -> void:
	for mark: String in ORDER:
		var level := int(levels[mark])
		for role: String in MAIN:
			var on_sale := offer(role, stock_at(mark))
			var starter := dressed(role, level, [STARTER[role]])
			var bought := dressed(role, level, on_sale["kit"])
			var foe := _foe(mark)
			var boss := Hunts.fighter(MARKS[mark]["boss"])
			var plain := [fight(starter, foe), fight(bought, foe)]
			var big := [fight(starter, boss), fight(bought, boss)]
			gut.p(_line(mark, level, role, on_sale, foe, plain, boss, big))
			assert_gt(float(plain[1]["margin"]), float(plain[0]["margin"]), "%s at %s: the shops' kit beats the starter's" % [role, mark])
			assert_gt(float(big[1]["margin"]), float(big[0]["margin"]), "%s at %s: and against the boss" % [role, mark])
			assert_lte(float(big[0]["margin"]), 1.0, "%s at %s: the boss is a wall in the starter kit" % [role, mark])
			assert_between(float(big[1]["margin"]), 0.6, 2.0, "%s at %s: and a fight in the shops' kit" % [role, mark])
			if mark in ["castle", "frost", "gate"]:
				assert_lte(float(plain[0]["margin"]), 3.0, "%s at %s: a pack is too much in the starter kit" % [role, mark])
				assert_gte(float(plain[1]["margin"]), 3.0, "%s at %s: and not in the shops' kit" % [role, mark])


## Down the Kings' Vault (PIX-257): its foes ask for the shops' best, its
## guardians for the Vault's own finds on top - the Hollow King a fight
## even then, and no fight at all in the shops' kit alone.
func test_the_vault_asks_for_its_own_finds() -> void:
	for mark: String in ["vault_1", "vault_5"]:
		var level := int(levels[mark])
		for role: String in MAIN:
			var on_sale := offer(role, stock_at(mark))
			var kits := [dressed(role, level, [STARTER[role]]), dressed(role, level, on_sale["kit"]), dressed(role, level, vault_kit(role, on_sale["kit"]))]
			var foe := _foe(mark)
			var boss := Hunts.fighter(MARKS[mark]["boss"])
			var plain: Array = kits.map(func(kit: Array) -> Dictionary: return fight(kit, foe))
			var big: Array = kits.map(func(kit: Array) -> Dictionary: return fight(kit, boss))
			gut.p(_line(mark, level, role, on_sale, foe, plain, boss, big))
			assert_gte(float(plain[1]["margin"]), 2.0, "%s at %s: the shops' best holds against a pack's foe" % [role, mark])
			assert_lte(float(plain[0]["margin"]), 2.0, "%s at %s: the starter kit doesn't" % [role, mark])
			assert_gte(float(big[2]["margin"]), float(big[1]["margin"]), "%s at %s: the Vault's finds are no step down from the shops'" % [role, mark])
			assert_between(float(big[2]["margin"]), 0.5, 2.0, "%s at %s: the guardian is a fight in them" % [role, mark])
