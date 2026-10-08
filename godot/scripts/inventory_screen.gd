extends CanvasLayer
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
const LIST := Vector2(710, 470)
const ROW_HEIGHT := 50

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
var status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	get_tree().paused = true
	var backdrop := ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# The pack's ledger: a page under the tabs and the list.
	add_child(UiStyle.page(Rect2(474, 58, 742, 572)))
	add_child(UiStyle.heading("Inventory", 20, UiStyle.CREAM, Vector2(80, 24)))
	header = UiStyle.label("", 16, UiStyle.GOLD, Vector2(490, 22))
	add_child(header)

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
	status = UiStyle.label("", 14, UiStyle.LAMP, Vector2(490, 596))
	status.custom_minimum_size = Vector2(710, 0)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	add_child(UiStyle.footer("A/D  tabs      W/S  choose      E  equip / use      X  drop      Z  drop all      I / Esc  close", Vector2(80, 660)))
	_refresh()


func _refresh() -> void:
	var hero := GameState.hero
	var pack := GameState.pack
	var weight := pack.carried_weight()
	var capacity := Skills.carry_capacity(hero, pack)
	header.text = "Weight %d/%d      Gold %d" % [weight, capacity, pack.gold]
	header.add_theme_color_override("font_color", Color(1, 0.45, 0.4) if weight > capacity else UiStyle.CREAM)
	_build_doll()
	for child in tab_row.get_children():
		child.queue_free()
	for index in TABS.size():
		var button := UiStyle.button(TABS[index][1], _switch.bind(index))
		UiStyle.focus(button, index == tab)
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
	if not rows.is_empty():
		scroll.scroll_vertical = clampi(scroll.scroll_vertical, (selected + 1) * (ROW_HEIGHT + 4) - int(LIST.y), selected * (ROW_HEIGHT + 4))


## Gear first, then stacks, each by category then name; the tab filters.
func _rows() -> Array[Dictionary]:
	var category: String = TABS[tab][0]
	if category == "craft":
		return _craft_rows()
	var pack := GameState.pack
	var out: Array[Dictionary] = []
	var gear := pack.gear.duplicate()
	gear.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ca: String = Catalog.item(a["itemId"])["category"]
		var cb: String = Catalog.item(b["itemId"])["category"]
		return ca < cb if ca != cb else InventoryState.gear_name(a) < InventoryState.gear_name(b)
	)
	for piece: Dictionary in gear:
		if category == "all" or Catalog.item(piece["itemId"])["category"] == category:
			out.append({"kind": "gear", "piece": piece, "item_id": piece["itemId"]})
	var stacks: Array = pack.items.keys()
	stacks.sort_custom(func(a: String, b: String) -> bool:
		var ca: String = Catalog.item(a)["category"]
		var cb: String = Catalog.item(b)["category"]
		return ca < cb if ca != cb else Catalog.item_name(a) < Catalog.item_name(b)
	)
	for item_id: String in stacks:
		if category == "all" or Catalog.item(item_id)["category"] == category:
			out.append({"kind": "stack", "item_id": item_id, "count": pack.items[item_id]})
	return out


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
		var where: String = "your workbench" if GameState.world.map_id == "town_house" else STATIONS[here[0]]
		return ["At %s" % where, "E crafts any recipe below you have the makings for."]
	var away := "Hilda forges behind the FORGE door, Vex brews behind BREWS; a bought house can fit a workbench."
	if not _town_gate().is_empty():
		return ["The stations are in town", away + " E travels to the gate."]
	return ["The stations are in town", away]


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
		name = InventoryState.gear_name(piece) + ("   EQUIPPED" if GameState.pack.is_equipped(piece["uid"]) else "")
		stats = stat_line(item, int(piece["bonus"]), Economy.gear_value(piece))
	else:
		name = String(item["name"]) + ("  x%d" % row["count"] if row["count"] > 1 else "")
		stats = stat_line(item, 0, int(item["value"]))
	text.add_child(UiStyle.label(name, 15, _rarity_color(row)))
	var detail := UiStyle.label("%s    %s" % [stats, item.get("description", "")], 12, UiStyle.FADED)
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
		var lines := _guide_lines()
		title = lines[0]
		detail = lines[1]
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
		detail = "%s    %s %d, at %s" % [", ".join(needs), job.capitalize(), entry["job"]["level"], STATIONS[job]]
		ink = UiStyle.INK if Economy.can_craft(entry, pack.items, GameState.hero.jobs) else UiStyle.FADED
	line.add_child(text)
	text.add_child(UiStyle.label(title, 15, ink))
	var small := UiStyle.label(detail, 12, UiStyle.FADED)
	small.clip_text = true
	small.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(small)
	line.add_child(UiStyle.label(_primary_label(row), 13, UiStyle.LAMP if chosen else UiStyle.FADED))
	return panel


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


## An item's numbers on one line (itemStatLine).
static func stat_line(item: Dictionary, bonus: int, value: int) -> String:
	var parts: Array[String] = []
	var plus := "+%d" % bonus if bonus > 0 else ""
	if item.has("damage"):
		var scaling: String = item.get("scaling", "strength")
		parts.append("DMG %d%s %s" % [int(item["damage"]) + bonus, " (%d%s)" % [item["damage"], plus] if plus != "" else "", scaling.substr(0, 3).to_upper()])
	if item.has("armor"):
		parts.append("ARMOR %d%s" % [int(item["armor"]) + bonus, " (%d%s)" % [item["armor"], plus] if plus != "" else ""])
	for stat: String in item.get("grants", {}):
		parts.append("+%d %s" % [item["grants"][stat], stat.substr(0, 3).to_upper()])
	if item.has("restoreHp"):
		parts.append("+%d HP" % item["restoreHp"])
	if item.has("restoreMp"):
		parts.append("+%d MP" % item["restoreMp"])
	if item.has("cures"):
		parts.append("cures %s" % item["cures"])
	parts.append("%d wt" % item["weight"])
	parts.append("%dg" % value)
	return "  ".join(parts)


