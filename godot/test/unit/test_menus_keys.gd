extends GutTest
## The menus' keys do what their footers say (PIX-484, PIX-487): a footer
## names only the keys that act where the choice stands (the counter while
## it asks how many, the pack's Craft tab, a save's slot by what it holds,
## the stats with or without points, each of Options' rows); E on another
## hero's slot from the title plays them at once; on a key's row in Options
## left and right cross to the other column and only E arms a rebind, and E
## leaves a volume alone; Large reading text grows every reading text; and
## a pad's right stick pages a card that runs long, the footer in its caps.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const DIR := "user://test_menus_keys"

var _lent: Node
var _kept := {}
var _screen: Screen


## Saves that say when they would start the world over, and don't.
class QuietSaves extends "res://scripts/saves_screen.gd":
	var reloaded := false

	func reload_world() -> void:
		reloaded = true


func before_each() -> void:
	Controls.apply({})
	Text.apply("en")
	var settings := GameState.settings
	_kept = {
		"hero": GameState.hero, "pack": GameState.pack, "settlement": GameState.settlement,
		"progression": GameState.progression, "dirty": GameState.dirty, "slots": GameState.slots,
		"slot": GameState.slot, "standing_in": GameState.standing_in, "title_seen": GameState.title_seen,
		"stall": GameState.trade.stall_shop, "large": settings.large_text, "read_only": settings.read_only,
		"music": settings.music_volume, "bindings": settings.bindings, "reduce_motion": settings.reduce_motion,
	}
	settings.read_only = true
	# Laid out where they settle, not 10 px down mid-entrance.
	settings.reduce_motion = true
	_lent = GameStateScript.new()
	_lent.new_game("Robin", "warrior")
	GameState.hero = _lent.hero
	GameState.pack = _lent.pack
	GameState.settlement = _lent.settlement
	GameState.progression = _lent.progression


func after_each() -> void:
	if is_instance_valid(_screen):
		_screen.close()
	_screen = null
	for key: String in ["hero", "pack", "settlement", "progression", "slots", "slot", "standing_in", "title_seen"]:
		GameState.set(key, _kept[key])
	GameState.dirty = _kept["dirty"]
	GameState.trade.stall_shop = _kept["stall"]
	var settings := GameState.settings
	settings.large_text = _kept["large"]
	settings.music_volume = _kept["music"]
	settings.bindings = _kept["bindings"]
	settings.reduce_motion = _kept["reduce_motion"]
	settings.read_only = _kept["read_only"]
	Controls.apply(settings.bindings)
	Controls.pad = false
	Controls._page_held = 0
	_lent.free()
	if DirAccess.dir_exists_absolute(DIR):
		for file in DirAccess.get_files_at(DIR):
			DirAccess.remove_absolute("%s/%s" % [DIR, file])
		DirAccess.remove_absolute(DIR)
	await get_tree().process_frame
	get_tree().paused = false


func _open(screen: Screen) -> Screen:
	if is_instance_valid(_screen):
		_screen.close()
	_screen = screen
	add_child(screen)
	return screen


## What a footer says: its caps and its words, in order.
func _says(footer: Node) -> Array:
	return footer.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event


## The pad's right stick at `value` (1 down, -1 up, 0 let go).
func _stick(value: float) -> InputEventJoypadMotion:
	var push := InputEventJoypadMotion.new()
	push.axis = JOY_AXIS_RIGHT_Y
	push.axis_value = value
	return push


func _counter(tab: String) -> ShopScreen:
	GameState.trade.stall_shop = Economy.shop_at("town_shop")
	GameState.pack.items.merge({"forest_herb": 10})
	var counter := ShopScreen.new()
	counter.start_tab = tab
	_open(counter)
	return counter


# ---- PIX-487: a pad pages a card ------------------------------------------------

