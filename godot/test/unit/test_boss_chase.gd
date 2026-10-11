extends GutTest
## A living boss lets the hero go for good reasons (PIX-288, reopened: « les
## bosses sont toujours bloqués »). Old Greymaw never gave a chase up
## (PIX-232) and charged in a straight line: a hero who walked off, or stood
## across the river from him, kept him hunting for as long as he lived - his
## bar across the top of the screen and every road out of the Reach barred.
## Now a boss or a named monster gives up once it has lost the hero (off the
## screen and far behind), has no way to them, or stands stuck; a named
## monster of the wilds also goes back once led out of its ground; it walks
## round what stands between by a route; and it keeps its wounds.

const BossBarScript := preload("res://scripts/boss_bar.gd")

## Where the overworld's river runs (rows 28-31), with its one bridge at
## x 48-49: Greymaw on the road south of it, a hero on the ash north of it.
const SOUTH_BANK := Vector2i(70, 32)
const NORTH_BANK := Vector2i(70, 27)


## The Reach as a visit lays it (its scatter, props and shut gates
## covered), or `bare`, as its tiles alone (the bridge's gate open).
func _overworld(bare := false) -> MapData:
	var map := MapData.load_by_id("overworld")
	if not bare:
		MapView.new(map, null).plan(map.spawn)
	return map


func test_a_boss_past_the_screens_edge_has_lost_the_hero() -> void:
	var lose := Packs.tiles("bossLoseTiles")
	assert_true(Packs.lost(Vector2.ZERO, Vector2(lose + 16.0, 0)), "past the screen's edge: lost")
	assert_false(Packs.lost(Vector2.ZERO, Vector2(lose - 16.0, 0)), "still near: it hunts on")
	# Past the edge whichever way it lies: the screen at play zoom is some
	# 27 cells across and 13 down above the dock.
	assert_gt(lose, 13.0 * MapView.TILE, "beyond half the screen's width")


func test_a_named_monster_of_the_wilds_keeps_to_its_ground() -> void:
	var home := Vector2(100, 100)
	var leash := Packs.tiles("bossLeashTiles")
	var out := home + Vector2(leash + 16.0, 0)
	assert_true(Packs.strays(home, out, out + Vector2(Packs.tiles("noticeTiles") + 16.0, 0)), "led out and the hero gone on: home")
	assert_false(Packs.strays(home, out, out + Vector2(16, 0)), "the hero fighting it at its ground's edge keeps it there")
	assert_false(Packs.strays(home, home + Vector2(leash - 16.0, 0), home + Vector2(400, 0)), "within its ground it hunts on")


func test_the_wilds_named_monsters_keep_to_a_ground_and_dungeon_bosses_to_their_hall() -> void:
	for named_id: String in ["greymaw", "drowned_knight", "cinderjaw", "mossback", "gulp"]:
		assert_true(Hunts.of_the_wilds(named_id), "%s keeps to its ground" % named_id)
	for named_id: String in ["tidecaller", "seam_warden", "hollow_captain", "rimefang"]:
		assert_false(Hunts.of_the_wilds(named_id), "%s fights anywhere in its hall (PIX-232)" % named_id)
	assert_false(Hunts.of_the_wilds(""))


func test_a_straight_line_over_water_is_no_way() -> void:
	var map := _overworld(true)
	assert_false(Packs.walks_straight(map, MapView.center(SOUTH_BANK), MapView.center(NORTH_BANK)), "the river between")
	assert_true(Packs.walks_straight(map, MapView.center(Vector2i(48, 34)), MapView.center(Vector2i(48, 26))), "over the bridge")


func test_across_the_river_there_is_no_way_near_enough() -> void:
	var map := _overworld()
	var area := Packs.route_area(SOUTH_BANK, NORTH_BANK, 8)
	var grid := Packs.route_grid(map, area)
	assert_eq(Packs.route(grid, SOUTH_BANK, NORTH_BANK), [] as Array[Vector2i], "no way within eight cells of both")
	# The whole Reach has one once the bridge's gate is open, twenty cells
	# off: too far round.
	var open := _overworld(true)
	var whole := Packs.route_grid(open, Rect2i(Vector2i.ZERO, open.size))
	var around := Packs.route(whole, SOUTH_BANK, NORTH_BANK)
	assert_gt(around.size(), 40, "by the bridge")
	assert_true(around.has(Vector2i(48, 30)) or around.has(Vector2i(49, 30)), "over the bridge")


