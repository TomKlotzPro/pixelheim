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
		"wenna_smugglers", "wenna_tidecaller", "brin_crabs", "brin_lens", "ola_catch", "rook_captain", "pip_fish", "vex_glass", "sela_rum"]},
	{"id": "road", "sweep": [], "hunt": "", "quests": ["ash_orcs", "wren_road", "iva_fever"]},
	{"id": "mines", "sweep": ["mines", "shafts"], "hunt": "seam_warden", "quests": [
		"garrick_crew", "garrick_seam", "dagny_ore", "dagny_carts", "pell_canary", "hildas_ore", "bram_shaftcheese"]},
	{"id": "deepwood", "sweep": ["deepwood"], "hunt": "", "quests": ["troll_toll", "loras_lute", "tomas_golems", "mirelle_caravan", "mira_moss"]},
	{"id": "castle", "sweep": ["castle", "cellars"], "hunt": "hollow_captain", "quests": [
		"ulla_turncoats", "ulla_captain", "teo_rest", "teo_steel", "fenwick_locket", "ana_badge"]},
	{"id": "frost", "sweep": ["frost", "icecave"], "hunt": "rimefang", "quests": [
		"aske_wolves", "aske_rimefang", "gunnar_strongbox", "linnea_lilies", "linnea_icefin", "mira_fur"]},
	{"id": "gate", "sweep": [], "hunt": "", "quests": ["maren_relics"]},
]
## On the climb: the floor a hero is on when each of the rest is handed in,
## and when the hardest wilds (wyverns and imps, the mire's mimic) are swept.
const FLOOR_QUESTS := {"mirelle_ink": 2, "loras_verse": 3, "mirelle_vault": 10, "loras_horn": 12, "bram_imps": 12}
const FLOOR_SWEEPS := {9: ["ash"], 12: ["mire"]}

var maps := {}


func test_the_curve_climbs() -> void:
	assert_eq([HeroState.xp_to_next_for(1), HeroState.xp_to_next_for(2), HeroState.xp_to_next_for(10)], [46, 70, 550])
	for level in range(1, 20):
		assert_gt(HeroState.xp_to_next_for(level + 1), HeroState.xp_to_next_for(level))


func test_a_kill_pays_less_the_further_the_hero_stands_above_it() -> void:
	var orc := Bestiary.spawn("orc")
	assert_eq(Bestiary.xp_for(orc, 1), 30, "a monster above the hero pays in full")
	assert_eq(Bestiary.xp_for(orc, 5), 30, "so does a match")
	assert_eq(Bestiary.xp_for(orc, 7), 21, "two levels above: 30% less")
	assert_eq(Bestiary.xp_for(orc, 20), 3, "never under a tenth")


func test_the_wilds_pay_xp_more_thinly_than_gold() -> void:
	var wolf := Bestiary.wild(Bestiary.spawn("wolf"))
	assert_eq([wolf["xp"], wolf["gold"]], [8, 9])


func test_a_first_clear_pays_xp_once() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.progression.unlocked_level = 3
	var lines: Array = state.clear_floor(3)["lines"]
	assert_eq(state.hero.xp, Dungeons.clear_xp(3))
	assert_true("+36 XP for the way down." in lines)
	state.clear_floor(3)
	assert_eq(state.hero.xp, 36, "a replay pays only its fights")


func test_the_level_up_line_counts_what_there_is_to_spend() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.hero.level = 4
	state.hero.xp_to_next = HeroState.xp_to_next_for(4)
	assert_eq(state.earn_xp(1), "")
	var line: String = state.earn_xp(state.hero.xp_to_next)
	assert_eq(line, "LEVEL UP! You are now level 5. +3 stat points and +2 skill points to spend.")


func test_skill_tiers_open_with_levels() -> void:
	var hero := HeroState.create("L", "warrior")
	hero.skill_points = 3
	var tree := Skills.tree("warrior")
	var by_tier := {}
	for entry: Dictionary in tree:
		by_tier[int(entry["tier"])] = entry
	assert_eq([0, 1, 2, 3].map(func(tier: int) -> int: return Skills.tier_level(by_tier[tier])), [1, 3, 6, 10])
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


## One kill of every foe in every pack of a region, where the world puts them.
func _sweep(hero: HeroState, region_id: String) -> void:
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if not maps.has(spawn["mapId"]):
			maps[spawn["mapId"]] = MapData.load_by_id(spawn["mapId"])
		var map: MapData = maps[spawn["mapId"]]
		var home := Vector2i(spawn["x"], spawn["y"])
		if map.region_at(home) != region_id:
			continue
		for i in int(spawn.get("size", PACK)):
			_earn(hero, Bestiary.xp_for(Bestiary.wild(Bestiary.spawn(Bestiary.species_of(spawn, region_id))), hero.level))


func _earn(hero: HeroState, xp: int) -> void:
	hero.xp += xp
	HeroRules.apply_level_ups(hero)
