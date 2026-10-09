extends Screen
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
var stack_button: Button
var purse: HBoxContainer
var status: Label


func _open() -> void:
	layer = 5
	shop_id = GameState.trade.active_shop()
	var shop := Economy.shop(shop_id)
	# The owner's till, emptied as they walk up (PIX-178).
	var owned := GameState.trade.owned_shop_map(shop_id)
	var collected := GameState.collect_till(owned) if owned != "" else 0
	tabs = ["Buy", "Sell"]
	if shop.get("forge", false):
		tabs.append("Forge")
		# Hilda breaks old gear down, and from Smithing 8 reforges it (PIX-182).
		tabs.append("Salvage")
		if int(GameState.hero.jobs["smithing"]["level"]) >= int(Economy._data()["reforge"]["smithing"]):
			tabs.append("Reforge")
		# Deep pieces can be quenched (PIX-218): the Deep Hunt's gold sink.
		if GameState.pack.gear.any(func(piece: Dictionary) -> bool: return int(piece.get("deep", 0)) > 0):
			tabs.append("Quench")
	if _craft_job() != "":
		tabs.append("Craft")

	dim()
	# The counter's ledger: a page under the tabs, the wares and the news.
	add_child(UiStyle.page(Rect2(60, 90, 740, 530)))
	add_child(UiStyle.title(shop["keeper"]))
	add_child(UiStyle.label(shop["greeting"], 14, UiStyle.DUSK, Vector2(80, 66)))
	purse = UiStyle.purse(0, 18)
	purse.position = Vector2(1060, 20)
	add_child(purse)

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
	# Large text reaches the counter's words too (PIX-214).
	detail = UiStyle.label("", UiStyle.reading(14), UiStyle.INK)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(340, 0)
	side_box.add_child(detail)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	side_box.add_child(actions)
	act_button = UiStyle.button("", _act)
	actions.add_child(act_button)
	# A stack also sells whole (Z), for the mouse too.
	stack_button = UiStyle.button("", _sell_stack)
	actions.add_child(stack_button)

	status = UiStyle.label("", 14, UiStyle.LAMP, Vector2(80, 580))
	add_child(status)
	add_child(UiStyle.screen_footer(Text.t("{key:move_left}/{key:move_right}  tab      {key:move_up}/{key:move_down}  choose      {key:interact}  %s      Z  sell a stack      Esc  close") % "/".join(tabs.map(func(tab: String) -> String: return Text.t(tab))).to_lower()))
	if collected > 0:
		status.text = Text.t("%s hands you the till: +%d gold.") % [String(shop.get("keeper", "")), collected]
	# A keeper who sells their business explains deeds once (PIX-179).
	if Town.deeds().has(GameState.world.map_id) and get_tree().current_scene.has_method("hint"):
		get_tree().current_scene.hint("deed")
	_refresh()


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
		command = _act
	elif event.is_action_pressed("drop_all") and not rows.is_empty() and rows[selected].has("stack"):
		command = _sell_stack
	return command


