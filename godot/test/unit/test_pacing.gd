extends GutTest
## XP pacing (PIX-141; the mountain last, PIX-170; the story's end and the
## Kings' Vault, PIX-257 with PIX-294): levels come from going on, not from
## farming what is already beaten. A hero who does the town's errands and
## sweeps each wild region once, takes the Reach's four chapters in turn
## (their packs, their quests, their chapter boss), brings the relics home,
## walks the Mirefen and the mountain road, holds the square on the Night of
## Bells and then goes down the Kings' Vault floor by floor (each floor's
## packs and its guardian) stands near level 4 on the road to Saltmere,
## near 12 at the mountain's gate, near 14 on the Night of Bells and climbs
## from 15 to about 19 down the Vault, each guardian about their match.
## Tom's playtest (PIX-294: « le perso va vite en niveau ») asked for fewer
## levels early: the Reach's first chapters pay less XP than they did, the
## last ones and the Vault more.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## Foes in a wild pack (world.gd PACK_SIZE).
const PACK := 3
## The story in the order a hero takes it: the wild regions swept there, the
## quests handed in and the chapter boss laid low; a Vault floor's packs and
## guardian (`floor`).
const STAGES := [
	{"id": "town", "sweep": ["forest", "marsh"], "hunt": "", "quests": [
		"slime_trouble", "cheese_run", "herbs_for_vex", "hildas_buckler", "wren_leather", "iva_reeds", "wren_apples", "iva_herbs", "wolf_watch"]},
	{"id": "coast", "sweep": ["coast", "seacave"], "hunt": "tidecaller", "quests": [
		"letter_wenna", "wenna_smugglers", "wenna_tidecaller", "brin_crabs", "brin_lens", "brin_oilskin", "ola_catch", "rook_captain", "pip_fish", "vex_glass", "sela_rum"]},
	{"id": "road", "sweep": [], "packs": ["ash_1", "ash_2"], "hunt": "", "quests": ["ash_orcs", "wren_road", "iva_fever"]},
	{"id": "mines", "sweep": ["mines", "shafts"], "hunt": "seam_warden", "quests": [
		"letter_pell", "garrick_crew", "garrick_seam", "garrick_helm", "dagny_ore", "dagny_carts", "pell_canary", "hildas_ore", "bram_shaftcheese"]},
	{"id": "deepwood", "sweep": ["deepwood"], "hunt": "", "quests": ["loras_lute", "tomas_golems", "mira_moss"]},
	{"id": "castle", "sweep": ["castle", "cellars"], "hunt": "hollow_captain", "quests": [
		"letter_hale", "ulla_turncoats", "ulla_captain", "teo_rest", "teo_steel", "fenwick_locket", "ana_badge"]},
	{"id": "frost", "sweep": ["frost", "icecave"], "hunt": "rimefang", "quests": [
		"letter_aske", "aske_wolves", "aske_rimefang", "gunnar_strongbox", "gunnar_wagon", "linnea_lilies", "linnea_icefin", "linnea_hood", "mira_fur"]},
	# The four keepsakes home: Maren's turn-in, and Mirelle's asks that wait
	# on the relics (the vault's gems, the Deepwood's trolls).
	{"id": "gate", "sweep": [], "hunt": "", "quests": ["maren_relics", "mirelle_vault", "mirelle_ink", "mirelle_caravan"]},
	# Before the fifth letter, what's left of the Reach: the Ash's wyverns,
	# the Mirefen (Gulp is posted at the Town), Loras's verse and horn.
	{"id": "mire", "sweep": ["ash", "mire"], "hunt": "", "quests": ["loras_verse", "loras_horn"]},
	# The fifth letter (PIX-253 step 8): up the mountain road to Morvax, and
	# Maren's next ask after it, the Deepwood's troll.
	{"id": "mountain", "sweep": ["road"], "hunt": "", "quests": ["letter_morvax", "troll_toll"]},
	# The Night of Bells (step 9): the embers on the square (Bram's imps) and
	# Fafnyr held till dawn, his stand-down paid as a fall.
	{"id": "bells", "night": true, "sweep": [], "hunt": "", "quests": ["bram_imps"]},
	# The Kings' Vault after it (PIX-257), floor by floor.
	{"id": "vault_1", "floor": "vault_1", "sweep": [], "hunt": "hollowmother", "quests": []},
	{"id": "vault_2", "floor": "vault_2", "sweep": [], "hunt": "grimshade", "quests": []},
	{"id": "vault_3", "floor": "vault_3", "sweep": [], "hunt": "bone_abbot", "quests": []},
	{"id": "vault_4", "floor": "vault_4", "sweep": [], "hunt": "ironheart", "quests": []},
	{"id": "vault_5", "floor": "vault_5", "sweep": [], "hunt": "hollow_king", "quests": []},
]

