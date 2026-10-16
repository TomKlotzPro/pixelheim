class_name Posting
extends RefCounted
## The Pixelheim Post in play (PIX-320): the day's post taken from the box
## on the square, a piece handed over to its addressee (their line, the
## tip, a reply to carry back). The rules are Post's; what the hero did is
## GameState's `post` section, reached through `owner`.

const GameStateScript := preload("res://scripts/state/game_state.gd")

## The GameState this works on, never the `GameState` autoload: tests build
## their own (GameStateScript.new()), and a module reaching the autoload
## would change the real game's state from inside one.
var owner: GameStateScript


func _init(state: GameStateScript) -> void:
	owner = state


## Whether the Post is open for this hero (Maren's first letter delivered).
func is_open() -> bool:
	return Post.open(owner.progression, owner.settlement)


## Today, as the box counts its mornings.
func today() -> int:
	return Post.day_of(owner.world.steps)


## What the post box on the square holds now, by piece id.
func in_box() -> Array[String]:
	return Post.in_box(owner.post, today(), owner.progression, owner.settlement, owner.world.discovered)


## E at the post box: the day's post into the satchel, and the line to
## show (where it goes, or that the box is empty till the morning). "" while
## the Post isn't open.
func take_bag() -> String:
	if not is_open():
		return ""
	var ids := in_box()
	if ids.is_empty():
		if owner.post.taken >= today():
			return Text.t("The post box is empty. Fresh post comes in the morning.")
		return Text.t("Nothing in the post box today. Fresh post comes in the morning.")
	Post.take(owner.post, ids, today())
	owner.mark_dirty()
	owner.save_now()
	if ids.size() == 1:
		return Text.t("You take the day's post: one piece, for %s.") % Post.where(Post.piece(ids[0]), owner.progression, owner.settlement)
	return Text.t("You take the day's post: %d pieces. Who each is for is in the journal's Post tab.") % ids.size()


## The piece in the satchel for `npc_id` ({} for none): handed over at the
## end of a word with them.
func carried_for(npc_id: String) -> Dictionary:
	return Post.carried_for(owner.post, npc_id)


## The piece for `npc_id` handed over as the word with them ends: their
## tip (and now and then a thing to keep, or a recipe for the book), the
## thread on a step, the courier's book stamped where they stand (PIX-321),
## and its reply, if one follows, in the satchel to carry back (said in the
## log, with a page stamped for the first time). Returns the line to show,
## "" when they're owed none.
func deliver(npc_id: String) -> String:
	var entry := carried_for(npc_id)
	if entry.is_empty():
		return ""
	var place := Post.place_for(npc_id, owner.progression, owner.settlement)
	var new_page := place != "" and not owner.post.stamps.has(place)
	var reply := Post.hand_over(owner.post, String(entry["id"]))
	Post.stamp(owner.post, String(entry["id"]), place, today())
	var paid: Array[String] = []
	var tip := int(entry.get("tip", 0))
	if tip > 0:
		owner.pack.gold += tip
		paid.append(Text.t("+%d gold") % tip)
	var kept := Post.kept(entry)
	if kept["gift"] != "":
		owner.pack.add_item(kept["gift"])
		paid.append(Catalog.item_name(kept["gift"]))
	if kept["recipe"] != "":
		paid.append(Text.t("a recipe in your book: %s") % Catalog.item_name(String(Economy.recipe(kept["recipe"]).get("itemId", ""))))
	owner.pack_changed()
	owner.save_now()
	var notes: Array[String] = []
	if new_page:
		notes.append(Text.t("A new postmark in your courier's book: %s.") % Text.mid(Catalog.place_name(place)))
	if not reply.is_empty():
		notes.append(Text.t("A reply to carry back: %s.") % reply["addressed"])
	if not notes.is_empty():
		owner.noted.emit(notes)
	if paid.is_empty():
		return Text.t("Delivered: %s.") % entry["addressed"]
	return Text.t("Delivered: %s. %s.") % [entry["addressed"], ", ".join(paid)]
