extends HBoxContainer
## The hero's skills along the bottom of the screen, by their number keys
## (as keycaps): each with its cost, gold when it can be cast, dimmed while it
## can't (too dear, the level not reached, or the last cast still in hand).
## Click a slot to cast it too.

var world: Node
var _shown: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	position = Vector2(0, 672)
	custom_minimum_size = Vector2(1280, 0)
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	var hero := GameState.hero
	var skills := Skills.hero_skills(hero).slice(0, Controls.SKILL_KEYS.size())
	var states := skills.map(func(skill: Dictionary) -> bool:
		return Skills.cast_block(hero, skill) == "" and world.player.skill_ready
	)
	var shown := [skills.map(func(skill: Dictionary) -> String: return skill["name"]), states]
	if shown == _shown:
		return
	_shown = shown
	for child in get_children():
		child.queue_free()
	var resource := Skills.resource_label(hero.role_id)
	for index in skills.size():
		var skill: Dictionary = skills[index]
		var ready: bool = states[index]
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(172, 0)
		slot.add_theme_stylebox_override("panel", UiStyle.box(
			Color(UiStyle.WINDOW, 0.92), UiStyle.LAMP if ready else UiStyle.RIM, 6
		))
		slot.modulate.a = 1.0 if ready else 0.6
		slot.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				world.player.cast(index)
		)
		var line := HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override("separation", 6)
		slot.add_child(line)
		line.add_child(UiStyle.keycap(str(index + 1), true))
		var name := UiStyle.label(skill["name"], 12, UiStyle.LAMP if ready else UiStyle.INK)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name.clip_text = true
		name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.add_child(name)
		var cost := "%d %s" % [skill["mpCost"], resource]
		if int(skill.get("hpCost", 0)) > 0:
			cost += " +%d HP" % skill["hpCost"]
		line.add_child(UiStyle.label(cost, 12, UiStyle.FADED))
		add_child(slot)
