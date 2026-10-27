class_name Features
## areas: all
## Every feature under scripts/features/ (PIX-361), found once: each folder
## there is one, its feature.gd a Feature, in the folders' name order.

const FOLDER := "res://scripts/features"
## The features, read once (`all()`).
static var _all: Array[Feature] = []


static func all() -> Array[Feature]:
	if _all.is_empty():
		var names := DirAccess.get_directories_at(FOLDER)
		names.sort()
		for folder_name in names:
			var feature: Feature = load(FOLDER.path_join(folder_name).path_join("feature.gd")).new()
			feature.folder = FOLDER.path_join(folder_name)
			_all.append(feature)
	return _all


## `feature`'s rows of one of the core's registries (`file`, as the core's
## is named: harness_flags.txt, harness_report.txt), read as the core's
## (HarnessFlags.read_rows), each with its `feature`; none when it has no
## such file.
static func rows(feature: Feature, file: String, columns: PackedStringArray, optional := 0) -> Array[Dictionary]:
	var path := feature.folder.path_join(file)
	if not FileAccess.file_exists(path):
		return []
	var out := HarnessFlags.read_rows(path, columns, optional)
	for row in out:
		row["feature"] = feature
	return out


## Every feature's map layers, by name (MapView).
static func layers() -> Dictionary[String, MapLayer]:
	var out: Dictionary[String, MapLayer] = {}
	for feature in all():
		out.merge(feature.layers())
	return out
