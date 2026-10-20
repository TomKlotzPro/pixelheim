class_name WorldFx
extends Node2D
## What flashes and floats over the world (Solid Ground, PIX-260: moved out
## of world.gd as it was): damage numbers and words rising over heads, a
## skill's light where it lands, the level-up burst, what's won rising from
## where it was won (PIX-245), dust kicked up, a monster fading into view. A
## Node2D at the world's origin, so what it adds stands where it always did.

var world: Node2D

## A win's colours over the world (PIX-245): XP in a sea-glass green no
## other number uses (a blow is warm white, a heal mint, a fine piece blue),
## gold as the purse counts it, behind its coin; an item in its rarity's
## colour, lit to read on the ground rather than on paper (PIX-211's fine and
## epic), a common one cream like the words over the world.
const GAIN_TONES := {
	"xp": Color("7fe3d6"), "gold": UiStyle.GOLD, "common": UiStyle.CREAM,
	"fine": Color("8cc4ff"), "epic": Color("d99bff"),
}
## Where the foot of a win's lowest words stands, from the spot it was won
## (PIX-245): over a foe, above where the damage numbers go (their words rise
## from 18 to 30 px over it, a crit's to 34, while this rises far slower), so
## the killing blow's number and what it won never sit on each other; over
## the hero's head for what they pick up underfoot; just over a chest or the
## water.
const OVER_FOE := Vector2(0, -26)
const OVER_HERO := Vector2(0, -18)
const OVER_THING := Vector2(0, -10)
## A win's rows stack this far apart, upward (the words are 11 px tall); the
## first comes in once the blow's number has shown, each next this long after
## the one below it; the whole stays up this long from the last win that
## joined it, rising this far.
const GAIN_ROW := 12.0
const GAIN_FIRST := 0.15
const GAIN_STAGGER := 0.12
const GAIN_LIFE := 1.8
const GAIN_RISE := 14.0
## With motion reduced a win doesn't rise, while a damage number still does:
## it stands this much higher from the start, clear of the number's whole
## path.
const GAIN_STILL_LIFT := 8.0
## A row's mark: an item's 16 px icon and the purse's coin (drawn at the
## UI's 2x) come out about the words' height, and the icon at twice its art
## on screen at play zoom, as the pack shows it - in whole screen pixels
## whatever CameraRig.ZOOM is (a half, made for 4, drew them a pixel and a
## half wide at 3).
const GAIN_ICON := 2.0 / CameraRig.ZOOM

## The wins rising now, each {box, at, joined, gains, rows (key -> row),
## fresh, tween}: a new win near one of them soon enough joins it.
var _rising: Array[Dictionary] = []
## Everything floated on this visit, merged (the harness reports it).
var floated := Gains.none()
## What a fight has won so far, held until it's over (PIX-334): {gains, at
## (where the last of it was won), view (the map it was won on)}, or {}.
var _held := {}
## Blows on one foe this close together add up into one number (PIX-334),
## and the number each foe (and colour) shows now: key -> {word, value,
## crit, at}.
const NUMBER_JOIN_S := 0.3
var _numbers := {}
## A word over the world steps up clear of a level tag or a word already
## there (PIX-340, keep_clear), this far apart, at most this far.
const SLOT_MARGIN := 1.0
const MOST_LIFT := 36.0


## A word that rises and fades over where it happened (PIX-155: "dodged",
## "blocked"). A `big` one (a bell's "Dong!"; LEVEL UP was one until it
## went to the plate, PIX-340; a fine or epic drop's name rises with the
## rest of a win, show_gains) bursts in at twice its size unless motion is reduced, then settles at the
## pixel face's own (anything larger dwarfs the fighters), and stays longer.
func float_text(text: String, at: Vector2, color: Color, big := false) -> void:
	var label := _floating(text, color)
	label.position = Vector2(Ink.centred(_ink(label), at.x), roundf(at.y))
	label.z_index = 11 if big else 10
	_stand(label)
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


## A word over the world on its own stand (PIX-340): the label rises and
## fades on its own tween, the stand lifts it clear of what was there first
## (keep_clear). Gone with its word.
func _stand(label: Label) -> void:
	var stand := Node2D.new()
	stand.set_meta("word", label)
	label.tree_exited.connect(stand.queue_free)
	stand.add_child(label)
	add_child(stand)


