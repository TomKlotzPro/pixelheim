extends GutTest
## PIX-442: the dock says what a skill costs, the tree's cards wear their
## icons, and the stat sheet opens on the stat the weapon in hand scales with.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const HudDockScript := preload("res://scripts/hud_dock.gd")
const StatsScreen := preload("res://scripts/stats_screen.gd")
const SkillsScreen := preload("res://scripts/skills_screen.gd")
const CreateScreen := preload("res://scripts/create_screen.gd")

var _kept: Array = []


## The dock's frames read only this much of the world while the hero's whole.
class StandIn extends Node:
	var player := Hands.new()


class Hands:
	var skill_ready := true
	var SKILL_TURN := 1.0


func _lend(role: String) -> void:
	var lent: Node = autofree(GameStateScript.new())
	lent.new_game("Aldegonde", role)
	GameState.hero = lent.hero
	GameState.pack = lent.pack


func before_each() -> void:
	_kept = [GameState.hero, GameState.pack]


func after_each() -> void:
	GameState.hero = _kept[0]
	GameState.pack = _kept[1]


func _dock() -> Control:
	var dock: Control = HudDockScript.new()
	dock.world = autofree(StandIn.new())
	add_child_autofree(dock)
	return dock


func _words(tag: Panel) -> Label:
	return tag.get_node("words") as Label


func test_a_slot_shows_its_cost_and_goes_red_when_the_hero_cant_pay() -> void:
	_lend("mage")
	var dock := _dock()
	var hero := GameState.hero
	var cost := int(Skills.docked(hero)[0]["mpCost"])
	hero.mp = cost
	dock._process(0.0)
	var tag: Panel = dock.slots[0]["cost"]
	assert_true(tag.visible)
	assert_eq(_words(tag).text, str(cost), "digits alone, so French fits")
	assert_eq(_words(tag).get_theme_color("font_color"), UiStyle.CREAM)
	hero.mp = cost - 1
	dock._process(0.0)
	assert_eq(_words(tag).get_theme_color("font_color"), HudDockScript.BARS["hp"][1], "too dear: red")
	assert_eq(dock.slots[0]["slot"].modulate.a, 1.0, "the slot dims its art, not the cost")
	assert_lt(dock.slots[0]["art"].modulate.a, 1.0)
	assert_false(dock.slots[5]["cost"].visible, "no skill on key 6, no cost")


func test_cant_pay_counts_the_health_a_skill_takes_too() -> void:
	_lend("warrior")
	var hero := GameState.hero
	hero.mp = 50
	hero.hp = 10
	assert_false(Skills.cant_pay(hero, {"mpCost": 50}))
	assert_true(Skills.cant_pay(hero, {"mpCost": 51}))
	assert_true(Skills.cant_pay(hero, {"mpCost": 1, "hpCost": 10}), "it may not kill the hero")
	assert_false(Skills.cant_pay(hero, {"mpCost": 1, "hpCost": 9}))


func test_six_costs_stand_clear_of_the_keys_and_the_icons() -> void:
	_lend("mage")
	var hero := GameState.hero
	for entry: Dictionary in Skills.tree("mage"):
		hero.skill_nodes.append(entry["id"])
	hero.mp = 999
	var docked := Skills.docked(hero).filter(func(skill: Dictionary) -> bool: return not skill.is_empty())
	assert_eq(docked.size(), 6)
	var dock := _dock()
	dock._process(0.0)
	await wait_process_frames(3)
	var seen: Array[Rect2] = []
	for slot: Dictionary in dock.slots:
		var cost := (slot["cost"] as Control).get_global_rect()
		assert_false(cost.intersects((slot["key"] as Control).get_global_rect()), "clear of its key")
		assert_false(cost.intersects((slot["art"] as Control).get_global_rect()), "clear of its icon")
		var outer := (slot["slot"] as Control).get_global_rect()
		assert_true(cost.position.x >= outer.position.x and cost.end.x <= outer.end.x, "inside its own slot's width")
		for other: Rect2 in seen:
			assert_false(cost.intersects(other), "clear of its neighbours")
		seen.append(cost)
	assert_true(dock.plate.get_global_rect().encloses(seen[0]), "on the dock's plate")


func test_the_trees_cards_wear_icons_and_keep_one_edge() -> void:
	_lend("mage")
	var screen: Screen = autofree(SkillsScreen.new())
	for entry: Dictionary in Skills.tree("mage"):
		var card: Control = autofree(screen._node_card(entry, false))
		var room: Control = card.get_child(0).get_child(0)
		assert_eq(room.custom_minimum_size, Vector2(24, 24), "%s: the same room" % entry["id"])
		var art := room.get_child(0) as TextureRect
		if not entry.has("skill"):
			assert_null(art.texture, "%s: no icon to borrow" % entry["id"])
		elif ItemIcons.stat("strength") != null:
			assert_not_null(art.texture, "%s: its own icon" % entry["id"])


