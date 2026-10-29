extends Screen
## areas: title
## The title (PIX-139): Pixelheim's street at night under the Ashen Mountain
## (TitleScene, alive under a drifting camera since PIX-249), PIXELHEIM cut
## in gold above it, and the menu: Continue, New Game (hero creation), the
## saves, options, or What's new. W/S choose, E or Enter takes it. The world
## waits paused behind, resting from drawing while the backdrop covers it.
## A launch arrives through its entrance (PIX-392, TitleEntrance): down from
## the stars, the dragon's pass, the name forged in fire, the menu last. The
## menu hangs on wooden planks (GegX's kit; the game's own planks without
## it), the chosen one lifted, lit and burning between two flames.

const VIEW := Vector2(1280, 720)
const LOGO_Y := 84.0
## The shine crosses the logo this long after the title opens, then this often (s).
const SHINE_FIRST_S := 0.7
const SHINE_EVERY_S := 8.0
## The picture the game loaded under (PIX-296: the boot splash and the web
## page's, drawn by tools/splash.py), which a launch's title rises out of.
const SPLASH := "res://assets/splash.png"
## The word about the slot in hand (PIX-303): this far under the menu, over
## the night's dark sky rather than the lit street, two lines at most.
const NOTE_GAP := 20.0
const NOTE_WIDTH := 1000.0
## The menu's planks (PIX-392): where the first hangs (close under the
## tagline, so with five planks the note under them still ends over the
## dark, above the bunting and the far bank's windows), the gap between
## them, the narrowest they are, how far the chosen one lifts (px) and how
## quickly it and the flames follow the choice (a share a second).
const MENU_Y := 222.0
const MENU_GAP := 4.0
const PLANK_WIDTH := 340.0
const LIFT := 3.0
const FOLLOW := 16.0
## The flames either side of the chosen plank: FireArt's tongue at this
## many canvas pixels an art pixel, this far off the plank's sides.
const FLAME_SCALE := 2.0
const FLAME_GAP := 10.0
## NEW stands this far past its plank's right end, clear of the flame.
const BADGE_GAP := 44.0

## Whether this session's first title has risen: later ones (back from the
## saves) rise out of the night's colour.
static var _risen := false

var world: Node
var scene: TitleScene
var options: Array[Dictionary] = []
var selected := 0
## The planks hang on it (it rises as a whole back from the saves).
var menu: Control
## Per line: its plank, where it hangs, how far the choice lifts it and how
## far below the entrance still holds it.
var planks: Array[Button] = []
var homes: Array[Vector2] = []
var lifts: Array[float] = []
var rises: Array[float] = []
## The chosen plank's flames and the warm light behind it, gliding with
## the choice.
var chosen_fire: Node2D
## Where the flames glide, unrounded (they stand on the whole pixel).
var fire_y := 0.0
var flames: Array[AnimatedSprite2D] = []
var warmth: Sprite2D
## The launch's entrance while it plays (TitleEntrance), else null.
var entrance: TitleEntrance
var footer: Label
var shine: ColorRect
## The line under the menu (PIX-303, PIX-316), and what it last said: slot
## (about the slot in hand) or full (New Game with no slot free), for the
## harness's report.
var note: Label
var said := ""
var logo: Control
## The name white hot over its gold as the forge leaves it, and the fire's
## glow round its letters (PIX-392).
var heat: Label
var ember: Label
var tagline: Label
## The game's version: the newest release in What's new.
var version := ""


## Its own entrance, not the screens' ease (PIX-212).
func _eases_in() -> bool:
	return false


func _open() -> void:
	layer = 7
	Sound.play_track("title")
	Sound.set_ambience("")
	scene = TitleScene.new()
	add_child(scene)
	_rest_world(true)
	# A full screen: the HUD steps aside under it (PIX-346).
	_put_hud_aside()
	_vignette()
	_logo()
	_card()
	_arrive()


func _exit_tree() -> void:
	_rest_world(false)
	super()


