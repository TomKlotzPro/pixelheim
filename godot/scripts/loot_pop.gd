class_name LootPop
extends Node2D
## areas: combat
## A kill's win on its way to the hero (PIX-492): coins spring out of the
## slain foe in arcs, bounce once and glint, then sweep to the hero and tick
## into the purse; sparks of XP rise and sweep in; a drop hops out, lands
## and lies a moment in its rarity's glow. Each coin and spark that lands
## hands its share to the win's float (WorldFx.show_gains), which counts up
## in place and ends on what the kill paid. Only the look: Spoils credited
## all of it at the kill. Never with motion reduced (WorldFx.burst_gains).
##
## One node draws them all, coins and sparks in whole world pixels: a coin,
## a spark or a drop is a pooled entry in `_bits`, never a node, so a pack felled at once costs
## a few dozen draws. Its dice are its own, so a burst never moves the
## game's.

enum {COIN, SPARK, DROP, FLASH}

## Past this many in the air a win's shares land at once: nothing waits on
## a coin that was never drawn.
const MOST := 160
## Where on the hero they land, from the feet.
const PURSE := Vector2(0, -8)
## A coin's tick rises this much a coin, up to this many, while they keep
## landing within TICK_RUN_S of each other: a little brighter each one.
const TICK_STEP := 0.05
const TICK_MOST := 10
const TICK_RUN_S := 0.5
## How long the twinkle where one landed lasts.
const FLASH_S := 0.14

var world: Node2D
var fx: Node2D

## What flies now, each a pooled entry, and the spent ones to use again.
var _bits: Array[Dictionary] = []
var _spare: Array[Dictionary] = []
## Seconds of play this has seen (its own count of the frames' time, held
## with the world).
var _clock := 0.0
var _dice := RandomNumberGenerator.new()
var _glows: Node2D
var _view: Variant
var _streak := 0
var _ticked := -1.0

## This visit's bursts, for the harness (loot=): coins and sparks sprung,
## each drop's rarity, a boss's burst seen, and the gold the floats were due
## and have counted.
var coins := 0
var sparks := 0
var drops: PackedStringArray = []
var big := false
var gold_due := 0
var gold_counted := 0

static var _art := {}


func _ready() -> void:
	_dice.seed = 492
	z_index = Foes.OVER_TAGS - 1
	# Bright at night, as the win's words are (PIX-221).
	material = Lights.unshaded()
	_glows = Node2D.new()
	_glows.material = Lights.glow()
	_glows.draw.connect(_draw_glows)
	add_child(_glows)
	set_process(false)


