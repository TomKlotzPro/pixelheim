extends GutTest
## The dodge's card opened over L'Appelle-Marée's entrance (PIX-341): over
## his bar, his name and his first words. A first-time hint waits while a
## boss makes its entrance, and shows once it falls (or the hero gets away,
## or the fight has gone on a while); and one hint at a time, the next in
## its turn, nothing lost. PIX-345: a title card over a hint already up held
## it pushed down over the hero; now it holds it unseen until it goes, and a
## title card stands clear of what rises over the world.


## Foes as the HUD asks them: the boss hunting the hero, and since when.
class FakeFoes extends RefCounted:
	var boss: Node = null
	var boss_noticed_at := -100.0

	func boss_hunting() -> Node:
		return boss


## What rises over the world, as far as it may yet go (WorldFx.reach).
class FakeFx extends RefCounted:
	var rising: Array[Rect2] = []

	func reach() -> Array[Rect2]:
		return rising


class FakeWorld extends Node:
	var foes := FakeFoes.new()
	var fx := FakeFx.new()


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


## PIX-345: walking out of the sea cave, Saltmere's name came over the dodge
## already up and pushed it down over the hero for seconds. The card holds
## it unseen, its time stopped; it comes back where it stood as the card
## goes.
func test_a_title_card_holds_a_hint_already_up() -> void:
	hud.hint("dodge")
	var top := hud.hint_card.position.y
	var show: Tween = hud.hint_card.get_meta("show")
	var card := hud.title_card("Saltmere", "")
	hud.keep_hint_clear()
	assert_false(hud.hint_card.visible, "held under the card")
	assert_false(show.is_running(), "its time stopped")
	assert_eq(hud.hint_card.position.y, top, "never pushed down")
	card.free()
	hud.keep_hint_clear()
	assert_true(hud.hint_card.visible, "back as the card goes")
	assert_true(show.is_running(), "its time running again")
	assert_eq(hud.hint_card.position.y, top, "where it stood")


## PIX-345: at a boss's fall the Victory card stood where its gold, its
## drops and LEVEL UP rose. A title card stands at its height with nothing
## in the way, and clear of what rises otherwise.
func test_a_title_card_stands_clear_of_what_rises() -> void:
	var alone := hud.title_card("Victoire", "L'Appelle-Marée n'est plus.")
	assert_eq(alone.position.y, Hud.CARD_TOP, "nothing in the way: where it stands")
	alone.free()
	var win := Rect2(500, 20, 280, 180)
	world.fx.rising = [win] as Array[Rect2]
	var card := hud.title_card("Victoire", "L'Appelle-Marée n'est plus.")
	assert_false(card.get_rect().intersects(win), "clear of the win and LEVEL UP")
	assert_gt(card.position.y, win.end.y, "under them")