var maps := {}
## The packs already felled (a chapter's, before its region is swept).
var felled := {}
## The gold the model has earned so far: its kills', quests' and bounties'.
var gold := 0


func test_the_curve_climbs() -> void:
	assert_eq([HeroState.xp_to_next_for(1), HeroState.xp_to_next_for(2), HeroState.xp_to_next_for(10)], [46, 70, 550])
	for level in range(1, 20):
		assert_gt(HeroState.xp_to_next_for(level + 1), HeroState.xp_to_next_for(level))


func test_a_kill_pays_less_the_further_the_hero_stands_above_it() -> void:
	var orc := Bestiary.spawn("orc")
	assert_eq(Bestiary.xp_for(orc, 1), 36, "a monster four levels above the hero pays a fifth more (PIX-189)")
	assert_eq(Bestiary.xp_for(orc, 4), 32, "one level above: 5% more")
	assert_eq(Bestiary.xp_for(Bestiary.spawn("imp"), 1), roundi(Bestiary.spawn("imp")["xp"] * 1.25), "never over a quarter more")
	assert_eq(Bestiary.xp_for(orc, 5), 30, "so does a match")
	assert_eq(Bestiary.xp_for(orc, 7), 21, "two levels above: 30% less")
	assert_eq(Bestiary.xp_for(orc, 20), 3, "never under a tenth")


## A quarter of a kill's XP in the fields (PIX-294: a third before, and the
## levels came too fast), two thirds of its gold.
func test_the_wilds_pay_xp_more_thinly_than_gold() -> void:
	var wolf := Bestiary.wild(Bestiary.spawn("wolf"))
	assert_eq([wolf["xp"], wolf["gold"]], [6, 9])
	assert_eq(Bestiary.wild(Bestiary.spawn("wolf"), "forest")["xp"], 6, "the fields pay the wilds' share")


## PIX-189: the Reach's chapters and their caves pay more XP than the fields;
## PIX-294: the first ones less than the last ones (Saltmere 0.3, the
## Frostgate 0.4: the early levels came too fast), the mountain road a
## whole kill's, and the Kings' Vault more than any chapter.
func test_the_chapters_pay_more_xp_than_the_fields() -> void:
	var crab := Bestiary.spawn("crab")
	assert_eq(Bestiary.wild(crab.duplicate(), "seacave")["gold"], Bestiary.wild(crab.duplicate(), "forest")["gold"], "gold is the wilds' everywhere")
	var fields := float(Bestiary._data()["wildXpMult"])
	var shares := {}
	for region_id in ["coast", "seacave", "mines", "shafts", "castle", "cellars", "frost", "icecave", "vault"]:
		shares[region_id] = float(Bestiary.region(region_id).get("wildXp", 0))
		assert_gt(shares[region_id], fields, region_id)
	assert_lt(shares["coast"], shares["frost"], "Saltmere pays less than the Frostgate")
	assert_lt(shares["mines"], shares["icecave"])
	for region_id: String in shares:
		if region_id != "vault":
			assert_gt(shares["vault"], shares[region_id], "the Vault pays more than %s" % region_id)


func test_the_level_up_line_counts_what_there_is_to_spend() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.hero.level = 4
	state.hero.xp_to_next = HeroState.xp_to_next_for(4)
	assert_eq(state.spoils.earn_xp(1), "")
	var line: String = state.spoils.earn_xp(state.hero.xp_to_next)
	assert_eq(line, "Level up: you are now level 5. +3 stat points and +2 skill points to spend.")


func test_skill_tiers_open_with_levels() -> void:
	var hero := HeroState.create("L", "warrior")
	hero.skill_points = 3
	var tree := Skills.tree("warrior")
	var by_tier := {}
	for entry: Dictionary in tree:
		by_tier[int(entry["tier"])] = entry
	assert_eq([0, 1, 2, 3].map(func(tier: int) -> int: return Skills.tier_level(by_tier[tier])), [1, 3, 6, 9])
	var second: Dictionary = Skills.node("warrior", "warrior_power_strike_2")
	assert_false(Skills.can_buy(hero, second), "tier 2 waits for level 3")
	hero.level = 3
	assert_true(Skills.can_buy(hero, second))