## The backdrop covers the whole view, so the world under it rests from
## drawing until the title goes - its map, its actors and its passes over
## them (PIX-249): that pays for the backdrop's own light and glow in the
## browser. A phone's wider view shows the world round the title, so there
## it keeps drawing.
func _rest_world(resting: bool) -> void:
	if world == null or not is_instance_valid(world):
		return
	if resting and Touch.view_size(self) != Touch.DESIGN:
		return
	world.visible = not resting
	if world.lights != null:
		world.lights.rest(resting)


## The corners fall into night, so the eye rests on the middle.
func _vignette() -> void:
	var shade := Gradient.new()
	shade.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	shade.colors = PackedColorArray([Color(0.02, 0.01, 0.05, 0.0), Color(0.02, 0.01, 0.05, 0.12), Color(0.02, 0.01, 0.05, 0.6)])
	var texture := GradientTexture2D.new()
	texture.gradient = shade
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.45)
	texture.fill_to = Vector2(1.15, 0.45)
	var vignette := TextureRect.new()
	vignette.texture = texture
	vignette.size = VIEW
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)


## PIXELHEIM cut deep in gold: a block of letters stepping back into dark
## bronze, a lighter top to the face, and a shine that crosses it now and then.
func _logo() -> void:
	var font := FontVariation.new()
	font.base_font = UiStyle.logo_font()
	font.spacing_glyph = 4
	logo = Control.new()
	logo.position = Vector2(0, LOGO_Y)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var depth := 8
	for step in range(depth, 0, -2):
		var back := _logo_word(font, Color("4a2408") if step > depth / 2 else Color("8a4f14"))
		back.position.y = step
		if step == depth:
			back.add_theme_color_override("font_outline_color", Color("140a03"))
			back.add_theme_constant_override("outline_size", 14)
		logo.add_child(back)
	ember = _logo_word(font, Color(1.0, 0.5, 0.15, 0.0))
	ember.add_theme_color_override("font_outline_color", Color(1.0, 0.42, 0.1, 0.55))
	ember.add_theme_constant_override("outline_size", 26)
	ember.material = TitleScene.additive()
	ember.modulate.a = 0.0
	logo.add_child(ember)
	var face := _logo_word(font, UiStyle.GOLD)
	face.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	logo.add_child(face)
	var top := ColorRect.new()
	top.color = Color("ffe08f")
	top.size = Vector2(VIEW.x, 30)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.add_child(top)
	shine = ColorRect.new()
	shine.color = Color(1, 0.98, 0.9, 0.75)
	shine.size = Vector2(18, 140)
	shine.position = Vector2(-200, -30)
	shine.rotation = 0.4
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# It sweeps in from off the screen on purpose: not a layout to fit.
	shine.set_meta(Layout.DECOR, true)
	face.add_child(shine)
	heat = _logo_word(font, Color("fff4d8"))
	heat.add_theme_color_override("font_outline_color", Color("ff8a2a"))
	heat.add_theme_constant_override("outline_size", 6)
	heat.modulate.a = 0.0
	logo.add_child(heat)
	tagline = UiStyle.label("The village burned. You stayed.", 18, UiStyle.CREAM, Vector2(0, LOGO_Y + 92))
	tagline.custom_minimum_size = Vector2(VIEW.x, 0)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_shadowed(tagline))


## Words over the scene keep a night shadow, so they read wherever the
## drifting scene puts a lamplit wall or the moon behind them.
static func _shadowed(words: Label) -> Label:
	words.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.05, 0.9))
	words.add_theme_constant_override("shadow_offset_x", 2)
	words.add_theme_constant_override("shadow_offset_y", 2)
	return words


func _logo_word(font: Font, color: Color) -> Label:
	var word := Label.new()
	word.text = "PIXELHEIM"
	word.add_theme_font_override("font", font)
	word.add_theme_font_size_override("font_size", 64)
	word.add_theme_color_override("font_color", color)
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	word.size = Vector2(VIEW.x, 72)
	word.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return word