## Z on the Sell tab: the whole stack at once (PIX-89).
func _sell_stack() -> void:
	var item_id: String = rows[selected]["stack"]
	var count: int = GameState.pack.items.get(item_id, 0)
	var gold := GameState.trade.sell_item(item_id, count)
	status.text = Text.t("Sold %d %s for %dg.") % [count, Catalog.item_name(item_id), gold] if gold > 0 else "Not for sale."
	_refresh()


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
		if GameState.trade.at_station(job) and Economy.station_shop(job) == shop_id:
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
					"label": Text.t("Deed: %s") % deed["name"], "price": Text.t("owned") if owned else Text.coins(int(deed["cost"])),
					"detail": Text.t("%s\nOwn this business: its till fills with %dg a day, and you pay a tenth less here.") % [deed["name"], Town.daily_rent(map_id, false, GameState.town_tier())],
					"verb": "Buy the deed", "enabled": not owned and pack.gold >= int(deed["cost"]),
					"action": func() -> void: _after(GameState.buy_property(map_id), "The deed is yours.", "Not enough gold."),
				})
			# Odo also sells the bigger house deeds (BUY_HOUSE_UPGRADE).
			var bigger := Town.next_house_tier(GameState.household.owns_house(), int(GameState.settlement.house.get("tier", 1)))
			if shop_id == "odo" and not bigger.is_empty():
				out.append({
					"label": Text.t("Deed: %s") % bigger["name"], "price": Text.coins(int(bigger["cost"])),
					"detail": Text.t("%s\nA bigger house: its new rooms wait the next time you walk in.") % bigger["name"],
					"verb": "Sign the deed", "enabled": pack.gold >= int(bigger["cost"]),
					"action": func() -> void:
						var text := GameState.household.buy_house_upgrade()
						status.text = text if text != "" else "Not enough gold.",
				})
			var picked := GameState.trade.owned_shop_map(shop_id) != ""
			var stock: Array = Economy.shop_stock(shop_id, GameState.trade.stock_stage(), GameState.town_tier())
			for item_id in GameState.trade.shop_wares(shop_id):
				var price := GameState.trade.price_of(item_id)
				# What only Pixelheim sells, since the age that brought it (PIX-159).
				var signature: bool = Catalog.item(item_id).get("signature", false)
				var detail := _describe(item_id)
				if signature:
					# Whole sentences, so each language can say the place its own way (PIX-196).
					var since: String = Text.t("\nThe shop's own, since Pixelheim became a %s.") if shop_id == "odo" else (
						Text.t("\nThe forge's own, since Pixelheim became a %s.") if shop_id == "smith" else Text.t("\nThe workshop's own, since Pixelheim became a %s."))
					detail += since % String(Town.tier(Economy.age_of(shop_id, item_id))["name"]).to_lower()
				out.append({
					"label": Catalog.item_name(item_id), "price": Text.coins(price), "icon": item_id,
					"tag": "Pixelheim's own" if signature else ("Owner's pick" if picked and item_id not in stock else ""),
					"detail": detail, "verb": "Buy", "enabled": pack.gold >= price,
					"action": func() -> void: _after(GameState.trade.buy_item(item_id), Text.t("Bought %s.") % Catalog.item_name(item_id), "Not enough gold."),
				})
		"Sell":
			for item_id: String in pack.items:
				# What the story gave you isn't for sale (the letter, PIX-152).
				if Catalog.item(item_id).get("quest", false):
					continue
				var each := floori(Economy.sell_price_at(shop_id, item_id, GameState.town_tier()) * GameState.trade.sale_multiplier(shop_id))
				out.append({
					"label": "%s  x%d" % [Catalog.item_name(item_id), pack.items[item_id]], "price": Text.coins(each), "icon": item_id,
					"detail": _describe(item_id), "verb": "Sell one", "enabled": true, "stack": item_id,
					"action": func() -> void: _sold(GameState.trade.sell_item(item_id)),
				})
			for instance in pack.gear:
				if pack.is_equipped(instance["uid"]):
					continue
				var uid: String = instance["uid"]
				var price := floori(Economy.gear_sell_price_at(shop_id, instance, GameState.town_tier()) * GameState.trade.sale_multiplier(shop_id))
				out.append({
					"label": _gear_label(instance), "price": Text.coins(price), "icon": instance["itemId"],
					"detail": _describe(instance["itemId"], instance), "verb": "Sell", "enabled": true,
					"action": func() -> void: _sold(GameState.trade.sell_gear(uid)),
				})
		"Forge":
			var smithing: int = GameState.hero.jobs["smithing"]["level"]
			for instance in pack.gear:
				var uid: String = instance["uid"]
				# Past the cap, masterwork from Smithing 8: a gem a step (PIX-180).
				var past: bool = instance["bonus"] >= Economy.forge_cap_for(smithing)
				var maxed: bool = past and not Economy.masterwork_open(smithing, instance["bonus"])
				var cost := GameState.trade.forge_price(instance, smithing, past)
				out.append({
					"label": _gear_label(instance) + (Text.t("  (worn)") if pack.is_equipped(uid) else ""), "icon": instance["itemId"],
					"price": Text.t("max") if maxed else (Text.t("%dg + gem") % cost if past else Text.coins(cost)),
					"detail": _describe(instance["itemId"], instance), "verb": "Temper +1",
					"enabled": not maxed and pack.gold >= cost,
					"action": func() -> void: _after(GameState.trade.upgrade_gear(uid), "Hilda tempers it: +1.", "Not enough gold, or it can take no more."),
				})
		"Quench":
			var gem := String(Economy._data()["quench"]["gem"])
			for instance in pack.gear:
				if int(instance.get("deep", 0)) <= 0:
					continue
				var uid: String = instance["uid"]
				var cost := Economy.quench_cost(instance)
				out.append({
					"label": _gear_label(instance) + (Text.t("  (worn)") if pack.is_equipped(uid) else ""), "icon": instance["itemId"],
					"price": Text.t("%dg + gem") % cost,
					"detail": _describe(instance["itemId"], instance) + "\n\n" + Text.t("Quenching adds +1 %s, for gold and a gem; each time costs half again.") % Text.t(Skills.ABBR[Economy.quench_stat(instance)]),
					"verb": "Quench",
					"enabled": pack.gold >= cost and int(pack.items.get(gem, 0)) > 0,
					"action": func() -> void:
						var line := GameState.trade.quench_gear(uid)
						if line != "":
							Sound.play("craft")
						status.text = line if line != "" else Text.t("That takes %dg and a gem.") % cost,
				})
		"Salvage":
			for instance in pack.gear:
				if pack.is_equipped(instance["uid"]):
					continue
				var uid: String = instance["uid"]
				var back := Economy.salvage_yield(instance)
				var parts: Array[String] = []
				for item_id: String in back:
					parts.append("%d %s" % [int(back[item_id]), Catalog.item_name(item_id)])
				out.append({
					"label": _gear_label(instance), "icon": instance["itemId"], "price": ", ".join(parts),
					"detail": _describe(instance["itemId"], instance), "verb": "Salvage", "enabled": true,
					"action": func() -> void: status.text = GameState.trade.salvage_gear(uid),
				})
		"Reforge":
			for instance in pack.gear:
				var uid: String = instance["uid"]
				var cost := Economy.reforge_cost(instance)
				out.append({
					"label": _gear_label(instance) + (Text.t("  (worn)") if pack.is_equipped(uid) else ""), "icon": instance["itemId"],
					"price": Text.coins(cost), "detail": _describe(instance["itemId"], instance), "verb": "Reforge",
					"enabled": pack.gold >= cost,
					"action": func() -> void:
						var line := GameState.trade.reforge_gear(uid)
						status.text = line if line != "" else "Not enough gold.",
				})
		"Craft":
			# This station's recipes, easiest first.
			var entries := Economy.recipes().filter(func(entry: Dictionary) -> bool: return entry["job"]["id"] == _craft_job())
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return int(a["job"]["level"]) < int(b["job"]["level"]) or (
					a["job"]["level"] == b["job"]["level"] and Catalog.item_name(a["itemId"]) < Catalog.item_name(b["itemId"])
				)
			)
			for entry: Dictionary in entries:
				var recipe_id: String = entry["id"]
				out.append({
					"label": Catalog.item_name(entry["itemId"]), "icon": entry["itemId"],
					"price": "%s %d" % [Economy.job_name(entry["job"]["id"]), entry["job"]["level"]],
					# Written when the row is chosen, not for every row each move (PIX-207).
					"detail_of": _describe_recipe.bind(entry), "verb": "Craft",
					"enabled": Economy.can_craft(entry, pack.items, GameState.hero.jobs),
					"action": func() -> void: _craft(recipe_id, entry),
				})
	return out


