extends GutTest
## XP pacing (PIX-141; rewritten for the mountain last, PIX-170): levels come
## from going on, not from farming what is already beaten. A hero who does
## the town's errands and sweeps each wild region once, takes the Reach's four
## chapters in turn (their packs, their quests, their chapter boss), brings
## the relics home and then climbs - each floor cleared once, the floors'
## quests handed in - stands near level 5 on the road to Saltmere, near 12 at
## the gate and near 18 at the Throne of the Deathless, every floor's
## guardian about their match.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## Foes in a wild pack (world.gd PACK_SIZE).
const PACK := 3
## The Reach in the order a hero takes it: the wild regions swept there, the
## quests handed in and the chapter boss laid low.
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
	{"id": "gate", "sweep": [], "hunt": "", "quests": ["maren_relics"]},
]
## On the climb: the floor a hero is on when each of the rest is handed in,
## and when the hardest wilds (wyverns and imps, the mire's mimic) are swept.
## A giver's quests come one after another (PIX-189): Maren's troll waits for
## the relics, Mirelle's ink and caravan for her vault's two gems (floors 2
## and 4 hold them), Loras's verse for a wyvern (floor 9 and the Ash), Bram's
## imps for the floors that hold them. On the road the Ash's two orc packs
## fall (Ana's and Wren's raiders); its wyverns wait for the climb.
const FLOOR_QUESTS := {"mirelle_vault": 4, "mirelle_ink": 4, "troll_toll": 8, "mirelle_caravan": 8, "loras_verse": 9, "loras_horn": 12, "bram_imps": 14}
const FLOOR_SWEEPS := {9: ["ash"], 12: ["mire"]}

var maps := {}
## The packs already felled (a chapter's, before its region is swept).
var felled := {}


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


func test_the_wilds_pay_xp_more_thinly_than_gold() -> void:
	var wolf := Bestiary.wild(Bestiary.spawn("wolf"))
	assert_eq([wolf["xp"], wolf["gold"]], [8, 9])
	assert_eq(Bestiary.wild(Bestiary.spawn("wolf"), "forest")["xp"], 8, "the fields pay the wilds' share")


## PIX-189: the Reach's chapters and their caves pay more XP than the fields
## (half a kill's, not a third: 0.7 put the hero two levels past the Throne).
func test_the_chapters_pay_more_xp_than_the_fields() -> void:
	var crab := Bestiary.spawn("crab")
	assert_eq(Bestiary.wild(crab.duplicate(), "seacave")["xp"], roundi(crab["xp"] * 0.5))
	assert_eq(Bestiary.wild(crab.duplicate(), "seacave")["gold"], Bestiary.wild(crab.duplicate(), "forest")["gold"], "gold is the wilds' everywhere")
	for region_id in ["coast", "seacave", "mines", "shafts", "castle", "cellars", "frost", "icecave"]:
		assert_eq(float(Bestiary.region(region_id).get("wildXp", 0)), 0.5, region_id)


func test_a_first_clear_pays_xp_once() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.progression.unlocked_level = 3
	var gains: Dictionary = state.spoils.clear_floor(3)["gains"]
	assert_eq(state.hero.xp, Dungeons.clear_xp(3))
	# The way down's XP floats up with the hoard (PIX-245).
	assert_eq(int(gains["xp"]), 36)
	assert_true(Gains.is_empty(state.spoils.clear_floor(3)["gains"]), "a replay has no hoard")
	assert_eq(state.hero.xp, 36, "a replay pays only its fights")


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


