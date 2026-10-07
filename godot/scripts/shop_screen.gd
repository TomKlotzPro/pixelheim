extends CanvasLayer
## A keeper's counter (talk to anyone in a shop): Buy, Sell, the Forge at the
## smithy, and Craft at the forge and the cauldron. Crafting lives in the web
## game's pack screen; until the UI suite brings that screen (PIX-127) the
## stations offer it here. A/D switch tabs, W/S choose, E acts, Esc closes;
## everything is clickable too. Pauses the world while open.

const LIST_SIZE := Vector2(700, 400)

var shop_id := ""
var tabs: Array[String] = []
var tab := 0
var selected := 0
var rows: Array[Dictionary] = []
var tab_buttons: Array[Button] = []
var list: VBoxContainer
var scroll: ScrollContainer
var detail: Label
var act_button: Button
var gold_label: Label
var status: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	get_tree().paused = true
	shop_id = GameState.active_shop()
	var shop := Economy.shop(shop_id)
	tabs = ["Buy", "Sell"]
	if shop.get("forge", false):
		tabs.append("Forge")
	if _craft_job() != "":
		tabs.append("Craft")

	var backdrop := ColorRect.new()
	backdrop.color = UiStyle.BACKDROP
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	# The counter's ledger: a page under the tabs, the wares and the news.
	add_child(UiStyle.page(Rect2(60, 90, 740, 530)))
	add_child(UiStyle.heading(shop["keeper"], 18, UiStyle.CREAM, Vector2(80, 32)))
	add_child(UiStyle.label(shop["greeting"], 14, UiStyle.DUSK, Vector2(80, 66)))
	gold_label = UiStyle.label("", 18, UiStyle.GOLD, Vector2(1060, 36))
	add_child(gold_label)

	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(80, 100)
	tab_row.add_theme_constant_override("separation", 10)
	for index in tabs.size():
		var button := UiStyle.button(tabs[index], _switch.bind(index))
		tab_buttons.append(button)
		tab_row.add_child(button)
	add_child(tab_row)

	scroll = ScrollContainer.new()
	scroll.position = Vector2(80, 150)
	scroll.custom_minimum_size = LIST_SIZE
	scroll.size = LIST_SIZE
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	list = VBoxContainer.new()
	list.custom_minimum_size = Vector2(LIST_SIZE.x - 16, 0)
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)

	var side := PanelContainer.new()
	side.position = Vector2(820, 150)
	side.custom_minimum_size = Vector2(380, LIST_SIZE.y)
	side.add_theme_stylebox_override("panel", UiStyle.window(18))
	add_child(side)
	var side_box := VBoxContainer.new()
	side_box.add_theme_constant_override("separation", 14)
	side.add_child(side_box)
	detail = UiStyle.label("", 14, UiStyle.INK)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(340, 0)
	side_box.add_child(detail)
	act_button = UiStyle.button("", _act)
	act_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	side_box.add_child(act_button)

	status = UiStyle.label("", 14, UiStyle.LAMP, Vector2(80, 580))
	add_child(status)
	add_child(UiStyle.footer("Esc  close      A/D  tab      W/S  choose      E  %s" % "/".join(tabs).to_lower(), Vector2(80, 660)))
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var command := Callable()
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
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
		command = _act
	if command.is_valid():
		get_viewport().set_input_as_handled()
		command.call()


func _switch(index: int) -> void:
	tab = wrapi(index, 0, tabs.size())
	selected = 0
	status.text = ""
	_refresh()


func _select(index: int) -> void:
	if rows.is_empty():
		return
	selected = clampi(index, 0, rows.size() - 1)
	_refresh()


## The trade this station crafts, if any (the smithy forges, Vex brews).
func _craft_job() -> String:
	for job: String in ["smithing", "alchemy"]:
		if Economy.at_job_station(job, GameState.world.map_id, false):
			return job
	return ""