## Each word over the world, oldest first, stepped up just clear
## (TextBudget.rise) of `reserved` (the level tags shown, Foes' pass), of the
## wins rising and of the words before it - never back down, so it doesn't
## jump about as the foes move. Words rising together at one pace stay clear.
func keep_clear(reserved: Array[Rect2]) -> void:
	var taken: Array[Rect2] = reserved.duplicate()
	for win: Dictionary in _rising:
		if is_instance_valid(win["box"]):
			for line: Node in (win["box"] as Node).get_children():
				for part: String in ["text", "then"]:
					if line.has_node(part):
						taken.append(_drawn(line.get_node(part)))
	for stand: Node in get_children():
		var word: Variant = stand.get_meta("word", null)
		if word == null or not is_instance_valid(word) or stand.is_queued_for_deletion():
			continue
		var lifted := -(stand as Node2D).position.y
		# Where it would be drawn unlifted.
		var rect := _drawn(word)
		rect.position.y += lifted
		lifted = TextBudget.rise(taken, rect, SLOT_MARGIN, lifted, MOST_LIFT)
		(stand as Node2D).position.y = -lifted
		rect.position.y -= lifted
		taken.append(rect)


## Where a floating label's words are drawn in the world.
static func _drawn(label: Label) -> Rect2:
	return Rect2(label.global_position + _ink(label).position, _ink(label).size)


## The pixels a floating label's words draw, from its top left (PIX-268).
## Its box is no measure: taken before the label is in the tree, it is the
## fallback font's at twice the size, and a number centred on it sat five
## pixels or so left of its foe.
static func _ink(label: Label) -> Rect2:
	# Measured once a text: the pass that keeps words clear asks every frame.
	if label.get_meta("inked", "") != label.text:
		label.set_meta("ink", Ink.of_text(label.text, UiStyle.bold_font(), UiStyle.BODY_PX))
		label.set_meta("inked", label.text)
	return label.get_meta("ink")


## A label bursting in at twice its size (PIX-209, PIX-211), not when motion
## is reduced: about the middle of its words.
func _pop(label: Label, tween: Tween) -> void:
	if GameState.settings.reduce_motion:
		return
	label.pivot_offset = _ink(label).get_center()
	label.scale = Vector2.ONE * 2.0
	tween.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A number over a head. Each lands a few pixels off the last (PIX-209), so
## a flurry reads as blows, not one smudge; a crit comes in gold with a "!"
## and a spark, bursting in at twice its size unless motion is reduced.
## Blows on one `who` in one colour within NUMBER_JOIN_S add up into one
## number (PIX-334: a pack's flurry read as a heap of numbers).
func float_number(value: int, at: Vector2, color: Color, crit := false, who: Object = null) -> void:
	var key := "%d:%s" % [who.get_instance_id(), color.to_html()] if who != null else ""
	var now := GameClock.seconds()
	var last: Dictionary = _numbers.get(key, {})
	if not last.is_empty() and now - float(last["at"]) <= NUMBER_JOIN_S and is_instance_valid(last["word"]):
		(last["word"] as Node).queue_free()
		value += int(last["value"])
		crit = crit or bool(last["crit"])
	var label := _floating(str(value) + ("!" if crit else ""), UiStyle.BRASS_LIGHT if crit else color)
	label.position = Vector2(Ink.centred(_ink(label), at.x + randf_range(-4.0, 4.0)), roundf(at.y - (4 if crit else 0)))
	label.z_index = 11 if crit else 10
	_stand(label)
	if key != "":
		_numbers[key] = {"word": label, "value": value, "crit": crit, "at": now}
	# The foes gone by leave their keys: let them go now and then.
	if _numbers.size() > 64:
		for stale: String in _numbers.keys():
			if now - float(_numbers[stale]["at"]) > NUMBER_JOIN_S:
				_numbers.erase(stale)
	var life := 0.8 if crit else 0.6
	var tween := label.create_tween().set_parallel()
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


## A level gained (PIX-211): a gold burst on the hero and the experience
## line flashing; its words go on the plate (Messages), after the fight
## (PIX-340: LEVEL UP over the hero's head ran across the foes beside them,
## over their tags and numbers, and said what the plate says).
func level_up_burst() -> void:
	if world.player == null:
		return
	skill_flash(world.player.global_position, UiStyle.GOLD)
	skill_flash(world.player.global_position + Vector2(0, -8), UiStyle.BRASS_LIGHT)
	world.hud.dock.flash_xp()


