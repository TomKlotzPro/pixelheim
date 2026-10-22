class_name HarnessFlags
## areas: all
## The screenshot harness's flags (PIX-262), every one in a single table:
## its name, what it takes and what it does. Two features once read the same
## word (`motion` was both the walking check and the look book's filming,
## and froze the hero in every clip until the filming became `film`), and
## nothing said so while each step searched the command line on its own. So
## a flag is declared once, the command line is parsed once against the
## table, and every reader - the harness's boot and steps, the world, the
## lights, the look book - asks the parse. test_harness_flags keeps it so (no
## name twice; every flag the scripts read, and the tools and the README
## pass, is here) and `-- --help` prints it.
##
## Parsing by the table also keeps a flag's argument from reading as a flag:
## `--story ending` used to play the `ending` step too, `--foe mimic` the
## `mimic` one.

## Every flag, a line each (PIX-356: a row a branch adds merges by union,
## where a table in this script made catch-up merges conflict):
## `flag | takes | does`, the argument it takes ("" for none) and what it
## does, then `| step | order` for a flag that is a step of the run
## (PIX-357). Its head says the order.
const TABLE_FILE := "res://scripts/harness_flags.txt"

## The run's own flags, parsed once (`given()`).
static var _given: HarnessFlags
## TABLE_FILE's rows, read once (`table()`).
static var _table: Array[Dictionary] = []
## flag -> its row in the table.
static var _rows := {}

## flag -> its argument ("" for a flag that takes none), as first given.
var _found := {}
## What the table doesn't know, and flags given without their argument: the
## harness warns of them.
var problems: PackedStringArray = []


## Parses `args` (what came after Godot's `--`) against the table: a flag
## that takes an argument takes the word after it, whatever it is, so an
## argument never reads as a flag. A flag given twice counts the first time
## (`FLOWS_EXTRA="--lang fr"` comes last).
func _init(args := PackedStringArray()) -> void:
	var at := 0
	while at < args.size():
		var word := args[at]
		at += 1
		var row := row_of(word)
		if row.is_empty():
			problems.append("unknown flag " + word)
			continue
		var takes: String = row["takes"]
		if takes == "":
			if not _found.has(word):
				_found[word] = ""
			continue
		if at >= args.size():
			problems.append(word + " takes " + takes)
			continue
		if not _found.has(word):
			_found[word] = args[at]
		at += 1


## The command line's flags, parsed the first time they're asked for; in a
## batch (`--batch <file>`, PIX-360), the flags of the flow it's on.
static func given() -> HarnessFlags:
	if _given == null:
		var flags := HarnessFlags.new(OS.get_cmdline_user_args())
		_given = flags
		if flags.has("--batch"):
			batch = FileAccess.get_file_as_string(flags.value("--batch")).split("\n", false)
			next_in_batch()
	return _given


## `--batch <file>`'s flows still to run, `name|harness arguments` a line each
## (tools/flows.sh: the look-only flows, one Godot booting once for several).
static var batch := PackedStringArray()


## The batch's next flow: its name on a line of its own (flows.sh splits the
## output there) and its flags given, the command line's with `--batch <file>`
## given way to the flow's arguments, as flows.sh runs a flow alone.
static func next_in_batch() -> void:
	var flow := batch[0].split("|")
	batch.remove_at(0)
	print("BATCH " + flow[0])
	var line := OS.get_cmdline_user_args()
	var at := line.find("--batch")
	_given = HarnessFlags.new(line.slice(0, at) + flow[1].split(" ", false) + line.slice(at + 2))


## Every flag's row, in TABLE_FILE's order.
static func table() -> Array[Dictionary]:
	if _table.is_empty():
		_table = read_rows(TABLE_FILE, ["flag", "takes", "does", "step", "order"], 2)
	return _table


## The rows of a registry kept a line each (this table, HarnessReport's):
## `a | b | c` under `columns`, the last taking the rest of the line, or
## leaving out the last `optional` columns (they read ""); blank lines and
## `#` ones skipped.
static func read_rows(path: String, columns: PackedStringArray, optional := 0) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges() == "" or line.begins_with("#"):
			continue
		var cells := line.split(" | ", true, columns.size() - 1)
		if cells.size() < columns.size() - optional:
			push_error("%s: a row is %s: %s" % [path, " | ".join(columns), line])
			continue
		var row := {}
		for at in columns.size():
			row[columns[at]] = cells[at].strip_edges() if at < cells.size() else ""
		rows.append(row)
	return rows


## The table's row for `flag`, or {} when it isn't one.
static func row_of(flag: String) -> Dictionary:
	if _rows.is_empty():
		for row: Dictionary in table():
			_rows[row["flag"]] = row
	return _rows.get(flag, {})


## Whether the run gave `flag` (with its argument, if it takes one).
func has(flag: String) -> bool:
	_declared(flag)
	return _found.has(flag)


## The argument `flag` was given, or `default` when it wasn't.
func value(flag: String, default := "") -> String:
	_declared(flag)
	return _found.get(flag, default)


## The argument of a flag that takes a list (`--walk l,d,r`), split on its
## commas; empty when it wasn't given.
func list(flag: String) -> PackedStringArray:
	return value(flag).split(",") if has(flag) else PackedStringArray()


## The rows of the flags given that are steps (PIX-357), by their order:
## harness.gd awaits each in turn.
func steps() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for flag: String in _found:
		if row_of(flag)["step"] != "":
			rows.append(row_of(flag))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["order"]) < int(b["order"]))
	return rows


## A flag read that the table doesn't declare is a mistake in the reader.
func _declared(flag: String) -> void:
	if row_of(flag).is_empty():
		push_error("HarnessFlags: %s is read but not in the table (scripts/harness_flags.txt)" % flag)


## The table as `-- --help` prints it: each flag and its argument, then
## what it does.
static func help() -> String:
	var width := 0
	for row: Dictionary in table():
		width = maxi(width, _usage(row).length())
	var lines: PackedStringArray = [
		"godot --path godot -- --screenshot [flags]   (scripts/harness_flags.gd, PIX-262)",
		"The steps run in harness.gd's own order, whatever the order they're given in.",
		"",
	]
	for row: Dictionary in table():
		lines.append("  " + _usage(row).rpad(width + 2) + String(row["does"]))
	return "\n".join(lines)


static func _usage(row: Dictionary) -> String:
	return String(row["flag"]) + ("" if row["takes"] == "" else " " + String(row["takes"]))
