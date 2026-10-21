extends GutTest
## Wrong words and numbers (PIX-347): a potion's heal said once, by the
## card's computed line; decimals and counts as each language writes them;
## where a fall wakes and what waking says; the unnamed hero's name.

const GameStateScript := preload("res://scripts/state/game_state.gd")
const ShopScreen := preload("res://scripts/shop_screen.gd")

const HEAL := "\\b\\d+ (HP|MP)\\b"


func after_each() -> void:
	Text.apply("en")


# ---- the heal line -----------------------------------------------------------------

func test_no_description_says_a_heal() -> void:
	var heal := RegEx.create_from_string(HEAL)
	for item_id: String in Catalog._data()["items"]:
		var item := Catalog.item(item_id)
		assert_null(heal.search(String(item.get("description", ""))), "%s's words leave the heal to the card's line" % item_id)


func test_the_card_says_a_potions_heal_once() -> void:
	var heal := RegEx.create_from_string(HEAL)
	for item_id: String in ["potion_hp", "greater_potion", "elixir", "antidote", "troll_salve", "city_banquet"]:
		var item := Catalog.item(item_id)
		var card := ShopScreen._describe(item_id)
		var said := heal.search_all(card).size()
		var restores := int(item.has("restoreHp")) + int(item.has("restoreMp"))
		assert_eq(said, restores, "%s: each heal once, in %s" % [item_id, card])
		if item.has("restoreHp"):
			assert_string_contains(card, "Restores %d HP" % GameState.upkeep.hp_restore(item), "the computed heal, a share of health where it has one")


# ---- decimals and counts -----------------------------------------------------------

func test_decimals_as_each_language_writes_them() -> void:
	assert_eq(Text.decimal(0.5), "0.5")
	assert_eq(Text.decimal(1.25), "1.25")
	assert_eq(Text.decimal(2.0), "2", "a whole number has no point")
	Text.apply("fr")
	assert_eq(Text.decimal(0.5), "0,5", "« 0,5 % par jour »")
	assert_eq(Text.decimal(1.5), "1,5")
	assert_eq(Text.decimal(2.0), "2")


func test_counts_stand_apart_from_the_name() -> void:
	assert_eq(Text.count(3, "Marsh Reed"), "3 × Marsh Reed")
	assert_eq(Text.count(1, "Wolf Pelt"), "1 × Wolf Pelt")
	# The counts the game builds read the same way.
	var recipe: Dictionary = Economy.recipes()[0]
	for line: String in Economy.missing_names(recipe, {}):
		assert_string_contains(line, " × ", "a recipe's missing materials")
	for project: Dictionary in Town.age(1)["projects"]:
		if not project["cost"]["items"].is_empty():
			assert_string_contains(Town.cost_line(project["id"]), " × ", "a project's price")
	Text.apply("fr")
	assert_eq(Text.count(3, Catalog.item_name("marsh_reed")), "3 × Roseau des marais")


# ---- where a fall wakes ------------------------------------------------------------

func test_a_fall_before_the_gate_wakes_on_the_road() -> void:
	for step: int in [Prologue.SCAVENGER, Prologue.GATE]:
		var woke := Upkeep.waking(step, [])
		assert_eq(woke["woke"], "road")
		assert_eq([woke["mapId"], woke["x"], woke["y"]], [Prologue.start()["mapId"], Prologue.start()["x"], Prologue.start()["y"]], "where the night began")


func test_a_fall_at_the_ashes_wakes_beside_the_tent() -> void:
	var tent := Town.ashes_tent([])
	var map := MapData.load_tiered("town", [], 1)
	for step: int in [Prologue.HOUNDS, Prologue.EMBERS, Prologue.DONE]:
		var woke := Upkeep.waking(step, [])
		var spot := Vector2i(woke["x"], woke["y"])
		assert_eq([woke["woke"], woke["mapId"]], ["tent", "town"])
		assert_ne(spot, tent, "not on the tent")
		assert_true(absi(spot.x - tent.x) <= 1 and spot.y <= tent.y, "beside it, never below it, where the hero is drawn over it")
		assert_true(map.is_walkable(spot), "on open ground")
	var inn := Upkeep.waking(Prologue.DONE, ["the_inn"])
	assert_eq([inn["woke"], inn["mapId"]], ["inn", Catalog._data()["innRest"]["mapId"]], "the inn once it's built")


func test_waking_says_where() -> void:
	var state: Node = autofree(GameStateScript.new())
	var said: Array[String] = []
	state.message.connect(func(text: String) -> void: said.append(text))
	state.pack.gold = 100
	var woke: Dictionary = state.upkeep.wake_at_inn()
	assert_eq(woke["woke"], "tent", "a new hero's town is in ashes")
	assert_true(state.pack.gold < 100, "the toll")
	assert_eq(said.size(), 1)
	assert_eq(said[0], Upkeep.wake_line("tent", 100 - state.pack.gold))
	assert_string_contains(said[0], "Sela's tent")
	state.progression.prologue = Prologue.SCAVENGER
	said.clear()
	state.upkeep.wake_at_inn()
	assert_eq(said.size(), 1)
	assert_eq(said[0], "You come to on the road. Pixelheim is still burning ahead.", "no inn, no toll on the night")
	assert_eq(Upkeep.wake_line("tent", 0), "You wake beside Sela's tent, your cuts bound. She has patched up worse.")
	assert_string_contains(Upkeep.wake_line("inn", 5), "at the inn, 5 gold lighter")


# ---- the hero's name ---------------------------------------------------------------

func test_the_unnamed_hero_is_named_once_in_the_language() -> void:
	var state: Node = autofree(GameStateScript.new())
	assert_eq(state.hero.hero_name, "Wanderer")
	Text.apply("fr")
	state.new_game()
	assert_eq(state.hero.hero_name, "Vagabond", "the stand-in, named in French")
	state.new_game("Wanderer")
	assert_eq(state.hero.hero_name, "Wanderer", "a chosen name is never translated")
