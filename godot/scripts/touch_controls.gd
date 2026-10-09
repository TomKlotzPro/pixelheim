extends CanvasLayer
## On-screen controls for a phone (PIX-162): a thumbstick under the left
## thumb and the hero's buttons under the right - attack, dodge roll, use,
## and the first three skills. They speak the game's own actions (the stick
## presses the move actions with its strength, a button sends its action as
## a key would), so everything else plays as it does by keyboard. They hide
## while a screen is open; screens have their own tap bar (Screen).

## Where the stick and buttons go: Touch.pad_plan (PIX-214).
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
		else:
			pad.layout()


func _input(event: InputEvent) -> void:
	if pad.visible and pad.take(event):
		get_viewport().set_input_as_handled()


class Pad extends Control:
	var stick_center := Vector2.ZERO
	var stick_radius := 64.0
	var knob := Vector2.ZERO
	var stick_finger := -1
	## {action, glyph, center, radius, finger}
	var buttons: Array[Dictionary] = []

	## Where everything goes for this screen: the stick bottom-left, attack in
	## the bottom-right corner, then around it - a ring with the roll, the
	## first skill and use, and a wider ring with skills two to six - all
	## above the dock.
	func layout() -> void:
		var planned := Touch.pad_plan(Touch.view_size(self), Touch.css(self, 1.0))
		stick_center = planned["stick_center"]
		stick_radius = planned["stick_radius"]
		buttons.assign(planned["buttons"])
		for button: Dictionary in buttons:
			button["finger"] = -1
		for child in get_children():
			child.queue_free()
		# Each skill key shows the skill on it (its icon, else its number).
		var docked := Skills.docked(GameState.hero)
		for button: Dictionary in buttons:
			var action: String = button["action"]
			if not action.begins_with("skill_"):
				continue
			var index := int(action.substr(6)) - 1
			var icon: Texture2D = ItemIcons.skill(docked[index]["name"]) if index < docked.size() and not docked[index].is_empty() else null
			var radius: float = button["radius"]
			if icon != null:
				var art := TextureRect.new()
				art.texture = icon
				art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				art.size = Vector2(radius, radius) * 1.2
				art.position = button["center"] - art.size / 2.0
				art.mouse_filter = Control.MOUSE_FILTER_IGNORE
				add_child(art)
			else:
				var label := UiStyle.strong(button["glyph"], 18, UiStyle.CREAM)
				label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				label.size = Vector2(radius, radius) * 2.0
				label.position = button["center"] - Vector2(radius, radius)
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
			_glyph(button["glyph"], button["center"], float(button["radius"]) * 0.5)

	## A button's mark drawn, not written (PIX-214: "Frapper" and "Roulade"
	## spilled out of their circles): a sword, a rolling arrow, an open hand.
	func _glyph(glyph: String, at: Vector2, reach: float) -> void:
		var ink := Color(UiStyle.CREAM, 0.9)
		var width := maxf(2.0, reach * 0.16)
		match glyph:
			"sword":
				var tip := at + Vector2(reach, -reach)
				var hilt := at + Vector2(-reach * 0.6, reach * 0.6)
				draw_line(hilt, tip, ink, width * 1.3)
				draw_line(hilt + Vector2(-reach * 0.35, -reach * 0.35), hilt + Vector2(reach * 0.35, reach * 0.35), ink, width)
				draw_line(hilt, hilt + Vector2(-reach * 0.35, reach * 0.35), ink, width)
			"roll":
				draw_arc(at, reach * 0.8, deg_to_rad(-200), deg_to_rad(60), 24, ink, width)
				var end := at + Vector2.RIGHT.rotated(deg_to_rad(60)) * reach * 0.8
				draw_line(end, end + Vector2(-reach * 0.5, -reach * 0.05), ink, width)
				draw_line(end, end + Vector2(reach * 0.05, -reach * 0.5), ink, width)
			"use":
				# An open hand: a palm and four fingers.
				draw_circle(at + Vector2(0, reach * 0.25), reach * 0.45, ink)
				for i in 4:
					var x := (i - 1.5) * reach * 0.28
					draw_line(at + Vector2(x, reach * 0.1), at + Vector2(x, -reach * (0.75 if i in [1, 2] else 0.55)), ink, width)
