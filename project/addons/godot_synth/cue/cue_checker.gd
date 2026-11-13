class_name CueChecker
extends RefCounted

## Headless diagnostics for cue files.
##
## `check_source` parses and validates one source string, `collect_files`
## expands command-line paths into a sorted file list and `run` implements the
## cue_check command line without touching the engine, so a test can call it.

const ParserScript = preload("res://addons/godot_synth/cue/cue_parser.gd")
const ValidatorScript = preload("res://addons/godot_synth/cue/cue_validator.gd")
const CatalogScript = preload("res://addons/godot_synth/cue/cue_catalog.gd")


## One file's result: {file: String, ok: bool, diagnostics: Array}.
## Parses source with CueParser; if that fails, diagnostics are the parser's;
## else diagnostics are CueValidator.validate(ast, catalog).
## ok is true when no diagnostic has severity "error" (warnings do not fail a file).
static func check_source(source: String, file: String, catalog: Dictionary) -> Dictionary:
	var parsed: Dictionary = ParserScript.parse(source)
	var diagnostics: Array[Dictionary] = []
	if parsed.get("ok") == true:
		var ast: Dictionary = parsed["ast"]
		diagnostics = ValidatorScript.validate(ast, catalog)
	else:
		for diagnostic: Dictionary in parsed["diagnostics"]:
			diagnostics.append(diagnostic)
	var ok := true
	for diagnostic: Dictionary in diagnostics:
		if String(diagnostic.get("severity", "")) == "error":
			ok = false
			break
	return {"file": file, "ok": ok, "diagnostics": diagnostics}


## Expands the arguments into a list of files: a file path stays as is; a directory is
## expanded recursively to every "*.cue" file under it; a path that is neither stays in the
## list (it becomes an E_IO result later). Result is sorted by path (String compare) with
## forward slashes, no duplicates.
static func collect_files(paths: Array[String]) -> Array[String]:
	var files: Array[String] = []
	var seen: Dictionary = {}
	for path: String in paths:
		_collect_path(path.replace("\\", "/"), files, seen)
	files.sort()
	return files


static func _collect_path(path: String, files: Array[String], seen: Dictionary) -> void:
	if DirAccess.dir_exists_absolute(path):
		for name: String in DirAccess.get_directories_at(path):
			_collect_path(path.path_join(name), files, seen)
		for name: String in DirAccess.get_files_at(path):
			if name.ends_with(".cue"):
				_add_file(path.path_join(name), files, seen)
	else:
		_add_file(path, files, seen)


static func _add_file(path: String, files: Array[String], seen: Dictionary) -> void:
	if seen.has(path):
		return
	seen[path] = true
	files.append(path)


## The real catalog (CueCatalog.load_default().validator_catalog()). The default of run().
static func default_catalog() -> Dictionary:
	return CatalogScript.load_default().validator_catalog()


## Path of the M2 corpus fixture catalog. No longer the default of run(); tests pass it with --catalog.
static func default_catalog_path() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../tests/cue_corpus/catalog.json")


## Full CLI logic without touching the engine: args are the user args (after "--").
## Returns {lines: Array[String], exit_code: int, error: String}.
static func run(args: PackedStringArray) -> Dictionary:
	var paths: Array[String] = []
	var catalog_path := ""
	var has_catalog := false
	var i := 0
	while i < args.size():
		var arg := String(args[i])
		if arg == "--catalog":
			if i + 1 >= args.size():
				return _usage_error()
			catalog_path = String(args[i + 1])
			has_catalog = true
			i += 2
		else:
			paths.append(arg)
			i += 1
	if paths.is_empty():
		return _usage_error()

	var catalog: Dictionary = {}
	if has_catalog:
		var loaded: Dictionary = _load_catalog(catalog_path)
		if String(loaded.get("error", "")) != "":
			return {"lines": [], "exit_code": 2, "error": loaded["error"]}
		catalog = loaded["catalog"]
	else:
		catalog = default_catalog()
		if catalog.is_empty():
			return {"lines": [], "exit_code": 2, "error": "cannot load the default instrument catalog"}

	var lines: Array[String] = []
	var exit_code := 0
	for file: String in collect_files(paths):
		var result: Dictionary = _check_file(file, catalog)
		if not bool(result["ok"]):
			exit_code = 1
		lines.append(JSON.stringify({
			"file": result["file"],
			"ok": result["ok"],
			"diagnostics": result["diagnostics"],
		}))
	return {"lines": lines, "exit_code": exit_code, "error": ""}


static func _check_file(path: String, catalog: Dictionary) -> Dictionary:
	if not FileAccess.file_exists(path):
		return _io_result(path)
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return _io_result(path)
	var source := handle.get_as_text()
	handle.close()
	return check_source(source, path, catalog)


static func _io_result(path: String) -> Dictionary:
	var diagnostics: Array[Dictionary] = [{
		"code": "E_IO",
		"message": "cannot read file",
		"line": 0,
		"col": 0,
		"severity": "error",
	}]
	return {"file": path, "ok": false, "diagnostics": diagnostics}


static func _load_catalog(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"catalog": {}, "error": "cannot read catalog: " + path}
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return {"catalog": {}, "error": "cannot open catalog: " + path}
	var text := handle.get_as_text()
	handle.close()
	var parsed: Variant = JSON.parse_string(text)
	if not (parsed is Dictionary):
		return {"catalog": {}, "error": "catalog is not a JSON object: " + path}
	return {"catalog": parsed, "error": ""}


static func _usage_error() -> Dictionary:
	return {
		"lines": [],
		"exit_code": 2,
		"error": "usage: cue_check <file|dir>... [--catalog <path>]",
	}