func test_the_right_stick_pages_once_a_push() -> void:
	assert_eq(Controls.paged(_stick(1.0)), 1, "pushed down: a page on")
	assert_eq(Controls.paged(_stick(0.9)), 0, "still held: no second page")
	assert_eq(Controls.paged(_stick(0.0)), 0, "let go")
	assert_eq(Controls.paged(_stick(-1.0)), -1, "pushed up: a page back")
	assert_eq(Controls.paged(_stick(0.2)), 0, "its drift is no push")
	Controls._page_held = 0
	assert_eq(Controls.paged(_stick(0.55)), 1, "a slow push, just past the mark")
	assert_eq(Controls.paged(_stick(0.45)), 0, "trembling back under it")
	assert_eq(Controls.paged(_stick(0.55)), 0, "and over again: still the one push")
	assert_eq(Controls.paged(_stick(0.2)), 0, "let go, lower than it was pushed")
	assert_eq(Controls.paged(_stick(0.55)), 1, "the next push pages")
	assert_eq(Controls.paged(_stick(-0.4)), 0, "half back the other way lets it go")
	assert_eq(Controls.paged(_stick(0.4)), 0, "and half a push is none")
	assert_eq(Controls.paged(_stick(0.8)), 1)
	var left := _stick(1.0)
	left.axis = JOY_AXIS_LEFT_Y
	assert_eq(Controls.paged(left), 0, "the left stick is the rows'")
	var key := InputEventKey.new()
	key.keycode = KEY_PAGEDOWN
	key.pressed = true
	assert_eq(Controls.paged(key), 1, "Page Down as ever")


func test_a_stick_let_go_in_the_world_is_let_go_at_the_next_screen() -> void:
	assert_eq(Controls.paged(_stick(1.0)), 1, "a page, and the screen closes on the push")
	# No screen reads the stick now: the game's own ear hears it let go.
	Controls.note_device(_stick(0.0))
	assert_eq(Controls.paged(_stick(1.0)), 1, "the next screen's first push pages")
	Controls.note_device(_stick(0.9))
	assert_eq(Controls.paged(_stick(1.0)), 0, "held is still held")
	var left := _stick(0.0)
	left.axis = JOY_AXIS_LEFT_Y
	Controls.note_device(left)
	assert_eq(Controls.paged(_stick(1.0)), 0, "and the left stick at rest lets nothing go")


func test_a_long_card_pages_by_the_stick_and_the_footer_wears_the_hands_caps() -> void:
	GameState.settings.large_text = true
	GameState.hero.stat_points = 0
	var stats := _open(StatsScreen.new()) as StatsScreen
	# A card of the big type that surely runs past its window.
	stats.info.text = "\n".join(range(40).map(func(line: int) -> String: return "Line %d" % line))
	await wait_process_frames(3)
	assert_true(Layout.runs_long(stats.info_scroll))
	assert_has(_says(stats.keys), "PgDn", "the keyboard's caps first")
	Controls.note_device(_stick(1.0))
	stats._unhandled_input(_stick(1.0))
	assert_gt(stats.info_scroll.scroll_vertical, 0, "the stick pushed down pages the card")
	var caps := _says(stats.keys)
	assert_has(caps, "R↓", "and the footer names the pad's")
	assert_does_not_have(caps, "PgDn", "with no keyboard cap for paging")
	assert_does_not_have(caps, "PgUp")
	var key := InputEventKey.new()
	key.keycode = KEY_PAGEUP
	key.pressed = true
	Controls.note_device(key)
	stats._unhandled_input(key)
	assert_eq(stats.info_scroll.scroll_vertical, 0, "Page Up brings it back")
	assert_has(_says(stats.keys), "PgUp", "and the keyboard's caps with it")


# ---- PIX-484: Large reading text grows every reading text ---------------------------