## The levels the model reaches: {stage id: level on arriving} ("bells"
## once the mountain road is walked), "end" once the Vault's last guardian
## is down, and each guardian's level and the hero's arriving at it; and
## the gold earned by each stage's arrival (`earned`, PIX-294).
func model() -> Dictionary:
	felled = {}
	gold = 0
	var hero := HeroState.create("Pace", "warrior")
	var arrived := {}
	var earned := {}
	var guardians := {}
	for stage: Dictionary in STAGES:
		arrived[stage["id"]] = hero.level
		earned[stage["id"]] = gold
		for region_id: String in stage["sweep"]:
			_sweep(hero, region_id)
		for spawn_id: String in stage.get("packs", []):
			_sweep(hero, "", spawn_id)
		if stage.has("floor"):
			_sweep_floor(hero, stage["floor"])
		if stage.get("night", false):
			_hold_the_square(hero)
		for quest_id: String in stage["quests"]:
			_earn(hero, int(Quests.by_id(quest_id)["reward"]["xp"]))
			gold += int(Quests.by_id(quest_id)["reward"].get("gold", 0))
		if stage["hunt"] != "":
			var fighter := Hunts.fighter(stage["hunt"])
			gold += int(fighter["gold"])
			if stage.has("floor"):
				guardians[stage["id"]] = [int(fighter["level"]), hero.level]
			_earn(hero, Bestiary.xp_for(fighter, hero.level))
	arrived["end"] = hero.level
	earned["end"] = gold
	return {"arrived": arrived, "guardians": guardians, "earned": earned}


func test_the_story_then_the_vault_levels_the_hero_on_pace() -> void:
	var modelled: Array[String] = []
	var swept: Array[String] = []
	for stage: Dictionary in STAGES:
		modelled.append_array(stage["quests"])
		swept.append_array(stage["sweep"])
	swept.append("vault")
	var every: Array = Quests.all().map(func(quest: Dictionary) -> String: return quest["id"])
	every.sort()
	modelled.sort()
	assert_eq(modelled, every, "every quest is in the model once")
	var regions: Array = Bestiary._data()["regions"].keys()
	regions.sort()
	swept.sort()
	assert_eq(swept, regions, "every region is swept once (the Vault's a floor at a time)")
	var run := model()
	var arrived: Dictionary = run["arrived"]
	gut.p("level on arriving: %s" % arrived)
	gut.p("gold earned by then: %s" % run["earned"])
	gut.p("guardians [level, the hero's]: %s" % run["guardians"])
	assert_between(int(arrived["coast"]), 3, 5, "about level 4 on the road to Saltmere")
	assert_lt(int(arrived["mines"]), int(arrived["castle"]), "each chapter a step up")
	assert_lt(int(arrived["castle"]), int(arrived["gate"]))
	assert_between(int(arrived["gate"]), 11, 13, "about level 12 at the gate")
	assert_between(int(arrived["bells"]), 13, 15, "about level 14 on the Night of Bells")
	assert_between(int(arrived["vault_1"]), 13, 16, "about 15 into the Vault")
	assert_between(int(arrived["end"]), 18, 20, "about 19 up out of it")
	for floor_id: String in run["guardians"]:
		var guardian: Array = run["guardians"][floor_id]
		assert_between(int(guardian[0]) - int(guardian[1]), 0, 4, "%s's guardian stands a little above the hero" % floor_id)


## The Kings' Vault's foes stand above their kind, each floor harder than
## the one over it (PIX-257).
func test_the_vaults_foes_stand_above_their_kind() -> void:
	var bone := Bestiary.spawn("boneknight", false, Depths.lift("vault_1"))
	assert_eq(int(bone["level"]), 11 + Depths.lift("vault_1"))
	assert_gt(int(bone["maxHp"]), int(Bestiary.monster("boneknight")["maxHp"]))
	assert_false(Bestiary.spawn("boneknight").has("level"), "a bone knight unlifted is its kind")
	for i in range(2, 6):
		assert_gt(Depths.foe_level("vault_%d" % i), Depths.foe_level("vault_%d" % (i - 1)), "floor %d is harder than the one above" % i)


## One kill of every foe in every pack of a region (or the one pack
## `spawn_id`), where the world puts them, but for packs already felled.
func _sweep(hero: HeroState, region_id: String, spawn_id := "") -> void:
	for spawn: Dictionary in _packs(region_id, spawn_id):
		_fell(hero, spawn)


