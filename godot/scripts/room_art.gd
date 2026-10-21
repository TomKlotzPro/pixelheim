class_name RoomArt
## A keeper's room its own (PIX-315): Liane keeps the stars in her
## observatory, and nothing in Shade's packs is a telescope, a star chart or
## a globe of the sky. So these are drawn here, a pixel a character in his
## palette (LampArt.PALETTE), and stand in a room's layout as any piece does
## (interiors.json: a vignette's `art`, [x, y, name]): the telescope on its
## tripod aimed up at a window, the chart of the two skies hung on the back
## wall, the celestial globe on its stand. Each takes whole cells, its top
## left on the cell it names; what stands on the floor blocks it. And the
## ledgers read in the world (PIX-338: Hale's order book was a pair of jugs
## on his table): a book lying open, laid over a table with its keeper's
## touch beside it, and the table itself where the paid pack isn't.

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
	# A ledger lying open on a table (PIX-338): two ruled pages written
	# down, a red ribbon hanging from its spine, and a quill standing in its
	# inkwell; the table's top left cell is its, the candle clear of it.
	"open_book": [
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"..............................o.",
		".............................oy.",
		"............................oyo.",
		"....ooooooooo.ooooooooo.....yho.",
		"...oBBBBBBBBDoDBBBBBBBBo...oyho.",
		"...oBqqBqqqBDqDBqqqBqqBo...yho..",
		"...oDDDDDDDDDqDDDDDDDDDo..oyho..",
		"...oBqqqBqqBDqDBqqBqqqBo..yho...",
		"...oDDDDDDDDDqDDDDDDDDDo..oDo...",
		"...oBqBqqqqBDqDBqqqBqBBo.okDko..",
		"...oDDDDDDDDDqDDDDDDDDDo.oihiko.",
		"...oBqqBqqBBDqDBqqBBBBBo.oiiiko.",
		"...oDDDDDDDDDqDDDDDDDDDo.oikkko.",
		"...oBBBBBBBBDqDBBBBBBBBo..ooooo.",
		"...owwwwwwwwwRwwwwwwwwwo........",
		"....oooooooooRooooooooo.........",
		".............R..................",
		"............R.R.................",
		"................................",
		"................................",
		"................................",
		"................................",
	],
	# Captain Hale's map of the mountain road under his dagger, beside his
	# order book (PIX-338).
	"map_dagger": [
		"................................",
		"...oooooooooooooo...............",
		"..onnnnnnnnnnnnnPo..............",
		"..onnGnnnnnnqnnnPo..............",
		"..onnnGnnnnqnqnnPo..............",
		"..onnnGGnnnnnnnnPo..............",
		"..onRnnnGnnnnRnnPo..............",
		"..onnRnnnoRnRnnnPo..............",
		"..onnnoooeoooooooo..............",
		"..onnoewweyyyyyyyo..............",
		"..oPPoewwehhhhhhhho.............",
		"...ooooooeoooooooo..............",
		".........o......................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
	],
	# The village's plans, rolled, and a seal, beside its ledger in the hall
	# (PIX-338).
	"plans": [
		"................................",
		"................................",
		"....oooooooooooo................",
		"...obBBBBBBBBBBbo...............",
		"..ombDDDDDDDDDDbmo..............",
		"..ombBBBBBBBBBBbmo..............",
		"...omoooooooooooo...............",
		"....obBBBBBBBBBBoo..............",
		"...ombDDDDDDDDDoRRo.............",
		"...ombBBBBBBBBBoRdo.............",
		"....omoooooooooooo..............",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
		"................................",
	],
	# A table without the paid pack (PIX-338), Shade's planks and a candle
	# at its back, for the ledgers and their touches to lie on.
	"desk": [
		"oooooooooooooooooooooooooooooooo",
		"occcccccccccccccccccccoYoccccccc",
		"obbbbmbbbbbbbbbbbbbbbbaYabbbbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbabbbbbbbo",
		"obbbbbbbbbbmmbbbbbbbbboyyobmbbbo",
		"obbbbbbbbbbbbbbbbbbbbboyBobbbbbo",
		"obbbbbbbbbbbbbbbbbbbbboyBobbbbbo",
		"obbbbbbbbbbbbbbbbbbmboooooobbbbo",
		"obbbbbbbbbbbbbbbbbbbomeeeemobbbo",
		"ommmmmmmmmmmmmmmmmmmmommmmommmmo",
		"occcccccccccccccccccccoooocccccc",
		"obbbbbbbbbbbbmbbbbbbbbbbbbbbbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"obbbmmbbbbbbbbbbbbbbbmbbbbbbbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"obbbbbbbbmbbbbbbbbbbbbbbbbbmbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"ommmmmmmmmmmmmmmmmmmmmmmmmmmmmmo",
		"occccccccccccccccccccccccccccccc",
		"obbbbmbbbbbbbbbbbbbbbbbmbbbbbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"obbbbbbbbbbmmbbbbbbbbbbbbbbmbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"obbbbbbbbbbbbbbbbbbmbbbbbbbbbbbo",
		"obbbbbbbbbbbbbbbbbbbbbbbbbbbbbbo",
		"ommmmmmmmmmmmmmmmmmmmmmmmmmmmmmo",
		"owwwwwwwwwwwwwwwwwwwwwwwwwwwwwwo",
		"oddddddddddddddddddddddddddddddo",
		"oowwoooooooooooooooooooooooowwoo",
		".owwo....................owwo...",
	],
	# Mirelle's counting table by the hall (PIX-338), a cell wide and two
	# long: her ledger open at its head, a candle between two coin stacks,
	# the strongbox below.
	"bank_desk": [
		"oooooooooooooooo",
		"ocooooocooooocco",
		"ooBBBBDoDBBBBobo",
		"ooBqqBDqDBqqBobo",
		"ooDDDDDqDDDDDobo",
		"ooBqBqDqDBqqBobo",
		"ooDDDDDqDDDDDobo",
		"ooBqqBDqDBqBBobo",
		"ooDDDDDqDDDDDobo",
		"oowwwwwRwwwwwobo",
		"ocoooooRooooocco",
		"ocbbbbbRbbbmbbbo",
		"ocbmbbRmRbbbbbbo",
		"occoobbYbbbbbbbo",
		"ocoYaoaYabboobbo",
		"ocoaeooyoboYaobo",
		"ocoPeooBoboaeobo",
		"ocoaeooyoboPeobo",
		"ocboobmembboobbo",
		"occcooooooooccco",
		"ocboihhhhhhiobbo",
		"occoimmmmmmiobbo",
		"ocboiiiiiiiiobbo",
		"ocbowwwoowwwobbo",
		"ocbowwoeYowwobbo",
		"occowwoeeowwobbo",
		"ocbokkkookkkobbo",
		"ocbboooooooobbbo",
		"owwwwwwwwwwwwwwo",
		"oddddddddddddddo",
		"oowoooooooooowoo",
		".owo........owo.",
	],
}

static var _textures := {}


## Whether `name` is drawn here: a piece, or pieces laid one over the other
## ("desk+open_book": the ledger on the table, PIX-338).
static func has(name: String) -> bool:
	return Array(name.split("+")).all(func(part: String) -> bool: return PIECES.has(part))


## How many cells `name` takes, across and down (pieces laid over one
## another take the first's).
static func cells(name: String) -> Vector2i:
	var rows: Array = PIECES[name.get_slice("+", 0)]
	return Vector2i(String(rows[0]).length() / 16, rows.size() / 16)


## `name` drawn, once a session; "a+b" is b drawn over a.
static func texture(name: String) -> ImageTexture:
	if not _textures.has(name):
		var parts := name.split("+")
		var image := LampArt.picture(PIECES[parts[0]])
		for part: String in parts.slice(1):
			var over := LampArt.picture(PIECES[part])
			image.blend_rect(over, Rect2i(Vector2i.ZERO, over.get_size()), Vector2i.ZERO)
		_textures[name] = ImageTexture.create_from_image(image)
	return _textures[name]
