extends Screen
## The pack and the paperdoll (Inventory.tsx): the hero dressed in what they
## wear, nine slots around them and the numbers that gear makes; beside it
## everything carried, by category. E equips, takes off, drinks or places;
## X drops one, Z the whole stack. A/D switch tabs, W/S choose, I or Esc
## closes, and every row and slot is clickable. The world holds still.
## The Craft tab is the guide to crafting (the web's craft tab): every recipe
## with its bill of materials and its station, crafted here with E at the
## forge, the cauldron or the home workbench, and away from them a first row
## that says where to go (and travels to the town gate once it's known).

const TABS := [
	["all", "All"], ["weapons", "Weapons"], ["apparel", "Apparel"], ["potions", "Potions"],
	["furniture", "Home"], ["food", "Food"], ["misc", "Misc"], ["craft", "Craft"],
]
## Who keeps each trade's station, for the Craft tab.
const STATIONS := {"smithing": "Hilda's forge", "alchemy": "Vex's cauldron"}
## Slots down the doll's left, then its right.
const DOLL_LEFT := [["head", "Head"], ["neck", "Neck"], ["body", "Body"], ["hands", "Hands"], ["feet", "Feet"]]
const DOLL_RIGHT := [["weapon", "Weapon"], ["offhand", "Off-hand"], ["ring1", "Ring"], ["ring2", "Ring"]]
const LIST := Vector2(710, 412)
const ROW_HEIGHT := 50
## What an empty slot shows, faintly: the kind of thing that goes there.
const GHOSTS := {
	"head": "leather_cap", "neck": "bone_charm", "body": "leather_armor", "hands": "wool_gloves",
	"feet": "worn_boots", "weapon": "rusty_sword", "offhand": "tower_shield", "ring1": "band_of_grit",
	"ring2": "band_of_grit",
}

## The world: for curing live ailments and placing furniture.
var world: Node
var tab := 0
var selected := 0
var rows: Array[Dictionary] = []
var doll: Control
var tab_row: HBoxContainer
var list: VBoxContainer
var scroll: ScrollContainer
var header: Label
var sort_label: Label
var purse: HBoxContainer
## The chosen row in full: an item's description, a recipe's station.
var about: Label
## How full the pack is, beside the weight (red near capacity).
var weight_fill: ColorRect
var status: Label


