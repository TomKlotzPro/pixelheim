extends GutTest
## The registries kept a line each (PIX-356): the harness's flags and report
## fields and the look book's shots. Each merges by union (.gitattributes),
## so a row both sides of a merge changed comes out twice, once as each side
## left it; this refuses a name given twice in any of them, and a line that
## isn't a row.

## Each file and the columns of its `a | b | c` rows (0: a JSON object a
## line, named by its `shot`).
const FILES := {
	"res://scripts/harness_flags.txt": 3,
	"res://scripts/harness_report.txt": 2,
	"res://scripts/lookbook_shots.jsonl": 0,
}


func test_no_name_is_given_twice() -> void:
	for path: String in FILES:
		var seen := {}
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges() == "" or line.begins_with("#"):
				continue
			var name := _name(line, FILES[path])
			assert_ne(name, "", "%s: a row: %s" % [path, line])
			assert_false(seen.has(name), "%s: %s is named once" % [path, name])
			seen[name] = true
		assert_gt(seen.size(), 90, "%s was read" % path)


## The row's name, or "" when the line isn't a row.
func _name(line: String, columns: int) -> String:
	if columns == 0:
		var shot: Variant = JSON.parse_string(line)
		return String(shot.get("shot", "")) if shot is Dictionary else ""
	var cells := line.split(" | ", true, columns - 1)
	return cells[0].strip_edges() if cells.size() == columns else ""
