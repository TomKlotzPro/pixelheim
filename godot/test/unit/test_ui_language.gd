extends GutTest
## One UI language (PIX-213): every full screen has its title in one place
## and its keys along the bottom in one order - leaving last, as "Esc
## close" - keys stand on keycaps inside the buttons, the gold is shown one
## way, and the codex fits its page.

## Sequences, not screens: their keys stand top right while a story runs.
const SEQUENCES := ["dawn_screen.gd", "reveal_screen.gd"]
const FULL_SCREENS := [
	"codex_screen.gd", "create_screen.gd", "inventory_screen.gd", "journal_screen.gd",
	"ledger_screen.gd", "map_screen.gd", "options_screen.gd", "skills_screen.gd", "shop_screen.gd",
]


func _scripts() -> Dictionary:
	var out := {}
	for file: String in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"):
			out[file] = FileAccess.get_file_as_string("res://scripts/" + file)
	return out


## The footer lines the scripts write: screen_footer's, and _footer()'s.
func _footer_lines() -> Array[String]:
	var lines: Array[String] = []
	var called := RegEx.create_from_string("UiStyle\\.screen_footer\\((?:Text\\.t\\()?\\s*\"([^\"]*)\"")
	var returned := RegEx.create_from_string("func _footer\\(\\) -> String:\\s*return (?:Text\\.t\\()?\"([^\"]*)\"")
	var sources := _scripts()
	for file: String in sources:
		for found in called.search_all(sources[file]) + returned.search_all(sources[file]):
			lines.append(found.get_string(1))
	return lines


func test_screens_use_the_one_footer() -> void:
	var sources := _scripts()
	for file: String in sources:
		if file == "ui_style.gd" or file in SEQUENCES:
			continue
		assert_false(sources[file].contains("UiStyle.footer("), "%s puts its keys where every screen does (screen_footer)" % file)


func test_leaving_comes_last_and_is_called_close() -> void:
	var lines := _footer_lines()
	assert_gt(lines.size(), 10, "the footers were found")
	for line in lines:
		var commands := RegEx.create_from_string(" {4,}").sub(line.strip_edges(), "\t", true).split("\t")
		for index in commands.size():
			if commands[index].contains("Esc"):
				assert_eq(index, commands.size() - 1, "Esc last in: %s" % line)
				assert_true(commands[index].ends_with("  close"), "leaving is 'close' in: %s" % line)


func test_full_screens_set_their_title_in_one_place() -> void:
	var sources := _scripts()
	for file: String in FULL_SCREENS:
		assert_true(sources[file].contains("UiStyle.title("), "%s titles with UiStyle.title" % file)


func test_gold_is_shown_one_way() -> void:
	var sources := _scripts()
	for file: String in sources:
		assert_false(sources[file].contains("\"Gold: %d\"") or sources[file].contains("\"Gold %d"), "%s shows the purse, not words" % file)
	var purse := UiStyle.purse(42)
	add_child_autofree(purse)
	assert_eq((purse.get_node("sum") as Label).text, "42")
	UiStyle.purse_set(purse, 7)
	assert_eq((purse.get_node("sum") as Label).text, "7")


func test_a_buttons_key_stands_on_a_keycap() -> void:
	var button := UiStyle.button("Play", func() -> void: pass, "{key:interact}")
	add_child_autofree(button)
	assert_eq(button.text, "", "no key spelled into the words")
	var row := button.get_node("keyed")
	assert_eq((row.get_child(1) as Label).text, "Play")
	assert_eq((row.get_child(0).get_child(0) as Label).text, Controls.shown("{key:interact}"))
	UiStyle.button_keyed(button, "Z", "Sell all 3")
	assert_eq(button.get_children().filter(func(child: Node) -> bool: return child.name == "keyed").size(), 1, "relabelled, not doubled")
	var sources := _scripts()
	for file: String in sources:
		assert_false(sources[file].contains("UiStyle.button(UiStyle.keyed("), "%s puts the key on a cap" % file)


func test_the_codex_bestiary_fits_its_page() -> void:
	var script := preload("res://scripts/codex_screen.gd")
	var kinds: int = Bestiary._data()["monsters"].size()
	assert_gte(script.pages() * script.PAGE_ROWS, kinds, "every kind on some page")
	# A row is 28 px and 6 apart; the page line on top; the card's inside is 512.
	assert_lte(script.PAGE_ROWS * 34 + 24, 512, "a page fits the card")
