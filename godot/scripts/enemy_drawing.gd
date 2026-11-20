class_name EnemyDrawing
extends RefCounted
## areas: combat field
## What is drawn of a foe besides its body (PIX-501, out of enemy.gd): its
## shadow on the ground and a boss's glow, its health bar, its level tag, a
## named one's name and what it wears on its head, an icon for each thing
## ailing it, and the marks over its head - the alert's "!", the fright's
## cold burst and drop of sweat, a sleeper's "Z". The enemy says when (the
## hero is seen, a blow landed, it falls); this builds the nodes as the
## enemy's own children, in the order they have always stood, and keeps them
## over its head whichever way it turns. It decides nothing of the fight.

## The fright's "!" and drop shiver this many art pixels either way; the
## drop starts this far under the burst's top and runs this far down.
const SHIVER := 1.0
const DROP_FROM := 4.0
const DROP_RUN := 3.0
## The danger mark's foot stands this far over the level tag (PIX-188),
## which hid the old "!"'s dot; where no tag has been laid out, the tag's
## height over the health bar.
const MARK_CLEAR := 1.0
const TAG_HEIGHT := 9.0
## How long the words over its head take to make way for the hero (make_way).
const MAKE_WAY_S := 0.1
const TAG_HALF_WIDTH := 10.0
## Between the level tag and an ailment's icon, and from one to the next.
const AILMENT_GAP := 1.0
## Asleep (PIX-252): how long each "Z" takes to drift up and fade, and the
## pause before the next.
const SLEEP_DRIFT_SECONDS := 1.6
const SLEEP_PAUSE_SECONDS := 0.3
## Over the head (PIX-314): a foe's health bar stands BAR_Y over its feet,
## or HEAD_CLEAR over the top of a head that reaches higher (over_head).
const BAR_Y := -20.0
const HEAD_CLEAR := 6.0
## A slime's half keeps its bar this near its top instead (PIX-497).
const SMALL_CLEAR := 2.0
## The health bar's full width, and a named monster's or one the story
## sizes itself (the Night of Bells' Fafnyr, towering over the square).
const BAR_WIDTH := 16.0
const LONG_BAR_WIDTH := 28.0
## A boss's weight besides its size (PIX-314): its shadow on the ground,
## how dark; and a glow of its own colour on the floor round its feet in the
## dark: a light that lights the floor alone (Lights.FLOOR), so nothing
## standing in it is tinted, reaching this far past its body either side
## (half as far before and behind it), in this many steps of whole pixels
## (as a wall torch's glow), how strong at full dark, and how near white.
const SHADOW_ALPHA := 0.3
const AURA_PAST := 12
const AURA_STEPS := 4
const AURA_ENERGY := 0.5
const AURA_WHITE := 0.15
## What a named monster may wear on its head (PIX-255), by the name the data
## gives it: the dungeon sheet's piece, its middle this many world pixels
## under the top of the head.
const CROWNS := {"stewpot": PunyDungeon.POT}
const CROWN_SINK := 3.0

## The enemy it draws for: every node here is a child of it.
var foe: Enemy
var health_bar: ColorRect
var health_bar_back: ColorRect
var bar_width := BAR_WIDTH
## "Lv N" beside the health bar (PIX-188).
var level_tag: PanelContainer
## Its tag is the one its pack shows (Foes hides the others': PIX-340).
var tag_led := false
## A named foe's name over its head, or null.
var name_plate: Label
## An icon for each thing ailing it beside the tag (PIX-440), built at the
## first: a foe nothing ails has no nodes for it.
var ailment_row: Node2D
var _ailing: Array[String] = []
## The danger mark over its head as it notices the hero (Marks, PIX-289).
var mark: Sprite2D
## The fright's cue over the head: the cold burst and a drop of sweat.
var fright_mark: Node2D
var _fright_tween: Tween
var _drop: Sprite2D
var _sleep_mark: Label
## Where its bar stands, from its feet (over_head, PIX-314).
var bar_at := BAR_Y
## Its shadow on the ground (ground_shadow, PIX-441) and a boss's glow.
var shadow: Sprite2D
var aura: PointLight2D
static var _shadows := {}
static var _auras := {}