## A win floating up from where it was won (PIX-245: less to read in the
## log): XP, gold, then each item with its icon, in its rarity's colour, a
## fine or epic piece bursting in as its name did (PIX-211). A win soon after
## another nearby joins it (Gains.joins): its rows count up in place, so a
## pack felled in a few blows reads "+36 XP" once. With motion reduced
## nothing rises or bursts: the rows fade in where they stand (a little
## higher, GAIN_STILL_LIFT), then out.
## In a fight a win waits for its end (PIX-334: gold and XP popped over
## each kill of a pack, among the blows): the fight's wins, merged, rise as
## one from where the last was won.
func show_gains(gains: Dictionary, at: Vector2) -> void:
	if Gains.is_empty(gains):
		return
	Gains.merge(floated, gains)
	if world != null and world.get("foes") != null and world.foes.in_fight(Foes.CALM_S):
		if _held.is_empty():
			_held = {"gains": Gains.none()}
		Gains.merge(_held["gains"], gains)
		_held["at"] = at
		_held["view"] = world.view
		return
	_rise(gains, at)


## The fight's wins rise once it's over: where the last was won, or over the
## hero when that was on a map left behind.
func _process(_delta: float) -> void:
	if _held.is_empty() or world.foes.in_fight(Foes.CALM_S):
		return
	var held := _held
	_held = {}
	var at: Vector2 = held["at"] if held["view"] == world.view else world.player.global_position + OVER_HERO
	_rise(held["gains"], at)


func _rise(gains: Dictionary, at: Vector2) -> void:
	var now := GameClock.seconds()
	for i in range(_rising.size() - 1, -1, -1):
		var gone: Variant = _rising[i]["box"]
		if not is_instance_valid(gone) or (gone as Node).is_queued_for_deletion():
			_rising.remove_at(i)
	var win := {}
	for rising: Dictionary in _rising:
		if Gains.joins(rising["at"], rising["joined"], at, now):
			win = rising
			break
	if win.is_empty():
		var box := Node2D.new()
		box.position = (at - Vector2(0, GAIN_STILL_LIFT if GameState.settings.reduce_motion else 0.0)).round()
		box.z_index = 10
		add_child(box)
		win = {"box": box, "at": at, "joined": now, "gains": Gains.none(), "rows": {}, "fresh": true, "tween": null}
		_rising.append(win)
	win["joined"] = now
	Gains.merge(win["gains"], gains)
	_lay_out(win)
	_hold(win)


## A win's rows from the bottom up, each centred over the spot: a row it
## already shows counts up in place (a bump unless motion is reduced), a new
## one comes in after the last (all at once with motion reduced).
func _lay_out(win: Dictionary) -> void:
	var box: Node2D = win["box"]
	var shown: Dictionary = win["rows"]
	var still: bool = GameState.settings.reduce_motion
	var delay := GAIN_FIRST if win["fresh"] else 0.0
	var lift := 0.0
	var rows := Gains.rows(win["gains"])
	# A row whose key went (XP alone, then gold beside it: one purse row,
	# Gains.rows) gives way.
	for key: String in shown.keys():
		if not rows.any(func(row: Dictionary) -> bool: return row["key"] == key):
			(shown[key] as Node).queue_free()
			shown.erase(key)
	for row: Dictionary in rows:
		var line: Node2D = shown.get(row["key"])
		if line == null:
			line = _gain_row(row)
			box.add_child(line)
			shown[row["key"]] = line
			_come_in(line, delay, row["tone"] in ["fine", "epic"])
			if not still:
				delay += GAIN_STAGGER
		elif (line.get_node("text") as Label).text != row["text"] or _then(line) != row.get("then", ""):
			(line.get_node("text") as Label).text = row["text"]
			if line.has_node("then"):
				(line.get_node("then") as Label).text = "· " + row["then"]
			_fit_row(line)
			_bump(line)
		line.position = Vector2(0, -lift)
		lift += GAIN_ROW
	win["fresh"] = false


## One row of a win: its mark (an item's icon when there's art for it, the
## purse's coin for gold) and its words in the row's colour, about the row's
## foot so it bursts about its middle; the purse's XP after its gold in the
## XP's own colour (PIX-340: "+36 gold · +7 XP", one line).
func _gain_row(row: Dictionary) -> Node2D:
	var line := Node2D.new()
	var label := _floating(row["text"], GAIN_TONES.get(row["tone"], UiStyle.CREAM))
	label.name = "text"
	line.add_child(label)
	if row.has("then"):
		var then := _floating("· " + row["then"], GAIN_TONES["xp"])
		then.name = "then"
		line.add_child(then)
	var art: Texture2D = null
	if row["item"] != "":
		art = ItemIcons.texture(row["item"])
	elif row["tone"] == "gold":
		art = UiStyle.coin()
	if art != null:
		var icon := Sprite2D.new()
		icon.name = "icon"
		icon.texture = art
		icon.centered = false
		icon.scale = Vector2.ONE * GAIN_ICON
		# Bright at night, as the words are (PIX-221).
		icon.material = Lights.unshaded()
		line.add_child(icon)
	_fit_row(line)
	return line


