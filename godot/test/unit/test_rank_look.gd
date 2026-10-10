extends GutTest
## Each rank of a class looking its own, and the ascension as a moment
## (PIX-244). The rule is pure (a rank to what it puts on the hero): the
## survivor first, then a trim, a rim of light, the weapon's glow and a trail,
## each kept by the ranks after it, in each class's own colours. The look
## lies on top of what is worn, never over it: the trim only ever recolours
## Shade's outline, and the rim is a copy of the frame drawn behind the
## sprite. The moment runs its beats in order - the hush, the lift, the old
## look giving way to the new, the name, what it brings, the landing - and
## with Reduce motion it holds still: nothing flies, the looks cross-fade.

const GameStateScript := preload("res://scripts/state/game_state.gd")
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


func test_the_first_rank_is_the_plain_survivor() -> void:
	var look := RankLook.spec("warrior", 0)
	assert_eq(look["steps"], [], "nothing added")
	for step: String in ["trim", "rim", "weapon", "trail", "aura"]:
		assert_eq((look[step] as Color).a, 0.0, "no %s on the survivor" % step)
	assert_false(look["breath"])


func test_each_rank_adds_a_step_and_keeps_the_ones_before() -> void:
	var expected := [[], ["trim"], ["trim", "rim"], ["trim", "rim", "weapon"], ["trim", "rim", "weapon", "trail"]]
	for rank in 5:
		var look := RankLook.spec("mage", rank)
		assert_eq(look["steps"], expected[rank], "rank %d" % (rank + 1))
		for step: String in ["trim", "rim", "weapon", "trail"]:
			assert_eq((look[step] as Color).a > 0.0, step in expected[rank], "rank %d's %s" % [rank + 1, step])
		assert_eq((look["aura"] as Color).a > 0.0, rank >= 1, "the pool of light from rank II")
	assert_true(RankLook.spec("mage", 4)["breath"], "the fifth rank's rim breathes")
	assert_eq(RankLook.spec("mage", 9)["rank"], 4, "five ranks at most")
	assert_eq(RankLook.spec("mage", -1)["rank"], 0)


func test_the_look_comes_from_the_heros_level() -> void:
	var hero := HeroState.create("L", "ranger")
	for pair: Array in [[1, 0], [4, 0], [5, 1], [10, 2], [15, 3], [20, 4], [40, 4]]:
		hero.level = pair[0]
		assert_eq(RankLook.of_hero(hero)["rank"], pair[1], "level %d" % pair[0])
	hero.level = 10
	assert_eq(RankLook.of_hero(hero)["rim"], Color(String(RankLook.COLORS["ranger"][1])), "in the ranger's own light")


func test_every_class_has_colours_of_its_own() -> void:
	var lights := {}
	for role_id: String in PunyArt.HEROES:
		assert_true(RankLook.COLORS.has(role_id), "%s has its colours" % role_id)
		var look := RankLook.spec(role_id, 4)
		var trim: Color = look["trim"]
		var light: Color = look["light"]
		assert_lt(trim.get_luminance(), light.get_luminance(), "%s's trim is a cloth colour, darker than its light" % role_id)
		assert_gt(light.get_luminance(), 0.58, "%s's light is bright enough to bloom at night (bloom.gdshader's threshold)" % role_id)
		assert_false(lights.has(light.to_html()), "%s's light is its own" % role_id)
		lights[light.to_html()] = role_id


func test_every_rank_brings_a_new_look_line() -> void:
	assert_eq(RankLook.line(0), "", "the survivor has nothing new")
	var lines := {}
	for rank in range(1, 5):
		var line := RankLook.line(rank)
		assert_ne(line, "", "rank %d says what it puts on" % (rank + 1))
		assert_false(lines.has(line))
		lines[line] = true