func test_the_reach_then_the_mountain_levels_the_hero_on_pace() -> void:
	var hero := HeroState.create("Pace", "warrior")
	var modelled: Array[String] = []
	var swept: Array[String] = []
	for stage: Dictionary in STAGES:
		modelled.append_array(stage["quests"])
		swept.append_array(stage["sweep"])
	modelled.append_array(FLOOR_QUESTS.keys())
	for regions: Array in FLOOR_SWEEPS.values():
		swept.append_array(regions)
	var every: Array = Quests.all().map(func(quest: Dictionary) -> String: return quest["id"])
	every.sort()
	modelled.sort()
	assert_eq(modelled, every, "every quest is in the model once")
	var regions: Array = Bestiary._data()["regions"].keys()
	regions.sort()
	swept.sort()
	assert_eq(swept, regions, "every region is swept once")
	var arrived := {}
	for stage: Dictionary in STAGES:
		arrived[stage["id"]] = hero.level
		for region_id: String in stage["sweep"]:
			_sweep(hero, region_id)
		for spawn_id: String in stage.get("packs", []):
			_sweep(hero, "", spawn_id)
		for quest_id: String in stage["quests"]:
			_earn(hero, int(Quests.by_id(quest_id)["reward"]["xp"]))
		if stage["hunt"] != "":
			_earn(hero, Bestiary.xp_for(Hunts.fighter(stage["hunt"]), hero.level))
	var guardians := {}
	for level in range(1, Dungeons.floor_count() + 1):
		for region_id: String in FLOOR_SWEEPS.get(level, []):
			_sweep(hero, region_id)
		arrived[level] = hero.level
		for encounter: Dictionary in Dungeons.floor_def(level)["encounters"]:
			var foe := Bestiary.spawn(encounter["monsterId"], encounter.get("elite", false), Dungeons.lift(level))
			guardians[level] = int(foe["level"])
			_earn(hero, Bestiary.xp_for(foe, hero.level))
		_earn(hero, Dungeons.clear_xp(level))
		for quest_id: String in FLOOR_QUESTS:
			if FLOOR_QUESTS[quest_id] == level:
				_earn(hero, int(Quests.by_id(quest_id)["reward"]["xp"]))
	gut.p("level on arriving: %s" % arrived)
	assert_between(int(arrived["coast"]), 4, 6, "about level 5 on the road to Saltmere")
	assert_lt(int(arrived["mines"]), int(arrived["castle"]), "each chapter a step up")
	assert_lt(int(arrived["castle"]), int(arrived["gate"]))
	assert_between(int(arrived["gate"]), 11, 13, "about level 12 at the gate")
	assert_between(int(arrived[10]), 15, 17, "about level 16 at the Ashen Throne")
	assert_between(int(arrived[15]), 17, 19, "about level 18 at the Throne of the Deathless")
	for level: int in guardians:
		assert_between(int(arrived[level]) - int(guardians[level]), -2, 2, "floor %d's guardian is about the hero's match" % level)


func test_a_floors_foes_stand_above_their_kind() -> void:
	var slime := Bestiary.spawn("slime", false, Dungeons.lift(1))
	assert_eq(int(slime["level"]), 1 + Dungeons.lift(1))
	assert_gt(int(slime["maxHp"]), 100, "the cellar's slimes are no field slimes")
	assert_gt(int(slime["xp"]), 50)
	assert_false(Bestiary.spawn("slime").has("level"), "a field slime is its kind")
	# The deepest floors lift least: Morvax is near his own strength.
	assert_lt(Dungeons.lift(15), Dungeons.lift(1))
	assert_eq(Dungeons.drop_floor(1), mini(1 + Dungeons.lift(1), Dungeons.floor_count()), "the mountain drops the mountain's loot")


## One kill of every foe in every pack of a region (or the one pack
## `spawn_id`), where the world puts them, but for packs already felled.
func _sweep(hero: HeroState, region_id: String, spawn_id := "") -> void:
	for spawn: Dictionary in _packs(region_id, spawn_id):
		if felled.has(spawn["id"]):
			continue
		felled[spawn["id"]] = true
		var here: String = _region_of(spawn)
		for i in int(spawn.get("size", PACK)):
			_earn(hero, Bestiary.xp_for(Bestiary.wild(Bestiary.spawn(Bestiary.species_of(spawn, here)), here), hero.level))


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


## Where in the model a quest is handed in: a chapter's index, or the floor's
## after the last chapter.
func _stage_of(quest_id: String) -> int:
	for i in STAGES.size():
		if quest_id in STAGES[i]["quests"]:
			return i
	return STAGES.size() + int(FLOOR_QUESTS[quest_id]) - 1


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
## swept by then, or on a floor climbed.
func test_the_model_hands_in_a_kill_where_its_foe_lives() -> void:
	var met := {}
	for i in STAGES.size() + Dungeons.floor_count():
		var packs := []
		for region_id: String in STAGES[i]["sweep"] if i < STAGES.size() else FLOOR_SWEEPS.get(i - STAGES.size() + 1, []):
			packs.append_array(_packs(region_id))
		for spawn_id: String in STAGES[i].get("packs", []) if i < STAGES.size() else []:
			packs.append_array(_packs("", spawn_id))
		for spawn: Dictionary in packs:
			met[Bestiary.species_of(spawn, _region_of(spawn))] = true
		if i >= STAGES.size():
			for encounter: Dictionary in Dungeons.floor_def(i - STAGES.size() + 1)["encounters"]:
				met[encounter["monsterId"]] = true
		for quest: Dictionary in Quests.all():
			if quest["objective"]["kind"] == "kill" and _stage_of(quest["id"]) == i:
				assert_true(met.has(quest["objective"]["monsterId"]), "%s's %s is met by then" % [quest["id"], quest["objective"]["monsterId"]])