## A row's pieces placed about its foot (the foot of its words): the mark,
## two pixels' gap, the words, centred together. The label's box runs wider
## and taller than the words it draws from its top left, so they're placed
## by the font's measure of the words, not by the box, and across by their
## ink (PIX-268: not the face's spacing after them).
func _fit_row(line: Node2D) -> void:
	var label: Label = line.get_node("text")
	label.size = label.get_minimum_size()
	var words := UiStyle.bold_font().get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.BODY_PX)
	var ink := _ink(label)
	var then: Label = line.get_node_or_null("then")
	# The XP after the gold, a space's width on (the face's own).
	var gap := UiStyle.bold_font().get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.BODY_PX).x
	var after := gap + _ink(then).size.x if then != null else 0.0
	var icon: Sprite2D = line.get_node_or_null("icon")
	var side := icon.texture.get_size().x * icon.scale.x if icon != null else 0.0
	var indent := side + 2.0 if icon != null else 0.0
	var left := Ink.centred(Rect2(0, 0, indent + ink.size.x + after, 0), 0.0)
	if icon != null:
		icon.position = Vector2(left, -roundf((words.y + side) / 2.0))
	label.position = Vector2(left + indent - ink.position.x, -words.y)
	if then != null:
		then.size = then.get_minimum_size()
		then.position = Vector2(left + indent + ink.size.x + gap - _ink(then).position.x, -words.y)


## A row's XP after its gold, or "".
static func _then(line: Node) -> String:
	return (line.get_node("then") as Label).text.trim_prefix("· ") if line.has_node("then") else ""


## A row fading in after `delay`; a fine or epic piece bursts in at twice
## its size (_pop's rule: not with motion reduced).
func _come_in(line: Node2D, delay: float, big: bool) -> void:
	line.modulate.a = 0.0
	var tween := line.create_tween().set_parallel()
	tween.tween_property(line, "modulate:a", 1.0, 0.12).set_delay(delay)
	if big and not GameState.settings.reduce_motion:
		line.scale = Vector2.ONE * 2.0
		tween.tween_property(line, "scale", Vector2.ONE, 0.22).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	line.set_meta("tween", tween)


## A row counted up by a win that joined: it swells a moment and settles
## (not with motion reduced), shown at once if it was still coming in.
func _bump(line: Node2D) -> void:
	var coming: Variant = line.get_meta("tween", null)
	if coming != null and (coming as Tween).is_valid():
		(coming as Tween).kill()
	line.modulate.a = 1.0
	line.scale = Vector2.ONE
	if GameState.settings.reduce_motion:
		return
	line.scale = Vector2.ONE * 1.3
	var settle := line.create_tween()
	settle.tween_property(line, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	line.set_meta("tween", settle)


## A win stays up GAIN_LIFE from the last that joined it, rising GAIN_RISE
## as it goes (in place with motion reduced), then fades away.
func _hold(win: Dictionary) -> void:
	var box: Node2D = win["box"]
	var held: Variant = win["tween"]
	if held != null and (held as Tween).is_valid():
		(held as Tween).kill()
	box.modulate.a = 1.0
	var tween := box.create_tween().set_parallel()
	if not GameState.settings.reduce_motion:
		tween.tween_property(box, "position:y", box.position.y - GAIN_RISE, GAIN_LIFE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(box, "modulate:a", 0.0, 0.45).set_delay(GAIN_LIFE - 0.45)
	tween.chain().tween_callback(box.queue_free)
	win["tween"] = tween


## A ring of dust motes kicked up from `at` (a monster appearing, a dodge).
## `held`: it drifts while a screen holds the world (the town's tour,
## PIX-264); the age's dust used to hang in the air until the tour let go.
func dust(at: Vector2, held := false) -> void:
	for i in 8:
		var mote := ColorRect.new()
		mote.color = Color(0.86, 0.8, 0.68, 0.9) if i % 2 == 0 else Color(0.7, 0.64, 0.52, 0.9)
		mote.size = Vector2(2, 2)
		mote.position = at + Vector2(-1, 1)
		mote.z_index = 4
		mote.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if held:
			mote.process_mode = Node.PROCESS_MODE_ALWAYS
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