## The trim recolours what is dark and meets the air: on every sheet the hero
## can wear (the plain clothes, every helmet's and armour's), that is only
## ever Shade's black outline (his 040404, and the pure black his armoured
## sheets are partly outlined in), never a piece of clothing or gear, and
## never the shirt's reds the walking check finds the hero by.
func test_the_trim_only_ever_takes_the_outline() -> void:
	var sheets := {}
	for sheet: String in PunyArt.PLAIN:
		sheets[sheet] = true
	for sheet: String in PunyArt.HEADS.values() + PunyArt.BODIES.values():
		sheets[sheet] = true
	var outlines := [Color("040404"), Color("000000")]
	for sheet: String in sheets:
		var image := (load(PunyArt.path(sheet)) as Texture2D).get_image()
		image.convert(Image.FORMAT_RGBA8)
		var odd := 0
		# The idle and walk columns, every direction.
		for y in range(1, image.get_height() - 1):
			for x in range(1, 4 * 32 - 1):
				var here := image.get_pixel(x, y)
				if here.a < 0.5 or maxf(here.r, maxf(here.g, here.b)) >= 0.06:
					continue
				var open := minf(minf(image.get_pixel(x + 1, y).a, image.get_pixel(x - 1, y).a), minf(image.get_pixel(x, y + 1).a, image.get_pixel(x, y - 1).a))
				if open < 0.5 and not outlines.any(func(black: Color) -> bool: return here.is_equal_approx(black)):
					odd += 1
		assert_eq(odd, 0, "%s: only the outline is dark at the edge" % sheet)
	for red: String in ["b60000", "770000"]:
		var shirt := Color(red)
		assert_gt(maxf(shirt.r, maxf(shirt.g, shirt.b)), 0.06, "%s is never taken for the outline" % red)


## The look goes on top of what is worn: the dressed sheet stays the sprite's
## (gear, weapon and all), the trim rides on its material and the rim is a
## copy behind it, following its every frame; a lower rank takes them off.
func test_the_look_lies_on_top_of_the_gear() -> void:
	var art := PunyArt.dressed("warrior", 0, {"head": "iron_helm", "body": "iron_armor", "offhand": "steel_shield"})
	var sprite: AnimatedSprite2D = autofree(AnimatedSprite2D.new())
	sprite.sprite_frames = PunyArt.frames(art)
	add_child(sprite)
	var frames := sprite.sprite_frames
	RankLook.wear(sprite, RankLook.spec("warrior", 4))
	assert_eq(sprite.sprite_frames, frames, "the gear's own sheet")
	assert_eq((sprite.material as ShaderMaterial).get_shader_parameter("trim"), RankLook.spec("warrior", 4)["trim"])
	var rim := RankLook.rim_of(sprite)
	assert_not_null(rim, "a rim from rank III")
	assert_true(rim.show_behind_parent, "drawn behind the figure, never over it")
	assert_eq(rim.sprite_frames, frames)
	sprite.play(PunyArt.pick(frames, "sword", "right"))
	sprite.frame = 2
	assert_eq([rim.animation, rim.frame], [sprite.animation, 2], "frame for frame")
	RankLook.wear(sprite, RankLook.spec("warrior", 1))
	assert_null(RankLook.rim_of(sprite), "rank II has no rim")
	assert_eq((sprite.material as ShaderMaterial).get_shader_parameter("trim"), RankLook.spec("warrior", 1)["trim"], "but its trim")
	RankLook.wear(sprite, RankLook.spec("warrior", 0))
	assert_eq(((sprite.material as ShaderMaterial).get_shader_parameter("trim") as Color).a, 0.0, "the survivor's plain edge")


func test_the_moments_beats_come_in_order() -> void:
	for reduced: bool in [false, true]:
		var names: Array = RankupScreen.beats(reduced).map(func(entry: Array) -> String: return entry[0])
		assert_eq(names, ["hush", "lift", "change", "named", "unlocks", "settled"], "every beat, with or without motion")
		var at := -1.0
		for entry: Array in RankupScreen.beats(reduced):
			assert_true(float(entry[1]) >= at, "%s comes after the beat before" % entry[0])
			at = float(entry[1])
	assert_gt(RankupScreen.beat_at("change", false) - RankupScreen.beat_at("lift", false), RankupScreen.LIFT_SECONDS, "lifted before the look changes")
	assert_gt(RankupScreen.beat_at("named", false) - RankupScreen.beat_at("change", false), RankupScreen.BURN_SECONDS, "the old look burnt away before the name")
	assert_gt(RankupScreen.beat_at("named", true) - RankupScreen.beat_at("change", true), RankupScreen.FADE_SECONDS, "the cross-fade done before the name")


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