func test_large_reading_text_grows_every_reading_text() -> void:
	GameState.settings.large_text = true
	var counter := _counter("Buy")
	for label: Label in [counter.detail, counter.card_extra]:
		assert_eq(label.get_theme_font_size("font_size"), UiStyle.BIG, "the counter's card, every line of it")
	counter.close()
	var pack := _open(InventoryScreen.new()) as InventoryScreen
	assert_eq(pack.about.get_theme_font_size("font_size"), UiStyle.BIG, "the pack's description")
	assert_lt(pack.scroll.size.y, InventoryScreen.LIST.y, "its list gives it the room")
	pack.close()
	GameState.progression.quests.merge({"slime_trouble": {"progress": 2, "done": false}})
	var journal := _open(JournalScreen.new()) as JournalScreen
	assert_eq(journal.detail.get_theme_font_size("font_size"), UiStyle.BIG, "the journal's quest text")
	journal.close()
	# A hero of the second rank: the path graph over the tree, the tallest page.
	GameState.hero.level = 10
	var skills := _open(SkillsScreen.new()) as SkillsScreen
	assert_eq(skills.details.get_theme_font_size("font_size"), UiStyle.BIG, "the Skills description")
	assert_eq(skills.reader.size.y, 2.0 * Layout.line_of(skills.reader), "two lines of it")
	for card: Node in skills.view.get_children():
		if card is PanelContainer:
			assert_lte(card.position.y + card.size.y, skills.reader.position.y, "under the tree's last row, not on it")
	assert_almost_eq(skills.reader.position.y + skills.reader.size.y, SkillsScreen.PAGE.end.y - UiStyle.INSET, 1.0, "its last line on the page's inset")


func test_a_description_keeps_its_window_and_pages_past_it() -> void:
	var label := UiStyle.label("", 14, UiStyle.INK)
	var reader := Layout.reader(label, 300.0)
	add_child_autofree(reader)
	Layout.read(reader, "One line.", 3)
	var line := reader.custom_minimum_size.y
	assert_gt(line, 0.0)
	Layout.read(reader, "", 3)
	assert_eq(reader.custom_minimum_size.y, 0.0, "no words, no room")
	Layout.read(reader, "", 3, 2)
	assert_eq(reader.custom_minimum_size.y, 2 * line, "or the least it keeps, where the page mustn't move")
	Layout.read(reader, " ".join(range(200).map(func(_at: int) -> String: return "words")), 3)
	assert_eq(reader.custom_minimum_size.y, 3 * line, "never more than its most")
	await wait_process_frames(3)
	assert_true(Layout.runs_long(reader), "the rest pages")
	assert_lt(label.size.x, 300.0, "beside its scrollbar")


# ---- PIX-484: footers name only the keys that act ----------------------------------

func test_the_counters_footer_is_the_questions_while_it_asks_how_many() -> void:
	var counter := _counter("Sell")
	counter._select(counter.rows.find_custom(func(row: Dictionary) -> bool: return row.get("stack", "") == "forest_herb"))
	var before := _says(counter.footer)
	assert_has(before, "sell a stack", "Z on a stack")
	assert_has(before, "tab")
	counter._ask(10)
	var asking := _says(counter.footer)
	for word: String in ["how many", "all", "sell", "keep"]:
		assert_has(asking, word)
	for word: String in ["tab", "choose", "sell a stack", "close"]:
		assert_does_not_have(asking, word, "nothing the question doesn't take")
	counter._cancel()
	assert_has(_says(counter.footer), "close", "put down, the counter's keys again")
	counter.switch(0)
	assert_does_not_have(_says(counter.footer), "sell a stack", "no Z where nothing sells")


