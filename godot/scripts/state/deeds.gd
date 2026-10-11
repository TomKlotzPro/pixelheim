class_name Deeds
## Deeds (PIX-219): long goals for a hero who has done the rest, read off
## what the save already knows - every bounty, every family's mastery, a
## whole set worn, the whole bestiary met, every letter delivered, every
## settler home. Each one done stays done (ProgressionState.deeds) and
## brings a medal home for the trophy shelf. A deed `retired` from play
## (Ten Below and Thirty Below: the Deep Hunt left with PIX-257) is never
## earned again, but shows, medal and all, for a hero who earned it. Pure,
## over progression.json's "deeds".


static func all() -> Array:
	return Quests._data()["deeds"]


## The deeds still to be earned: every one but the retired.
static func in_play() -> Array:
	return all().filter(func(deed: Dictionary) -> bool: return not deed.get("retired", false))


## The deeds the journal shows this hero: those in play, and a retired one
## they earned before it left.
static func shown(progression: ProgressionState) -> Array:
	return all().filter(func(deed: Dictionary) -> bool: return not deed.get("retired", false) or deed["id"] in progression.deeds)


## Whether `deed` is done for this hero now.
static func met(deed: Dictionary, hero: HeroState, pack: InventoryState, progression: ProgressionState, settlement: SettlementState = null) -> bool:
	var counted := count(deed, hero, pack, progression, settlement)
	return counted[0] >= counted[1]


## How far along a deed is: [have, need]. A retired one counts as done
## once earned, else as nothing to do.
static func count(deed: Dictionary, hero: HeroState, pack: InventoryState, progression: ProgressionState, settlement: SettlementState = null) -> Array:
	if deed.get("retired", false):
		return [1, 1] if deed["id"] in progression.deeds else [0, 1]
	match String(deed["kind"]):
		"hunts":
			var named := Hunts.all()
			return [named.filter(func(entry: Dictionary) -> bool: return entry["id"] in progression.hunted).size(), named.size()]
		"masteries":
			var families: Array = Bestiary._data()["familyNames"].keys()
			var top: int = Bestiary._data()["masteryTiers"].size()
			return [families.filter(func(family: String) -> bool: return Bestiary.mastery_tier(hero.mastery, family) >= top).size(), families.size()]
		"set":
			# The most of any one set worn, against that set's whole.
			var best := [0, 1]
			var worn := pack.set_counts()
			for set_id: String in Catalog._data()["sets"]:
				var whole: int = Catalog._data()["sets"][set_id]["pieces"].size()
				var have := int(worn.get(set_id, 0))
				if float(have) / whole > float(best[0]) / best[1]:
					best = [have, whole]
			if best[0] == 0:
				best = [0, Catalog._data()["sets"].values()[0]["pieces"].size()]
			return best
		"bestiary":
			# A kind no longer met anywhere (Morvax, who is no foe now:
			# combat.json's `retired`) counts only once it was met.
			var kinds: Array = Bestiary._data()["monsters"].keys().filter(func(kind: String) -> bool:
				return not Bestiary.monster(kind).get("retired", false) or progression.met.has(kind))
			return [kinds.filter(func(kind: String) -> bool: return progression.met.has(kind)).size(), kinds.size()]
		"letters":
			# Every one of Maren's letters handed over (PIX-257): the main
			# story's delivery steps met, an old save's own way too (a
			# keepsake already won, Morvax already cast down).
			var steps := MainQuest.steps().filter(func(step: Dictionary) -> bool: return step["when"]["kind"] == "delivered")
			var empty := SettlementState.new() if settlement == null else settlement
			return [steps.filter(func(step: Dictionary) -> bool: return MainQuest.is_met(step, progression, empty)).size(), steps.size()]
		"settlers":
			# Every settler home (PIX-257): the four the Reach's errands
			# bring and the families the letters bring.
			var recruits: Array = Npcs._data()["recruits"].map(func(recruit: Dictionary) -> String: return recruit["id"])
			var home: Array = settlement.settlers if settlement != null else []
			return [recruits.filter(func(id: String) -> bool: return id in home).size(), recruits.size()]
	return [0, 1]
