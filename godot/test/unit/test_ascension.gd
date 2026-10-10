extends GutTest
## The ascension as a moment, and a hero who looks the same at every rank
## (PIX-244). Tom found the rank's look on the hero ugly (an edge, a rim of
## light, a glowing weapon, a trail, a coloured pool, a figure a fifth
## bigger at rank V): gear is what shows, so the hero in the world is the
## same at level 1 and level 20. The moment runs its beats in order - the
## hush, the lift, the light's flare on the one figure, the name, what it
## brings, the landing - and with Reduce motion it holds still: nothing
## flies, rises or flashes, the light only brightens.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const PlayerScript := preload("res://scripts/player.gd")
const RankupScreen := preload("res://scripts/rankup_screen.gd")

var screen: Node
var _lent: Node
var _kept := {}
var _reduce_motion := false


func before_each() -> void:
	Controls.apply({})
	_kept = {"hero": GameState.hero, "pack": GameState.pack, "progression": GameState.progression}
	_reduce_motion = GameState.settings.reduce_motion
	_lent = GameStateScript.new()
	_lent.new_game("Robin", "warrior")
	GameState.hero = _lent.hero
	GameState.pack = _lent.pack
	GameState.progression = _lent.progression


func after_each() -> void:
	if is_instance_valid(screen):
		screen.close()
	screen = null
	for key: String in _kept:
		GameState.set(key, _kept[key])
	GameState.settings.reduce_motion = _reduce_motion
	_lent.free()
	await get_tree().process_frame
	get_tree().paused = false


## How the world draws a hero of `level`: the sprite's size and place, its
## shader's settings, and everything hung on the hero, by kind.
func _drawn_at(level: int) -> Dictionary:
	GameState.hero.level = level
	var hero: CharacterBody2D = PlayerScript.new()
	# Drawn, never run: its steps reach for a world the test has none of.
	hero.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(hero)
	var sprite: AnimatedSprite2D = hero.sprite
	var material := sprite.material as ShaderMaterial
	var drawn := {
		"scale": sprite.scale,
		"at": sprite.position,
		"modulate": [sprite.modulate, sprite.self_modulate],
		"shader": material.shader.get_shader_uniform_list().map(func(uniform: Dictionary) -> Array:
			return [uniform["name"], material.get_shader_parameter(uniform["name"])]),
		"parts": hero.get_children().map(func(child: Node) -> String: return child.get_class()),
		"inside": sprite.get_child_count(),
	}
	hero.free()
	return drawn


## The hero in the world at every rank, plain and at their own size: no
## trim or rim on the sprite, nothing more hung on them, no bigger.
func test_the_hero_looks_the_same_at_every_rank() -> void:
	var first := _drawn_at(1)
	assert_eq(first["scale"], Vector2.ONE, "the hero's own size")
	assert_eq(first["inside"], 0, "nothing drawn behind or over the sprite")
	for level: int in [4, 5, 10, 15, 20, 40]:
		assert_eq(_drawn_at(level), first, "level %d looks as level 1 does" % level)


func test_every_class_has_a_light_of_its_own() -> void:
	var lights := {}
	for role_id: String in PunyArt.HEROES:
		assert_true(RankupScreen.LIGHTS.has(role_id), "%s has its light" % role_id)
		var light := RankupScreen.light_of(role_id)
		assert_gt(light.get_luminance(), 0.58, "%s's light is bright enough to bloom (bloom.gdshader's threshold)" % role_id)
		assert_false(lights.has(light.to_html()), "%s's light is its own" % role_id)
		lights[light.to_html()] = role_id


func test_the_moments_beats_come_in_order() -> void:
	for reduced: bool in [false, true]:
		var names: Array = RankupScreen.beats(reduced).map(func(entry: Array) -> String: return entry[0])
		assert_eq(names, ["hush", "lift", "flare", "named", "unlocks", "settled"], "every beat, with or without motion")
		var at := -1.0
		for entry: Array in RankupScreen.beats(reduced):
			assert_true(float(entry[1]) >= at, "%s comes after the beat before" % entry[0])
			at = float(entry[1])
	assert_gt(RankupScreen.beat_at("flare", false) - RankupScreen.beat_at("lift", false), RankupScreen.LIFT_SECONDS, "lifted before the light flares")
	assert_gt(RankupScreen.beat_at("named", false) - RankupScreen.beat_at("flare", false), RankupScreen.FLARE_SECONDS, "out of the white before the name")
	assert_gt(RankupScreen.beat_at("named", true) - RankupScreen.beat_at("flare", true), RankupScreen.FADE_SECONDS, "the light brightened before the name")


## The world falls as dark behind the moment on the desktop app's linear
## canvas as in the browser: the veil there is thicker.
func test_the_hush_is_as_dark_on_the_apps_canvas() -> void:
	assert_eq(DesktopLook.veil(RankupScreen.HUSH, false), RankupScreen.HUSH, "the browser's as it is")
	var thick := DesktopLook.veil(RankupScreen.HUSH, true)
	assert_almost_eq(1.0 - thick, pow(1.0 - RankupScreen.HUSH, 2.2), 0.0001, "what lets light through, in linear light")
	assert_eq(DesktopLook.veil(0.0, true), 0.0)
	assert_eq(DesktopLook.veil(1.0, true), 1.0)


