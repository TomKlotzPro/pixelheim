extends GutTest
## A boss fight ends cleanly (Tom's second playtest). PIX-288: « J'ai encore
## le bug : j'ai tué un boss mais il reste affiché » - the bar let go of a
## boss whose body had dissolved before its bar had faded out (a freed foe
## is `== null` in Godot 4, and the bar stopped there, frozen on the
## screen); now it fades out whatever became of its foe, and a new map
## takes it down at once. PIX-292: « Porte de sortie direct après un boss » -
## a boss that falls more than a few steps from its door opens a way out
## right where it fell, straight out to the dungeon's way in, and the arrow
## points out by the nearest way out, not back up the stairs. PIX-339:
## « ça fait bizarre de tuer un boss et qu'un escalier pop » - that way out
## rises out of the floor once the boss has finished falling (StairRise),
## its cracks on the floor round it, and opens only as it ends.

const BossBarScript := preload("res://scripts/boss_bar.gd")
const GameStateScript := preload("res://scripts/state/game_state.gd")
## Each region dungeon's bottom floor and its boss.
const BOTTOMS := {
	"seacave_grotto": "tidecaller", "shafts_blackseam": "seam_warden",
	"cellars_hall": "hollow_captain", "icecave_glass": "rimefang",
}


## Just enough of a foe for the bar to follow.
class Foe:
	extends Node
	var fighter := {"id": "king_slime", "name": "The Tidecaller", "hp": 220, "maxHp": 220, "named": "tidecaller"}
	var dying := false
	var hunting := true


func _bar() -> Control:
	var bar: Control = BossBarScript.new()
	add_child_autofree(bar)
	return bar


func test_the_bar_lets_go_of_a_boss_freed_before_it_faded() -> void:
	var bar := _bar()
	var foe := Foe.new()
	add_child(foe)
	bar.follow(foe)
	bar._process(0.1)
	assert_true(bar.showing(), "up while it hunts")
	# Worn down, then the last blow: the ghost of the blows still holds.
	foe.fighter["hp"] = 15
	bar._process(0.05)
	foe.dying = true
	bar._process(0.05)
	assert_gt(bar.ghost_share, 0.0, "the last blows' ghost holds a moment")
	# Its body dissolves and is freed before the bar has faded.
	foe.free()
	for i in 60:
		bar._process(0.1)
	assert_eq(bar.modulate.a, 0.0, "the bar fades out all the same")
	assert_false(bar.showing())
	assert_false(bar.following(), "and follows nothing")
	assert_eq(bar.reading(), "fading 0%")


func test_the_bar_fades_out_after_a_boss_stands_down() -> void:
	var bar := _bar()
	var foe: Foe = autofree(Foe.new())
	bar.follow(foe)
	bar._process(0.1)
	foe.fighter["hp"] = 66
	bar._process(0.1)
	# Standing down (enemy.stand_down): out of the fight, still standing.
	foe.dying = true
	foe.hunting = false
	for i in 60:
		bar._process(0.1)
	assert_false(bar.showing())


func test_a_lethal_blow_while_the_bar_eases_still_lets_go() -> void:
	var bar := _bar()
	var foe: Foe = autofree(Foe.new())
	bar.follow(foe)
	bar._process(0.1)
	foe.fighter["hp"] = 100
	bar._process(0.1)
	bar._process(0.5)
	assert_gt(bar.ghost_share, bar.share, "the ghost draining")
	foe.fighter["hp"] = 0
	foe.dying = true
	for i in 60:
		bar._process(0.1)
	assert_false(bar.showing())


func test_a_new_map_takes_the_bar_down_at_once() -> void:
	var bar := _bar()
	var foe: Foe = autofree(Foe.new())
	bar.follow(foe)
	bar._process(0.5)
	assert_true(bar.showing())
	bar.let_go()
	assert_false(bar.showing(), "gone at once (world.enter_map)")
	assert_false(bar.following())
	bar._process(0.1)
	assert_eq(bar.modulate.a, 0.0, "and stays gone")


func test_the_bar_still_follows_the_next_boss() -> void:
	var bar := _bar()
	var first := Foe.new()
	add_child(first)
	bar.follow(first)
	bar._process(0.5)
	first.free()
	for i in 60:
		bar._process(0.1)
	var next: Foe = autofree(Foe.new())
	next.fighter["name"] = "The Seam Warden"
	bar.follow(next)
	bar._process(0.1)
	assert_true(bar.showing())
	assert_eq(bar.name_label.text, "The Seam Warden")
	assert_eq(bar.reading(), "100%")