func _open() -> void:
	closing_actions = [&"inventory"]
	layer = 5
	dim()
	# The pack's ledger: a page under the tabs and the list.
	add_child(UiStyle.page(Rect2(474, 58, 742, 572)))
	add_child(UiStyle.title("Inventory"))
	var weight := HBoxContainer.new()
	weight.position = Vector2(490, 22)
	weight.add_theme_constant_override("separation", 10)
	add_child(weight)
	header = UiStyle.label("", 16, UiStyle.CREAM)
	weight.add_child(header)
	var track := ColorRect.new()
	track.color = UiStyle.NIGHT
	track.custom_minimum_size = Vector2(124, 12)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weight.add_child(track)
	weight_fill = ColorRect.new()
	weight_fill.position = Vector2(2, 2)
	track.add_child(weight_fill)
	sort_label = UiStyle.label("", 16, UiStyle.DUSK, Vector2(740, 22))
	sort_label.custom_minimum_size = Vector2(300, 0)
	sort_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(sort_label)
	# The gold, shown as everywhere else (PIX-213).
	purse = UiStyle.purse(0, 18)
	purse.position = Vector2(1060, 20)
	add_child(purse)

	var doll_card := PanelContainer.new()
	doll_card.position = Vector2(80, 70)
	doll_card.custom_minimum_size = Vector2(380, 560)
	doll_card.add_theme_stylebox_override("panel", UiStyle.window(10))
	add_child(doll_card)
	doll = Control.new()
	doll.position = Vector2(80, 70)
	doll.size = Vector2(380, 560)
	add_child(doll)

	tab_row = HBoxContainer.new()
	tab_row.position = Vector2(490, 72)
	tab_row.add_theme_constant_override("separation", 6)
	add_child(tab_row)
	scroll = ScrollContainer.new()
	scroll.position = Vector2(490, 114)
	scroll.custom_minimum_size = LIST
	scroll.size = LIST
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(LIST.x - 14, 0)
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var rule := ColorRect.new()
	rule.color = UiStyle.RIM
	rule.position = Vector2(490, 530)
	rule.size = Vector2(LIST.x, 2)
	add_child(rule)
	about = UiStyle.label("", 14, UiStyle.FADED, Vector2(490, 536))
	about.custom_minimum_size = Vector2(LIST.x, 0)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(about)
	status = UiStyle.label("", 14, UiStyle.LAMP, Vector2(490, 590))
	status.custom_minimum_size = Vector2(710, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	add_child(UiStyle.screen_footer("{key:move_left}/{key:move_right}  tabs      {key:move_up}/{key:move_down}  choose      {key:interact}  equip / use      X  drop      Z  drop all      R  sort      {key:inventory} / Esc  close"))
	_refresh()


func _refresh() -> void:
	var hero := GameState.hero
	var pack := GameState.pack
	var weight := pack.carried_weight()
	var capacity := Skills.carry_capacity(hero, pack)
	header.text = Text.t("Weight %d/%d") % [weight, capacity]
	header.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if weight > capacity else UiStyle.CREAM)
	var share := clampf(float(weight) / maxi(1, capacity), 0.0, 1.0)
	weight_fill.size = Vector2(120 * share, 8)
	weight_fill.color = UiStyle.LAMP if share >= 0.9 else UiStyle.GOLD
	sort_label.text = Text.t("Sorted by %s") % sort_name(GameState.settings.pack_sort)
	UiStyle.purse_set(purse, pack.gold)
	_build_doll()
	for child in tab_row.get_children():
		child.queue_free()
	for index in TABS.size():
		var button := UiStyle.button(TABS[index][1], _switch.bind(index))
		UiStyle.focus(button, index == tab)
		var count := _tab_count(TABS[index][0])
		if count > 0 and index > 0:
			button.add_child(_count_badge(count))
		elif count == 0:
			button.modulate.a = 0.55
		tab_row.add_child(button)
	rows = _rows()
	selected = clampi(selected, 0, maxi(0, rows.size() - 1))
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		list.add_child(UiStyle.label("Nothing here. Go hit some monsters.", 15, UiStyle.FADED))
	for index in rows.size():
		list.add_child(_row(index))
	about.text = _about(rows[selected]) if not rows.is_empty() else ""
	if not rows.is_empty():
		scroll.scroll_vertical = clampi(scroll.scroll_vertical, (selected + 1) * (ROW_HEIGHT + 4) - int(LIST.y), selected * (ROW_HEIGHT + 4))


## Gear first, then stacks, each by category then name; the tab filters.
func _rows() -> Array[Dictionary]:
	var category: String = TABS[tab][0]
	if category == "craft":
		return _craft_rows()
	return GameState.pack.listing(category, GameState.settings.pack_sort)


## The Craft tab: where to craft, then every recipe by trade and level.
func _craft_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = [{"kind": "guide", "item_id": ""}]
	var entries := Economy.recipes().duplicate()
	var here := _jobs_here()
	# What can be made here first, then each trade by level and name.
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_here: bool = a["job"]["id"] in here
		if a_here != (b["job"]["id"] in here):
			return a_here
		if a["job"]["id"] != b["job"]["id"]:
			return a["job"]["id"] < b["job"]["id"]
		return int(a["job"]["level"]) < int(b["job"]["level"]) or (
			a["job"]["level"] == b["job"]["level"] and Catalog.item_name(a["itemId"]) < Catalog.item_name(b["itemId"])
		)
	)
	for entry: Dictionary in entries:
		out.append({"kind": "recipe", "item_id": entry["itemId"], "entry": entry})
	return out


