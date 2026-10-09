extends GutTest
## Readable danger (PIX-210): bites told long enough to react to, a hero
## near the end warned, and bosses that carry a bar of their own, notched
## where their phases turn.

const BossBarScript := preload("res://scripts/boss_bar.gd")
const HudDockScript := preload("res://scripts/hud_dock.gd")
const SoundScript := preload("res://scripts/sound.gd")


## Just enough of a foe for the bar to follow.
class Foe:
	extends Node
	var fighter := {"id": "dragon", "name": "Fafnyr", "hp": 300, "maxHp": 300}
	var dying := false
	var hunting := true


func test_a_bite_is_told_long_enough_to_step_away() -> void:
	assert_gte(float(Packs.rules()["biteTellSeconds"]), 0.4)


func test_a_boss_turns_at_two_thirds_and_one_third() -> void:
	assert_eq(BossBrain.phase_at(1.0), 0)
	assert_eq(BossBrain.phase_at(0.7), 0)
	assert_eq(BossBrain.phase_at(0.66), 1)
	assert_eq(BossBrain.phase_at(0.34), 1)
	assert_eq(BossBrain.phase_at(0.33), 2)


func test_a_blows_ghost_holds_then_drains_to_the_health() -> void:
	var held: Array = BossBarScript.trail(0.8, 0.5, 0.4, 0.1)
	assert_eq(held[0], 0.8, "it holds first")
	var draining: Array = BossBarScript.trail(0.8, 0.5, 0.0, 0.1)
	assert_almost_eq(float(draining[0]), 0.74, 0.001)
	assert_eq(BossBarScript.trail(0.52, 0.5, 0.0, 1.0)[0], 0.5, "never below the health")
	assert_eq(BossBarScript.trail(0.4, 0.5, 0.0, 0.1)[0], 0.5, "a heal lifts it at once")


func test_the_boss_bar_follows_a_boss_and_lets_go_when_it_falls() -> void:
	var bar: Control = BossBarScript.new()
	add_child_autofree(bar)
	var foe: Foe = autofree(Foe.new())
	bar.follow(foe)
	assert_eq(bar.name_label.text, "Fafnyr")
	assert_true(bar.notches.all(func(notch: ColorRect) -> bool: return notch.visible), "a boss's phases are notched")
	foe.fighter["hp"] = 150
	bar._process(0.1)
	assert_eq(bar.share, 0.5)
	assert_eq(bar.ghost_share, 1.0, "the blow's ghost stays a moment")
	assert_gt(bar.ghost.size.x, bar.fill.size.x)
	foe.dying = true
	for i in 60:
		bar._process(0.1)
	assert_eq(bar.modulate.a, 0.0)
	assert_null(bar.target, "it lets go once faded")
	assert_false(bar.following())


func test_a_named_foe_has_the_bar_without_notches() -> void:
	var bar: Control = BossBarScript.new()
	add_child_autofree(bar)
	var foe: Foe = autofree(Foe.new())
	foe.fighter = {"id": "wolf", "name": "Old Grey", "hp": 40, "maxHp": 40, "named": "old_grey"}
	bar.follow(foe)
	assert_false(bar.notches.any(func(notch: ColorRect) -> bool: return notch.visible))


func test_low_health_is_below_a_quarter() -> void:
	assert_true(HudDockScript.low_hp(24, 100))
	assert_false(HudDockScript.low_hp(25, 100))
	assert_false(HudDockScript.low_hp(0, 100), "the dead hear no heartbeat")


func test_danger_has_its_sounds() -> void:
	for name: String in ["tell", "mark", "slam", "heart"]:
		assert_true(SoundScript.UI_SOUNDS.has(name), name)
		assert_gt(SoundScript._synth(SoundScript.UI_SOUNDS[name]).data.size(), 0, name)