func _refresh() -> void:
	for index in tab_buttons.size():
		UiStyle.focus(tab_buttons[index], index == tab)
	UiStyle.purse_set(purse, GameState.pack.gold)
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
	detail.text = row["detail_of"].call() if row.has("detail_of") else row.get("detail", "")
	act_button.visible = not row.is_empty()
	UiStyle.button_keyed(act_button, "{key:interact}", Text.t(row.get("verb", "")))
	act_button.disabled = not row.get("enabled", false)
	var stacked: int = GameState.pack.items.get(row.get("stack", ""), 0)
	stack_button.visible = stacked > 1
	UiStyle.button_keyed(stack_button, "Z", Text.t("Sell all %d") % stacked)
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
	line.add_theme_constant_override("separation", 10)
	panel.add_child(line)
	# The item's own icon, as in the pack (deeds have none).
	if row.has("icon"):
		var icon := TextureRect.new()
		icon.texture = ItemIcons.texture(row["icon"])
		icon.custom_minimum_size = Vector2(32, 32)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate.a = 1.0 if row["enabled"] else 0.55
		line.add_child(icon)
	var color := UiStyle.INK if row["enabled"] else UiStyle.FADED
	var name := UiStyle.label(row["label"], 16, color)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(name)
	# A signature item's mark (PIX-159), before its price.
	if row.get("tag", "") != "":
		line.add_child(UiStyle.label(row["tag"], 16, UiStyle.FADED))
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
		Sound.play_ui("deny")
		return
	row["action"].call()
	_refresh()


