extends GutTest
## The Night of Bells (PIX-253 step 9, chapter 7): home after the run, the
## night plays its beats in order - the five lanterns, the embers and the
## roofs, Fafnyr held on the square until the sky turns - with each of the
## townsfolk at a job only where that one lives in Pixelheim; at dawn, or
## worn down to his share, he stands down, the collar comes off, his scale
## builds the fountain and the day begins. Nothing of the night is saved but
## its end; a hero who slew Fafnyr on the old mountain never sees it.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const NightLight := preload("res://test/unit/test_night_light.gd")
## Who the story brings home before the night: the families of the four
## keepsakes.
const HOMECOMERS := ["saltmere_wenna", "mines_pell", "greyhold_ulla", "greyhold_teo", "frost_aske"]
## The jobs a settler does, and who: none of them is there in a save the
## story didn't bring them home in.
const SETTLER_JOBS := {
	"greyhold_teo": "bell", "greyhold_ulla": "arrows", "settler_iva": "heal",
	"settler_loras": "song", "frost_aske": "lamps", "saltmere_wenna": "shelter",
}
## What the balance model's heroes wear and wield (test_armour's kits at the
## gate, test_bosses' weapons): a level-13 hero with average gear, nothing
## forged up.
const KITS := {
	"warrior": ["blackiron_helm", "blackiron_plate", "blackiron_gauntlets", "blackiron_sabatons", "blackiron_bulwark", "warden_longsword"],
	"mage": ["frost_hood", "frostweave_robe", "frost_mitts", "frost_boots", "frost_ward", "rime_staff"],
	"ranger": ["warden_helm", "warden_hauberk", "warden_gloves", "warden_boots", "warden_kite", "deeproot_bow"],
}
const MAIN := {"warrior": ["strength", 2], "mage": ["intelligence", 3], "ranger": ["dexterity", 3]}
const DEF_A_LEVEL := {"warrior": 1}
## A swing every 0.45 s for half the fight (the rest stepping out of marks
## and closing in), as test_bosses models a boss fight.
const SWING_S := 0.45
const UPTIME := 0.5

var state: Node


func before_each() -> void:
	state = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")


func _next(hero: Node = null) -> String:
	var who: Node = hero if hero != null else state
	return MainQuest.next_step(who.progression, who.settlement).get("id", "")


## A hero home from the forge: the tin found, the keepsakes home with their
## families, Maren heard out, the fifth letter in Morvax's hands.
func _home_from_the_forge() -> void:
	state.mark_seen(Letters.scene_id())
	state.progression.quests[Relics.quest_id()] = {"progress": 4, "done": true}
	for relic: Dictionary in Relics.all():
		state.progression.hunted.append(relic["named"])
	state.holdings.come_home(true)
	state.mark_seen(Letters.confession_id())
	state.progression.quests[Letters.fifth_quest()["id"]] = {"progress": 1, "done": true}
	state.settlement.town_tier = 2
	state.settlement.projects.assign(Town.projects_through(2))


func _reloaded(hero: Node = null) -> Node:
	var who: Node = hero if hero != null else state
	var back: Node = autofree(GameStateScript.new())
	back.apply(SaveCodec.parse_json(SaveCodec.serialize(who.to_dict()))["state"])
	return back


# ---- The beats ------------------------------------------------------------------

func test_the_chapter_is_the_nights_beats_in_order() -> void:
	var chapter: Dictionary = MainQuest.chapters()[6]
	assert_eq(chapter["title"], "The Night of Bells")
	assert_eq(chapter["steps"].map(func(step: Dictionary) -> String: return step["id"]), ["run_home", "lanterns", "embers", "hold"])
	for index in chapter["steps"].size():
		var when: Dictionary = chapter["steps"][index]["when"]
		assert_eq([when["kind"], int(when["beat"])], ["bells", index + 1], "a beat a step")
	# Home's first step is Morvax's choice (step 10).
	var home: Dictionary = MainQuest.chapters()[7]["steps"][0]
	assert_eq(home["id"], "morvax_choice")
	assert_eq(home["when"]["kind"], "chosen")


func test_home_after_the_run_begins_the_night() -> void:
	_home_from_the_forge()
	assert_eq(_next(), "run_home")
	assert_true(Bells.due(state.progression, state.settlement), "home, and the bell rings")
	state.questing.bells_begin()
	assert_eq(state.progression.bells, Bells.LANTERNS)
	assert_false(Bells.due(state.progression, state.settlement), "once")
	assert_eq(_next(), "lanterns")
	assert_true(DayNight.is_night(state.world.steps), "the middle of the night")
	assert_eq(state.progression.quests.get("bram_imps", {}), {"progress": 0, "done": false}, "Bram's imps asked: the embers are imps")


