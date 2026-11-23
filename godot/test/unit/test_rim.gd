extends GutTest
## The lights' rim (PIX-531): its strength by how dark it is (none by day nor
## by a room's dim day), what the LightRig hands the shaders, which shaders
## take it (only what stands: the characters, the domed props, the
## see-through ones; never the ground, a house or a lamp's own post), and the
## villagers' one shared material.

var _rim_on := true


func before_each() -> void:
	_rim_on = LightRig.rim_on


func after_each() -> void:
	LightRig.rim_on = _rim_on


func test_none_by_day_whole_in_the_dark() -> void:
	LightRig.rim_on = true
	assert_eq(LightRig.rim_strength(0.0), 0.0, "none by day")
	assert_eq(LightRig.rim_strength(Lights.darkness(Lights.INDOOR_DAY)), 0.0, "none by a room's dim day")
	assert_eq(LightRig.rim_strength(Lights.RIM_DUSK), 0.0, "none until the dusk")
	assert_eq(LightRig.rim_strength(Lights.LANTERN_DARK), Lights.RIM, "whole where the hand lantern lights")
	assert_eq(LightRig.rim_strength(1.0), Lights.RIM, "whole at night")
	LightRig.rim_on = false
	assert_eq(LightRig.rim_strength(1.0), 0.0, "--rim off holds it back")


func test_the_rig_hands_the_shaders_the_rim() -> void:
	assert_true(ProjectSettings.has_setting("shader_globals/light_rim"), "a global the shaders read")
	var rig := FileAccess.get_file_as_string("res://scripts/light_rig.gd")
	assert_string_contains(rig.substr(rig.find("func _process(")), "global_shader_parameter_set(\"light_rim\", rim_strength(dark))", "set every frame")


## Only what stands takes the rim, through the relief's one light().
func test_only_what_stands_is_rimmed() -> void:
	var rimmed := ["fighter.gdshader", "relief.gdshader", "see_through.gdshader"]
	for file in DirAccess.get_files_at("res://shaders"):
		if not file.ends_with(".gdshader"):
			continue
		var code := FileAccess.get_file_as_string("res://shaders/" + file)
		if file in rimmed:
			var define := code.find("#define RELIEF_RIM")
			assert_gt(define, -1, "%s rims" % file)
			assert_lt(define, code.find("#include \"res://shaders/relief.gdshaderinc\""), "%s defines it before the include" % file)
			assert_string_contains(code, "rim_open = ", "%s finds its open sides" % file)
		else:
			assert_false(code.contains("RELIEF_RIM"), "%s never rims (the ground, houses, dungeon floors)" % file)
	var include := FileAccess.get_file_as_string("res://shaders/relief.gdshaderinc")
	var block := include.substr(include.find("#ifdef RELIEF_RIM\n\t"))
	block = block.substr(0, block.find("#endif"))
	assert_string_contains(block, "!LIGHT_IS_DIRECTIONAL", "never from the lightning")
	assert_string_contains(block, "light_rim > 0.0", "nothing by day")


## A carved or plain piece never rims, nor a lamp's own post (its light pools
## at its foot, between its lanterns); every other domed piece does.
func test_a_lamps_post_is_never_rimmed() -> void:
	var post := Relief.lamp_post()
	assert_eq(post, Relief.lamp_post(), "one for every post")
	assert_eq(post.get_shader_parameter("relief_form"), Relief.DOMED, "domed as every prop")
	assert_eq(post.get_shader_parameter("relief_rimmed"), false, "never rimmed")
	assert_ne(Relief.material(Relief.DOMED, false).get_shader_parameter("relief_rimmed"), false, "a prop is")
	assert_string_contains(FileAccess.get_file_as_string("res://scripts/map_layers/props_layer.gd"), "post.material = Relief.lamp_post()")


## The villagers share one material of the fighters' shader (never flashed
## nor dissolved, so they still draw together); the hero and each foe keep
## their own.
func test_the_villagers_share_the_fighters_shader() -> void:
	var folk := Npc.rim_material()
	assert_eq(folk.shader, Juice.FIGHTER_SHADER, "rimmed as the hero and the foes")
	assert_eq(Npc.rim_material(), folk, "one for every villager")
	assert_string_contains(FileAccess.get_file_as_string("res://scripts/npc.gd"), "sprite.material = rim_material()")
	assert_ne(Juice.fighter_material(), Juice.fighter_material(), "a fighter's own")
