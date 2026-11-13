extends GutTest
## Each skill's own strips (PIX-396): every skill in the catalogue plays
## strips the Puny Skills pack has, the weapons and the blows theirs, and a
## bolt lands in the blow's time.


## Every skill a hero can cast: each role's actives, every path's signature.
func _catalogue() -> Array[Dictionary]:
	var skills: Array[Dictionary] = []
	for role: String in Bestiary._data()["skillTrees"]:
		for entry: Dictionary in Skills.tree(role):
			if entry["kind"] == "active":
				skills.append(entry["skill"])
	for path: Dictionary in Bestiary._data()["pathNodes"]:
		if path.has("signature"):
			skills.append(path["signature"])
	return skills


## A strip icons.json names, and where the pack is installed, there: 16 px
## frames along one row.
func _assert_strip(strip: String, loop: bool, what: String) -> void:
	assert_true(ItemIcons._data()["effects"].has(strip), "%s: %s needs a line in icons.json's effects" % [what, strip])
	if not DirAccess.dir_exists_absolute(ItemIcons.PRIVATE):
		return
	var frames := ItemIcons.effect(strip, SkillFx.FPS, loop)
	assert_not_null(frames, "%s: %s is in the pack" % [what, strip])
	if frames != null:
		assert_gt(frames.get_frame_count("default"), 1, strip)
		# ItemIcons.effect cuts 16 px cells along the top row: a taller or
		# ragged strip would be drawn cut.
		var sheet: Texture2D = (frames.get_frame_texture("default", 0) as AtlasTexture).atlas
		assert_eq(sheet.get_height(), 16, strip)
		assert_eq(sheet.get_width() % 16, 0, strip)


func test_every_skill_plays_strips_the_pack_has() -> void:
	var skills := _catalogue()
	assert_gt(skills.size(), 80)
	for skill: Dictionary in skills:
		var look := ItemIcons.skill_look(skill["name"])
		var own: String = look["self"] if skill["kind"] == "heal" else look["hit"]
		assert_ne(own, "", "%s plays something of its own" % skill["name"])
		assert_true(Color.html_is_valid(look["light"]), "%s lights the ground in its strips' colour" % skill["name"])
		if skill["kind"] == "heal":
			_assert_strip(look["self"], false, skill["name"])
			continue
		_assert_strip(look["hit"], false, skill["name"])
		if look["fly"] != "":
			_assert_strip(look["fly"], true, skill["name"])


func test_the_weapons_and_the_blows_have_theirs() -> void:
	var fx := ItemIcons.skill_fx()
	for weapon: String in ["bow", "staff"]:
		_assert_strip(fx["swings"][weapon], true, weapon)
	_assert_strip(fx["impact"], false, "impact")
	for strip: String in fx["glow"]:
		assert_true(ItemIcons._data()["effects"].has(strip), "glow: %s" % strip)


## A skill that reaches from afar is seen crossing the gap (PIX-410): it
## flies something to its foe unless its blow falls from the sky; a melee
## one flies nothing.
func test_a_ranged_skill_is_seen_crossing_the_gap() -> void:
	const SKY := ["thunder", "divine_sword"]
	for skill: Dictionary in _catalogue():
		if skill["kind"] != "damage":
			continue
		var look := ItemIcons.skill_look(skill["name"])
		if skill["reach"] == "ranged":
			assert_true(look["fly"] != "" or look["hit"] in SKY, "%s flies to its foe or falls from the sky" % skill["name"])
		elif skill["reach"] == "melee":
			assert_eq(look["fly"], "", "%s is a blow up close" % skill["name"])


## A strip loops while it flies and plays once where it lands (ItemIcons
## keeps one set of frames a strip), so none does both.
func test_no_strip_both_flies_and_lands() -> void:
	var flown: Array[String] = []
	var landed: Array[String] = [String(ItemIcons.skill_fx()["impact"])]
	for skill: Dictionary in _catalogue():
		var look := ItemIcons.skill_look(skill["name"])
		if look["fly"] != "":
			flown.append(look["fly"])
		landed.append_array([look["hit"], look["self"]])
	flown.append_array(ItemIcons.skill_fx()["swings"].values())
	for strip in flown:
		assert_false(strip in landed, "%s both flies and lands" % strip)


