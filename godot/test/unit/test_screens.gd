extends GutTest
## Screens stack (PIX-199): the keys go to the top one only - the highest
## layer, the latest opened among equals - so a screen hidden under another
## (Morvax's throne under a rank-up) never takes a key meant for the one above.


func after_each() -> void:
	get_tree().paused = false


func _screen(layer: int) -> Screen:
	var screen := Screen.new()
	screen.layer = layer
	add_child(screen)
	return screen


func test_the_keys_go_to_the_screen_on_top() -> void:
	var rankup := _screen(6)
	var throne := _screen(5)
	assert_true(rankup.on_top(), "the higher layer, though opened first")
	assert_false(throne.on_top(), "the throne waits under the rank-up")
	rankup.close()
	await wait_physics_frames(1)
	assert_true(throne.on_top(), "its turn once the rank-up is gone")
	throne.close()


func test_among_equals_the_latest_takes_the_keys() -> void:
	var first := _screen(5)
	var second := _screen(5)
	assert_true(second.on_top())
	assert_false(first.on_top())
	second.close()
	first.close()
	await wait_physics_frames(1)
	assert_false(get_tree().paused, "the world runs again with every screen closed")