## A foe that stood at `feet` bursts into `gains`: coins for its gold,
## sparks for its XP (more and wider for a `grand` win: a boss's, a named
## monster's), a drop for each item. Its float rises from `at` as the first
## of them lands, the items' rows with it.
func burst(gains: Dictionary, at: Vector2, feet: Vector2, grand := false) -> void:
	var now := _clock
	var purse: Array[Dictionary] = []
	var xp := LootBurst.shares(int(gains["xp"]), LootBurst.sparks(int(gains["xp"]), grand))
	var gold := LootBurst.shares(int(gains["gold"]), LootBurst.coins(int(gains["gold"]), grand))
	big = big or grand
	gold_due += int(gains["gold"])
	var wide := 1.7 if grand else 1.0
	for i in xp.size():
		var bit := _bit(SPARK, now, at)
		bit["from"] = feet + Vector2(0, -8)
		bit["rest"] = bit["from"] + Vector2(_dice.randf_range(-12, 12) * wide, _dice.randf_range(-20, -10) * wide)
		bit["leave"] = now + LootBurst.RISE_S + i * minf(LootBurst.STAGGER_S, LootBurst.SWEEP_S / xp.size())
		bit["win"] = {"xp": xp[i], "gold": 0, "items": []}
		bit["whole"] = gains
		purse.append(bit)
	sparks += xp.size()
	# The coins leave after the first spark is in (LootBurst.RISE_S): the
	# float is up, its XP on it, when the gold starts to count.
	var turn := _dice.randf() * TAU
	for i in gold.size():
		var bit := _bit(COIN, now, at)
		var way := turn + TAU * i / gold.size() + _dice.randf_range(-0.3, 0.3)
		bit["from"] = feet
		# Round the foe's feet, the ring flattened as the ground is seen.
		bit["rest"] = (feet + Vector2(cos(way), sin(way) * 0.55) * _dice.randf_range(9, 18) * wide).round()
		bit["height"] = _dice.randf_range(10, 16) * wide
		bit["out"] = LootBurst.OUT_S + _dice.randf_range(0.0, 0.06)
		bit["leave"] = now + LootBurst.OUT_S + 0.06 + LootBurst.BOUNCE_S + LootBurst.REST_S + i * minf(LootBurst.STAGGER_S, LootBurst.SWEEP_S / gold.size())
		bit["win"] = {"xp": 0, "gold": gold[i], "items": []}
		bit["whole"] = gains
		purse.append(bit)
	coins += gold.size()
	var items: Array = gains["items"]
	for i in mini(items.size(), LootBurst.DROPS):
		var item: Dictionary = items[i]
		var rarity := String(item["rarity"])
		var bit := _bit(DROP, now, at)
		var side := (1.0 if i % 2 == 0 else -1.0) * (12.0 + 6.0 * (i / 2))
		bit["from"] = feet
		bit["rest"] = (feet + Vector2(side, 5.0 + _dice.randf_range(-2, 2))).round()
		bit["height"] = 14.0
		bit["out"] = LootBurst.OUT_S + 0.04
		bit["shine"] = LootBurst.shine(rarity)
		bit["tone"] = WorldFx.GAIN_TONES.get(rarity, UiStyle.CREAM)
		bit["art"] = ItemIcons.texture(String(item["id"]))
		bit["leave"] = now + float(bit["out"]) + LootBurst.BOUNCE_S + (LootBurst.BEAM_S if bit["shine"] == "beam" else LootBurst.LIE_S)
		# It only goes to the pack: its row is the purse's first lander's.
		bit["lands"] = float(bit["leave"]) + LootBurst.FLY_S
		drops.append(rarity)
	for bit in purse:
		bit["lands"] = float(bit["leave"]) + LootBurst.FLY_S
	# The items' rows come up with the purse's, on the first to land, so the
	# purse's line never pushes them up a row after they showed.
	var rows := {"xp": 0, "gold": 0, "items": items}
	if purse.is_empty():
		fx.show_gains(rows, at, false)
	else:
		purse[0]["win"]["items"] = items
	if grand and world != null:
		fx.skill_flash(feet, UiStyle.GOLD)
	# Past the most: landed at once.
	if _bits.size() > MOST:
		_settle()
	set_process(not _bits.is_empty())


## A pooled entry, born `now`, its float at `at`.
func _bit(kind: int, now: float, at: Vector2) -> Dictionary:
	var bit: Dictionary = _spare.pop_back() if not _spare.is_empty() else {}
	bit.clear()
	bit["kind"] = kind
	bit["born"] = now
	bit["at"] = at
	bit["out"] = LootBurst.OUT_S
	bit["height"] = 0.0
	bit["spin"] = _dice.randf() * 4.0
	bit["lands"] = now
	_bits.append(bit)
	return bit


func _process(delta: float) -> void:
	_clock += delta
	# Another place: what flew stays behind with it (all of it was paid).
	if world != null and world.view != _view:
		if _view != null:
			_spare.append_array(_bits)
			_bits.clear()
		_view = world.view
	var i := 0
	# Oldest first, so a float counts up in the order its coins left.
	while i < _bits.size():
		var bit := _bits[i]
		if _clock >= float(bit["lands"]):
			_bits.remove_at(i)
			_land(bit)
			_spare.append(bit)
		else:
			i += 1
	queue_redraw()
	_glows.queue_redraw()
	if _bits.is_empty():
		set_process(false)