## The bolt reaches its foe in the blow's time - where the foe is by then -
## turned a quarter to fly right, then goes back to the pool.
func test_a_bolt_lands_in_the_blows_time() -> void:
	assert_true(SkillFx.FLIGHT <= Juice.FLASH_SECONDS, "a skill's bolt lands while its foe still flashes from the blow")
	assert_gt(int(preload("res://scripts/player.gd").STRIKE_FRAMES["bow"][0]), 0, "the bow has a frame to fly its arrow in")
	var fx: SkillFx = add_child_autofree(SkillFx.new())
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = SpriteFrames.new()
	sprite.sprite_frames.add_frame("default", PlaceholderTexture2D.new())
	fx.add_child(sprite)
	var foe: Node2D = add_child_autofree(Node2D.new())
	foe.position = Vector2(64, 0)
	fx._flight(sprite, Vector2.ZERO, foe, foe.position, SkillFx.FLIGHT)
	assert_almost_eq(sprite.rotation, PI / 2.0, 0.0001, "Shade's bolts point up: a quarter turn flies right")
	assert_eq(sprite.position, SkillFx.ON_BODY, "from the hero")
	# Stepped by hand: a frame's delta in a test run is no measure.
	var flight: Tween = sprite.get_meta("tween")
	flight.pause()
	flight.custom_step(SkillFx.FLIGHT / 2.0)
	assert_true(sprite.visible, "on its way")
	assert_eq(sprite.position, Vector2(32, 0) + SkillFx.ON_BODY, "halfway at half the time, on whole pixels")
	foe.position = Vector2(64, 32)
	flight.custom_step(SkillFx.FLIGHT / 2.0 + 0.001)
	assert_eq(sprite.position, (foe.position + SkillFx.ON_BODY).round(), "on the foe where it stepped to")
	assert_false(sprite.visible, "landed, back in the pool")


## Under a skill's own strips the ground is still lit where it lands
## (PIX-221): only the soft burst gives way to them.
func test_the_ground_is_lit_under_the_strips() -> void:
	var fx: WorldFx = add_child_autofree(WorldFx.new())
	var stub := GDScript.new()
	stub.source_code = "extends Node2D\nvar lights = null\n"
	stub.reload()
	fx.world = autofree(Node2D.new())
	fx.world.set_script(stub)
	for glow: bool in [false, true]:
		var before := fx.get_child_count()
		fx.skill_flash(Vector2.ZERO, Color.ORANGE, glow)
		var added := fx.get_children().slice(before)
		assert_eq(added.filter(func(node: Node) -> bool: return node is PointLight2D).size(), 1, "the ground lit, glow %s" % glow)
		assert_eq(added.filter(func(node: Node) -> bool: return node is Sprite2D).size(), 1 if glow else 0, "the burst only without strips")


## A skill's strips are its impact; with motion reduced nothing is drawn
## (the caller's glow stands in), though the harness still hears what was
## asked.
func test_held_impacts_and_reduced_motion() -> void:
	var fx: SkillFx = add_child_autofree(SkillFx.new())
	fx.impacts_held = true
	fx.impact(add_child_autofree(Node2D.new()))
	assert_eq(fx.asked, [] as Array[String], "held under a skill's blows")
	fx.impacts_held = false
	var was: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = true
	var hero: Node2D = add_child_autofree(Node2D.new())
	assert_false(fx.cast({"name": "Mend", "kind": "heal"}, hero, []), "still: nothing drawn")
	assert_null(fx.play("impact", hero))
	GameState.settings.reduce_motion = was
	assert_eq(fx.asked, ["vitality_heal"] as Array[String])
	assert_eq(fx.drawn, 0)


## The bow's arrow and the staff's bolt are seen flying with or without the
## paid pack (PIX-410: without it, Firebolt's plain shaft and ball); a blade
## looses nothing, and with motion reduced nothing flies.
func test_the_heros_shot_flies_without_the_pack_too() -> void:
	var fx: SkillFx = add_child_autofree(SkillFx.new())
	var foe: Node2D = add_child_autofree(Node2D.new())
	foe.position = Vector2(48, 0)
	for weapon: String in ["bow", "staff"]:
		assert_true(fx.swing(weapon, Vector2.ZERO, foe, foe.position, 0.1), "%s: its shot flies" % weapon)
	assert_false(fx.swing("sword", Vector2.ZERO, foe, foe.position, 0.1), "a blade looses nothing")
	assert_true(autofree(Firebolt.plain("arrow", Vector2.RIGHT)).get_child(0) is Line2D, "a shaft")
	assert_true(autofree(Firebolt.plain("ball", Vector2.RIGHT)).get_child(0) is ColorRect, "a ball")
	var was: bool = GameState.settings.reduce_motion
	GameState.settings.reduce_motion = true
	assert_false(fx.swing("bow", Vector2.ZERO, foe, foe.position, 0.1), "still: nothing flies")
	GameState.settings.reduce_motion = was
