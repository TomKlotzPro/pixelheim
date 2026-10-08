extends Screen
## The skill tree (SkillTree.tsx): once the hero has ranked, the Path Graph on
## top (six identities, walked edges lit, a pending step to claim), then the
## role's three branches of four tiers. Arrows move across the grid, E learns
## a node or walks a path, K or Esc closes. The world holds still meanwhile.

const KIND_LABELS := {"active": "SKILL", "upgrade": "UPGRADE", "passive": "PASSIVE"}
const TIER_BADGES := ["I", "II", "III", "CAP"]
const COLUMN_X := [80, 470, 860]
const PATH_CARD := Vector2(340, 56)
const NODE_CARD := Vector2(340, 78)

## Grid cell -> {kind: "path"|"node", entry}; cells (col, row): the path
## graph on rows 0-1 (branch a, b), the tree's tiers on rows 2-5.
var cells := {}
var selected := Vector2i(0, 2)
var view: Control
var details: Label
var status: Label
## F asked once: a second F forgets (any other key thinks better of it).
var forget_armed := false


func _open() -> void:
	closing_actions = [&"skills"]
	layer = 5
	dim()
	# The paths are written on one page; the details read below it.
	add_child(UiStyle.page(Rect2(60, 60, 1160, 562)))
	view = Control.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	details = UiStyle.label("", 13, UiStyle.CREAM, Vector2(80, 632))
	details.custom_minimum_size = Vector2(1120, 0)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(details)
	status = UiStyle.label("", 14, UiStyle.GOLD, Vector2(260, 30))
	status.custom_minimum_size = Vector2(720, 0)
	add_child(status)
	add_child(UiStyle.footer("Arrows  choose      E  learn / walk      F  forget      K / Esc  close", Vector2(80, 672)))
	var rule := UiStyle.label("A point each level, one more each rank.", 13, UiStyle.DUSK, Vector2(800, 678))
	rule.custom_minimum_size = Vector2(416, 0)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(rule)
	# Start on the first pending path step, else the first learnable node.
	_layout()
	for cell: Vector2i in cells:
		if _claimable(cells[cell]):
			selected = cell
			break
	if not _claimable(cells.get(selected, {})):
		for cell: Vector2i in cells:
			if cells[cell]["kind"] == "node" and Skills.can_buy(GameState.hero, cells[cell]["entry"]):
				selected = cell
				break
	_layout()


func _layout() -> void:
	for child in view.get_children():
		child.queue_free()
	cells = {}
	var hero := GameState.hero
	view.add_child(UiStyle.heading("Skills", 20, UiStyle.CREAM, Vector2(80, 24)))
	var points := hero.skill_points
	view.add_child(UiStyle.label(
		"%d skill point%s" % [points, "" if points == 1 else "s"], 18, UiStyle.GOLD if points > 0 else UiStyle.DUSK,
		Vector2(1000, 30)
	))
	var top := 80
	if HeroRules.rank_index(hero.level) >= 1:
		_path_graph(hero)
		top = 262
	var tree := Skills.tree(hero.role_id)
	for branch in 3:
		var nodes := tree.filter(func(entry: Dictionary) -> bool: return int(entry["branch"]) == branch)
		nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["tier"] < b["tier"])
		var root: Dictionary = nodes[0]
		var head: String = root["skill"]["name"] if root.has("skill") else root["name"]
		view.add_child(UiStyle.label("Path of %s" % head, 16, UiStyle.LAMP, Vector2(COLUMN_X[branch], top)))
		for entry: Dictionary in nodes:
			var cell := Vector2i(branch, 2 + int(entry["tier"]))
			cells[cell] = {"kind": "node", "entry": entry}
			var card := _node_card(entry, cell == selected)
			card.position = Vector2(COLUMN_X[branch], top + 26 + int(entry["tier"]) * (NODE_CARD.y + 5))
			view.add_child(card)
	_describe()


