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
	"dodge": ["Dodge roll", KEY_SHIFT],
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
	"attack": [KEY_SPACE], "interact": [KEY_ENTER], "map": [KEY_TAB], "dodge": [KEY_L],
	"drop": [KEY_X], "drop_all": [KEY_Z], "menu": [KEY_ESCAPE],
}
## Skills by their place in the hero's list: the number row, fixed.
const SKILL_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
## InputMap's "any device" (Godot's InputMap::ALL_DEVICES).
const ALL_DEVICES := -1
## The pad (PIX-215): A answers and confirms, B only goes back (Godot's
## ui_cancel), X swings, Y opens the pack, RB rolls, LB the first skill,
## Back the dock's menu (the other screens, skills 4-6), Start the pause
## menu; the D-pad walks like the stick.
const PAD_BUTTONS := {
	"interact": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "inventory": JOY_BUTTON_Y, "menu": JOY_BUTTON_START,
	"dodge": JOY_BUTTON_RIGHT_SHOULDER, "skill_1": JOY_BUTTON_LEFT_SHOULDER, "dock_menu": JOY_BUTTON_BACK,
	"move_up": JOY_BUTTON_DPAD_UP, "move_down": JOY_BUTTON_DPAD_DOWN,
	"move_left": JOY_BUTTON_DPAD_LEFT, "move_right": JOY_BUTTON_DPAD_RIGHT,
}
## The triggers, pulled: skills 2 and 3.
const PAD_TRIGGERS := {"skill_2": JOY_AXIS_TRIGGER_LEFT, "skill_3": JOY_AXIS_TRIGGER_RIGHT}
## What a keycap reads for an action while the player plays by pad.
const PAD_NAMES := {
	"interact": "A", "attack": "X", "inventory": "Y", "menu": "Start", "dodge": "RB",
	"skill_1": "LB", "skill_2": "LT", "skill_3": "RT", "dock_menu": "Back",
	"move_up": "↑", "move_down": "↓", "move_left": "←", "move_right": "→",
	"map": "Back", "journal": "Back", "stats": "Back", "skills": "Back", "codex": "Back",
	"skill_4": "Back", "skill_5": "Back", "skill_6": "Back",
}
## Keys named outright in footers, as the pad has them.
const PAD_FOR_KEYS := {"Esc": "B", "Enter": "A"}
## Whether the last thing the player touched was a pad (PIX-215): keycaps
## then show its buttons.
static var pad := false
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


## What the player's own keyboard calls each physical key (PIX-201): an
## AZERTY board's "Z" where a QWERTY board has "W". Learned from the keys
## pressed (a browser may not say), else asked of the system.
static var learned := {}


static func learn(event: InputEventKey) -> void:
	if event.physical_keycode != KEY_NONE and event.key_label != KEY_NONE:
		learned[event.physical_keycode] = event.key_label


## Notes which hands are on the game (PIX-215): a key or a click, or a pad's
## button or a firm push of its stick.
static func note_device(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		pad = false
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5):
		pad = true


## A physical key's name for the screen, on the player's layout ("W", "Space",
## "Esc"): short where a cap is small (Keycap.SHORT).
static func key_label(key: int) -> String:
	var shown: int = learned.get(key, KEY_NONE)
	if shown == KEY_NONE and DisplayServer.get_name() != "headless":
		shown = DisplayServer.keyboard_get_label_from_physical(key)
	if shown == KEY_NONE:
		shown = key
	var name := OS.get_keycode_string(shown)
	return String(Keycap.SHORT.get(name, name))


## A key as the code names it ("{key:interact}", or a QWERTY letter for a
## screen's own physical key, "X"), as the player's keyboard shows it.
## Digits and named keys (Esc, Tab, Enter...) read the same everywhere.
static func shown(name: String) -> String:
	if name.begins_with("{key:"):
		return say(name)
	if pad and PAD_FOR_KEYS.has(name):
		return PAD_FOR_KEYS[name]
	if name.length() == 1 and name.to_upper() != name.to_lower():
		return key_label(OS.find_keycode_from_string(name.to_upper()))
	return name


## What a key already does for good, in the player's words, "" if nothing
## (PIX-201): binding `action` onto it would make one key do two things.
## An action's own alternates are its own (Up for moving up).
const FIXED_NAMES := {"drop": "Drop", "drop_all": "Drop all", "menu": "Menu"}


static func fixed_use(key: int, action := "") -> String:
	if key == KEY_ESCAPE:
		return Text.t("Menu")
	for other: String in ALTERNATES:
		if other != action and key in ALTERNATES[other]:
			return Text.t(String(BINDABLE[other][0]) if BINDABLE.has(other) else String(FIXED_NAMES.get(other, other)))
	if key in SKILL_KEYS:
		return Text.t("skill %d") % (SKILL_KEYS.find(key) + 1)
	return ""


## Text that names keys by action (PIX-194): "{key:interact} to help" reads
## "E to help", or whatever the player bound, so no line names a key the
## player has moved. `bindings` defaults to the player's.
static func say(text: String, bindings: Variant = null) -> String:
	if not "{key:" in text:
		return text
	var bound: Dictionary = bindings if bindings is Dictionary else GameState.settings.bindings
	var out := text
	for found in RegEx.create_from_string("\\{key:([a-z_0-9]+)\\}").search_all(text):
		var action := found.get_string(1)
		if pad and PAD_NAMES.has(action):
			out = out.replace(found.get_string(), PAD_NAMES[action])
		elif BINDABLE.has(action):
			out = out.replace(found.get_string(), key_label(key_for(action, bound)))
		elif action.begins_with("skill_") and int(action.substr(6)) in range(1, SKILL_KEYS.size() + 1):
			out = out.replace(found.get_string(), key_label(SKILL_KEYS[int(action.substr(6)) - 1]))
	return out


## Rebuilds the InputMap from scratch: primaries, alternates, the pad.
static func apply(bindings: Dictionary) -> void:
	var actions := {}
	for action: String in BINDABLE:
		actions[action] = true
	for action: String in ALTERNATES:
		actions[action] = true
	for index in SKILL_KEYS.size():
		actions["skill_%d" % (index + 1)] = true
	for action: String in PAD_BUTTONS:
		actions[action] = true
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
		if PAD_TRIGGERS.has(action):
			var pull := InputEventJoypadMotion.new()
			pull.axis = PAD_TRIGGERS[action]
			pull.axis_value = 1.0
			pull.device = ALL_DEVICES
			InputMap.action_add_event(action, pull)
		if PAD_STICK.has(action):
			var motion := InputEventJoypadMotion.new()
			motion.axis = PAD_STICK[action][0]
			motion.axis_value = PAD_STICK[action][1]
			motion.device = ALL_DEVICES
			InputMap.action_add_event(action, motion)

	# The pad's A and B in Godot's own confirm and back (PIX-215): screens
	# close on ui_cancel, so B goes back everywhere.
	for pair: Array in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B]]:
		var has := InputMap.action_get_events(pair[0]).any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == pair[1])
		if not has:
			var button := InputEventJoypadButton.new()
			button.button_index = pair[1]
			button.device = ALL_DEVICES
			InputMap.action_add_event(pair[0], button)