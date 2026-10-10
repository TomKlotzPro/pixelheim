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
	GameState.slots = SaveSlots.new(FULL_SLOTS)
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


## `kind` opened in a `size` view; what runs past it, as Layout.overflows
## lines, each led by the view and the language.
func _overflows(kind: String, size: Vector2i, language: String) -> Array[String]:
	Text.apply(language)
	var view := SubViewport.new()
	view.size = size
	view.disable_3d = true
	add_child(view)
	var screen := _make(kind, view)
	if screen.get_parent() == null:
		view.add_child(screen)
	# Lines wrap once they know their width, panels settle round them.
	await wait_process_frames(3)
	var out: Array[String] = []
	for line in Layout.overflows(view, Vector2(size)):
		out.append("%s %dx%d %s: %s" % [kind, size.x, size.y, language, line])
	screen.close()
	view.queue_free()
	await get_tree().process_frame
	return out


func _make(kind: String, view: SubViewport) -> Screen:
	match kind:
		"saves":
			return SavesScreen.new()
		"saves, a web hero":
			# The first visit's offer, for a hero with a long name.
			var screen := SavesScreen.new()
			screen.web_save = GameState.slots.read(1)
			screen.welcome = true
			return screen
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
		"dungeon":
			# The mountain's gate: the longest list of floors.
			var gate: Screen = load("res://scripts/dungeon_screen.gd").new()
			gate.dungeon_id = "mountain"
			return gate
	return load("res://scripts/%s_screen.gd" % kind).new()


func _fits(kinds: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for kind in kinds:
		for language in LANGUAGES:
			for size in VIEWS:
				out.append_array(await _overflows(kind, size, language))
	return out


func test_the_saves_screen_fits_with_every_slot_full() -> void:
	var out := await _fits(["saves", "saves, a web hero"])
	assert_eq(out.size(), 0, "\n".join(out))


func test_the_saves_window_keeps_its_width_and_its_place() -> void:
	# Set, not grown by what it holds: the window is WINDOW.x wide in the
	# middle of the canvas, and the column it stands in hugs it.
	for language in LANGUAGES:
		Text.apply(language)
		var screen: Screen = SavesScreen.new()
		screen.web_save = GameState.slots.read(1)
		screen.welcome = true
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
		"changelog", "bank", "town_hall", "bounty", "dungeon", "home",
	]
	var out := await _fits(kinds)
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