## PIX-570: a sale shelves a buy-back row at the top of Buy, and the tab
## came back on the place its choice had stood at, now another thing's: with
## the deed chosen, one sale lit the rug above it, and the next E bought
## the rug. The thing chosen is kept, and E buys it.
func test_after_a_sale_e_buys_the_row_left_chosen() -> void:
	var counter := _counter("Buy")
	GameState.pack.gold = 500
	counter._select(3)
	var chosen: Dictionary = counter.rows[3]
	counter.switch(1)
	counter._select(counter.rows.find_custom(func(row: Dictionary) -> bool: return row.get("stack", "") == "forest_herb"))
	counter._ask(3)
	counter._command(_action("interact")).call()
	assert_eq(GameState.trade.sold_here.size(), 1, "three herbs sold, on the shelf")
	counter.switch(0)
	assert_eq(counter.rows[0]["tag"], "sold", "the buy-back row over the goods")
	assert_eq(counter.selected, 4, "a row down, with the thing")
	assert_eq(counter.rows[counter.selected]["key"], chosen["key"], "the thing chosen before the sale")
	var lit: Array = counter.lists[0].get_children().filter(func(row: PanelContainer) -> bool:
		return (row.get_theme_stylebox("panel") as StyleBoxTexture).texture == (UiStyle.box(UiStyle.CARD, UiStyle.LAMP, 8) as StyleBoxTexture).texture)
	assert_eq(lit, [counter.lists[0].get_child(4)], "and it is the row drawn chosen")
	var gold := GameState.pack.gold
	counter._command(_action("interact")).call()
	assert_eq(GameState.pack.gold, gold - int(chosen["cost"]), "E buys it, at its price")
	assert_eq(counter.status.text, "Bought %s." % chosen["label"])
	assert_eq(counter.rows[counter.selected]["key"], chosen["key"], "still chosen after")


## PIX-570: the choice is the thing on every tab, across A/D and through a
## list that changes under it. Selling the last junk of a stack takes the
## "Sell all junk" row from over it: the stack stays chosen (the place
## alone chose the thing under it, which the next E sold). Once the thing
## is gone, the place it stood at.
func test_the_chosen_thing_is_kept_across_tabs_and_a_changed_list() -> void:
	var counter := _counter("Sell")
	var herbs := func() -> int: return counter.rows.find_custom(func(row: Dictionary) -> bool: return row.get("stack", "") == "forest_herb")
	assert_eq(counter.rows[0]["key"], "junk", "four herbs past what crafting keeps")
	var at: int = herbs.call()
	counter._select(at)
	counter._ask(4)
	counter._act()
	assert_ne(counter.rows[0]["key"], "junk", "the lot's row gone")
	assert_eq(herbs.call(), at - 1, "the herbs a row up")
	assert_eq(counter.selected, at - 1, "and chosen still")
	counter.switch(0)
	counter._select(2)
	var ware: String = counter.rows[2]["key"]
	counter.switch(1)
	assert_eq(counter.rows[counter.selected].get("stack", ""), "forest_herb", "Sell kept its own across A/D")
	counter.switch(0)
	assert_eq(counter.rows[counter.selected]["key"], ware, "and Buy its own")
	counter.switch(1)
	counter._ask(6)
	counter._act()
	assert_eq(herbs.call(), -1, "the last herbs sold")
	assert_eq(counter.selected, mini(at - 1, counter.rows.size() - 1), "the place, once the thing is gone")


func test_the_packs_craft_tab_offers_what_a_recipe_takes() -> void:
	var pack := InventoryScreen.new()
	pack.tab = InventoryScreen.TABS.size() - 1
	_open(pack)
	assert_eq(String(InventoryScreen.TABS[pack.tab][0]), "craft")
	for word: String in ["equip / use", "drop", "drop all", "sort", "travel"]:
		assert_does_not_have(_says(pack.footer), word, "the guide, in town: nothing for E, X, Z or R")
	pack._select(1)
	var recipe := _says(pack.footer)
	assert_eq(pack._primary_label(pack.rows[1]), "", "away from its station the row offers no E")
	assert_does_not_have(recipe, "craft", "nor does the footer: E only says where it's made")
	assert_does_not_have(recipe, "equip / use")
	assert_does_not_have(recipe, "drop")
	# At the house's workbench, with what the first recipe takes.
	var map_id := GameState.world.map_id
	GameState.world.map_id = "town_house"
	GameState.settlement.house["workbench"] = true
	pack._refresh()
	var at: int = pack.rows.find_custom(func(row: Dictionary) -> bool:
		return row["kind"] == "recipe" and int(row["entry"]["job"]["level"]) <= int(GameState.hero.jobs[row["entry"]["job"]["id"]]["level"]))
	assert_gt(at, 0, "a recipe of a trade's first level")
	GameState.pack.items.merge(pack.rows[at]["entry"]["needs"], true)
	pack._select(at)
	assert_ne(pack._primary_label(pack.rows[at]), "", "there the row says E crafts")
	assert_has(_says(pack.footer), "craft", "and so does the footer")
	GameState.world.map_id = map_id
	pack._switch(0)
	# Laid out: the description's window knows whether its words run long.
	await wait_process_frames(3)
	for word: String in ["equip / use", "drop", "drop all", "sort"]:
		assert_has(_says(pack.footer), word, "the pack's own keys on what it holds")


