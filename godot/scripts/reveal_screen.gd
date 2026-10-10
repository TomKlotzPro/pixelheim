extends Screen
## The town risen (PIX-147): after a project is funded, the camera walks the
## town to what was built - "Street lamps: built." under each - and when an
## age is complete it says what Pixelheim is now; a homecoming after a boss
## falls says how the town took the news. The world holds still meanwhile;
## E moves on, Esc skips to the end.
##
## A project's stop raises it (PIX-264): its ruin stands from the moment the
## tour opens, gives way in dust as the camera arrives, and the building goes
## up out of it (RebuildRise); its name shows as it lands, what it brings
## under it. An age's stop names who moved in.

## [{at: Vector2 (map pixels), line: String, detail: String (smaller, under
## the line), project: id (raised at its stop)}]
var stops: Array[Dictionary] = []
## Where the caption's last line ends: just above the dock.
const CAPTION_FOOT := 594.0
## What it brings comes a breath after its name.
const DETAIL_DELAY := 0.35
var world: Node
## What comes after the last stop (the ending's credits).
var on_done := Callable()
var caption: Label
var detail: Label
var _index := -1
var _tour: Tween
var _detail_in: Tween
## Stop index -> the building rising there.
var _rises := {}


func _open() -> void:
	layer = 4
	caption = _line(UiStyle.strong("", 24, UiStyle.CREAM), 8)
	# Cream like the name (gold was lost on the town's sandy roads).
	detail = _line(UiStyle.label("", 18, UiStyle.CREAM), 8)
	add_child(UiStyle.footer("{key:interact}  next      Esc  skip", Vector2(1010, 40)))
	world.camera_rig.follows = false
	# The camera answers to the tour while the world is held.
	world.camera_rig.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	# Every building on the tour shows its ruin until its stop: none is seen
	# finished before it rises.
	if world.map.id == "town":
		var view: MapView = world.view
		for i in stops.size():
			if stops[i].has("project"):
				var rise := RebuildRise.new()
				rise.world = world
				rise.project_id = stops[i]["project"]
				view.ground.add_child(rise)
				_rises[i] = rise
	_next()


## A centred line over the world, outlined in the night.
func _line(label: Label, outline: int) -> Label:
	label.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
	label.add_theme_constant_override("outline_size", outline)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(140, 520)
	label.size = Vector2(1000, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(label)
	return label


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		return _next
	return Callable()


## The next stop: the camera eases there, a building rises if one is
## raised there, and its line shows; past the last, back to the hero.
func _next() -> void:
	_index += 1
	for tween: Tween in [_tour, _detail_in]:
		if tween != null:
			tween.kill()
	# Moved on mid-rise, the last stop's building stands at once.
	_stand(_index - 1)
	if _index >= stops.size():
		close()
		return
	var stop: Dictionary = stops[_index]
	caption.text = ""
	detail.text = ""
	_tour = world.camera_rig.camera.create_tween()
	_tour.tween_property(world.camera_rig.camera, "global_position", stop["at"], 0.0 if GameState.settings.reduce_motion else 0.9).set_trans(Tween.TRANS_SINE)
	var rise: RebuildRise = _rises.get(_index)
	if rise != null:
		_tour.tween_callback(rise.play)
		_tour.tween_interval(RebuildRise.seconds())
	_tour.tween_callback(func() -> void:
		_show(caption, stop["line"])
		_show(detail, stop.get("detail", ""))
		_lay_out()
		if not GameState.settings.reduce_motion and detail.text != "":
			detail.modulate.a = 0.0
			_detail_in = detail.create_tween()
			_detail_in.tween_property(detail, "modulate:a", 1.0, 0.3).set_delay(DETAIL_DELAY)
		# A new age is bigger news than a building (PIX-211): it evolves,
		# raising dust on the square.
		Sound.play(stop.get("sound", "coin"))
		if stop.get("dust", false):
			for spot: Vector2 in [Vector2(-20, 6), Vector2(18, -4), Vector2(0, 14), Vector2(-6, -12)]:
				world.fx.dust(stop["at"] + spot, true)
	)
	# Long enough to read the lines (the dawn's are long).
	_tour.tween_interval(UiStyle.reading_seconds(stop["line"] + " " + stop.get("detail", "")))
	_tour.tween_callback(_next)


func _show(label: Label, text: String) -> void:
	label.text = text
	label.modulate.a = 1.0
	label.size = Vector2(1000, 0)


## Standing on the dock's top edge however many lines they take: what it
## brings at the foot, its name over it.
func _lay_out() -> void:
	var foot := CAPTION_FOOT
	if detail.text != "":
		detail.position.y = foot - detail.get_minimum_size().y
		foot = detail.position.y - 4
	caption.position.y = foot - caption.get_minimum_size().y


## The building raised at stop `index`, standing now if it isn't yet.
func _stand(index: int) -> void:
	var rise: Variant = _rises.get(index)
	if rise != null and is_instance_valid(rise):
		(rise as RebuildRise).finish()


func close() -> void:
	if _tour != null:
		_tour.kill()
	# Skipped, every building on the tour stands.
	for index: int in _rises:
		_stand(index)
	world.camera_rig.camera.process_mode = Node.PROCESS_MODE_INHERIT
	world.camera_rig.follows = true
	world.camera_rig.cut()
	super.close()
	if on_done.is_valid():
		on_done.call()