func _after(ok: bool, done: String, refused: String) -> void:
	status.text = done if ok else refused
	# Coin for a deal, a no for a refusal (PIX-212).
	if ok:
		Sound.play("coin")
	else:
		Sound.play_ui("deny")


func _sold(gold: int) -> void:
	status.text = Text.t("Sold for %dg.") % gold if gold > 0 else "Not for sale."


## A craft, unless it would take what a taken delivery needs: then it asks
## first, and the same craft again goes ahead (PIX-206).
func _craft(recipe_id: String, entry: Dictionary) -> void:
	var ask := GameState.ask_before_dip("craft:" + recipe_id, entry["needs"])
	if ask != "":
		status.text = ask
		return
	_crafted(GameState.trade.craft(recipe_id), entry)


func _crafted(result: Dictionary, entry: Dictionary) -> void:
	if not result["made"]:
		var job: String = entry["job"]["id"]
		if int(GameState.hero.jobs[job]["level"]) < int(entry["job"]["level"]):
			status.text = Text.t("That takes %s %d.") % [Economy.job_name(job), entry["job"]["level"]]
		else:
			status.text = Text.t("Still missing: %s.") % ", ".join(Economy.missing_names(entry, GameState.pack.items))
		return
	Sound.play("craft")
	if result["count"] > 1:
		status.text = Text.t("A lucky brew: 2x %s! %s") % [Catalog.item_name(entry["itemId"]), result["level_line"]]
	else:
		status.text = Text.t("Made %s. %s") % [Catalog.item_name(entry["itemId"]), result["level_line"]]


func _empty_note() -> String:
	match tabs[tab]:
		"Sell":
			return "Nothing to sell. Worn gear stays on your back."
		"Forge":
			return "Bring me steel to work with."
		"Salvage":
			return "Nothing to break down. Worn gear stays on your back."
		"Reforge":
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
	# The forge's bonus and the deep's (PIX-218).
	var bonus: int = int(instance.get("bonus", 0)) + int(instance.get("deepBonus", 0))
	if item.has("damage"):
		lines.append(Text.t("Damage %d") % (int(item["damage"]) + bonus))
		# What it hits with (PIX-183): the stat a swing of it adds.
		lines.append(Text.t("Scales with %s") % Text.t(Skills.ABBR.get(String(item.get("scaling", "strength")), "STR")))
	if item.has("armor"):
		lines.append(Text.t("Armor %d") % (int(item["armor"]) + bonus))
	for stat: String in item.get("grants", {}):
		lines.append("+%d %s" % [item["grants"][stat], Text.t(Skills.ABBR.get(stat, stat))])
	if not InventoryState.shown_affixes(instance).is_empty():
		lines.append(InventoryState.affix_line(instance))
	# A set piece says its set and what wearing more of it gives (PIX-166).
	if item.has("set"):
		lines.append(Catalog.set_line(item["set"], int(GameState.pack.set_counts().get(item["set"], 0))))
	if item.has("restoreHp"):
		lines.append(Text.t("Restores %d HP") % GameState.hp_restore(item))
	if item.has("restoreMp"):
		lines.append(Text.t("Restores %d MP") % item["restoreMp"])
	lines.append(Text.t("Weight %d") % item["weight"])
	return "\n".join(lines)


static func _describe_recipe(entry: Dictionary) -> String:
	var lines: Array[String] = [_describe(entry["itemId"]), "", Text.t("Needs:")]
	for need: String in entry["needs"]:
		var have: int = GameState.pack.items.get(need, 0)
		lines.append(Text.t("  %d x %s  (have %d)") % [entry["needs"][need], Catalog.item_name(need), have])
		# Where a missing one comes from (PIX-143).
		if have < int(entry["needs"][need]):
			var sources := Economy.material_sources(need, GameState.town_tier(), GameState.trade.stock_stage())
			if not sources.is_empty():
				lines.append("    " + String(sources[0]["text"]))
	var job: String = entry["job"]["id"]
	lines.append(Text.t("%s level %d - you are %s") % [Economy.job_name(job), entry["job"]["level"], Economy.job_line(GameState.hero.jobs, job)])
	return "\n".join(lines)