func test_the_pack_gives_sorts_place_to_the_page_keys() -> void:
	GameState.settings.large_text = true
	var pack := _open(InventoryScreen.new()) as InventoryScreen
	await wait_process_frames(3)
	assert_has(_says(pack.footer), "sort")
	Layout.read(pack.reader, " ".join(range(200).map(func(_at: int) -> String: return "words")), 3)
	await wait_process_frames(3)
	assert_true(Layout.runs_long(pack.reader), "a description past three lines of the big type")
	var paged := _says(pack.footer)
	assert_has(paged, "read", "the page keys")
	assert_does_not_have(paged, "sort", "in the place of R's sort, not on top of the pack's eight")
	assert_has(paged, "drop all", "every key of the row still")
	assert_lte(pack.footer.get_combined_minimum_size().x, 1280.0, "and the line needs no closing up")
	assert_eq(Layout.footer_for(pack.reader, "A  one      B  two"), Layout.paged_footer("A  one      B  two"), "a screen with no shorter line keeps its own")


func test_a_footer_closed_up_stands_in_the_canvas() -> void:
	# The first line of short hints too wide for the canvas: by less than
	# closing up its many gaps wins back.
	var row: HBoxContainer
	for hints in range(8, 60):
		row = UiStyle.screen_footer("      ".join(range(hints).map(func(_at: int) -> String: return "K  go")))
		if row.get_combined_minimum_size().x > 1280.0:
			break
		row.free()
	add_child_autofree(row)
	assert_gt(row.get_combined_minimum_size().x, 1280.0)
	await wait_process_frames(3)
	assert_lte(row.get_combined_minimum_size().x, 1280.0, "closed up, its words fit")
	assert_eq(row.size.x, 1280.0, "and it is the canvas's width again, its words about the middle")


func test_the_skills_footer_names_the_keys_the_card_takes() -> void:
	var hero := GameState.hero
	hero.skill_points = 1
	var skills := _open(SkillsScreen.new()) as SkillsScreen
	var first: Vector2i = skills.cells.keys().filter(func(cell: Vector2i) -> bool: return Skills.can_buy(hero, skills.cells[cell]["entry"]))[0]
	skills.selected = first
	skills._layout()
	var open := _says(skills.footer)
	assert_has(open, "learn", "E on a skill a point can buy")
	assert_does_not_have(open, "set key", "no key takes a skill not yet known")
	assert_has(open, "forget")
	assert_true(GameState.training.buy_skill_node(skills.cells[first]["entry"]["id"]))
	skills._layout()
	var known := _says(skills.footer)
	assert_does_not_have(known, "learn", "learned: E has nothing more to do")
	assert_eq("set key" in known, skills.cells[first]["entry"]["kind"] == "active", "1-6 on a skill that is cast")
	assert_does_not_have(known, "walk")