## The six identities: columns are ranks, edges are the ascensions allowed.
func _path_graph(hero: HeroState) -> void:
	var pending := Ranks.pending_tier(hero)
	var walked := HeroRules.walked(hero)
	var nodes: Array = Bestiary._data()["pathNodes"].filter(
		func(node: Dictionary) -> bool: return node["roleId"] == hero.role_id
	)
	view.add_child(UiStyle.label(
		"Your ascension demands a path" if pending > 0 else "The Path Graph", 16, UiStyle.LAMP, Vector2(80, 70)
	))
	if not walked.is_empty():
		var identity := HeroRules.path_node(walked[-1])
		view.add_child(UiStyle.label("%s - %s" % [identity["name"], identity["blurb"]], 13, UiStyle.FADED, Vector2(380, 72)))
	var at := func(node: Dictionary) -> Vector2:
		return Vector2(COLUMN_X[int(node["tier"]) - 1], 100 + (0 if node["branch"] == "a" else PATH_CARD.y + 18))
	for node: Dictionary in nodes:
		for from_id: String in node["from"]:
			var from := HeroRules.path_node(from_id)
			var line := Line2D.new()
			line.width = 2
			var lit: bool = from_id in walked and node["id"] in walked and walked.find(node["id"]) == walked.find(from_id) + 1
			line.default_color = UiStyle.LAMP if lit else Color(UiStyle.RIM, 0.9)
			line.add_point(at.call(from) + Vector2(PATH_CARD.x, PATH_CARD.y / 2))
			line.add_point(at.call(node) + Vector2(0, PATH_CARD.y / 2))
			view.add_child(line)
	for node: Dictionary in nodes:
		var cell := Vector2i(int(node["tier"]) - 1, 0 if node["branch"] == "a" else 1)
		cells[cell] = {"kind": "path", "entry": node}
		var card := _path_card(node, walked, cell == selected)
		card.position = at.call(node)
		view.add_child(card)


func _path_card(node: Dictionary, walked: Array, chosen: bool) -> Control:
	var current: bool = not walked.is_empty() and walked[-1] == node["id"]
	var state := "Current" if current else ("Walked" if node["id"] in walked else ("Walk this path" if _claimable({"kind": "path", "entry": node}) else "Rank %d" % node["tier"]))
	var lit: bool = current or node["id"] in walked or state == "Walk this path"
	var panel := _panel(PATH_CARD, chosen, lit)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	panel.add_child(lines)
	var head := HBoxContainer.new()
	var name := UiStyle.label(node["name"], 15, UiStyle.LAMP if current else (UiStyle.INK if lit else UiStyle.FADED))
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiStyle.label(TIER_BADGES[int(node["tier"]) - 1], 13, UiStyle.FADED))
	lines.add_child(head)
	lines.add_child(UiStyle.label(state, 12, UiStyle.LAMP if state == "Walk this path" else UiStyle.FADED))
	return panel


func _node_card(entry: Dictionary, chosen: bool) -> Control:
	var hero := GameState.hero
	var owned: bool = entry["id"] in hero.skill_nodes
	var buyable := Skills.can_buy(hero, entry)
	var panel := _panel(NODE_CARD, chosen, owned or buyable)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 2)
	panel.add_child(lines)
	var head := HBoxContainer.new()
	var name := UiStyle.label(
		"%s  %s" % [TIER_BADGES[int(entry["tier"])], entry["name"]], 15,
		UiStyle.LAMP if owned else (UiStyle.INK if buyable else UiStyle.FADED)
	)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name)
	head.add_child(UiStyle.label(KIND_LABELS[entry["kind"]], 11, UiStyle.FADED))
	lines.add_child(head)
	var numbers := _numbers(entry)
	if numbers != "":
		lines.add_child(UiStyle.label(numbers, 12, UiStyle.INK if owned or buyable else UiStyle.FADED))
	var state := "OWNED" if owned else ("Learn (1 pt)" if buyable else (
		"Requires the skill above" if entry.has("requires") and entry["requires"] not in hero.skill_nodes else "No points"
	))
	lines.add_child(UiStyle.label(state, 12, UiStyle.LAMP if owned or buyable else UiStyle.FADED))
	return panel


## A skill's cost and punch, as the web prints it.
func _numbers(entry: Dictionary) -> String:
	if not entry.has("skill"):
		return ""
	var skill: Dictionary = entry["skill"]
	var verb := "damage" if skill["kind"] == "damage" else ("healing" if skill["kind"] == "heal" else "")
	if verb == "":
		return ""
	var cost := "%s %s" % [skill["mpCost"], Skills.resource_label(GameState.hero.role_id)]
	if skill.get("hpCost", 0) > 0:
		cost += " + %d HP" % skill["hpCost"]
	return "%sx %s %s · %s" % [skill["multiplier"], Skills.ABBR.get(skill["stat"], skill["stat"]), verb, cost]


