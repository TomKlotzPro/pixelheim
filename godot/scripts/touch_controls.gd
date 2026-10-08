extends CanvasLayer
## On-screen controls for a phone (PIX-162): a thumbstick under the left
## thumb and the hero's buttons under the right - attack, dodge roll, use,
## and the first three skills. They speak the game's own actions (the stick
## presses the move actions with its strength, a button sends its action as
## a key would), so everything else plays as it does by keyboard. They hide
## while a screen is open; screens have their own tap bar (Screen).

## Sizes in screen pixels, whatever the canvas's scale: a thumb is a thumb.
const STICK_PX := 64.0
const BIG_PX := 42.0
const SMALL_PX := 30.0
const MARGIN_PX := 28.0
const DEADZONE := 0.22

var pad: Pad


func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	pad = Pad.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pad)
	get_tree().root.size_changed.connect(pad.layout)
	pad.layout()


func _process(_delta: float) -> void:
	var shown := Screen.holds() == 0
	if shown != pad.visible:
		pad.visible = shown
		if not shown:
			pad.let_go()


func _input(event: InputEvent) -> void:
	if pad.visible and pad.take(event):
		get_viewport().set_input_as_handled()


class Pad extends Control:
	var stick_center := Vector2.ZERO
	var stick_radius := 64.0
	var knob := Vector2.ZERO
	var stick_finger := -1
	## {action, label, center, radius, finger}
	var buttons: Array[Dictionary] = []

	## Where everything goes for this screen: the stick bottom-left and the
	## buttons bottom-right, above the dock.
	func layout() -> void:
		var size := Touch.view_size(self)
		var scale := maxf(0.2, get_tree().root.get_final_transform().get_scale().x)
		var dock_room := 130.0
		stick_radius = STICK_PX / scale
		var margin := MARGIN_PX / scale
		var big := BIG_PX / scale
		var small := SMALL_PX / scale
		stick_center = Vector2(margin + stick_radius, size.y - dock_room - margin - stick_radius)
		var attack := Vector2(size.x - margin - big, size.y - dock_room - margin - big)
		buttons = [
			{"action": "attack", "label": "Hit", "center": attack, "radius": big},
			{"action": "dodge", "label": "Roll", "center": attack + Vector2(-big * 2.3, big * 0.3), "radius": small},
			{"action": "interact", "label": "Use", "center": attack + Vector2(-big * 1.5, -big * 1.7), "radius": small},
			{"action": "skill_1", "label": "1", "center": attack + Vector2(0, -big * 2.6), "radius": small * 0.85},
			{"action": "skill_2", "label": "2", "center": attack + Vector2(-big * 1.4, -big * 3.4), "radius": small * 0.85},
			{"action": "skill_3", "label": "3", "center": attack + Vector2(-big * 2.9, -big * 2.6), "radius": small * 0.85},
		]
		for button: Dictionary in buttons:
			button["finger"] = -1
		for child in get_children():
			child.queue_free()
		for button: Dictionary in buttons:
			var label := UiStyle.strong(button["label"], maxi(12, roundi(float(button["radius"]) * 0.55)), UiStyle.CREAM)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.size = Vector2(button["radius"], button["radius"]) * 2.0
			label.position = button["center"] - Vector2(button["radius"], button["radius"])
			add_child(label)
		queue_redraw()

	## Claims a touch on the stick or a button; false lets it through.
	func take(event: InputEvent) -> bool:
		if event is InputEventScreenTouch:
			var touch := event as InputEventScreenTouch
			if touch.pressed:
				if stick_finger == -1 and touch.position.distance_to(stick_center) <= stick_radius * 1.5:
					stick_finger = touch.index
					_steer(touch.position)
					return true
				for button: Dictionary in buttons:
					if int(button["finger"]) == -1 and touch.position.distance_to(button["center"]) <= float(button["radius"]) * 1.2:
						button["finger"] = touch.index
						_send(button["action"], true)
						queue_redraw()
						return true
				return false
			if touch.index == stick_finger:
				_release_stick()
				return true
			for button: Dictionary in buttons:
				if int(button["finger"]) == touch.index:
					button["finger"] = -1
					_send(button["action"], false)
					queue_redraw()
					return true
		elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == stick_finger:
			_steer((event as InputEventScreenDrag).position)
			return true
		return false

	## Lets go of everything (a screen opened over the world).
	func let_go() -> void:
		if stick_finger != -1:
			_release_stick()
		for button: Dictionary in buttons:
			if int(button["finger"]) != -1:
				button["finger"] = -1
				_send(button["action"], false)

	func _steer(at: Vector2) -> void:
		knob = (at - stick_center).limit_length(stick_radius)
		var heading := knob / stick_radius
		if heading.length() < DEADZONE:
			heading = Vector2.ZERO
		for pair: Array in [["move_left", -heading.x], ["move_right", heading.x], ["move_up", -heading.y], ["move_down", heading.y]]:
			if float(pair[1]) > 0.0:
				Input.action_press(pair[0], float(pair[1]))
			else:
				Input.action_release(pair[0])
		queue_redraw()

	func _release_stick() -> void:
		stick_finger = -1
		knob = Vector2.ZERO
		for action: String in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		queue_redraw()

	func _send(action: String, pressed: bool) -> void:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)

	func _draw() -> void:
		draw_circle(stick_center, stick_radius, Color(UiStyle.NIGHT, 0.35))
		draw_arc(stick_center, stick_radius, 0, TAU, 48, Color(UiStyle.CREAM, 0.45), 3.0)
		draw_circle(stick_center + knob, stick_radius * 0.42, Color(UiStyle.CREAM, 0.55))
		for button: Dictionary in buttons:
			var held := int(button["finger"]) != -1
			draw_circle(button["center"], button["radius"], Color(UiStyle.LAMP if held else UiStyle.NIGHT, 0.6 if held else 0.4))
			draw_arc(button["center"], button["radius"], 0, TAU, 40, Color(UiStyle.CREAM, 0.5), 3.0)
