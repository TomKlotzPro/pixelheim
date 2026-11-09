extends GutTest
## Everyone stands on the ground (PIX-441): the hero, villagers and foes each
## have one soft shadow under their feet (a boss's is the same one, PIX-314),
## planted where the squash and the walk don't move it, and never raised
## with a villager drawn over the hero (Npc.stands_over).

const PlayerScript := preload("res://scripts/player.gd")
const Enemy := preload("res://scripts/enemy.gd")


func _hero() -> CharacterBody2D:
	var hero: CharacterBody2D = PlayerScript.new()
	# Never run: its steps reach for a world the test has none of.
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(hero)
	return hero


## How far the shadow reaches past the feet of the frame the figure stands in.
func _past_the_feet(shadow: Sprite2D, sprite: AnimatedSprite2D, rest_y: float, size := 1.0) -> float:
	var frame := sprite.sprite_frames.get_frame_texture(PunyArt.pick(sprite.sprite_frames, "idle", "down"), 0)
	var feet := (Ink.used(frame).end.y - frame.get_height() / 2.0) * size + rest_y
	return shadow.position.y + shadow.texture.get_height() * size / 2.0 - feet


func test_the_hero_stands_on_one_shadow_the_squash_leaves_planted() -> void:
	var hero := _hero()
	var shadow: Sprite2D = hero._shadow
	assert_lt(shadow.get_index(), hero.sprite.get_index(), "drawn under them")
	assert_eq(_past_the_feet(shadow, hero.sprite, PunyArt.lift(hero.art)), 1.0, "a pixel past their feet")
	var at := shadow.position
	hero.squash = Vector2(1.3, 0.7)
	assert_eq(shadow.position, at, "the squash leaves it where it lies")
	assert_ne(hero.sprite.position.y, PunyArt.lift(hero.art), "though the sprite moved")


func test_a_new_sheet_lays_one_new_shadow() -> void:
	var hero := _hero()
	hero._lay_shadow()
	assert_eq(hero.get_children().filter(func(node: Node) -> bool: return node is Sprite2D and (node as Sprite2D).texture == hero._shadow.texture).size(), 1, "one shadow, no double")
	assert_lt(hero._shadow.get_index(), hero.sprite.get_index(), "still under them")


func test_a_villager_at_any_size_stands_on_theirs() -> void:
	for look: String in ["villager", "bram", "cat"]:
		var art := PunyArt.villager(look)
		var size: float = art.get("scale", 1.0)
		var sprite := AnimatedSprite2D.new()
		autofree(sprite)
		sprite.sprite_frames = PunyArt.frames(art)
		var shadow: Sprite2D = autofree(Enemy.ground_shadow(sprite, size, PunyArt.lift(art) * size))
		assert_almost_eq(_past_the_feet(shadow, sprite, PunyArt.lift(art) * size, size), size, 0.01, "%s: a pixel of theirs past their feet" % look)
		assert_false(shadow.z_as_relative, "%s: not raised over the hero with them (the hero's head would darken)" % look)
		assert_eq(shadow.z_index, 0, "%s: on the ground's own z" % look)