## A bottom floor with its boss down: its door open, as a world loads it.
func _opened(map_id: String) -> MapData:
	var map := MapData.load_by_id(map_id)
	Depths.open_shortcut(map, [BOTTOMS[map_id]])
	return map


func test_every_dungeon_has_words_for_a_way_out_where_its_boss_fell() -> void:
	for map_id: String in BOTTOMS:
		var door := Depths.shortcut_on(map_id)
		assert_ne(String(door["fell"]), "", map_id + ": what's said as it opens")
		assert_ne(String(door["sign"]), "", map_id + ": where it leads, over it")


func test_a_boss_felled_far_from_its_door_opens_a_way_out_where_it_fell() -> void:
	for map_id: String in BOTTOMS:
		var map := _opened(map_id)
		var door := Depths.shortcut_on(map_id)
		var lair: Dictionary = Hunts.named(BOTTOMS[map_id])["lair"]
		var fell := Vector2i(int(lair["x"]), int(lair["y"]))
		assert_gt(Vector2(fell).distance_to(Vector2(door["cell"])), Depths.WAY_OUT_NEAR, map_id + ": its lair is far from its door")
		var cell := Depths.way_out_cell(map, fell)
		assert_eq(cell, fell, map_id + ": right where it fell")
		Depths.open_way_out(map, cell)
		assert_eq(map.portals[cell], door["to"], map_id + ": out to the dungeon's way in, as the door")
		assert_true(map.is_walkable(cell), map_id + ": stepped onto")
		assert_eq(map.pieces[cell], PunyDungeon.STAIRS, map_id + ": a stair up")
		assert_eq(Depths.exits(map), [door["cell"], cell] as Array[Vector2i], map_id + ": the door, then the way out")


func test_a_boss_felled_by_its_door_has_the_door_for_its_way_out() -> void:
	for map_id: String in BOTTOMS:
		var map := _opened(map_id)
		var door: Vector2i = Depths.shortcut_on(map_id)["cell"]
		# Two cells out from the door into the hall below it.
		var fell := door + Vector2i(0, 2)
		assert_true(map.is_walkable(fell), map_id)
		assert_eq(Depths.way_out_cell(map, fell), Depths.NOWHERE, map_id + ": the door is a few steps off")


func test_a_way_out_never_opens_under_the_hero_nor_in_the_rock() -> void:
	var map := _opened("seacave_grotto")
	var fell := Vector2i(25, 12)
	var beside := Depths.way_out_cell(map, fell, fell)
	assert_ne(beside, fell, "not where the hero stands")
	assert_lt(Vector2(beside - fell).length(), 2.0, "but right beside")
	# Against the grotto's west wall: on the floor, never in the rock.
	var by_wall := Depths.way_out_cell(map, Vector2i(17, 12))
	assert_eq(map.tile_at(by_wall), "floor")
	assert_false(map.portals.has(by_wall))
	assert_eq(Depths.way_out_cell(MapData.load_by_id("seacave"), Vector2i(10, 10)), Depths.NOWHERE, "no shortcut, no way out")


func test_the_arrow_points_out_by_the_nearest_way_out() -> void:
	var map := MapData.load_by_id("seacave_grotto")
	var hero := Vector2i(24, 12)
	assert_eq(Depths.way_out_toward(map, "town", hero), Depths.NOWHERE, "the door shut: the stairs as before")
	Depths.open_shortcut(map, ["tidecaller"])
	assert_eq(Depths.way_out_toward(map, "town", hero), Vector2i(30, 4), "the tide door")
	var beside := Depths.way_out_cell(map, Vector2i(25, 12), hero)
	Depths.open_way_out(map, beside)
	assert_eq(Depths.way_out_toward(map, "town", hero), beside, "the nearer: where it fell")
	assert_eq(Depths.way_out_toward(map, "saltmere", hero), beside, "the dungeon's way in itself")
	assert_eq(Depths.way_out_toward(map, "seacave_galleries", hero), Depths.NOWHERE, "a floor above: up its stair")
	assert_eq(Depths.way_out_toward(map, "", hero), Depths.NOWHERE, "nowhere to go")
	var cellars := _opened("cellars_hall")
	assert_eq(Depths.way_out_toward(cellars, "cellars", Vector2i(28, 8)), Vector2i(30, 3), "the cellars' first floor is where the north stair leads")


## Where each bottom floor's boss fell in its lair: its way out's cell.
func _lair_way_out(map: MapData, map_id: String) -> Vector2i:
	var lair: Dictionary = Hunts.named(BOTTOMS[map_id])["lair"]
	return Depths.way_out_cell(map, Vector2i(int(lair["x"]), int(lair["y"])))