## Everything in the air lands now, its shares counted (too many at once).
func _settle() -> void:
	var flying := _bits.duplicate()
	_bits.clear()
	for bit: Dictionary in flying:
		if bit["kind"] != FLASH:
			_land(bit, true)
		_spare.append(bit)


## One reached the hero: its share goes on the float; a coin ticks, a
## little higher and brighter than the one before, and each leaves a
## twinkle where it landed (not when `quiet`: landed undrawn).
func _land(bit: Dictionary, quiet := false) -> void:
	var kind: int = bit["kind"]
	if kind == FLASH:
		return
	if bit.has("win"):
		gold_counted += int(bit["win"]["gold"])
		fx.show_gains(bit["win"], bit["at"], false)
	if quiet:
		return
	var tone: Color = UiStyle.GOLD
	var strength := 0.6
	if kind == COIN:
		_streak = mini(_streak + 1, TICK_MOST) if _clock - _ticked <= TICK_RUN_S else 0
		_ticked = _clock
		strength = 0.45 + 0.55 * _streak / TICK_MOST
		# Off the game's dice: a tick's pitch is its place in the run.
		Sound.play("coin_gain", false, 1.0 + TICK_STEP * _streak)
	elif kind == SPARK:
		tone = WorldFx.GAIN_TONES["xp"]
	else:
		tone = bit["tone"]
	var flash := _bit(FLASH, _clock, bit["at"])
	flash["lands"] = _clock + FLASH_S
	flash["tone"] = tone
	flash["strength"] = strength
	flash["from"] = Vector2(_dice.randf_range(-3, 3), _dice.randf_range(-3, 3)).round()


## The floats still to come up, or to count on: each burst with a share in
## the air as {"at", "gains" (the whole win it will read)}, so what stands
## clear of the floats (a title card) stands clear of these too.
func to_come() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bit in _bits:
		if bit.has("whole") and not out.any(func(due: Dictionary) -> bool: return is_same(due["gains"], bit["whole"])):
			out.append({"at": bit["at"], "gains": bit["whole"]})
	return out


## Where the hero's purse is, or `otherwise` with no hero (a test's stage).
func _purse(otherwise: Vector2) -> Vector2:
	if world == null or world.player == null:
		return otherwise
	return world.player.global_position + PURSE


## Where a coin, a spark or a drop is at `t`: on its hop out, its bounce,
## at rest, or on its sweep to the hero.
func _where(bit: Dictionary, t: float) -> Vector2:
	var rest: Vector2 = bit["rest"]
	if t >= float(bit["leave"]):
		return LootBurst.sweep(rest, _purse(bit["at"]), (t - float(bit["leave"])) / LootBurst.FLY_S)
	var age: float = t - float(bit["born"])
	if bit["kind"] == SPARK:
		return LootBurst.hop(bit["from"], rest, 0.0, age / (float(bit["leave"]) - float(bit["born"])))
	var out: float = bit["out"]
	if age < out:
		return LootBurst.hop(bit["from"], rest, bit["height"], age / out)
	return LootBurst.hop(rest, rest, float(bit["height"]) * 0.3, (age - out) / LootBurst.BOUNCE_S)