## The trades that craft where the hero stands.
func _jobs_here() -> Array[String]:
	return Economy.jobs_here(GameState.world.map_id, GameState.settlement.house.get("workbench", false))


## The town gate, when it's known and the hero is away from town: where the
## guide row travels.
func _town_gate() -> Dictionary:
	if GameState.world.map_id.begins_with("town"):
		return {}
	for waypoint: Dictionary in Interactables.waypoints():
		if waypoint["id"] == "town_gate" and Interactables.waypoint_usable(waypoint, GameState.world.discovered, GameState.settlement.settlers):
			return waypoint
	return {}


## The guide: at a station it says so; away from them it says where they are.
func _guide_lines() -> Array[String]:
	var here := _jobs_here()
	if not here.is_empty():
		var where: String = Text.t("your workbench") if GameState.world.map_id == "town_house" else Text.mid(Text.t(STATIONS[here[0]]))
		return [Text.t("At %s") % where, Text.t("E crafts any recipe below you have the makings for.")]
	var away := Text.t("Hilda forges behind the FORGE door, Vex brews behind BREWS; a bought house can fit a workbench.")
	if not _town_gate().is_empty():
		return [Text.t("The stations are in town"), away + Text.t(" E travels to the gate.")]
	return [Text.t("The stations are in town"), away]


func _row(index: int) -> Control:
	var row: Dictionary = rows[index]
	if row["kind"] in ["guide", "recipe"]:
		return _craft_row(index)
	var item := Catalog.item(row["item_id"])
	var chosen := index == selected
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(LIST.x - 14, ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 6
	))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and index == selected:
				_primary()
			else:
				_select(index)
	)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	line.add_child(_icon(row["item_id"]))
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var name := ""
	var stats := ""
	if row["kind"] == "gear":
		var piece: Dictionary = row["piece"]
		name = InventoryState.gear_name(piece) + ("   " + Text.t("EQUIPPED") if GameState.pack.is_equipped(piece["uid"]) else "")
		# The forge's and the deep's bonus, the affixes and what was quenched (PIX-218).
		stats = stat_line(item, int(piece["bonus"]) + int(piece.get("deepBonus", 0)), Economy.gear_value(piece), InventoryState.shown_affixes(piece))
	else:
		name = String(item["name"]) + ("  x%d" % row["count"] if row["count"] > 1 else "")
		stats = stat_line(item, 0, int(item["value"]))
	text.add_child(UiStyle.strong(name, 15, _rarity_color(row)))
	var detail := UiStyle.label(stats, 12, UiStyle.FADED)
	detail.clip_text = true
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(detail)
	line.add_child(UiStyle.label(_primary_label(row), 13, UiStyle.LAMP if chosen else UiStyle.FADED))
	return panel


## A Craft tab row: the guide, or a recipe with its materials (each with
## how many are carried), its trade and level, and where it's made.
func _craft_row(index: int) -> Control:
	var row: Dictionary = rows[index]
	var chosen := index == selected
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(LIST.x - 14, ROW_HEIGHT)
	panel.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 6
	))
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and index == selected:
				_primary()
			else:
				_select(index)
	)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := ""
	var detail := ""
	var ink := UiStyle.INK
	if row["kind"] == "guide":
		title = _guide_lines()[0]
		# The trades' standing, always in view (PIX-143).
		detail = "%s    %s" % [Economy.job_line(GameState.hero.jobs, "smithing"), Economy.job_line(GameState.hero.jobs, "alchemy")]
		ink = UiStyle.LAMP
	else:
		var entry: Dictionary = row["entry"]
		line.add_child(_icon(row["item_id"]))
		var pack := GameState.pack
		var needs: Array[String] = []
		for need: String in entry["needs"]:
			needs.append("%s %d/%d" % [Catalog.item_name(need), mini(pack.items.get(need, 0), entry["needs"][need]), entry["needs"][need]])
		var job: String = entry["job"]["id"]
		title = Catalog.item_name(row["item_id"])
		detail = ", ".join(needs)
		ink = UiStyle.INK if Economy.can_craft(entry, pack.items, GameState.hero.jobs) else UiStyle.FADED
	line.add_child(text)
	text.add_child(UiStyle.strong(title, 15, ink))
	var small := UiStyle.label(detail, 12, UiStyle.FADED)
	small.clip_text = true
	small.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(small)
	line.add_child(UiStyle.label(_primary_label(row), 13, UiStyle.LAMP if chosen else UiStyle.FADED))
	return panel


