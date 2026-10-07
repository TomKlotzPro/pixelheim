class_name Controls
## The keys (src/app/settings.ts bindings, grown for real-time play): every
## action has one primary key the options screen can rebind, plus fixed
## alternates that always work (arrows, Enter, Space, Tab) and gamepad
## buttons. Bindings live in GameSettings, outside the save.

## Rebindable actions, in the options screen's order: action -> [label, default key].
const BINDABLE := {
	"move_up": ["Move up", KEY_W],
	"move_down": ["Move down", KEY_S],
	"move_left": ["Move left", KEY_A],
	"move_right": ["Move right", KEY_D],
	"attack": ["Attack", KEY_J],
	"interact": ["Talk / interact", KEY_E],
	"inventory": ["Inventory", KEY_I],
	"map": ["World map", KEY_M],
	"journal": ["Journal", KEY_Q],
	"stats": ["Stats", KEY_C],
	"skills": ["Skills", KEY_K],
	"codex": ["Codex", KEY_B],
}
## Keys that always work beside the primary one.
const ALTERNATES := {
	"move_up": [KEY_UP], "move_down": [KEY_DOWN], "move_left": [KEY_LEFT], "move_right": [KEY_RIGHT],
	"attack": [KEY_SPACE], "interact": [KEY_ENTER], "map": [KEY_TAB],
	"drop": [KEY_X], "drop_all": [KEY_Z], "menu": [KEY_ESCAPE],
}
## Skills by their place in the hero's list: the number row, fixed.
const SKILL_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
## InputMap's "any device" (Godot's InputMap::ALL_DEVICES).
const ALL_DEVICES := -1
const PAD_BUTTONS := {
	"attack": JOY_BUTTON_A, "interact": JOY_BUTTON_B, "map": JOY_BUTTON_Y, "menu": JOY_BUTTON_START,
	"inventory": JOY_BUTTON_X,
}
const PAD_STICK := {
	"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
}


## The key an action answers to first: the player's choice or the default.
static func key_for(action: String, bindings: Dictionary) -> int:
	return int(bindings.get(action, BINDABLE[action][1]))


## Binds `key` to `action`; an action already holding that key takes the
## old key in exchange, so no two actions ever share one.
static func rebind(bindings: Dictionary, action: String, key: int) -> Dictionary:
	var next := bindings.duplicate()
	var old := key_for(action, bindings)
	for other: String in BINDABLE:
		if other != action and key_for(other, bindings) == key:
			next[other] = old
	next[action] = key
	return next


## A key's name for the screen ("W", "Space", "Escape").
static func key_label(key: int) -> String:
	return OS.get_keycode_string(key)


## Rebuilds the InputMap from scratch: primaries, alternates, the pad.
static func apply(bindings: Dictionary) -> void:
	var actions := {}
	for action: String in BINDABLE:
		actions[action] = true
	for action: String in ALTERNATES:
		actions[action] = true
	for index in SKILL_KEYS.size():
		actions["skill_%d" % (index + 1)] = true
	for action: String in actions:
		if InputMap.has_action(action):
			InputMap.action_erase_events(action)
		else:
			InputMap.add_action(action)
		var keys: Array = ALTERNATES.get(action, []).duplicate()
		if action.begins_with("skill_"):
			keys = [SKILL_KEYS[int(action.substr(6)) - 1]]
		if BINDABLE.has(action):
			keys.push_front(key_for(action, bindings))
		# Every binding answers any keyboard or pad (device -1), not only the
		# first one plugged in.
		for key: int in keys:
			var event := InputEventKey.new()
			event.physical_keycode = key
			event.device = ALL_DEVICES
			InputMap.action_add_event(action, event)
		if PAD_BUTTONS.has(action):
			var button := InputEventJoypadButton.new()
			button.button_index = PAD_BUTTONS[action]
			button.device = ALL_DEVICES
			InputMap.action_add_event(action, button)
		if PAD_STICK.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = PAD_STICK[action][0]
			motion.axis_value = PAD_STICK[action][1]
			motion.device = ALL_DEVICES
			InputMap.action_add_event(action, motion)
