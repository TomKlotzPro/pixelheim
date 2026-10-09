extends GutTest
## The small life of the world (PIX-225): fireflies by the hour and the
## place, what the hero's feet kick up, which foes throw sparks, what glows
## in the dark and what takes the scene's light, and the perf guard's count.


func after_each() -> void:
	GameState.progression.prologue = Prologue.DONE


func test_fireflies_come_out_at_dusk_and_night_in_the_open() -> void:
	var overworld := MapData.load_by_id("overworld")
	assert_eq(Motes.fireflies(overworld, "", 0.0, 0.0), 0.0, "none by day")
	assert_eq(Motes.fireflies(overworld, "", 1.0, 0.0), 1.0, "all of them at night")
	assert_between(Motes.fireflies(overworld, "woods", 0.5, 0.0), 0.01, 0.99, "the first at dusk")
	assert_eq(Motes.fireflies(overworld, "", 1.0, 1.0), 0.0, "none in the rain")
	for air: String in Motes.NO_FIREFLIES:
		assert_eq(Motes.fireflies(overworld, air, 1.0, 0.0), 0.0, "none in the %s air" % air)
	assert_eq(Motes.fireflies(MapData.load_by_id("town_inn"), "", 1.0, 0.0), 0.0, "none indoors")
	var town := MapData.load_by_id("town")
	assert_eq(Motes.fireflies(town, "", 1.0, 0.0), 1.0, "over the village's green")
	GameState.progression.prologue = Prologue.SCAVENGER
	assert_eq(Motes.fireflies(town, "", 1.0, 0.0), 0.0, "but not the night it burns")


func test_feet_kick_up_dust_or_splash() -> void:
	assert_eq(Motes.footfall("path"), "dust")
	assert_eq(Motes.footfall("snow"), "dust", "snow puffs too")
	assert_eq(Motes.footfall("marsh"), "splash", "wading through a bog")
	assert_eq(Motes.footfall("grass"), "", "grass keeps quiet")
	assert_eq(Motes.footfall("floor"), "")
	for tile: String in Motes.DUST:
		assert_true(WorldTiles.is_walkable(tile), "%s is walked on" % tile)


func test_steel_sparks_off_armour() -> void:
	var monsters: Dictionary = Bestiary._data()["monsters"]
	for id: String in Motes.ARMOURED:
		assert_true(monsters.has(id), "%s is a foe" % id)
	assert_true(Motes.sparks_off("orc"))
	assert_true(Motes.sparks_off("golem"))
	assert_false(Motes.sparks_off("slime"), "no sparks off a slime")
	assert_false(Motes.sparks_off("wolf"))


func test_what_glows_glows_and_the_rest_takes_the_light() -> void:
	for node: CPUParticles2D in [Motes.make_fireflies(), Motes.make_embers(), Motes.make_sparks()]:
		autofree(node)
		assert_eq(node.material, Lights.glow(), "it glows in the dark")
	for node: CPUParticles2D in [Motes.make_leaves(), Motes.make_dust(), Motes.make_splash()]:
		autofree(node)
		assert_null(node.material, "it takes the scene's light")
	for node: CPUParticles2D in [Motes.make_dust(), Motes.make_splash(), Motes.make_sparks()]:
		autofree(node)
		assert_true(node.one_shot, "a burst, fired when needed")
		assert_false(node.emitting, "and quiet until then")


func test_the_perf_guard_counts_particles() -> void:
	var root: Node2D = autofree(Node2D.new())
	var on := Motes.make_embers(5)
	on.emitting = true
	root.add_child(on)
	var off := Motes.make_sparks()
	root.add_child(off)
	assert_eq(PerfProbe.particles(root), 5, "only what's emitting")
