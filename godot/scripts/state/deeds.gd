class_name Deeds
## Deeds (PIX-219): long goals for a hero who has done the rest, read off
## what the save already knows - every bounty, every family's mastery, a
## whole set worn, the whole bestiary met, every letter delivered, every
## settler home. Each one done stays done (ProgressionState.deeds) and
## brings a medal home for the trophy shelf. (Ten Below and Thirty Below,
## the Deep Hunt's, left with the old saves that could hold them, PIX-319.)
## Pure, over progression.json's "deeds".


static func all() -> Array:
	return Quests._data()["deeds"]


## Whether `deed` is done for this hero now.
static func met(deed: Dictionary, hero: HeroState, pack: InventoryState, progression: ProgressionState, settlement: SettlementState = null) -> bool:
	var counted := count(deed, hero, pack, progression, settlement)
	return counted[0] >= counted[1]


## How far along a deed is: [have, need].
static func count(deed: Dictionary, hero: HeroState, pack: InventoryState, progression: ProgressionState, settlement: SettlementState = null) -> Array:
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
			var kinds: Array = Bestiary._data()["monsters"].keys()
			return [kinds.filter(func(kind: String) -> bool: return progression.met.has(kind)).size(), kinds.size()]
		"letters":
			# Every one of Maren's letters handed over (PIX-257): the main
			# story's delivery steps met (a keepsake already won counts).
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
