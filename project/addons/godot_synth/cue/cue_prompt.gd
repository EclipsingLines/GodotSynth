class_name CuePrompt
extends RefCounted
## Assembles a provider-neutral cue prompt from the pack under prompts/cue.
##
## The pack is plain text outside res://: one system prompt, a manifest, and
## request/example cue pairs. `build` adds the real catalog's instrument table
## and returns a system message plus an alternating user/assistant conversation.

const CATALOG_HEADING: String = "## Instruments"
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")
const USAGE := "usage: cue_prompt --request <text> [--pack <dir>]"

## Absolute path of prompts/cue: ProjectSettings.globalize_path("res://").path_join("../prompts/cue").
static func default_pack_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../prompts/cue")

## Reads pack.json, the system file and every example. Returns
## {ok: bool, error: String, system: String, examples: Array}, examples = [{request: String, cue: String}]
## in pack order (cue = the file text exactly as stored). Failures (missing/invalid pack.json, wrong version,
## unreadable system or example file, empty request) give ok false and a message naming the file.
static func load_pack(pack_dir: String) -> Dictionary:
	var loaded: Dictionary = _load_pack(pack_dir)
	return {
		"ok": bool(loaded.get("ok", false)),
		"error": String(loaded.get("error", "")),
		"system": String(loaded.get("system", "")),
		"examples": loaded.get("examples", []),
	}

static func _load_pack(pack_dir: String) -> Dictionary:
	var manifest_path := pack_dir.path_join("pack.json")
	if not FileAccess.file_exists(manifest_path):
		return _pack_error("cannot read " + manifest_path)
	var manifest_text := FileAccess.get_file_as_string(manifest_path)
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not parsed is Dictionary:
		return _pack_error(manifest_path + ": not a JSON object")
	var manifest: Dictionary = parsed
	if int(manifest.get("version", 0)) != 1:
		return _pack_error(manifest_path + ": version must be 1")

	var system_file := String(manifest.get("system_file", ""))
	if system_file.is_empty():
		return _pack_error(manifest_path + ": system_file is missing")
	var system_path := pack_dir.path_join(system_file)
	if not FileAccess.file_exists(system_path):
		return _pack_error("cannot read " + system_path)
	var system_text := FileAccess.get_file_as_string(system_path)

	var raw_examples: Variant = manifest.get("examples", [])
	if not raw_examples is Array:
		return _pack_error(manifest_path + ": examples is not an array")
	var examples: Array = []
	for item: Variant in raw_examples:
		if not item is Dictionary:
			return _pack_error(manifest_path + ": an example entry is not an object")
		var entry: Dictionary = item
		var request := String(entry.get("request", ""))
		if request.strip_edges().is_empty():
			return _pack_error(manifest_path + ": an example request is empty")
		var cue_file := String(entry.get("cue_file", ""))
		if cue_file.is_empty():
			return _pack_error(manifest_path + ": an example cue_file is empty")
		var cue_path := pack_dir.path_join(cue_file)
		if not FileAccess.file_exists(cue_path):
			return _pack_error("cannot read " + cue_path)
		examples.append({
			"request": request,
			"cue": FileAccess.get_file_as_string(cue_path),
		})

	return {
		"ok": true,
		"error": "",
		"system": system_text,
		"examples": examples,
		"catalog_table": bool(manifest.get("catalog_table", false)),
	}

static func _pack_error(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
		"system": "",
		"examples": [],
		"catalog_table": false,
	}

## Builds the chat prompt for a request. catalog null means CueCatalog.load_default(); pack_dir "" means default_pack_dir().
## Returns {system: String, messages: Array, error: String}; error is "" on success, otherwise system "" and messages [].
## system = system file text with trailing newlines removed + "\n\n" + CATALOG_HEADING + "\n\n"
##          + catalog.to_prompt_table() (trailing newlines removed) + "\n"      (only when pack.catalog_table is true)
## messages = for each example {role: "user", content: request}, {role: "assistant", content: cue text with trailing "\n" removed},
##            then {role: "user", content: request.strip_edges()}. Each message is a Dictionary with exactly the keys role, content.
## An empty (after strip_edges) request is an error ("empty request").
static func build(request: String, catalog: CueCatalog = null, pack_dir: String = "") -> Dictionary:
	var dir := pack_dir if pack_dir != "" else default_pack_dir()
	var loaded: Dictionary = _load_pack(dir)
	if not bool(loaded.get("ok", false)):
		return {"system": "", "messages": [], "error": String(loaded.get("error", ""))}
	if request.strip_edges().is_empty():
		return {"system": "", "messages": [], "error": "empty request"}

	var active_catalog: CueCatalog = catalog
	if active_catalog == null:
		active_catalog = CatalogScript.load_default()
	var system_text := String(loaded.get("system", "")).rstrip("\n")
	if bool(loaded.get("catalog_table", false)):
		var table := active_catalog.to_prompt_table().rstrip("\n")
		system_text += "\n\n" + CATALOG_HEADING + "\n\n" + table + "\n"

	var messages: Array = []
	for item: Variant in loaded.get("examples", []):
		var example: Dictionary = item
		messages.append({"role": "user", "content": String(example.get("request", ""))})
		messages.append({"role": "assistant", "content": String(example.get("cue", "")).rstrip("\n")})
	messages.append({"role": "user", "content": request.strip_edges()})
	return {"system": system_text, "messages": messages, "error": ""}

## One plain-text block: blocks joined by "\n\n", each "=== SYSTEM ===\n<system>" or "=== USER ===\n<content>"
## or "=== ASSISTANT ===\n<content>", the system block first, then the messages in order; the text ends with one "\n".
static func to_text(prompt: Dictionary) -> String:
	var blocks := PackedStringArray()
	blocks.append("=== SYSTEM ===\n" + String(prompt.get("system", "")))
	for item: Variant in prompt.get("messages", []):
		if not item is Dictionary:
			continue
		var message: Dictionary = item
		var role := String(message.get("role", "")).to_upper()
		blocks.append("=== " + role + " ===\n" + String(message.get("content", "")))
	return "\n\n".join(blocks) + "\n"

## CLI logic. args = user args after "--": --request <text> (required, non-empty), --pack <dir> (optional).
## Anything else is a usage error. Returns {text: String, exit_code: int, error: String}.
static func run(args: PackedStringArray) -> Dictionary:
	var request := ""
	var pack_dir := ""
	var has_request := false
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg == "--request" or arg == "--pack":
			if i + 1 >= args.size():
				return _usage_error()
			if arg == "--request":
				request = String(args[i + 1])
				has_request = true
			else:
				pack_dir = String(args[i + 1])
			i += 2
		else:
			return _usage_error()
	if not has_request or request.strip_edges().is_empty():
		return _usage_error()

	var prompt: Dictionary = build(request, null, pack_dir)
	if String(prompt.get("error", "")) != "":
		return {"text": "", "exit_code": 2, "error": String(prompt["error"])}
	return {"text": to_text(prompt), "exit_code": 0, "error": ""}

static func _usage_error() -> Dictionary:
	return {"text": "", "exit_code": 2, "error": USAGE}