## How the title arrives. A launch plays its entrance (PIX-392,
## TitleEntrance), rising out of the loading screen's picture (PIX-296: the
## boot splash, the web page's) as the camera starts among the stars; harness
## runs skip it (their keys walk the menu) unless `--title-at` asks for it.
## Back from the saves, the scene rises out of the night's colour and the
## menu rises in line by line. Then the shine crosses the name now and then.
func _arrive() -> void:
	var launch := not _risen
	_risen = true
	if GameState.settings.reduce_motion:
		return
	if launch and (world == null or not world.harness or HarnessFlags.given().has("--title-at")):
		enter(_veil(true, false))
		return
	var veil := _veil(launch, true)
	var lift := veil.create_tween()
	lift.tween_property(veil, "modulate:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE)
	lift.tween_callback(veil.queue_free)
	menu.create_tween().tween_property(menu, "position:y", 0.0, 0.5).from(12.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	for i in planks.size():
		planks[i].modulate.a = 0.0
		planks[i].create_tween().tween_property(planks[i], "modulate:a", 1.0, 0.3).set_delay(0.08 * i)
	footer.modulate.a = 0.0
	footer.create_tween().tween_property(footer, "modulate:a", 1.0, 0.6).set_delay(0.4)
	_shine()


## The launch's entrance, out of `veil`, until it settles.
func enter(veil: Control) -> void:
	entrance = TitleEntrance.new()
	entrance.screen = self
	entrance.scene = scene
	entrance.veil = veil
	entrance.on_done = _settled
	add_child(entrance)


func _settled() -> void:
	entrance = null
	_shine()


## The shine crossing the name, now and then.
func _shine() -> void:
	var sweep := shine.create_tween().set_loops()
	sweep.tween_interval(SHINE_FIRST_S)
	sweep.tween_property(shine, "position:x", VIEW.x + 200, 1.1).from(-200.0).set_trans(Tween.TRANS_SINE)
	sweep.tween_interval(SHINE_EVERY_S - SHINE_FIRST_S)


## Where the entrance is, for the report: its beat, settled once it's over.
func beat() -> String:
	return TitleEntrance.beat_at(entrance.t) if entrance != null else "settled"


## What the title rises out of: on a launch the loading screen's picture,
## at the canvas's size in whole pixels like the boot splash, under the name
## when it holds still there (and over the line below it, which rises with
## the scene), else over everything; not on a launch, or on a phone's wider
## canvas, the night's colour over everything.
func _veil(launch: bool, under_name: bool) -> Control:
	if launch and Touch.view_size(self) == Touch.DESIGN and ResourceLoader.exists(SPLASH):
		var picture := TextureRect.new()
		picture.texture = load(SPLASH)
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_SCALE
		picture.size = VIEW
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(picture)
		if under_name:
			move_child(picture, logo.get_index())
			move_child(tagline, picture.get_index())
		return picture
	var night := ColorRect.new()
	night.color = TitleScene.SKY[1]
	night.set_anchors_preset(Control.PRESET_FULL_RECT)
	night.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(night)
	return night


func _card() -> void:
	menu = Control.new()
	menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(menu)
	version = load("res://scripts/changelog_screen.gd").releases()[0]["version"]
	if not GameState.standing_in:
		options.append({"label": Text.t("Continue  %s, Lv %d") % [GameState.hero.hero_name, GameState.hero.level], "action": _continue})
	options.append({"label": "New Game", "action": _new_game})
	options.append({"label": "Saves", "action": _saves})
	options.append({"label": "Options", "action": _options})
	options.append({"label": "What's new", "action": _whats_new})
	_draw_menu()
	# The line under the menu, for a word the title has to say.
	note = _shadowed(Layout.wrapped(UiStyle.label("", 13, UiStyle.CREAM), NOTE_WIDTH))
	note.position = Vector2((VIEW.x - NOTE_WIDTH) / 2.0, homes[-1].y + UiStyle.PLANK + NOTE_GAP)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Placed, so kept to its lines once they know their width.
	add_child(Layout.hugging(note))
	# A word about the slot in hand, said once (PIX-303): the one this launch
	# opened can't be read (so no Continue, and New Game makes its hero in
	# a free slot), or its hero is the save before, the last unreadable.
	if GameState.slot_note != "":
		_say("slot", GameState.slot_note)
		GameState.slot_note = ""
	# A browser that won't keep saves says so before anyone plays (PIX-200).
	if not GameState.saves_kept():
		var warning := UiStyle.label("This browser window won't keep your saves (a private window?). Your hero lasts only while it's open.", 13, UiStyle.LAMP, Vector2(0, 664))
		warning.custom_minimum_size = Vector2(VIEW.x, 0)
		warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_shadowed(warning))
	# The version line opens What's new (the web's changelog link).
	footer = UiStyle.label(Text.t("v%s  ·  What's new") % version, 13, UiStyle.DUSK, Vector2(0, 690))
	footer.custom_minimum_size = Vector2(VIEW.x, 0)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.mouse_filter = Control.MOUSE_FILTER_STOP
	footer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	footer.mouse_entered.connect(func() -> void: footer.add_theme_color_override("font_color", UiStyle.GOLD))
	footer.mouse_exited.connect(func() -> void: footer.add_theme_color_override("font_color", UiStyle.DUSK))
	footer.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_whats_new()
	)
	add_child(_shadowed(footer))