func test_the_beats_come_in_order_and_each_is_a_step() -> void:
	_home_from_the_forge()
	state.questing.bells_begin()
	var seen: Array[String] = []
	for i in 3:
		seen.append(_next())
		state.questing.bells_on()
	seen.append(_next())
	assert_eq(seen, ["lanterns", "embers", "hold", "morvax_choice"] as Array[String])
	assert_eq(state.progression.bells, Bells.DAWN)
	state.questing.bells_on()
	assert_eq(state.progression.bells, Bells.DAWN, "nothing past the dawn")


func test_the_line_above_the_dock_says_how_far_each_beat_has_got() -> void:
	assert_string_contains(Bells.objective(Bells.LANTERNS, 3, 0, 0, 0.0), "Light the five lanterns on the square (3/5)")
	assert_string_contains(Bells.objective(Bells.EMBERS, 0, 2, 1, 0.0), "Drive off the embers and douse the fires")
	assert_string_contains(Bells.objective(Bells.HOLD, 0, 0, 0, 83.2), "1:24")


func test_walking_passes_no_time_tonight_and_the_sky_turns_as_the_square_is_held() -> void:
	_home_from_the_forge()
	state.questing.bells_begin()
	var night: float = state.world.steps
	state.walk(50.0)
	assert_eq(state.world.steps, night, "the night holds its clock")
	assert_eq(Bells.sky_at(night, 0.0), night)
	var dawn := Bells.sky_at(night, 1.0)
	assert_gt(dawn, night)
	assert_almost_eq(fposmod(dawn, DayNight.DAY_CYCLE_STEPS) / DayNight.DAY_CYCLE_STEPS, 0.91, 0.001, "the first grey of morning")
	assert_lt(Lights.darkness(Lights.outdoor(dawn)), Lights.darkness(Lights.outdoor(night)), "lighter at dawn")
	assert_true(DayNight.is_night(Bells.sky_at(night, 0.5)), "dark most of the way")
	assert_almost_eq(Bells.night_start(night), night, 0.001, "a night already begun stays")
	assert_true(DayNight.is_night(Bells.night_start(0.0)), "a morning's homecoming waits for the night")


# ---- The town that night ---------------------------------------------------------

## The town at the Night of Bells: a Village building its Town, its props
## standing (what blocks), as a door draws it.
func _town() -> MapData:
	var map := MapData.load_tiered("town", Town.projects_through(2), 1)
	for prop: Dictionary in PunyProps.compose(map.grid)["props"]:
		if (prop["foot"] as Rect2).has_area():
			for cell: Vector2i in prop["covers"]:
				map.covered[cell] = true
	for site: Dictionary in Town.sites(Town.projects_through(2)):
		for cell: Vector2i in Town.site_tiles(site):
			map.covered[cell] = true
	return map


func _open(map: MapData, cell: Vector2i) -> bool:
	return map.is_walkable(cell) and not map.portals.has(cell)


func test_everyone_and_everything_stands_on_open_ground() -> void:
	var map := _town()
	for job: Dictionary in Bells.all_jobs():
		assert_true(_open(map, Bells.cell(job["at"])), "%s at %s" % [job["who"], job["at"]])
		if job.has("tent"):
			assert_true(_open(map, Bells.cell(job["tent"])), "%s's tent" % job["who"])
	for cell in Bells.lanterns() + Bells.ember_cells() + [Bells.landing()]:
		assert_true(_open(map, cell), "%s on open ground" % cell)
	var spots := {}
	for job: Dictionary in Bells.all_jobs():
		assert_false(spots.has(job["at"]), "one to a cell: %s" % job["who"])
		spots[job["at"]] = true


func test_the_roofs_that_burn_are_homes_and_a_well_is_near() -> void:
	var houses: Array[Rect2i] = []
	for project: Dictionary in Town.age(1)["projects"]:
		for ruin: Dictionary in project.get("ruins", []):
			houses.append(Town._rect(ruin["rect"]))
	for roof in Bells.roofs():
		assert_has(houses, roof, "%s is one of the village's houses" % roof)
	var map := _town()
	var wells := map.grid.keys().filter(func(cell: Vector2i) -> bool: return map.grid[cell] == "well")
	assert_false(wells.is_empty(), "the well below the square")
	assert_eq(Bells.roof_at(Vector2i(23, 19)), 0, "Vex's door is the brewery's roof")
	assert_eq(Bells.roof_at(Bells.landing()), -1)


