extends Screen
## The codex (Codex.tsx): the trophy case. Masteries shows each monster
## family's kills, the Slayer tier earned and what the next teaches; the
## Bestiary shows every monster whose family the hero has met, and keeps the
## rest secret. A/D switch tabs, B or Esc closes. The world holds still.

const TABS := ["Masteries", "Bestiary"]

var tab := 0
var body: VBoxContainer
var tabs_row: HBoxContainer


func _open() -> void:
	closing_actions = [&"codex"]
	layer = 5
	dim()
	add_child(UiStyle.heading("Codex", 20, UiStyle.CREAM, Vector2(80, 24)))
	tabs_row = HBoxContainer.new()
	tabs_row.position = Vector2(80, 64)
	tabs_row.add_theme_constant_override("separation", 10)
	add_child(tabs_row)
	var card := PanelContainer.new()
	card.position = Vector2(80, 104)
	card.custom_minimum_size = Vector2(1120, 540)
	card.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 14))
	add_child(card)
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	card.add_child(body)
	add_child(UiStyle.label("Every kill teaches. Families over faces.", 13, UiStyle.DUSK, Vector2(80, 660)))
	add_child(UiStyle.footer("A/D  tabs      B / Esc  close", Vector2(1000, 660)))
	_show()


func _show() -> void:
	for child in tabs_row.get_children() + body.get_children():
		child.queue_free()
	for index in TABS.size():
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UiStyle.plank(index == tab, 6))
		chip.add_child(UiStyle.label(TABS[index], 16, UiStyle.GOLD if index == tab else UiStyle.CREAM))
		tabs_row.add_child(chip)
	if tab == 0:
		_masteries()
	else:
		_bestiary()


## Each family: kills, the tier earned, a bar toward the next and its bonus.
func _masteries() -> void:
	var data := Bestiary._data()
	var tiers: Array = data["masteryTiers"]
	var mastery: Variant = GameState.hero.mastery
	for family: String in data["familyNames"]:
		var kills: int = (mastery as Dictionary).get(family, 0) if mastery is Dictionary else 0
		var tier := Bestiary.mastery_tier(mastery, family)
		var next: Dictionary = tiers[tier] if tier < tiers.size() else {}
		var line := HBoxContainer.new()
		var name := UiStyle.label(
			"%s%s" % [data["familyNames"][family], "   Slayer %s" % ["I", "II", "III"][tier - 1] if tier > 0 else ""],
			16, UiStyle.LAMP if tier > 0 else UiStyle.INK
		)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(name)
		line.add_child(UiStyle.label("%d slain" % kills, 15, UiStyle.FADED))
		body.add_child(line)
		var track := ColorRect.new()
		track.color = UiStyle.RIM
		track.custom_minimum_size = Vector2(1090, 5)
		var fill := ColorRect.new()
		fill.color = UiStyle.LAMP
		var share := 1.0 if next.is_empty() else minf(1.0, float(kills) / int(next["kills"]))
		fill.size = Vector2(1090.0 * share, 5)
		track.add_child(fill)
		body.add_child(track)
		var note := ""
		if tier > 0:
			note = "+%d%% damage against them. " % roundi(float(tiers[tier - 1]["bonus"]) * 100)
		note += "Nothing left to teach you." if next.is_empty() else "%d more for +%d%%." % [
			int(next["kills"]) - kills, roundi(float(next["bonus"]) * 100),
		]
		body.add_child(UiStyle.label(note, 13, UiStyle.FADED))


## Every monster, in the bestiary's order: the met ones in full.
func _bestiary() -> void:
	var data := Bestiary._data()
	var mastery: Variant = GameState.hero.mastery
	for monster_id: String in data["monsters"]:
		var monster: Dictionary = data["monsters"][monster_id]
		var family: String = data["families"].get(monster_id, "")
		var met: bool = family != "" and mastery is Dictionary and int((mastery as Dictionary).get(family, 0)) > 0
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		line.custom_minimum_size = Vector2(0, 28)
		line.add_child(_portrait(monster_id, met))
		if met:
			var name := UiStyle.label(monster["name"], 15, UiStyle.INK)
			name.custom_minimum_size = Vector2(220, 0)
			line.add_child(name)
			var numbers := UiStyle.label(
				"HP %d  ATK %d  DEF %d  %d xp" % [monster["maxHp"], monster["attack"], monster["defense"], monster["xp"]],
				14, UiStyle.INK
			)
			numbers.custom_minimum_size = Vector2(360, 0)
			line.add_child(numbers)
			line.add_child(UiStyle.label(data["familyNames"][family], 14, UiStyle.FADED))
		else:
			line.add_child(UiStyle.label("Unmet. The wilds keep their secrets.", 14, UiStyle.FADED))
		body.add_child(line)


## The monster's first idle frame, or its silhouette while unmet.
func _portrait(monster_id: String, met: bool) -> Control:
	var spec := PunyArt.monster(monster_id)
	var frames := PunyArt.frames(spec)
	var icon := TextureRect.new()
	icon.texture = frames.get_frame_texture(PunyArt.pick(frames, "idle", "down"), 0)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.modulate = Color(spec.get("tint", Color.WHITE)) if met else Color(0, 0, 0, 0.8)
	return icon


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_left") or event.is_action_pressed("move_right"):
		command = func() -> void:
			tab = 1 - tab
			_show()
	return command
