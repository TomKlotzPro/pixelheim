class_name WebImport
## The way across from the web game. The Godot build is served from the same
## origin as the web game (tomklotzpro.github.io/pixelheim/), so on the web
## export it can read the web save straight out of localStorage; anywhere
## else a pasted save code (or the raw localStorage JSON) does the job.

## SAVE_KEY in src/state/save.ts.
const WEB_SAVE_KEY := "pixelheim-save-v1"


## The web game's save in this browser, migrated; {} when there is none or
## this is not a web build.
static func find_in_browser() -> Dictionary:
	if not OS.has_feature("web"):
		return {}
	# Storage access can throw (privacy modes): never let it reach the engine.
	var raw: Variant = JavaScriptBridge.eval(
		"(() => { try { return localStorage.getItem('%s'); } catch (e) { return null; } })()"
		% WEB_SAVE_KEY,
		true
	)
	return parse_any(raw) if raw is String else {}


## Accepts what a player is likely to paste: a PXH1 save code, or the raw
## JSON of a save (enveloped or bare, any version). {} when it is neither.
static func parse_any(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed.begins_with(SaveCodec.CODE_PREFIX):
		return SaveCodec.decode_code(trimmed)
	if trimmed.begins_with("{"):
		return SaveCodec.migrate(SaveCodec.parse_json(trimmed))
	return {}


## "Brann, level 7 ranger"
static func describe(state: Dictionary) -> String:
	var hero: Dictionary = state["hero"]
	var role: String = Catalog.role(hero["roleId"]).get("name", hero["roleId"]).to_lower()
	return Text.t("%s, level %d %s") % [hero["name"], hero["level"], role]