func _init(of: Enemy) -> void:
	foe = of


## Its shadow on the ground under where its sprite will stand (laid before
## the sprite is added, so it draws under it), a boss's glow with it. Half
## the shadow's width in world pixels: its foot as drawn.
func lay_shadow(size: int) -> float:
	shadow = ground_shadow(foe.sprite, size, foe.rest_at.y)
	foe.add_child(shadow)
	if foe.boss_like:
		_weigh(size)
	return shadow.texture.get_width() * size / 2.0


## Its words' line over its head as drawn, and over what it wears on it (a
## named one's crown, put on here): worked out once its sprite stands. The
## highest its head reaches, from its feet.
func measure_head(size: int) -> float:
	var frames: SpriteFrames = foe.sprite.sprite_frames
	var worn := _wear_crown()
	var crown := crown_of(frames, foe.rest_at, size, worn)
	bar_at = over_head(frames, foe.rest_at, size, worn)
	# A slime's half stands far under its kind's line (PIX-497: its tag and
	# its "!" floated a body's height over it, belonging to nothing).
	if foe.fighter.get("small", false):
		bar_at = floorf(crown) - SMALL_CLEAR
	foe.sprite.animation_changed.connect(turned)
	return crown


## Its health bar, a named one's name and its level tag, over its head.
func raise_bars() -> void:
	var fighter: Dictionary = foe.fighter
	if not foe.named.is_empty() or fighter.has("size"):
		bar_width = LONG_BAR_WIDTH
	# Health floats above the head, hidden until first scratched; elites in gold.
	health_bar_back = ColorRect.new()
	health_bar_back.color = Color(0, 0, 0, 0.6)
	health_bar_back.size = Vector2(bar_width, 2)
	health_bar_back.position = Vector2(-bar_width / 2.0, bar_at)
	health_bar_back.visible = false
	foe.add_child(health_bar_back)
	health_bar = ColorRect.new()
	health_bar.color = Color(1, 0.8, 0.3) if fighter["elite"] else Color(0.9, 0.25, 0.25)
	health_bar.size = Vector2(bar_width, 2)
	health_bar.position = Vector2(-bar_width / 2.0, bar_at)
	health_bar.visible = false
	foe.add_child(health_bar)
	# A foe's bar and name read at night too (PIX-221).
	health_bar_back.material = Lights.unshaded()
	health_bar.material = Lights.unshaded()
	var plate: Label = null
	if not foe.named.is_empty():
		plate = _name_plate(bar_at - 1)
		name_plate = plate
		Lights.unshade(plate)
		foe.add_child(plate)
	# Its level by the health bar (PIX-188), coloured by the gap to the
	# hero's: seen once the hero is near enough to be noticed, before the charge.
	var level := Bestiary.level_of(fighter)
	# On the night's plate (no outline round its words), over every actor
	# (the y-sort would put a hero standing above the foe on top of it).
	level_tag = PanelContainer.new()
	level_tag.add_theme_stylebox_override("panel", UiStyle.plate(6))
	level_tag.add_child(UiStyle.strong(Text.t("Lv %d") % level, 16, Bestiary.gap_color(level, GameState.hero.level)))
	level_tag.scale = Vector2.ONE * CameraRig.LABEL_SCALE
	level_tag.z_as_relative = false
	level_tag.z_index = Foes.TAG_Z
	level_tag.visible = false
	level_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A named foe's tag stands above its name, not over it.
	var place_tag := func() -> void:
		var above := bar_at - 0.5 - (plate.size.y * CameraRig.LABEL_SCALE if plate != null else 0.0)
		level_tag.position = Vector2(-level_tag.size.x * CameraRig.LABEL_SCALE / 2.0, above - level_tag.size.y * CameraRig.LABEL_SCALE)
	level_tag.resized.connect(place_tag)
	if plate != null:
		plate.resized.connect(place_tag)
	Lights.unshade(level_tag)
	foe.add_child(level_tag)