func test_the_stats_footer_counts_the_points_and_drops_e_with_none() -> void:
	GameState.hero.stat_points = 3
	var stats := _open(StatsScreen.new()) as StatsScreen
	assert_has(_says(stats.keys), "spend a point (3 left)")
	assert_does_not_have(_says(stats.keys), "do it")
	assert_string_contains(stats.intro.text, "3 stat points to spend")
	stats._act()
	assert_has(_says(stats.keys), "spend a point (2 left)", "counted down as they go")
	# PIX-542: the header under the title counts down with them.
	assert_string_contains(stats.intro.text, "2 stat points to spend")
	GameState.hero.stat_points = 0
	stats._refresh()
	assert_string_contains(stats.intro.text, "Every level brings")
	var none := _says(stats.keys)
	assert_does_not_have(none, Controls.say("{key:interact}"), "no E with nothing to spend")
	assert_has(none, "close")


func test_the_weapon_tag_is_ink_on_the_page_and_whole() -> void:
	var stats := _open(StatsScreen.new()) as StatsScreen
	await wait_process_frames(3)
	var tags: Array = stats.list.find_children("*", "Label", true, false).filter(func(label: Label) -> bool: return label.text == "Weapon")
	assert_eq(tags.size(), 1, "the stat the weapon in hand asks for")
	var tag: Label = tags[0]
	assert_eq(tag.get_theme_color("font_color"), UiStyle.FADED, "the page's own ink, no dark chip")
	assert_false(tag.get_parent() is Panel)
	assert_gte(tag.size.x, Layout.words_width(tag), "every letter of it")


func test_a_saves_footer_follows_what_the_slot_holds() -> void:
	GameState.slots = SaveSlots.new(DIR)
	GameState.slot = GameState.NO_SLOT
	var game: Node = autofree(GameStateScript.new())
	game.new_game("Hrafna", "ranger")
	GameState.slots.write(1, game.to_dict())
	GameState.slots.write(2, game.to_dict())
	var saves := _open(SavesScreen.new()) as SavesScreen
	saves._select(0)
	for word: String in ["continue", "duplicate", "delete", "copy", "paste"]:
		assert_has(_says(saves.footer), word, "a hero's slot")
	saves._select(2)
	var empty := _says(saves.footer)
	assert_has(empty, "paste", "an empty slot takes a code")
	for word: String in ["continue", "duplicate", "delete", "copy", "bring back"]:
		assert_does_not_have(empty, word, "and nothing else")
	saves._select(1)
	saves._delete()
	saves._delete()
	var deleted := _says(saves.footer)
	assert_has(deleted, "bring back", "R, while the deleted hero waits")
	assert_has(deleted, "R")
	saves._restore()
	assert_has(_says(saves.footer), "continue", "back, a hero's keys again")


func test_from_the_title_the_last_hero_is_last_played_and_e_on_another_plays_at_once() -> void:
	GameState.slots = SaveSlots.new(DIR)
	var mine: Dictionary = GameState.to_dict()
	var game: Node = autofree(GameStateScript.new())
	game.new_game("Tes", "ranger")
	GameState.slots.write(1, mine)
	GameState.slots.write(2, game.to_dict())
	GameState.slot = 1
	GameState.standing_in = false
	GameState.title_seen = false
	var saves := _open(QuietSaves.new()) as QuietSaves
	var words := _says(saves)
	assert_has(words, "Last played", "no one plays yet")
	assert_does_not_have(words, "Playing")
	saves._select(0)
	saves._delete()
	assert_eq(saves.said, "ask")
	assert_false("go back to the title" in saves.status.text, "already there")
	saves._keep()
	GameState.title_seen = true
	saves._draw()
	assert_has(_says(saves), "Playing", "over the world, the hero in hand plays")
	saves._delete()
	assert_string_contains(saves.status.text, "You'll go back to the title.")
	saves._keep()
	# E on the other hero, from the title: played, not handed back to it.
	GameState.title_seen = false
	saves._select(1)
	saves._continue()
	assert_true(saves.reloaded, "the world starts over round them")
	assert_true(GameState.title_seen, "past the title: no second Continue to press")
	assert_eq(GameState.hero.hero_name, "Tes")
	GameState.apply(mine)


# ---- PIX-484: Options' keys as said ----------------------------------------------