func _draw() -> void:
	var shade := Color(0, 0, 0, 0.3)
	for bit in _bits:
		var age: float = _clock - float(bit["born"])
		var at := _where(bit, _clock) if bit["kind"] != FLASH else Vector2.ZERO
		match bit["kind"]:
			COIN:
				var landed: float = float(bit["out"]) + LootBurst.BOUNCE_S
				var lying := age >= landed and _clock < float(bit["leave"])
				if age < landed:
					# Its shadow on the ground under the arc.
					var ground: Vector2 = LootBurst.hop(bit["from"], bit["rest"], 0.0, age / float(bit["out"]))
					draw_rect(Rect2(roundf(ground.x) - 1, roundf(ground.y), 3, 1), shade)
				# It turns in the air and lies face up.
				var face := 0 if lying else int(age / 0.07 + float(bit["spin"])) % 4
				draw_texture(_coin([0, 1, 2, 1][face]), (at - Vector2(2, 4)).round())
				# The glint: as it comes to rest, and again as it leaves.
				if lying and (age - landed < 0.09 or float(bit["leave"]) - _clock < 0.07):
					_twinkle((at - Vector2(1, 3)).round(), UiStyle.KEY_LIGHT, 1)
			SPARK:
				var tone: Color = WorldFx.GAIN_TONES["xp"]
				# Its tail: where it was a frame and two ago.
				for back: int in [2, 1]:
					var was := _where(bit, maxf(float(bit["born"]), _clock - back * 0.03)).round()
					draw_rect(Rect2(was, Vector2.ONE), Color(tone, 0.25 * (3 - back)))
				draw_rect(Rect2(at.round() - Vector2.ONE, Vector2(2, 2)), tone)
				draw_rect(Rect2(at.round() - Vector2.ONE, Vector2.ONE), UiStyle.KEY_LIGHT)
			DROP:
				var art: Texture2D = bit["art"] if bit["art"] != null else _pouch()
				# Its icon as the float beside it shows it (WorldFx.GAIN_ICON:
				# two screen pixels an art pixel, on the screen's grid); at the
				# world's own scale an apple stood as tall as the hero.
				var size := art.get_size() * WorldFx.GAIN_ICON
				if age < float(bit["out"]) + LootBurst.BOUNCE_S:
					var ground: Vector2 = LootBurst.hop(bit["from"], bit["rest"], 0.0, age / float(bit["out"]))
					draw_rect(Rect2(roundf(ground.x) - 3, roundf(ground.y), 7, 1), shade)
				draw_texture_rect(art, Rect2(((at - Vector2(size.x / 2.0, size.y - 2.0)) * CameraRig.ZOOM).round() / CameraRig.ZOOM, size), false)
			FLASH:
				var strength: float = bit["strength"]
				var fade := 1.0 - age / FLASH_S
				_twinkle((_purse(bit["at"]) + bit["from"]).round(), Color(bit["tone"], fade), 1 + int(strength * 2.0))


## A drop's glow and beam where it lies, a spark's halo, a landing's light:
## added onto the world under them.
func _draw_glows() -> void:
	for bit in _bits:
		var age: float = _clock - float(bit["born"])
		match bit["kind"]:
			SPARK:
				_halo(_small(), _where(bit, _clock), Color(WorldFx.GAIN_TONES["xp"], 0.5))
			FLASH:
				_halo(_small(), _purse(bit["at"]) + bit["from"], Color(bit["tone"], float(bit["strength"]) * (1.0 - age / FLASH_S)))
			DROP:
				var landed: float = float(bit["out"])
				if bit["shine"] == "" or age < landed:
					continue
				var tone: Color = bit["tone"]
				var at := _where(bit, _clock)
				var lies: float = float(bit["leave"]) - float(bit["born"]) - landed
				# Out as it leaves for the pack.
				var left := clampf((float(bit["leave"]) + LootBurst.FLY_S - _clock) / LootBurst.FLY_S, 0.0, 1.0)
				_halo(_soft(), at - Vector2(0, 4), Color(tone, (0.5 + 0.15 * sin(_clock * 7.0)) * left))
				if bit["shine"] == "beam" and _clock < float(bit["leave"]):
					# A short beam: full as it lands, thinning as it lies.
					var beam := _beam()
					var strong := 1.0 - 0.7 * clampf((age - landed) / lies, 0.0, 1.0)
					_glows.draw_texture(beam, (at - Vector2(beam.get_width() / 2.0, beam.get_height() + 2.0)).round(), Color(tone, strong))


## A glow's texture centred on `at`, in whole pixels.
func _halo(glow: Texture2D, at: Vector2, tone: Color) -> void:
	_glows.draw_texture(glow, (at - glow.get_size() / 2.0).round(), tone)


## A plus of pixels about `at`, its arms `arm` long: a glint, a landing.
func _twinkle(at: Vector2, tone: Color, arm: int) -> void:
	draw_rect(Rect2(at - Vector2(arm, 0), Vector2(arm * 2 + 1, 1)), tone)
	draw_rect(Rect2(at - Vector2(0, arm), Vector2(1, arm * 2 + 1)), tone)
	draw_rect(Rect2(at, Vector2.ONE), Color(UiStyle.KEY_LIGHT, tone.a))