## Each tick: its tag shows once the hero is near enough to be noticed, in a
## fight or scratched, and goes with a falling foe (PIX-340: it stayed up
## over the body, and as the nearest kept the pack's living tags hidden) or
## a pile of bones; the ailments beside it.
func tick() -> void:
	if level_tag == null:
		return
	level_tag.visible = not foe.dying and foe.state != EnemyState.PILE and (foe.hunting or health_bar.visible or Packs.within_notice(foe.global_position, foe.world.player.global_position))
	show_ailments()


## What stands over its head (its level tag, the ailments beside it, a named
## foe's name, its health bar) makes way while the hero, feet at `hero`,
## stands under the words (PIX-469: over every actor, the plate hid a hero
## in the cell above the foe, and the bar crossed them), fading out and back
## in a few frames: by its alpha, so what shows and hides each still does.
func make_way(hero: Vector2, delta: float) -> void:
	if level_tag == null:
		return
	var under := Foes.hero_under(level_tag.get_global_rect(), hero) or (name_plate != null and Foes.hero_under(name_plate.get_global_rect(), hero))
	var alpha := move_toward(level_tag.modulate.a, 0.0 if under else 1.0, delta / MAKE_WAY_S)
	for words: CanvasItem in [level_tag, name_plate, ailment_row, health_bar, health_bar_back]:
		if words != null:
			words.modulate.a = alpha


## Whether its tag is its pack's one; a mark up moves with it (a half's
## "!" stands over a tag it shows, PIX-497).
func lead_tag(leads: bool) -> void:
	if tag_led == leads:
		return
	tag_led = leads
	turned()


## The level its tag reads (PIX-340: in a fight a pack's one tag reads the
## pack's highest), coloured by the gap to the hero's.
func show_level(level: int) -> void:
	lead_tag(true)
	var words: Label = level_tag.get_child(0)
	var text := Text.t("Lv %d") % level
	if words.text != text:
		words.text = text
		words.add_theme_color_override("font_color", Bestiary.gap_color(level, GameState.hero.level))


## Its health bar at the health it has, `shown` or not (a boss's is on the
## boss bar across the screen's top, PIX-210; a falling foe's is gone).
func show_health(shown: bool) -> void:
	health_bar.size.x = bar_width * foe.fighter["hp"] / foe.fighter["maxHp"]
	health_bar.visible = shown
	health_bar_back.visible = shown


func hide_health() -> void:
	health_bar.visible = false
	health_bar_back.visible = false


## Whole again (Enemy._mend): its bar full, and hidden as before a scratch.
func mended() -> void:
	hide_health()
	health_bar.size.x = bar_width


## An icon for each thing ailing it, beside its level tag (PIX-440), gone
## with the ailment or the foe. Nothing to do for a foe with none, and the
## icons are made again only when the list changes, so a big pack pays only
## for those ailing.
func show_ailments() -> void:
	var ailments: Ailments = foe.ailments
	if ailments.effects.is_empty() and _ailing.is_empty():
		return
	var kinds := ailments.kinds()
	# A fixed order: a refreshed ailment moves to the end of the list.
	kinds.sort()
	if foe.dying:
		kinds.clear()
	if ailment_row == null:
		ailment_row = Node2D.new()
		# Over every actor, as the tag.
		ailment_row.z_as_relative = false
		ailment_row.z_index = Foes.TAG_Z
		ailment_row.modulate.a = level_tag.modulate.a
		foe.add_child(ailment_row)
	ailment_row.position = _beside_tag()
	if kinds == _ailing:
		return
	_ailing = kinds
	for icon in ailment_row.get_children():
		icon.free()
	var x := 0.0
	for kind in kinds:
		var art := ItemIcons.ailment(kind)
		# Each is a few art pixels in the corner of a blank 16x16: cut to its
		# ink, or the row would stand a full tile apart and off the tag's line.
		var ink := Rect2i() if art == null else Ink.used(art)
		var icon := Sprite2D.new()
		icon.texture = art
		icon.centered = false
		icon.region_enabled = true
		icon.region_rect = ink
		icon.position = Vector2(x, -floorf(ink.size.y / 2.0))
		# Reads in the dark, as the tag does.
		icon.material = Lights.unshaded()
		ailment_row.add_child(icon)
		x += ink.size.x + AILMENT_GAP