## The moment, beat by beat: the hero in the old look, lifted, the new look
## out of the old one's light, the name, what the rank brings.
func test_the_moment_plays_its_beats() -> void:
	GameState.settings.reduce_motion = false
	_open(10)
	assert_eq(screen.rank, 2)
	assert_eq(screen.old_look["steps"], ["trim"], "the rank before")
	assert_eq(screen.new_look["steps"], ["trim", "rim"])
	assert_not_null(RankLook.rim_of(screen.new_hero), "the new look wears its rim")
	assert_null(RankLook.rim_of(screen.old_hero), "the old one had none")
	assert_eq(_particles(screen).size(), 2, "motes and sparks")
	assert_false(screen.new_hero.visible, "the new look waits under the old one")
	assert_false(screen.name_card.visible)
	screen._timeline.custom_step(RankupScreen.beat_at("lift", false) + 0.01)
	assert_eq(screen.phase, "lift")
	assert_true(screen.motes.emitting, "motes rise in the light")
	screen._timeline.custom_step(RankupScreen.beat_at("change", false) - RankupScreen.beat_at("lift", false))
	assert_eq(screen.phase, "change")
	assert_true(screen.new_hero.visible, "the new look comes out of the light")
	assert_eq((screen.old_hero.material as ShaderMaterial).get_shader_parameter("flash"), 1.0, "the old one flashes white")
	screen._timeline.custom_step(RankupScreen.beat_at("named", false) - RankupScreen.beat_at("change", false))
	assert_eq(screen.phase, "named")
	assert_true(screen.name_card.visible)
	assert_eq((screen.name_card.get_child(1) as Label).text, "Champion")
	assert_false(screen.unlocks.visible)
	screen._timeline.custom_step(RankupScreen.beat_at("unlocks", false) - RankupScreen.beat_at("named", false))
	assert_eq(screen.phase, "unlocks")
	assert_true(screen.unlocks.visible)
	var lines: Array = screen.unlocks.get_children().map(func(label: Label) -> String: return label.text)
	assert_eq(lines.size(), 4, "skills, stats, the path, the look")
	assert_eq(lines[0], "+1 bonus skill point")
	assert_true(String(lines[1]).begins_with("Level 10: +3 stat points"), lines[1])
	assert_eq(lines[2], "A new step on your path: choose it below")
	assert_eq(lines[3], RankLook.line(2))
	assert_eq(screen.cards.get_child_count(), 2, "the fork's two walks")
	screen._timeline.custom_step(RankupScreen.beat_at("settled", false) - RankupScreen.beat_at("unlocks", false))
	assert_eq(screen.phase, "settled")
	assert_false(screen.motes.emitting, "the motes settle with the hero")
	assert_false(screen.closing, "a fork holds the moment")


## Reduce motion: nothing flies or rises, the old look cross-fades into the
## new one, and without a fork the moment still passes.
func test_with_reduce_motion_it_holds_still() -> void:
	GameState.settings.reduce_motion = true
	GameState.hero.path = ["juggernaut", "bastion", "unbroken"]
	_open(20)
	# The screen holds the world still; GUT's waits need it running.
	get_tree().paused = false
	assert_eq(_particles(screen).size(), 0, "no motes, no sparks")
	assert_false(screen.new_hero.is_playing(), "the figures hold still")
	assert_eq(screen.new_hero.modulate.a, 0.0)
	var feet: float = screen.figure.position.y
	screen._timeline.custom_step(RankupScreen.beat_at("change", true) + 0.01)
	assert_eq(screen.phase, "change")
	await wait_seconds(RankupScreen.FADE_SECONDS + 0.15)
	assert_almost_eq(screen.old_hero.modulate.a, 0.0, 0.01, "the old look faded out")
	assert_almost_eq(screen.new_hero.modulate.a, 1.0, 0.01, "the new one in")
	assert_true(screen.new_hero.visible)
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
