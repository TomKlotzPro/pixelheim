extends GutTest
## Every screen fits the window it's played in, whatever the window's shape
## (PIX-230). A desktop window or a browser full screen, wide or narrow,
## shows the whole 1280x720 canvas letterboxed, so on a computer what must
## fit is that canvas; a phone stretches the canvas to its own shape and
## stands each screen in its middle. Each screen opens in a view of each of
## those sizes, in English and in French (the longer), and nothing it shows
## may run past the view (Layout.overflows). The saves screen opens with
## every slot full: a full slot's line ("Niveau 18, nécromancien - Le col de
## la Porte-Givre") widened its window and ran its right column 86 px off
## the canvas, which no run with empty slots ever showed.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const SavesScreen := preload("res://scripts/saves_screen.gd")
const MapScreen := preload("res://scripts/map_screen.gd")
const InventoryScreen := preload("res://scripts/inventory_screen.gd")
const ShopScreen := preload("res://scripts/shop_screen.gd")
const TownHallScreen := preload("res://scripts/town_hall_screen.gd")
const HomeScreen := preload("res://scripts/home_screen.gd")
const JournalScreen := preload("res://scripts/journal_screen.gd")
const CodexScreen := preload("res://scripts/codex_screen.gd")
## Three heroes with the longest lines a slot card shows (`--slots` in the
## harness reads them too).
const FULL_SLOTS := "res://test/fixtures/slots"

## The views a screen is laid out in: the canvas any computer shows (a 16:9,
## 16:10, 21:9 or 4:3 window, the canvas letterboxed in it), then the
## canvases a phone or tablet stretches it to: 16:10, 21:9 and 4:3
## sideways, and a phone held upright.
const VIEWS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1707, 720), Vector2i(1280, 960), Vector2i(1280, 2773),
]
const LANGUAGES: Array[String] = ["en", "fr"]

var _lent: Node
var _kept := {}


## The map's world, standing in (GUT doesn't load world.gd).
class StandIn extends Node2D:
	var map: MapData
	var player_cell := Vector2i(40, 30)

	func load_map(map_id: String) -> MapData:
		return MapData.load_by_id(map_id)

	func travel_to(_waypoint: Dictionary) -> void:
		pass


func before_each() -> void:
	Controls.apply({})
	_kept = {
		"hero": GameState.hero, "pack": GameState.pack, "settlement": GameState.settlement,
		"progression": GameState.progression, "dirty": GameState.dirty, "slots": GameState.slots,
		"reduce_motion": GameState.settings.reduce_motion, "stall": GameState.trade.stall_shop,
	}
	# A hero with a long name, quests taken and things in the pack, lent to
	# GameState and given back after.
	_lent = GameStateScript.new()
	_lent.new_game("Aldegonde-Marie", "necromancer")
	GameState.hero = _lent.hero
	GameState.pack = _lent.pack
	GameState.settlement = _lent.settlement
	GameState.progression = _lent.progression
	GameState.progression.quests.merge({
		"slime_trouble": {"progress": 2, "done": false},
		"cheese_run": {"progress": 0, "done": false},
		"maren_relics": {"progress": 0, "done": false},
	})
	GameState.pack.items.merge({"potion_hp": 4, "gem": 1, "furn_plant": 1})
	GameState.slots = SaveSlots.new(FULL_SLOTS, true)
	# Laid out where they settle, not 10 px down mid-entrance.
	GameState.settings.reduce_motion = true


func after_each() -> void:
	for key: String in ["hero", "pack", "settlement", "progression", "slots"]:
		GameState.set(key, _kept[key])
	GameState.dirty = _kept["dirty"]
	GameState.settings.reduce_motion = _kept["reduce_motion"]
	GameState.trade.stall_shop = _kept["stall"]
	_lent.free()
	Text.apply("en")
	await get_tree().process_frame
	get_tree().paused = false


## `kind` opened in a view of each of VIEWS' sizes, side by side; what runs
## past each, as Layout.overflows lines, each led by the view and the
## language. One screen built in each view (a screen lays itself out for
## its view as it opens), all of them settling in the same frames: one wait
## for the five, not five (PIX-354).
func _overflows(kind: String, language: String) -> Array[String]:
	Text.apply(language)
	var opened: Array[Array] = []
	for size in VIEWS:
		var view := SubViewport.new()
		view.size = size
		view.disable_3d = true
		add_child(view)
		var screen := _make(kind, view)
		if screen.get_parent() == null:
			view.add_child(screen)
		opened.append([view, screen])
	# Lines wrap once they know their width, panels settle round them.
	await wait_process_frames(3)
	var out: Array[String] = []
	for pair: Array in opened:
		var view: SubViewport = pair[0]
		for line in Layout.overflows(view, Vector2(view.size)):
			out.append("%s %dx%d %s: %s" % [kind, view.size.x, view.size.y, language, line])
		pair[1].close()
		view.queue_free()
	await get_tree().process_frame
	return out


