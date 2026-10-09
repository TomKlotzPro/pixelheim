class_name WorldFx
extends Node2D
## What flashes and floats over the world (Solid Ground, PIX-260: moved out
## of world.gd as it was): damage numbers and words rising over heads, a
## skill's light where it lands, the level-up burst, a fine or epic drop's
## name, dust kicked up, a monster fading into view. A Node2D at the world's
## origin, so what it adds stands where it always did.

var world: Node2D

## A fine or epic drop's name over the fallen foe (PIX-211): the rarities'
## colours, lit to read on the ground rather than on paper.
const LOOT_GLOW := {"fine": Color("8cc4ff"), "epic": Color("d99bff")}


## A word that rises and fades over where it happened (PIX-155: "dodged",
## "blocked"). A `big` one (PIX-211: LEVEL UP, a fine or epic drop's name)
## bursts in at twice its size unless motion is reduced, then settles at the
## pixel face's own (anything larger dwarfs the fighters), and stays longer.
func float_text(text: String, at: Vector2, color: Color, big := false) -> void:
	var label := _floating(text, color)
	label.position = (at - Vector2(label.size.x / 2.0, 0)).round()
	label.z_index = 11 if big else 10
	add_child(label)
	var life := 1.8 if big else 0.6
	var tween := label.create_tween().set_parallel()
	if big:
		_pop(label, tween)
	tween.tween_property(label, "position:y", label.position.y - (16 if big else 12), life).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(life - 0.35)
	tween.chain().tween_callback(label.queue_free)


## The UI's bold pixel face at its own size, outlined in the night (PIX-194).
func _floating(text: String, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", UiStyle.bold_font())
	label.add_theme_font_size_override("font_size", UiStyle.BODY_PX)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
	label.add_theme_constant_override("outline_size", 3)
	label.size = label.get_minimum_size()
	# Bright at night too (PIX-221).
	label.material = Lights.unshaded()
	return label


## A label bursting in at twice its size (PIX-209, PIX-211), not when motion
## is reduced.
func _pop(label: Label, tween: Tween) -> void:
	if GameState.settings.reduce_motion:
		return
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * 2.0
	tween.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A number over a head. Each lands a few pixels off the last (PIX-209), so
## a flurry reads as blows, not one smudge; a crit comes in gold with a "!"
## and a spark, bursting in at twice its size unless motion is reduced.
func float_number(value: int, at: Vector2, color: Color, crit := false) -> void:
	var label := _floating(str(value) + ("!" if crit else ""), UiStyle.BRASS_LIGHT if crit else color)
	label.position = at - Vector2(label.size.x / 2.0 + randf_range(-4.0, 4.0), 4 if crit else 0)
	label.z_index = 11 if crit else 10
	add_child(label)
	var life := 0.8 if crit else 0.6
	var tween := create_tween().set_parallel()
	if crit:
		_pop(label, tween)
		skill_flash(at + Vector2(0, 10), UiStyle.BRASS_LIGHT)
	tween.tween_property(label, "position:y", label.position.y - 12, life).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, life).set_delay(life * 0.4)
	tween.chain().tween_callback(label.queue_free)


## A skill's light where it lands: a soft burst that swells and fades.
func skill_flash(at: Vector2, color: Color) -> void:
	var burst := Sprite2D.new()
	burst.texture = preload("res://scripts/player.gd")._glow()
	burst.material = Lights.glow()
	burst.modulate = Color(color, 0.85)
	# A spell lights the ground for a breath where it lands (PIX-221).
	var flare := Lights.make(at, 96.0, color, 0.8)
	flare.remove_from_group("lights")
	flare.energy = 0.8 * maxf(0.35, world.lights.dark if world.lights != null else 0.0)
	add_child(flare)
	var dim := flare.create_tween()
	dim.tween_property(flare, "energy", 0.0, 0.45).set_ease(Tween.EASE_IN)
	dim.tween_callback(flare.queue_free)
	burst.global_position = at
	burst.scale = Vector2(0.4, 0.6)
	burst.z_index = 5
	add_child(burst)
	var bloom := create_tween().set_parallel()
	bloom.tween_property(burst, "scale", Vector2(1.6, 2.2), 0.35).set_ease(Tween.EASE_OUT)
	bloom.tween_property(burst, "modulate:a", 0.0, 0.35)
	bloom.chain().tween_callback(burst.queue_free)


## A level gained (PIX-211): a gold burst on the hero, LEVEL UP over their
## head and the experience line flashing; its words go on the plate (_log).
func level_up_burst() -> void:
	if world.player == null:
		return
	skill_flash(world.player.global_position, UiStyle.GOLD)
	skill_flash(world.player.global_position + Vector2(0, -8), UiStyle.BRASS_LIGHT)
	float_text(Text.t("LEVEL UP"), world.player.global_position + Vector2(0, -40), UiStyle.GOLD, true)
	world.hud.dock.flash_xp()


## A fine or epic piece from a kill (PIX-211): its name rises over the
## fallen foe in its rarity's colour, so it isn't lost in the log.
func show_loot(pieces: Array, at: Vector2) -> void:
	var lift := 0.0
	for piece: Dictionary in pieces:
		var glow: Variant = LOOT_GLOW.get(String(piece["rarity"]))
		if glow == null:
			continue
		float_text(InventoryState.gear_name(piece), at + Vector2(0, -24 - lift), glow, true)
		lift += 12.0


## A ring of dust motes kicked up from `at` (a monster appearing, a dodge).
func dust(at: Vector2) -> void:
	for i in 8:
		var mote := ColorRect.new()
		mote.color = Color(0.86, 0.8, 0.68, 0.9) if i % 2 == 0 else Color(0.7, 0.64, 0.52, 0.9)
		mote.size = Vector2(2, 2)
		mote.position = at + Vector2(-1, 1)
		mote.z_index = 4
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mote)
		var away := Vector2.RIGHT.rotated(TAU * i / 8.0) * Vector2(9, 4)
		var drift := mote.create_tween().set_parallel()
		drift.tween_property(mote, "position", mote.position + away + Vector2(0, -3), 0.45).set_ease(Tween.EASE_OUT)
		drift.tween_property(mote, "modulate:a", 0.0, 0.45).set_delay(0.15)
		drift.chain().tween_callback(mote.queue_free)


## Dust where a monster comes into sight (PIX-142): a ring of motes kicked up
## from its feet as it fades in, so nothing simply pops into being.
func appear(enemy: Node) -> void:
	if not world.camera_rig.in_view(enemy.position, world.TILE):
		return
	enemy.modulate.a = 0.0
	var fade_in := enemy.create_tween()
	fade_in.tween_property(enemy, "modulate:a", 1.0, 0.3)
	dust(enemy.position)
