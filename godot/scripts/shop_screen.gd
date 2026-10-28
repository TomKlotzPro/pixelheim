extends Screen
## areas: trade
## A keeper's counter (talk to anyone in a shop): Buy, Sell, the Forge at the
## smithy, and Craft at the forge and the cauldron. Crafting lives in the web
## game's pack screen; until the UI suite brings that screen (PIX-127) the
## stations offer it here, and E at a forge, an anvil or a cauldron opens the
## counter on Craft (PIX-234).
## Buy and Sell lie open side by side (PIX-336): the shop's goods on the
## left, the pack on the right, and between them the chosen thing's card -
## its numbers against what's worn there (green up, red down), the hero
## wearing it, its price and the gold after. Junk is marked and sold in one
## go, a stack asks how many, and this visit's sales wait on a buyback shelf
## at what they fetched until the counter closes. A/D switch tabs (Buy is
## the left list, Sell the right), W/S choose, E acts, Z sells a stack (how
## many asked), Esc closes; everything is clickable too. Pauses the world
## while open.

## Where things stand on the 1280x720 canvas (PIX-336). Buy and Sell: the
## goods, the card, the pack. The other tabs: their list across the left
## two, the card at the right.
const GOODS := Rect2(64, 136, 384, 500)
const CARD := Rect2(460, 136, 360, 500)
const PACK := Rect2(832, 136, 384, 500)
const WIDE := Rect2(64, 136, 756, 500)
const SIDE := Rect2(832, 136, 384, 500)
## A page's margin round its list, the heading's room over it, and the room
## a list leaves its scrollbar.
const INSET := 16.0
const HEADED := 44.0
const BAR := 16.0
## The card's padding inside its frame.
const PADDING := 14
## The most of a wide row a tag or a price takes before it wraps, so the
## name beside it keeps room.
const NOTE_SHARE := 0.4
## The tabs that lie open together: Buy the left list, Sell the right.
const PAIRED := ["Buy", "Sell"]

var shop_id := ""
var tabs: Array[String] = []
var tab := 0
## The tab it opens on, by name: E at a forge or a cauldron opens the
## counter on its Craft tab (PIX-234). The first tab when it has none such.
var start_tab := ""
var selected := 0
## Where each tab's choice stood: Buy and Sell keep theirs across A/D.
var _chosen := {}
var rows: Array[Dictionary] = []
var tab_buttons: Array[Button] = []
var footer: HBoxContainer
## The left and right pages, their headings, scrolling windows and lists.
var pages: Array[Panel] = []
var headings: Array[Label] = []
var scrolls: Array[ScrollContainer] = []
var lists: Array[VBoxContainer] = []
var card: PanelContainer
var card_head: HBoxContainer
var card_icon: TextureRect
var card_name: Label
## The hero wearing the chosen piece, beside its numbers against what's worn.
var card_body: HBoxContainer
var card_doll: PanelContainer
var card_numbers: VBoxContainer
## What's worn there, the set, and the like, under the numbers.
var card_extra: Label
var detail: Label
var price_row: HBoxContainer
var after_row: HBoxContainer
var picker: HFlowContainer
var picked: Label
var act_button: Button
var other_button: Button
var purse: HBoxContainer
var status: Label
## How many of the chosen stack E sells while the counter asks (PIX-336);
## 0 when it isn't asking.
var amount := 0
## Whether E sells all the junk, asked once with its sum.
var asking_junk := false