## The middle of the level tag's right side, or where it would be while the
## tag has never been laid out (hidden from the start in a pack's fight).
func _beside_tag() -> Vector2:
	if level_tag.size.x <= 0.0:
		return Vector2(TAG_HALF_WIDTH + AILMENT_GAP, bar_at - TAG_HEIGHT / 2.0)
	return level_tag.position + Vector2(level_tag.size.x * CameraRig.LABEL_SCALE + AILMENT_GAP, level_tag.size.y * CameraRig.LABEL_SCALE / 2.0)


## The line its health bar stands on, from its feet (PIX-314): HEAD_CLEAR
## over the highest its head reaches (crown_of), and never lower than BAR_Y.
## A foe its kind's size keeps its bar where it was; a big one's sits over
## its head, not out in the air twenty pixels a size put it (the
## Tidecaller's name floated two heads over it).
static func over_head(frames: SpriteFrames, at: Vector2, size: float, worn := INF) -> float:
	return minf(BAR_Y, floorf(crown_of(frames, at, size, worn)) - HEAD_CLEAR)


## The highest its head reaches as drawn at `at` and `size`, from its feet,
## standing or walking any way it faces, or what it wears there (`worn`,
## its top).
static func crown_of(frames: SpriteFrames, at: Vector2, size: float, worn := INF) -> float:
	var poses := Array(frames.get_animation_names()).filter(func(anim: String) -> bool: return anim.begins_with("idle") or anim.begins_with("walk"))
	return minf(Ink.crown(frames, poses, at, Vector2.ONE * size), worn)


## The colour of a boss's glow (PIX-314): its own (a named monster's tint)
## as a light's, toward white; fire for one without (Fafnyr).
static func aura_color(fighter: Dictionary) -> Color:
	if not fighter.has("named"):
		return Lights.FIRE
	var own: Array = Hunts.named(fighter["named"])["tint"]
	var tint := Color(float(own[0]), float(own[1]), float(own[2]))
	var top := maxf(tint.r, maxf(tint.g, tint.b))
	return Color(tint.r / top, tint.g / top, tint.b / top).lerp(Color.WHITE, AURA_WHITE)


## A boss's weight besides its size (PIX-314): a glow of its own colour on
## the floor round its feet that breathes in the dark, a light on the floor
## alone (Lights.FLOOR): drawn with the ground, under every actor and
## pickup, so a hero standing in it looks as without it.
func _weigh(size: int) -> void:
	# Round its feet, a little past its body either side, on whole pixels.
	aura = Lights.make(shadow.position, 0.0, aura_color(foe.fighter), AURA_ENERGY)
	aura.texture = aura_texture(shadow.texture.get_width() * size / 2 + AURA_PAST)
	aura.texture_scale = 1.0
	aura.range_item_cull_mask = Lights.FLOOR
	aura.set_meta("pulse", true)
	foe.add_child(aura)


## A boss's glow `reach` world pixels either side and half that before and
## behind: an oval in AURA_STEPS rings of whole pixels, brightest at its
## middle, as a wall torch's glow is stepped (TitleScene.glow_texture).
static func aura_texture(reach: int) -> Texture2D:
	if _auras.has(reach):
		return _auras[reach]
	var size := Vector2i(reach * 2, reach)
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var middle := Vector2(size) / 2.0
	for y in size.y:
		for x in size.x:
			var d := ((Vector2(x, y) + Vector2(0.5, 0.5) - middle) / middle).length()
			if d >= 1.0:
				continue
			var level := ceilf((1.0 - d) * AURA_STEPS) / AURA_STEPS
			image.set_pixel(x, y, Color(level * level, level * level, level * level))
	_auras[reach] = ImageTexture.create_from_image(image)
	return _auras[reach]