## What a tab holds: rows of the pack, or for Craft what can be made now.
func _tab_count(category: String) -> int:
	if category == "craft":
		return Economy.recipes().filter(func(entry: Dictionary) -> bool:
			return Economy.can_craft(entry, GameState.pack.items, GameState.hero.jobs)
		).size()
	return GameState.pack.listing(category).size()


## A tab's count in a little dark tag above its top right corner, outside
## the tab's own layout.
func _count_badge(count: int) -> Control:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.NIGHT, UiStyle.NIGHT, 2))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UiStyle.label(str(count), 12, UiStyle.CREAM))
	# Standing on the tab's top edge at its right end, clear of its name.
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = 4
	badge.offset_right = 4
	badge.offset_top = 4
	badge.offset_bottom = 4
	badge.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	badge.grow_vertical = Control.GROW_DIRECTION_BEGIN
	return badge


## A sort's name for the "Sorted by" line: the SORTS are ids.
static func sort_name(sort: String) -> String:
	match sort:
		"kind":
			return Text.t("kind")
		"value":
			return Text.t("value")
		"weight":
			return Text.t("weight")
		"name":
			return Text.t("name")
	return sort


## On a phone, the tap bar's own buttons (PIX-214): X, Z and R by touch.
func _tap_actions() -> Array[Dictionary]:
	return [
		{"label": "Drop", "call": _drop.bind(false)},
		{"label": "Drop all", "call": _drop.bind(true)},
		{"label": "Sort", "call": _sort},
	]


## R: the next order (InventoryState.SORTS), remembered between sessions.
func _sort() -> void:
	var sorts := InventoryState.SORTS
	var settings := GameState.settings
	settings.pack_sort = sorts[(sorts.find(settings.pack_sort) + 1) % sorts.size()]
	settings.save_file()
	selected = 0
	_refresh()


## The chosen row in full, under the list: what an item is, where a recipe
## is made and what it makes, or the craft guide's whole advice.
func _about(row: Dictionary) -> String:
	match String(row["kind"]):
		"guide":
			return _guide_lines()[1]
		"recipe":
			var entry: Dictionary = row["entry"]
			var job: String = entry["job"]["id"]
			var about := Text.t("%s %d, at %s.") % [Economy.job_name(job), entry["job"]["level"], Text.mid(Text.t(STATIONS[job]))]
			if int(GameState.hero.jobs[job]["level"]) < int(entry["job"]["level"]):
				about += Text.t(" You are %s.") % Economy.job_line(GameState.hero.jobs, job)
			# What's missing and where it comes from (PIX-143), else what it is.
			var missing: Array[String] = []
			for need: String in entry["needs"]:
				if GameState.pack.items.get(need, 0) < entry["needs"][need]:
					# The nearest lead true now (PIX-184), or at least its name.
					var lead := Economy.where_to_find(need, GameState.town_tier(), GameState.stock_stage())
					missing.append(lead if lead != "" else Catalog.item_name(need))
			if missing.is_empty():
				return about + " " + String(Catalog.item(row["item_id"]).get("description", ""))
			return about + " " + "; ".join(missing) + "."
	var item := Catalog.item(row["item_id"])
	if item.has("set"):
		return "%s %s." % [item.get("description", ""), Catalog.set_line(item["set"], int(GameState.pack.set_counts().get(item["set"], 0)))]
	return String(item.get("description", ""))


