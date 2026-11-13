extends SceneTree
# CueChecker: collect_files, check_source and the JSON lines from run().
# Run: bash tests/verify.sh --no-build tests/test_cue_check.gd
# Exits with code 0 when every check passes, 1 otherwise.

const CheckerScript = preload("res://addons/godot_synth/cue/cue_checker.gd")

var failures: Array[String] = []
var checks := 0
var fixture_catalog: String = ""


func check(name: String, ok: bool, detail: String = "") -> void:
	checks += 1
	if ok:
		print("PASS " + name)
	else:
		print("FAIL " + name + ": " + detail)
		failures.append(name)


func _corpus_dir() -> String:
	return ProjectSettings.globalize_path("res://").path_join("../tests/cue_corpus")


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _load_catalog(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(_read(path))
	if parsed is Dictionary:
		return parsed
	check("catalog loads", false, path)
	return {}


func _has_diagnostic(diagnostics: Array, code: String, line: int, col: int) -> bool:
	for diagnostic: Dictionary in diagnostics:
		if String(diagnostic.get("code", "")) == code \
				and int(diagnostic.get("line", 0)) == line \
				and int(diagnostic.get("col", 0)) == col:
			return true
	return false


func _parse_lines(lines: Array) -> Array[Dictionary]:
	var parsed: Array[Dictionary] = []
	for line: String in lines:
		var value: Variant = JSON.parse_string(line)
		if value is Dictionary:
			parsed.append(value)
	return parsed


func _initialize() -> void:
	var corpus := _corpus_dir()
	fixture_catalog = corpus.path_join("catalog.json")
	var catalog := _load_catalog(corpus.path_join("catalog.json"))
	var run_results: Array[Dictionary] = []

	# 1. collect_files expands directories, keeps missing paths and sorts.
	var all_files := CheckerScript.collect_files([corpus])
	check("collect all count", all_files.size() == 40, str(all_files.size()))
	var paths_ok := true
	for path: String in all_files:
		if not path.ends_with(".cue") or "\\" in path:
			paths_ok = false
			break
	check("collect all cue paths", paths_ok, str(all_files))
	var sorted_ok := true
	for i: int in range(1, all_files.size()):
		if String(all_files[i]) < String(all_files[i - 1]):
			sorted_ok = false
			break
	check("collect all sorted", sorted_ok, str(all_files))
	var valid_files := CheckerScript.collect_files([corpus + "/valid"])
	check("collect valid count", valid_files.size() == 12, str(valid_files.size()))
	var missing_files := CheckerScript.collect_files(["nope/missing.cue"])
	check("collect missing stays", missing_files.size() == 1 \
		and missing_files[0] == "nope/missing.cue", str(missing_files))

	# 2. check_source: parser diagnostics, validator diagnostics, warnings pass.
	var forest_text := _read(corpus.path_join("valid/forest.cue"))
	var forest := CheckerScript.check_source(forest_text, "forest.cue", catalog)
	check("forest ok", bool(forest["ok"]), str(forest))
	check("forest file echoed", String(forest["file"]) == "forest.cue", str(forest))
	var forest_errors := false
	for diagnostic: Dictionary in forest["diagnostics"]:
		if String(diagnostic.get("severity", "")) == "error":
			forest_errors = true
			break
	check("forest no errors", not forest_errors, str(forest["diagnostics"]))

	var js_arrow := CheckerScript.check_source(
		_read(corpus.path_join("invalid/js_arrow.cue")), "js_arrow.cue", catalog)
	var js_diagnostics: Array = js_arrow["diagnostics"]
	var js_first_ok := false
	if not js_diagnostics.is_empty():
		var first: Dictionary = js_diagnostics[0]
		js_first_ok = String(first.get("code", "")) == "E_SYNTAX" \
			and int(first.get("line", 0)) == 4 \
			and int(first.get("col", 0)) == 23
	check("js arrow fails", not bool(js_arrow["ok"]), str(js_arrow))
	check("js arrow diagnostic", js_first_ok, str(js_diagnostics))

	var unknown := CheckerScript.check_source(
		_read(corpus.path_join("invalid/unknown_instrument.cue")),
		"unknown_instrument.cue", catalog)
	check("unknown instrument fails", not bool(unknown["ok"]), str(unknown))
	check("unknown instrument diagnostic",
		_has_diagnostic(unknown["diagnostics"], "E_UNKNOWN_INSTRUMENT", 4, 6),
		str(unknown["diagnostics"]))

	var warning := CheckerScript.check_source(
		"state a:\n  n(\"0 2\").s(\"lead\")\n", "x.cue", catalog)
	check("warning stays ok", bool(warning["ok"]), str(warning))
	check("warning diagnostic",
		_has_diagnostic(warning["diagnostics"], "W_N_WITHOUT_SCALE", 2, 3),
		str(warning["diagnostics"]))

	# 3. run() on one valid file.
	var valid_run := CheckerScript.run(PackedStringArray([
		corpus + "/valid/forest.cue", "--catalog", fixture_catalog,
	]))
	run_results.append(valid_run)
	var valid_lines: Array = valid_run["lines"]
	check("run forest exit", int(valid_run["exit_code"]) == 0, str(valid_run))
	check("run forest one line", valid_lines.size() == 1, str(valid_lines))
	var valid_parsed := _parse_lines(valid_lines)
	var valid_dictionary := valid_parsed.size() == 1
	if valid_dictionary:
		var entry: Dictionary = valid_parsed[0]
		valid_dictionary = entry.has("file") and entry.has("ok") \
			and entry.has("diagnostics") and bool(entry["ok"])
	check("run forest json", valid_dictionary, str(valid_lines))

	# 4. run() on one invalid file.
	var invalid_run := CheckerScript.run(PackedStringArray([
		corpus + "/invalid/js_arrow.cue", "--catalog", fixture_catalog,
	]))
	run_results.append(invalid_run)
	var invalid_lines: Array = invalid_run["lines"]
	check("run js arrow exit", int(invalid_run["exit_code"]) == 1, str(invalid_run))
	check("run js arrow one line", invalid_lines.size() == 1, str(invalid_lines))
	var invalid_parsed := _parse_lines(invalid_lines)
	check("run js arrow json", invalid_parsed.size() == 1 \
		and not bool(invalid_parsed[0]["ok"]), str(invalid_lines))

	# 5. run() over directories and the whole corpus.
	var valid_dir_run := CheckerScript.run(PackedStringArray([
		corpus + "/valid", "--catalog", fixture_catalog,
	]))
	run_results.append(valid_dir_run)
	check("run valid dir exit", int(valid_dir_run["exit_code"]) == 0, str(valid_dir_run))
	check("run valid dir lines", (valid_dir_run["lines"] as Array).size() == 12,
		str((valid_dir_run["lines"] as Array).size()))

	var invalid_dir_run := CheckerScript.run(PackedStringArray([
		corpus + "/invalid", "--catalog", fixture_catalog,
	]))
	run_results.append(invalid_dir_run)
	var invalid_dir_lines: Array = invalid_dir_run["lines"]
	check("run invalid dir exit", int(invalid_dir_run["exit_code"]) == 1,
		str(invalid_dir_run))
	check("run invalid dir lines", invalid_dir_lines.size() == 28,
		str(invalid_dir_lines.size()))
	var invalid_dir_parsed := _parse_lines(invalid_dir_lines)
	var all_invalid := invalid_dir_parsed.size() == invalid_dir_lines.size()
	if all_invalid:
		for entry: Dictionary in invalid_dir_parsed:
			if bool(entry["ok"]):
				all_invalid = false
				break
	check("run invalid dir all fail", all_invalid, str(invalid_dir_lines))

	var corpus_run := CheckerScript.run(PackedStringArray([
		corpus, "--catalog", fixture_catalog,
	]))
	run_results.append(corpus_run)
	var corpus_lines: Array = corpus_run["lines"]
	check("run corpus exit", int(corpus_run["exit_code"]) == 1, str(corpus_run))
	check("run corpus lines", corpus_lines.size() == 40, str(corpus_lines.size()))
	var corpus_parsed := _parse_lines(corpus_lines)
	var files_in_order: Array[String] = []
	for entry: Dictionary in corpus_parsed:
		files_in_order.append(String(entry.get("file", "")))
	var expected_order := files_in_order.duplicate()
	expected_order.sort()
	check("run corpus sorted", files_in_order == expected_order, str(files_in_order))

	# 6. Lines are single-line JSON; every diagnostic has the stable shape.
	var lines_ok := true
	var shapes_ok := true
	for result: Dictionary in run_results:
		for line: String in result["lines"]:
			if "\n" in line:
				lines_ok = false
				break
			var value: Variant = JSON.parse_string(line)
			if not (value is Dictionary):
				shapes_ok = false
				continue
			for diagnostic: Variant in (value as Dictionary).get("diagnostics", []):
				if not (diagnostic is Dictionary):
					shapes_ok = false
					continue
				var keys: Array = (diagnostic as Dictionary).keys()
				keys.sort()
				if keys != ["code", "col", "line", "message", "severity"]:
					shapes_ok = false
				var line_type := typeof((diagnostic as Dictionary).get("line"))
				var col_type := typeof((diagnostic as Dictionary).get("col"))
				if line_type != TYPE_INT and line_type != TYPE_FLOAT:
					shapes_ok = false
				if col_type != TYPE_INT and col_type != TYPE_FLOAT:
					shapes_ok = false
	check("run lines single line", lines_ok, str(run_results))
	check("run diagnostic shape", shapes_ok, str(run_results))

	# 7. A missing file is an E_IO diagnostic, not a usage error.
	var missing_run := CheckerScript.run(PackedStringArray(["nope/missing.cue"]))
	run_results.append(missing_run)
	var missing_lines: Array = missing_run["lines"]
	check("run missing exit", int(missing_run["exit_code"]) == 1, str(missing_run))
	check("run missing one line", missing_lines.size() == 1, str(missing_lines))
	var missing_parsed := _parse_lines(missing_lines)
	var missing_io := false
	if missing_parsed.size() == 1:
		missing_io = _has_diagnostic(missing_parsed[0]["diagnostics"], "E_IO", 0, 0)
	check("run missing E_IO", missing_io, str(missing_lines))

	# 8. Usage and catalog failures exit 2 with no lines.
	var no_args := CheckerScript.run(PackedStringArray())
	check("usage no paths", int(no_args["exit_code"]) == 2 \
		and (no_args["lines"] as Array).is_empty() \
		and String(no_args["error"]) != "", str(no_args))
	var no_value := CheckerScript.run(PackedStringArray(["--catalog"]))
	check("usage missing catalog value", int(no_value["exit_code"]) == 2 \
		and (no_value["lines"] as Array).is_empty() \
		and String(no_value["error"]) != "", str(no_value))
	var bad_catalog := CheckerScript.run(PackedStringArray([
		corpus + "/valid/forest.cue", "--catalog", "nope/missing.json",
	]))
	check("usage bad catalog", int(bad_catalog["exit_code"]) == 2 \
		and (bad_catalog["lines"] as Array).is_empty() \
		and String(bad_catalog["error"]) != "", str(bad_catalog))

	# 9. --catalog replaces the default fixture.
	var temp_catalog := ProjectSettings.globalize_path("user://cue_check_test_catalog.json")
	var handle := FileAccess.open(temp_catalog, FileAccess.WRITE)
	if handle == null:
		check("custom catalog write", false, temp_catalog)
	else:
		handle.store_string("{\"pad\": {\"controls\": [\"lpf\"]}}")
		handle.close()
		var custom_run := CheckerScript.run(PackedStringArray([
			corpus + "/valid/forest.cue", "--catalog", temp_catalog,
		]))
		run_results.append(custom_run)
		var custom_lines: Array = custom_run["lines"]
		var custom_parsed := _parse_lines(custom_lines)
		var custom_unknown := false
		if custom_parsed.size() == 1:
			for diagnostic: Dictionary in custom_parsed[0]["diagnostics"]:
				if String(diagnostic.get("code", "")) == "E_UNKNOWN_INSTRUMENT":
					custom_unknown = true
					break
		check("custom catalog exit", int(custom_run["exit_code"]) == 1, str(custom_run))
		check("custom catalog unknown instrument", custom_unknown, str(custom_lines))
		DirAccess.remove_absolute(temp_catalog)

	if failures.is_empty():
		print("PASS all cue check checks (%d)" % checks)
		quit(0)
	else:
		print("FAILURES: " + ", ".join(failures))
		quit(1)
