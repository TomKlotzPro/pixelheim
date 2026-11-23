extends GutTest
## Light and darkness (PIX-221): the day's colours on its wheel, how dark
## each place is, lights that come up with the dark and flicker if they
## burn, and the world's words that the dark doesn't touch.


func after_each() -> void:
	GameState.progression.prologue = Prologue.DONE


func _at(share: float) -> float:
	return share * DayNight.DAY_CYCLE_STEPS


func test_the_day_turns_gold_then_peach_rose_violet_and_blue() -> void:
	# The golden hours (PIX-526): a pale gold morning, two hours of evening.
	assert_eq(Lights.outdoor(0.0), Lights.MORNING, "six is pale gold")
	assert_ne(Lights.outdoor(0.0), Lights.DAY, "six is no longer noon")
	assert_eq(Lights.outdoor(_at(2.0 / 24.0)), Lights.DAY, "plain daylight from eight")
	assert_eq(Lights.outdoor(_at(0.2)), Lights.DAY, "plain daylight")
	assert_eq(Lights.outdoor(_at(12.0 / 24.0)), Lights.PEACH, "peach at six in the evening")
	assert_eq(Lights.outdoor(_at(13.0 / 24.0)), Lights.ROSE, "rose at seven")
	assert_eq(Lights.outdoor(_at(14.0 / 24.0)), Lights.VIOLET, "violet at eight")
	assert_eq(Lights.outdoor(_at(0.75)), Lights.NIGHT, "a blue night")
	assert_eq(Lights.outdoor(_at(0.86)), Lights.NIGHT, "the night's end kept")
	assert_eq(Lights.outdoor(_at(0.93)), Lights.DAWN, "a gold dawn, where the Bells' dawn reads it")
	var wrap := Lights.outdoor(_at(1.0) - 0.01)
	assert_almost_eq(wrap.g, Lights.MORNING.g, 0.001, "the wheel comes round to the morning")
	assert_almost_eq(wrap.b, Lights.MORNING.b, 0.001)
	assert_eq(Lights.darkness(Lights.DAY), 0.0, "no lamp shows by day")
	assert_eq(Lights.darkness(Lights.NIGHT), 1.0, "every lamp shows at night")
	assert_lt(Lights.darkness(Lights.MORNING), 0.1, "the morning is bright")
	assert_lt(Lights.darkness(Lights.PEACH), Lights.darkness(Lights.ROSE), "the evening deepens")
	assert_lt(Lights.darkness(Lights.ROSE), Lights.darkness(Lights.VIOLET))
	assert_lt(Lights.darkness(Lights.VIOLET), 1.0, "and is not yet night")
	assert_true(Lights.PEACH.r > Lights.PEACH.g and Lights.PEACH.g > Lights.PEACH.b, "peach leans warm")
	assert_gte(Lights.ROSE.b, Lights.ROSE.g, "rose leans pink, not orange")
	assert_true(Lights.VIOLET.b > Lights.VIOLET.r and Lights.VIOLET.b > Lights.VIOLET.g, "violet leans blue")
	assert_eq(Lights.MORNING.r, 1.0, "the morning gold, never grey")


func test_each_place_has_its_own_dark() -> void:
	var rig: Node = autofree(LightRig.new())
	var floor := MapData.new()
	floor.style = "cave"
	assert_eq(rig.light_for(floor), Lights.UNDERGROUND, "under the ground, whatever the hour")
	var room := MapData.load_by_id("town_inn")
	GameState.world.steps = _at(0.2)
	assert_eq(rig.light_for(room), Lights.INDOOR_DAY)
	GameState.world.steps = _at(0.75)
	assert_eq(rig.light_for(room), Lights.INDOOR_NIGHT, "a room at night, kinder than outside")
	var town := MapData.load_by_id("town")
	GameState.progression.prologue = Prologue.SCAVENGER
	assert_eq(rig.light_for(town), Lights.ASH_NIGHT, "the night the village burns")
	rig.ash_dawn = 1.0
	assert_eq(rig.light_for(town), Lights.ASH_DAWN, "and its dawn, grey over the ashes (PIX-543)")
	assert_lt(Lights.darkness(Lights.ASH_DAWN), Lights.RIM_DUSK, "light enough that nothing rims or burns as at night")


## The moon shone through the Night of Ash's smoke from the first frame of
## its dawn's pan: the night was told by its colour, which the dawn greys.
func test_no_moon_through_the_night_of_ashs_smoke_or_its_dawn() -> void:
	var rig: LightRig = autofree(LightRig.new())
	var town := MapData.load_by_id("town")
	assert_eq(rig.moon(town, 1.0, 0.0), 1.0, "a clear night's moon")
	assert_eq(rig.moon(town, 1.0, 1.0), 0.0, "none through cloud")
	GameState.progression.prologue = Prologue.SCAVENGER
	for share: float in [0.0, 0.01, 0.5, 1.0]:
		rig.ash_dawn = share
		assert_eq(rig.moon(town, Lights.darkness(rig.light_for(town)), 0.0), 0.0, "none through the smoke, the dawn %s in" % share)
	var floor := MapData.new()
	floor.style = "cave"
	assert_eq(rig.moon(floor, 1.0, 0.0), 0.0, "none under the ground")