func _rising(map: MapData, cell: Vector2i) -> StairRise:
	var rise := StairRise.new()
	rise.map = map
	rise.cell = cell
	rise.still = false
	add_child_autofree(rise)
	return rise


func test_the_way_out_rises_and_opens_only_as_it_ends() -> void:
	for map_id: String in BOTTOMS:
		var map := _opened(map_id)
		var door := Depths.shortcut_on(map_id)
		var cell := _lair_way_out(map, map_id)
		var rise := _rising(map, cell)
		watch_signals(rise)
		rise._process(StairRise.CRACK_S / 2.0)
		assert_eq(rise.phase(), "cracking", map_id + ": the floor cracks first")
		rise._process(StairRise.CRACK_S)
		assert_eq(rise.phase(), "sinking", map_id + ": then the slabs give")
		assert_signal_emit_count(rise, "sinking", 1, map_id)
		assert_false(map.portals.has(cell), map_id + ": no way yet while it rises")
		assert_eq(Depths.exits(map), [door["cell"]] as Array[Vector2i], map_id + ": the door alone")
		rise._process(StairRise.SINK_S)
		assert_eq(rise.phase(), "open", map_id)
		assert_eq(map.portals.get(cell), door["to"], map_id + ": straight out to the way in once risen")
		assert_eq(map.pieces[cell], PunyDungeon.STAIRS, map_id + ": a stair up")
		assert_eq(Depths.exits(map), [door["cell"], cell] as Array[Vector2i], map_id + ": the door, then the way out")
		rise._process(1.0)
		assert_signal_emit_count(rise, "risen", 1, map_id + ": opened once")


func test_with_reduce_motion_its_cracks_are_there_at_once() -> void:
	var map := _opened("seacave_grotto")
	var rise := _rising(map, _lair_way_out(map, "seacave_grotto"))
	rise.still = true
	rise._process(0.01)
	assert_eq(rise._shown, rise._cracks.size())


func test_its_cracks_run_out_over_the_floor_round_it_never_the_rock() -> void:
	for map_id: String in BOTTOMS:
		var map := _opened(map_id)
		var cell := _lair_way_out(map, map_id)
		var cracks := StairRise.cracks(map, cell)
		assert_eq(StairRise.cracks(map, cell), cracks, map_id + ": the same each time")
		var middle := Vector2(MapView.TILE, MapView.TILE) / 2.0
		var beyond := 0
		for i in cracks.size():
			var on := cell + Vector2i((Vector2(cracks[i]) / MapView.TILE).floor())
			if on != cell:
				beyond += 1
				assert_true(map.is_walkable(on) and not map.portals.has(on), "%s: %s is open floor" % [map_id, on])
			if i > 0:
				assert_true(Vector2(cracks[i - 1]).distance_to(middle) <= Vector2(cracks[i]).distance_to(middle), map_id + ": they run outward")
		assert_gt(beyond, 8, map_id + ": out round the stair, as broken slabs")


## A save made while it rises wakes with the way straight out open: the
## fall wrote the boss's hunt before the stair began, and the floor, laid
## afresh, opens its door in the rock from it.
func test_a_save_made_while_it_rises_wakes_with_the_way_out_open() -> void:
	var state: Node = autofree(GameStateScript.new())
	state.new_game("Robin", "warrior")
	state.spoils.hunted("tidecaller")
	var map := MapData.load_by_id("seacave_grotto")
	Depths.open_shortcut(map, state.progression.hunted)
	var rise := _rising(map, _lair_way_out(map, "seacave_grotto"))
	rise._process(StairRise.CRACK_S + StairRise.SINK_S / 2.0)
	assert_eq(rise.phase(), "sinking")
	state.world.map_id = "seacave_grotto"
	state.world.cell = Vector2i(24, 12)
	var reloaded: Node = autofree(GameStateScript.new())
	reloaded.apply(SaveCodec.reread(state.to_dict()))
	var woke := Depths.waking(reloaded.world.map_id, reloaded.world.cell)
	assert_eq(woke["mapId"], "seacave_grotto", "on the floor it was saved on")
	var again := MapData.load_by_id(woke["mapId"])
	assert_true(Depths.open_shortcut(again, reloaded.progression.hunted), "its door in the rock open")
	assert_eq(Depths.way_out_toward(again, "saltmere", woke["cell"]), Vector2i(30, 4), "and the arrow out by it")