func test_a_route_goes_round_a_wall_cell_by_cell_never_through_it() -> void:
	var map := _overworld()
	# The town's rampart stands between (36..61, 42..55): round its corner.
	var from := Vector2i(58, 57)
	var to := Vector2i(58, 40)
	assert_false(Packs.walks_straight(map, MapView.center(from), MapView.center(to)), "no straight line through the walls")
	var grid := Packs.route_grid(map, Packs.route_area(from, to, 8))
	var way := Packs.route(grid, from, to)
	assert_false(way.is_empty(), "a way along the open ground")
	assert_eq(way[0], from)
	assert_eq(way[-1], to)
	for i in range(1, way.size()):
		var step: Vector2i = way[i] - way[i - 1]
		assert_true(absi(step.x) <= 1 and absi(step.y) <= 1, "one cell at a time")
		assert_true(map.is_walkable(way[i]), "%s is open ground" % way[i])
		if step.x != 0 and step.y != 0:
			assert_true(map.is_walkable(way[i - 1] + Vector2i(step.x, 0)) and map.is_walkable(way[i - 1] + Vector2i(0, step.y)), "no corner cut at %s" % way[i])


func test_a_route_never_takes_a_doorway() -> void:
	var map := _overworld()
	var door := Vector2i(48, 42)
	assert_true(map.portals.has(door), "the town's gate")
	var grid := Packs.route_grid(map, Packs.route_area(Vector2i(44, 40), Vector2i(52, 40), 8))
	assert_true(grid.is_point_solid(door), "a foe never leaves its map")


func test_the_ends_of_a_route_count_as_open() -> void:
	var map := _overworld()
	var grid := Packs.route_grid(map, Packs.route_area(SOUTH_BANK, SOUTH_BANK + Vector2i(4, 0), 8))
	grid.set_point_solid(SOUTH_BANK)
	assert_false(Packs.route(grid, SOUTH_BANK, SOUTH_BANK + Vector2i(4, 0)).is_empty(), "feet reaching into a covered cell's open half")
	assert_true(grid.is_point_solid(SOUTH_BANK), "and the grid is left as it was")
	assert_eq(Packs.route(grid, Vector2i(-50, -50), SOUTH_BANK), [] as Array[Vector2i], "nothing from outside the grid")


func test_every_lair_has_open_ground_round_it() -> void:
	for entry in Hunts.all():
		if entry.has("deepDepth"):
			continue
		var map := MapData.load_by_id(entry["mapId"])
		MapView.new(map, null).plan(map.spawn)
		var lair := Hunts.lair(entry)
		assert_true(map.is_walkable(lair), "%s's lair is open, its scatter and props laid" % entry["id"])
		# Room to fight in: the open cells it walks to within four steps.
		var grid := Packs.route_grid(map, Packs.route_area(lair, lair, 4))
		var reached := 0
		for y in range(lair.y - 4, lair.y + 5):
			for x in range(lair.x - 4, lair.x + 5):
				var cell := Vector2i(x, y)
				if cell != lair and map.is_walkable(cell) and not Packs.route(grid, lair, cell).is_empty():
					reached += 1
		assert_gt(reached, 30, "%s isn't boxed in at its lair" % entry["id"])


## Just enough of a foe for the bar to follow (as test_boss_end's).
class Foe:
	extends Node
	var fighter := {"id": "wolf", "name": "Old Greymaw", "hp": 120, "maxHp": 120, "named": "greymaw"}
	var dying := false
	var hunting := true


func test_a_boss_that_gives_up_takes_its_bar_and_brings_it_back_as_it_was() -> void:
	var bar: Control = BossBarScript.new()
	add_child_autofree(bar)
	var foe: Foe = autofree(Foe.new())
	bar.follow(foe)
	foe.fighter["hp"] = 66
	for i in 20:
		bar._process(0.1)
	assert_eq(bar.reading(), "55%")
	# Led out of its ground, it walks home: out of the fight, alive.
	foe.hunting = false
	for i in 20:
		bar._process(0.1)
	assert_false(bar.showing(), "its bar goes")
	assert_false(bar.following(), "and follows nothing, so the next hunt takes it up")
	# Home with its wounds (enemy._settle), it takes the fight up again: the
	# soundscape gives the bar to a boss on the hunt it isn't following.
	foe.hunting = true
	bar.follow(foe)
	for i in 5:
		bar._process(0.1)
	assert_true(bar.showing())
	assert_eq(bar.reading(), "55%", "as it was")


func test_a_boss_that_turns_back_as_its_bar_fades_keeps_it() -> void:
	var bar: Control = BossBarScript.new()
	add_child_autofree(bar)
	var foe: Foe = autofree(Foe.new())
	bar.follow(foe)
	for i in 5:
		bar._process(0.1)
	foe.hunting = false
	bar._process(0.1)
	assert_true(bar.showing(), "fading")
	foe.hunting = true
	assert_true(bar.following(), "still its bar: nothing new to follow")
	for i in 5:
		bar._process(0.1)
	assert_eq(bar.modulate.a, 1.0, "back in full")
	assert_eq(bar.reading(), "100%")