## The names the tree's cards cut in this hero's state, each as what it needs
## over what it has. A clipped label reports no overflow, so no fit-* flow or
## test_fit sees this.
func _cut_names(screen: Screen, nodes: Array) -> Array[String]:
	var cards: Array[Control] = []
	for entry: Dictionary in nodes:
		var card: Control = screen._node_card(entry, false)
		add_child_autofree(card)
		cards.append(card)
	await wait_process_frames(2)
	var cut: Array[String] = []
	for card: Control in cards:
		for node: Node in card.get_child(0).get_children():
			if node is Label and node.clip_text:
				var font: Font = node.get_theme_font("font")
				var needs := font.get_string_size(node.text, HORIZONTAL_ALIGNMENT_LEFT, -1, node.get_theme_font_size("font_size")).x
				if needs > node.size.x:
					cut.append("%s %s %s: %d over %d" % [GameState.hero.role_id, TranslationServer.get_locale(), node.text, needs, node.size.x])
	return cut


func test_every_name_on_the_tree_fits_its_card() -> void:
	var screen: Screen = autofree(SkillsScreen.new())
	var cut: Array[String] = []
	for language: String in ["en", "fr"]:
		Text.apply(language)
		for role: String in CreateScreen.ROLES:
			_lend(role)
			var hero := GameState.hero
			var nodes := Skills.tree(role)
			# Not owned: a level away, then in reach (one point, or locked).
			hero.level = 1
			cut.append_array(await _cut_names(screen, nodes))
			hero.level = 99
			hero.skill_points = 9
			cut.append_array(await _cut_names(screen, nodes))
			# Owned: on no key (its kind), then each active on a key.
			for entry: Dictionary in nodes:
				if entry["id"] not in hero.skill_nodes:
					hero.skill_nodes.append(entry["id"])
			hero.skill_dock = [""]
			cut.append_array(await _cut_names(screen, nodes))
			var actives := nodes.filter(func(entry: Dictionary) -> bool: return entry["kind"] == "active")
			hero.skill_dock.assign(actives.map(func(entry: Dictionary) -> String: return entry["id"]))
			for from in range(0, actives.size(), Skills.DOCK_SIZE):
				hero.skill_dock = hero.skill_dock.slice(from) + hero.skill_dock.slice(0, from)
				cut.append_array(await _cut_names(screen, actives.slice(from, from + Skills.DOCK_SIZE)))
	Text.apply("en")
	assert_eq(cut.size(), 0, "\n".join(cut))


func _sheet() -> Screen:
	var screen: Screen = StatsScreen.new()
	add_child_autofree(screen)
	await wait_process_frames(2)
	return screen


func test_the_sheet_opens_on_the_stat_the_weapon_scales_with() -> void:
	_lend("mage")
	var screen: Screen = await _sheet()
	assert_eq(Skills.STATS[screen.selected], "intelligence", "a mage's staff")
	assert_eq(screen.rows[screen.selected]["tag"], Text.t("Weapon"))
	assert_eq(screen.rows.filter(func(row: Dictionary) -> bool: return row.get("tag", "") != "").size(), 1, "one row marked")


func test_it_follows_the_weapon_not_the_role() -> void:
	_lend("mage")
	var pack := GameState.pack
	var sword: String = HeroRules.weapon(pack)["uid"]
	pack.gear_by_uid(sword)["itemId"] = "rusty_sword"
	assert_eq(Catalog.item("rusty_sword")["scaling"], "strength")
	var screen: Screen = await _sheet()
	assert_eq(Skills.STATS[screen.selected], "strength", "a mage holding a sword")
	assert_eq(screen.rows[screen.selected]["tag"], Text.t("Weapon"))


func test_bare_hands_open_on_strength_with_no_tag() -> void:
	_lend("ranger")
	GameState.pack.equipped.erase("weapon")
	var screen: Screen = await _sheet()
	assert_eq(Skills.STATS[screen.selected], "strength")
	assert_false(screen.rows.any(func(row: Dictionary) -> bool: return row.get("tag", "") != ""), "no weapon to name")


## Large text keeps who the hero is above the chosen stat's words, the
## longest name a hero can have, every role and stat, and still fits.
func test_large_text_keeps_the_heros_line_and_fits() -> void:
	var before: bool = GameState.settings.large_text
	GameState.settings.large_text = true
	var out: Array[String] = []
	var view := SubViewport.new()
	view.size = Vector2i(1280, 720)
	view.disable_3d = true
	add_child_autofree(view)
	for language: String in ["en", "fr"]:
		Text.apply(language)
		for role: String in CreateScreen.ROLES:
			_lend(role)
			GameState.hero.hero_name = "M".repeat(16)
			var screen: Screen = StatsScreen.new()
			view.add_child(screen)
			for index in Skills.STATS.size():
				screen.selected = index
				screen._refresh()
				await wait_process_frames(2)
				assert_string_contains(screen.info.text, GameState.hero.hero_name)
				for line in Layout.overflows(view, Vector2(view.size)):
					out.append("%s %s %s: %s" % [language, role, Skills.STATS[index], line])
			screen.close()
			await get_tree().process_frame
	Text.apply("en")
	GameState.settings.large_text = before
	assert_eq(out.size(), 0, "\n".join(out))


func test_every_stat_row_has_its_icon() -> void:
	if ItemIcons.stat("strength") == null:
		pass_test("no paid art here")
		return
	_lend("warrior")
	var screen: Screen = await _sheet()
	for index in Skills.STATS.size():
		assert_not_null(screen.rows[index]["icon"], Skills.STATS[index])