## A contact shadow `wide` art pixels across: an oval a quarter as tall (two
## pixels at least, even), dark and see-through, its edge on whole pixels.
static func shadow_texture(wide: int) -> Texture2D:
	if _shadows.has(wide):
		return _shadows[wide]
	var tall := maxi(2, wide / 4 + (wide / 4) % 2)
	var image := Image.create(wide, tall, false, Image.FORMAT_RGBA8)
	var middle := Vector2(wide, tall) / 2.0
	for y in tall:
		for x in wide:
			var off := (Vector2(x, y) + Vector2(0.5, 0.5) - middle) / middle
			if off.length_squared() <= 1.0:
				image.set_pixel(x, y, Color(0, 0, 0, SHADOW_ALPHA))
	_shadows[wide] = ImageTexture.create_from_image(image)
	return _shadows[wide]


## A figure's shadow on the ground (PIX-314; PIX-441: the hero, villagers and
## every foe), measured on the frame it stands in facing the player, whatever
## it is playing, on its own pixels: under the middle of its body, reaching a
## pixel past its feet, whole art pixels from the frame's corner. A child of
## the figure beside its sprite, so the squash and the walk leave it planted:
## add it before the sprite. Never raised with its figure: a villager drawn
## over the hero (Npc.stands_over) would lay it across the hero's head.
static func ground_shadow(sprite: AnimatedSprite2D, size: float, rest_y: float) -> Sprite2D:
	var frames := sprite.sprite_frames
	var frame := frames.get_frame_texture(PunyArt.pick(frames, "idle", "down"), 0)
	var ink := Ink.used(frame)
	var half := Vector2i(frame.get_size()) / 2
	var shadow := Sprite2D.new()
	shadow.texture = shadow_texture(ink.size.x + ink.size.x % 2)
	shadow.scale = Vector2.ONE * size
	shadow.z_as_relative = false
	var tall := shadow.texture.get_height()
	shadow.position = Vector2(ink.position.x + ink.size.x / 2 - half.x, ink.end.y + 1 - tall / 2 - half.y) * size + Vector2(0, rest_y)
	return shadow


## A named monster wearing something of the story's (combat.json's
## "crown"): the Tidecaller with Tam's stewpot on its head, sitting on the
## top of the frame it shows, squashing and flashing with it. The highest
## its top reaches, from the foe's feet (INF: nothing worn).
func _wear_crown() -> float:
	var named: Dictionary = foe.named
	if not CROWNS.has(String(named.get("crown", ""))):
		return INF
	var sprite: AnimatedSprite2D = foe.sprite
	var crown := Sprite2D.new()
	crown.texture = PunyDungeon.sheet().tile_texture(CROWNS[named["crown"]])
	# Pot-sized on the hero's scale, whatever the monster's: the world's own
	# 1x, as every pot on a shelf (PIX-314: three quarters of it drew its
	# pixels uneven).
	crown.scale = Vector2.ONE / sprite.scale.x
	var top := Ink.crown(sprite.sprite_frames, Array(sprite.sprite_frames.get_animation_names()))
	# On the head of the frame showing, so it rides each squash rather than
	# floating at the figure's highest reach.
	var sit := func() -> void:
		crown.position = Vector2(0, Ink.top_now(sprite, top) + CROWN_SINK / sprite.scale.y)
	sprite.frame_changed.connect(sit)
	sprite.animation_changed.connect(sit)
	sit.call()
	# It flashes and dissolves with the one wearing it.
	crown.use_parent_material = true
	sprite.add_child(crown)
	var ink := crown.texture.get_image().get_used_rect()
	return foe.rest_at.y + top * foe.rest_scale.y + CROWN_SINK - crown.texture.get_height() / 2.0 + ink.position.y