## The moon's rim on what stands (PIX-545): a clear night's under the sky
## alone, and the lightning's, as bright as its flash, never the soft kind.
func test_the_moon_and_the_lightning_rim_what_stands() -> void:
	var rim_on := LightRig.rim_on
	LightRig.rim_on = true
	var rig: LightRig = autofree(LightRig.new())
	var town := MapData.load_by_id("town")
	assert_eq(rig.moon_rim(town, 1.0, 0.0), Lights.RIM, "whole under a clear night's moon")
	assert_eq(rig.moon_rim(town, 1.0, 1.0), 0.0, "none through cloud")
	assert_almost_eq(rig.moon_rim(town, 1.0, 0.5), 0.5 * Lights.RIM, 0.001, "half through half a sky of it")
	assert_eq(rig.moon_rim(town, 0.0, 0.0), 0.0, "none by day")
	assert_eq(rig.moon_rim(town, Lights.RIM_DUSK, 0.0), 0.0, "none until the dusk")
	var floor := MapData.new()
	floor.style = "cave"
	assert_eq(rig.moon_rim(floor, 1.0, 0.0), 0.0, "none under the ground")
	assert_eq(rig.moon_rim(MapData.load_by_id("town_smith"), 1.0, 0.0), 0.0, "none in a room")
	GameState.progression.prologue = Prologue.SCAVENGER
	assert_eq(rig.moon_rim(town, Lights.darkness(rig.light_for(town)), 0.0), 0.0, "none through the Night of Ash's smoke")
	assert_eq(LightRig.flash_rim(1.0, 1.0, false), Lights.RIM, "the lightning's, whole at its flash's height at night")
	assert_eq(LightRig.flash_rim(1.0, 0.25, false), 0.25 * Lights.RIM, "fading as the flash does")
	assert_eq(LightRig.flash_rim(1.0, 0.0, false), 0.0, "none between two strikes")
	assert_eq(LightRig.flash_rim(0.0, 1.0, false), 0.0, "none by day")
	assert_eq(LightRig.flash_rim(1.0, Weather.SOFT_LIGHT, true), 0.0, "none for the soft flash (Reduce motion, Flashes off)")
	LightRig.rim_on = false
	assert_eq(rig.moon_rim(MapData.load_by_id("town"), 1.0, 0.0) + LightRig.flash_rim(1.0, 1.0, false), 0.0, "--rim off holds both back")
	LightRig.rim_on = rim_on


func test_a_light_comes_up_with_the_dark_and_fire_flickers() -> void:
	var lamp := Lights.make(Vector2(10, 20), 64.0, Lights.LAMP, 0.5, true)
	autofree(lamp)
	assert_eq(lamp.energy, 0.0, "the rig brings it up")
	assert_eq(float(lamp.get_meta("energy")), 0.5)
	assert_true(lamp.get_meta("flicker"))
	assert_true(lamp.is_in_group("lights"))
	assert_almost_eq(lamp.texture_scale * Lights.TEXTURE_PX, 128.0, 0.01, "reaching its radius")


func test_the_worlds_words_stay_bright() -> void:
	var tag: PanelContainer = autofree(PanelContainer.new())
	var label := Label.new()
	tag.add_child(label)
	Lights.unshade(tag)
	assert_eq((tag.material as CanvasItemMaterial).light_mode, CanvasItemMaterial.LIGHT_MODE_UNSHADED)
	assert_true(label.use_parent_material, "and what's in it")
	assert_eq(Lights.glow().blend_mode, CanvasItemMaterial.BLEND_MODE_ADD)
	assert_eq(Lights.glow().light_mode, CanvasItemMaterial.LIGHT_MODE_UNSHADED, "a glow is added to the night, not darkened by it")


## PIX-222: the glow sits between the world and the HUD, and can be turned off.
func test_the_glow_sits_under_the_hud_and_can_be_turned_off() -> void:
	assert_lt(LightRig.GLOW_LAYER, 2, "under the HUD's layer, so the HUD never blooms")
	assert_eq(LightRig.GLOW_DAY, 0.0, "sunlit sand doesn't bloom")
	assert_gt(LightRig.GLOW_NIGHT, 0.0)
	var path := "user://test_glow_settings.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var settings := GameSettings.new(path)
	assert_true(settings.glow, "on unless turned off")
	settings.glow = false
	settings.save_file()
	var again := GameSettings.new(path)
	again.load_file()
	assert_false(again.glow, "remembered")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var shader := preload("res://shaders/bloom.gdshader")
	assert_string_contains(shader.code, "hint_screen_texture", "it blooms what the world drew")
