extends GutTest
## Lantern Night (PIX-362): once the story is over, the last night of every
## Reach year is a festival, and that night Fafnyr lights every lamp on the
## Reach in one pass: once a night, kept in the save's festival, skippable.

const DAY := LanternNight.NIGHT
const GameStateScript := preload("res://scripts/state/game_state.gd")


## The world as the watch asks it (LanternPass.watch): a map, the hero's
## cell, and the map drawn again round them.
class FakeWorld extends Node:
	var harness := false
	var map := MapData.new()
	var player_cell := Vector2i(43, 27)
	## Each drawing: the map, where the hero stands, whether the festival's on.
	var drawn: Array = []

	func load_map(id: String) -> MapData:
		var next := MapData.new()
		next.id = id
		return next

	func enter_map(next: MapData, at: Vector2i) -> void:
		drawn.append([next.id, at, GameState.holdings.festival_on()])


func _progression(ended := true) -> ProgressionState:
	var progression := ProgressionState.new()
	if ended:
		progression.story_seen.append("ending_home")
	return progression


## A pass over a drawing whose lamps stand at `places`, all dark.
func _moment(places: Array[String], town: SettlementState) -> LanternPass:
	var view := MapView.new(MapData.new(), autofree(Node2D.new()))
	for place in places:
		var ember: Node2D = autofree(Node2D.new())
		var halo: Node2D = autofree(Node2D.new())
		halo.set_meta("light", autofree(PointLight2D.new()))
		ember.set_meta("halo", halo)
		ember.visible = false
		halo.visible = false
		view.ember_lamps[place] = ember
	var moment := LanternPass.new()
	moment.view = view
	moment.places = places
	moment.day = DAY
	moment.settlement = town
	return moment


func _lit(moment: LanternPass) -> Array[String]:
	var out: Array[String] = []
	for place: String in moment.view.ember_lamps:
		var ember: Node2D = moment.view.ember_lamps[place]
		if ember.visible and (ember.get_meta("halo") as Node2D).visible:
			out.append(place)
	return out


func test_it_comes_only_after_the_story_and_only_on_lantern_night() -> void:
	var town := SettlementState.new()
	assert_false(LanternNight.tonight(_progression(false), town, DAY), "not before the story's end")
	assert_true(LanternNight.tonight(_progression(), town, DAY))
	assert_true(LanternNight.tonight(_progression(), town, DAY + LanternNight.YEAR), "every year")
	for day in [0, DAY - 1, DAY + 1, DAY + 7, DAY + LanternNight.YEAR - 1]:
		assert_false(LanternNight.tonight(_progression(), town, day), "not on day %d" % day)
	assert_false(LanternNight.waits(_progression(false), town, DAY), "the lamps never wait before the story's end")


func test_it_brings_the_town_its_festival_until_the_next_morning() -> void:
	var town := SettlementState.new()
	assert_true(LanternNight.begins(_progression(), town, DAY))
	LanternNight.begin(town, DAY, 2)
	assert_eq(int(town.festival["until"]), (DAY + 1) * DayNight.DAY_CYCLE_STEPS)
	assert_eq([town.festival["age"], town.festival["won"]], [2, false], "the ring toss's prize by the town's age")
	assert_false(LanternNight.begins(_progression(), town, DAY), "begun once")


func test_his_pass_comes_once_a_night_kept_in_the_save_and_again_next_year() -> void:
	var town := SettlementState.new()
	LanternNight.begin(town, DAY, 1)
	assert_true(LanternNight.waits(_progression(), town, DAY), "the lamps wait for him")
	LanternNight.fly(town, DAY, 1)
	assert_false(LanternNight.waits(_progression(), town, DAY), "flown: the lamps burn as any night")
	var kept := {}
	town.write_into(kept)
	var back := SettlementState.from_dict(SaveCodec.parse_json(JSON.stringify(kept)))
	assert_true(LanternNight.flown(back, DAY), "kept in the save's festival")
	assert_false(LanternNight.begins(_progression(), back, DAY), "the night doesn't begin again")
	var next := DAY + LanternNight.YEAR
	LanternNight.begin(back, next, 1)
	assert_true(LanternNight.waits(_progression(), back, next), "next year he flies again")