func _panel(size: Vector2, chosen: bool, lit: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = size
	panel.size = size
	var fill := UiStyle.CARD if lit else Color(UiStyle.CARD, 0.55)
	panel.add_theme_stylebox_override("panel", UiStyle.box(fill, UiStyle.LAMP if chosen else UiStyle.RIM, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel


func _claimable(cell: Dictionary) -> bool:
	if cell.is_empty() or cell["kind"] != "path":
		return false
	return Ranks.path_choices(GameState.hero).any(func(node: Dictionary) -> bool: return node["id"] == cell["entry"]["id"])


## The selected card in full at the foot of the screen.
func _describe() -> void:
	var cell: Dictionary = cells.get(selected, {})
	if cell.is_empty():
		details.text = ""
		return
	var entry: Dictionary = cell["entry"]
	if cell["kind"] == "path":
		details.text = "%s: %s  Signature: %s - %s" % [entry["name"], entry["blurb"], entry["signature"]["name"], entry["signature"]["description"]]
	else:
		details.text = "%s: %s" % [entry["name"], entry["description"]]


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	if event.is_action_pressed("move_up"):
		command = _move.bind(Vector2i.UP)
	elif event.is_action_pressed("move_down"):
		command = _move.bind(Vector2i.DOWN)
	elif event.is_action_pressed("move_left"):
		command = _move.bind(Vector2i.LEFT)
	elif event.is_action_pressed("move_right"):
		command = _move.bind(Vector2i.RIGHT)
	elif event.is_action_pressed("interact"):
		command = _act
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		command = _forget
	if command.is_valid() and command != _forget:
		forget_armed = false
	return command


## F: forget every bought skill for its point back (PIX-86), in the village and
## for gold; it asks first, and a second F agrees.
func _forget() -> void:
	var hero := GameState.hero
	var count := Skills.forgettable(hero).size()
	var cost := Skills.forget_cost(hero)
	var armed := false
	if count == 0:
		status.text = "Nothing learned to forget yet."
	elif not Skills.can_forget_at(GameState.world.map_id):
		status.text = "Forgetting takes the village's quiet. Come back to Pixelheim."
	elif GameState.pack.gold < cost:
		status.text = "Forgetting %s costs %dg." % [_skills(count), cost]
	elif not forget_armed:
		armed = true
		status.text = "Forget %s for %dg and get the points back? F again to agree." % [_skills(count), cost]
	elif GameState.forget_skills():
		Sound.play("learn")
		status.text = "Forgotten. %s to spend again." % ("1 point" if count == 1 else "%d points" % count)
		_layout()
	forget_armed = armed


func _skills(count: int) -> String:
	return "1 skill" if count == 1 else "%d skills" % count


## To the next card that way: same column first, else the nearest one.
func _move(step: Vector2i) -> void:
	var probe := selected + step
	for i in 6:
		if cells.has(probe):
			selected = probe
			break
		if step.y != 0:
			probe += step
			continue
		# Sideways onto a shorter column: the nearest row there.
		var best := Vector2i(-1, -1)
		for cell: Vector2i in cells:
			if cell.x == probe.x and (best.x < 0 or absi(cell.y - selected.y) < absi(best.y - selected.y)):
				best = cell
		if best.x >= 0:
			selected = best
		break
	status.text = ""
	_layout()


func _act() -> void:
	var cell: Dictionary = cells.get(selected, {})
	if cell.is_empty():
		return
	var entry: Dictionary = cell["entry"]
	if cell["kind"] == "path":
		if GameState.choose_path(entry["id"]):
			Sound.play("learn")
			status.text = "You walk the path of the %s." % entry["name"]
		else:
			status.text = "That path isn't yours to walk now."
	elif GameState.buy_skill_node(entry["id"]):
		Sound.play("learn")
		status.text = "Learned: %s." % entry["name"]
	elif entry["id"] in GameState.hero.skill_nodes:
		status.text = "Already learned."
	else:
		status.text = "Requires the skill above." if entry.has("requires") and entry["requires"] not in GameState.hero.skill_nodes else "No skill points to spend."
	_layout()