func test_the_lanterns_hold_the_square_and_iva_is_in_reach_of_it() -> void:
	for cell in Bells.lanterns():
		assert_true(Bells.holding(cell), "%s is on the square" % cell)
	assert_true(Bells.holding(Bells.landing()))
	var iva := Bells.job("heal", ["settler_iva"], 2)
	assert_true(Bells.holding(Bells.cell(iva["at"])), "a heal without leaving the square")
	var sela := Bells.job("shelter", [], 2)
	assert_false(Bells.holding(Bells.cell(sela["at"])), "the inn is a run away: the dawn waits while you're there")


func test_each_settlers_job_is_done_only_when_they_are_home() -> void:
	for who: String in SETTLER_JOBS:
		var kind: String = SETTLER_JOBS[who]
		assert_false(Bells.jobs([], 4).any(func(job: Dictionary) -> bool: return job["who"] == who), "%s isn't out without coming home" % who)
		assert_true(Bells.jobs([who], 4).any(func(job: Dictionary) -> bool: return job["who"] == who and job["job"] == kind), "%s does the %s at home" % [who, kind])
	assert_eq(Bells.folk([], 2).map(func(npc: Dictionary) -> String: return npc["id"]).filter(func(id: String) -> bool: return id in SETTLER_JOBS), [], "nobody not home is on the square")


## An old save the story never brought anyone home in (an old floor's
## climber): the night is still winnable - the shelter and Bram's cheese
## are the village's own, a pot rings for the bell, the village puts its
## own lamps out.
func test_the_night_is_winnable_with_nobody_home() -> void:
	var kinds := Bells.jobs([], 2).map(func(job: Dictionary) -> String: return job["job"])
	assert_has(kinds, "shelter", "Sela's inn, always")
	assert_has(kinds, "cheese", "Bram, always")
	assert_eq(Bells.start_line([], 2), String(Bells.data()["startQuiet"]))
	assert_eq(Bells.dark_line([], 2), String(Bells.data()["lanterns"]["darkQuiet"]))
	assert_eq(Bells.start_line(HOMECOMERS, 2), String(Bells.data()["start"]))
	assert_eq(Bells.dark_line(HOMECOMERS, 2), String(Bells.data()["lanterns"]["dark"]))


func test_the_night_folk_say_the_nights_words_where_their_job_puts_them() -> void:
	var folk := Bells.folk(HOMECOMERS + ["settler_iva", "settler_loras"], 2)
	var by_id := {}
	for npc: Dictionary in folk:
		by_id[npc["id"]] = npc
		assert_eq(npc["mapId"], "town")
		assert_false(npc["wander"], "at their place all night")
		assert_false(npc.has("stall"))
	for job: Dictionary in Bells.all_jobs():
		assert_true(by_id.has(job["who"]), "%s is out" % job["who"])
		assert_eq(by_id[job["who"]]["lines"], job["lines"], "%s says the night's words" % job["who"])
		assert_eq(Vector2i(int(by_id[job["who"]]["x"]), int(by_id[job["who"]]["y"])), Bells.cell(job["at"]))
	assert_false(Bells.folk(HOMECOMERS, 1).any(func(npc: Dictionary) -> bool: return npc["id"] == "kid_pip"), "Pip comes with the Village")


func test_the_shelter_and_iva_heal_and_nobody_hands_anything_in() -> void:
	_home_from_the_forge()
	state.settlement.settlers.append("settler_iva")
	state.questing.bells_begin()
	state.progression.quests["bram_imps"] = {"progress": 2, "done": false}
	state.hero.hp = 3
	state.questing.finish_dialogue("innkeeper")
	assert_eq(state.hero.hp, int(state.hero.stats["maxHp"]), "a bowl at the inn")
	state.hero.hp = 3
	state.questing.finish_dialogue("settler_iva")
	assert_eq(state.hero.hp, int(state.hero.stats["maxHp"]), "Iva's tent")
	state.hero.hp = 3
	state.questing.finish_dialogue("villager_bram")
	assert_eq(state.hero.hp, 3, "Bram only talks")
	assert_false(state.progression.quests["bram_imps"]["done"], "nothing handed in tonight")
	assert_true(Bells.heal_ready(Bells.job("heal", ["settler_iva"], 2), 0.0, 20.0))
	assert_false(Bells.heal_ready(Bells.job("heal", ["settler_iva"], 2), 10.0, 15.0), "her tent heals every so often")