func test_the_pass_lights_every_lamp_on_the_reach_west_to_east() -> void:
	var town := SettlementState.new()
	for place: String in Routes.places():
		var lamp := Routes.lamp_of(place)
		if not lamp.is_empty():
			town.projects.append(String(lamp["work"]))
	var lamps := Routes.lamps(town)
	assert_gt(lamps.size(), 3, "every road's lamp built")
	var order := LanternNight.order(lamps)
	assert_eq(order.size(), lamps.size(), "every lamp in his way")
	for i in range(1, order.size()):
		assert_true(Vector2i(Routes.lamp_of(order[i - 1])["cell"]).x <= Vector2i(Routes.lamp_of(order[i])["cell"]).x, "west to east")
	var moment := _moment(order, town)
	moment.step(false)
	assert_eq(_lit(moment), [order[0]] as Array[String], "the first in his way first")
	for i in order.size():
		moment.step(false)
	assert_eq(_lit(moment).size(), order.size(), "every lamp lit")
	moment.finish()
	assert_true(LanternNight.flown(town, DAY))


func test_his_scene_crosses_the_sky_west_to_east_and_is_short() -> void:
	var steps: Array = Cutscene.scenes()["lantern_night"]
	var crossing := steps.filter(func(step: Dictionary) -> bool: return step.has("to_cell"))
	assert_eq(crossing.size(), 1, "one crossing, his: the lamps catch along it (LanternPass)")
	assert_lt(int(crossing[0]["cell"][0]), int(crossing[0]["to_cell"][0]), "west to east")
	assert_eq(steps.filter(func(step: Dictionary) -> bool: return step["kind"] == "caption").size(), 2, "short: two lines")


func test_esc_skips_it_every_lamp_lit_at_once_and_the_night_flown_once() -> void:
	var town := SettlementState.new()
	var places: Array[String] = ["saltmere", "blackiron", "frostgate"]
	var moment := _moment(places, town)
	var scene: Cutscene = autofree(Cutscene.new())
	scene.on_done = moment.finish
	var esc := InputEventAction.new()
	esc.action = &"ui_cancel"
	esc.pressed = true
	scene._command(esc).call()
	assert_eq(_lit(moment).size(), places.size(), "every lamp lit at once")
	assert_true(LanternNight.flown(town, DAY), "the night's one pass")
	assert_eq(moment.lit, places.size())
	moment.finish()
	assert_eq(moment.lit, places.size(), "over once")


## PIX-367: begun with the hero in town, its stalls went up only the next
## time the town was drawn; now the town is drawn again round the hero as it
## begins, as an age's festival's is once the board shuts.
func test_begun_with_the_hero_in_town_its_stalls_go_up_round_them() -> void:
	var kept: Array = [GameState.progression, GameState.settlement, GameState.world.steps]
	GameState.progression = _progression()
	GameState.settlement = SettlementState.new()
	GameState.world.steps = DAY * DayNight.DAY_CYCLE_STEPS
	var world: FakeWorld = autofree(FakeWorld.new())
	world.map.id = "town"
	LanternPass.watch(world)
	LanternPass.watch(world)
	GameState.progression = kept[0]
	GameState.settlement = kept[1]
	GameState.world.steps = kept[2]
	assert_eq(world.drawn, [["town", Vector2i(43, 27), true]], "drawn again where the hero stands, the festival on, once")


## PIX-367: an age finished on Lantern Night replaced the night's record, so
## the lamps didn't wait and Fafnyr didn't fly; now the town has both, the
## age's festival day and the night's pass, in the one record.
func test_an_age_finished_on_lantern_night_keeps_the_night() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.progression = _progression()
	var town: SettlementState = state.settlement
	var evening := (DAY + 0.4) * DayNight.DAY_CYCLE_STEPS
	state.world.steps = evening
	LanternNight.begin(town, DAY, 1)
	state.holdings.start_festival(2)
	assert_true(LanternNight.waits(state.progression, town, DAY), "the lamps still wait for him")
	assert_false(LanternNight.begins(state.progression, town, DAY), "the night isn't begun again")
	assert_eq([int(town.festival["until"]), town.festival["age"]], [int(evening) + DayNight.DAY_CYCLE_STEPS, 2], "the age's festival day")
	LanternNight.fly(town, DAY, 2)
	state.holdings.start_festival(3)
	assert_true(LanternNight.flown(town, DAY), "an age after his pass: he flew once")
	# The age first, the night begun after it: the age's day is kept.
	var other: SettlementState = SettlementState.new()
	state.settlement = other
	state.holdings.start_festival(2)
	LanternNight.begin(other, DAY, 2)
	assert_eq(int(other.festival["until"]), int(evening) + DayNight.DAY_CYCLE_STEPS, "the age's day, past the night's morning")
	assert_true(LanternNight.waits(state.progression, other, DAY))
