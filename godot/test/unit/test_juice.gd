extends GutTest
## How a fight feels (PIX-226): the flash and the dissolve on a fighter's own
## material, the slash's colour and arc, and what a fallen foe leaves.


func test_each_fighter_flashes_on_its_own() -> void:
	var one := Juice.fighter_material()
	var two := Juice.fighter_material()
	assert_ne(one, two, "a blow on one doesn't flash the pack")
	assert_eq(one.shader, Juice.FIGHTER_SHADER)
	var sprite: Sprite2D = autofree(Sprite2D.new())
	add_child(sprite)
	sprite.material = one
	Juice.flash(sprite)
	assert_eq(float(one.get_shader_parameter("flash")), 1.0, "pure white at the blow")
	var code: String = Juice.FIGHTER_SHADER.code
	assert_string_contains(code, "TEXTURE_PIXEL_SIZE", "it dissolves by the art's own pixels")


func test_the_slash_wears_the_weapons_colour() -> void:
	assert_eq(Juice.slash_color("staff", "epic"), Juice.ARCANE, "a staff's arc is arcane")
	assert_eq(Juice.slash_color("sword", ""), Juice.STEEL)
	assert_eq(Juice.slash_color("sword", "fine"), UiStyle.FINE)
	assert_eq(Juice.slash_color("sword", "epic"), UiStyle.EPIC)
	var arc := Juice.arc().get_image()
	var lit := 0
	for y in arc.get_height():
		for x in arc.get_width():
			if arc.get_pixel(x, y).a > 0.0:
				lit += 1
	assert_gt(lit, 20, "a crescent of pixels")
	for facing: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var turns := Juice.arc_turn(facing) / (PI / 2.0)
		assert_almost_eq(turns, roundf(turns), 0.0001, "quarter turns only: the pixels stay square")


func test_a_fallen_foe_leaves_embers_or_dust() -> void:
	assert_ne(Juice.remains_color("fireborn"), Juice.remains_color("beasts"), "embers from the fireborn")
	assert_ne(Juice.remains_color("undead"), Juice.remains_color("beasts"), "cold motes from the undead")
	var remains: CPUParticles2D = autofree(Motes.make_remains())
	assert_true(remains.one_shot)
	assert_lt(remains.gravity.y, 0.0, "they drift up")


func test_the_hero_springs_back_with_feet_on_the_ground() -> void:
	assert_gt(Juice.SET_OFF.y, 1.0, "taller setting off")
	assert_lt(Juice.LAND.y, 1.0, "flatter landing a roll")
	assert_gt(Juice.FEET, 0.0)