## The menu on wooden planks hung one under another (PIX-392), the words
## in the name's pixel type: GegX's planks with the kit (ink on the page,
## the chosen one red), the game's own without it. Every plank as wide as
## the widest, so a long first line ("Continue  name, Lv N") widens them all
## about the middle. The mouse chooses by pointing.
func _draw_menu() -> void:
	Layout.clear(menu)
	planks.clear()
	homes.clear()
	lifts.clear()
	rises.clear()
	flames.clear()
	chosen_fire = Node2D.new()
	menu.add_child(chosen_fire)
	warmth = Sprite2D.new()
	warmth.texture = TitleScene.glow_texture(32, Color("ff9a40"), 0.3, 5)
	warmth.material = TitleScene.additive()
	chosen_fire.add_child(warmth)
	var width := PLANK_WIDTH
	for index in options.size():
		var plank := UiStyle.button(options[index]["label"], _take.bind(index))
		plank.add_theme_font_override("font", UiStyle.logo_font())
		plank.add_theme_font_size_override("font_size", 16)
		plank.mouse_entered.connect(_point.bind(index))
		menu.add_child(plank)
		planks.append(plank)
		width = maxf(width, plank.get_combined_minimum_size().x + 32.0)
	for index in planks.size():
		homes.append(Vector2(roundf((VIEW.x - width) / 2.0), MENU_Y + index * (UiStyle.PLANK + MENU_GAP)))
		lifts.append(LIFT if index == selected else 0.0)
		rises.append(0.0)
		planks[index].size = Vector2(width, UiStyle.PLANK)
		planks[index].position = homes[index]
		# NEW past its plank: notes not yet read.
		if options[index]["action"] == _whats_new and GameState.settings.seen_version != version:
			planks[index].add_child(_new_badge())
	warmth.position.x = VIEW.x / 2.0
	warmth.scale = Vector2((width + 120.0) / 64.0, 1.4)
	for side in 2:
		var flame := AnimatedSprite2D.new()
		flame.sprite_frames = FireArt.frames("tongue", side)
		flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		flame.centered = false
		flame.scale = Vector2.ONE * FLAME_SCALE
		var size: Vector2i = FireArt.KINDS["tongue"]
		flame.offset = -Vector2(size.x / 2, size.y / 2 + 2)
		flame.position.x = homes[0].x - FLAME_GAP - FLAME_SCALE * size.x / 2.0 if side == 0 else homes[0].x + width + FLAME_GAP + FLAME_SCALE * size.x / 2.0
		flame.play()
		flame.frame = side * 5
		if GameState.settings.reduce_motion:
			flame.stop()
		chosen_fire.add_child(flame)
		flames.append(flame)
	_show_choice()
	_follow(1.0)


## The chosen plank lit: the kit's red one (brass without it), its words in
## rubric, and it stays lit under the mouse; the rest plain. Planks are
## restyled, not rebuilt, so a pointer resting on the menu never takes the
## choice back from the keys.
func _show_choice() -> void:
	for index in planks.size():
		var plank := planks[index]
		UiStyle.focus(plank, index == selected)
		plank.add_theme_stylebox_override("hover", plank.get_theme_stylebox("normal") if index == selected else UiStyle.plank(true, 6))


func _process(delta: float) -> void:
	_follow(1.0 - exp(-FOLLOW * delta))