## Options open with the row labelled `label` chosen.
func _options(label: String) -> OptionsScreen:
	var options := _open(OptionsScreen.new()) as OptionsScreen
	for tab in OptionsScreen.TABS.size():
		var rows := options.rows_of(tab)
		for at in rows.size():
			if rows[at]["label"] == label:
				options.tab = tab
				options.selected = at
				options.on_tabs = false
	options._refresh()
	return options


func _chosen(options: OptionsScreen) -> Dictionary:
	return options.rows[options.selected]


## PIX-550: every tab and every row has a line saying what it is for, each
## row its own (the keys share theirs), with its French; the line under the
## rows is the tab's while the keys are on the tabs and the chosen row's once
## they are down among them, no taller than the page leaves it, in English
## and in French with Large reading text.
func test_options_say_what_each_tab_and_row_does() -> void:
	assert_eq(OptionsScreen.TAB_HELP.size(), OptionsScreen.TABS.size(), "a line a tab")
	var language := GameState.settings.language
	var large := GameState.settings.large_text
	var french := TranslationServer.get_translation_object("fr")
	var said := {}
	for wide: bool in [false, true]:
		GameState.settings.large_text = wide
		Text.apply("fr" if wide else "en")
		var options := _open(OptionsScreen.new()) as OptionsScreen
		for tab in OptionsScreen.TABS.size():
			assert_eq(options.help.text, Text.t(OptionsScreen.TAB_HELP[tab]), "%s: on the tabs, what the tab holds" % OptionsScreen.TABS[tab])
			await wait_process_frames(2)
			assert_true(Rect2(OptionsScreen.PAGE.position, OptionsScreen.PAGE.size).grow(-UiStyle.INSET).encloses(options.help.get_global_rect()), "%s%s: the tab's line inside the page" % [OptionsScreen.TABS[tab], " large, in French" if wide else ""])
			for at in options.rows_of(tab).size():
				options._command(_action(&"move_down")).call()
				var row := _chosen(options)
				var line := String(row.get("help", ""))
				assert_gt(line.length(), 20, "%s says what it does" % row["label"])
				assert_ne(String(french.get_message(line)), "", "%s: in French too" % row["label"])
				assert_eq(options.help.text, Controls.say(Text.t(line)), "%s: its line under the rows" % row["label"])
				assert_false("{key:" in options.help.text, "the key by its name")
				if not wide and not row.has("rebind"):
					assert_false(said.has(line), "%s: a line of its own" % row["label"])
					said[line] = true
				await wait_process_frames(2)
				var page := Rect2(OptionsScreen.PAGE.position, OptionsScreen.PAGE.size).grow(-UiStyle.INSET)
				assert_true(page.encloses(options.help.get_global_rect()), "%s%s: the line inside the page, %s" % [row["label"], " large, in French" if wide else "", options.help.get_global_rect()])
				var word := options.columns[0].get_child(0).get_child(0).get_child(0) as Label
				assert_eq(options.help.get_global_rect().position.x, word.get_global_rect().position.x, "%s: the line flush with the rows' words" % row["label"])
			options.turn(1)
	GameState.settings.large_text = large
	Text.apply(language)


