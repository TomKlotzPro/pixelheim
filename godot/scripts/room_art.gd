class_name RoomArt
## A keeper's room its own (PIX-315): Liane keeps the stars in her
## observatory, and nothing in Shade's packs is a telescope, a star chart or
## a globe of the sky. So these are drawn here, a pixel a character in his
## palette (LampArt.PALETTE), and stand in a room's layout as any piece does
## (interiors.json: a vignette's `art`, [x, y, name]): the telescope on its
## tripod aimed up at a window, the chart of the two skies hung on the back
## wall, the celestial globe on its stand. Each takes whole cells, its top
## left on the cell it names; what stands on the floor blocks it.

const PIECES := {
	# A brass telescope on a wooden tripod, its tube up and to the right.
	"telescope": [
		"................................",
		"................................",
		"................................",
		"................................",
		"............................o...",
		".........................oooGo..",
		"........................oeeeho..",
		"......................ooeeeeyo..",
		"......................weecccGo..",
		"...................ooowecbbbGo..",
		"..................oeeewcbmmmGo..",
		"...............oooecccwbmwwwoo..",
		"..............oewecbbbwmwooo....",
		"...........oooecwcbmmmdwo.......",
		"..........oeeecbwbmooooo........",
		".......oooecccbmdmo.............",
		"......oeewcbbbmoooo.............",
		"....ooeccwbmmmolllo.............",
		"...oeecbbwmooooiiio.............",
		".ooebbbmmdo...oiiio.............",
		".oebmmmooo....oooooo............",
		".obmooo.......obwbwo............",
		".omo.........obwddbwo...........",
		"..o.........obwoddbwo...........",
		"............obwoddobwo..........",
		"...........obwooddoobwo.........",
		"..........obwo.oddoobwo.........",
		"..........obwo.oddo.obwo........",
		".........obwo..oddo.obwo........",
		"........obwo...oddo..obwo.......",
		"........obwo...oooo..obwo.......",
		".......oooo...........oooo......",
	],
	# The sky in two halves on a parchment hung from a rod, stars and a
	# constellation inked in.
	"star_chart": [
		"................................",
		"..oooooooooooooooooooooooooooo..",
		"..ommwmmmmwmmmmwmmmmwmmmmwmmmo..",
		"...oPppppppppppppppppppppppPo...",
		"...oPqqpqqtqqppppppqqttqqpqPo...",
		"...oPppqttstyqppqpqttsyttqpPo...",
		"...oPpqtsyssstqpppqtYssstqpPo...",
		"...oPpqtssssstqppptssuysstpPo...",
		"...oPpqtsssYstqpqptsssusstpPo...",
		"...oPpqtYsssstqpppqtyssYtqpPo...",
		"...oPppqttyttqpqppqttssttqpPo...",
		"...oPqppqqtqqppppppqqttqqqqPo...",
		"...oPPPPPPPPPPPPPPPPPPPPPPPPo...",
		"..oooooooooooooooooooooooooooo..",
		"..ommwmmmmwmmmmwmmmmwmmmmwmmmo..",
		"..oooooooooooooooooooooooooooo..",
	],
	# A globe of the night sky in its brass ring, on a stand.
	"star_globe": [
		".....oooooo.....",
		"....oeeeecco....",
		"...oeooGGooco...",
		"..oeoGyGuuuoco..",
		"..oeoGGuuYgomo..",
		"..oeGGuuuggsmo..",
		"..oeGYuuygssmo..",
		"..ocouuggYsomo..",
		"..ocouggsssomo..",
		"...ocoossoomo...",
		"....ocmmmmmo....",
		".....oobmoo.....",
		"......obmo......",
		"....obbccmmo....",
		"....oooooooo....",
		"................",
	],
}

static var _textures := {}


## How many cells `name` takes, across and down.
static func cells(name: String) -> Vector2i:
	var rows: Array = PIECES[name]
	return Vector2i(String(rows[0]).length() / 16, rows.size() / 16)


## `name` drawn, once a session.
static func texture(name: String) -> ImageTexture:
	if not _textures.has(name):
		_textures[name] = ImageTexture.create_from_image(LampArt.picture(PIECES[name]))
	return _textures[name]