## Each frame, `share` of the way: the chosen plank lifts and the rest
## settle, the flames and the warm light behind glide to it, each plank
## kept as far below as the entrance holds it, on whole pixels.
func _follow(share: float) -> void:
	if planks.is_empty():
		return
	for index in planks.size():
		lifts[index] = lerpf(lifts[index], LIFT if index == selected else 0.0, share)
		planks[index].position.y = roundf(homes[index].y - lifts[index] + rises[index])
	var middle := homes[selected].y + UiStyle.PLANK / 2.0 - LIFT + rises[selected]
	fire_y = lerpf(fire_y, middle, share)
	chosen_fire.position.y = roundf(fire_y)


func _point(index: int) -> void:
	# Harness runs drive keys only: the desktop's pointer must not choose.
	if world != null and world.harness:
		return
	if index != selected:
		_choose(index)


## The choice moved to `index`, heard as the pages' pen tick.
func _choose(index: int) -> void:
	selected = index
	Sound.play_ui("tick")
	_show_choice()


## NEW, in rubric red past its plank: notes not yet read.
func _new_badge() -> Control:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.LAMP, UiStyle.NIGHT, 3))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(UiStyle.strong(Text.t("NEW"), 12, UiStyle.CREAM))
	# Past the plank's right end and the flame there, middles level, growing
	# rightward: it takes no part in the plank's width.
	badge.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	badge.offset_left = BADGE_GAP
	badge.offset_right = BADGE_GAP
	badge.grow_horizontal = Control.GROW_DIRECTION_END
	badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	return badge


func _command(event: InputEvent) -> Callable:
	var command := Callable()
	# While the entrance plays, any key or button goes straight to the
	# settled title, and does only that.
	if entrance != null:
		var press := (event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
		return entrance.skip if press else command
	if event.is_action_pressed("move_up") or event.is_action_pressed("ui_up"):
		command = func() -> void: _choose(wrapi(selected - 1, 0, options.size()))
	elif event.is_action_pressed("move_down") or event.is_action_pressed("ui_down"):
		command = func() -> void: _choose(wrapi(selected + 1, 0, options.size()))
	elif event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		command = _take.bind(selected)
	return command


## Esc never closes the title: there is nowhere under it to go.
func _closes_on(_event: InputEvent) -> bool:
	return false


func _take(index: int) -> void:
	selected = index
	options[index]["action"].call()


## A word on the line under the menu; `kind` is what it's about.
func _say(kind: String, text: String) -> void:
	said = kind
	note.text = text


func _continue() -> void:
	_leave()


## New Game: the opening (PIX-31), skippable, then hero creation.
## It's the one way to a new hero (PIX-316), and it never writes over one:
## with every slot holding a save, it says so and starts nothing.
func _new_game() -> void:
	if not GameState.room_for_hero():
		Sound.play_ui("deny")
		_say("full", "Every slot holds a save. Delete one in Saves to start a new hero.")
		return
	var opening := Cutscene.new()
	opening.scene_id = "opening"
	opening.on_done = _create_hero
	add_child(opening)


func _create_hero() -> void:
	var creation := preload("res://scripts/create_screen.gd").new()
	creation.world = world
	add_child(creation)


## The saves over the title, like Options: Esc comes back here, and playing
## the hero in hand is Continue.
func _saves() -> void:
	var screen := preload("res://scripts/saves_screen.gd").new()
	screen.on_play_current = _continue
	add_child(screen)
	screen.layer = layer + 1


## Every release's notes, over the title (Esc hands back).
func _whats_new() -> void:
	add_child(preload("res://scripts/changelog_screen.gd").new())
	# Read: the badge goes, until the next version.
	if GameState.settings.seen_version != version:
		GameState.settings.seen_version = version
		GameState.settings.save_file()
		_draw_menu()


## Options over the title, so sound and keys can be set before a hero
## exists; Esc hands back to the menu.
func _options() -> void:
	var screen := preload("res://scripts/options_screen.gd").new()
	screen.world = world
	add_child(screen)
	# Over the title, which shares its layer (Tom: "Options does nothing").
	screen.layer = layer + 1


func _leave() -> void:
	GameState.title_seen = true
	close()
	world.soundscape.refresh()