## A named monster's name over its head in the boss's red: the UI's type at
## CameraRig.LABEL_SCALE, so at play zoom one font pixel is one screen pixel.
func _name_plate(lift: float) -> Label:
	var plate := UiStyle.strong(foe.fighter["name"], 16, Color("ffb3a1"))
	plate.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.03))
	plate.add_theme_constant_override("outline_size", 4)
	plate.scale = Vector2.ONE * CameraRig.LABEL_SCALE
	plate.z_index = 10
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its words' ink centred over the bar, not its box (PIX-268, Ink).
	var words := Ink.of_text(plate.text, UiStyle.bold_font(), UiStyle.TEXT)
	plate.resized.connect(func() -> void: plate.position = Vector2(-words.get_center().x * CameraRig.LABEL_SCALE, lift - plate.size.y * CameraRig.LABEL_SCALE))
	return plate


## The danger mark in `tone` (Marks.alert: "danger", or "fright"), at the
## world's scale, over the fighters round it and bright at night (PIX-221).
static func alert_mark(tone: String) -> Sprite2D:
	var burst := Sprite2D.new()
	burst.texture = Marks.alert(tone)
	burst.centered = false
	burst.z_index = 10
	Lights.unshade(burst)
	return burst


## The hero is seen: the danger mark over its head, up for the wind-up's
## `seconds` and a little more, then fading; the fright's cue gone.
func alert(seconds: float) -> void:
	if fright_mark != null:
		fright_mark.visible = false
	if mark == null:
		mark = alert_mark("danger")
		foe.add_child(mark)
	_place_mark(mark)
	mark.modulate.a = 1.0
	mark.visible = true
	var fade := mark.create_tween()
	fade.tween_interval(seconds + 0.5)
	fade.tween_property(mark, "modulate:a", 0.0, 0.25)


## A mark over the head the way the monster faces now (PIX-268: its head
## isn't always over its middle), its middle (the "!") on the head's in
## whole pixels, its foot over the level tag.
func _place_mark(burst: Sprite2D) -> void:
	var sprite: AnimatedSprite2D = foe.sprite
	var head := Ink.head(sprite.sprite_frames, Ink.rest_pose(sprite.sprite_frames, sprite.animation), foe.rest_at, foe.rest_scale)
	var size := burst.texture.get_size()
	burst.position = Vector2(Marks.centred(size.x, head.get_center().x), mark_foot() - size.y)


## Where a mark over the head has its foot: MARK_CLEAR over the level tag
## (PIX-188; a named foe's tag stands over its name), or over where the tag
## stands before it is laid out.
func mark_foot() -> float:
	# A slime's half whose tag its pack's one tag hides wears its mark right
	# over it (PIX-497): a tag's height up, over a blob 8 px tall, the "!"
	# belonged to nothing. The half showing the tag keeps it over the tag.
	if foe.fighter.get("small", false) and not tag_led:
		return floorf(bar_at - MARK_CLEAR)
	var tag_top := bar_at - TAG_HEIGHT
	if level_tag != null and level_tag.size.y > 0.0:
		tag_top = level_tag.position.y
	return floorf(tag_top - MARK_CLEAR)


## The alert or the fright's cue keeps over its head as it turns to the
## chase or the flight.
func turned() -> void:
	if mark != null and mark.visible:
		_place_mark(mark)
	if fright_mark != null and fright_mark.visible:
		_place_fright()


## The fright's burst over the head, its drop of sweat beside it.
func _place_fright() -> void:
	var burst := fright_mark.get_child(0) as Sprite2D
	_place_mark(burst)
	_drop.position.x = burst.position.x + burst.texture.get_width() + 1.0