## Fine and epic pieces wear their rarity in the name's colour.
func _rarity_color(row: Dictionary) -> Color:
	if row["kind"] != "gear":
		return UiStyle.INK
	match String(row["piece"]["rarity"]):
		"fine":
			return UiStyle.FINE
		"epic":
			return UiStyle.EPIC
	return UiStyle.INK


## An item's icon (Shade's, ItemIcons), twice life size.
static func _icon(item_id: String) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = ItemIcons.texture(item_id)
	icon.custom_minimum_size = Vector2(32, 32)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


## An item's numbers on one line (itemStatLine), a piece's affixes with
## them (PIX-191).
static func stat_line(item: Dictionary, bonus: int, value: int, affixes := {}) -> String:
	var parts: Array[String] = []
	var plus := "+%d" % bonus if bonus > 0 else ""
	if item.has("damage"):
		var scaling: String = item.get("scaling", "strength")
		parts.append(Text.t("DMG %d%s %s") % [int(item["damage"]) + bonus, " (%d%s)" % [item["damage"], plus] if plus != "" else "", Text.t(scaling.substr(0, 3).to_upper())])
	if item.has("armor"):
		parts.append(Text.t("ARMOR %d%s") % [int(item["armor"]) + bonus, " (%d%s)" % [item["armor"], plus] if plus != "" else ""])
	for stat: String in item.get("grants", {}):
		parts.append("+%d %s" % [item["grants"][stat], Text.t(stat.substr(0, 3).to_upper())])
	for stat: String in affixes:
		parts.append("+%d %s" % [int(affixes[stat]), Text.t(stat.substr(0, 3).to_upper())])
	if item.has("restoreHp"):
		parts.append(Text.t("+%d HP") % GameState.hp_restore(item))
	if item.has("restoreMp"):
		parts.append(Text.t("+%d MP") % item["restoreMp"])
	if item.has("cures"):
		parts.append(Text.t("cures %s") % Ailments.label(item["cures"]))
	parts.append(Text.t("%d wt") % item["weight"])
	parts.append(Text.coins(value))
	return "  ".join(parts)


## What E does to a row: equip or take off gear, use a drinkable or edible,
## place furniture at home.
func _primary_label(row: Dictionary) -> String:
	if row["kind"] == "guide":
		return UiStyle.keyed("{key:interact}", Text.t("travel")) if not _town_gate().is_empty() else ""
	if row["kind"] == "recipe":
		var entry: Dictionary = row["entry"]
		var here := String(entry["job"]["id"]) in _jobs_here()
		return UiStyle.keyed("{key:interact}", Text.t("craft")) if here and Economy.can_craft(entry, GameState.pack.items, GameState.hero.jobs) else ""
	if row["kind"] == "gear":
		return UiStyle.keyed("{key:interact}", Text.t("take off")) if GameState.pack.is_equipped(row["piece"]["uid"]) else UiStyle.keyed("{key:interact}", Text.t("equip"))
	var item := Catalog.item(row["item_id"])
	if item.has("restoreHp") or item.has("restoreMp") or item.has("cures"):
		return UiStyle.keyed("{key:interact}", Text.t("use"))
	if item["category"] == "furniture" and GameState.world.map_id == "town_house":
		return UiStyle.keyed("{key:interact}", Text.t("place"))
	return ""


