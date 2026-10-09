extends Screen
## The festival's ring toss (PIX-159): a ring slides along the rail, back and
## forth, quicker each throw; E throws it, and it lands if it's over the
## peg. Three throws, two on the peg wins the festival's prize (once per
## festival; after that it's just for fun). Free to play, as often as you
## like. Esc leaves.

const RAIL := Rect2(240, 300, 800, 24)
const PEG_WIDTH := 70.0
const RING := 36.0

var throws := 0
var hits := 0
## Where along the rail the ring is (0..1) and which way it's going.
var at := 0.0
var going := 1.0
var speed := 0.55
var peg_at := 0.5
var ring: Panel
var peg: ColorRect
var post: ColorRect
var score: Label
var status: Label
var marks: Array[ColorRect] = []
var done := false


func _open() -> void:
	layer = 5
	dim()
	var page := UiStyle.page(Rect2(200, 150, 880, 400))
	add_child(page)
	add_child(UiStyle.heading("Ring Toss", 20, UiStyle.CREAM, Vector2(220, 104)))
	add_child(UiStyle.label("Throw when the ring is over the peg. Two of three wins the prize.", 14, UiStyle.DUSK, Vector2(220, 132)))
	var rail := ColorRect.new()
	rail.color = Color("6b4a2c")
	rail.position = RAIL.position
	rail.size = RAIL.size
	add_child(rail)
	# Where a throw lands: a lighter strip on the rail, a peg standing in it.
	peg = ColorRect.new()
	peg.color = Color("c9a46a")
	peg.size = Vector2(PEG_WIDTH, RAIL.size.y)
	add_child(peg)
	post = ColorRect.new()
	post.color = Color("4a3426")
	post.size = Vector2(10, 64)
	add_child(post)
	ring = Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = UiStyle.GOLD
	box.set_border_width_all(6)
	box.set_corner_radius_all(18)
	ring.add_theme_stylebox_override("panel", box)
	ring.size = Vector2(RING, RING)
	add_child(ring)
	for i in int(Town.festival("throws")):
		var mark := ColorRect.new()
		mark.color = Color(UiStyle.FADED, 0.4)
		mark.size = Vector2(22, 22)
		mark.position = Vector2(560 + i * 34, 390)
		add_child(mark)
		marks.append(mark)
	score = UiStyle.strong("", 16, UiStyle.INK, Vector2(240, 430))
	add_child(score)
	status = UiStyle.label("", 14, UiStyle.INK, Vector2(240, 470))
	status.custom_minimum_size = Vector2(800, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	add_child(UiStyle.screen_footer("{key:interact}  throw      Esc  close"))
	_new_round()


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		return _throw
	return Callable()


func _process(delta: float) -> void:
	at += going * speed * delta
	if at > 1.0 or at < 0.0:
		going = -going
		at = clampf(at, 0.0, 1.0)
	_place()


func _place() -> void:
	ring.position = Vector2(RAIL.position.x + at * (RAIL.size.x - RING), RAIL.position.y - 6)
	peg.position = Vector2(RAIL.position.x + peg_at * (RAIL.size.x - PEG_WIDTH), RAIL.position.y)
	post.position = Vector2(peg.position.x + (PEG_WIDTH - post.size.x) / 2.0, RAIL.position.y - 48)


## A throw: on the peg when the ring's middle is over it.
func _throw() -> void:
	if done:
		_new_round()
		return
	var middle := ring.position.x + RING / 2.0
	var landed := middle >= peg.position.x and middle <= peg.position.x + PEG_WIDTH
	marks[throws].color = Color("5cbf4a") if landed else Color("d8433f")
	throws += 1
	hits += 1 if landed else 0
	Sound.play("coin" if landed else "bump")
	# Each throw the ring slides quicker and the peg moves.
	speed += 0.25
	peg_at = randf_range(0.1, 0.9)
	_score()
	if throws >= marks.size():
		_finish()


func _finish() -> void:
	done = true
	if hits >= int(Town.festival("hitsToWin")):
		var prize := GameState.win_ring_toss()
		Sound.play("levelUp" if prize != "" else "coin")
		status.text = prize if prize != "" else Controls.say(Text.t("On the peg again! The prize is already yours this festival. {key:interact} to throw again."))
		if prize != "":
			status.text += Controls.say(Text.t(" {key:interact} to throw again."))
	else:
		status.text = Controls.say(Text.t("Not this time. {key:interact} to throw again."))


func _new_round() -> void:
	done = false
	throws = 0
	hits = 0
	speed = 0.55
	at = 0.0
	going = 1.0
	peg_at = randf_range(0.2, 0.8)
	for mark in marks:
		mark.color = Color(UiStyle.FADED, 0.4)
	status.text = ""
	_score()
	_place()


func _score() -> void:
	score.text = Text.t("On the peg: %d of %d") % [hits, throws]