## The Night of Bells' fights (PIX-253 step 9): the embers on the square,
## at the night's level, and Fafnyr, his stand-down paid as a fall.
func _hold_the_square(hero: HeroState) -> void:
	var embers: Dictionary = Bells.data()["embers"]
	var kind := String(embers["monsterId"])
	for cell: Array in embers["cells"]:
		_earn(hero, Bestiary.xp_for(Bestiary.spawn(kind, false, int(embers["level"]) - int(Bestiary.monster(kind)["level"])), hero.level))
	_earn(hero, Bestiary.xp_for(Bells.fafnyr(), hero.level))


## Every pack on a Vault floor, lifted as the floor lifts them.
func _sweep_floor(hero: HeroState, map_id: String) -> void:
	for spawn: Dictionary in Bestiary.spawns_on(map_id):
		_fell(hero, spawn, Depths.lift(map_id))


func _fell(hero: HeroState, spawn: Dictionary, lift := 0) -> void:
	if felled.has(spawn["id"]):
		return
	felled[spawn["id"]] = true
	var here: String = _region_of(spawn)
	for i in int(spawn.get("size", PACK)):
		var foe := Bestiary.wild(Bestiary.spawn(Bestiary.species_of(spawn, here), false, lift), here)
		_earn(hero, Bestiary.xp_for(foe, hero.level))
		gold += int(foe["gold"])


## The packs of a region, or the one named. The model sweeps by day: the
## packs that come out only after dark (PIX-252) are a night-goer's extra.
func _packs(region_id: String, spawn_id := "") -> Array:
	return Bestiary._data()["spawns"].filter(func(spawn: Dictionary) -> bool:
		if Packs.of_the_night(spawn):
			return false
		return spawn["id"] == spawn_id if spawn_id != "" else _region_of(spawn) == region_id)


func _region_of(spawn: Dictionary) -> String:
	if not maps.has(spawn["mapId"]):
		maps[spawn["mapId"]] = MapData.load_by_id(spawn["mapId"])
	return maps[spawn["mapId"]].region_at(Vector2i(spawn["x"], spawn["y"]))


func _earn(hero: HeroState, xp: int) -> void:
	hero.xp += xp
	HeroRules.apply_level_ups(hero)


## Where in the model a quest is handed in: its stage's index.
func _stage_of(quest_id: String) -> int:
	for i in STAGES.size():
		if quest_id in STAGES[i]["quests"]:
			return i
	return -1


## PIX-189: a giver offers the next quest only once the last is done, and a
## quest that opens after another waits for it - the model can't hand one in
## before the one it waits on.
func test_the_model_follows_each_givers_order() -> void:
	var by_giver := {}
	for quest: Dictionary in Quests.all():
		var stage := _stage_of(quest["id"])
		var before: Dictionary = by_giver.get(quest["giver"], {})
		if not before.is_empty():
			assert_true(stage >= int(before["stage"]), "%s comes after %s" % [quest["id"], before["id"]])
		by_giver[quest["giver"]] = {"id": quest["id"], "stage": stage}
		var after: String = quest.get("opensAfter", "")
		if Quests.by_id(after).size() > 0:
			assert_true(stage >= _stage_of(after), "%s opens after %s" % [quest["id"], after])


## And a kill quest is handed in where its quarry has been met: in a region
## swept by then, on the Night of Bells' square, or on a Vault floor walked.
func test_the_model_hands_in_a_kill_where_its_foe_lives() -> void:
	var met := {}
	for i in STAGES.size():
		var packs := []
		for region_id: String in STAGES[i]["sweep"]:
			packs.append_array(_packs(region_id))
		for spawn_id: String in STAGES[i].get("packs", []):
			packs.append_array(_packs("", spawn_id))
		if STAGES[i].has("floor"):
			packs.append_array(Bestiary.spawns_on(STAGES[i]["floor"]))
		for spawn: Dictionary in packs:
			met[Bestiary.species_of(spawn, _region_of(spawn))] = true
		if STAGES[i].get("night", false):
			met[String(Bells.data()["embers"]["monsterId"])] = true
		for quest: Dictionary in Quests.all():
			if quest["objective"]["kind"] == "kill" and _stage_of(quest["id"]) == i:
				assert_true(met.has(quest["objective"]["monsterId"]), "%s's %s is met by then" % [quest["id"], quest["objective"]["monsterId"]])
