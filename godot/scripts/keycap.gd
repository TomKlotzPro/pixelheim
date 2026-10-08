class_name Keycap
extends PanelContainer
## A key the player can press, drawn as one (PIX-193): a raised key in the
## page's parchment - a lit top edge, a darker lip under the face, a dark
## outline with rounded corners - its label on the face. Pressing its key
## dips it for a moment, so a footer answers the hand. UiStyle.keycap builds
## them; everything that names a key (footers, hints, the dock's menu, the
## world's prompt) goes through it.

## How long a press holds the key down.
const DIP_SECONDS := 0.12
## Key names as the OS spells them -> as a cap reads them.
const SHORT := {"Escape": "Esc", "PageUp": "PgUp", "PageDown": "PgDn", "Return": "Enter", "Kp Enter": "Enter"}

## The keys this cap answers to (a cap reads one key).
var keys: Array[String] = []
var label: Label
var small := false
## On the world's pixel grid (UiStyle.world_keycap): its frame is drawn at 1x.
var world := false
var _dipped := 0.0


func _ready() -> void:
	set_process(false)


## The cap's face: `text` as a key name ("E", "Esc", "↑").
func show_key(text: String) -> void:
	label.text = text
	keys.assign([text, _long(text)])


## A pressed key whose name is this cap's dips it.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	var name := OS.get_keycode_string(key.keycode)
	if name in keys or String(SHORT.get(name, "")) in keys:
		dip()


## Down for a moment, then up.
func dip() -> void:
	add_theme_stylebox_override("panel", UiStyle.keycap_style(true, small, 1 if world else UiStyle.UI_SCALE))
	_dipped = DIP_SECONDS
	set_process(true)


func _process(delta: float) -> void:
	_dipped -= delta
	if _dipped <= 0:
		add_theme_stylebox_override("panel", UiStyle.keycap_style(false, small, 1 if world else UiStyle.UI_SCALE))
		set_process(false)


static func _long(text: String) -> String:
	for name: String in SHORT:
		if SHORT[name] == text:
			return name
	return {"↑": "Up", "↓": "Down", "←": "Left", "→": "Right"}.get(text, text)
