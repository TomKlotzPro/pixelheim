class_name PostState
extends Resource
## The Pixelheim Post as the hero has kept it (PIX-320): only what they did.
## Which pieces wait in the post box each morning is worked out from the
## day, the seed and the threads (Post.in_box), so it's never saved; what's
## kept is the satchel (the pieces taken from the box, and the replies
## handed back to carry home), how far each thread has come, the pieces
## delivered (in the order they were, for the journal's Post tab), the day
## the box was last emptied (it fills again the morning after), and the
## courier's book (PIX-321): the day each place's page was first stamped,
## and the place each piece was delivered at (a settler's old letters stay
## on the page of where they lived then).

## The pieces in the satchel, by id, in the order they came.
var bag: Array[String] = []
## Thread id -> how many of its pieces are delivered (its next one's index).
var threads := {}
## The pieces delivered, by id, oldest first.
var delivered: Array[String] = []
## The day the box was last emptied (Gathering.day_of), -1 before the first.
var taken := -1
## The courier's book: a page (a place, Post.place_of) -> the day it was
## first stamped.
var stamps := {}
## A delivered piece -> the page it was stamped on.
var places := {}


static func from_dict(data: Dictionary) -> PostState:
	var post := PostState.new()
	post.bag.assign(data.get("bag", []))
	var steps: Dictionary = data.get("threads", {})
	for thread_id: String in steps:
		post.threads[thread_id] = int(steps[thread_id])
	post.delivered.assign(data.get("delivered", []))
	post.taken = int(data.get("taken", -1))
	var stamped: Dictionary = data.get("stamps", {})
	for place: String in stamped:
		post.stamps[place] = int(stamped[place])
	var at: Dictionary = data.get("places", {})
	for piece_id: String in at:
		post.places[piece_id] = String(at[piece_id])
	return post


## The section as the save holds it.
func to_dict() -> Dictionary:
	return {
		"bag": bag.duplicate(), "threads": threads.duplicate(), "delivered": delivered.duplicate(), "taken": taken,
		"stamps": stamps.duplicate(), "places": places.duplicate(),
	}


## Whether nothing has happened yet: no piece taken or delivered, the box
## never emptied (the save leaves the section out).
func is_empty() -> bool:
	return bag.is_empty() and threads.is_empty() and delivered.is_empty() and taken < 0 and stamps.is_empty()


## How far thread `thread_id` has come: its pieces delivered.
func step(thread_id: String) -> int:
	return int(threads.get(thread_id, 0))