func _build_doll() -> void:
	for child in doll.get_children():
		child.queue_free()
	var hero := GameState.hero
	var art := GameState.hero_art()
	var figure := AnimatedSprite2D.new()
	figure.sprite_frames = PunyArt.frames(art)
	figure.self_modulate = art["tint"]
	figure.scale = Vector2(5, 5)
	figure.position = Vector2(190, 170)
	figure.play(PunyArt.pick(figure.sprite_frames, "idle", "down"))
	doll.add_child(figure)
	for column in [[DOLL_LEFT, 24.0], [DOLL_RIGHT, 304.0]]:
		var y := 24.0
		for slot: Array in column[0]:
			var box := _slot(slot[0], slot[1])
			box.position = Vector2(column[1], y)
			doll.add_child(box)
			y += 62.0
	var pack := GameState.pack
	var weapon := HeroRules.weapon(pack)
	var scaling: String = Catalog.item(weapon["itemId"]).get("scaling", "strength") if not weapon.is_empty() else "strength"
	var attack := HeroRules.effective_stat(hero, pack, scaling) + (HeroRules.gear_damage(weapon) if not weapon.is_empty() else 2)
	var lines: Array[String] = [Text.t("ATK %d") % attack, Text.t("DEF %d") % HeroRules.total_defense(hero, pack)]
	for stat: String in ["strength", "intelligence", "dexterity"]:
		var granted := pack.granted_stat(stat)
		lines.append("%s %d%s" % [Text.t(Skills.ABBR[stat]), hero.stats[stat], "  +%d" % granted if granted > 0 else ""])
	lines.append(Text.t("Carry %d/%d") % [pack.carried_weight(), Skills.carry_capacity(hero, pack)])
	var numbers := UiStyle.label("\n".join(lines), 15, UiStyle.INK, Vector2(24, 340))
	doll.add_child(numbers)


## One slot: the worn piece's icon (click to take it off), or a faint one of
## what goes there, its name on hover.
func _slot(slot: String, label: String) -> Control:
	var instance := GameState.pack.gear_by_uid(GameState.pack.equipped.get(slot, ""))
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(52, 52)
	box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP if not instance.is_empty() else UiStyle.RIM, 4))
	if instance.is_empty():
		var ghost := _icon(GHOSTS[slot])
		ghost.modulate = Color(UiStyle.INK, 0.28)
		box.add_child(ghost)
		box.tooltip_text = Text.t(label)
	else:
		box.add_child(_icon(instance["itemId"]))
		box.tooltip_text = Text.t("%s - click to take off") % InventoryState.gear_name(instance)
		box.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameState.unequip(slot)
				Sound.play("equip")
				_refresh()
		)
	return box


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_left"):
		command = _switch.bind(tab - 1)
	elif event.is_action_pressed("move_right"):
		command = _switch.bind(tab + 1)
	elif event.is_action_pressed("move_up"):
		command = _select.bind(selected - 1)
	elif event.is_action_pressed("move_down"):
		command = _select.bind(selected + 1)
	elif event.is_action_pressed("interact"):
		command = _primary
	elif event.is_action_pressed("drop"):
		command = _drop.bind(false)
	elif event.is_action_pressed("drop_all"):
		command = _drop.bind(true)
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		command = _sort
	return command


func _switch(index: int) -> void:
	tab = wrapi(index, 0, TABS.size())
	selected = 0
	status.text = ""
	_refresh()


func _select(index: int) -> void:
	if rows.is_empty():
		return
	selected = wrapi(index, 0, rows.size())
	_refresh()


func _primary() -> void:
	if rows.is_empty():
		return
	var row: Dictionary = rows[selected]
	if row["kind"] == "guide":
		var gate := _town_gate()
		if not gate.is_empty() and world != null:
			close()
			world.travel_to(gate)
			world._flash_message(Text.t("You travel to %s.") % gate["name"])
		return
	if row["kind"] == "recipe":
		_craft(row["entry"])
		_refresh()
		return
	if row["kind"] == "gear":
		var piece: Dictionary = row["piece"]
		if GameState.pack.is_equipped(piece["uid"]):
			for slot: String in GameState.pack.equipped:
				if GameState.pack.equipped[slot] == piece["uid"]:
					GameState.unequip(slot)
					break
			status.text = Text.t("%s goes back in the pack.") % InventoryState.gear_name(piece)
			Sound.play("equip")
		elif GameState.equip(piece["uid"]):
			status.text = Text.t("You put on %s.") % InventoryState.gear_name(piece)
			Sound.play("equip")
		else:
			status.text = "That can't be worn."
	else:
		var item_id: String = row["item_id"]
		var item := Catalog.item(item_id)
		if item["category"] == "furniture" and GameState.world.map_id == "town_house" and world != null:
			close()
			world.place_from_pack(item_id)
			return
		var used := GameState.use_item(item_id)
		if not used["used"]:
			status.text = "Nothing to do with that here."
		else:
			status.text = used["text"]
			if used["cures"] != "" and world != null and world.player.ailments.cure(used["cures"]):
				status.text += Text.t(" Cured %s.") % Ailments.label(used["cures"])
	_refresh()