func _open() -> void:
	layer = 5
	shop_id = GameState.trade.active_shop()
	var shop := Economy.shop(shop_id)
	# The owner's till, emptied as they walk up (PIX-178).
	var owned := GameState.trade.owned_shop_map(shop_id)
	var collected := GameState.holdings.collect_till(owned) if owned != "" else 0
	tabs = ["Buy", "Sell"]
	if shop.get("forge", false):
		tabs.append("Forge")
		# Hilda breaks old gear down, and from Smithing 8 reforges it (PIX-182).
		tabs.append("Salvage")
		if int(GameState.hero.jobs["smithing"]["level"]) >= int(Economy.forge_rules("reforge")["smithing"]):
			tabs.append("Reforge")
		# Deep pieces can be quenched (PIX-218): the Vault's gold sink (PIX-257).
		if GameState.pack.gear.any(func(piece: Dictionary) -> bool: return int(piece.get("deep", 0)) > 0):
			tabs.append("Quench")
	if _craft_job() != "":
		tabs.append("Craft")
	tab = maxi(0, tabs.find(start_tab))
	# The buyback shelf is this visit's: leaving the counter empties it.
	tree_exiting.connect(func() -> void: GameState.trade.sold_here.clear())

	dim()
	add_child(UiStyle.title(shop["keeper"]))
	add_child(UiStyle.label(shop["greeting"], 14, UiStyle.DUSK, Vector2(80, 66)))
	purse = UiStyle.purse(0, 18)
	purse.position = Vector2(1060, 20)
	add_child(purse)

	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(80, 94)
	tab_row.add_theme_constant_override("separation", 10)
	for index in tabs.size():
		var button := UiStyle.button(tabs[index], _switch.bind(index))
		tab_buttons.append(button)
		tab_row.add_child(button)
	add_child(tab_row)

	# Two pages: the goods (or a tab's list) and the pack. In a frame of their
	# own, which the entrance eases in (UiStyle.enter) while _place moves
	# what's in it: a tab changed as the screen rose left the card where it
	# rose to.
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)
	for side in 2:
		var page := UiStyle.page(GOODS)
		pages.append(page)
		frame.add_child(page)
		var heading := UiStyle.heading("For sale" if side == 0 else "Your pack", 14, UiStyle.INK)
		headings.append(heading)
		frame.add_child(heading)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scrolls.append(scroll)
		frame.add_child(scroll)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 4)
		lists.append(list)
		scroll.add_child(list)

	# The card: what's chosen, then what just happened and what E does.
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.window(PADDING))
	frame.add_child(card)
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 8)
	card.add_child(inside)
	# What the card says scrolls when large text runs it long (PIX-214).
	var about := ScrollContainer.new()
	about.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	about.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inside.add_child(about)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 8)
	about.add_child(info)
	card_head = HBoxContainer.new()
	card_head.add_theme_constant_override("separation", 10)
	info.add_child(card_head)
	card_icon = TextureRect.new()
	card_icon.custom_minimum_size = Vector2(48, 48)
	card_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_head.add_child(card_icon)
	card_name = UiStyle.strong("", 16, UiStyle.INK)
	card_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_head.add_child(card_name)
	card_body = HBoxContainer.new()
	card_body.add_theme_constant_override("separation", 12)
	info.add_child(card_body)
	card_doll = PanelContainer.new()
	card_doll.custom_minimum_size = Vector2(104, 104)
	card_doll.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.CARD, UiStyle.RIM, 4))
	card_doll.add_child(Control.new())
	card_body.add_child(card_doll)
	card_numbers = VBoxContainer.new()
	card_numbers.add_theme_constant_override("separation", 2)
	card_numbers.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_numbers.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card_body.add_child(card_numbers)
	card_extra = UiStyle.label("", 14, UiStyle.INK)
	card_extra.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(card_extra)
	# Large text reaches the counter's words too (PIX-214).
	detail = UiStyle.label("", UiStyle.reading(14), UiStyle.INK)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(detail)
	price_row = HBoxContainer.new()
	after_row = HBoxContainer.new()
	for row: HBoxContainer in [price_row, after_row]:
		row.add_theme_constant_override("separation", 10)
		info.add_child(row)
	# How many of a stack (PIX-336): a key and a plank each way, all of it.
	picker = Layout.flow(8)
	picker.add_child(UiStyle.button("-", func() -> void: _pick(amount - 1), "{key:move_left}"))
	picked = UiStyle.strong("", 16, UiStyle.INK)
	picked.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	picker.add_child(picked)
	picker.add_child(UiStyle.button("+", func() -> void: _pick(amount + 1), "{key:move_right}"))
	picker.add_child(UiStyle.button("All", func() -> void: _pick(_stack_count()), "Z"))
	inside.add_child(picker)
	# Two lines on the card when a recipe lacks a lot (PIX-234), not one
	# running off it.
	status = UiStyle.label("", 14, UiStyle.LAMP)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inside.add_child(status)
	var actions := Layout.flow(10)
	inside.add_child(actions)
	act_button = UiStyle.button("", _act)
	actions.add_child(act_button)
	# A stack sells whole (Z) and a question is put down (Esc), for the
	# mouse too.
	other_button = UiStyle.button("", _other)
	actions.add_child(other_button)

	_set_footer()
	if collected > 0:
		status.text = Text.t("%s hands you the till: +%d gold.") % [String(shop.get("keeper", "")), collected]
	# A keeper who sells their business explains deeds once (PIX-179).
	if Town.deeds().has(GameState.world.map_id) and get_tree().current_scene.has_method("hint"):
		get_tree().current_scene.hud.hint("deed")
	_refresh()


func _command(event: InputEvent) -> Callable:
	# A question asked (how many, all the junk): E answers, Esc puts it down.
	if amount > 0 or asking_junk:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu"):
			return _cancel
		if event.is_action_pressed("interact"):
			return _act
		if amount > 0 and (event.is_action_pressed("move_right") or event.is_action_pressed("move_up")):
			return _pick.bind(amount + 1)
		if amount > 0 and (event.is_action_pressed("move_left") or event.is_action_pressed("move_down")):
			return _pick.bind(amount - 1)
		if amount > 0 and event.is_action_pressed("drop_all"):
			return _pick.bind(_stack_count())
		return Callable()
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
		command = _ask.bind(_stack_count())
	return command


