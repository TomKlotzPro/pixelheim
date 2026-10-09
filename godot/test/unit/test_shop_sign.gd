extends GutTest
## Shop signs (PIX-134): every town sign gets a trade icon, and the nameplate
## names the place and its keeper from the game's own data.


func test_every_town_sign_has_a_trade_icon() -> void:
	for owned: bool in [false, true]:
		for sign_def: Dictionary in Interactables.signs_on("town", owned):
			assert_true(ShopSign.ICONS.has(sign_def["label"]), "%s has an icon" % sign_def["label"])


func test_nameplates_name_the_place_and_its_keeper() -> void:
	assert_eq(ShopSign.about("GOODS", "town_shop", false), {"name": "Odo's Emporium", "about": "Merchant Odo"})
	assert_eq(ShopSign.about("FORGE", "town_smith", false), {"name": "Hilda's Smithy", "about": "Smith Hilda"})
	assert_eq(ShopSign.about("BREWS", "town_alchemist", false), {"name": "Vex's Workshop", "about": "Alchemist Vex"})
	assert_eq(ShopSign.about("INN", "town_inn", false), {"name": "The Inn", "about": "Innkeeper Sela"})
	assert_eq(ShopSign.about("HALL", "town_hall", false), {"name": "Town Hall", "about": "Mayor Aldric"})


func test_the_house_is_for_sale_then_home() -> void:
	var sale := ShopSign.about("FOR SALE", "", false)
	assert_eq(sale["name"], "For sale")
	assert_string_contains(sale["about"], "%dg" % int(Town._data()["houseDeedCost"]))
	assert_eq(ShopSign.about("HOME", "", true), {"name": "Home", "about": "Your house"})


## PIX-196: in French the boards keep their icons (the label is an id).
func test_a_sign_keeps_its_icon_in_another_language() -> void:
	TranslationServer.set_locale("fr")
	Text.forget()
	for sign_def: Dictionary in Interactables._data()["signs"]["town"]:
		assert_true(ShopSign.ICONS.has(sign_def["label"]), "%s keeps its icon" % sign_def["label"])
	assert_ne(Catalog.item_name("bread"), "Bread", "the rest of the data does speak French")
	Text.apply("en")