## PIX-546: Options open on their tabs, where left and right turn them (round
## past either end) and change nothing; down or E goes into the rows, and
## past the last (or up past the first) is the tabs again.
func test_options_open_on_their_tabs_and_the_rows_lead_back_to_them() -> void:
	var settings := GameState.settings
	var muted := settings.muted
	var options := _open(OptionsScreen.new()) as OptionsScreen
	assert_true(options.on_tabs, "the tabs chosen first")
	var lit := func() -> int: return options.tabs_row.get_children().filter(func(chip: Node) -> bool: return chip.get_meta("lit", false)).size()
	assert_eq(lit.call(), 1, "the chosen tab framed while the keys stand on the tabs")
	assert_has(_says(options.footer), "tabs")
	assert_does_not_have(_says(options.footer), "change", "nothing to change on the tabs")
	var seen: Array[String] = []
	for turn in OptionsScreen.TABS.size():
		seen.append(OptionsScreen.TABS[options.tab])
		assert_eq(options.columns[1].visible, seen[-1] == "Controls", "%s: the keys alone fill both columns" % seen[-1])
		options._command(_action(&"move_right")).call()
	assert_eq(seen, ["Sound", "Display", "Access", "Controls"])
	assert_eq(options.tab, 0, "round to the first")
	options._command(_action(&"move_left")).call()
	assert_eq(OptionsScreen.TABS[options.tab], "Controls", "and back past it to the last")
	options._command(_action(&"move_right")).call()
	assert_eq(settings.muted, muted, "left and right on the tabs changed nothing")
	options._command(_action(&"interact")).call()
	assert_false(options.on_tabs, "E goes into the rows")
	assert_eq(lit.call(), 0, "and no tab framed once they are in the rows")
	assert_eq(String(_chosen(options)["label"]), "Sound")
	assert_has(_says(options.footer), "change")
	options._command(_action(&"move_up")).call()
	assert_true(options.on_tabs, "up past the first row: the tabs")
	options._command(_action(&"move_up")).call()
	assert_eq(String(_chosen(options)["label"]), "Ambience volume", "up from the tabs: the last row")
	options._command(_action(&"move_down")).call()
	assert_true(options.on_tabs, "down past the last: the tabs")
	var all: Array[String] = []
	for tab in OptionsScreen.TABS.size():
		assert_lte(options.rows_of(tab).filter(func(row: Dictionary) -> bool: return row.get("column", 0) == 0).size(), 7, "%s: a column of seven rows at most" % OptionsScreen.TABS[tab])
		for row: Dictionary in options.rows_of(tab):
			all.append(row["label"])
	assert_eq(all.size(), options._build().size(), "every row on a tab")
	assert_has(all, "Rim light")


func test_on_a_key_row_left_and_right_cross_columns_and_only_e_rebinds() -> void:
	var options := _options("Move up")
	var says := _says(options.footer)
	assert_has(says, "other column")
	assert_has(says, "rebind")
	assert_does_not_have(says, "adjust")
	for action: StringName in [&"move_left", &"move_right"]:
		options.selected = options.rows.find_custom(func(row: Dictionary) -> bool: return row.get("rebind", "") == "move_up")
		options._command(_action(action)).call()
		assert_eq(options.listening, "", "%s arms no rebind" % action)
		assert_eq(int(_chosen(options).get("column", 0)), 1, "it crosses to the other column")
		assert_eq(String(_chosen(options)["label"]), "Inventory", "to the row level with it")
		options._command(_action(action)).call()
		assert_eq(String(_chosen(options)["label"]), "Move up", "and back")
	options = _options("Move up")
	options._command(_action(&"interact")).call()
	assert_eq(options.listening, "move_up", "E arms it")
	assert_true(options.waiting_footer.visible and not options.footer.visible)


func test_e_leaves_a_volume_alone_and_flips_a_switch() -> void:
	var settings := GameState.settings
	settings.music_volume = 0.5
	var options := _options("Music volume")
	assert_has(_says(options.footer), "adjust")
	assert_does_not_have(_says(options.footer), Controls.say("{key:interact}"), "no E named on a slider")
	options._command(_action(&"interact")).call()
	assert_almost_eq(settings.music_volume, 0.5, 0.001, "E does nothing to it")
	options._command(_action(&"move_right")).call()
	assert_almost_eq(settings.music_volume, 0.6, 0.001, "right raises it")
	options._command(_action(&"move_left")).call()
	assert_almost_eq(settings.music_volume, 0.5, 0.001, "left lowers it")
	options = _options("Large reading text")
	assert_has(_says(options.footer), "change")
	var was: bool = settings.large_text
	options._command(_action(&"interact")).call()
	assert_eq(settings.large_text, not was, "E flips a switch")
	options = _options("Reset keys to defaults")
	assert_has(_says(options.footer), "reset")
