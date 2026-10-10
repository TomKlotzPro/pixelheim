class_name RankSheet
extends CanvasLayer
## Every class's ranks side by side (PIX-244), for the look book's 23_ranks:
## a row a class, a column a rank (I to V, with the level it comes at), and
## in each cell the hero three ways - from the front, walking right (the
## trail of light, from V) and caught on the swing's striking frame (the
## weapon's glow, from IV) - in plain clothes, each wearing that rank's
## look (RankLook) over its pool of light, the rank's title under them. The
## last row is a warrior in iron with a shield and an obsidian blade, to show
## a rank's look on top of worn gear, never over it. Drawn at 3x in whole pixels (the presence's
## few per cent of size is left out, so every pixel stays square), over a
## plain dark page so the light reads.

const SIZE := Vector2(1280, 720)
const SCALE := 3.0
## The page: a column of class names, then a column a rank; a header row.
const NAMES_WIDTH := 140.0
const HEADER := 36.0
## In a cell: where each pose's feet stand (x from the cell's left, y from
## the row's top), and the title's line under them.
const POSES := [["front", 46.0], ["walk", 112.0], ["swing", 174.0]]
const FEET := 54.0
const TITLE_AT := 58.0
const ROMAN := ["I", "II", "III", "IV", "V"]
## The geared row: what the warrior wears.
const GEAR := {"head": "iron_helm", "body": "iron_armor", "offhand": "steel_shield", "weapon": "obsidian_blade"}

var _rows: Array = []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	for role_id: String in PunyArt.HEROES:
		_rows.append([role_id, PunyArt.dressed(role_id, 0, {}), Catalog.role(role_id)["name"], ""])
	_rows.append(["warrior", PunyArt.dressed("warrior", 0, GEAR), Catalog.role("warrior")["name"], Catalog.item(GEAR["body"])["name"]])
	var page := ColorRect.new()
	page.color = Color("16131c")
	page.size = SIZE
	add_child(page)
	var row_height := (SIZE.y - HEADER) / _rows.size()
	var column := (SIZE.x - NAMES_WIDTH) / RankLook.STEPS.size()
	for rank in RankLook.STEPS.size():
		var head := UiStyle.label("%s   %s" % [ROMAN[rank], Text.t("Lv %d") % maxi(1, rank * 5)], 15, UiStyle.GOLD, Vector2(NAMES_WIDTH + rank * column, 8))
		head.custom_minimum_size = Vector2(column, 0)
		head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(head)
	for index in _rows.size():
		var row: Array = _rows[index]
		var top := HEADER + index * row_height
		if index % 2 == 1:
			var band := ColorRect.new()
			band.color = Color("1d1925")
			band.position = Vector2(0, top)
			band.size = Vector2(SIZE.x, row_height)
			add_child(band)
		add_child(UiStyle.label(row[2], 15, UiStyle.CREAM, Vector2(12, top + 18)))
		if row[3] != "":
			add_child(UiStyle.label(row[3], 15, UiStyle.DUSK, Vector2(12, top + 40)))
		for rank in RankLook.STEPS.size():
			_cell(row[0], row[1], rank, Vector2(NAMES_WIDTH + rank * column, top), column)


## One rank of one class: the three poses and the title.
func _cell(role_id: String, art: Dictionary, rank: int, at: Vector2, width: float) -> void:
	var look := RankLook.spec(role_id, rank)
	for pose: Array in POSES:
		var stage := Node2D.new()
		stage.position = at + Vector2(float(pose[1]), FEET)
		stage.scale = Vector2.ONE * SCALE
		stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(stage)
		_figure(stage, art, look, String(pose[0]))
	var title := UiStyle.label(_fitted(Ranks.title(role_id, maxi(1, rank * 5)), width - 12.0), 15, UiStyle.DUSK, at + Vector2(0, TITLE_AT))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(width, 0)
	add_child(title)


## `text` cut short to fit `width` in the page's type (French's longest
## titles run past their column), with "..." where it was cut.
static func _fitted(text: String, width: float) -> String:
	var font := UiStyle.body_font()
	var wide := func(words: String) -> float: return font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, UiStyle.TEXT).x
	if wide.call(text) <= width:
		return text
	var cut := text
	while cut.length() > 1 and wide.call(cut.strip_edges() + "...") > width:
		cut = cut.left(cut.length() - 1)
	return cut.strip_edges() + "..."


## The hero on `stage` (its origin at their feet) in one pose, wearing `look`.
func _figure(stage: Node2D, art: Dictionary, look: Dictionary, pose: String) -> void:
	var aura: Color = look["aura"]
	if aura.a > 0.0:
		var pool := Sprite2D.new()
		pool.texture = preload("res://scripts/player.gd")._glow()
		pool.position = Vector2(0, 2)
		# Smaller than in the world, so three poses' pools don't run together.
		pool.scale = Vector2.ONE * 0.5
		pool.modulate = Color(aura, 0.4)
		stage.add_child(pool)
	var trail: Color = look["trail"]
	if pose == "walk" and trail.a > 0.0:
		# Shed behind a walk to the right: drifting off to the left.
		var motes := RankLook.trail(trail)
		motes.local_coords = true
		motes.direction = Vector2(-1, -0.3)
		motes.initial_velocity_min = 14.0
		motes.initial_velocity_max = 20.0
		motes.preprocess = motes.lifetime
		motes.emitting = true
		stage.add_child(motes)
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = PunyArt.frames(art)
	sprite.self_modulate = art["tint"]
	sprite.position = Vector2(0, PunyArt.lift(art) - 3)
	stage.add_child(sprite)
	RankLook.wear(sprite, look)
	match pose:
		"front":
			sprite.animation = PunyArt.pick(sprite.sprite_frames, "idle", "down")
		"walk":
			sprite.animation = PunyArt.pick(sprite.sprite_frames, "walk", "right")
			sprite.frame = 1
		"swing":
			sprite.animation = PunyArt.pick(sprite.sprite_frames, art["attack"], "right")
			var strike: Array = preload("res://scripts/player.gd").STRIKE_FRAMES.get(art["attack"], [1, 2])
			sprite.frame = int(strike[0])
			var reach := Vector2(Juice.SLASH_REACH, -6) - Vector2(0, -3)
			if art["attack"] != "bow":
				var arc := Sprite2D.new()
				arc.texture = Juice.arc()
				arc.material = Lights.glow()
				arc.modulate = Juice.slash_color(art["attack"], "")
				arc.rotation = Juice.arc_turn(Vector2.RIGHT)
				arc.position = reach
				stage.add_child(arc)
			var glow: Color = look["weapon"]
			if glow.a > 0.0:
				var flare := Sprite2D.new()
				flare.texture = RankLook.flare()
				flare.material = Lights.glow()
				flare.modulate = glow
				flare.position = reach
				stage.add_child(flare)
