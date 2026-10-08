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
	_hold()
	_open()


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


## The world behind, dimmed (fully hidden at 1.0).
func dim(alpha := UiStyle.BACKDROP.a) -> ColorRect:
	var backdrop := ColorRect.new()
	backdrop.color = Color(UiStyle.BACKDROP, alpha)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	return backdrop


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