func _make(kind: String, view: SubViewport) -> Screen:
	match kind:
		"saves":
			return SavesScreen.new()
		"map", "map, the Reach":
			# The Reach's page (PIX-269 step 7) from Saltmere, its south edge.
			var world := StandIn.new()
			world.map = MapData.load_by_id("town" if kind == "map" else "saltmere")
			view.add_child(world)
			var chart: Screen = MapScreen.new()
			chart.world = world
			world.add_child(chart)
			return chart
		"shop":
			# The general store's counter, as talking to its keeper opens it.
			GameState.trade.stall_shop = Economy.shop_at("town_shop")
	return load("res://scripts/%s_screen.gd" % kind).new()


func _fits(kinds: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for kind in kinds:
		for language in LANGUAGES:
			out.append_array(await _overflows(kind, language))
	return out


func test_the_saves_screen_fits_with_every_slot_full() -> void:
	var out := await _fits(["saves"])
	assert_eq(out.size(), 0, "\n".join(out))


func test_the_saves_screen_fits_with_saves_it_cant_read() -> void:
	# PIX-303: a damaged and a newer version's card, then a hero from the
	# save before, its line said on the card; PIX-302: an older version's.
	for folder in ["res://test/fixtures/slots_unread", "res://test/fixtures/slots_backup", "res://test/fixtures/slots_older"]:
		GameState.slots = SaveSlots.new(folder, true)
		var out := await _fits(["saves"])
		assert_eq(out.size(), 0, "%s\n%s" % [folder, "\n".join(out)])


func test_the_saves_window_keeps_its_width_and_its_place() -> void:
	# Set, not grown by what it holds: the window is WINDOW.x wide in the
	# middle of the canvas, and the column it stands in hugs it.
	for language in LANGUAGES:
		Text.apply(language)
		var screen: Screen = SavesScreen.new()
		add_child(screen)
		await wait_process_frames(3)
		var window: PanelContainer = screen.window
		var stack := window.get_parent() as Control
		assert_eq(window.size.x, SavesScreen.WINDOW.x, "%s: the window's width" % language)
		assert_eq(stack.position.x + window.size.x / 2.0, Touch.DESIGN.x / 2.0, "%s: in the middle" % language)
		assert_eq(stack.size, stack.get_combined_minimum_size(), "%s: the column hugs the window" % language)
		assert_lt(stack.get_global_rect().end.y, UiStyle.FOOTER_Y - 16.0, "%s: clear of the keys below" % language)
		screen.close()
		await get_tree().process_frame


func test_every_screen_fits_every_view() -> void:
	var kinds: Array[String] = [
		"title", "create", "pause", "options", "journal", "inventory", "stats", "skills", "codex", "map", "shop",
		"changelog", "bank", "town_hall", "bounty", "home",
	]
	var out := await _fits(kinds)
	assert_eq(out.size(), 0, "\n".join(out))


## PIX-298: Tom's level-15 mage in Frostweave, with the longest names a
## piece can carry (deep-forged, two affixes: "Grande hache d'acier cendré
## des forges profondes de perspicacité") worn: no row is wider than its
## list in the pack (every tab), at the smithy's counter (every tab), the
## town's ledger with holdings and every fixture of the house, in either
## language. The pack's rows ran 75 px past its page in French, "E retirer"
## under the scrollbar, the Forge's 200 px.
func test_long_names_keep_to_their_lists() -> void:
	var saved := SaveCodec.parse_any(FileAccess.get_file_as_string("res://test/fixtures/frostweave_mage.json"))
	GameState.pack.gear.assign(saved["gear"])
	GameState.pack.equipped = saved["equipped"].duplicate()
	GameState.pack.items.merge(saved["inventory"])
	for trophy: String in Town.trophy_buffs():
		GameState.pack.items[trophy] = 1
	GameState.hero.jobs["smithing"]["level"] = 8
	GameState.settlement.properties.assign(["town_shop", "town_smith"])
	var screens: Array[Array] = []
	for index in InventoryScreen.TABS.size():
		screens.append(["pack " + String(InventoryScreen.TABS[index][0]), func() -> Screen:
			var pack: Screen = InventoryScreen.new()
			pack.tab = index
			return pack])
	for tab: String in ["Buy", "Sell", "Forge", "Salvage", "Reforge", "Quench"]:
		screens.append(["smithy " + tab, func() -> Screen:
			GameState.trade.stall_shop = Economy.shop_at("town_smith")
			var counter: Screen = ShopScreen.new()
			counter.start_tab = tab
			return counter])
	screens.append(["town hall", func() -> Screen: return TownHallScreen.new()])
	for mode: String in ["storage", "workbench", "trophies", "nook", "furniture"]:
		screens.append(["house " + mode, func() -> Screen:
			var fixture: Screen = HomeScreen.new()
			fixture.mode = mode
			return fixture])
	var out: Array[String] = []
	for language in LANGUAGES:
		Text.apply(language)
		for entry: Array in screens:
			var view := SubViewport.new()
			view.size = VIEWS[0]
			view.disable_3d = true
			add_child(view)
			var screen: Screen = entry[1].call()
			view.add_child(screen)
			await wait_process_frames(3)
			for line in Layout.overflows(view, Vector2(VIEWS[0])):
				out.append("%s %s: %s" % [entry[0], language, line])
			screen.close()
			view.queue_free()
			await get_tree().process_frame
	assert_eq(out.size(), 0, "\n".join(out))


func test_the_reachs_page_fits_every_view() -> void:
	# A hero who has walked the whole Reach: every region on the page, every
	# name on it, in both languages.
	var discovered: Dictionary = GameState.world.discovered
	GameState.world.discovered = {}
	Atlas.walk_all(GameState.world.discovered)
	var out := await _fits(["map, the Reach"] as Array[String])
	GameState.world.discovered = discovered
	assert_eq(out.size(), 0, "\n".join(out))


## PIX-388: a screen's tabs stand on its page's top edge, side by side and
## never on each other, clear of its corners: the last ends INSET in from
## the right one (the pack's « Artisanat » ran onto it), the first no
## nearer the left one than INSET less the kit tab's clear shoulder (4), in
## either language, with the kit and drawn without it. The counter's
## tabs over its goods, the smithy's over its wide page.
func test_tabs_stand_apart_on_their_pages_edge() -> void:
	var screens: Array[Array] = [
		["pack", InventoryScreen.PAGE, func() -> Screen: return InventoryScreen.new()],
		["store", ShopScreen.GOODS, func() -> Screen:
			GameState.trade.stall_shop = Economy.shop_at("town_shop")
			return ShopScreen.new()],
		["smithy", ShopScreen.WIDE, func() -> Screen:
			GameState.trade.stall_shop = Economy.shop_at("town_smith")
			var counter: Screen = ShopScreen.new()
			counter.start_tab = "Forge"
			return counter],
		["journal", Rect2(JournalScreen.AT, JournalScreen.SIZE), func() -> Screen: return JournalScreen.new()],
		["codex", CodexScreen.CARD, func() -> Screen: return CodexScreen.new()],
	]
	var withheld := UiStyle.withheld
	for drawn in [false, true]:
		UiStyle.withheld = drawn
		for language in LANGUAGES:
			Text.apply(language)
			for entry: Array in screens:
				var view := SubViewport.new()
				view.size = VIEWS[0]
				view.disable_3d = true
				add_child(view)
				var screen: Screen = entry[2].call()
				view.add_child(screen)
				await wait_process_frames(3)
				var page: Rect2 = entry[1]
				var row: Array = screen.tab_buttons if screen is ShopScreen else (screen.tab_row if screen is InventoryScreen else screen.tabs_row).get_children()
				var said := "%s %s%s" % [entry[0], language, " drawn" if drawn else ""]
				assert_gt(row.size(), 1, said)
				for index in row.size():
					var tab := (row[index] as Control).get_global_rect()
					assert_eq(tab.end.y, page.position.y, "%s: tab %d on the page's top edge" % [said, index])
					if index + 1 < row.size():
						assert_true(tab.end.x <= (row[index + 1] as Control).get_global_rect().position.x, "%s: tab %d clear of the next" % [said, index])
				assert_true((row[0] as Control).get_global_rect().position.x >= page.position.x + UiStyle.INSET - 4, "%s: clear of the left corner" % said)
				assert_true((row[-1] as Control).get_global_rect().end.x <= page.end.x - UiStyle.INSET, "%s: clear of the right corner, %s" % [said, (row[-1] as Control).get_global_rect()])
				screen.close()
				view.queue_free()
				await get_tree().process_frame
	UiStyle.withheld = withheld