## Rows for the current tab: {label, price, detail, action, enabled}.
func _build_rows() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pack := GameState.pack
	match tabs[tab]:
		"Buy":
			# The business itself is for sale too (BUY_PROPERTY): rent after every victory.
			var map_id := GameState.world.map_id
			var deed: Dictionary = Town.deeds().get(map_id, {})
			if not deed.is_empty():
				var owned := map_id in GameState.settlement.properties
				out.append({
					"label": "Deed: %s" % deed["name"], "price": "owned" if owned else "%dg" % deed["cost"],
					"detail": "%s\nOwn this business: it pays you %dg rent after every victory." % [deed["name"], Town.rent_per_property(GameState.town_tier())],
					"verb": "Buy the deed", "enabled": not owned and pack.gold >= int(deed["cost"]),
					"action": func() -> void: _after(GameState.buy_property(map_id), "The deed is yours.", "Not enough gold."),
				})
			# Odo also sells the bigger house deeds (BUY_HOUSE_UPGRADE).
			var bigger := Town.next_house_tier(GameState.owns_house(), int(GameState.settlement.house.get("tier", 1)))
			if shop_id == "odo" and not bigger.is_empty():
				out.append({
					"label": "Deed: %s" % bigger["name"], "price": "%dg" % bigger["cost"],
					"detail": "%s\nA bigger house: its new rooms wait the next time you walk in." % bigger["name"],
					"verb": "Sign the deed", "enabled": pack.gold >= int(bigger["cost"]),
					"action": func() -> void:
						var text := GameState.buy_house_upgrade()
						status.text = text if text != "" else "Not enough gold.",
				})
			for item_id in Economy.shop_stock(shop_id, GameState.progression.unlocked_level):
				var price := Economy.buy_price(item_id)
				out.append({
					"label": Catalog.item_name(item_id), "price": "%dg" % price,
					"detail": _describe(item_id), "verb": "Buy", "enabled": pack.gold >= price,
					"action": func() -> void: _after(GameState.buy_item(item_id), "Bought %s." % Catalog.item_name(item_id), "Not enough gold."),
				})
		"Sell":
			for item_id: String in pack.items:
				var each := floori(Economy.sell_price_at(shop_id, item_id, GameState.town_tier()) * GameState.trophy_sell_multiplier())
				out.append({
					"label": "%s  x%d" % [Catalog.item_name(item_id), pack.items[item_id]], "price": "%dg" % each,
					"detail": _describe(item_id), "verb": "Sell one", "enabled": true,
					"action": func() -> void: _sold(GameState.sell_item(item_id)),
				})
			for instance in pack.gear:
				if pack.is_equipped(instance["uid"]):
					continue
				var uid: String = instance["uid"]
				var price := floori(Economy.gear_sell_price_at(shop_id, instance, GameState.town_tier()) * GameState.trophy_sell_multiplier())
				out.append({
					"label": _gear_label(instance), "price": "%dg" % price,
					"detail": _describe(instance["itemId"], instance), "verb": "Sell", "enabled": true,
					"action": func() -> void: _sold(GameState.sell_gear(uid)),
				})
		"Forge":
			var smithing: int = GameState.hero.jobs["smithing"]["level"]
			for instance in pack.gear:
				var uid: String = instance["uid"]
				var maxed: bool = instance["bonus"] >= Economy.forge_cap_for(smithing)
				var cost := Economy.forge_cost_for(instance["itemId"], instance["bonus"], smithing)
				out.append({
					"label": _gear_label(instance) + ("  (worn)" if pack.is_equipped(uid) else ""),
					"price": "max" if maxed else "%dg" % cost,
					"detail": _describe(instance["itemId"], instance), "verb": "Temper +1",
					"enabled": not maxed and pack.gold >= cost,
					"action": func() -> void: _after(GameState.upgrade_gear(uid), "Hilda tempers it: +1.", "Not enough gold, or it can take no more."),
				})
		"Craft":
			for entry: Dictionary in Economy.recipes():
				if entry["job"]["id"] != _craft_job():
					continue
				var recipe_id: String = entry["id"]
				out.append({
					"label": Catalog.item_name(entry["itemId"]),
					"price": "%s %d" % [String(entry["job"]["id"]).capitalize(), entry["job"]["level"]],
					"detail": _describe_recipe(entry), "verb": "Craft",
					"enabled": Economy.can_craft(entry, pack.items, GameState.hero.jobs),
					"action": func() -> void: _crafted(GameState.craft(recipe_id), entry),
				})
	return out