func _open(level: int) -> Node:
	GameState.hero.level = level
	screen = RankupScreen.new()
	screen.title = Ranks.title(GameState.hero.role_id, level)
	add_child(screen)
	return screen


func _particles(root: Node) -> Array:
	return root.find_children("*", "CPUParticles2D", true, false)


## The moment, beat by beat: the hero lifted into the light, flashing white
## as it flares, the name, what the rank brings - one figure throughout.
func test_the_moment_plays_its_beats() -> void:
	GameState.settings.reduce_motion = false
	_open(10)
	assert_eq(screen.rank, 2)
	assert_eq(screen.find_children("*", "AnimatedSprite2D", true, false).size(), 1, "one hero, never two looks")
	assert_eq(screen.light, RankupScreen.light_of("warrior"), "in the warrior's light")
	assert_eq(_particles(screen).size(), 2, "motes and sparks")
	assert_false(screen.name_card.visible)
	screen._timeline.custom_step(RankupScreen.beat_at("lift", false) + 0.01)
	assert_eq(screen.phase, "lift")
	assert_true(screen.motes.emitting, "motes rise in the light")
	screen._timeline.custom_step(RankupScreen.beat_at("flare", false) - RankupScreen.beat_at("lift", false))
	assert_eq(screen.phase, "flare")
	assert_eq((screen.hero_sprite.material as ShaderMaterial).get_shader_parameter("flash"), 1.0, "the hero flashes white in the light")
	assert_true(screen.sparks.emitting, "sparks fly")
	screen._timeline.custom_step(RankupScreen.beat_at("named", false) - RankupScreen.beat_at("flare", false))
	assert_eq(screen.phase, "named")
	assert_true(screen.name_card.visible)
	assert_eq((screen.name_card.get_child(0) as Label).text, "Ascension: rank 3 of 5")
	assert_eq((screen.name_card.get_child(1) as Label).text, "Champion")
	assert_false(screen.unlocks.visible)
	screen._timeline.custom_step(RankupScreen.beat_at("unlocks", false) - RankupScreen.beat_at("named", false))
	assert_eq(screen.phase, "unlocks")
	assert_true(screen.unlocks.visible)
	var lines: Array = screen.unlocks.get_children().map(func(label: Label) -> String: return label.text)
	assert_eq(lines.size(), 3, "skills, stats, the path")
	assert_eq(lines[0], "+1 bonus skill point")
	assert_true(String(lines[1]).begins_with("Level 10: +3 stat points"), lines[1])
	assert_eq(lines[2], "A new step on your path: choose it below")
	assert_eq(screen.cards.get_child_count(), 2, "the fork's two walks")
	screen._timeline.custom_step(RankupScreen.beat_at("settled", false) - RankupScreen.beat_at("unlocks", false))
	assert_eq(screen.phase, "settled")
	assert_false(screen.motes.emitting, "the motes settle with the hero")
	assert_false(screen.closing, "a fork holds the moment")


## Reduce motion: nothing flies, rises or flashes; the light brightens as it
## flares, and without a fork the moment still passes.
func test_with_reduce_motion_it_holds_still() -> void:
	GameState.settings.reduce_motion = true
	GameState.hero.path = ["juggernaut", "bastion", "unbroken"]
	_open(20)
	# The screen holds the world still; GUT's waits need it running.
	get_tree().paused = false
	assert_eq(_particles(screen).size(), 0, "no motes, no sparks")
	assert_false(screen.hero_sprite.is_playing(), "the hero holds still")
	var feet: float = screen.figure.position.y
	screen._timeline.custom_step(RankupScreen.beat_at("flare", true) + 0.01)
	assert_eq(screen.phase, "flare")
	await wait_seconds(RankupScreen.FADE_SECONDS + 0.15)
	assert_almost_eq(screen.beam.modulate.a, RankupScreen.BEAM_ALPHA, 0.01, "the light brightened")
	assert_almost_eq(screen.pool.modulate.a, RankupScreen.POOL_LIT, 0.01, "the pool in the class's light")
	# Never set is the shader's own 0.
	var flash: Variant = (screen.hero_sprite.material as ShaderMaterial).get_shader_parameter("flash")
	assert_eq(0.0 if flash == null else float(flash), 0.0, "no flash")
	assert_eq(screen.figure.position.y, feet, "never lifted")
	screen._timeline.custom_step(RankupScreen.beat_at("settled", true))
	assert_eq(screen.phase, "settled")
	assert_eq(screen.cards.get_child_count(), 0, "the path is walked: no fork")
	await wait_seconds(RankupScreen.HOLD_AFTER + 0.3)
	assert_true(not is_instance_valid(screen) or screen.closing, "the moment passes")


## E during the show skips to what the rank brings.
func test_e_skips_to_the_unlocks() -> void:
	GameState.settings.reduce_motion = false
	_open(5)
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	screen._command(press).call()
	assert_eq(screen.phase, "unlocks")
	assert_true(screen.unlocks.visible)
