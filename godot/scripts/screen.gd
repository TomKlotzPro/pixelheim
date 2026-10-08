class_name Screen
extends CanvasLayer
## What every screen shares (PIX-136): the menus, pages and conversations
## that open over the world. A screen
## - keeps running while the world is paused, and holds the world still while
##   it is open. Holds are counted, so the world runs again only when the
##   last screen lets go: options over the pause menu or the title, a rank-up
##   over a conversation, a shop opening as a conversation closes;
## - may dim the world behind it (`dim`);
## - takes its keys one way: `_command` turns an event into what to do, the
##   event is marked handled, then it runs. Handled first, because an action
##   that reloads the scene frees the screen, and a key must never reach a
##   second screen as well (PIX-131);
## - closes on Esc, the menu key and its own keys (`closing_actions`), when
##   `_command` doesn't claim the event first.
## A screen builds itself in `_open` (not `_ready`).

## Screens holding the world still right now.
static var _holds := 0

## Actions besides Esc and the menu key that close this screen (its own key:
## I closes the pack).
var closing_actions: Array[StringName] = []
var _holding := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# On a phone the canvas outgrows 1280x720: the screen keeps to the middle
	# (PIX-162). On a desktop this is no offset at all.
	offset = Touch.center_offset(self)
	_hold()
	_open()
	if Touch.enabled() and _wants_tap_bar():
		_tap_bar()


## Builds the screen.
func _open() -> void:
	pass


## What this screen does for `event`, or an empty Callable to let it pass
## (on to closing, then to whatever is under the screen).
func _command(_event: InputEvent) -> Callable:
	return Callable()


func _unhandled_input(event: InputEvent) -> void:
	var command := _command(event)
	if not command.is_valid() and _closes_on(event):
		command = close
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()


func _closes_on(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
		return true
	return closing_actions.any(func(action: StringName) -> bool: return event.is_action_pressed(action))


## Leaves; the world runs again unless another screen still holds it.
func close() -> void:
	_let_go()
	queue_free()


## The world behind, dimmed (fully hidden at 1.0), edge to edge whatever
## the screen's shape.
func dim(alpha := UiStyle.BACKDROP.a) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = Color(UiStyle.BACKDROP, alpha)
	backdrop.position = -offset
	backdrop.size = Touch.view_size(self)
	add_child(backdrop)
	return backdrop


## Whether this screen takes the tap bar on a phone; a story scene that
## moves on by itself, or by any tap, doesn't need it.
func _wants_tap_bar() -> bool:
	return true


## Keys for fingers (PIX-162): buttons that send the actions every screen
## already understands - the arrows, OK (E) and Back (Esc). They stand in
## the room a phone leaves beside the 1280x720 layout (a column at the side
## when held sideways, a row below when upright), over its corner when
## there is none.
func _tap_bar() -> void:
	var size := Touch.view_size(self)
	var scale := maxf(0.2, get_tree().root.get_final_transform().get_scale().x)
	var button_px := 46.0 / scale
	var gap := 8.0 / scale
	var spare := (size - Touch.DESIGN) / 2.0
	var keys := [["<", "move_left"], ["^", "move_up"], ["v", "move_down"], [">", "move_right"], ["OK", "interact"], ["Back", "ui_cancel"]]
	var column := spare.x >= button_px * 1.15 + gap * 2
	var bar: BoxContainer = VBoxContainer.new() if column else HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(gap))
	for key: Array in keys:
		var button := Button.new()
		button.text = key[0]
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(button_px * (1.15 if column else (1.6 if key[0].length() > 1 else 1.0)), button_px)
		button.add_theme_font_size_override("font_size", roundi(button_px * 0.4))
		button.add_theme_stylebox_override("normal", UiStyle.box(Color(UiStyle.NIGHT, 0.8), UiStyle.RIM, 8))
		button.add_theme_stylebox_override("pressed", UiStyle.box(Color(UiStyle.LAMP, 0.8), UiStyle.RIM, 8))
		button.add_theme_stylebox_override("hover", UiStyle.box(Color(UiStyle.NIGHT, 0.8), UiStyle.RIM, 8))
		button.add_theme_color_override("font_color", UiStyle.CREAM)
		var action: String = key[1]
		button.button_down.connect(func() -> void: _tap(action))
		bar.add_child(button)
	add_child(bar)
	bar.reset_size()
	var at := Vector2(size.x - bar.size.x - gap * 2, size.y - bar.size.y - gap * 2)
	if column:
		at = Vector2(size.x - spare.x / 2.0 - bar.size.x / 2.0, (size.y - bar.size.y) / 2.0)
	elif spare.y >= button_px + gap * 2:
		at = Vector2((size.x - bar.size.x) / 2.0, size.y - spare.y / 2.0 - bar.size.y / 2.0)
	bar.position = (at - offset).round()


func _tap(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	var lift := InputEventAction.new()
	lift.action = action
	lift.pressed = false
	Input.parse_input_event(lift)


## How many screens hold the world (what the tests read).
static func holds() -> int:
	return _holds


func _hold() -> void:
	if _holding:
		return
	_holding = true
	_holds += 1
	get_tree().paused = true


func _let_go() -> void:
	if not _holding:
		return
	_holding = false
	_holds = maxi(0, _holds - 1)
	if _holds == 0:
		get_tree().paused = false


## Freed without closing (the scene reloading under it): its hold goes too.
func _exit_tree() -> void:
	_let_go()
