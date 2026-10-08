extends Screen
## The town risen (PIX-147): after a project is funded, the camera walks the
## town to what was built - "Street lamps: built." under each - and when an
## age is complete it says what Pixelheim is now; a homecoming after a boss
## falls says how the town took the news. The world holds still meanwhile;
## E moves on, Esc skips to the end.

## [{at: Vector2 (map pixels), line: String}]
var stops: Array[Dictionary] = []
var world: Node
## What comes after the last stop (the ending's credits).
var on_done := Callable()
var caption: Label
var _index := -1
var _tour: Tween


func _open() -> void:
	layer = 4
	caption = UiStyle.strong("", 24, UiStyle.CREAM)
	caption.add_theme_color_override("font_outline_color", UiStyle.NIGHT)
	caption.add_theme_constant_override("outline_size", 8)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.position = Vector2(140, 520)
	caption.size = Vector2(1000, 0)
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(caption)
	add_child(UiStyle.footer("E  next      Esc  skip", Vector2(1010, 40)))
	world.camera_follows = false
	# The camera answers to the tour while the world is held.
	world.camera.process_mode = Node.PROCESS_MODE_ALWAYS
	_next()


func _command(event: InputEvent) -> Callable:
	if event.is_action_pressed("interact") or event.is_action_pressed("attack"):
		return _next
	return Callable()


## The next stop: the camera eases there and its line shows; past the last,
## back to the hero.
func _next() -> void:
	_index += 1
	if _tour != null:
		_tour.kill()
	if _index >= stops.size():
		close()
		return
	var stop: Dictionary = stops[_index]
	caption.text = ""
	_tour = world.camera.create_tween()
	_tour.tween_property(world.camera, "global_position", stop["at"], 0.0 if GameState.settings.reduce_motion else 0.9).set_trans(Tween.TRANS_SINE)
	_tour.tween_callback(func() -> void:
		caption.text = stop["line"]
		Sound.play("coin")
	)
	# Long enough to read the line (the dawn's are long).
	_tour.tween_interval(clampf(String(stop["line"]).length() / 22.0, 2.2, 6.0))
	_tour.tween_callback(_next)


func close() -> void:
	if _tour != null:
		_tour.kill()
	world.camera.process_mode = Node.PROCESS_MODE_INHERIT
	world.camera_follows = true
	world._teleported()
	super.close()
	if on_done.is_valid():
		on_done.call()
