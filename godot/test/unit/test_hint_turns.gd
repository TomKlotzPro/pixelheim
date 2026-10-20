extends GutTest
## The dodge's card opened over L'Appelle-Marée's entrance (PIX-341): over
## his bar, his name and his first words. A first-time hint waits while a
## boss makes its entrance, and shows once it falls (or the hero gets away,
## or the fight has gone on a while); and one hint at a time, the next in
## its turn, nothing lost.


## Foes as the HUD asks them: the boss hunting the hero, and since when.
class FakeFoes extends RefCounted:
	var boss: Node = null
	var boss_noticed_at := -100.0

	func boss_hunting() -> Node:
		return boss


class FakeWorld extends Node:
	var foes := FakeFoes.new()


var world: FakeWorld
var hud: Hud
var kept: GameSettings


func before_each() -> void:
	# A new player's hints, never written over the real settings.
	kept = GameState.settings
	GameState.settings = GameSettings.new("user://test_hint_turns.cfg")
	GameState.settings.read_only = true
	world = add_child_autofree(FakeWorld.new())
	hud = Hud.new()
	hud.world = world
	world.add_child(hud)
	hud.root = CanvasLayer.new()
	world.add_child(hud.root)
	hud.boss_bar = preload("res://scripts/boss_bar.gd").new()
	hud.root.add_child(hud.boss_bar)


func after_each() -> void:
	GameState.settings = kept


func _up() -> String:
	return String(hud.hint_card.get_meta("id")) if is_instance_valid(hud.hint_card) else ""


func test_a_hint_waits_out_a_boss_entrance_and_shows_once_it_falls() -> void:
	world.foes.boss = autofree(Node.new())
	world.foes.boss_noticed_at = GameClock.seconds()
	hud.hint("dodge")
	assert_eq([_up(), hud.hint_held()], ["", "dodge"], "held, not over the entrance")
	hud.keep_hint_clear()
	assert_eq(hud.hint_held(), "dodge", "still held while the entrance plays")
	assert_false("dodge" in GameState.settings.hints_seen, "not seen until it shows")
	world.foes.boss = null
	hud.keep_hint_clear()
	assert_eq([_up(), hud.hint_held()], ["dodge", ""], "the boss down: it shows")
	assert_true("dodge" in GameState.settings.hints_seen)


func test_a_long_boss_fight_lets_the_hint_show() -> void:
	world.foes.boss = autofree(Node.new())
	world.foes.boss_noticed_at = GameClock.seconds() - Hud.BOSS_HINT_S - 0.1
	hud.hint("dodge")
	assert_eq(_up(), "dodge", "past the entrance, in a calm moment")


func test_one_hint_at_a_time_the_next_in_its_turn() -> void:
	hud.hint("dodge")
	hud.hint("fright")
	hud.hint("fright")
	assert_eq([_up(), hud.hint_held()], ["dodge", "fright"], "the second waits, once")
	hud.hint_card.free()
	hud.keep_hint_clear()
	assert_eq(_up(), "fright", "its turn")


func test_a_hint_waits_for_a_title_card() -> void:
	var card := hud.title_card("La Grotte marine", "")
	hud.hint("dodge")
	assert_eq(hud.hint_held(), "dodge", "not over the place's name")
	card.free()
	hud.keep_hint_clear()
	assert_eq(_up(), "dodge")
