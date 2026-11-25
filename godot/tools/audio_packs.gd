extends SceneTree
## The web build's audio packs (PIX-518): the packs' takes (sfx.pck), the
## title's track (title.pck, PIX-552: small and fetched first, the title
## being the first thing heard) and the bundle's other tracks (music.pck) as
## Godot imported them, each in a pack of its own beside the page. The Web
## preset leaves them out of index.pck (its exclude_filter), so the game
## starts without waiting on 50 MB of audio;
## Sound fetches these once it runs and mounts them (`Sound.PACKS`, `mount`).
## Run after the import, before or after the export; without the paid audio
## installed it writes nothing. The packs hold paid audio: they ship in the
## built site only, never in this repo (godot/export/ is git-ignored).
##
##   godot --headless --audio-driver Dummy --path godot -s tools/audio_packs.gd [-- <out>]
##
## <out> is the export's folder (export/web by default).

const PAID := "res://assets/audio/paid"
## Each pack's files by their extension, as `Sound.PACKS` names them.
const PACKS := {"title.pck": "ogg", "sfx.pck": "wav", "music.pck": "ogg"}
## The title's pack holds this track alone (tools/music_prep.py's name for
## the "title" slot's), and music.pck every other.
const TITLE := "music_title.ogg"


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "export/web"
	if not DirAccess.dir_exists_absolute(PAID):
		print("no paid audio installed: no packs")
		quit()
		return
	DirAccess.make_dir_recursive_absolute(out)
	for pack: String in PACKS:
		var files: Array[String] = []
		for file in DirAccess.get_files_at(PAID):
			if file.get_extension() == PACKS[pack] and (PACKS[pack] != "ogg" or (file == TITLE) == (pack == "title.pck")):
				files.append(PAID.path_join(file))
		if files.is_empty():
			continue
		var packer := PCKPacker.new()
		var failed := packer.pck_start(out.path_join(pack))
		for file in files:
			# A sound is its .import, which names what the import made of it.
			var made := ConfigFile.new()
			failed = failed if failed != OK else made.load(file + ".import")
			var path := str(made.get_value("remap", "path", ""))
			for part: String in [file + ".import", path]:
				failed = failed if failed != OK else packer.add_file(part, part)
		failed = failed if failed != OK else packer.flush()
		if failed != OK:
			printerr("%s: %s (was the project imported?)" % [pack, error_string(failed)])
			quit(1)
			return
		print("%s: %d sounds, %.1f MiB" % [pack, files.size(), FileAccess.get_size(out.path_join(pack)) / 1048576.0])
	quit()
