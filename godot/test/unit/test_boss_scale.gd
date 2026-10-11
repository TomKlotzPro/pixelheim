extends GutTest
## Bosses on the art's own grid (PIX-314): every kind, every elite, every
## named monster and the foes the story sizes are drawn at whole sizes, so
## each of the art's pixels is a square of whole world pixels like
## everything round it. Grown by fractions (combat.json's 1.3 to 2.2 times
## their kinds' 1.15 to 1.3) the Tidecaller drew at 2.86, the Seam Warden at
## 1.92 and the Hollow King at 2.38, their pixels uneven and fatter than the
## world's. A boss is still bigger than its kind; its name, level and crown
## sit on its head as drawn, its shadow under its feet, its box for blows
## over its body.

const Enemy := preload("res://scripts/enemy.gd")


static func _whole(value: float) -> bool:
	return is_equal_approx(value, roundf(value))


## A foe as the world spawns it, standing still (no world to hunt in).
func _foe(fighter: Dictionary) -> Node:
	var foe: Node = Enemy.new()
	foe.fighter = fighter
	add_child_autofree(foe)
	foe.set_physics_process(false)
	return foe


## Every boss: each named monster, and Fafnyr as the Night of Bells brings him.
func _bosses() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry in Hunts.all():
		out.append(Hunts.fighter(entry["id"]))
	out.append(Bells.fafnyr())
	return out


## The pixels the frame `foe` rests on draws, from its feet, in world pixels.
static func _drawn(foe: Node) -> Rect2:
	var frame: Texture2D = foe.sprite.sprite_frames.get_frame_texture(foe.sprite.animation, 0)
	var ink: Rect2i = Enemy._ink(frame)
	var size: float = foe.sprite.scale.x
	var corner: Vector2 = foe.sprite.position - frame.get_size() * size / 2.0
	return Rect2(corner + Vector2(ink.position) * size, Vector2(ink.size) * size)


func test_every_kind_and_its_elite_are_drawn_at_a_whole_size() -> void:
	for species: String in PunyArt.MONSTERS:
		var scale := float(PunyArt.monster(species).get("scale", 1))
		assert_true(_whole(scale) and scale >= 1.0, "%s: drawn at %s, a whole size" % [species, scale])
		for elite: bool in [false, true]:
			var fighter := Bestiary.spawn(species, elite)
			assert_eq(Enemy.drawn_size(fighter), roundi(scale), "%s%s: its kind's size" % [species, " (elite)" if elite else ""])


func test_every_named_monster_is_its_kind_grown_a_whole_size() -> void:
	for entry in Hunts.all():
		var grown := float(entry["scale"])
		assert_true(_whole(grown), "%s grown %s: a whole size, not a fraction" % [entry["id"], grown])
		assert_gte(grown, 2.0, "%s stands bigger than its kind" % entry["id"])
		var kind := Bestiary.spawn(String(entry["monsterId"]))
		assert_eq(Enemy.drawn_size(Hunts.fighter(entry["id"])), Enemy.drawn_size(kind) * roundi(grown), "%s: its kind's size, grown" % entry["id"])


func test_fafnyr_towers_over_the_square_on_whole_pixels() -> void:
	var scale := float(Bells.fafnyr_spec()["scale"])
	assert_true(_whole(scale), "Fafnyr's night grows him %s: a whole size" % scale)
	assert_eq(Enemy.drawn_size(Bells.fafnyr()), 3, "three times his kind on the square")
	assert_gt(Enemy.drawn_size(Bells.fafnyr()), Enemy.drawn_size(Hunts.fighter("cinderjaw")), "bigger than his last brood-wyrm")


## The story's monsters on its stages, and Fafnyr on Hilda's forge: their
## kinds' sheets at whole sizes too.
func test_the_storys_monsters_are_drawn_whole() -> void:
	var sheets := {}
	for species: String in PunyArt.MONSTERS:
		sheets[PunyArt.monster(species)["sheet"]] = species
	var actors := 0
	for scene_id: String in Cutscene.scenes():
		for step: Dictionary in Cutscene.scenes()[scene_id]:
			if step.get("kind", "") == "actor" and sheets.has(String(step.get("sheet", ""))):
				actors += 1
				var scale := float(step.get("scale", 1.0))
				assert_true(_whole(scale), "%s's %s at %s: a whole size" % [scene_id, sheets[step["sheet"]], scale])
	assert_gt(actors, 5, "the story's monsters were looked at")
	assert_true(_whole(float(preload("res://scripts/world_stage.gd").FORGE_DRAGON_SCALE)), "Fafnyr on the forge at a whole size")


