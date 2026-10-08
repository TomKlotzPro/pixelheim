extends GutTest
## XP pacing (PIX-141): levels come from going deeper, not from farming what
## is already beaten. A hero who clears each floor once, does the quests and
## sweeps each wild region once on reaching it stands near level 10 at the
## Ashen Throne and near 14 at the Throne of the Deathless.

const GameStateScript := preload("res://scripts/state/game_state.gd")
## Foes in a wild pack (world.gd PACK_SIZE).
const PACK := 3
## The floor a hero is on when each quest is handed in.
const QUEST_FLOORS := {"slime_trouble": 1, "cheese_run": 1, "wolf_watch": 4, "herbs_for_vex": 2, "hildas_buckler": 4, "troll_toll": 8, "iva_reeds": 4, "wren_leather": 2, "loras_lute": 8, "mirelle_vault": 10, "ash_orcs": 6, "bram_imps": 12, "mira_moss": 11, "tomas_golems": 10, "iva_herbs": 5, "iva_fever": 7, "wren_apples": 3, "wren_road": 6, "loras_verse": 9, "loras_horn": 12, "mirelle_ink": 10, "mirelle_caravan": 11}

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


func test_going_deeper_levels_the_hero_on_pace() -> void:
	var hero := HeroState.create("Pace", "warrior")
	var quests := {}
	for quest: Dictionary in Quests.all():
		quests[quest["id"]] = int(quest["reward"]["xp"])
	assert_eq(quests.keys().size(), QUEST_FLOORS.size(), "every quest has a floor in the model")
	var arrived := {}
	for level in range(1, Dungeons.floor_count() + 1):
		for region_id: String in Bestiary._data()["regions"]:
			if int(Bestiary.region(region_id)["dropFloor"]) == level:
				_sweep(hero, region_id)
		arrived[level] = hero.level
		for encounter: Dictionary in Dungeons.floor_def(level)["encounters"]:
			_earn(hero, Bestiary.xp_for(Bestiary.spawn(encounter["monsterId"], encounter.get("elite", false)), hero.level))
		_earn(hero, Dungeons.clear_xp(level))
		for quest_id: String in QUEST_FLOORS:
			if QUEST_FLOORS[quest_id] == level:
				_earn(hero, quests[quest_id])
	gut.p("level on arriving at each floor: %s" % arrived)
	assert_between(int(arrived[10]), 9, 11, "about level 10 at the Ashen Throne")
	assert_between(int(arrived[15]), 13, 15, "about level 14 at the Throne of the Deathless")
	assert_lt(int(arrived[5]), 7, "no runaway start")


## One kill of every foe in every pack of a region, where the world puts them.
func _sweep(hero: HeroState, region_id: String) -> void:
	for spawn: Dictionary in Bestiary._data()["spawns"]:
		if not maps.has(spawn["mapId"]):
			maps[spawn["mapId"]] = MapData.load_by_id(spawn["mapId"])
		var map: MapData = maps[spawn["mapId"]]
		var home := Vector2i(spawn["x"], spawn["y"])
		if map.region_at(home) != region_id:
			continue
		for i in PACK:
			_earn(hero, Bestiary.xp_for(Bestiary.wild(Bestiary.spawn(Bestiary.species_of(spawn, region_id))), hero.level))


func _earn(hero: HeroState, xp: int) -> void:
	hero.xp += xp
	HeroRules.apply_level_ups(hero)
