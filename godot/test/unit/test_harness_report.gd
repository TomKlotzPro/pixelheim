extends GutTest
## The harness's report line (PIX-273): every field in one table, the head
## first and the rest by name, each written by its own function in the
## table's order; harness.gd writes no field itself, and every field a
## release flow expects is in the table. Each branch used to add its field
## to the end of one print in harness.gd, so any two at once conflicted
## there, and a flow anchored on the line's end (`packs=...$`) broke when a
## field came after it.

## The fields every run shows, first, as the line always began.
const HEAD := ["map", "cell", "hp", "gold", "save", "draws", "paused", "open", "night", "mobs"]


func _fields() -> Array:
	return HarnessReport.table().map(func(row: Dictionary) -> String: return row["field"])


func test_no_field_is_declared_twice() -> void:
	var seen := {}
	var word := RegEx.create_from_string("^[a-z]+$")
	for row: Dictionary in HarnessReport.table():
		var field: String = row["field"]
		assert_false(seen.has(field), "%s is declared once" % field)
		seen[field] = true
		assert_not_null(word.search(field), "%s is one lowercase word" % field)
		assert_ne(String(row.get("says", "")), "", "%s says what it shows" % field)
	assert_gt(seen.size(), 35, "the whole report is here")


func test_the_head_comes_first_then_the_rest_by_name() -> void:
	var fields := _fields()
	assert_eq(HarnessReport.HEAD, HEAD.size())
	assert_eq(fields.slice(0, HEAD.size()), HEAD, "every run's fields open the line, as they always did")
	var rest := fields.slice(HEAD.size())
	var by_name := rest.duplicate()
	by_name.sort()
	assert_eq(rest, by_name, "after the head the fields go by name: a new one goes in its place, not at the end")


func test_each_field_has_its_function_in_the_tables_order() -> void:
	# The core's in harness_report.gd; a feature's in its feature.gd, given
	# the report (PIX-361).
	var sources := {"": FileAccess.get_file_as_string("res://scripts/harness_report.gd")}
	var lasts := {}
	for row: Dictionary in HarnessReport.table():
		var field: String = row["field"]
		var script := String(row["feature"].folder.path_join("feature.gd")) if row.has("feature") else ""
		if not sources.has(script):
			sources[script] = FileAccess.get_file_as_string(script)
		var head := "\nfunc field_%s(report: HarnessReport) -> String:" if script != "" else "\nfunc field_%s() -> String:"
		var at: int = sources[script].find(head % field)
		assert_gt(at, -1, "field_%s() writes %s= (%s)" % [field, field, script if script != "" else "harness_report.gd"])
		assert_gt(at, lasts.get(script, -1), "field_%s() stands where %s stands in its harness_report.txt" % [field, field])
		lasts[script] = at
	assert_gt(sources.size(), 1, "a feature's fields were checked")
	for script: String in sources:
		for found in RegEx.create_from_string("\\nfunc field_(\\w+)\\(").search_all(sources[script]):
			assert_true(HarnessReport.has(found.get_string(1)), "field_%s() has its row in a harness_report.txt" % found.get_string(1))


func test_the_line_joins_the_fields_with_text_in_the_tables_order() -> void:
	var line := HarnessReport.joined({"gate": "bridge", "fell": "", "map": "overworld", "cell": "(48, 31)", "nowhere": "x"})
	assert_eq(line, "screenshot saved; map=overworld cell=(48, 31) gate=bridge",
		"in the table's order, a field without text left out, one the table doesn't hold never shown")


func test_the_harness_writes_no_field_itself() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/harness.gd")
	# And its steps (PIX-357).
	for file in DirAccess.get_files_at("res://scripts/harness_steps"):
		if file.ends_with(".gd"):
			source += FileAccess.get_file_as_string("res://scripts/harness_steps/" + file)
	assert_false(source.contains("screenshot saved"), "harness.gd prints HarnessReport.line()")
	assert_null(RegEx.create_from_string("\" [a-z_]+=%").search(source), "no ` name=%s` piece of a line built by hand")
	assert_null(RegEx.create_from_string("\\w+_report \\+?= ").search(source), "no line of fields kept beside the report")
	var report := FileAccess.get_file_as_string("res://scripts/harness_report.gd")
	var notes := RegEx.create_from_string("report\\.note\\(\\s*\"(\\w+)\"").search_all(source)
	assert_gt(notes.size(), 3, "the notes were found")
	for found in notes:
		var field := found.get_string(1)
		assert_true(HarnessReport.has(field), "%s (noted in harness.gd) is in harness_report.txt" % field)
		assert_true(report.contains("return noted(\"%s\")" % field), "field_%s() reads its note" % field)


func test_every_field_a_flow_expects_is_in_the_table() -> void:
	var named := RegEx.create_from_string("(?:^| )([a-z_]+)=")
	var checked := 0
	# flows.txt and each feature's flows (PIX-361).
	var lines := FileAccess.get_file_as_string("res://tools/flows.txt").split("\n")
	for file in DirAccess.get_files_at("res://tools/flows.d"):
		lines.append_array(FileAccess.get_file_as_string("res://tools/flows.d/" + file).split("\n"))
	for line in lines:
		if line.strip_edges() == "" or line.strip_edges().begins_with("#"):
			continue
		var parts := line.split("|")
		assert_eq(parts.size(), 4, "a flow is name | arguments | expected | tags: %s" % line)
		if parts.size() != 4:
			continue
		for found in named.search_all(parts[2].strip_edges()):
			assert_true(HarnessReport.has(found.get_string(1)), "%s= (expected by %s) is in harness_report.txt" % [found.get_string(1), parts[0].strip_edges()])
			checked += 1
	assert_gt(checked, 150, "the flows' fields were checked")
