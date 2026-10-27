extends GutTest
## The registries kept a line each (PIX-356): the harness's flags and report
## fields and the look book's shots, the core's and every feature's beside
## its feature.gd (PIX-361). Each merges by union (.gitattributes), so a row
## both sides of a merge changed comes out twice, once as each side left it;
## this refuses a name given twice in any of them, or in the core's and a
## feature's both, and a line that isn't a row. And each feature plugs in
## where it says.

## Each registry's file name, the core's in scripts/ and a feature's in its
## folder, and the columns of its `a | b | c` rows (0: a JSON object a
## line, named by its `shot`).
const FILES := {
	"harness_flags.txt": 3,
	"harness_report.txt": 2,
	"lookbook_shots.jsonl": 0,
}


func test_no_name_is_given_twice() -> void:
	for file: String in FILES:
		var seen := {}
		for path in _paths(file):
			for line in FileAccess.get_file_as_string(path).split("\n"):
				if line.strip_edges() == "" or line.begins_with("#"):
					continue
				var name := _name(line, FILES[file])
				assert_ne(name, "", "%s: a row: %s" % [path, line])
				assert_false(seen.has(name), "%s: %s is named once (in %s already)" % [path, name, seen.get(name)])
				seen[name] = path
		assert_gt(seen.size(), 90, "%s was read" % file)


func test_the_lamps_plug_in_where_they_say() -> void:
	var lamps: Array = Features.all().filter(func(feature: Feature) -> bool: return feature.folder.ends_with("/lamps"))
	assert_eq(lamps.size(), 1, "scripts/features/lamps is a feature")
	var flags: Array = HarnessFlags.table().map(func(row: Dictionary) -> String: return row["flag"])
	assert_eq(flags[flags.find("--lit") - 1], "brew", "--lit after brew, where it always stood in --help")
	for field: String in ["air", "finds", "healed", "lamps", "visitors"]:
		var row: Array = HarnessReport.table().filter(func(entry: Dictionary) -> bool: return entry["field"] == field)
		assert_eq(row.size(), 1, "%s= is a field" % field)
		assert_eq(row[0].get("feature"), lamps[0], "%s= is the lamps'" % field)


func test_each_feature_names_a_flag_that_is_there() -> void:
	for feature in Features.all():
		if feature.flags_after() != "":
			assert_false(HarnessFlags.row_of(feature.flags_after()).is_empty(), "%s's flags follow a flag in the table" % feature.folder)


## A layer's name taken already keeps its first layer (Dictionary.merge):
## the core's, then the first feature's.
func test_no_map_layer_is_named_twice() -> void:
	var view := MapView.new(MapData.load_by_id("town"), null)
	var own := 0
	for feature in Features.all():
		own += feature.layers().size()
	assert_eq(view._feature_layers.size(), own, "no two features name a layer alike")
	for name: String in view._feature_layers:
		assert_same(view._layers[name], view._feature_layers[name], "%s is a feature's layer, not the core's" % name)


## The core's file, then each feature's that has one.
func _paths(file: String) -> PackedStringArray:
	var paths: PackedStringArray = ["res://scripts/" + file]
	for feature in Features.all():
		if FileAccess.file_exists(feature.folder.path_join(file)):
			paths.append(feature.folder.path_join(file))
	return paths


## The row's name, or "" when the line isn't a row.
func _name(line: String, columns: int) -> String:
	if columns == 0:
		var shot: Variant = JSON.parse_string(line)
		return String(shot.get("shot", "")) if shot is Dictionary else ""
	var cells := line.split(" | ", true, columns - 1)
	return cells[0].strip_edges() if cells.size() == columns else ""