## A recipe crafted where the hero stands, or why it can't be.
func _craft(entry: Dictionary) -> void:
	var job: String = entry["job"]["id"]
	if job not in _jobs_here():
		status.text = Economy.station_hint(job, Town.done_projects(GameState.settlement)) + "."
		return
	if not Economy.can_craft(entry, GameState.pack.items, GameState.hero.jobs):
		var level := int(entry["job"]["level"])
		status.text = Text.t("You need %s %d for that.") % [Economy.job_name(job), level] if GameState.hero.jobs[job]["level"] < level else Text.t("Still missing: %s.") % ", ".join(Economy.missing_names(entry, GameState.pack.items))
		return
	# Not with what a taken delivery needs, unless asked twice (PIX-206).
	var ask := GameState.ask_before_dip("craft:" + String(entry["id"]), entry["needs"])
	if ask != "":
		status.text = ask
		return
	var made := GameState.craft(entry["id"])
	if made["made"]:
		Sound.play("craft")
		status.text = Text.t("You craft %s%s. %s") % [Catalog.item_name(entry["itemId"]), Text.t(" (two!)") if made["count"] > 1 else "", made["level_line"]]


## A drop that can't be undone - a piece of gear, a whole stack - waits for
## the same key again (PIX-201: on another keyboard the key under a finger
## may not be the one it seems).
var _drop_armed := ""
var _drop_armed_at := -10.0
const DROP_CONFIRM_SECONDS := 3.0


func _drop(whole_stack: bool) -> void:
	if rows.is_empty():
		return
	var row: Dictionary = rows[selected]
	if row["kind"] in ["guide", "recipe"]:
		return
	var lasting: bool = row["kind"] == "gear" or (whole_stack and int(row.get("count", 1)) > 1)
	if lasting and not Catalog.item(row.get("item_id", "")).get("quest", false):
		var which := "%s|%s|%s" % [row["kind"], row.get("item_id", ""), String(row.get("piece", {}).get("uid", ""))]
		var now := Time.get_ticks_msec() / 1000.0
		if _drop_armed != which or now - _drop_armed_at > DROP_CONFIRM_SECONDS:
			_drop_armed = which
			_drop_armed_at = now
			var what: String = InventoryState.gear_name(row["piece"]) if row["kind"] == "gear" else Text.t("%dx %s") % [row["count"], Catalog.item_name(row["item_id"])]
			status.text = Text.t("Drop %s for good? Press %s again.") % [what, Controls.shown("Z" if whole_stack else "X")]
			return
		_drop_armed = ""
	if row["kind"] == "gear":
		var piece: Dictionary = row["piece"]
		if GameState.drop_gear(piece["uid"]):
			status.text = Text.t("You leave %s behind.") % InventoryState.gear_name(piece)
		else:
			status.text = "Take it off before you drop it."
	elif Catalog.item(row["item_id"]).get("quest", false):
		status.text = "You'd better hold on to that."
	else:
		var count: int = row["count"] if whole_stack else 1
		GameState.drop_item(row["item_id"], count)
		status.text = Text.t("You drop %dx %s.") % [count, Catalog.item_name(row["item_id"])]
	_refresh()