# ---- Fafnyr -------------------------------------------------------------------

func test_fafnyr_holds_the_square_as_a_boss_and_yields_at_his_share() -> void:
	var fafnyr := Bells.fafnyr()
	assert_true(Bestiary.is_boss(fafnyr["id"]), "a boss: the boss brain, the bar, the roar")
	assert_true(fafnyr["bells"])
	assert_eq(int(fafnyr["level"]), 14)
	assert_eq(fafnyr["roars"].size(), 2, "a roar for each new phase, over the square")
	for roar: String in fafnyr["roars"]:
		assert_false(roar.contains("cave"), "on the square, not in his cave")
	fafnyr["hp"] = int(fafnyr["maxHp"] * 0.5)
	assert_false(Hunts.yields(fafnyr), "half spent, still fighting")
	fafnyr["hp"] = int(fafnyr["maxHp"] * float(fafnyr["yieldsAt"]))
	assert_true(Hunts.yields(fafnyr), "at his share he stands down")
	assert_false(Hunts.yields(Bestiary.spawn("dragon")), "the old mountain's Fafnyr fought to the end")


func test_teos_bell_stuns_him_a_breath_whatever_his_guard() -> void:
	var held := Ailments.new()
	held.stun_guard = 12.0
	held.inflict({"kind": "stun", "chance": 1.0, "turns": 1, "power": 0}, func() -> float: return 0.0)
	assert_false(held.inflict({"kind": "stun", "chance": 1.0, "turns": 1, "power": 0}, func() -> float: return 0.0), "a boss shrugs a second stun off")
	held.stun_for(2)
	assert_true(held.is_stunned(), "but every ring holds him")
	held.tick(2.1)
	assert_false(held.is_stunned(), "for a breath")


## A level-13 hero in average gear (the gate's kit, the stage's weapon,
## nothing forged up) wins with some care: the dawn comes about when they'd
## have worn him to his share (a strong hero ends it first), the townsfolk's
## blows count, and his bite takes several to bring them down, with Iva's
## tent and the shelter to mend them.
func test_a_level_thirteen_hero_holds_until_dawn_with_some_care() -> void:
	var fafnyr := Bells.fafnyr()
	var dawn := Bells.dawn_seconds()
	var to_yield := float(fafnyr["maxHp"]) * (1.0 - float(fafnyr["yieldsAt"]))
	var helpers := 0.0
	for job in Bells.jobs(HOMECOMERS, 2):
		if job["job"] in ["arrows", "cheese"]:
			helpers += float(job["damage"]) * float(job.get("count", 1)) / float(job["every"])
	gut.p("Fafnyr tonight: level %d, %d HP, yields at %d%% (%d to wear down), attack %d; dawn after %.0f s held; the walls and the cheese %.1f a second" % [
		fafnyr["level"], fafnyr["maxHp"], roundi(float(fafnyr["yieldsAt"]) * 100), to_yield, fafnyr["attack"], dawn, helpers])
	for role: String in KITS:
		var kit := _kitted(role, 13)
		var hero: HeroState = kit[0]
		var swing := Bestiary.hero_attack_damage(hero, kit[1], fafnyr, false, func() -> float: return 0.5)
		var bite := Bestiary.monster_attack_damage(fafnyr, hero, kit[1], func() -> float: return 0.5)
		var dps := swing * UPTIME / SWING_S + helpers
		var seconds := to_yield / dps
		var hits := float(hero.stats["maxHp"]) / bite
		gut.p("  a level-13 %s: %d HP, swings %d, %.0f a second with the town: his share in %.0f s; bitten for %d (breath %d), %.1f bites to fall" % [
			role, hero.stats["maxHp"], swing, dps, seconds, bite, roundi(bite * 1.4), hits])
		assert_between(seconds, dawn * 0.75, dawn * 1.6, "a level-13 %s: the dawn ends it about when they'd have worn him down" % role)
		assert_between(hits, 4.0, 10.0, "a level-13 %s falls to a few bites, not one, not twenty" % role)
	var iva := Bells.job("heal", ["settler_iva"], 2)
	assert_gte(dawn / float(iva["every"]), 6.0, "Iva's tent mends a hero at least six times before dawn")


