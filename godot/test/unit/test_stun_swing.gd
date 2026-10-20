extends GutTest
## A stun landing mid-swing (PIX-333, Tom: « des fois quand trop d'ennemis
## j'peux plus attaquer et j'peux plus rien faire »): the swing ends with it,
## so once the stun wears off the hero swings again.

const PlayerScript := preload("res://scripts/player.gd")


func test_a_stun_mid_swing_ends_the_swing() -> void:
	var hero: CharacterBody2D = PlayerScript.new()
	# Never run: its steps reach for a world the test has none of.
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	add_child_autofree(hero)
	hero.attack()
	assert_true(hero.attacking, "the swing is on")
	hero.ailments.inflict({"kind": "stun", "chance": 1.0, "turns": 1, "power": 0}, func() -> float: return 0.0)
	assert_true(hero._held_by_stun(), "the stun holds the hero")
	assert_false(hero.attacking, "and ends the swing")
	assert_false(hero.casting, "a cast too")
	assert_false(hero.hitbox.monitoring, "the blade no longer bites")
	hero.ailments.clear()
	assert_false(hero._held_by_stun(), "the stun worn off")
	hero.attack_ready = true
	hero.attack()
	assert_true(hero.attacking, "the hero swings again")