## What the harness reports (loot=): "coins 6 flying 3 sparks 4 drops
## 1:epic counted 5/8", " big" after a boss's or a named monster's burst;
## "" before any burst.
func summary() -> String:
	if coins + sparks + drops.size() == 0:
		return ""
	var flying := _bits.filter(func(bit: Dictionary) -> bool: return bit["kind"] != FLASH).size()
	var fell := "%d:%s" % [drops.size(), "+".join(drops)] if not drops.is_empty() else "0"
	var said: Array = ["coins", coins, "flying", flying, "sparks", sparks, "drops", fell, "counted", "%d/%d" % [gold_counted, gold_due]]
	return " ".join(said.map(str)) + (" big" if big else "")


# --- The art: drawn here at the world's scale, a pixel a world pixel ---------

## A coin five pixels across, on the purse's palette (UiStyle.coin is the
## HUD's, drawn for the canvas: at a float's scale its pixels aren't the
## world's): face on, turning, edge on.
static func _coin(turn: int) -> Texture2D:
	var faces := [
		[".ooo.", "oLGGo", "oGGBo", "oGBBo", ".ooo."],
		["..o..", ".oLo.", ".oGo.", ".oBo.", "..o.."],
		["..o..", "..L..", "..G..", "..B..", "..o.."],
	]
	return _drawn("coin%d" % turn, faces[turn])


## A tied pouch, for a drop with no icon of its own.
static func _pouch() -> Texture2D:
	return _drawn("pouch", ["..ooo..", ".oWWWo.", "..oCo..", ".oLWWo.", "oLWWWDo", "oWWWDDo", ".ooooo."])


static func _drawn(key: String, rows: Array) -> Texture2D:
	if not _art.has(key):
		var colors := {
			"o": UiStyle.NIGHT, "L": UiStyle.BRASS_LIGHT, "G": UiStyle.GOLD, "B": UiStyle.BRASS,
			"W": UiStyle.WOOD_LIGHT, "D": UiStyle.WOOD_DARK, "C": UiStyle.CREAM,
		}
		var art := Image.create(String(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
		art.fill(Color(0, 0, 0, 0))
		for y in rows.size():
			for x in String(rows[y]).length():
				if colors.has(rows[y][x]):
					art.set_pixel(x, y, colors[rows[y][x]])
		_art[key] = ImageTexture.create_from_image(art)
	return _art[key]


## A drop's soft glow and a spark's halo: white ovals fading out in a few
## steps, pixel by pixel (no smooth gradient among the world's pixels).
static func _soft() -> Texture2D:
	return _oval("soft", 23, 15)


static func _small() -> Texture2D:
	return _oval("small", 7, 7)


static func _oval(key: String, wide: int, tall: int) -> Texture2D:
	if not _art.has(key):
		var art := Image.create(wide, tall, false, Image.FORMAT_RGBA8)
		for y in tall:
			for x in wide:
				var off := Vector2((x + 0.5) / wide - 0.5, (y + 0.5) / tall - 0.5).length() * 2.0
				art.set_pixel(x, y, Color(1, 1, 1, ceilf(clampf(1.0 - off, 0.0, 1.0) * 4.0) / 4.0 * 0.8))
		_art[key] = ImageTexture.create_from_image(art)
	return _art[key]


## An epic drop's beam: a column of light five pixels wide, its core the
## brightest, fading out toward the top in steps.
static func _beam() -> Texture2D:
	if not _art.has("beam"):
		var tall := 40
		var art := Image.create(5, tall, false, Image.FORMAT_RGBA8)
		for y in tall:
			var up := ceilf(float(y + 1) / tall * 6.0) / 6.0
			for x in 5:
				art.set_pixel(x, y, Color(1, 1, 1, [0.2, 0.55, 1.0, 0.55, 0.2][x] * up))
		_art["beam"] = ImageTexture.create_from_image(art)
	return _art["beam"]