## Selling a stack asks how many first (PIX-336), from `count`.
func _ask(count: int) -> void:
	amount = Trade.stack_amount(count, _stack_count())
	status.text = ""
	_refresh()


func _pick(count: int) -> void:
	if amount > 0:
		amount = Trade.stack_amount(count, _stack_count())
		_refresh()


## The chosen stack's size, 0 when the row isn't a stack.
func _stack_count() -> int:
	return int(GameState.pack.items.get(rows[selected].get("stack", ""), 0)) if not rows.is_empty() else 0


## The question put down, nothing sold.
func _cancel() -> void:
	amount = 0
	asking_junk = false
	status.text = ""
	_refresh()


## The second plank: put a question down, or ask for the whole stack.
func _other() -> void:
	if amount > 0 or asking_junk:
		_cancel()
	elif not rows.is_empty() and rows[selected].has("stack"):
		_ask(_stack_count())


func _switch(index: int) -> void:
	_chosen[tabs[tab]] = selected
	tab = wrapi(index, 0, tabs.size())
	selected = int(_chosen.get(tabs[tab], 0))
	amount = 0
	asking_junk = false
	status.text = ""
	_set_footer()
	_refresh()


## The footer (PIX-374): what E does on this tab, a verb (a tab's name is
## a noun in French: « Forge », « Artisanat »), and Z only where a stack sells.
func _set_footer() -> void:
	if footer != null:
		remove_child(footer)
		footer.queue_free()
	var verb: String = {"Buy": Text.t("buy"), "Sell": Text.t("sell"), "Forge": Text.t("forge"), "Salvage": Text.t("salvage"),
		"Reforge": Text.t("reforge"), "Quench": Text.t("quench"), "Craft": Text.t("craft")}[tabs[tab]]
	var line := Text.t("{key:move_left}/{key:move_right}  tab      {key:move_up}/{key:move_down}  choose      {key:interact}  %s      Z  sell a stack      Esc  close") if tabs[tab] == "Sell" \
		else Text.t("{key:move_left}/{key:move_right}  tab      {key:move_up}/{key:move_down}  choose      {key:interact}  %s      Esc  close")
	footer = UiStyle.screen_footer(line % verb)
	add_child(footer)


func _select(index: int) -> void:
	if rows.is_empty():
		return
	selected = clampi(index, 0, rows.size() - 1)
	amount = 0
	asking_junk = false
	_refresh()


## Whether Buy and Sell lie open: the goods beside the pack.
func _paired() -> bool:
	return tabs[tab] in PAIRED


## The trade this station crafts, if any (the smithy forges, Vex brews).
func _craft_job() -> String:
	for job: String in ["smithing", "alchemy"]:
		if GameState.trade.at_station(job) and Economy.station_shop(job) == shop_id:
			return job
	return ""


## A stack's junk tag (PIX-374): "junk" when all of it goes, else how many
## of it the lot sells ("4 junk" on ten herbs), "" for none.
static func junk_tag(junk: int, count: int) -> String:
	if junk <= 0:
		return ""
	return Text.t("junk") if junk >= count else Text.t("%d junk") % junk


