extends GutTest
## A foe freed while something still speaks of it (PIX-503, the crash hunt of
## 2026-11-16): a door, a fall or a reload frees every foe on the map without
## its dying, and what was in flight - a line of the log asking whether it
## still stands, a bolt on its way, the Night of Bells' dawn, a named foe's
## last words, the hit stop's slowed clock - must land without it. An engine
## error fails a test here, so each of these fails on the error alone.


var _bells := 0
var _reduce_motion := false


func before_each() -> void:
	_bells = GameState.progression.bells
	_reduce_motion = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = false


func after_each() -> void:
	GameState.progression.bells = _bells
	GameState.settings.reduce_motion = _reduce_motion
	Engine.time_scale = 1.0


## A foe as the log knows one: its line holds while it stands (enemy.gd's
## own lambda, which keeps a bare pointer to the foe).
class Foe extends Node2D:
	var dying := false
	var hunting := false
	var fighter := {"name": "Hollow Captain", "named": "nobody_at_all"}

	func afflicted(messages: Messages) -> void:
		messages.log_now("Orc Raider is afflicted by poison!", func() -> bool: return not dying)


func _chips(messages: Messages) -> Array:
	return messages.log_box.get_children().filter(func(chip: Node) -> bool: return not chip.is_queued_for_deletion()).map(
		func(chip: Node) -> String: return (chip.get_child(0) as Label).text)


func test_a_freed_foes_line_leaves_the_log_unasked() -> void:
	var hud: CanvasLayer = add_child_autofree(CanvasLayer.new())
	var messages: Messages = add_child_autofree(Messages.new())
	messages.build_log(hud)
	messages.build_plate(hud)
	var foe := Foe.new()
	add_child(foe)
	foe.afflicted(messages)
	messages.update()
	assert_eq(_chips(messages), ["Orc Raider is afflicted by poison!"], "said while it stands")
	foe.free()
	# What the freed memory holds next decides what asking it does: taken
	# again by other nodes, as a new map's are.
	var others: Array = []
	for i in 32:
		others.append(autofree(Foe.new()))
	messages.update()
	assert_eq(_chips(messages), [], "gone with its foe")
	assert_true((messages._log.showing + messages._log.waiting).is_empty(), "and not kept waiting")


func test_a_line_with_nobody_behind_it_is_still_asked() -> void:
	var hud: CanvasLayer = add_child_autofree(CanvasLayer.new())
	var messages: Messages = add_child_autofree(Messages.new())
	messages.build_log(hud)
	messages.build_plate(hud)
	var foe: Foe = add_child_autofree(Foe.new())
	foe.afflicted(messages)
	messages.log_now("The bell rings.")
	messages.update()
	foe.dying = true
	messages.update()
	assert_false("Orc Raider is afflicted by poison!" in _chips(messages), "its foe dead, the line goes")


func test_a_bolt_lands_where_it_was_sent_once_its_foe_is_freed() -> void:
	var fx: SkillFx = add_child_autofree(SkillFx.new())
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_frame("default", PlaceholderTexture2D.new())
	fx.add_child(sprite)
	var foe := Node2D.new()
	add_child(foe)
	foe.position = Vector2(64, 0)
	var end := Vector2(64, 32)
	fx._flight(sprite, Vector2.ZERO, foe, end, SkillFx.FLIGHT, "no_such_strip")
	var flight: Tween = sprite.get_meta("tween")
	flight.pause()
	flight.custom_step(SkillFx.FLIGHT / 2.0)
	foe.free()
	flight.custom_step(SkillFx.FLIGHT / 2.0 + 0.001)
	assert_eq(sprite.position, (end + SkillFx.ON_BODY).round(), "where it was sent")
	assert_false(sprite.visible, "landed, back in the pool")
	assert_eq(SkillFx._goal(null, end).call(), end, "a miss flies to its end")


func test_the_hit_stop_hands_the_clock_back_when_the_world_goes() -> void:
	var rig := CameraRig.new()
	add_child(rig)
	rig.hit_stop(Foes.BOSS_SLOW_S, Foes.BOSS_SLOW)
	assert_almost_eq(Engine.time_scale, Foes.BOSS_SLOW, 0.0001, "slowed for the boss's fall")
	rig.free()
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001, "a reload inside the stop: the next world runs at full speed")


class Hero extends Node2D:
	var dead := true
	var raised := 0

	func respawn(at: Vector2) -> void:
		position = at
		dead = false
		raised += 1


class Square extends Node:
	var player := Hero.new()
	var last_player_position := Vector2.ZERO
	var map: MapData = null
	var view: Node = null
	var soundscape := Quiet.new()
	var entered := 0

	func _init() -> void:
		add_child(player)

	func load_map(_id: String) -> MapData:
		return MapData.new()

	func enter_map(_map: MapData, _at: Vector2i) -> void:
		entered += 1


class Quiet extends RefCounted:
	func hush(_seconds: float) -> void:
		pass


func _night() -> Night:
	var night: Night = autofree(Night.new())
	night.world = autofree(Square.new())
	return night


func test_a_fall_at_dawn_gets_up_where_it_lies_and_the_town_stands() -> void:
	var night := _night()
	GameState.progression.bells = Bells.DAWN
	night.world.player.position = Vector2(120, 80)
	night.hero_fell()
	assert_eq(night.world.entered, 0, "the town isn't drawn anew: Fafnyr stays for the dawn")
	assert_false(night.world.player.dead, "the hero is up")
	assert_eq(night.world.player.position, Vector2(120, 80), "where they lay")
	night.hero_fell()
	assert_eq(night.world.player.raised, 1, "a hero already up is left be")


func test_the_collar_comes_though_the_dragon_went_while_the_dawn_played() -> void:
	var night := _night()
	var dragon := Node.new()
	var next: Callable = night._collar.bind(dragon.get_instance_id())
	dragon.free()
	next.call()
	var scenes := night.world.get_children().filter(func(node: Node) -> bool: return node is Cutscene)
	assert_eq(scenes.size(), 1, "the collar's scene, which leads to the day")
	assert_eq(scenes[0].scene_id if not scenes.is_empty() else "", Bells.collar_id())


func test_a_named_foe_standing_down_holds_the_ways_until_it_is_paid() -> void:
	var world: Square = add_child_autofree(Square.new())
	var foes := Foes.new()
	foes.world = world
	world.add_child(foes)
	# Only its stand-down is under test: its frame wants a whole world.
	foes.set_process(false)
	foes.set_physics_process(false)
	var foe := Foe.new()
	foe.dying = true  # as Enemy.stand_down leaves it
	world.add_child(foe)
	foes.stood_down(foe)
	assert_eq(foes.yielding, foe, "a fallen hero's waking waits on it")
	assert_eq(foes.boss_hunting(), foe, "and no door opens: it would free him unpaid")
	foe.free()
	assert_null(foes.boss_hunting(), "gone some other way, he bars nothing")
	await wait_seconds(Foes.STAND_DOWN_BEAT + 0.2)
	assert_null(foes.yielding, "nor keeps a hero from waking")
