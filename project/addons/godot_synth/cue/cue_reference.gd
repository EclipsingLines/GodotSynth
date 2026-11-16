## Generates the function and instrument tables in docs/cue-language.md.
##
## The page is hand-written except for two marker-delimited blocks: the function
## table comes from CueLib.FUNCTIONS and the instrument table from CueCatalog.
## tools/cue_reference.gd is the CLI wrapper; --check only reports whether the
## page is up to date.
class_name CueReference
extends RefCounted

const FUNCTIONS_BEGIN: String = "<!-- BEGIN GENERATED FUNCTIONS -->"
const FUNCTIONS_END: String = "<!-- END GENERATED FUNCTIONS -->"
const INSTRUMENTS_BEGIN: String = "<!-- BEGIN GENERATED INSTRUMENTS -->"
const INSTRUMENTS_END: String = "<!-- END GENERATED INSTRUMENTS -->"

## Absolute path of docs/cue-language.md.
static func default_doc_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../docs/cue-language.md")

## Signature text of one FUNCTIONS entry.
static func signature(name: String, entry: Dictionary) -> String:
	var max_args := int(entry.get("max_args", 0))
	if max_args == 0:
		if String(entry.get("kind", "")) == "method":
			return name + "()"
		return name
	var kinds: Array = entry.get("arg_kinds", [])
	if max_args == -1:
		var last := ""
		if not kinds.is_empty():
			last = String(kinds[kinds.size() - 1])
		return name + "(" + last + "...)"
	var min_args := int(entry.get("min_args", 0))
	var parts := PackedStringArray()
	for i: int in range(max_args):
		var kind := ""
		if i < kinds.size():
			kind = String(kinds[i])
		elif not kinds.is_empty():
			kind = String(kinds[kinds.size() - 1])
		if i < min_args:
			parts.append(kind)
		else:
			parts.append("[" + kind + "]")
	return name + "(" + ", ".join(parts) + ")"

## The functions table: a markdown table, header then one row per function sorted by name.
static func functions_block() -> String:
	var lines := PackedStringArray()
	lines.append("| Name | Kind | Signature |")
	lines.append("|---|---|---|")
	var names: Array = CueLib.FUNCTIONS.keys()
	names.sort()
	for name: String in names:
		var entry: Dictionary = CueLib.FUNCTIONS[name]
		var kind := String(entry.get("kind", ""))
		if bool(entry.get("also_method", false)):
			kind += ", method"
		lines.append("| `" + name + "` | " + kind + " | `" + signature(name, entry) + "` |")
	return "\n".join(lines)

## The instruments block: the catalog's prompt table in a text fence.
static func instruments_block(catalog: CueCatalog) -> String:
	return "```text\n" + catalog.to_prompt_table().rstrip("\n") + "\n```"

## Replaces what lies between the two marker lines.
## Returns {ok: bool, text: String, error: String}; on an error text is doc unchanged.
static func replace_block(doc: String, begin: String, end: String, body: String) -> Dictionary:
	var begin_count := doc.count(begin)
	var end_count := doc.count(end)
	if begin_count == 0:
		return _failure(doc, "begin marker not found: " + begin)
	if end_count == 0:
		return _failure(doc, "end marker not found: " + end)
	if begin_count > 1:
		return _failure(doc, "begin marker appears more than once: " + begin)
	if end_count > 1:
		return _failure(doc, "end marker appears more than once: " + end)
	var begin_at := doc.find(begin)
	var end_at := doc.find(end)
	if end_at < begin_at:
		return _failure(doc, "end marker comes before begin marker: " + end)
	var prefix := doc.substr(0, begin_at + begin.length())
	var suffix := doc.substr(end_at)
	return {"ok": true, "text": prefix + "\n" + body + "\n" + suffix, "error": ""}

## Applies both blocks, functions then instruments.
## Returns {ok: bool, text: String, error: String}; on an error text is doc unchanged.
static func regenerate(doc: String, catalog: CueCatalog) -> Dictionary:
	var functions := replace_block(doc, FUNCTIONS_BEGIN, FUNCTIONS_END, functions_block())
	if not bool(functions["ok"]):
		return functions
	var instruments := replace_block(
		String(functions["text"]), INSTRUMENTS_BEGIN, INSTRUMENTS_END, instruments_block(catalog))
	if not bool(instruments["ok"]):
		return _failure(doc, String(instruments["error"]))
	return instruments

## CLI logic; args are the user args after "--": [--check] [--doc <path>].
## Returns {lines: Array[String], exit_code: int, error: String}.
static func run(args: PackedStringArray) -> Dictionary:
	var check := false
	var doc_path := ""
	var has_doc := false
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg == "--check":
			check = true
			i += 1
		elif arg == "--doc":
			if i + 1 >= args.size():
				return _usage("--doc needs a path argument")
			doc_path = String(args[i + 1])
			has_doc = true
			i += 2
		else:
			return _usage("unknown argument: " + arg)
	if not has_doc:
		doc_path = default_doc_path()

	var handle := FileAccess.open(doc_path, FileAccess.READ)
	if handle == null:
		return _run_error("cannot read doc: " + doc_path)
	var doc := handle.get_as_text()
	handle.close()

	var catalog := CueCatalog.load_default()
	var result := regenerate(doc, catalog)
	if not bool(result["ok"]):
		return _run_error(String(result["error"]))
	var text := String(result["text"])

	if check:
		if text == doc:
			return {"lines": ["up to date"], "exit_code": 0, "error": ""}
		return {
			"lines": ["out of date: run tools/cue_reference.gd without --check"],
			"exit_code": 1,
			"error": "",
		}
	if text == doc:
		return {"lines": ["unchanged " + doc_path], "exit_code": 0, "error": ""}

	var out := FileAccess.open(doc_path, FileAccess.WRITE)
	if out == null:
		return _run_error("cannot write doc: " + doc_path)
	out.store_string(text)
	out.close()
	return {"lines": ["updated " + doc_path], "exit_code": 0, "error": ""}

static func _failure(doc: String, message: String) -> Dictionary:
	return {"ok": false, "text": doc, "error": message}

static func _usage(message: String) -> Dictionary:
	return {"lines": [], "exit_code": 2, "error": message}

static func _run_error(message: String) -> Dictionary:
	return {"lines": [], "exit_code": 2, "error": message}