## A hero of the role at `level`, grown, their points in what they hit with
## (a fighter's one a level in DEF), their defensive passives learned, in the
## kit.
func _kitted(role: String, level: int) -> Array:
	var hero := HeroState.create("Model", role)
	while hero.level < level:
		hero.xp = hero.xp_to_next
		HeroRules.apply_level_ups(hero)
	for i in int(DEF_A_LEVEL.get(role, 0)) * (level - 1):
		Skills.apply_stat_point(hero, "defense")
	hero.stats[MAIN[role][0]] = int(hero.stats[MAIN[role][0]]) + int(MAIN[role][1]) * (level - 1)
	for entry: Dictionary in Skills.tree(role):
		if entry["kind"] == "passive" and int(entry.get("passive", {}).get("defense", 0)) > 0 and Skills.tier_level(entry) <= level:
			hero.skill_nodes.append(entry["id"])
	var pack := InventoryState.new()
	for item_id: String in KITS[role]:
		var piece := InventoryState.create_gear(item_id)
		pack.gear.append(piece)
		pack.equipped[Catalog.item(item_id)["slot"]] = piece["uid"]
	return [hero, pack]


# ---- Dawn, the collar, the day ----------------------------------------------------

func test_dawn_frees_him_for_good_and_his_scale_builds_the_fountain() -> void:
	_home_from_the_forge()
	state.questing.bells_begin()
	for i in 2:
		state.questing.bells_on()
	assert_false(Town.done_projects(state.settlement).has("fountain"))
	var xp: int = state.hero.xp
	var built: String = state.questing.bells_dawn()
	assert_string_contains(built, Town.project("fountain")["name"])
	assert_true(Bells.over(state.progression), "the collar's off, in the ledger")
	assert_true(state.has_seen(Bells.dawn_id()))
	assert_true(Town.done_projects(state.settlement).has("fountain"), "the scale in the fountain")
	assert_has(state.reveals, "project:fountain", "the town's tour shows it")
	assert_eq(int(state.pack.items.get("dragon_scale", 0)), 0, "in the fountain, not the pack")
	assert_eq(state.hero.xp, xp + int(Bells.fafnyr_spec()["xp"]), "holding the square earns its XP")
	assert_eq(_next(), "morvax_choice")
	state.questing.bells_day()
	assert_eq(state.progression.bells, Bells.NONE)
	assert_false(DayNight.is_night(state.world.steps), "morning")
	var back := _reloaded()
	assert_true(Bells.over(back.progression), "kept by the save")
	assert_false(Bells.due(back.progression, back.settlement), "no second night")
	assert_eq(_next(back), "morvax_choice")
	assert_eq(MainQuest.continued(back.progression, back.settlement), "", "home is written: no card")
	assert_eq(MainQuest.card_due(back.progression, back.settlement), 8)
	assert_eq(state.holdings.scale_in_fountain(), "", "one scale, one fountain")


func test_the_fountain_finishes_the_town_when_it_is_the_last_of_it() -> void:
	_home_from_the_forge()
	state.settlement.projects.assign(Town.projects_through(2) + ["slate_hall", "moss_cottage"])
	state.questing.bells_dawn()
	assert_eq(state.settlement.town_tier, 3, "Pixelheim is a Town")
	assert_has(state.reveals, "age:3")


# ---- Old saves ------------------------------------------------------------------

## A hero who slew Fafnyr on the old mountain keeps him slain (step 8): no
## night at all, Morvax's choice next - and their fountain is as it was,
## theirs to build with the scale they won.
func test_a_dragon_slayer_never_sees_the_night() -> void:
	_home_from_the_forge()
	state.progression.cleared_levels.assign(range(1, 11))
	assert_true(MainQuest.skips(7, state.progression, state.settlement))
	assert_false(Bells.due(state.progression, state.settlement))
	assert_eq(_next(), "morvax_choice")
	assert_false(Town.done_projects(state.settlement).has("fountain"), "no scale left in it for them")
	assert_true(Town.project("fountain")["cost"]["items"].has("dragon_scale"), "the board still asks the scale they won")