## Rows for a tab: {label, cost or price, detail or card words, action,
## enabled}; at Buy and Sell also the item and piece the card shows.
func _rows_for(tab_name: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pack := GameState.pack
	var trade := GameState.trade
	match tab_name:
		"Buy":
			# This visit's sales first, at what they fetched (PIX-336).
			for index in trade.sold_here.size():
				var entry: Dictionary = trade.sold_here[index]
				var piece: Dictionary = entry.get("piece", {})
				var name: String = _gear_label(piece) if not piece.is_empty() else Catalog.item_name(entry["item_id"])
				var cost := int(entry["each"]) * int(entry["count"])
				out.append({
					"label": name, "count": int(entry["count"]), "cost": cost, "icon": entry["item_id"], "item_id": entry["item_id"],
					"piece": piece, "tag": Text.t("sold"), "verb": "Buy back", "enabled": pack.gold >= cost,
					"action": func() -> void: _after(trade.buy_back(index), Text.t("Bought back %s.") % name, "Not enough gold."),
				})
			# The business itself is for sale too (BUY_PROPERTY): rent after every victory.
			var map_id := GameState.world.map_id
			var deed: Dictionary = Town.deeds().get(map_id, {})
			if not deed.is_empty():
				var owned := map_id in GameState.settlement.properties
				var row := {
					"label": Text.t("Deed: %s") % deed["name"],
					"detail": Text.t("%s\nOwn this business: its till fills with %dg a day, and you pay a tenth less here.") % [deed["name"], Town.daily_rent(map_id, false, GameState.town_tier())],
					"verb": "Buy the deed", "enabled": not owned and pack.gold >= int(deed["cost"]),
					"action": func() -> void: _after(GameState.holdings.buy_property(map_id), "The deed is yours.", "Not enough gold."),
				}
				if owned:
					row["price"] = Text.t("owned")
				else:
					row["cost"] = int(deed["cost"])
				out.append(row)
			# Odo also sells the bigger house deeds (BUY_HOUSE_UPGRADE).
			var bigger := Town.next_house_tier(GameState.household.owns_house(), int(GameState.settlement.house.get("tier", 1)))
			if shop_id == "odo" and not bigger.is_empty():
				out.append({
					"label": Text.t("Deed: %s") % bigger["name"], "cost": int(bigger["cost"]),
					"detail": Text.t("%s\nA bigger house: its new rooms wait the next time you walk in.") % bigger["name"],
					"verb": "Sign the deed", "enabled": pack.gold >= int(bigger["cost"]),
					"action": func() -> void:
						var text := GameState.household.buy_house_upgrade()
						status.text = text if text != "" else "Not enough gold.",
				})
			var picked_here := trade.owned_shop_map(shop_id) != ""
			var stock: Array = Economy.shop_stock(shop_id, trade.stock_stage(), GameState.town_tier())
			for item_id in trade.shop_wares(shop_id):
				var price := trade.price_of(item_id)
				# What only Pixelheim sells, since the age that brought it (PIX-159).
				var signature: bool = Catalog.item(item_id).get("signature", false)
				var words := String(Catalog.item(item_id).get("description", ""))
				if signature:
					# Whole sentences, so each language can say the place its own way (PIX-196).
					var since: String = Text.t("\nThe shop's own, since Pixelheim became a %s.") if shop_id == "odo" else (
						Text.t("\nThe forge's own, since Pixelheim became a %s.") if shop_id == "smith" else Text.t("\nThe workshop's own, since Pixelheim became a %s."))
					words += since % String(Town.tier(Economy.age_of(shop_id, item_id))["name"]).to_lower()
				out.append({
					"label": Catalog.item_name(item_id), "cost": price, "icon": item_id, "item_id": item_id,
					# What the card measures and draws: the piece as the shop sells it.
					"piece": {"itemId": item_id, "rarity": "common", "bonus": 0} if Catalog.item(item_id).has("slot") else {},
					"tag": "Pixelheim's own" if signature else ("Owner's pick" if picked_here and item_id not in stock else ""),
					"words": words, "verb": "Buy", "enabled": pack.gold >= price,
					"action": func() -> void: _after(trade.buy_item(item_id), Text.t("Bought %s.") % Catalog.item_name(item_id), "Not enough gold."),
				})
		"Sell":
			# All the junk at once (PIX-336), asked once with its sum.
			var lot := trade.junk()
			if int(lot["gold"]) > 0:
				out.append({
					"label": Text.t("Sell all junk"), "cost": int(lot["gold"]), "lot": lot, "verb": "Sell all junk", "enabled": true,
					"action": func() -> void: asking_junk = true,
				})
			for item_id: String in pack.items:
				# What the story gave you isn't for sale (the letter, PIX-152).
				if Catalog.item(item_id).get("quest", false):
					continue
				var count: int = pack.items[item_id]
				var junk: int = lot["items"].get(item_id, 0)
				out.append({
					"label": Catalog.item_name(item_id), "count": count, "cost": trade.item_pays(item_id), "icon": item_id, "item_id": item_id,
					"tag": junk_tag(junk, count),
					"junk": (Text.t("Junk: nothing needs it.") if junk == count else Text.t("Junk: %d past what crafting keeps.") % junk) if junk > 0 else "",
					"words": String(Catalog.item(item_id).get("description", "")), "verb": "Sell", "enabled": true, "stack": item_id,
					# A stack asks how many (PIX-336); one alone goes.
					"action": func() -> void:
						if count > 1:
							_ask(1)
						else:
							_sold(trade.sell_item(item_id)),
				})
			for instance in pack.gear:
				if pack.is_equipped(instance["uid"]):
					continue
				var uid: String = instance["uid"]
				var junk := trade.junk_piece(instance)
				out.append({
					"label": _gear_label(instance), "cost": trade.gear_pays(instance), "icon": instance["itemId"], "item_id": instance["itemId"],
					"piece": instance, "tag": Text.t("junk") if junk else "", "junk": Text.t("Junk: worse than what you wear.") if junk else "",
					"words": String(Catalog.item(instance["itemId"]).get("description", "")), "verb": "Sell", "enabled": true,
					"action": func() -> void: _sold(trade.sell_gear(uid)),
				})
		"Forge":
			var smithing: int = GameState.hero.jobs["smithing"]["level"]
			for instance in pack.gear:
				var uid: String = instance["uid"]
				# Past the cap, masterwork from Smithing 8: a gem a step (PIX-180).
				var past: bool = instance["bonus"] >= Economy.forge_cap_for(smithing)
				var maxed: bool = past and not Economy.masterwork_open(smithing, instance["bonus"])
				var cost := trade.forge_price(instance, smithing, past)
				var row := {
					"label": _gear_label(instance), "tag": Text.t("  (worn)").strip_edges() if pack.is_equipped(uid) else "", "icon": instance["itemId"],
					"detail": _describe(instance["itemId"], instance), "verb": "Temper +1",
					"enabled": not maxed and pack.gold >= cost,
					"action": func() -> void: _after(trade.upgrade_gear(uid), "Hilda tempers it: +1.", "Not enough gold, or it can take no more."),
				}
				if maxed:
					row["price"] = Text.t("max")
				else:
					row["cost"] = cost
					row["price"] = Text.t("+ gem") if past else ""
				out.append(row)
		"Quench":
			var gem := String(Economy.forge_rules("quench")["gem"])
			for instance in pack.gear:
				if int(instance.get("deep", 0)) <= 0:
					continue
				var uid: String = instance["uid"]
				var cost := Economy.quench_cost(instance)
				out.append({
					"label": _gear_label(instance), "tag": Text.t("  (worn)").strip_edges() if pack.is_equipped(uid) else "", "icon": instance["itemId"],
					"cost": cost, "price": Text.t("+ gem"),
					"detail": _describe(instance["itemId"], instance) + "\n\n" + Text.t("Quenching adds +1 %s, for gold and a gem; each time costs half again.") % Text.t(Skills.ABBR[Economy.quench_stat(instance)]),
					"verb": "Quench",
					"enabled": pack.gold >= cost and int(pack.items.get(gem, 0)) > 0,
					"action": func() -> void:
						var line := trade.quench_gear(uid)
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
					parts.append(Text.count(int(back[item_id]), Catalog.item_name(item_id)))
				out.append({
					"label": _gear_label(instance), "icon": instance["itemId"], "price": ", ".join(parts),
					"detail": _describe(instance["itemId"], instance), "verb": "Salvage", "enabled": true,
					"action": func() -> void: status.text = trade.salvage_gear(uid),
				})
		"Reforge":
			for instance in pack.gear:
				var uid: String = instance["uid"]
				var cost := Economy.reforge_cost(instance)
				out.append({
					"label": _gear_label(instance), "tag": Text.t("  (worn)").strip_edges() if pack.is_equipped(uid) else "", "icon": instance["itemId"],
					"cost": cost, "detail": _describe(instance["itemId"], instance), "verb": "Reforge",
					"enabled": pack.gold >= cost,
					"action": func() -> void:
						var line := trade.reforge_gear(uid)
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
					# What it still lacks, said when E is pressed on it (PIX-234).
					"why_of": func() -> String: return Economy.craft_refusal(entry, GameState.pack.items, GameState.hero.jobs),
					"action": func() -> void: _craft(recipe_id, entry),
				})
	return out


func _refresh() -> void:
	for index in tab_buttons.size():
		UiStyle.focus(tab_buttons[index], index == tab)
	UiStyle.purse_set(purse, GameState.pack.gold)
	_place()
	rows = _rows_for(tabs[tab])
	selected = clampi(selected, 0, maxi(0, rows.size() - 1))
	# The chosen tab's list, and at Buy and Sell the other beside it.
	var side := 1 if tabs[tab] == "Sell" else 0
	_fill(side, tabs[tab], rows, selected)
	if _paired():
		var other: String = PAIRED[1 - side]
		_fill(1 - side, other, _rows_for(other), -1)
	_show(rows[selected] if not rows.is_empty() else {})
	if not rows.is_empty():
		# Deferred until layout. Old rows leave the list at once on refresh, so
		# looking the row up by index then always finds the current one.
		var index := selected
		var reveal := func() -> void:
			if index < lists[side].get_child_count():
				scrolls[side].ensure_control_visible(lists[side].get_child(index))
		reveal.call_deferred()


## The pages, lists and card where this tab has them: Buy and Sell three
## columns, the others a wide list and the card.
func _place() -> void:
	var paired := _paired()
	var rects := [GOODS, PACK] if paired else [WIDE, SIDE]
	for side in 2:
		var rect: Rect2 = rects[side]
		pages[side].position = rect.position
		pages[side].size = rect.size
		headings[side].position = rect.position + Vector2(INSET, 12)
		var top := HEADED if paired else INSET
		var room := Vector2(rect.size.x - 2 * INSET, rect.size.y - top - INSET)
		scrolls[side].position = rect.position + Vector2(INSET, top)
		scrolls[side].custom_minimum_size = room
		scrolls[side].size = room
		lists[side].custom_minimum_size = Vector2(room.x - BAR, 0)
		pages[side].visible = paired or side == 0
		scrolls[side].visible = pages[side].visible
		headings[side].visible = paired
	# Without a pack beside it, the card stands where the pack would.
	var at := CARD if paired else SIDE
	card.position = at.position
	card.custom_minimum_size = at.size
	card.size = at.size
	var width := at.size.x - 2 * PADDING
	for words: Label in [card_extra, detail, status]:
		words.custom_minimum_size.x = width - BAR
	card_name.custom_minimum_size.x = width - BAR - 58
	headings[0].add_theme_color_override("font_color", UiStyle.INK if tabs[tab] == "Buy" else UiStyle.FADED)
	headings[1].add_theme_color_override("font_color", UiStyle.INK if tabs[tab] == "Sell" else UiStyle.FADED)


## A list's rows, `chosen` lit (-1: none, the list beside the chosen one).
func _fill(side: int, tab_name: String, list_rows: Array[Dictionary], chosen: int) -> void:
	var list := lists[side]
	Layout.clear(list)
	if list_rows.is_empty():
		list.add_child(Layout.wrapped(UiStyle.label(_empty_note(tab_name), 14, UiStyle.FADED), list.custom_minimum_size.x))
	for index in list_rows.size():
		list.add_child(_row(list_rows[index], index == chosen, tab_name, index))


func _row(row: Dictionary, chosen: bool, tab_name: String, index: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(
		UiStyle.CARD if chosen else Color(UiStyle.CARD, 0.5), UiStyle.LAMP if chosen else UiStyle.RIM, 8
	))
	panel.gui_input.connect(_on_row_input.bind(tab_name, index))
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
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.modulate.a = 1.0 if row["enabled"] else 0.55
		line.add_child(icon)
	# The name gives way to an ellipsis (the card reads it whole); fine and
	# epic pieces in their ink, as in the pack.
	var name := UiStyle.label(row["label"], 16, _ink(row) if row["enabled"] else UiStyle.FADED)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Layout.ellipsis(name)
	# A price you can't pay greyed (PIX-336), the coin as everywhere.
	var money: Array[Control] = []
	if row.has("cost"):
		var coins := UiStyle.purse(int(row["cost"]), 16, UiStyle.INK if row["enabled"] else UiStyle.FADED)
		coins.modulate.a = 1.0 if row["enabled"] else 0.55
		money.append(coins)
	if row.get("price", "") != "":
		money.append(UiStyle.label(row["price"], 16, UiStyle.LAMP if row["enabled"] else UiStyle.FADED))
	var marks: Array[Control] = []
	if int(row.get("count", 1)) > 1:
		marks.append(UiStyle.label("x%d" % row["count"], 16, UiStyle.INK))
	if row.get("tag", "") != "":
		marks.append(UiStyle.label(row["tag"], 16, UiStyle.FADED))
	if _paired():
		# Two lines in a narrow list: the name over its price and marks.
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_constant_override("separation", 0)
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(name)
		var under := HBoxContainer.new()
		under.mouse_filter = Control.MOUSE_FILTER_IGNORE
		under.add_theme_constant_override("separation", 12)
		for note in money + marks:
			under.add_child(note)
		# The last mark gives way when the line runs long (French).
		var last: Control = (money + marks)[-1] if not (money + marks).is_empty() else null
		if last is Label:
			Layout.ellipsis(last as Label)
			last.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.add_child(under)
		line.add_child(words)
		return panel
	# One line in a wide list: the tag and the price keep their words,
	# wrapping when they'd take more than a share of the row: a deep piece's
	# French name with its price ran the Forge's rows 200 px past the page
	# (PIX-298).
	line.add_child(name)
	for note in marks + money:
		if note is Label:
			(note as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			Layout.narrowed(note as Label, NOTE_SHARE * lists[0].custom_minimum_size.x)
		note.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(note)
	return panel


## Fine and epic pieces in their ink, the rest in ink.
static func _ink(row: Dictionary) -> Color:
	match String(row.get("piece", {}).get("rarity", "")):
		"fine":
			return UiStyle.FINE
		"epic":
			return UiStyle.EPIC
	return UiStyle.INK


## The card for the chosen row: at Buy and Sell what it is, the hero
## wearing it, its numbers against what's worn, its price and the gold
## after (PIX-336); at the other tabs what it is in a few lines.
func _show(row: Dictionary) -> void:
	var paired := _paired()
	var gold := GameState.pack.gold
	var item_id: String = row.get("item_id", "")
	var piece: Dictionary = row.get("piece", {})
	card_head.visible = paired and not row.is_empty()
	card_icon.texture = ItemIcons.texture(item_id) if item_id != "" else null
	card_icon.visible = item_id != ""
	card_name.text = String(row.get("label", ""))
	card_name.add_theme_color_override("font_color", _ink(row))
	card_body.visible = paired and not piece.is_empty()
	card_extra.visible = false
	price_row.visible = paired and row.has("cost")
	after_row.visible = price_row.visible
	picker.visible = amount > 0
	# At the other tabs the whole of it in ink; at Buy and Sell what it is, faded under its numbers.
	detail.add_theme_color_override("font_color", UiStyle.FADED if paired else UiStyle.INK)
	if not paired:
		detail.text = row["detail_of"].call() if row.has("detail_of") else row.get("detail", "")
	else:
		detail.text = row.get("detail", row.get("words", ""))
		var extra: Array[String] = []
		if not piece.is_empty():
			_dress(item_id)
			extra.append(_numbers(item_id, piece))
		elif item_id != "":
			Layout.clear(card_numbers)
			extra.append_array(_lines(item_id))
		if row.has("lot"):
			extra.append(_lot_line(row["lot"]))
		if row.get("junk", "") != "":
			extra.append(row["junk"])
		card_extra.text = "\n".join(extra)
		card_extra.visible = card_extra.text != ""
		if row.has("cost"):
			# What the counter pays, for as many as asked.
			var buying := tabs[tab] == "Buy"
			var each := int(row["cost"])
			var sum := each * maxi(1, amount)
			var short := sum - gold if buying else 0
			_coins(price_row, "Price" if buying else ("Pays each" if int(row.get("count", 1)) > 1 and amount == 0 else "Pays"), sum, UiStyle.INK if short <= 0 else UiStyle.FADED)
			if short > 0:
				_coins(after_row, "Short by", short, UiStyle.LAMP)
			else:
				_coins(after_row, "Gold after", gold - sum if buying else gold + sum, UiStyle.INK)
		picked.text = "%d / %d" % [amount, _stack_count()]
	detail.visible = detail.text != ""
	act_button.visible = not row.is_empty()
	var verb: String = Text.t(row.get("verb", ""))
	if amount > 0:
		verb = Text.t("Sell %d") % amount
	elif asking_junk:
		verb = Text.t("Yes")
	UiStyle.button_keyed(act_button, "{key:interact}", verb)
	act_button.disabled = not row.get("enabled", false)
	var stacked := _stack_count()
	other_button.visible = amount > 0 or asking_junk or stacked > 1
	if amount > 0 or asking_junk:
		UiStyle.button_keyed(other_button, "Esc", Text.t("Keep"))
	else:
		UiStyle.button_keyed(other_button, "Z", Text.t("Sell all %d") % stacked)
	if asking_junk:
		status.text = Text.t("Sell all of it?")
	status.visible = status.text != ""


## The hero wearing `item_id` on the card's plinth: the Inventory's paper
## doll, the piece put on (PIX-336).
func _dress(item_id: String) -> void:
	var holder: Control = card_doll.get_child(0)
	Layout.clear(holder)
	var art := GameState.upkeep.hero_art({String(Catalog.item(item_id).get("slot", "")): item_id})
	var figure := AnimatedSprite2D.new()
	figure.sprite_frames = PunyArt.frames(art)
	figure.self_modulate = art["tint"]
	figure.scale = Vector2(3, 3)
	# The plinth's middle, inside its 6 px rim.
	figure.position = card_doll.custom_minimum_size / 2.0 - Vector2(6, 6)
	figure.play(PunyArt.pick(figure.sprite_frames, "idle", "down"))
	holder.add_child(figure)


## The piece's numbers beside the doll, each against what wearing it would
## take off: a green arrow up, a red one down. Returns the line naming what
## it's set against, and what else the piece says (its stat, its set).
func _numbers(item_id: String, piece: Dictionary) -> String:
	Layout.clear(card_numbers)
	var worn := GameState.trade.worn_against(item_id)
	var mine := Trade.numbers(piece)
	var steps := Trade.compare(piece, worn)
	for key: String in steps:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var value := int(mine.get(key, 0))
		var said := Text.t("Damage %d") % value if key == "damage" else (Text.t("Armor %d") % value if key == "armor" else "+%d %s" % [value, Text.t(Skills.ABBR.get(key, key))])
		line.add_child(UiStyle.label(said, 14, UiStyle.INK))
		var step := int(steps[key])
		if step != 0:
			line.add_child(UiStyle.trend(step > 0))
			line.add_child(UiStyle.label("+%d" % step if step > 0 else str(step), 14, UiStyle.GAIN if step > 0 else UiStyle.LAMP))
		card_numbers.add_child(line)
	var item := Catalog.item(item_id)
	var lines: Array[String] = [Text.t("Worn: %s") % InventoryState.gear_name(worn) if not worn.is_empty() else Text.t("Worn: nothing there")]
	if item.has("damage"):
		lines.append(Text.t("Scales with %s") % Text.t(Skills.ABBR.get(String(item.get("scaling", "strength")), "STR")))
	if item.has("set"):
		lines.append(Catalog.set_line(item["set"], int(GameState.pack.set_counts().get(item["set"], 0))))
	return "\n".join(lines)


## What all the junk is, in a line: "12 × Forest Herb, Rusty Sword".
static func _lot_line(lot: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: String in lot["items"]:
		parts.append(Text.count(int(lot["items"][item_id]), Catalog.item_name(item_id)))
	for uid: String in lot["gear"]:
		parts.append(_gear_label(GameState.pack.gear_by_uid(uid)))
	return ", ".join(parts)


## A price line on the card: its words, then the coin and the sum.
static func _coins(row: HBoxContainer, words: String, sum: int, color: Color) -> void:
	Layout.clear(row)
	var said := UiStyle.label(words, 14, UiStyle.FADED)
	said.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(said)
	row.add_child(UiStyle.purse(sum, 16, color))


func _on_row_input(event: InputEvent, tab_name: String, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# A row of the list beside the chosen one: its tab first.
		if tab_name != tabs[tab]:
			_switch(tabs.find(tab_name))
			_select(index)
		elif event.double_click and index == selected:
			_act()
		else:
			_select(index)


func _act() -> void:
	if rows.is_empty():
		return
	var row := rows[selected]
	# The question answered: as many as asked, or all the junk (PIX-336).
	if amount > 0:
		var item_id: String = row["stack"]
		var sold := amount
		amount = 0
		var gold := GameState.trade.sell_item(item_id, sold)
		status.text = Text.t("Sold %s for %dg.") % [Text.count(sold, Catalog.item_name(item_id)), gold] if gold > 0 else "Not for sale."
		Sound.play("coin")
		_refresh()
		return
	if asking_junk:
		asking_junk = false
		status.text = Text.t("Sold the junk for %dg.") % GameState.trade.sell_junk()
		Sound.play("coin")
		_refresh()
		return
	if not row["enabled"]:
		# A recipe says what it lacks (PIX-234); anything else, only no.
		var why: String = row["why_of"].call() if row.has("why_of") else ""
		status.text = why if why != "" else "Not possible right now."
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
	if gold > 0:
		Sound.play("coin")


## A craft, unless it would take what a taken delivery needs: then it asks
## first, and the same craft again goes ahead (PIX-206).
func _craft(recipe_id: String, entry: Dictionary) -> void:
	var ask := GameState.questing.ask_before_dip("craft:" + recipe_id, entry["needs"])
	if ask != "":
		status.text = ask
		return
	_crafted(GameState.trade.craft(recipe_id), entry)


func _crafted(result: Dictionary, entry: Dictionary) -> void:
	if not result["made"]:
		var why := Economy.craft_refusal(entry, GameState.pack.items, GameState.hero.jobs, GameState.trade.at_station(entry["job"]["id"]), Town.done_projects(GameState.settlement))
		status.text = why if why != "" else "Not possible right now."
		return
	Sound.play("craft")
	if result["count"] > 1:
		status.text = Text.t("A lucky brew: 2x %s! %s") % [Catalog.item_name(entry["itemId"]), result["level_line"]]
	else:
		status.text = Text.t("Made %s. %s") % [Catalog.item_name(entry["itemId"]), result["level_line"]]


func _empty_note(tab_name: String) -> String:
	match tab_name:
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


## Name, flavor and the numbers that matter, for the card at the other tabs.
static func _describe(item_id: String, instance := {}) -> String:
	var item := Catalog.item(item_id)
	var lines: Array[String] = [
		_gear_label(instance) if not instance.is_empty() else String(item["name"]),
		String(item.get("description", "")),
	]
	lines.append_array(_lines(item_id, instance))
	return "\n".join(lines)


## The numbers that matter, a line each.
static func _lines(item_id: String, instance := {}) -> Array[String]:
	var item := Catalog.item(item_id)
	var lines: Array[String] = []
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
		lines.append(Text.t("Restores %d HP") % GameState.upkeep.hp_restore(item))
	if item.has("restoreMp"):
		lines.append(Text.t("Restores %d MP") % item["restoreMp"])
	lines.append(Text.t("Weight %d") % item["weight"])
	return lines


static func _describe_recipe(entry: Dictionary) -> String:
	var lines: Array[String] = [_describe(entry["itemId"]), "", Text.t("Needs:")]
	for need: String in entry["needs"]:
		var have: int = GameState.pack.items.get(need, 0)
		lines.append(Text.t("  %s  (have %d)") % [Text.count(int(entry["needs"][need]), Catalog.item_name(need)), have])
		# Where a missing one comes from (PIX-143).
		if have < int(entry["needs"][need]):
			var sources := Economy.material_sources(need, GameState.town_tier(), GameState.trade.stock_stage())
			if not sources.is_empty():
				lines.append("    " + String(sources[0]["text"]))
	var job: String = entry["job"]["id"]
	lines.append(Text.t("%s level %d - you are %s") % [Economy.job_name(job), entry["job"]["level"], Economy.job_line(GameState.hero.jobs, job)])
	return "\n".join(lines)
