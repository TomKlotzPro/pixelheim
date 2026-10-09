extends GutTest
## Weak monsters flee a much stronger hero (PIX-251): six levels below the
## hero (an elite counting two higher) a monster runs instead of charging -
## never a boss, a Deep Hunt warden or a named monster, nor one held to its
## fight (an escort's attackers, the Night of Ash's foes, a mimic just woken,
## a boss's raised dead). It runs away over open ground in its region, never
## through a doorway, turns to fight only when cornered, and calms down once
## far enough away.

const Enemy := preload("res://scripts/enemy.gd")
const Escort := preload("res://scripts/escort.gd")
const TILE := 16.0


func test_the_margin_is_six_levels() -> void:
	assert_eq(int(Packs.rules()["fleeLevels"]), 6, "the number lives with the packs' rules")
	var slime := Bestiary.spawn("slime")
	assert_eq(Bestiary.level_of(slime), 1)
	assert_false(Enemy.flees_from(slime, 6), "five levels up: it still charges")
	assert_true(Enemy.flees_from(slime, 7), "six levels up: it runs")
	assert_true(Enemy.flees_from(slime, 40))
	var wolf := Bestiary.spawn("wolf")
	assert_false(Enemy.flees_from(wolf, 9))
	assert_true(Enemy.flees_from(wolf, 10))
	assert_false(Enemy.flees_from(slime, 1), "a match fights")


func test_an_elite_counts_two_levels_higher() -> void:
	assert_eq(int(Packs.rules()["fleeEliteLevels"]), 2)
	var elite := Bestiary.spawn("slime", true)
	assert_false(Enemy.flees_from(elite, 8), "an elite slime stands where a plain one runs")
	assert_true(Enemy.flees_from(elite, 9))
	assert_true(Packs.outmatched(1, false, 7))
	assert_false(Packs.outmatched(1, true, 7))


func test_a_lifted_foe_counts_its_lifted_level() -> void:
	# The mountain's floors lift their foes above their kind (PIX-170).
	var lifted := Bestiary.spawn("slime", false, 10)
	assert_eq(Bestiary.level_of(lifted), 11)
	assert_false(Enemy.flees_from(lifted, 16))
	assert_true(Enemy.flees_from(lifted, 17))


func test_bosses_and_named_monsters_never_run() -> void:
	for boss: String in Bestiary._data()["bossIds"]:
		assert_false(Enemy.flees_from(Bestiary.spawn(boss), 999), "%s never runs" % boss)
	for entry: Dictionary in Hunts.all():
		var fighter := Hunts.fighter(entry["id"])
		assert_false(Enemy.flees_from(fighter, 999), "%s never runs" % entry["id"])


func test_a_deep_hunt_warden_never_runs() -> void:
	# A warden is a boss under the deep's name: should one ever be another
	# kind, it must be kept from running some other way.
	for warden: Dictionary in Bestiary._data()["deepHunt"]["wardens"]:
		assert_true(Bestiary.is_boss(warden["monsterId"]), "%s is a boss" % warden["name"])
	var depth := int(Bestiary._data()["deepHunt"]["bossEvery"])
	assert_true(Dungeons.is_warden_depth(depth))
	var guard: Dictionary = Dungeons.deep_def(depth)["encounters"][-1]
	assert_true(guard.get("warden", false), "the depth's last foe is its warden")
	var fighter := Bestiary.spawn(guard["monsterId"], false, int(guard["lift"]))
	assert_false(Enemy.flees_from(fighter, 999))


func test_a_foe_held_to_its_fight_never_runs() -> void:
	assert_false(Enemy.flees_from(Bestiary.spawn("slime"), 99, true))


func test_what_holds_a_foe_to_its_fight() -> void:
	assert_false(_foe().held_to_fight(), "a wild slime is free to run")
	var scavenger := _foe()
	scavenger.set_meta("prologue", true)
	assert_true(scavenger.held_to_fight(), "the Night of Ash's scavenger")
	var hound := _foe()
	hound.set_meta("prologue_wave", true)
	assert_true(hound.held_to_fight(), "a wave of the night's foes")
	var mimic := _foe()
	mimic.woken = true
	assert_true(mimic.held_to_fight(), "a mimic just burst from its chest")
	var raised := _foe()
	raised.add_to_group("summoned")
	assert_true(raised.held_to_fight(), "the dead a boss raised")
	var ambusher := _foe()
	var wagon: Escort = autofree(Escort.new())
	ambusher.quarry = wagon
	assert_true(ambusher.held_to_fight(), "sent at the escort's wagon")
	wagon.done = true
	assert_false(ambusher.held_to_fight(), "the escort over, it is a wild foe again")