func _refresh() -> void:
	for index in tab_buttons.size():
		UiStyle.focus(tab_buttons[index], index == tab)
	gold_label.text = "Gold: %d" % GameState.pack.gold
	rows = _build_rows()
	selected = clampi(selected, 0, maxi(0, rows.size() - 1))
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	if rows.is_empty():
		list.add_child(UiStyle.label(_empty_note(), 14, UiStyle.FADED))
	for index in rows.size():
		list.add_child(_row(index))
	var row := rows[selected] if not rows.is_empty() else {}
	detail.text = row.get("detail", "")
	act_button.visible = not row.is_empty()
	act_button.text = "E  %s" % row.get("verb", "")
	act_button.disabled = not row.get("enabled", false)
	if not rows.is_empty():
		# Deferred until layout. Old rows leave the list at once on refresh, so
		# looking the row up by index then always finds the current one.
		var index := selected
		var reveal := func() -> void:
			if index < list.get_child_count():
				scroll.ensure_control_visible(list.get_child(index))
		reveal.call_deferred()


func _row(index: int) -> Control:
	var row: Dictionary = rows[index]
	var panel := PanelContainer.new()
	var chosen := index == selected
	panel.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 8
	))
	panel.gui_input.connect(_on_row_input.bind(index))
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(line)
	var color := UiStyle.INK if row["enabled"] else UiStyle.FADED
	var name := UiStyle.label(row["label"], 16, color)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	line.add_child(UiStyle.label(row["price"], 16, UiStyle.LAMP if row["enabled"] else UiStyle.FADED))
	return panel


func _on_row_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if event.double_click and index == selected:
			_act()
		else:
			_select(index)


func _act() -> void:
	if rows.is_empty():
		return
	var row := rows[selected]
	if not row["enabled"]:
		status.text = "Not possible right now."
		return
	row["action"].call()
	_refresh()


func _after(ok: bool, done: String, refused: String) -> void:
	status.text = done if ok else refused


func _sold(gold: int) -> void:
	status.text = "Sold for %dg." % gold if gold > 0 else "Not for sale."


func _crafted(result: Dictionary, entry: Dictionary) -> void:
	if not result["made"]:
		status.text = "Missing materials or skill."
		return
	Sound.play("craft")
	if result["count"] > 1:
		status.text = "A lucky brew: 2x %s!" % Catalog.item_name(entry["itemId"])
	else:
		status.text = "Made %s." % Catalog.item_name(entry["itemId"])


func _empty_note() -> String:
	match tabs[tab]:
		"Sell":
			return "Nothing to sell. Worn gear stays on your back."
		"Forge":
			return "Bring me steel to work with."
	return "Nothing here yet."


static func _gear_label(instance: Dictionary) -> String:
	var bonus: int = instance["bonus"]
	return InventoryState.gear_name(instance) + (" +%d" % bonus if bonus > 0 else "")


## Name, flavor and the numbers that matter, for the side panel.
static func _describe(item_id: String, instance := {}) -> String:
	var item := Catalog.item(item_id)
	var lines: Array[String] = [
		_gear_label(instance) if not instance.is_empty() else String(item["name"]),
		String(item.get("description", "")),
	]
	var bonus: int = instance.get("bonus", 0)
	if item.has("damage"):
		lines.append("Damage %d" % (int(item["damage"]) + bonus))
	if item.has("armor"):
		lines.append("Armor %d" % (int(item["armor"]) + bonus))
	for stat: String in item.get("grants", {}):
		lines.append("+%d %s" % [item["grants"][stat], stat])
	if item.has("restoreHp"):
		lines.append("Restores %d HP" % item["restoreHp"])
	if item.has("restoreMp"):
		lines.append("Restores %d MP" % item["restoreMp"])
	lines.append("Weight %d" % item["weight"])
	return "\n".join(lines)


static func _describe_recipe(entry: Dictionary) -> String:
	var lines: Array[String] = [_describe(entry["itemId"]), "", "Needs:"]
	for need: String in entry["needs"]:
		lines.append("  %d x %s  (have %d)" % [entry["needs"][need], Catalog.item_name(need), GameState.pack.items.get(need, 0)])
	lines.append("%s level %d" % [String(entry["job"]["id"]).capitalize(), entry["job"]["level"]])
	return "\n".join(lines)


func _close() -> void:
	get_tree().paused = false
	queue_free()