## What E does to a row: equip or take off gear, use a drinkable or edible,
## place furniture at home.
func _primary_label(row: Dictionary) -> String:
	if row["kind"] == "guide":
		return "E  travel" if not _town_gate().is_empty() else ""
	if row["kind"] == "recipe":
		var entry: Dictionary = row["entry"]
		var here := String(entry["job"]["id"]) in _jobs_here()
		return "E  craft" if here and Economy.can_craft(entry, GameState.pack.items, GameState.hero.jobs) else ""
	if row["kind"] == "gear":
		return "E  take off" if GameState.pack.is_equipped(row["piece"]["uid"]) else "E  equip"
	var item := Catalog.item(row["item_id"])
	if item.has("restoreHp") or item.has("restoreMp") or item.has("cures"):
		return "E  use"
	if item["category"] == "furniture" and GameState.world.map_id == "town_house":
		return "E  place"
	return ""


func _build_doll() -> void:
	for child in doll.get_children():
		child.queue_free()
	var hero := GameState.hero
	var art := PunyArt.hero(hero.role_id, hero.look)
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
	var lines: Array[String] = ["ATK %d" % attack, "DEF %d" % HeroRules.total_defense(hero, pack)]
	for stat: String in ["strength", "intelligence", "dexterity"]:
		var granted := pack.granted_stat(stat)
		lines.append("%s %d%s" % [Skills.ABBR[stat], hero.stats[stat], "  +%d" % granted if granted > 0 else ""])
	lines.append("Carry %d/%d" % [pack.carried_weight(), Skills.carry_capacity(hero, pack)])
	var numbers := UiStyle.label("\n".join(lines), 15, UiStyle.INK, Vector2(24, 340))
	doll.add_child(numbers)


## One slot: the worn piece's icon (click to take it off) or the slot's name.
func _slot(slot: String, label: String) -> Control:
	var instance := GameState.pack.gear_by_uid(GameState.pack.equipped.get(slot, ""))
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(52, 52)
	box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.LAMP if not instance.is_empty() else UiStyle.RIM, 4))
	if instance.is_empty():
		var name := UiStyle.label(label, 10, UiStyle.FADED)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(name)
	else:
		box.add_child(_icon(instance["itemId"]))
		box.tooltip_text = "%s - click to take off" % InventoryState.gear_name(instance)
		box.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				GameState.unequip(slot)
				Sound.play("equip")
				_refresh()
		)
	return box


func _unhandled_input(event: InputEvent) -> void:
	var command := Callable()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu") or event.is_action_pressed("inventory"):
		command = _close
	elif event.is_action_pressed("move_left"):
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
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()


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
			_close()
			world.travel_to(gate)
			world._flash_message("You travel to %s." % gate["name"])
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
			status.text = "%s goes back in the pack." % InventoryState.gear_name(piece)
			Sound.play("equip")
		elif GameState.equip(piece["uid"]):
			status.text = "You put on %s." % InventoryState.gear_name(piece)
			Sound.play("equip")
		else:
			status.text = "That can't be worn."
	else:
		var item_id: String = row["item_id"]
		var item := Catalog.item(item_id)
		if item["category"] == "furniture" and GameState.world.map_id == "town_house" and world != null:
			_close()
			world.place_from_pack(item_id)
			return
		var used := GameState.use_item(item_id)
		if not used["used"]:
			status.text = "Nothing to do with that here."
		else:
			status.text = used["text"]
			if used["cures"] != "" and world != null and world.player.ailments.cure(used["cures"]):
				status.text += " Cured %s." % used["cures"]
	_refresh()


## A recipe crafted where the hero stands, or why it can't be.
func _craft(entry: Dictionary) -> void:
	var job: String = entry["job"]["id"]
	if job not in _jobs_here():
		status.text = Economy.station_hint(job) + "."
		return
	if not Economy.can_craft(entry, GameState.pack.items, GameState.hero.jobs):
		var level := int(entry["job"]["level"])
		status.text = "You need %s %d for that." % [job.capitalize(), level] if GameState.hero.jobs[job]["level"] < level else "You're missing what it takes."
		return
	var made := GameState.craft(entry["id"])
	if made["made"]:
		Sound.play("craft")
		status.text = "You craft %s%s." % [Catalog.item_name(entry["itemId"]), " (two!)" if made["count"] > 1 else ""]


func _drop(whole_stack: bool) -> void:
	if rows.is_empty():
		return
	var row: Dictionary = rows[selected]
	if row["kind"] in ["guide", "recipe"]:
		return
	if row["kind"] == "gear":
		var piece: Dictionary = row["piece"]
		if GameState.drop_gear(piece["uid"]):
			status.text = "You leave %s behind." % InventoryState.gear_name(piece)
		else:
			status.text = "Take it off before you drop it."
	else:
		var count: int = row["count"] if whole_stack else 1
		GameState.drop_item(row["item_id"], count)
		status.text = "You drop %dx %s." % [count, Catalog.item_name(row["item_id"])]
	_refresh()


func _close() -> void:
	get_tree().paused = false
	queue_free()
