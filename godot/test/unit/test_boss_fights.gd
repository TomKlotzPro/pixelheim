extends GutTest
## A boss fight ends clearly (PIX-232): a named monster like Rimefang fights
## and falls as a boss does, and neither gives up the chase to walk home and
## heal while an ordinary foe still does.

const Enemy := preload("res://scripts/enemy.gd")
const HOME := Vector2.ZERO
## Far past any leash, from home and from the hero.
const FAR := Vector2(4000, 0)
const HERO := Vector2(8000, 0)


func test_bosses_and_named_monsters_fight_like_bosses() -> void:
	assert_true(Bestiary.fights_like_boss(Bestiary.spawn("dragon")), "a boss")
	assert_true(Bestiary.fights_like_boss(Hunts.fighter("rimefang")), "Rimefang, a named frost drake")
	assert_false(Bestiary.is_boss(String(Hunts.fighter("rimefang")["id"])), "though its kind is no boss")
	assert_false(Bestiary.fights_like_boss(Bestiary.spawn("wolf")), "a wolf")


func test_only_ordinary_foes_give_up_the_chase() -> void:
	assert_true(Enemy.gives_up(Bestiary.spawn("wolf"), HOME, FAR, HERO), "a wolf goes home")
	assert_false(Enemy.gives_up(Hunts.fighter("rimefang"), HOME, FAR, HERO), "Rimefang keeps on")
	assert_false(Enemy.gives_up(Bestiary.spawn("dragon"), HOME, FAR, HERO), "a boss keeps on")


func test_a_wolf_close_by_keeps_on_too() -> void:
	assert_false(Enemy.gives_up(Bestiary.spawn("wolf"), HOME, Vector2(16, 0), Vector2(32, 0)))


func test_the_boss_slayers_edge_lasts_a_while_and_is_one_heros() -> void:
	var state: Node = autofree(preload("res://scripts/state/game_state.gd").new())
	state.new_game("Robin", "warrior")
	assert_eq(state.spoils.damage_scale(), 1.0, "no edge to begin with")
	state.spoils.slay_boss()
	assert_almost_eq(state.spoils.damage_scale(), 1.0 + Spoils.SLAYER_DAMAGE, 0.0001, "a boss slain: more damage")
	state.spoils.tick_slayer(Spoils.SLAYER_SECONDS - 1.0)
	assert_gt(state.spoils.damage_scale(), 1.0, "still on a second before the end")
	state.spoils.tick_slayer(2.0)
	assert_eq(state.spoils.damage_scale(), 1.0, "and gone after")
	state.spoils.slay_boss()
	state.new_game("Sam", "mage")
	assert_eq(state.spoils.damage_scale(), 1.0, "another hero doesn't inherit it")