## The hero is seen, and far too strong (PIX-251): a pale "!" and a drop of
## sweat over its head, shivering a whole pixel either way while the drop
## runs down beside the "!" - or, `still` (Reduce motion), just standing a
## while - then fading. The alert's mark goes.
func fright(still: bool) -> void:
	if mark != null:
		mark.visible = false
	if fright_mark == null:
		fright_mark = _fright_cue()
		foe.add_child(fright_mark)
	_place_fright()
	fright_mark.visible = true
	fright_mark.modulate.a = 1.0
	fright_mark.position = Vector2.ZERO
	var from: float = (fright_mark.get_child(0) as Sprite2D).position.y + DROP_FROM
	_drop.position.y = from
	if _fright_tween != null:
		_fright_tween.kill()
	_fright_tween = fright_mark.create_tween()
	if not still:
		# A shiver a whole pixel either way (the art's pixels stay square),
		# while the drop runs down beside the "!" a pixel at a time.
		for i in 6:
			_fright_tween.tween_callback(func() -> void: fright_mark.position.x = SHIVER if i % 2 == 0 else -SHIVER)
			_fright_tween.tween_interval(0.06)
		_fright_tween.tween_callback(func() -> void: fright_mark.position.x = 0.0)
		var run := _drop.create_tween()
		run.tween_method(func(y: float) -> void: _drop.position.y = roundf(y), from, from + DROP_RUN, 0.5)
	_fright_tween.tween_interval(0.5 if not still else 1.0)
	_fright_tween.tween_property(fright_mark, "modulate:a", 0.0, 0.25)


## The fright's cue: the danger mark's cold burst, and a drop of sweat at
## its side, both at the world's scale.
func _fright_cue() -> Node2D:
	var cue := Node2D.new()
	cue.add_child(alert_mark("fright"))
	_drop = Sprite2D.new()
	_drop.texture = Juice.sweat_drop()
	_drop.centered = false
	cue.add_child(_drop)
	Lights.unshade(cue)
	return cue


## The fright's cue gone at once (struck as it ran, it stands and fights),
## and every mark with it (it stands down).
func hide_fright() -> void:
	if fright_mark != null:
		fright_mark.visible = false


func hide_marks() -> void:
	if mark != null:
		mark.visible = false
	hide_fright()


## A sleeper's "Z" over it (`on`), or gone as it gets up (PIX-252).
func sleep(on: bool) -> void:
	if on and _sleep_mark == null:
		_sleep_mark = _sleep_cue()
		foe.add_child(_sleep_mark)
	elif not on and _sleep_mark != null:
		_sleep_mark.queue_free()
		_sleep_mark = null


## A sleeper's "Z" (a capital: the small one read as a 2): the UI's type at
## CameraRig.LABEL_SCALE, as the level tag, beside its head, drifting up and
## fading a whole art pixel at a time, then again - each sleeper on its own
## breath, not in step with its pack; still with Reduce motion. Lit at night.
func _sleep_cue() -> Label:
	var cue := UiStyle.strong("Z", 16, UiStyle.CREAM)
	cue.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
	cue.add_theme_constant_override("outline_size", 4)
	cue.scale = Vector2.ONE * CameraRig.LABEL_SCALE
	cue.z_index = 10
	cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rest := Vector2(3.0, bar_at - 2.0)
	cue.position = rest
	Lights.unshade(cue)
	if not GameState.settings.reduce_motion:
		var rise := func(t: float) -> void:
			cue.position = rest + Vector2(roundf(t * 3.0), -roundf(t * 6.0))
			cue.modulate.a = 1.0 - t * t
		var drift := cue.create_tween().set_loops()
		drift.tween_method(rise, 0.0, 1.0, SLEEP_DRIFT_SECONDS)
		drift.tween_interval(SLEEP_PAUSE_SECONDS)
		drift.custom_step(randf() * (SLEEP_DRIFT_SECONDS + SLEEP_PAUSE_SECONDS))
	return cue


## The fall (or, stood down, lying down at last): the fright's cue and its
## bars gone; a common foe's shadow goes as it falls, a boss's with its
## body (dissolve).
func lie_down() -> void:
	hide_fright()
	hide_health()
	if not foe.boss_like:
		shadow.visible = false


## The last of it: a boss's shadow and glow go with its body (PIX-314).
func dissolve() -> void:
	shadow.create_tween().tween_property(shadow, "modulate:a", 0.0, Juice.DISSOLVE_SECONDS)
	if aura != null:
		var light := aura
		light.create_tween().tween_method(func(energy: float) -> void: light.set_meta("energy", energy), AURA_ENERGY, 0.0, Juice.DISSOLVE_SECONDS)