func test_a_boss_is_drawn_on_its_own_whole_pixels() -> void:
	for fighter in _bosses():
		var foe := _foe(fighter)
		var who := String(fighter["name"])
		var size: float = foe.sprite.scale.x
		assert_eq(foe.sprite.scale, Vector2.ONE * Enemy.drawn_size(fighter), "%s: drawn its size" % who)
		assert_true(_whole(size) and size >= 2.0, "%s: drawn at %s, a whole size, bigger than its kind" % [who, size])
		var frame: Texture2D = foe.sprite.sprite_frames.get_frame_texture(foe.sprite.animation, 0)
		var corner: Vector2 = foe.sprite.position - frame.get_size() * size / 2.0
		assert_eq(corner, corner.round(), "%s: its frame's corner on a whole pixel" % who)


func test_a_bosses_words_sit_on_its_head() -> void:
	for fighter in _bosses():
		var foe := _foe(fighter)
		var who := String(fighter["name"])
		var head: float = Ink.crown(foe.sprite.sprite_frames, ["idle_down", "walk_down"], foe._rest_at, foe._rest_scale)
		var bar: float = foe.health_bar.position.y
		assert_eq(bar, roundf(bar), "%s: its bar on a whole pixel" % who)
		assert_lte(bar + foe.health_bar.size.y, head - 1.0, "%s: its bar clear of its head" % who)
		# Not out in the air twenty pixels a size put it (the Tidecaller's
		# name floated two heads over it).
		assert_lte(head - bar, Enemy.HEAD_CLEAR + 4.0, "%s: its bar just over its head (%s over it)" % [who, head - bar])
		assert_eq(foe.health_bar_back.position, foe.health_bar.position, "%s: the bar's back under it" % who)
		assert_lt(foe.mark_foot(), bar, "%s: a mark over the head over its words" % who)


func test_a_common_foe_keeps_its_bar_where_it_was() -> void:
	for species: String in PunyArt.MONSTERS:
		var foe := _foe(Bestiary.spawn(species))
		var head: float = Ink.crown(foe.sprite.sprite_frames, Array(foe.sprite.sprite_frames.get_animation_names()).filter(
			func(anim: String) -> bool: return anim.begins_with("idle") or anim.begins_with("walk")), foe._rest_at, foe._rest_scale)
		var bar: float = foe.health_bar.position.y
		assert_lte(bar + foe.health_bar.size.y, head - 1.0, "%s: its bar clear of its head" % species)
		if head > Enemy.BAR_Y + Enemy.HEAD_CLEAR:
			assert_eq(bar, Enemy.BAR_Y, "%s: its bar where it always stood" % species)


func test_the_tidecallers_stewpot_is_the_worlds_size_and_under_its_name() -> void:
	var foe := _foe(Hunts.fighter("tidecaller"))
	var pot: Sprite2D = null
	for child in foe.sprite.get_children():
		if child is Sprite2D:
			pot = child
	assert_not_null(pot, "it wears the stewpot")
	assert_eq(pot.global_scale, Vector2.ONE, "the pot at the world's own 1x, as on a shelf")
	var top: float = pot.global_position.y - foe.global_position.y - pot.texture.get_height() / 2.0 + pot.texture.get_image().get_used_rect().position.y
	assert_eq(top, roundf(top), "its pixels on whole world pixels")
	assert_lte(foe.health_bar.position.y + foe.health_bar.size.y, top - 1.0, "the bar and name over the pot")


func test_a_bosses_box_for_blows_is_its_body() -> void:
	for fighter in _bosses():
		var foe := _foe(fighter)
		var who := String(fighter["name"])
		var shape := foe.hurtbox.get_child(0) as CollisionShape2D
		var box := Rect2(shape.position - (shape.shape as RectangleShape2D).size / 2.0, (shape.shape as RectangleShape2D).size)
		var body := _drawn(foe)
		assert_true(box.has_point(body.get_center()), "%s: its box over its body's middle" % who)
		var covered := box.intersection(body)
		assert_gt(covered.size.y, body.size.y * 0.8, "%s: its box covers most of its body, head to feet" % who)
		assert_gte(box.end.y, 0.0, "%s: down to its feet" % who)


func test_an_elites_box_is_as_big_as_it_ever_was() -> void:
	var orc := Bestiary.spawn("orc", true)
	assert_eq(Enemy.drawn_size(orc), 1, "drawn its kind's size")
	assert_eq(Enemy.body_of(orc), Enemy.BODY * Enemy.ELITE_BODY, "hit over the body it had when drawn 1.2")
	assert_eq(Enemy.body_of(Bestiary.spawn("orc")), Enemy.BODY, "a common foe's as it was")


func test_a_boss_stands_on_its_shadow() -> void:
	for fighter in _bosses():
		var foe := _foe(fighter)
		var who := String(fighter["name"])
		var shadow: Sprite2D = foe._shadow
		assert_not_null(shadow, "%s: a shadow" % who)
		assert_eq(shadow.scale, foe.sprite.scale, "%s: its shadow on its own pixels" % who)
		var half := shadow.texture.get_size() * shadow.scale / 2.0
		assert_eq(shadow.position - half, (shadow.position - half).round(), "%s: its shadow's corner on a whole pixel" % who)
		var body := _drawn(foe)
		var below := shadow.position.y + half.y - body.end.y
		assert_true(below > 0.0 and below <= shadow.scale.y, "%s: a pixel of shadow under its feet (%s)" % [who, below])
		assert_almost_eq(shadow.position.x, body.get_center().x, shadow.scale.x, "%s: under its body" % who)
		assert_true(shadow.get_index() < foe.sprite.get_index(), "%s: the shadow drawn under it" % who)