## A save made in the night (it autosaves as a hero walks) keeps nothing of
## it but what the save always kept: on load the night begins again from
## the bell, and the format has no new field.
func test_a_save_made_in_the_night_plays_it_again_from_the_start() -> void:
	_home_from_the_forge()
	var before: Array = state.to_dict().keys()
	state.questing.bells_begin()
	for i in 2:
		state.questing.bells_on()
	assert_eq(state.progression.bells, Bells.HOLD)
	var saved: Dictionary = state.to_dict()
	assert_false(saved.has("bells"), "no new field")
	assert_eq(saved.keys(), before, "nothing the save didn't hold")
	var back := _reloaded()
	assert_eq(back.progression.bells, Bells.NONE)
	assert_eq(_next(back), "run_home")
	assert_true(Bells.due(back.progression, back.settlement), "home again, the bell rings again")
	assert_true(back.progression.quests.has("bram_imps"), "what the save kept, it keeps")


## PIX-297: a save made in town on the run home (the build before the
## night, its card never shown) begins the night as it loads, wherever in
## town it stands; and the save made in the night, the same.
func test_a_save_in_town_on_the_run_home_begins_the_night() -> void:
	for fixture: String in ["run_home_town", "bells_night"]:
		var hero: Node = autofree(GameStateScript.new())
		hero.apply(WebImport.parse_any(FileAccess.get_file_as_string("res://test/fixtures/%s.json" % fixture)))
		assert_eq(hero.world.map_id, "town", fixture)
		assert_eq(_next(hero), "run_home", "%s: the run home next" % fixture)
		assert_true(Bells.due(hero.progression, hero.settlement), "%s: the bell rings" % fixture)


func test_the_late_web_hero_keeps_their_story_told() -> void:
	var late := SaveCodec.decode_code(FileAccess.get_file_as_string("res://test/fixtures/web_save_late.txt"))
	state.apply(late.duplicate(true))
	assert_false(Bells.due(state.progression, state.settlement), "no night for the hero who cast Morvax down")
	assert_eq(_next(), "", "their story is told")


# ---- The scenes -----------------------------------------------------------------

func test_the_dawn_and_the_collar_are_scenes_with_the_plans_words() -> void:
	var dawn: Array = Cutscene.scenes()[Bells.dawn_id()]
	var collar: Array = Cutscene.scenes()[Bells.collar_id()]
	assert_eq(dawn[0], {"kind": "stage", "stage": "world"}, "on the square itself")
	var said := func(scene: Array) -> String:
		return "\n".join(scene.filter(func(step: Dictionary) -> bool: return step["kind"] == "caption").map(func(step: Dictionary) -> String: return step["text"]))
	assert_string_contains(said.call(dawn), "The cat looks at the dragon, then at you, then away. The verdict is in.")
	assert_string_contains(said.call(collar), "Corners. All corners.")
	assert_string_contains(said.call(collar), "Morvax")
	assert_string_contains(said.call(collar), "fountain")
	var flown := collar.filter(func(step: Dictionary) -> bool: return step.get("name", "") == "fafnyr" and step.has("to_cell"))
	assert_eq(flown.size(), 1, "he flies home")
	assert_true(Cutscene.STAGES.has("world"))


func test_a_light_never_crowds_the_square_that_night() -> void:
	var saved_steps: float = GameState.world.steps
	GameState.world.steps = Prologue.night_steps()
	var root := Node2D.new()
	add_child_autofree(root)
	var actors := Node2D.new()
	root.add_child(actors)
	var map := MapData.load_tiered("town", Town.projects_through(2), 1)
	var view := MapView.new(map, actors)
	view.plan(map.spawn)
	view.build(root)
	view.lamps_out()
	for roof in Bells.roofs():
		view.burn(roof)
	view.pitch_tent(Bells.cell(Bells.job("heal", ["settler_iva"], 2)["tent"]))
	var spots := Bells.lanterns()
	for i in spots.size():
		var lantern := Night.lantern_at(spots[i])
		actors.add_child(lantern)
		Night.light(lantern, i)
	var reaches := NightLight._reaches(root)
	var worst := 0
	for node in root.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		var block := layer.rendering_quadrant_size
		var blocks := {}
		for cell: Vector2i in layer.get_used_cells():
			blocks[Vector2i(floori(cell.x / float(block)), floori(cell.y / float(block)))] = true
		for corner: Vector2i in blocks:
			var rect := Rect2(layer.global_position + Vector2(corner * block * MapView.TILE), Vector2.ONE * block * MapView.TILE).grow(MapView.TILE)
			worst = maxi(worst, reaches.filter(func(reach: Rect2) -> bool: return reach.intersects(rect)).size())
	GameState.world.steps = saved_steps
	assert_lte(worst, Lights.PER_ITEM - NightLight.MOVING, "the lanterns, the burning roofs and the windows leave room for what moves")