func test_it_runs_straight_away_over_open_ground() -> void:
	var map := _field()
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3)), Vector2i.RIGHT, "away from a hero to its west")
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(5, 1)), Vector2i.DOWN)
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(3, 1)), Vector2i(1, 1), "a hero off its corner: the diagonal")
	assert_eq(Packs.middle(Vector2i(6, 3)), _center(6, 3), "it heads for the next cell's middle")


func test_a_wall_turns_it_aside_never_back() -> void:
	var map := _field()
	for y in 7:
		map.grid[Vector2i(6, y)] = "wall"
	var step := Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3))
	assert_ne(step, Vector2i.ZERO, "along the wall")
	assert_eq(step.x, 0, "sideways, square to the hero, never back toward them")


func test_it_never_cuts_a_blocked_corner() -> void:
	var map := _field()
	map.grid[Vector2i(6, 3)] = "wall"
	map.grid[Vector2i(5, 4)] = "wall"
	var step := Packs.flight_step(map, "forest", _center(5, 3), _center(4, 2))
	assert_ne(step, Vector2i(1, 1), "not between two walls' corners")


func test_it_never_runs_through_a_doorway() -> void:
	var map := _field()
	map.portals[Vector2i(6, 3)] = {"kind": "map", "mapId": "town"}
	var step := Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3))
	assert_ne(step, Vector2i.RIGHT, "not into the way out")
	assert_ne(step, Vector2i.ZERO, "round it")


func test_a_body_in_the_way_shuts_that_cell() -> void:
	var map := _field()
	var step := Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3), [Vector2i(6, 3)])
	assert_ne(step, Vector2i.RIGHT, "a packmate stands there")
	assert_eq(step.x, 1, "still away from the hero")


func test_it_keeps_to_its_region_while_it_can() -> void:
	var map := _field()
	for y in 7:
		map.regions.erase(Vector2i(6, y))
	map.regions.erase(Vector2i(5, 2))
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3)), Vector2i.DOWN, "down its own region's edge, not out of it")
	map.regions.erase(Vector2i(5, 4))
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3)), Vector2i.RIGHT, "with no way on inside, out onto the open ground: an unseen line is no corner")


func test_it_slips_round_a_walls_end_beside_the_hero() -> void:
	var map := _field()
	# Walls east and south, the hero west and a little above: north leads a
	# touch back across the hero's way, and is the way out.
	for cell: Vector2i in [Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(5, 4), Vector2i(4, 4)]:
		map.grid[cell] = "wall"
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3) - Vector2(0, 6)), Vector2i.UP)
	# Further back than that, it would be running at the hero: cornered.
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(4, 2)), Vector2i.ZERO)


func test_cornered_it_turns() -> void:
	var map := _field()
	# A nook: walls east, north and south of it, the hero at its mouth.
	for cell: Vector2i in [Vector2i(6, 2), Vector2i(6, 3), Vector2i(6, 4), Vector2i(5, 2), Vector2i(5, 4), Vector2i(4, 2), Vector2i(4, 4)]:
		map.grid[cell] = "wall"
	assert_eq(Packs.flight_step(map, "forest", _center(5, 3), _center(3, 3)), Vector2i.ZERO, "nowhere left to run")


func test_far_enough_it_calms_down() -> void:
	assert_eq(int(Packs.rules()["calmTiles"]), 8)
	var at := Vector2(100, 100)
	assert_false(Packs.calmed(at, at + Vector2(8 * TILE, 0)))
	assert_true(Packs.calmed(at, at + Vector2(8 * TILE + 1, 0)))


## A wild slime, not in the tree (its rules need no world).
func _foe() -> Enemy:
	var foe: Enemy = autofree(Enemy.new())
	foe.fighter = Bestiary.spawn("slime")
	return foe


## A grass field 12 by 7, all of it the forest's region.
func _field() -> MapData:
	var map := MapData.new()
	map.size = Vector2i(12, 7)
	for y in 7:
		for x in 12:
			map.grid[Vector2i(x, y)] = "grass"
			map.regions[Vector2i(x, y)] = "forest"
	return map


func _center(x: int, y: int) -> Vector2:
	return (Vector2(x, y) + Vector2(0.5, 0.5)) * TILE