## The glow round a boss's feet is a light on the floor alone: drawn with
## the ground, under every actor and pickup, so nothing standing in it is
## tinted or faded (the first glow, a sprite added over the boss, washed
## out the hero beside the Tidecaller).
func test_a_bosses_glow_lights_the_floor_alone_round_its_feet() -> void:
	assert_eq(Lights.FLOOR & 1, 0, "the floor's bit is not the one every canvas item answers to")
	for fighter in _bosses():
		var foe := _foe(fighter)
		var who := String(fighter["name"])
		var aura: PointLight2D = foe._aura
		assert_not_null(aura, "%s: a glow of its own" % who)
		assert_eq(aura.range_item_cull_mask, Lights.FLOOR, "%s: it lights the floor alone" % who)
		assert_true(aura.is_in_group("lights") and aura.get_meta("pulse", false), "%s: lit in the dark, breathing" % who)
		assert_eq(foe.sprite.light_mask & Lights.FLOOR, 0, "%s: not its own body" % who)
		assert_eq(aura.position, foe._shadow.position, "%s: round its feet" % who)
		# Tight round them: a little past its body either side, half as far
		# before and behind (the first one reached the hero five cells off).
		var reach := aura.texture.get_size() * aura.texture_scale / 2.0
		var body := _drawn(foe)
		assert_lte(reach.x, body.size.x / 2.0 + Enemy.AURA_PAST + 1.0, "%s: no further than a little past its body" % who)
		assert_eq(reach.y, reach.x / 2.0, "%s: an oval on the ground" % who)
		# Stepped in whole pixels, as a wall torch's glow.
		assert_eq(aura.texture_scale, 1.0, "%s: a texel a world pixel" % who)
		var levels := {}
		var image := aura.texture.get_image()
		for y in image.get_height():
			for x in image.get_width():
				levels[image.get_pixel(x, y).r8] = true
		assert_lte(levels.size(), Enemy.AURA_STEPS + 1, "%s: in %d steps (and none)" % [who, Enemy.AURA_STEPS])


## What stands in the glow answers to the world's lights only: the hero,
## the foes, a patch or a pouch on the ground, a prop. The floor under them
## answers to it, outdoors and in a dungeon.
func test_only_the_floor_answers_to_a_bosses_glow() -> void:
	var standing: Array[CanvasItem] = [
		autofree(preload("res://scripts/player.gd").new()),
		autofree(MapView.pickup(PunyDungeon.sheet().tile_texture(PunyDungeon.POT), Vector2i(2, 2))),
	]
	var foe := _foe(Bestiary.spawn("orc"))
	standing.append(foe.sprite)
	for item in standing:
		for node: Node in [item] + item.find_children("*", "CanvasItem", true, false):
			assert_eq((node as CanvasItem).light_mask & Lights.FLOOR, 0, "%s stands untinted" % node.name)
	for map_id: String in ["seacave_grotto", "overworld"]:
		var root := Node2D.new()
		add_child_autofree(root)
		var actors := Node2D.new()
		root.add_child(actors)
		var data := MapData.load_by_id(map_id)
		var view := MapView.new(data, actors)
		view.plan(data.spawn)
		view.build(root)
		var floors := view.under.find_children("*", "TileMapLayer", true, false).filter(
			func(layer: Node) -> bool: return (layer as CanvasItem).light_mask & Lights.FLOOR != 0)
		assert_gt(floors.size(), 0, "%s: its floor answers to the glow" % map_id)
		assert_lt(view.under.get_index(), actors.get_index(), "%s: the floor it lights drawn before the actors" % map_id)
		for node in actors.find_children("*", "CanvasItem", true, false):
			assert_eq((node as CanvasItem).light_mask & Lights.FLOOR, 0, "%s: %s stands untinted" % [map_id, node.name])


func test_a_common_foe_has_no_shadow_or_glow() -> void:
	var foe := _foe(Bestiary.spawn("orc", true))
	assert_null(foe._shadow, "an elite's weight is its gold")
	assert_null(foe._aura)


func test_a_bosses_glow_is_its_own_colour() -> void:
	var cinderjaw := Enemy.aura_color(Hunts.fighter("cinderjaw"))
	assert_gt(cinderjaw.r, cinderjaw.b, "Cinderjaw's fire")
	var rimefang := Enemy.aura_color(Hunts.fighter("rimefang"))
	assert_gt(rimefang.b, rimefang.r, "Rimefang's ice")
	assert_eq(Enemy.aura_color(Bells.fafnyr()), Lights.FIRE, "Fafnyr's fire")
